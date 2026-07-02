#Requires -Version 7.0
<#
.SYNOPSIS
  No-install Entra app registration bootstrap for Agent Compliance Community.

.DESCRIPTION
  Creates or updates the Reader, AgentStatusAction and BillingChange app registrations,
  creates certificate material, writes github-secrets.json and opens Admin Consent URLs.

  This script intentionally performs no Install-Module, no Install-Package and no local
  GitHub secret encryption. GitHub repository secrets are imported on the GitHub Pages
  bootstrap page by uploading github-secrets.json.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$TenantId,
    [Parameter(Mandatory)][string]$TenantDomain,
    [Parameter(Mandatory)][string]$GitHubRepository,
    [string]$AppPrefix = 'Agent Compliance Community',
    [string]$OutputDirectory = '.out/entra-bootstrap',
    [ValidateRange(1,2)][int]$CertificateYears = 1,
    [string]$AdminConsentRedirectUri = '',
    [string]$GitHubRef = 'main',
    [switch]$GrantApplicationAdminConsent,
    [switch]$AllowUnresolvedPermissions,
    [switch]$OpenAdminConsentUrls,

    # Deprecated switches are intentionally accepted to avoid parser failures from cached old pages,
    # but they are ignored and do not install anything.
    [switch]$SetGitHubSecrets,
    [switch]$DispatchFinalPermissionCheck
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Write-Step {
    param([string]$Message)
    Write-Host "[entra-bootstrap] $Message" -ForegroundColor Cyan
}

function Get-GrcObjectProperty {
    param($InputObject,[Parameter(Mandatory)][string]$Name,$Default=$null)
    if ($null -eq $InputObject) { return $Default }
    if ($InputObject -is [System.Collections.IDictionary]) {
        if ($InputObject.Contains($Name)) { return $InputObject[$Name] }
        return $Default
    }
    $property = $InputObject.PSObject.Properties[$Name]
    if ($null -ne $property) { return $property.Value }
    return $Default
}

function Get-GrcFirst {
    param($Items)
    $array = @($Items)
    if ($array.Count -gt 0) { return $array[0] }
    return $null
}

function Invoke-GrcGraphPagedGet {
    param([Parameter(Mandatory)][string]$Uri)
    $items = @()
    $next = $Uri
    while ($next) {
        $page = Invoke-MgGraphRequest -Method GET -Uri $next -ErrorAction Stop
        $value = Get-GrcObjectProperty -InputObject $page -Name 'value' -Default @()
        if ($value) { $items += @($value) }
        $next = Get-GrcObjectProperty -InputObject $page -Name '@odata.nextLink' -Default $null
    }
    return $items
}

function Get-GrcServicePrincipalByAppId {
    param([Parameter(Mandatory)][string]$AppId)
    $filter = [uri]::EscapeDataString("appId eq '$AppId'")
    $sp = Get-GrcFirst (Invoke-GrcGraphPagedGet -Uri "https://graph.microsoft.com/v1.0/servicePrincipals?`$filter=$filter&`$select=id,appId,displayName,appRoles,oauth2PermissionScopes")
    if (-not $sp) { return $null }
    $spId = Get-GrcObjectProperty -InputObject $sp -Name 'id'
    if ($spId) {
        return Invoke-MgGraphRequest -Method GET -Uri "https://graph.microsoft.com/v1.0/servicePrincipals/$($spId)?`$select=id,appId,displayName,appRoles,oauth2PermissionScopes" -ErrorAction Stop
    }
    return $sp
}

function Ensure-GrcServicePrincipalByAppId {
    param([Parameter(Mandatory)][string]$AppId,[Parameter(Mandatory)][string]$Name)
    $sp = Get-GrcServicePrincipalByAppId -AppId $AppId
    if ($sp) {
        Write-Step "Service principal available: $Name"
        return $sp
    }
    Write-Step "Creating service principal prerequisite: $Name"
    Invoke-MgGraphRequest -Method POST -Uri 'https://graph.microsoft.com/v1.0/servicePrincipals' -Body @{ appId = $AppId } -ErrorAction Stop | Out-Null
    Start-Sleep -Seconds 8
    $sp = Get-GrcServicePrincipalByAppId -AppId $AppId
    if (-not $sp) { throw "Service principal was not available after creation: $Name / $AppId" }
    return $sp
}

