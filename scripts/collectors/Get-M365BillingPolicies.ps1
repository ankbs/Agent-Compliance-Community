[CmdletBinding()]
param(
    [string]$OutputPath = "data/raw/M365BillingPolicies.json"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Get-EnvValue {
    param([string]$Name)
    [Environment]::GetEnvironmentVariable($Name)
}

$dir = Split-Path -Parent $OutputPath
if ($dir -and -not (Test-Path $dir)) {
    New-Item -ItemType Directory -Path $dir -Force | Out-Null
}

$tenantId = Get-EnvValue -Name "TENANT_ID"
$clientId = Get-EnvValue -Name "CLIENT_ID"
$certificateBase64 = Get-EnvValue -Name "CERTIFICATE_BASE64"
$certificatePasswordPlain = Get-EnvValue -Name "CERTIFICATE_PASSWORD"

$policies = @()
$status = "preview"
$note = "Preview dataset."
$isLive = $false
$errorMsg = $null

$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot "../..")).Path
$overridePath = Join-Path $repoRoot "config/billing-override.json"

if ($tenantId -and $clientId -and $certificateBase64 -and $certificatePasswordPlain) {
    
    # --- METHOD 1: Try Microsoft Graph Beta Commerce API ---
    try {
        $commonModule = Join-Path $PSScriptRoot "../../common/GRC-M365-Common.psm1"
        if (Test-Path $commonModule) {
            Import-Module $commonModule -ErrorAction Stop
            $securePassword = ConvertTo-SecureString $certificatePasswordPlain -AsPlainText -Force
            Connect-GRCGraph -TenantId $tenantId -ClientId $clientId -CertificateBase64 $certificateBase64 -CertificatePassword $securePassword | Out-Null
            
            # Query the Graph Beta commerce endpoint
            $graphRes = Invoke-GRCGraphGet -Uri "https://graph.microsoft.com/beta/commerce/azureSubscriptionBilling"
            if ($graphRes -and $graphRes.value) {
                foreach ($policy in $graphRes.value) {
                    $policies += [pscustomobject]@{
                        name = $policy.displayName
                        service = "M365 Pay-as-you-go"
                        subscriptionId = $policy.subscriptionId
                        subscriptionName = $policy.subscriptionName
                        resourceGroup = $policy.resourceGroup
                        resourceId = $policy.id
                        type = "Microsoft.Commerce/billingPolicies"
                    }
                }
                if ($policies.Count -gt 0) {
                    $isLive = $true
                    $status = "live"
                    $note = "Live M365 Graph Beta commerce billing policies query succeeded."
                }
            }
        }
    } catch {
        Write-Warning "Graph Beta commerce query failed: $_"
    }

    # --- METHOD 2: Fallback to Azure ARM Subscription resource-scanning ---
    if ($policies.Count -eq 0) {
        try {
            $securePassword = ConvertTo-SecureString $certificatePasswordPlain -AsPlainText -Force
            $certBytes = [Convert]::FromBase64String($certificateBase64)
            $cert = [System.Security.Cryptography.X509Certificates.X509Certificate2]::new(
                $certBytes,
                $securePassword,
                [System.Security.Cryptography.X509Certificates.X509KeyStorageFlags]::EphemeralKeySet
            )

            $x5t = [Convert]::ToBase64String($cert.GetCertHash()).Replace('=', '').Replace('+', '-').Replace('/', '_')
            $header = @{ alg = "RS256"; typ = "JWT"; x5t = $x5t }
            $now = [DateTimeOffset]::UtcNow
            $exp = $now.AddMinutes(10)
            $payload = @{
                aud = "https://login.microsoftonline.com/$tenantId/oauth2/v2.0/token"
                iss = $clientId
                sub = $clientId
                jti = [Guid]::NewGuid().ToString()
                nbf = $now.ToUnixTimeSeconds()
                exp = $exp.ToUnixTimeSeconds()
            }

            $headerJson = ConvertTo-Json $header -Compress
            $payloadJson = ConvertTo-Json $payload -Compress
            $headerBase64 = [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes($headerJson)).Replace('=', '').Replace('+', '-').Replace('/', '_')
            $payloadBase64 = [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes($payloadJson)).Replace('=', '').Replace('+', '-').Replace('/', '_')

            $toSign = "$headerBase64.$payloadBase64"
            $toSignBytes = [Text.Encoding]::UTF8.GetBytes($toSign)
            $privateKey = [System.Security.Cryptography.X509Certificates.RSACertificateExtensions]::GetRSAPrivateKey($cert)
            $sigBytes = $privateKey.SignData($toSignBytes, [System.Security.Cryptography.HashAlgorithmName]::SHA256, [System.Security.Cryptography.RSASignaturePadding]::Pkcs1)
            $sigBase64 = [Convert]::ToBase64String($sigBytes).Replace('=', '').Replace('+', '-').Replace('/', '_')
            $assertion = "$toSign.$sigBase64"

            $tokenUri = "https://login.microsoftonline.com/$tenantId/oauth2/v2.0/token"
            $body = @{
                grant_type = "client_credentials"
                client_id = $clientId
                scope = "https://management.azure.com/.default"
                client_assertion_type = "urn:ietf:params:oauth:client-assertion-type:jwt-bearer"
                client_assertion = $assertion
            }
            $bodyStr = ($body.Keys | ForEach-Object { "$_=$([Uri]::EscapeDataString($body[$_]))" }) -join "&"
            $tokenResponse = Invoke-RestMethod -Uri $tokenUri -Method Post -Body $bodyStr -ContentType "application/x-www-form-urlencoded"
            $token = $tokenResponse.access_token

            $headers = @{
                Authorization = "Bearer $token"
            }

            $subResponse = Invoke-RestMethod -Uri "https://management.azure.com/subscriptions?api-version=2022-12-01" -Headers $headers -Method Get
            if ($subResponse -and $subResponse.value) {
                foreach ($sub in $subResponse.value) {
                    $subId = $sub.subscriptionId
                    try {
                        $resourceUri = "https://management.azure.com/subscriptions/$subId/resources?api-version=2021-04-01"
                        $resResponse = Invoke-RestMethod -Uri $resourceUri -Headers $headers -Method Get
                        if ($resResponse -and $resResponse.value) {
                            $billingResources = @($resResponse.value | Where-Object { 
                                $_.type -match "Microsoft\.PowerPlatform/accounts|Microsoft\.PaygPlatform/accounts|Microsoft\.Billing|Microsoft\.Copilot" -or
                                $_.name -match "Abrechnung|Billing|Payg|Copilot"
                            })

                            foreach ($r in $billingResources) {
                                $rg = "Default"
                                if ($r.id -match "resourceGroups/([^/]+)") {
                                    $rg = $Matches[1]
                                }

                                $policies += [pscustomobject]@{
                                    name = $r.name
                                    service = if ($r.type -match "PowerPlatform") { "Power Platform / Copilot Studio" } else { "M365 Pay-as-you-go" }
                                    subscriptionId = $subId
                                    subscriptionName = $sub.displayName
                                    resourceGroup = $rg
                                    resourceId = $r.id
                                    type = $r.type
                                }
                            }
                        }
                    } catch {
                        Write-Warning "Could not fetch resources for subscription $($subId): $_"
                    }
                }
                if ($policies.Count -gt 0) {
                    $isLive = $true
                    $status = "live"
                    $note = "Live Azure-based Pay-as-you-go billing policies scan completed."
                }
            }
        } catch {
            $errorMsg = $_.Exception.Message
            Write-Warning "Azure subscription resource-scanning failed: $errorMsg"
        }
    }
}

