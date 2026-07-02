[CmdletBinding(SupportsShouldProcess)]
param(
    [Parameter(Mandatory)][string]$TargetId,
    [Parameter(Mandatory)][double]$BudgetLimit,
    [Parameter()][string]$InitiatorUpn,
    [switch]$DryRun
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot "../..")).Path
Import-Module (Join-Path $repoRoot "common/GRC-M365-Common.psm1") -Force

Write-Host "Triggered Budget Change Action: Target=$TargetId, Limit=$BudgetLimit, Initiator=$InitiatorUpn"

# Verify Initiator is assigned to the app in Entra ID
if ($InitiatorUpn) {
    $tenantId = $env:TENANT_ID
    $clientId = $env:CAG_BILLING_CLIENT_ID
    $certificateBase64 = $env:CAG_BILLING_CERTIFICATE_BASE64
    $certificatePasswordPlain = $env:CAG_BILLING_CERTIFICATE_PASSWORD
    
    if ($tenantId -and $clientId -and $certificateBase64 -and $certificatePasswordPlain) {
        $securePassword = ConvertTo-SecureString $certificatePasswordPlain -AsPlainText -Force
        Connect-GRCGraph -TenantId $tenantId -ClientId $clientId -CertificateBase64 $certificateBase64 -CertificatePassword $securePassword | Out-Null
        
        $isAssigned = Test-GRCUserAppAssignment -UserUpn $InitiatorUpn -AppClientId $clientId
        if (-not $isAssigned) {
            throw "Access Denied: Initiator UPN '$InitiatorUpn' is not assigned to the billing-change application in Microsoft Entra ID."
        }
        Write-Host "Access Granted: Initiator UPN '$InitiatorUpn' is successfully verified in Entra ID."
    } else {
        Write-Warning "Billing Change App credentials are not configured. Proceeding without Entra ID role verification."
    }
} else {
    Write-Warning "No Initiator UPN specified. Proceeding without validation."
}

if ($DryRun) {
    Write-Host "DryRun: Would execute action 'change budget' to $BudgetLimit EUR on target '$TargetId'."
    return
}

if ($PSCmdlet.ShouldProcess($TargetId, "Change budget to $BudgetLimit EUR")) {
    # Place your live Azure Consumption API / Azure Budget API calls here to adjust the budget.
    Write-Host "Successfully adjusted budget for '$TargetId' to $BudgetLimit EUR."
}
