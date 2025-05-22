# OPA Multi-Tenant RBAC/ABAC/ReBAC Guide

This guide walks you through designing, structuring, deploying, and testing a multi-tenant access control system using Open Policy Agent (OPA) with RBAC, ABAC, and ReBAC policies.

---

## Table of Contents

1. [What is OPA?](#what-is-opa)
2. [Overview](#overview)
3. [Install OPA Server](#install-opa-server)
4. [Folder and Bundle Structure](#folder-and-bundle-structure)
5. [Example Policy and Data Files](#example-policy-and-data-files)
    - [Examples for tenantA](#examples-for-tenanta)
    - [Examples for tenantB](#examples-for-tenantb)
6. [Bundle Packaging & Serving](#bundle-packaging--serving)
7. [OPA Server Configuration](#opa-server-configuration)
8. [Testing Policies via API](#testing-policies-via-api)
9. [FastAPI Bundle Server Example](#fastapi-bundle-server-example)
10. [requirements.txt for Bundle Server](#requirementstxt-for-bundle-server)
11. [Manifest.json Usage](#manifestjson-usage)
12. [Can Data Be Overridden via API?](#can-data-be-overridden-via-api)
13. [References](#references)

---

## What is OPA?

**Open Policy Agent (OPA)** is an open source, general-purpose policy engine that enables unified, context-aware policy enforcement across the stack. OPA decouples policy decision-making from policy enforcement, letting you write policies in a high-level declarative language (Rego) and query them over a REST API.  
OPA is widely used for authorization (RBAC, ABAC, ReBAC), admission control, data filtering, and more in cloud-native environments (like Kubernetes, microservices, and APIs).

- **Website:** [openpolicyagent.org](https://www.openpolicyagent.org/)
- **Key Features:**
  - Policy-as-code (Rego language)
  - REST API for decision queries
  - Supports bundles for policy/data distribution
  - Integrates with Kubernetes, Envoy, microservices, gateways, and custom apps

---

## Overview

- Each tenant has a dedicated bundle containing their policies and data.
- Policies can be split by type (RBAC, ABAC, ReBAC) and by module (e.g., per application).
- OPA loads bundles regularly and evaluates policies via REST API.

---

## Install OPA Server

### 1. Download OPA Binary

You can install OPA by downloading the binary from the official releases:

**Linux/macOS:**
```bash
curl -L -o opa https://openpolicyagent.org/downloads/latest/opa_linux_amd64_static
chmod +x opa
sudo mv opa /usr/local/bin/
```

**Windows:**
- Download the latest release from [OPA GitHub Releases](https://github.com/open-policy-agent/opa/releases)
- Add the OPA executable to your `PATH`

### 2. Verify Installation

```bash
opa version
```
You should see output like:
```
Version: 0.60.0
Build Commit: ...
Build Timestamp: ...
```

---

## Folder and Bundle Structure

```
bundles/
  tenantA/
    policies/
      rbac_app1.rego
      abac_finance.rego
      rebac_project.rego
    data.json
    manifest.json
  tenantB/
    policies/
      rbac_main.rego
      abac_sales.rego
      rebac_invoice.rego
    data.json
    manifest.json
```
- Each tenant has a folder.
- Policies are split by function/module.
- `data.json` holds tenant-specific data.
- `manifest.json` (optional) specifies bundle roots and revision.

---

## Example Policy and Data Files

### Examples for tenantA

#### RBAC Example (`bundles/tenantA/policies/rbac_app1.rego`)
```rego
package tenants.tenantA.rbac.app1

default allow := false

allow if {
    input.user == "alice"
    input.action == "edit"
    input.resource == "document"
}
```

#### ABAC Example (`bundles/tenantA/policies/abac_finance.rego`)
```rego
package tenants.tenantA.abac.finance

default allow := false

allow if {
    input.user.department == "finance"
    input.action == "read"
    input.resource.department == "finance"
}
```

#### ReBAC Example (`bundles/tenantA/policies/rebac_project.rego`)
```rego
package tenants.tenantA.rebac.project

default allow := false

allow if {
    data.tenants.tenantA.relationships[input.user][input.resource] == "owner"
    input.action == "delete"
}
```

#### Data Example (`bundles/tenantA/data.json`)
```json
{
  "tenants": {
    "tenantA": {
      "relationships": {
        "alice": { "project-123": "owner" },
        "bob": { "project-123": "member" }
      }
    }
  },
  "users": {
    "alice": {"department": "finance"},
    "bob": {"department": "engineering"}
  }
}
```

#### Manifest Example (`bundles/tenantA/manifest.json`)
```json
{
  "revision": "2025-05-22-1",
  "roots": ["policies", "users", "relationships"]
}
```

---

### Examples for tenantB

#### RBAC Example (`bundles/tenantB/policies/rbac_main.rego`)
```rego
package tenants.tenantB.rbac.main

default allow := false

allow if {
    input.user == "charlie"
    input.action == "approve"
    input.resource == "expense"
}
```

#### ABAC Example (`bundles/tenantB/policies/abac_sales.rego`)
```rego
package tenants.tenantB.abac.sales

default allow := false

allow if {
    input.user.region == input.resource.region
    input.action == "view"
    input.resource.department == "sales"
}
```

#### ReBAC Example (`bundles/tenantB/policies/rebac_invoice.rego`)
```rego
package tenants.tenantB.rebac.invoice

default allow := false

allow if {
    data.tenants.tenantB.relationships[input.user][input.resource] == "editor"
    input.action == "update"
}
```

#### Data Example (`bundles/tenantB/data.json`)
```json
{
  "tenants": {
    "tenantB": {
      "relationships": {
        "charlie": { "invoice-456": "editor" },
        "dana": { "invoice-456": "viewer" }
      }
    }
  },
  "users": {
    "charlie": { "region": "us-west", "department": "sales" },
    "dana": { "region": "eu-central", "department": "sales" }
  }
}
```

#### Manifest Example (`bundles/tenantB/manifest.json`)
```json
{
  "revision": "2025-05-22-1",
  "roots": ["policies", "users", "relationships"]
}
```

---

## Bundle Packaging & Serving

1. From inside each tenant's directory:
   ```bash
   tar -czf bundle.tar.gz policies data.json manifest.json
   ```
2. Serve each `bundle.tar.gz` via a simple HTTP server (see below for FastAPI example).

---

## OPA Server Configuration

### Example `opa-config.yaml`

```yaml
services:
  bundle-server:
    url: http://localhost:8000
bundles:
  tenantA:
    service: bundle-server
    resource: /bundles/tenantA/bundle.tar.gz
    polling:
      min_delay_seconds: 10
      max_delay_seconds: 60
  tenantB:
    service: bundle-server
    resource: /bundles/tenantB/bundle.tar.gz
    polling:
      min_delay_seconds: 10
      max_delay_seconds: 60
```

- **Default OPA polling interval:** 60 seconds if not specified.
- Start OPA:
  ```bash
  opa run --server --config-file opa-config.yaml
  ```

### Other Common OPA Server Config Options

- `--server` : Run the REST API server.
- `--addr`   : Listen address (default `:8181`).
- `services` : Define bundle/log/status services.
- `bundles`  : List and configure bundles per tenant.
- `decision_logs`, `status`, `labels`, `plugins`, `default_decision`, etc.

For more, see [OPA Configuration Reference](https://www.openpolicyagent.org/docs/latest/configuration/).

---

## Testing Policies via API

**General API:**  
`POST /v1/data/tenants/{tenant}/{policy_type}/{module}/allow`

**Examples:**

### tenantA

#### RBAC
```bash
curl -X POST "http://localhost:8181/v1/data/tenants/tenantA/rbac/app1/allow" \
  -H "Content-Type: application/json" \
  -d '{"input": {"user": "alice", "action": "edit", "resource": "document"}}'
```
**Expected:** `{"result": true}`

#### ABAC
```bash
curl -X POST "http://localhost:8181/v1/data/tenants/tenantA/abac/finance/allow" \
  -H "Content-Type: application/json" \
  -d '{"input": {"user": {"department": "finance"}, "action": "read", "resource": {"department": "finance"}}}'
```
**Expected:** `{"result": true}`

#### ReBAC
```bash
curl -X POST "http://localhost:8181/v1/data/tenants/tenantA/rebac/project/allow" \
  -H "Content-Type: application/json" \
  -d '{"input": {"user": "alice", "action": "delete", "resource": "project-123"}}'
```
**Expected:** `{"result": true}`

---

### tenantB

#### RBAC
```bash
curl -X POST "http://localhost:8181/v1/data/tenants/tenantB/rbac/main/allow" \
  -H "Content-Type: application/json" \
  -d '{"input": {"user": "charlie", "action": "approve", "resource": "expense"}}'
```
**Expected:** `{"result": true}`

#### ABAC
```bash
curl -X POST "http://localhost:8181/v1/data/tenants/tenantB/abac/sales/allow" \
  -H "Content-Type: application/json" \
  -d '{"input": {"user": {"region": "us-west"}, "action": "view", "resource": {"department": "sales", "region": "us-west"}}}'
```
**Expected:** `{"result": true}`

#### ReBAC
```bash
curl -X POST "http://localhost:8181/v1/data/tenants/tenantB/rebac/invoice/allow" \
  -H "Content-Type: application/json" \
  -d '{"input": {"user": "charlie", "action": "update", "resource": "invoice-456"}}'
```
**Expected:** `{"result": true}`

---

## FastAPI Bundle Server Example

```python name=bundle_server/main.py
from fastapi import FastAPI, HTTPException
from fastapi.responses import FileResponse
from pathlib import Path

app = FastAPI(
    title="OPA Bundle Server",
    description="Simple server for serving OPA policy/data bundles.",
)

# Directory where bundles are stored
BUNDLES_ROOT = Path("./bundles")

@app.get("/bundles/{tenant}/{bundle_file}", response_class=FileResponse)
async def get_bundle(tenant: str, bundle_file: str):
    """
    Serve a policy/data bundle for a specific tenant.
    Example: /bundles/tenantA/bundle.tar.gz
    """
    bundle_path = BUNDLES_ROOT / tenant / bundle_file
    if not bundle_path.is_file():
        raise HTTPException(status_code=404, detail="Bundle not found")
    return FileResponse(bundle_path, filename=bundle_file, media_type="application/gzip")

@app.get("/")
def health():
    return {"status": "ok", "message": "OPA Bundle Server running"}
```

---

## requirements.txt for Bundle Server

```txt name=bundle_server/requirements.txt
fastapi
uvicorn
aiofiles
```

**Install with:**
```bash
pip install -r requirements.txt
```

**Run server:**
```bash
uvicorn bundle_server.main:app --reload --host 0.0.0.0 --port 8000
```

---

## Manifest.json Usage

The **manifest.json** file in an OPA bundle serves several important purposes:

- **Declares Bundle Roots:**  
  The `"roots"` key specifies the top-level keys in the data namespace (e.g., `policies`, `users`, `relationships`) that OPA should load or overwrite from the bundle. Only data and policies under these roots are considered part of the bundle. If omitted, OPA treats the entire bundle as a single root.

- **Versioning and Revision Tracking:**  
  The `"revision"` key lets you specify a version or revision string for the bundle (e.g., a commit SHA, date, or semantic version). OPA uses this in status and diagnostics, so you can track which bundle version is loaded.

- **Partial/Incremental Bundle Updates:**  
  If you have multiple bundles or want to update only portions of your OPA data/policy tree, specifying roots in `manifest.json` helps OPA know what to replace when a bundle is downloaded.

- **Required for Multi-bundle Setups:**  
  If you use multiple bundles or layer them (e.g., global and tenant-specific), OPA requires a manifest with explicit roots to avoid conflicts and correctly merge data.

**Example:**
```json
{
  "revision": "2025-05-22-1",
  "roots": ["policies", "users", "relationships"]
}
```

- [OPA Bundles: Manifest](https://www.openpolicyagent.org/docs/latest/management/#the-bundle-manifest)
- [OPA Bundles: Roots](https://www.openpolicyagent.org/docs/latest/management/#roots)

---

## Can Data Be Overridden via API?

**Yes, data can be overridden via the OPA REST API,** but with important caveats:

- **Manual Data Overriding:**  
  OPA exposes endpoints to read and write data at runtime:
  - `GET /v1/data/...` — Read data
  - `PUT /v1/data/{path}` — Replace or create data
  - `PATCH /v1/data/{path}` — Modify data
  - `DELETE /v1/data/{path}` — Delete data

  Example:
  ```bash
  curl -X PUT "http://localhost:8181/v1/data/tenants/tenantA/users" \
    -H "Content-Type: application/json" \
    -d '{"alice": {"department": "finance"}}'
  ```
  - This overrides the in-memory data for `tenants.tenantA.users`.
  - The change is **not persisted** after OPA restarts unless re-applied.

- **Bundles Take Precedence:**  
  If you load data via bundles, every time a new bundle is downloaded, it will **overwrite** the corresponding data roots (as specified in `manifest.json`) with what's in the bundle.  
  **Manual changes via the API will be lost** the next time the bundle is refreshed for that root.

- **Best Practice:**  
  - For dynamic, ephemeral, or test data: API writes are fine.
  - For production, multi-tenant, or managed systems: **Provide data via bundles** and treat the API as read-only for data, unless you explicitly want to allow ephemeral overrides.

- [OPA REST API: Data](https://www.openpolicyagent.org/docs/latest/rest-api/#data-api)
- [OPA Bundles](https://www.openpolicyagent.org/docs/latest/management/#bundles)

---

## References

- [OPA REST API](https://www.openpolicyagent.org/docs/latest/rest-api/)
- [OPA Bundles](https://www.openpolicyagent.org/docs/latest/management/#bundles)
- [OPA Configuration Reference](https://www.openpolicyagent.org/docs/latest/configuration/)
- [OPA Playground](https://play.openpolicyagent.org/)
- [FastAPI](https://fastapi.tiangolo.com/)

---

**Ready to go!**  
Use this guide to build, deploy, and test multi-tenant RBAC/ABAC/ReBAC policies with OPA.