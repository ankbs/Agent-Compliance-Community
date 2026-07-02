<#
.SYNOPSIS
    Creates an exportable certificate for the Agent Compliance Community app profiles.
.DESCRIPTION
    Intended for Azure Cloud Shell on Windows or GitHub Windows runners. The CSP provider is used intentionally so later Exchange/Purview-adjacent scenarios remain compatible, even though Exchange Online is not part of this MOC.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$SubjectName,
    [ValidateRange(1,3)][int]$ValidYears = 1,
    [string]$OutputDirectory = $env:RUNNER_TEMP
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

if (-not (Get-Command New-SelfSignedCertificate -ErrorAction SilentlyContinue)) {
    throw 'New-SelfSignedCertificate is not available. Run this script in Azure Cloud Shell/PowerShell on Windows or on a GitHub windows-latest runner.'
}

if ([string]::IsNullOrWhiteSpace($OutputDirectory)) {
    $OutputDirectory = [System.IO.Path]::GetTempPath()
}

if (-not (Test-Path $OutputDirectory)) {
    New-Item -ItemType Directory -Path $OutputDirectory -Force | Out-Null
}

$provider = 'Microsoft Enhanced RSA and AES Cryptographic Provider'
$notBefore = Get-Date
$notAfter = $notBefore.AddYears($ValidYears)
$normalizedSubject = $SubjectName -replace '[^a-zA-Z0-9_.-]', '-'
$pfxPath = Join-Path $OutputDirectory "$normalizedSubject.pfx"

$passwordBytes = [byte[]]::new(32)
[System.Security.Cryptography.RandomNumberGenerator]::Fill($passwordBytes)
$plainPassword = [Convert]::ToBase64String($passwordBytes)
$securePassword = ConvertTo-SecureString $plainPassword -AsPlainText -Force

$cert = New-SelfSignedCertificate `
    -Subject "CN=$SubjectName" `
    -KeyAlgorithm RSA `
    -KeyLength 2048 `
    -Provider $provider `
    -CertStoreLocation 'Cert:\CurrentUser\My' `
    -NotBefore $notBefore `
    -NotAfter $notAfter `
    -KeyExportPolicy Exportable

Export-PfxCertificate -Cert $cert -FilePath $pfxPath -Password $securePassword | Out-Null

[pscustomobject]@{
    subject = $cert.Subject
    thumbprint = $cert.Thumbprint
    notBefore = $cert.NotBefore.ToUniversalTime().ToString('o')
    notAfter = $cert.NotAfter.ToUniversalTime().ToString('o')
    provider = $provider
    pfxPath = $pfxPath
    certificateBase64 = [Convert]::ToBase64String([IO.File]::ReadAllBytes($pfxPath))
    certificatePassword = $plainPassword
    certificateRawDataBase64 = [Convert]::ToBase64String($cert.RawData)
    customKeyIdentifierBase64 = [Convert]::ToBase64String($cert.GetCertHash())
}
