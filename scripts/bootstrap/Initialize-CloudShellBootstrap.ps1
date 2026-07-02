<#
.SYNOPSIS
    Creates the three mandatory Entra app profiles for the Agent Compliance Community MOC.
.DESCRIPTION
    Intended for Azure Cloud Shell or another controlled admin shell, not for an unmanaged end-user device.
    No Exchange Online permissions are requested.
#>
[CmdletBinding(SupportsShouldProcess)]
param(
    [Parameter(Mandatory)][string]$TenantId,
    [Parameter(Mandatory)][string]$TenantDomain,
    [Parameter(Mandatory)][string]$GitHubOwner,
    [Parameter(Mandatory)][string]$GitHubRepository,
    [Parameter(Mandatory)][string]$AuthorizedReaderUpn,
    [Parameter(Mandatory)][string]$AuthorizedStatusAdminUpn,
    [Parameter(Mandatory)][string]$AuthorizedChangeAdminUpn,
    [Parameter(Mandatory)][string]$NotificationMail,
    [switch]$DryRun
)

Write-Host 'Agent Compliance Cloud Shell Bootstrap'
Write-Host 'This scaffold intentionally excludes Exchange Online permissions.'
Write-Host "Tenant: $TenantId / $TenantDomain"
Write-Host "Repository: $GitHubOwner/$GitHubRepository"
Write-Host "Reader UPN: $AuthorizedReaderUpn"
Write-Host "Status Admin UPN: $AuthorizedStatusAdminUpn"
Write-Host "Change Admin UPN: $AuthorizedChangeAdminUpn"

if ($DryRun) {
    Write-Host 'DryRun mode enabled. No changes will be applied.'
    return
}

Write-Warning 'Implementation placeholder: create Reader, Status Action and Billing Change apps, assign permissions, create certificates, write GitHub secrets.'
Write-Warning 'Next iteration should wire this to Microsoft Graph and GitHub REST endpoints.'