function Resolve-GrcResourceAccess {
    param($ResourceServicePrincipal,[string[]]$ApplicationPermissions=@(),[string[]]$DelegatedScopes=@(),[string]$ResourceName)
    $roles = @(Get-GrcObjectProperty -InputObject $ResourceServicePrincipal -Name 'appRoles' -Default @())
    $scopes = @(Get-GrcObjectProperty -InputObject $ResourceServicePrincipal -Name 'oauth2PermissionScopes' -Default @())
    $access = @()
    $unresolved = @()

    foreach ($permission in ($ApplicationPermissions | Sort-Object -Unique)) {
        $role = Get-GrcFirst ($roles | Where-Object {
            (Get-GrcObjectProperty $_ 'value') -eq $permission -and
            @((Get-GrcObjectProperty $_ 'allowedMemberTypes' @())) -contains 'Application'
        })
        if ($role) { $access += @{ id = Get-GrcObjectProperty $role 'id'; type = 'Role' } }
        else { $unresolved += "$ResourceName application permission not found: $permission" }
    }

    foreach ($scopeName in ($DelegatedScopes | Sort-Object -Unique)) {
        $scope = Get-GrcFirst ($scopes | Where-Object { (Get-GrcObjectProperty $_ 'value') -eq $scopeName })
        if ($scope) { $access += @{ id = Get-GrcObjectProperty $scope 'id'; type = 'Scope' } }
        else { $unresolved += "$ResourceName delegated scope not found: $scopeName" }
    }

    [pscustomobject]@{ access = $access; unresolved = $unresolved }
}

function New-GrcLocalCertificateBundle {
    param(
        [Parameter(Mandatory)][string]$SubjectName,
        [Parameter(Mandatory)][string]$OutputBaseName,
        [Parameter(Mandatory)][string]$OutputDirectory,
        [int]$Years = 1
    )
    New-Item -ItemType Directory -Path $OutputDirectory -Force | Out-Null
    $safeSubject = ($SubjectName -replace '[^A-Za-z0-9 ._-]','')
    $cert = New-SelfSignedCertificate -Subject "CN=$safeSubject" -CertStoreLocation 'Cert:\CurrentUser\My' -KeyExportPolicy Exportable -KeySpec KeyExchange -Provider 'Microsoft Enhanced RSA and AES Cryptographic Provider' -NotAfter (Get-Date).AddYears($Years)
    $password = [Convert]::ToBase64String([System.Security.Cryptography.RandomNumberGenerator]::GetBytes(24))
    $securePassword = ConvertTo-SecureString $password -AsPlainText -Force
    $pfxPath = Join-Path $OutputDirectory "$OutputBaseName.pfx"
    $cerPath = Join-Path $OutputDirectory "$OutputBaseName.cer"
    Export-PfxCertificate -Cert $cert -FilePath $pfxPath -Password $securePassword | Out-Null
    Export-Certificate -Cert $cert -FilePath $cerPath | Out-Null
    [pscustomobject]@{
        certificate = $cert
        password = $password
        pfxPath = $pfxPath
        cerPath = $cerPath
        pfxBase64 = [Convert]::ToBase64String([IO.File]::ReadAllBytes($pfxPath))
        cerBase64 = [Convert]::ToBase64String([IO.File]::ReadAllBytes($cerPath))
        startDateTime = $cert.NotBefore.ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ssZ')
        endDateTime = $cert.NotAfter.ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ssZ')
    }
}

function Get-GrcApplicationByDisplayName {
    param([Parameter(Mandatory)][string]$DisplayName)
    $safe = $DisplayName.Replace("'", "''")
    $filter = [uri]::EscapeDataString("displayName eq '$safe'")
    Get-GrcFirst (Invoke-GrcGraphPagedGet -Uri "https://graph.microsoft.com/v1.0/applications?`$filter=$filter&`$select=id,appId,displayName")
}

function Ensure-GrcApplicationRegistration {
    param(
        [Parameter(Mandatory)][string]$DisplayName,
        [Parameter(Mandatory)][array]$RequiredResourceAccess,
        [Parameter(Mandatory)][string]$RedirectUri
    )

    $app = Get-GrcApplicationByDisplayName -DisplayName $DisplayName
    $body = @{
        requiredResourceAccess = $RequiredResourceAccess
        web = @{ redirectUris = @($RedirectUri) }
    }

    if ($app) {
        Write-Step "Updating app registration: $DisplayName"
        Invoke-MgGraphRequest -Method PATCH -Uri "https://graph.microsoft.com/v1.0/applications/$(Get-GrcObjectProperty $app 'id')" -Body $body -ErrorAction Stop | Out-Null
        return Get-GrcApplicationByDisplayName -DisplayName $DisplayName
    }

    Write-Step "Creating app registration: $DisplayName"
    $createBody = @{
        displayName = $DisplayName
        signInAudience = 'AzureADMyOrg'
        requiredResourceAccess = $RequiredResourceAccess
        web = @{ redirectUris = @($RedirectUri) }
    }
    Invoke-MgGraphRequest -Method POST -Uri 'https://graph.microsoft.com/v1.0/applications' -Body $createBody -ErrorAction Stop | Out-Null
    Start-Sleep -Seconds 3
    return Get-GrcApplicationByDisplayName -DisplayName $DisplayName
}

