[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$TenantIdOrDomain,
    [Parameter(Mandatory)][string]$ClientId
)
"https://login.microsoftonline.com/$TenantIdOrDomain/adminconsent?client_id=$ClientId"
