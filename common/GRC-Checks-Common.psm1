Set-StrictMode -Version Latest

function New-GRCCheckResult {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$CheckId,
        [Parameter(Mandatory)][string]$Name,
        [Parameter(Mandatory)][bool]$Passed,
        [string]$Message = '',
        [string]$Remediation = '',
        [ValidateSet('Info','Low','Medium','High','Critical')][string]$Severity = 'Info',
        [ValidateSet('Prerequisite','Authentication','Permission','Collector','Action','Reporting','Configuration')][string]$Category = 'Configuration',
        [hashtable]$Data = @{}
    )

    [pscustomobject]@{
        checkId     = $CheckId
        name        = $Name
        category    = $Category
        status      = if ($Passed) { 'passed' } else { 'failed' }
        passed      = $Passed
        message     = $Message
        remediation = $Remediation
        severity    = $Severity
        data        = $Data
        timestamp   = (Get-Date).ToUniversalTime().ToString('o')
    }
}

function Test-GRCRequiredValue {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$Name,
        [AllowNull()][AllowEmptyString()][string]$Value,
        [string]$Remediation = "Set the required value '$Name' as a repository variable, secret or workflow input."
    )

    $hasValue = -not [string]::IsNullOrWhiteSpace($Value)
    New-GRCCheckResult `
        -CheckId "required-value-$($Name.ToLowerInvariant())" `
        -Name "Required value: $Name" `
        -Passed $hasValue `
        -Message $(if ($hasValue) { "Value '$Name' is present." } else { "Value '$Name' is missing." }) `
        -Remediation $(if ($hasValue) { '' } else { $Remediation }) `
        -Severity $(if ($hasValue) { 'Info' } else { 'High' }) `
        -Category 'Configuration'
}

function Export-GRCCheckResult {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][object[]]$Results,
        [Parameter(Mandatory)][string]$Path
    )

    $dir = Split-Path -Parent $Path
    if ($dir -and -not (Test-Path $dir)) {
        New-Item -ItemType Directory -Path $dir -Force | Out-Null
    }

    $Results | ConvertTo-Json -Depth 30 | Set-Content -Path $Path -Encoding UTF8
}

function Export-GRCCheckSummaryMarkdown {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][object[]]$Results,
        [Parameter(Mandatory)][string]$Path,
        [string]$Title = 'Agent Compliance Check Summary'
    )

    $dir = Split-Path -Parent $Path
    if ($dir -and -not (Test-Path $dir)) {
        New-Item -ItemType Directory -Path $dir -Force | Out-Null
    }

    $passed = @($Results | Where-Object { $_.passed }).Count
    $failed = @($Results | Where-Object { -not $_.passed }).Count
    $total = @($Results).Count

    $lines = New-Object System.Collections.Generic.List[string]
    $lines.Add("# $Title")
    $lines.Add('')
    $lines.Add("Generated: $((Get-Date).ToUniversalTime().ToString('o'))")
    $lines.Add('')
    $lines.Add("Total: **$total** | Passed: **$passed** | Failed: **$failed**")
    $lines.Add('')
    $lines.Add('| Status | Severity | Category | Check | Message | Remediation |')
    $lines.Add('|---|---|---|---|---|---|')

    foreach ($result in $Results) {
        $statusIcon = if ($result.passed) { '✅' } else { '❌' }
        $message = ($result.message -replace '\|','/' -replace "`r?`n", ' ')
        $remediation = ($result.remediation -replace '\|','/' -replace "`r?`n", ' ')
        $lines.Add("| $statusIcon | $($result.severity) | $($result.category) | $($result.name) | $message | $remediation |")
    }

    $lines | Set-Content -Path $Path -Encoding UTF8
}

Export-ModuleMember -Function New-GRCCheckResult, Test-GRCRequiredValue, Export-GRCCheckResult, Export-GRCCheckSummaryMarkdown
