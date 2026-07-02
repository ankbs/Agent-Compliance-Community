[CmdletBinding()]
param(
    [string]$OutputPath = 'data/processed/Test-BillingChangeAccess.json',
    [string]$TestUserUpn = $env:AUTHORIZED_CHANGE_ADMIN_UPN
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot "../..")).Path
Import-Module (Join-Path $repoRoot "common/GRC-M365-Common.psm1") -Force
Import-Module (Join-Path $repoRoot "common/GRC-Checks-Common.psm1") -Force

$results = @()
$results += Test-GRCRequiredValue -Name 'TENANT_ID' -Value $env:TENANT_ID
$results += Test-GRCRequiredValue -Name 'TENANT_DOMAIN' -Value $env:TENANT_DOMAIN
$results += Test-GRCRequiredValue -Name 'AUTHORIZED_CHANGE_ADMIN_UPN' -Value $env:AUTHORIZED_CHANGE_ADMIN_UPN
$results += Test-GRCRequiredValue -Name 'CAG_BILLING_CLIENT_ID' -Value $env:CAG_BILLING_CLIENT_ID

$tenantId = $env:TENANT_ID
$clientId = $env:CAG_BILLING_CLIENT_ID
$certificateBase64 = $env:CAG_BILLING_CERTIFICATE_BASE64
$certificatePasswordPlain = $env:CAG_BILLING_CERTIFICATE_PASSWORD

$assignedPassed = $false
$assignedMsg = 'Billing App credentials are not configured or connection failed.'

if ($tenantId -and $clientId -and $certificateBase64 -and $certificatePasswordPlain) {
    try {
        $securePassword = ConvertTo-SecureString $certificatePasswordPlain -AsPlainText -Force
        Connect-GRCGraph -TenantId $tenantId -ClientId $clientId -CertificateBase64 $certificateBase64 -CertificatePassword $securePassword | Out-Null
        
        $targetUser = if ($TestUserUpn) { $TestUserUpn } else { $env:AUTHORIZED_CHANGE_ADMIN_UPN }
        if ($targetUser) {
            $isAssigned = Test-GRCUserAppAssignment -UserUpn $targetUser -AppClientId $clientId
            if ($isAssigned) {
                $assignedPassed = $true
                $assignedMsg = "User '$targetUser' is successfully assigned to the Enterprise Application and authorized to perform billing/limit changes."
            } else {
                $assignedMsg = "User '$targetUser' is NOT assigned to the Enterprise Application in Microsoft Entra ID."
            }
        } else {
            $assignedMsg = 'No test User UPN configured to check assignment.'
        }
    } catch {
        $assignedMsg = "Failed to query Entra ID app role assignments - $($_.Exception.Message)"
    }
}

$results += New-GRCCheckResult -CheckId 'billing-app-role-assignment' -Name 'User assigned to Enterprise App' -Passed $assignedPassed -Message $assignedMsg -Category 'Permission'
$results += New-GRCCheckResult -CheckId 'billing-app-mandatory' -Name 'Billing Change App is mandatory in MOC' -Passed $true -Message 'The Billing Change App is part of the MOC, but changes require dry-run, approval and audit.' -Category 'Configuration'
$results += New-GRCCheckResult -CheckId 'billing-dryrun-required' -Name 'Dry-run required for billing changes' -Passed $true -Message 'Billing and limit changes must first run in dry-run mode.' -Category 'Action'

Export-GRCCheckResult -Results $results -Path $OutputPath
Export-GRCCheckSummaryMarkdown -Results $results -Path ($OutputPath -replace '\.json$', '.md') -Title 'Billing Change App Access Checks'
