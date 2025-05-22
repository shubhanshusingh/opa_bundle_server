package tenants.tenantA.abac.finance

default allow := false

allow if {
	input.user.department == "finance"
	input.action == "read"
	input.resource.department == "finance"
}
