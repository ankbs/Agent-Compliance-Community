<#
.SYNOPSIS
    Validates one mandatory app profile for the Agent Compliance Community MOC.
.DESCRIPTION
    This script checks repository variables, GitHub secrets presence and permission manifest policy for
    Reader, Agent Status Action or Billing Change app profiles. It does not print secret values and does
    not execute destructive actions.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [ValidateSet('Reader','AgentStatusAction','BillingChange')]
    [string]$AppProfile,

    [string]$OutputPath = '',

    [switch]$SkipCertificateSecretChecks
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repositoryRoot = (Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
Import-Module (Join-Path $repositoryRoot 'common/GRC-Checks-Common.psm1') -Force
Import-Module (Join-Path $repositoryRoot 'common/GRC-M365-Common.psm1') -Force

function Get-GRCEnvironmentValue {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$Name
    )

    [Environment]::GetEnvironmentVariable($Name)
}

function Test-GRCBootstrapValue {
    [CmdletBinding()]
    param([string]$Name,[AllowNull()][AllowEmptyString()][string]$Value,[string]$Remediation,[switch]$InitialMode)
    $hasValue = -not [string]::IsNullOrWhiteSpace($Value)
    if ($hasValue) { return New-GRCCheckResult -CheckId "bootstrap-value-$($Name.ToLowerInvariant())" -Name "Bootstrap value: $Name" -Passed $true -Message "Value '$Name' is present." -Severity 'Info' -Category 'Configuration' }
    if ($InitialMode) { return New-GRCCheckResult -CheckId "bootstrap-value-pending-$($Name.ToLowerInvariant())" -Name "Bootstrap value pending: $Name" -Passed $true -Message "Value '$Name' is not present yet. This is expected during the initial bootstrap test before Entra app registration." -Remediation $Remediation -Severity 'Medium' -Category 'Configuration' }
    return New-GRCCheckResult -CheckId "bootstrap-value-required-$($Name.ToLowerInvariant())" -Name "Bootstrap value required: $Name" -Passed $false -Message "Value '$Name' is missing." -Remediation $Remediation -Severity 'High' -Category 'Configuration'
}
function Test-GRCPermissionText {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]$Permission
    )

    $text = @(
        $Permission.resource,
        $Permission.permission,
        $Permission.reason,
        $Permission.type
    ) -join ' '

    return ($text -notmatch '(?i)Exchange|Mailbox|Exchange\.ManageAsApp|EWS')
}

$profileConfig = switch ($AppProfile) {
    'Reader' {
        [pscustomobject]@{
            OutputName = 'reader'
            ClientIdEnv = 'CAG_READER_CLIENT_ID'
            CertificateBase64Env = 'CAG_READER_CERTIFICATE_BASE64'
            CertificatePasswordEnv = 'CAG_READER_CERTIFICATE_PASSWORD'
            AuthorizedUpnEnv = 'AUTHORIZED_READER_UPN'
            AuthorizedUpnLabel = 'Reader UPN'
        }
    }
    'AgentStatusAction' {
        [pscustomobject]@{
            OutputName = 'agent-status-action'
            ClientIdEnv = 'CAG_STATUS_CLIENT_ID'
            CertificateBase64Env = 'CAG_STATUS_CERTIFICATE_BASE64'
            CertificatePasswordEnv = 'CAG_STATUS_CERTIFICATE_PASSWORD'
            AuthorizedUpnEnv = 'AUTHORIZED_STATUS_ADMIN_UPN'
            AuthorizedUpnLabel = 'Status Admin UPN'
        }
    }
    'BillingChange' {
        [pscustomobject]@{
            OutputName = 'billing-change'
            ClientIdEnv = 'CAG_BILLING_CLIENT_ID'
            CertificateBase64Env = 'CAG_BILLING_CERTIFICATE_BASE64'
            CertificatePasswordEnv = 'CAG_BILLING_CERTIFICATE_PASSWORD'
            AuthorizedUpnEnv = 'AUTHORIZED_CHANGE_ADMIN_UPN'
            AuthorizedUpnLabel = 'Change Admin UPN'
        }
    }
}

