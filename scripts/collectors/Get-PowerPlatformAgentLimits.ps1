[CmdletBinding()]
param(
    [string]$OutputPath = "data/raw/PowerPlatformAgentLimits.json"
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

$environments = @()
$status = "preview"
$note = "Preview dataset."
$isLive = $false
$errorMsg = $null

if ($tenantId -and $clientId -and $certificateBase64 -and $certificatePasswordPlain) {
    try {
        # 1. Obtain Azure Management Access Token
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

        # 2. Query Power Platform environments from Microsoft.PowerPlatform provider
        $envUri = "https://management.azure.com/providers/Microsoft.PowerPlatform/environments?api-version=2020-10-01-preview"
        $envResponse = Invoke-RestMethod -Uri $envUri -Headers $headers -Method Get
        if ($envResponse -and $envResponse.value) {
            $environments = $envResponse.value
            $isLive = $true
            $status = "live"
            $note = "Live Power Platform environments scan succeeded."
        }
    } catch {
        $errorMsg = $_.Exception.Message
        $status = "fallback_alternative"
        $note = "Der Abruf der Power Platform Umgebungen konnte wegen fehlender Berechtigungen nicht durchgeführt werden."
        Write-Warning "Power Platform scan failed: $errorMsg"
    }
} else {
    $status = "preview"
    $note = "Fehlende Umgebungsvariablen. Power Platform Daten werden als inaktiv angezeigt."
}

$result = [pscustomobject]@{
    collector = "Power Platform Agent Limits"
    status = $status
    generatedAt = (Get-Date).ToUniversalTime().ToString("o")
    note = $note
    data = [pscustomobject]@{
        isLive = $isLive
        environments = $environments
        error = $errorMsg
    }
}

$result | ConvertTo-Json -Depth 50 | Set-Content -Path $OutputPath -Encoding UTF8
Write-Host "Wrote $OutputPath"