function Ensure-GrcClientServicePrincipal {
    param([Parameter(Mandatory)]$Application)
    $appId = Get-GrcObjectProperty $Application 'appId'
    $sp = Get-GrcServicePrincipalByAppId -AppId $appId
    if ($sp) { return $sp }
    Write-Step "Creating client service principal for $(Get-GrcObjectProperty $Application 'displayName')"
    Invoke-MgGraphRequest -Method POST -Uri 'https://graph.microsoft.com/v1.0/servicePrincipals' -Body @{ appId = $appId } -ErrorAction Stop | Out-Null
    Start-Sleep -Seconds 5
    return Get-GrcServicePrincipalByAppId -AppId $appId
}

function Set-GrcApplicationCertificateCredential {
    param([Parameter(Mandatory)]$Application,[Parameter(Mandatory)]$CertificateBundle,[Parameter(Mandatory)][string]$DisplayName)
    $keyCredential = @{
        customKeyIdentifier = [Convert]::ToBase64String($CertificateBundle.certificate.GetCertHash())
        displayName = $DisplayName
        endDateTime = $CertificateBundle.endDateTime
        key = $CertificateBundle.cerBase64
        startDateTime = $CertificateBundle.startDateTime
        type = 'AsymmetricX509Cert'
        usage = 'Verify'
    }
    Invoke-MgGraphRequest -Method PATCH -Uri "https://graph.microsoft.com/v1.0/applications/$(Get-GrcObjectProperty $Application 'id')" -Body @{ keyCredentials = @($keyCredential) } -ErrorAction Stop | Out-Null
}

function Grant-GrcApplicationRoles {
    param([Parameter(Mandatory)]$ClientServicePrincipal,[Parameter(Mandatory)]$ResourceServicePrincipal,[Parameter(Mandatory)][array]$ResourceAccess)
    $roleIds = @($ResourceAccess | Where-Object { $_.type -eq 'Role' } | ForEach-Object { [string]$_.id })
    if ($roleIds.Count -eq 0) { return }
    $clientSpId = Get-GrcObjectProperty $ClientServicePrincipal 'id'
    $resourceSpId = Get-GrcObjectProperty $ResourceServicePrincipal 'id'
    $existing = Invoke-GrcGraphPagedGet -Uri "https://graph.microsoft.com/v1.0/servicePrincipals/$clientSpId/appRoleAssignments"

    foreach ($roleId in $roleIds) {
        $already = @($existing | Where-Object {
            [string](Get-GrcObjectProperty $_ 'resourceId') -eq [string]$resourceSpId -and
            [string](Get-GrcObjectProperty $_ 'appRoleId') -eq $roleId
        }).Count -gt 0
        if (-not $already) {
            Write-Step "Granting application role on $(Get-GrcObjectProperty $ResourceServicePrincipal 'displayName')"
            Invoke-MgGraphRequest -Method POST -Uri "https://graph.microsoft.com/v1.0/servicePrincipals/$clientSpId/appRoleAssignments" -Body @{ principalId=$clientSpId; resourceId=$resourceSpId; appRoleId=$roleId } -ErrorAction Stop | Out-Null
        }
    }
}

if ($SetGitHubSecrets -or $DispatchFinalPermissionCheck) {
    Write-Warning 'Deprecated switches -SetGitHubSecrets/-DispatchFinalPermissionCheck were ignored. Secrets are imported in the browser upload section.'
}

$repoParts = $GitHubRepository -split '/', 2
if ($repoParts.Count -ne 2) { throw "GitHubRepository must be owner/repo. Current value: $GitHubRepository" }

if ([string]::IsNullOrWhiteSpace($AdminConsentRedirectUri)) {
    $AdminConsentRedirectUri = "https://$($repoParts[0]).github.io/$($repoParts[1])/entra-bootstrap.html"
}

