<#
.SYNOPSIS
    Validates and prepares the GitHub Actions runner for the Agent Compliance Community MOC.
.DESCRIPTION
    This script runs on GitHub-hosted runners or Azure Cloud Shell. It is not intended to install Microsoft modules on the end user's local client.
#>
[CmdletBinding()]
param(
    [string]$JsonOutputPath = 'data/processed/requirements/worker-requirements.json',
    [string]$MarkdownOutputPath = 'data/reports/00-worker-requirements.md',
    [switch]$SkipModuleInstall
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

Import-Module "$PSScriptRoot/../../common/GRC-Checks-Common.psm1" -Force

$results = @()
$results += New-GRCCheckResult -CheckId 'runner-os' -Name 'Runner operating system' -Passed $true -Message "Runner OS: $([System.Environment]::OSVersion.VersionString)" -Category 'Prerequisite'
$pwshOk = $PSVersionTable.PSVersion.Major -ge 7
$results += New-GRCCheckResult -CheckId 'pwsh-version' -Name 'PowerShell version' -Passed $pwshOk -Message "PowerShell version: $($PSVersionTable.PSVersion)" -Remediation 'Use GitHub windows-latest or a runner with PowerShell 7+.' -Severity $(if ($pwshOk) { 'Info' } else { 'High' }) -Category 'Prerequisite'

$requiredPaths = @(
    'common/GRC-Checks-Common.psm1',
    'common/GRC-M365-Common.psm1',
    'config/permissions/reader.permissions.json',
    'config/permissions/agent-status.permissions.json',
    'config/permissions/billing-change.permissions.json',
    'scripts/checks/Test-AppProfileAccess.ps1',
    'scripts/checks/Test-ReaderAccess.ps1',
    'scripts/checks/Test-StatusActionAccess.ps1',
    'scripts/checks/Test-BillingChangeAccess.ps1'
)

foreach ($path in $requiredPaths) {
    $exists = Test-Path $path
    $results += New-GRCCheckResult -CheckId "required-path-$($path.Replace('/','-').ToLowerInvariant())" -Name "Required repository path: $path" -Passed $exists -Message $(if ($exists) { 'Path exists.' } else { 'Path is missing.' }) -Remediation "Restore or create '$path'." -Severity $(if ($exists) { 'Info' } else { 'Critical' }) -Category 'Prerequisite'
}

$modules = @('Microsoft.Graph.Authentication','Microsoft.Graph.Applications','Microsoft.Graph.Reports','PSScriptAnalyzer')
foreach ($module in $modules) {
    $availableBefore = $null -ne (Get-Module -ListAvailable -Name $module | Select-Object -First 1)
    if (-not $availableBefore -and -not $SkipModuleInstall) {
        Install-Module -Name $module -Scope CurrentUser -Force -AllowClobber -ErrorAction Stop
    }
    $availableAfter = $null -ne (Get-Module -ListAvailable -Name $module | Select-Object -First 1)
    $results += New-GRCCheckResult -CheckId "module-$($module.ToLowerInvariant())" -Name "Runner module: $module" -Passed $availableAfter -Message $(if ($availableAfter) { 'Module is available on the runner.' } else { 'Module is not available on the runner.' }) -Remediation 'Modules are installed only on the runner or Cloud Shell, not on the local client.' -Severity $(if ($availableAfter) { 'Info' } else { 'High' }) -Category 'Prerequisite'
}

$exoAvailable = $null -ne (Get-Module -ListAvailable -Name ExchangeOnlineManagement | Select-Object -First 1)
$results += New-GRCCheckResult -CheckId 'exchange-module-not-required' -Name 'Exchange Online module is not required' -Passed $true -Message $(if ($exoAvailable) { 'ExchangeOnlineManagement is present on the runner but is not used by this MOC.' } else { 'ExchangeOnlineManagement is not installed and is not required.' }) -Category 'Prerequisite'

$manifestFiles = Get-ChildItem -Path 'config/permissions' -Filter '*.json' -ErrorAction SilentlyContinue
foreach ($manifestFile in $manifestFiles) {
    try {
        $manifest = Get-Content -Path $manifestFile.FullName -Raw | ConvertFrom-Json
        $exchangeExcluded = $manifest.includesExchangeOnline -eq $false
        $mailboxExcluded = $manifest.includesMailboxAccess -eq $false
        $permissionRows = @($manifest.permissions)
        $excludedPermissionText = @($permissionRows | Where-Object {
            $text = @($_.resource, $_.permission, $_.reason, $_.type) -join ' '
            $text -match '(?i)Exchange|Mailbox|Exchange\.ManageAsApp|EWS'
        })

        $results += New-GRCCheckResult -CheckId "manifest-exchange-excluded-$($manifestFile.BaseName.ToLowerInvariant())" -Name "Manifest excludes Exchange Online: $($manifestFile.Name)" -Passed $exchangeExcluded -Message $(if ($exchangeExcluded) { 'includesExchangeOnline is false.' } else { 'includesExchangeOnline is not false.' }) -Remediation 'Set includesExchangeOnline to false for all MOC profiles.' -Severity $(if ($exchangeExcluded) { 'Info' } else { 'Critical' }) -Category 'Permission'
        $results += New-GRCCheckResult -CheckId "manifest-mailbox-excluded-$($manifestFile.BaseName.ToLowerInvariant())" -Name "Manifest excludes mailbox access: $($manifestFile.Name)" -Passed $mailboxExcluded -Message $(if ($mailboxExcluded) { 'includesMailboxAccess is false.' } else { 'includesMailboxAccess is not false.' }) -Remediation 'Set includesMailboxAccess to false for all MOC profiles.' -Severity $(if ($mailboxExcluded) { 'Info' } else { 'Critical' }) -Category 'Permission'
        $results += New-GRCCheckResult -CheckId "manifest-no-excluded-permission-text-$($manifestFile.BaseName.ToLowerInvariant())" -Name "Permission rows exclude Exchange/Mailbox/EWS: $($manifestFile.Name)" -Passed ($excludedPermissionText.Count -eq 0) -Message $(if ($excludedPermissionText.Count -eq 0) { 'Permission rows contain no excluded workload references.' } else { "Permission rows contain $($excludedPermissionText.Count) excluded workload reference(s)." }) -Remediation 'Remove excluded workload references from permission rows.' -Severity $(if ($excludedPermissionText.Count -eq 0) { 'Info' } else { 'Critical' }) -Category 'Permission'
    }
    catch {
        $results += New-GRCCheckResult -CheckId "manifest-parse-$($manifestFile.BaseName.ToLowerInvariant())" -Name "Permission manifest parses: $($manifestFile.Name)" -Passed $false -Message $_.Exception.Message -Remediation 'Fix the JSON syntax in the permission manifest.' -Severity 'Critical' -Category 'Permission'
    }
}

try {
    Import-Module PSScriptAnalyzer -ErrorAction Stop
        $analyzerResults = @()
    foreach ($analyzerPath in @('./scripts','./common')) {
        if (Test-Path $analyzerPath) {
            $analyzerResults += @(Invoke-ScriptAnalyzer -Path $analyzerPath -Recurse -Severity Error -ExcludeRule 'PSAvoidUsingConvertToSecureStringWithPlainText')
        }
    }
    $results += New-GRCCheckResult -CheckId 'psscriptanalyzer-errors' -Name 'PSScriptAnalyzer errors' -Passed ($analyzerResults.Count -eq 0) -Message "PSScriptAnalyzer error count: $($analyzerResults.Count)" -Remediation 'Fix PowerShell analyzer errors before running productive checks.' -Severity $(if ($analyzerResults.Count -eq 0) { 'Info' } else { 'High' }) -Category 'Prerequisite'
}
catch {
    $results += New-GRCCheckResult -CheckId 'psscriptanalyzer-execution' -Name 'PSScriptAnalyzer execution' -Passed $false -Message $_.Exception.Message -Remediation 'Ensure PSScriptAnalyzer can be installed on the runner.' -Severity 'High' -Category 'Prerequisite'
}

Export-GRCCheckResult -Results $results -Path $JsonOutputPath
Export-GRCCheckSummaryMarkdown -Results $results -Path $MarkdownOutputPath -Title '00 - Worker Requirements'

$failedCritical = @($results | Where-Object { -not $_.passed -and $_.severity -in @('High','Critical') })
if ($failedCritical.Count -gt 0) {
    Write-Error "Worker requirements failed with $($failedCritical.Count) high or critical issue(s)."
}

Write-Host "Wrote $JsonOutputPath"
Write-Host "Wrote $MarkdownOutputPath"