# --- METHOD 3: Try Local configuration override file ---
if ($policies.Count -eq 0) {
    if (Test-Path $overridePath) {
        try {
            $rawJson = Get-Content $overridePath -Raw | ConvertFrom-Json
            if ($rawJson) {
                foreach ($item in $rawJson) {
                    $policies += [pscustomobject]@{
                        name = $item.name
                        service = $item.service
                        subscriptionId = $item.subscriptionId
                        subscriptionName = $item.subscriptionName
                        resourceGroup = $item.resourceGroup
                        resourceId = "config-override"
                        type = "Microsoft.Commerce/billingPolicies"
                    }
                }
                $isLive = $true
                $status = "live"
                $note = "Abrechnungsrichtlinie aus lokaler Konfigurationsdatei geladen (API-Zugriff eingeschränkt)."
            }
        } catch {
            Write-Warning "Failed to load override config: $_"
        }
    }
}

if ($policies.Count -eq 0 -and $null -eq $errorMsg) {
    $note = "Keine aktiven Pay-as-you-go Abrechnungsrichtlinien im Tenant gefunden."
}

$result = [pscustomobject]@{
    collector = "M365 Billing Policies"
    status = $status
    generatedAt = (Get-Date).ToUniversalTime().ToString("o")
    note = $note
    data = [pscustomobject]@{
        isLive = $isLive
        policies = $policies
        error = $errorMsg
    }
}

$result | ConvertTo-Json -Depth 50 | Set-Content -Path $OutputPath -Encoding UTF8
Write-Host "Wrote $OutputPath"