$OutputDirectory = [IO.Path]::GetFullPath($OutputDirectory)
New-Item -ItemType Directory -Path $OutputDirectory -Force | Out-Null

Write-Step "Admin consent redirect URI: $AdminConsentRedirectUri"

if (-not (Get-Module -ListAvailable -Name Microsoft.Graph.Authentication)) {
    throw 'Microsoft.Graph.Authentication is not available. This no-install bootstrap does not install modules on the end user client. Use a prepared PowerShell environment where Microsoft.Graph.Authentication is already available.'
}
Import-Module Microsoft.Graph.Authentication -ErrorAction Stop

$scopes = @('Application.ReadWrite.All','AppRoleAssignment.ReadWrite.All','Directory.Read.All')
Write-Step "Connecting to Microsoft Graph tenant $TenantId"
Connect-MgGraph -TenantId $TenantId -Scopes $scopes -NoWelcome -UseDeviceAuthentication -ErrorAction Stop

$graphAppId = '00000003-0000-0000-c000-000000000000'
$workIqAppId = 'fdcc1f02-fc51-4226-8753-f668596af7f7'
$graphSp = Ensure-GrcServicePrincipalByAppId -AppId $graphAppId -Name 'Microsoft Graph'
$workIqSp = Ensure-GrcServicePrincipalByAppId -AppId $workIqAppId -Name 'WorkIQ prerequisite resource'

$profiles = @(
    [pscustomobject]@{
        Name='Reader'; DisplayName="$AppPrefix - Reader"; SecretPrefix='CAG_READER'; Short='reader'
        GraphApplicationPermissions=@('Reports.Read.All','Directory.Read.All','Application.Read.All','AuditLog.Read.All','Policy.Read.All','AgentRegistration.Read.All')
        GraphDelegatedScopes=@('Reports.Read.All','AgentRegistration.Read.All','CopilotPackages.Read.All')
        WorkIqDelegatedScopes=@()
    },
    [pscustomobject]@{
        Name='AgentStatusAction'; DisplayName="$AppPrefix - Agent Status Action"; SecretPrefix='CAG_STATUS'; Short='status'
        GraphApplicationPermissions=@('Reports.Read.All','Directory.Read.All','Application.Read.All','AgentRegistration.ReadWrite.All','AgentRegistration.Read.All','CopilotPackages.ReadWrite.All')
        GraphDelegatedScopes=@('CopilotSettings-LimitedMode.Read','CopilotSettings-LimitedMode.ReadWrite','CopilotPolicySettings.Read','CopilotPolicySettings.ReadWrite','Reports.Read.All','AgentRegistration.ReadWrite.All','AgentRegistration.Read.All','CopilotPackages.Read.All','CopilotPackages.ReadWrite.All')
        WorkIqDelegatedScopes=@('WorkIQAgent.Ask')
    },
    [pscustomobject]@{
        Name='BillingChange'; DisplayName="$AppPrefix - Billing Change"; SecretPrefix='CAG_BILLING'; Short='billing'
        GraphApplicationPermissions=@('Reports.Read.All','Directory.Read.All','Application.Read.All','AgentRegistration.ReadWrite.All','AgentRegistration.Read.All','CopilotPackages.ReadWrite.All')
        GraphDelegatedScopes=@('CopilotSettings-LimitedMode.Read','CopilotSettings-LimitedMode.ReadWrite','CopilotPolicySettings.Read','CopilotPolicySettings.ReadWrite','Reports.Read.All','AgentRegistration.ReadWrite.All','AgentRegistration.Read.All','CopilotPackages.Read.All','CopilotPackages.ReadWrite.All')
        WorkIqDelegatedScopes=@('WorkIQAgent.Ask')
    }
)

$summary = @()
$secretMap = [ordered]@{}
$unresolvedAll = @()

