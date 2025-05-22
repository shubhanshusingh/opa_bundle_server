package tenants["tenantA"].rbac.app1

default allow = false

allow {
  input.user == "alice"
  input.action == "edit"
  input.resource == "document"
}