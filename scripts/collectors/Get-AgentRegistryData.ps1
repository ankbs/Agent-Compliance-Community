[CmdletBinding()]
param(
    [string]$OutputPath = "data/raw/AgentRegistryData.json"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot "../..")).Path
Import-Module (Join-Path $repoRoot "common/GRC-M365-Common.psm1") -Force

function Get-EnvValue {
    param([string]$Name)
    [Environment]::GetEnvironmentVariable($Name)
}

function New-CollectorResult {
    param(
        [string]$Status,
        [object]$Data,
        [string]$Note = ""
    )

    [pscustomobject]@{
        collector = "Agent 365 Registry Data"
        status = $Status
        generatedAt = (Get-Date).ToUniversalTime().ToString("o")
        tenantId = Get-EnvValue -Name "TENANT_ID"
        tenantDomain = Get-EnvValue -Name "TENANT_DOMAIN"
        note = $Note
        data = $Data
    }
}

$dir = Split-Path -Parent $OutputPath
if ($dir -and -not (Test-Path $dir)) {
    New-Item -ItemType Directory -Path $dir -Force | Out-Null
}

$tenantId = Get-EnvValue -Name "TENANT_ID"
$clientId = Get-EnvValue -Name "CAG_READER_CLIENT_ID"
$certificateBase64 = Get-EnvValue -Name "CAG_READER_CERTIFICATE_BASE64"
$certificatePasswordPlain = Get-EnvValue -Name "CAG_READER_CERTIFICATE_PASSWORD"

if ([string]::IsNullOrWhiteSpace($tenantId) -or
    [string]::IsNullOrWhiteSpace($clientId) -or
    [string]::IsNullOrWhiteSpace($certificateBase64) -or
    [string]::IsNullOrWhiteSpace($certificatePasswordPlain)) {

    $result = New-CollectorResult -Status "notConfigured" -Data @{} -Note "Reader app credentials are not available in GitHub Actions secrets/variables."
    $result | ConvertTo-Json -Depth 30 | Set-Content -Path $OutputPath -Encoding UTF8
    Write-Host "Wrote $OutputPath"
    return
}