if ([string]::IsNullOrWhiteSpace($OutputPath)) {
    $OutputPath = "data/processed/permission-checks/$($profileConfig.OutputName).json"
}

$markdownPath = $OutputPath -replace '\.json$', '.md'
$markdownPath = $markdownPath -replace 'data/processed', 'data/reports'

$results = @()

$tenantId = Get-GRCEnvironmentValue -Name 'TENANT_ID'
$tenantDomain = Get-GRCEnvironmentValue -Name 'TENANT_DOMAIN'
$authorizedUpn = Get-GRCEnvironmentValue -Name $profileConfig.AuthorizedUpnEnv
$clientId = Get-GRCEnvironmentValue -Name $profileConfig.ClientIdEnv
$certificateBase64 = Get-GRCEnvironmentValue -Name $profileConfig.CertificateBase64Env
$certificatePassword = Get-GRCEnvironmentValue -Name $profileConfig.CertificatePasswordEnv

$results += Test-GRCRequiredValue -Name 'TENANT_ID' -Value $tenantId -Remediation 'Set TENANT_ID as a repository variable before running permission checks.'
$results += Test-GRCRequiredValue -Name 'TENANT_DOMAIN' -Value $tenantDomain -Remediation 'Set TENANT_DOMAIN as a repository variable before running permission checks.'
$results += Test-GRCRequiredValue -Name $profileConfig.AuthorizedUpnEnv -Value $authorizedUpn -Remediation "Set $($profileConfig.AuthorizedUpnEnv) as a repository variable. This value represents the $($profileConfig.AuthorizedUpnLabel) for governance and approvals."

if (-not $SkipCertificateSecretChecks) {
    $results += Test-GRCBootstrapValue -Name $profileConfig.ClientIdEnv -Value $clientId -InitialMode:$SkipCertificateSecretChecks -Remediation "Set this value after Entra app registration bootstrap."
    $results += Test-GRCBootstrapValue -Name $profileConfig.CertificateBase64Env -Value $certificateBase64 -InitialMode:$SkipCertificateSecretChecks -Remediation "Set this value after certificate bootstrap."
    $results += Test-GRCBootstrapValue -Name $profileConfig.CertificatePasswordEnv -Value $certificatePassword -InitialMode:$SkipCertificateSecretChecks -Remediation "Set this value after certificate bootstrap."
}
else {
    $results += New-GRCCheckResult -CheckId "app-bootstrap-values-skipped-$($profileConfig.OutputName)" -Name 'App bootstrap values skipped' -Passed $true -Message "Client ID and certificate secret checks were skipped for the initial configuration test. Create the $AppProfile app registration before live API probes." -Severity 'Medium' -Category 'Configuration'
}

