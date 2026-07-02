[CmdletBinding(SupportsShouldProcess)]
param(
    [Parameter(Mandatory)][string]$ApplicationObjectId,
    [Parameter(Mandatory)][ValidateSet('Reader','AgentStatusAction','BillingChange')][string]$AppProfile
)
$manifestPath = Join-Path $PSScriptRoot "..\..\config\permissions\$($AppProfile.ToLower()).permissions.json"
Write-Host "TODO: Apply permission manifest for $AppProfile to application object $ApplicationObjectId"
Write-Host "Manifest path: $manifestPath"
