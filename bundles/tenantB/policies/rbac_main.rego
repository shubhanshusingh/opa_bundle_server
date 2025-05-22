package tenants.tenantB.rbac.main

default allow := false

allow if {
    input.user == "charlie"
    input.action == "approve"
    input.resource == "expense"
}