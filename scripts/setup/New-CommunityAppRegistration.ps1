[CmdletBinding(SupportsShouldProcess)]
param(
    [Parameter(Mandatory)][ValidateSet('Reader','AgentStatusAction','BillingChange')][string]$AppProfile,
    [Parameter(Mandatory)][string]$DisplayName
)
# This script is intended for Azure Cloud Shell or GitHub runner with delegated bootstrap credentials.
# Exchange Online permissions are intentionally excluded.
if ($PSCmdlet.ShouldProcess($DisplayName, 'Create Entra App Registration')) {
    Write-Host "TODO: Create app registration for profile $AppProfile named $DisplayName"
}
