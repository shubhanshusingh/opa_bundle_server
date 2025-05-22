from fastapi import FastAPI, HTTPException
from fastapi.responses import FileResponse
from pathlib import Path

app = FastAPI(
    title="OPA Bundle Server",
    description="Simple server for serving OPA policy/data bundles.",
)

# Directory where bundles are stored (e.g., ./bundles/tenantA/bundle.tar.gz)
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