foreach ($profile in $profiles) {
    Write-Step "Processing profile: $($profile.Name)"

    $graphResolved = Resolve-GrcResourceAccess -ResourceServicePrincipal $graphSp -ApplicationPermissions $profile.GraphApplicationPermissions -DelegatedScopes $profile.GraphDelegatedScopes -ResourceName 'Microsoft Graph'
    $workIqResolved = Resolve-GrcResourceAccess -ResourceServicePrincipal $workIqSp -ApplicationPermissions @() -DelegatedScopes $profile.WorkIqDelegatedScopes -ResourceName 'WorkIQ'
    $unresolved = @($graphResolved.unresolved + $workIqResolved.unresolved)

    if ($unresolved.Count -gt 0) {
        $unresolvedAll += @($unresolved | ForEach-Object { "$($profile.Name): $_" })
        if (-not $AllowUnresolvedPermissions) { throw "Unresolved permissions for $($profile.Name): $($unresolved -join '; ')" }
    }

    $requiredResourceAccess = @()
    if ($graphResolved.access.Count -gt 0) {
        $requiredResourceAccess += @{ resourceAppId = $graphAppId; resourceAccess = @($graphResolved.access) }
    }
    if ($workIqResolved.access.Count -gt 0) {
        $requiredResourceAccess += @{ resourceAppId = $workIqAppId; resourceAccess = @($workIqResolved.access) }
    }

    $app = Ensure-GrcApplicationRegistration -DisplayName $profile.DisplayName -RequiredResourceAccess $requiredResourceAccess -RedirectUri $AdminConsentRedirectUri
    $clientSp = Ensure-GrcClientServicePrincipal -Application $app

    $certBundle = New-GrcLocalCertificateBundle -SubjectName ($profile.DisplayName -replace '[^A-Za-z0-9 -]','') -OutputBaseName $profile.Short -OutputDirectory $OutputDirectory -Years $CertificateYears
    Set-GrcApplicationCertificateCredential -Application $app -CertificateBundle $certBundle -DisplayName "Agent Compliance Bootstrap $($profile.Name)"

    if ($GrantApplicationAdminConsent) {
        Grant-GrcApplicationRoles -ClientServicePrincipal $clientSp -ResourceServicePrincipal $graphSp -ResourceAccess $graphResolved.access
    }

    $clientId = Get-GrcObjectProperty $app 'appId'
    $consentUrl = "https://login.microsoftonline.com/$TenantId/adminconsent?client_id=$clientId&redirect_uri=$([uri]::EscapeDataString($AdminConsentRedirectUri))&state=$([uri]::EscapeDataString($profile.Name))"

    $secretMap["$($profile.SecretPrefix)_CLIENT_ID"] = $clientId
    $secretMap["$($profile.SecretPrefix)_CERTIFICATE_BASE64"] = $certBundle.pfxBase64
    $secretMap["$($profile.SecretPrefix)_CERTIFICATE_PASSWORD"] = $certBundle.password

    $summary += [pscustomobject]@{
        profile = $profile.Name
        displayName = $profile.DisplayName
        clientId = $clientId
        servicePrincipalId = (Get-GrcObjectProperty $clientSp 'id')
        certificateFile = $certBundle.pfxPath
        certificateEndDateTime = $certBundle.endDateTime
        unresolvedPermissions = $unresolved
        adminConsentUrl = $consentUrl
        adminConsentGrantedForApplicationRoles = [bool]$GrantApplicationAdminConsent
    }
}

$summaryPath = Join-Path $OutputDirectory 'entra-bootstrap-summary.json'
$secretsPath = Join-Path $OutputDirectory 'github-secrets.json'
$summary | ConvertTo-Json -Depth 20 | Set-Content -Path $summaryPath -Encoding UTF8
$secretMap | ConvertTo-Json -Depth 20 | Set-Content -Path $secretsPath -Encoding UTF8

Write-Host ''
Write-Host 'Admin Consent URLs:' -ForegroundColor Green
foreach ($item in $summary) {
    Write-Host "  $($item.profile): $($item.adminConsentUrl)" -ForegroundColor Green
}
Write-Host ''
Write-Step "Wrote summary: $summaryPath"
Write-Step "Wrote local GitHub secret map: $secretsPath"
if ($unresolvedAll.Count -gt 0) {
    Write-Warning "Unresolved permissions: $($unresolvedAll -join '; ')"
}

if ($OpenAdminConsentUrls) {
    Write-Step 'Opening Admin Consent URLs in the default browser.'
    foreach ($item in $summary) {
        Start-Process $item.adminConsentUrl
        Start-Sleep -Seconds 2
    }
}

Write-Host ''
Write-Host 'Next steps:' -ForegroundColor Green
Write-Host '1. Confirm all three Admin Consent browser tabs.'
Write-Host '2. Return to entra-bootstrap.html.'
Write-Host "3. Upload this file in the browser secret-import section: $secretsPath"
Write-Host '4. The browser page sets the GitHub repository secrets and dispatches the final permission check.'
Write-Host 'Keep .out/ private. Do not commit certificates or JSON secret files.' -ForegroundColor Yellow
