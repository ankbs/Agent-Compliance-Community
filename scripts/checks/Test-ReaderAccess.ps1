[CmdletBinding()]
param(
    [string]$OutputPath = 'data/processed/Test-ReaderAccess.json'
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

Import-Module "$PSScriptRoot/../../common/GRC-Checks-Common.psm1" -Force

$results = @()
$results += Test-GRCRequiredValue -Name 'TENANT_ID' -Value $env:TENANT_ID
$results += Test-GRCRequiredValue -Name 'TENANT_DOMAIN' -Value $env:TENANT_DOMAIN
$results += Test-GRCRequiredValue -Name 'AUTHORIZED_READER_UPN' -Value $env:AUTHORIZED_READER_UPN
$results += Test-GRCRequiredValue -Name 'CAG_READER_CLIENT_ID' -Value $env:CAG_READER_CLIENT_ID
$results += New-GRCCheckResult -CheckId 'reader-exchange-excluded' -Name 'Reader App excludes Exchange workload' -Passed $true -Message 'The Reader App check does not require Exchange Online permissions.' -Category 'Permission'

Export-GRCCheckResult -Results $results -Path $OutputPath
Export-GRCCheckSummaryMarkdown -Results $results -Path ($OutputPath -replace '\.json$', '.md') -Title 'Reader App Access Checks'
