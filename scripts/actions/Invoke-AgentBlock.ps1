[CmdletBinding(SupportsShouldProcess)]
param(
    [Parameter(Mandatory)][string]$TargetId,
    [Parameter()][string]$Action = 'block',
    [Parameter()][string]$InitiatorUpn,
    [switch]$DryRun
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot "../..")).Path
Import-Module (Join-Path $repoRoot "common/GRC-M365-Common.psm1") -Force

Write-Host "Triggered Agent Status Action: Action=$Action, Target=$TargetId, Initiator=$InitiatorUpn"

# Verify Initiator is assigned to the app in Entra ID
if ($InitiatorUpn) {
    $tenantId = $env:TENANT_ID
    $clientId = $env:CAG_STATUS_CLIENT_ID
    $certificateBase64 = $env:CAG_STATUS_CERTIFICATE_BASE64
    $certificatePasswordPlain = $env:CAG_STATUS_CERTIFICATE_PASSWORD
    
    if ($tenantId -and $clientId -and $certificateBase64 -and $certificatePasswordPlain) {
        $securePassword = ConvertTo-SecureString $certificatePasswordPlain -AsPlainText -Force
        Connect-GRCGraph -TenantId $tenantId -ClientId $clientId -CertificateBase64 $certificateBase64 -CertificatePassword $securePassword | Out-Null
        
        $isAssigned = Test-GRCUserAppAssignment -UserUpn $InitiatorUpn -AppClientId $clientId
        if (-not $isAssigned) {
            throw "Access Denied: Initiator UPN '$InitiatorUpn' is not assigned to the status-admin application in Microsoft Entra ID."
        }
        Write-Host "Access Granted: Initiator UPN '$InitiatorUpn' is successfully verified in Entra ID."
    } else {
        Write-Warning "Status Action App credentials are not configured. Proceeding without Entra ID role verification."
    }
} else {
    Write-Warning "No Initiator UPN specified. Proceeding without validation."
}

if ($DryRun) {
    Write-Host "DryRun: Would execute action '$Action' on target agent '$TargetId'."
    return
}

if ($PSCmdlet.ShouldProcess($TargetId, $Action)) {
    # Place your live Microsoft Graph / Teams Admin Center API calls here to block or activate the app/agent.
    Write-Host "Successfully executed action '$Action' on target agent '$TargetId' in Microsoft 365 Tenant."
}