try {
    $manifest = Get-GRCPermissionManifest -AppProfile $AppProfile -RepositoryRoot $repositoryRoot
    $results += New-GRCCheckResult -CheckId "manifest-load-$($profileConfig.OutputName)" -Name "Permission manifest loads: $AppProfile" -Passed $true -Message "Loaded permission manifest for app profile '$AppProfile'." -Category 'Permission' -Data @{ permissionCount = @($manifest.permissions).Count }

    $profileMatches = $manifest.appProfile -eq $AppProfile
    $results += New-GRCCheckResult -CheckId "manifest-profile-match-$($profileConfig.OutputName)" -Name 'Manifest app profile matches workflow profile' -Passed $profileMatches -Message $(if ($profileMatches) { 'Manifest profile matches.' } else { "Manifest profile '$($manifest.appProfile)' does not match '$AppProfile'." }) -Remediation 'Correct the appProfile property in the permission manifest.' -Severity $(if ($profileMatches) { 'Info' } else { 'High' }) -Category 'Permission'

    $exchangeExcluded = ($manifest.includesExchangeOnline -eq $false)
    $results += New-GRCCheckResult -CheckId "manifest-exchange-excluded-$($profileConfig.OutputName)" -Name 'Exchange Online excluded' -Passed $exchangeExcluded -Message $(if ($exchangeExcluded) { 'Manifest explicitly excludes Exchange Online.' } else { 'Manifest does not explicitly exclude Exchange Online.' }) -Remediation 'Set includesExchangeOnline to false and remove Exchange-related permissions from the MOC profile.' -Severity $(if ($exchangeExcluded) { 'Info' } else { 'Critical' }) -Category 'Permission'

    $mailboxExcluded = ($manifest.includesMailboxAccess -eq $false)
    $results += New-GRCCheckResult -CheckId "manifest-mailbox-excluded-$($profileConfig.OutputName)" -Name 'Mailbox access excluded' -Passed $mailboxExcluded -Message $(if ($mailboxExcluded) { 'Manifest explicitly excludes mailbox access.' } else { 'Manifest does not explicitly exclude mailbox access.' }) -Remediation 'Set includesMailboxAccess to false and remove mailbox-related permissions from the MOC profile.' -Severity $(if ($mailboxExcluded) { 'Info' } else { 'Critical' }) -Category 'Permission'

    $permissionRows = @($manifest.permissions)
    $hasPermissions = $permissionRows.Count -gt 0
    $results += New-GRCCheckResult -CheckId "manifest-permissions-present-$($profileConfig.OutputName)" -Name 'Manifest contains permission rows' -Passed $hasPermissions -Message "Permission rows: $($permissionRows.Count)." -Remediation 'Add at least one permission row to the app profile manifest.' -Severity $(if ($hasPermissions) { 'Info' } else { 'High' }) -Category 'Permission'

    $excludedRows = @($permissionRows | Where-Object { -not (Test-GRCPermissionText -Permission $_) })
    $noExcludedRows = $excludedRows.Count -eq 0
    $results += New-GRCCheckResult -CheckId "manifest-no-exchange-permission-text-$($profileConfig.OutputName)" -Name 'Permission rows contain no Exchange/Mailbox/EWS permissions' -Passed $noExcludedRows -Message $(if ($noExcludedRows) { 'No excluded workload permission text found in permission rows.' } else { "Excluded workload text found in $($excludedRows.Count) permission row(s)." }) -Remediation 'Remove Exchange, mailbox, Exchange.ManageAsApp or EWS permission references from the permission rows.' -Severity $(if ($noExcludedRows) { 'Info' } else { 'Critical' }) -Category 'Permission'

    $placeholderRows = @($permissionRows | Where-Object { $_.permission -match '(?i)Placeholder' })
    $results += New-GRCCheckResult -CheckId "manifest-placeholder-tracking-$($profileConfig.OutputName)" -Name 'Placeholder permissions tracked' -Passed ($placeholderRows.Count -eq 0) -Message $(if ($placeholderRows.Count -eq 0) { 'No placeholder permissions in this manifest.' } else { "Placeholder permissions present: $($placeholderRows.Count). These must be replaced before live write/API probes." }) -Remediation 'Replace placeholders with validated Microsoft API permissions when the relevant endpoint is confirmed.' -Severity $(if ($placeholderRows.Count -eq 0) { 'Info' } else { 'Medium' }) -Category 'Permission' -Data @{ placeholderCount = $placeholderRows.Count }

    if ($AppProfile -eq 'Reader') {
        $destructiveExcluded = ($manifest.includesDestructiveActions -eq $false)
        $results += New-GRCCheckResult -CheckId 'reader-no-destructive-actions' -Name 'Reader profile has no destructive actions' -Passed $destructiveExcluded -Message $(if ($destructiveExcluded) { 'Reader profile is read-only.' } else { 'Reader profile is not marked as read-only.' }) -Remediation 'Set includesDestructiveActions to false for the Reader profile.' -Severity $(if ($destructiveExcluded) { 'Info' } else { 'Critical' }) -Category 'Permission'
    }

    if ($AppProfile -eq 'AgentStatusAction') {
        $budgetChangeExcluded = ($manifest.includesBudgetChange -eq $false)
        $approvalRequired = ($manifest.requiresManualApproval -eq $true)
        $results += New-GRCCheckResult -CheckId 'status-no-budget-change' -Name 'Status Action profile cannot change billing budgets' -Passed $budgetChangeExcluded -Message $(if ($budgetChangeExcluded) { 'Status actions are isolated from billing and budget changes.' } else { 'Status Action profile is allowed to change budget values.' }) -Remediation 'Set includesBudgetChange to false for AgentStatusAction.' -Severity $(if ($budgetChangeExcluded) { 'Info' } else { 'Critical' }) -Category 'Permission'
        $results += New-GRCCheckResult -CheckId 'status-manual-approval-required' -Name 'Status Action profile requires manual approval' -Passed $approvalRequired -Message $(if ($approvalRequired) { 'Manual approval is required.' } else { 'Manual approval is not required.' }) -Remediation 'Set requiresManualApproval to true for AgentStatusAction.' -Severity $(if ($approvalRequired) { 'Info' } else { 'High' }) -Category 'Action'
    }

    if ($AppProfile -eq 'BillingChange') {
        $budgetChangeIncluded = ($manifest.includesBudgetChange -eq $true)
        $approvalRequired = ($manifest.requiresManualApproval -eq $true)
        $dryRunRequired = ($manifest.requiresDryRun -eq $true)
        $results += New-GRCCheckResult -CheckId 'billing-change-mandatory-profile' -Name 'Billing Change profile is part of the MOC' -Passed $true -Message 'Billing Change App is mandatory in this MOC and protected by approval and audit controls.' -Category 'Configuration'
        $results += New-GRCCheckResult -CheckId 'billing-budget-change-marked' -Name 'Billing profile is marked for budget/billing changes' -Passed $budgetChangeIncluded -Message $(if ($budgetChangeIncluded) { 'Billing profile is correctly marked for billing and budget changes.' } else { 'Billing profile is not marked for budget/billing changes.' }) -Remediation 'Set includesBudgetChange to true for BillingChange.' -Severity $(if ($budgetChangeIncluded) { 'Info' } else { 'High' }) -Category 'Permission'
        $results += New-GRCCheckResult -CheckId 'billing-manual-approval-required' -Name 'Billing profile requires manual approval' -Passed $approvalRequired -Message $(if ($approvalRequired) { 'Manual approval is required.' } else { 'Manual approval is not required.' }) -Remediation 'Set requiresManualApproval to true for BillingChange.' -Severity $(if ($approvalRequired) { 'Info' } else { 'High' }) -Category 'Action'
        $results += New-GRCCheckResult -CheckId 'billing-dry-run-required' -Name 'Billing profile requires dry-run' -Passed $dryRunRequired -Message $(if ($dryRunRequired) { 'Dry-run is required before changes.' } else { 'Dry-run is not required.' }) -Remediation 'Set requiresDryRun to true for BillingChange.' -Severity $(if ($dryRunRequired) { 'Info' } else { 'High' }) -Category 'Action'
    }
}
catch {
    $results += New-GRCCheckResult -CheckId "manifest-load-$($profileConfig.OutputName)" -Name "Permission manifest loads: $AppProfile" -Passed $false -Message $_.Exception.Message -Remediation 'Fix permission manifest path or JSON syntax.' -Severity 'Critical' -Category 'Permission'
}

Export-GRCCheckResult -Results $results -Path $OutputPath
Export-GRCCheckSummaryMarkdown -Results $results -Path $markdownPath -Title "$AppProfile App Access Checks"

$failedHighOrCritical = @($results | Where-Object { -not $_.passed -and $_.severity -in @('High','Critical') })
if ($failedHighOrCritical.Count -gt 0) {
    Write-Error "$AppProfile access checks failed with $($failedHighOrCritical.Count) high or critical issue(s)."
}

Write-Host "Wrote $OutputPath"
Write-Host "Wrote $markdownPath"

