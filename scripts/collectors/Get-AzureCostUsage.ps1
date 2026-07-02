[CmdletBinding()]
param(
    [string]$OutputPath = "data/raw/AzureCostUsage.json"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot "../..")).Path

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

$subscriptions = @()
$budgets = @()
$costs = @()
$status = "preview"
$note = "Preview dataset."
$isLive = $false
$errorMsg = $null

if ($tenantId -and $clientId -and $certificateBase64 -and $certificatePasswordPlain) {
    try {
        # 1. Obtain Azure Management Access Token using Client Assertion certificate flow
        $securePassword = ConvertTo-SecureString $certificatePasswordPlain -AsPlainText -Force
        $certBytes = [Convert]::FromBase64String($certificateBase64)
        $cert = [System.Security.Cryptography.X509Certificates.X509Certificate2]::new(
            $certBytes,
            $securePassword,
            [System.Security.Cryptography.X509Certificates.X509KeyStorageFlags]::EphemeralKeySet
        )

        $x5t = [Convert]::ToBase64String($cert.GetCertHash()).Replace('=', '').Replace('+', '-').Replace('/', '_')
        $header = @{
            alg = "RS256"
            typ = "JWT"
            x5t = $x5t
        }
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

        # 2. Query subscriptions
        $subResponse = Invoke-RestMethod -Uri "https://management.azure.com/subscriptions?api-version=2022-12-01" -Headers $headers -Method Get
        if ($subResponse -and $subResponse.value) {
            $subscriptions = $subResponse.value
            $isLive = $true
            $status = "live"
            $note = "Live Azure Subscription cost data query succeeded."

            # Loop through subscriptions to query cost and budgets
            foreach ($sub in $subscriptions) {
                $subId = $sub.subscriptionId
                
                # Fetch Budgets
                try {
                    $budgetUri = "https://management.azure.com/subscriptions/$subId/providers/Microsoft.Consumption/budgets?api-version=2023-05-01"
                    $budgetRes = Invoke-RestMethod -Uri $budgetUri -Headers $headers -Method Get
                    if ($budgetRes -and $budgetRes.value) {
                        $budgets += $budgetRes.value
                    }
                } catch {
                    Write-Warning "Could not fetch budgets for subscription $($subId): $_"
                }

                # Fetch Azure OpenAI costs
                try {
                    $costUri = "https://management.azure.com/subscriptions/$subId/providers/Microsoft.CostManagement/query?api-version=2019-11-01"
                    $query = @{
                        type = "Usage"
                        timeframe = "MonthToDate"
                        dataset = @{
                            granularity = "None"
                            aggregation = @{
                                totalCost = @{
                                    name = "PreTaxCost"
                                    function = "Sum"
                                }
                            }
                            grouping = @(
                                @{
                                    type = "Dimension"
                                    name = "ResourceType"
                                }
                            )
                        }
                    }
                    $queryJson = ConvertTo-Json $query -Depth 10
                    $costRes = Invoke-RestMethod -Uri $costUri -Headers $headers -Method Post -Body $queryJson -ContentType "application/json"
                    if ($costRes -and $costRes.properties -and $costRes.properties.rows) {
                        $costs += @($costRes.properties.rows | ForEach-Object {
                            [pscustomobject]@{
                                subscriptionId = $subId
                                cost = $_[0]
                                resourceType = $_[1]
                            }
                        })
                    }
                } catch {
                    Write-Warning "Could not fetch cost details for subscription $($subId): $_"
                }
            }
        }
    } catch {
        $errorMsg = $_.Exception.Message
        $status = "fallback_alternative"
        $note = "Der Abruf der Azure-Kosten konnte wegen fehlender Azure Reader-Rolle nicht durchgeführt werden. Es werden alternative/simulierte Budgetdaten angezeigt."
        Write-Warning "Azure connection failed: $errorMsg"
    }
} else {
    $status = "preview"
    $note = "Fehlende Umgebungsvariablen für Azure-Verbindung. Es werden simulierte Budgetdaten angezeigt."
}

$data = [pscustomobject]@{
    isLive = $isLive
    subscriptions = $subscriptions
    budgets = $budgets
    costs = $costs
    error = $errorMsg
}

$result = [pscustomobject]@{
    collector = "Azure Cost Usage"
    status = $status
    generatedAt = (Get-Date).ToUniversalTime().ToString("o")
    note = $note
    data = $data
}

$result | ConvertTo-Json -Depth 50 | Set-Content -Path $OutputPath -Encoding UTF8
Write-Host "Wrote $OutputPath"
