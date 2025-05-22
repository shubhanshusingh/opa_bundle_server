package tenants["tenantA"].rebac.project

default allow = false

allow {
  data.tenants["tenantA"].relationships[input.user][input.resource] == "owner"
  input.action == "delete"
}