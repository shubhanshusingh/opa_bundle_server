package tenants.tenantA.rbac.app1

default allow := false

allow if {
	input.user == "alice"
	input.action == "edit"
	input.resource == "document"
}
