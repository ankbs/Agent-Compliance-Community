[CmdletBinding()]
param(
    [string]$OutputPath = "data/raw/CopilotUsageReport.json"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$dir = Split-Path -Parent $OutputPath
if ($dir -and -not (Test-Path $dir)) {
    New-Item -ItemType Directory -Path $dir -Force | Out-Null
}

$result = [pscustomobject]@{
    collector = "Microsoft 365 Copilot Usage Report"
    status = "preview"
    generatedAt = (Get-Date).ToUniversalTime().ToString("o")
    note = "Preview dataset. Live API integration for this collector is tracked separately."
    data = @()
}

$result | ConvertTo-Json -Depth 30 | Set-Content -Path $OutputPath -Encoding UTF8
Write-Host "Wrote $OutputPath"
