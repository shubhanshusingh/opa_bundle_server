package tenants.tenantB.rebac.invoice

default allow := false

allow if {
    data.tenants.tenantB.relationships[input.user][input.resource] == "editor"
    input.action == "update"
}