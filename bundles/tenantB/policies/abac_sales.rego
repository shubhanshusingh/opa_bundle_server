package tenants.tenantB.abac.sales

default allow := false

allow if {
    input.user.region == input.resource.region
    input.action == "view"
    input.resource.department == "sales"
}