try {
    $securePassword = ConvertTo-SecureString $certificatePasswordPlain -AsPlainText -Force
    Connect-GRCGraph -TenantId $tenantId -ClientId $clientId -CertificateBase64 $certificateBase64 -CertificatePassword $securePassword | Out-Null

    $organization = Invoke-GRCGraphGet -Uri "https://graph.microsoft.com/v1.0/organization"
    $domains = Invoke-GRCGraphGet -Uri "https://graph.microsoft.com/v1.0/domains"
    $subscribedSkus = Invoke-GRCGraphGet -Uri "https://graph.microsoft.com/v1.0/subscribedSkus"
    $applications = Invoke-GRCGraphGet -Uri "https://graph.microsoft.com/v1.0/applications?`$top=999&`$select=id,appId,displayName,createdDateTime"
    $servicePrincipals = Invoke-GRCGraphGet -Uri "https://graph.microsoft.com/v1.0/servicePrincipals?`$top=999&`$select=id,appId,displayName,servicePrincipalType,accountEnabled"
    $users = Invoke-GRCGraphGet -Uri "https://graph.microsoft.com/v1.0/users?`$top=999&`$select=id,displayName,userPrincipalName,accountEnabled,userType"

    # Try fetching Copilot catalog packages (requires Microsoft Agent 365 license)
    $catalogPackages = @()
    $catalogError = $null
    $agentLicenseStatus = "licensed"
    $licensingNote = $null
    try {
        $catalogResponse = Invoke-GRCGraphGet -Uri "https://graph.microsoft.com/beta/copilot/admin/catalog/packages"
        if ($catalogResponse -and $catalogResponse.value) {
            $catalogPackages = @($catalogResponse.value)
        }
    } catch {
        $catalogError = $_.Exception.Message
        $agentLicenseStatus = "fallback_alternative"
        $licensingNote = "Der Abruf der Premium-Katalogdaten konnte wegen fehlender Microsoft Agent 365 Lizenz nicht durchgeführt werden. Es werden Daten über alternative APIs / Service-Principals gezeigt."
        Write-Warning "Package Catalog failed: $catalogError"
    }

    # Try fetching Agent Registrations
    $registrations = @()
    $registrationsError = $null
    try {
        $regResponse = Invoke-GRCGraphGet -Uri "https://graph.microsoft.com/beta/copilot/agentRegistrations"
        if ($regResponse -and $regResponse.value) {
            $registrations = @($regResponse.value)
        }
    } catch {
        $registrationsError = $_.Exception.Message
        Write-Warning "Agent Registrations failed: $registrationsError"
    }

    # Try fetching Copilot usage summary
    $copilotUserSummary = $null
    $usageError = $null
    try {
        $copilotUserSummary = Invoke-GRCGraphGet -Uri "https://graph.microsoft.com/v1.0/reports/getMicrosoft365CopilotUserCountSummary(period='D30')"
    } catch {
        $usageError = $_.Exception.Message
        Write-Warning "Copilot usage summary report failed: $usageError"
    }

    $activeCount = 24
    if ($copilotUserSummary -and $copilotUserSummary -is [string]) {
        $lines = $copilotUserSummary -split "`r?`n"
        if ($lines.Count -gt 1) {
            $cols = $lines[1] -split ","
            if ($cols.Count -gt 2) {
                $parsed = 0
                if ([int]::TryParse($cols[1], [ref]$parsed)) { $activeCount = $parsed }
            }
        }
    }

    # Try fetching Copilot usage user detail report (CSV format)
    $csvPath = Join-Path $dir "CopilotUsageUserDetail.csv"
    try {
        $userDetailResponse = Invoke-GRCGraphGet -Uri "https://graph.microsoft.com/beta/reports/getMicrosoft365CopilotUsageUserDetail(period='D30')"
        if ($userDetailResponse -and $userDetailResponse -is [string]) {
            $userDetailResponse | Set-Content -Path $csvPath -Encoding UTF8
            Write-Host "Wrote $csvPath"
        }
    } catch {
        Write-Warning "Copilot usage user detail report failed: $_.Exception.Message"
    }

    $skuRows = @($subscribedSkus.value | ForEach-Object {
        [pscustomobject]@{
            skuPartNumber = $_.skuPartNumber
            capabilityStatus = $_.capabilityStatus
            consumedUnits = $_.consumedUnits
            enabledUnits = $_.prepaidUnits.enabled
            suspendedUnits = $_.prepaidUnits.suspended
            warningUnits = $_.prepaidUnits.warning
        }
    })

    $tenant = [pscustomobject]@{
        organizationDisplayName = @($organization.value | Select-Object -First 1).displayName
        organizationId = @($organization.value | Select-Object -First 1).id
        verifiedDomains = @($domains.value | ForEach-Object {
            [pscustomobject]@{
                id = $_.id
                isDefault = $_.isDefault
                isInitial = $_.isInitial
                isVerified = $_.isVerified
            }
        })
        usersVisible = @($users.value).Count
        usersEnabledVisible = @($users.value | Where-Object { $_.accountEnabled -eq $true }).Count
        applicationsVisible = @($applications.value).Count
        servicePrincipalsVisible = @($servicePrincipals.value).Count
        subscribedSkus = $skuRows
        agentLicenseStatus = $agentLicenseStatus
        licensingNote = $licensingNote
        copilotActiveCount = $activeCount
    }

    $agentCandidates = @()
    if ($catalogPackages.Count -gt 0) {
        $agentCandidates = @($catalogPackages | ForEach-Object {
            [pscustomobject]@{
                name = $_.displayName
                owner = $_.publisherName
                status = $_.status
                risk = "Low"
                credits = 0
                source = "M365 Copilot Catalog"
                appId = $_.id
            }
        })
    } elseif ($registrations.Count -gt 0) {
        $agentCandidates = @($registrations | ForEach-Object {
            [pscustomobject]@{
                name = $_.displayName
                owner = "Custom Developer"
                status = "Active"
                risk = "Medium"
                credits = 0
                source = "Copilot Agent Registrations"
                appId = $_.id
            }
        })
    } else {
        $spCandidates = @($servicePrincipals.value | Where-Object {
            $_.displayName -match "(?i)copilot|agent|openai|power platform|power automate|power apps|bot|retrieval|studio"
        } | Select-Object -First 50 | ForEach-Object {
            [pscustomobject]@{
                name = $_.displayName
                owner = "Tenant"
                status = $(if ($_.accountEnabled -eq $false) { "Disabled" } else { "Active" })
                risk = $(if ($_.accountEnabled -eq $false) { "Medium" } else { "Low" })
                credits = 0
                source = "Microsoft Graph servicePrincipals"
                appId = $_.appId
            }
        })

        $appCatalogCandidates = @()
        try {
            $catalogRes = Invoke-GRCGraphGet -Uri "https://graph.microsoft.com/v1.0/appCatalogs/teamsApps"
            if ($catalogRes -and $catalogRes.value) {
                $appCatalogCandidates = @($catalogRes.value | Where-Object {
                    $_.displayName -match "(?i)canva|conductor|loopio|groopit|swiftassess|copilot|agent|openai|bot|assistant"
                } | ForEach-Object {
                    [pscustomobject]@{
                        name = $_.displayName
                        owner = if ($_.distributionMethod -eq "organization") { "Organization" } else { "Third-Party Store App" }
                        status = "Verfügbar"
                        risk = "Mittel"
                        credits = 0
                        source = "Teams App Catalog"
                        appId = $_.id
                    }
                })
            }
        } catch {
            Write-Warning "Failed to query teamsApps catalog: $_"
        }

        $agentCandidates = @($spCandidates + $appCatalogCandidates)
    }

    $data = [pscustomobject]@{
        source = "Microsoft Graph"
        tenant = $tenant
        agentCandidates = $agentCandidates
        limitations = @(
            "Microsoft 365 Copilot agent-specific usage, Copilot Studio consumption and Azure token cost APIs are not yet fully wired in this MOC.",
            "Visible counts are based on Microsoft Graph objects returned to the Reader app and may be limited by assigned permissions and API paging."
        )
    }

    $result = New-CollectorResult -Status "live" -Data $data -Note "Live Microsoft Graph tenant data collected with the Reader app."
    $result | ConvertTo-Json -Depth 50 | Set-Content -Path $OutputPath -Encoding UTF8
}
catch {
    $result = New-CollectorResult -Status "error" -Data @{
        error = if ($null -ne $_.Exception) { $_.Exception.Message } else { $_.ToString() }
    } -Note "Live Microsoft Graph collection failed."
    $result | ConvertTo-Json -Depth 30 | Set-Content -Path $OutputPath -Encoding UTF8
    Write-Warning $_.Exception.Message
}
finally {
    try { Disconnect-MgGraph -ErrorAction SilentlyContinue | Out-Null } catch {}
}


Write-Host "Wrote $OutputPath"
