<#
.SYNOPSIS
    Creates or updates Agent Compliance Entra app registrations and local certificate material.
.DESCRIPTION
    Run in PowerShell 7, Windows PowerShell, Azure Cloud Shell, or a local admin workstation with Microsoft.Graph.Authentication.
    The script:
    - ensures Microsoft Graph and WorkIQ resource service principals are available,
    - creates/updates Reader, AgentStatusAction and BillingChange app registrations,
    - resolves Graph/WorkIQ permission IDs dynamically,
    - adds a fresh certificate credential to each app registration,
    - writes local GitHub secret helper files.

    Important:
    - The WorkIQ service principal is a tenant prerequisite only.
    - It is not one of our apps and receives no certificate or GitHub secret.
    - Certificate based app-only auth only uses Application permissions.
    - Delegated scopes are added as app registration consent metadata for delegated flows.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$TenantId,
    [Parameter(Mandatory)][string]$TenantDomain,
    [string]$GitHubRepository = '',
    [string]$AppPrefix = 'Agent Compliance Community',
    [string]$OutputDirectory = '.out/entra-bootstrap',
    [ValidateRange(1,2)][int]$CertificateYears = 1,
    [switch]$GrantApplicationAdminConsent,
    [switch]$AllowUnresolvedPermissions
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Write-Step {
    param([string]$Message)
    Write-Host "[entra-bootstrap] $Message" -ForegroundColor Cyan
}

function Get-GrcObjectProperty {
    param(
        [Parameter(Mandatory=$false)]$InputObject,
        [Parameter(Mandatory)][string]$Name,
        $Default = $null
    )

    if ($null -eq $InputObject) { return $Default }

    if ($InputObject -is [System.Collections.IDictionary]) {
        if ($InputObject.Contains($Name)) { return $InputObject[$Name] }
        return $Default
    }

    $property = $InputObject.PSObject.Properties[$Name]
    if ($null -ne $property) { return $property.Value }

    return $Default
}

function ConvertTo-UrlFilterValue {
    param([string]$Value)
    return $Value.Replace("'", "''")
}

function Invoke-GraphPagedGet {
    param([Parameter(Mandatory)][string]$Uri)

    $items = @()
    $next = $Uri

    while ($next) {
        $page = Invoke-MgGraphRequest -Method GET -Uri $next -ErrorAction Stop
        $value = Get-GrcObjectProperty -InputObject $page -Name 'value' -Default @()
        if ($null -ne $value) { $items += @($value) }
        $next = Get-GrcObjectProperty -InputObject $page -Name '@odata.nextLink' -Default $null
    }

    return @($items)
}

function Get-ServicePrincipalByAppId {
    param([Parameter(Mandatory)][string]$AppId)

    $filter = [uri]::EscapeDataString("appId eq '$AppId'")
    $items = Invoke-GraphPagedGet -Uri "https://graph.microsoft.com/v1.0/servicePrincipals?`$filter=$filter&`$select=id,appId,displayName"
    if (@($items).Count -lt 1) { return $null }

    $first = @($items)[0]
    $spId = Get-GrcObjectProperty -InputObject $first -Name 'id' -Default $null
    if (-not $spId) { return $first }

    $detailUri = "https://graph.microsoft.com/v1.0/servicePrincipals/$($spId)?`$select=id,appId,displayName,appRoles,oauth2PermissionScopes"
    return Invoke-MgGraphRequest -Method GET -Uri $detailUri -ErrorAction Stop
}

function Ensure-ServicePrincipalByAppId {
    param(
        [Parameter(Mandatory)][string]$AppId,
        [string]$Name = $AppId
    )

    $sp = Get-ServicePrincipalByAppId -AppId $AppId
    if ($sp) {
        Write-Step "Service principal available: $Name"
        return $sp
    }

    Write-Step "Creating service principal prerequisite: $Name"
    Invoke-MgGraphRequest -Method POST -Uri 'https://graph.microsoft.com/v1.0/servicePrincipals' -Body @{ appId = $AppId } -ErrorAction Stop | Out-Null
    Start-Sleep -Seconds 10

    $sp = Get-ServicePrincipalByAppId -AppId $AppId
    if (-not $sp) { throw "Service principal was not available after creation: $Name / $AppId" }

    Write-Step "Service principal created: $Name"
    return $sp
}

function Resolve-ResourceAccess {
    param(
        [Parameter(Mandatory)]$ResourceServicePrincipal,
        [string[]]$ApplicationPermissions = @(),
        [string[]]$DelegatedScopes = @(),
        [Parameter(Mandatory)][string]$ResourceName
    )

    $access = @()
    $unresolved = @()

    $appRoles = @(Get-GrcObjectProperty -InputObject $ResourceServicePrincipal -Name 'appRoles' -Default @())
    $scopes = @(Get-GrcObjectProperty -InputObject $ResourceServicePrincipal -Name 'oauth2PermissionScopes' -Default @())

    foreach ($permission in ($ApplicationPermissions | Sort-Object -Unique)) {
        $roleMatches = @(
            $appRoles | Where-Object {
                (Get-GrcObjectProperty -InputObject $_ -Name 'value' -Default '') -eq $permission -and
                @((Get-GrcObjectProperty -InputObject $_ -Name 'allowedMemberTypes' -Default @())) -contains 'Application'
            } | Select-Object -First 1
        )

        $role = if ($roleMatches.Count -gt 0) { $roleMatches[0] } else { $null }

        if ($role) {
            $access += @{
                id = Get-GrcObjectProperty -InputObject $role -Name 'id'
                type = 'Role'
            }
        }
        else {
            $unresolved += "$ResourceName application permission not found: $permission"
        }
    }

    foreach ($scopeName in ($DelegatedScopes | Sort-Object -Unique)) {
        $scopeMatches = @(
            $scopes | Where-Object {
                (Get-GrcObjectProperty -InputObject $_ -Name 'value' -Default '') -eq $scopeName
            } | Select-Object -First 1
        )

        $scope = if ($scopeMatches.Count -gt 0) { $scopeMatches[0] } else { $null }

        if ($scope) {
            $access += @{
                id = Get-GrcObjectProperty -InputObject $scope -Name 'id'
                type = 'Scope'
            }
        }
        else {
            $unresolved += "$ResourceName delegated scope not found: $scopeName"
        }
    }

    return [pscustomobject]@{
        access = @($access)
        unresolved = @($unresolved)
    }
}

function Format-GraphDateTime {
    param([Parameter(Mandatory)][datetime]$DateTime)
    return $DateTime.ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ssZ', [System.Globalization.CultureInfo]::InvariantCulture)
}

function New-LocalCertificateBundle {
    param(
        [Parameter(Mandatory)][string]$SubjectName,
        [Parameter(Mandatory)][string]$OutputBaseName,
        [Parameter(Mandatory)][string]$OutputDirectory,
        [int]$Years = 1
    )

    $resolvedOutput = $OutputDirectory
    if (-not [System.IO.Path]::IsPathRooted($resolvedOutput)) {
        $resolvedOutput = Join-Path (Get-Location).Path $resolvedOutput
    }

    New-Item -ItemType Directory -Path $resolvedOutput -Force | Out-Null

    $rsa = [System.Security.Cryptography.RSA]::Create(3072)
    $hashAlgorithm = [System.Security.Cryptography.HashAlgorithmName]::SHA256
    $padding = [System.Security.Cryptography.RSASignaturePadding]::Pkcs1
    $request = [System.Security.Cryptography.X509Certificates.CertificateRequest]::new("CN=$SubjectName", $rsa, $hashAlgorithm, $padding)
    $request.CertificateExtensions.Add([System.Security.Cryptography.X509Certificates.X509KeyUsageExtension]::new([System.Security.Cryptography.X509Certificates.X509KeyUsageFlags]::DigitalSignature, $false))

    $notBefore = [datetime]::UtcNow.AddMinutes(-5)
    $notAfter = $notBefore.AddYears($Years)

    $cert = $request.CreateSelfSigned([datetimeoffset]$notBefore, [datetimeoffset]$notAfter)

    $password = [Convert]::ToBase64String([System.Security.Cryptography.RandomNumberGenerator]::GetBytes(32))
    $pfxBytes = $cert.Export([System.Security.Cryptography.X509Certificates.X509ContentType]::Pfx, $password)
    $cerBytes = $cert.Export([System.Security.Cryptography.X509Certificates.X509ContentType]::Cert)

    $pfxPath = Join-Path $resolvedOutput "$OutputBaseName.pfx"
    $cerPath = Join-Path $resolvedOutput "$OutputBaseName.cer"
    [System.IO.File]::WriteAllBytes($pfxPath, $pfxBytes)
    [System.IO.File]::WriteAllBytes($cerPath, $cerBytes)

    return [pscustomobject]@{
        certificate = $cert
        password = $password
        pfxBase64 = [Convert]::ToBase64String($pfxBytes)
        cerBase64 = [Convert]::ToBase64String($cerBytes)
        pfxPath = $pfxPath
        cerPath = $cerPath
        startDateTime = Format-GraphDateTime -DateTime $notBefore
        endDateTime = Format-GraphDateTime -DateTime $notAfter
    }
}

function Get-ApplicationByDisplayName {
    param([Parameter(Mandatory)][string]$DisplayName)

    $safe = ConvertTo-UrlFilterValue -Value $DisplayName
    $filter = [uri]::EscapeDataString("displayName eq '$safe'")
    $items = Invoke-GraphPagedGet -Uri "https://graph.microsoft.com/v1.0/applications?`$filter=$filter&`$select=id,appId,displayName"
    if (@($items).Count -lt 1) { return $null }

    $first = @($items)[0]
    $appObjectId = Get-GrcObjectProperty -InputObject $first -Name 'id' -Default $null
    if (-not $appObjectId) { return $first }

    return Invoke-MgGraphRequest -Method GET -Uri "https://graph.microsoft.com/v1.0/applications/$($appObjectId)?`$select=id,appId,displayName,keyCredentials,requiredResourceAccess" -ErrorAction Stop
}

function Ensure-ApplicationRegistration {
    param(
        [Parameter(Mandatory)][string]$DisplayName,
        [Parameter(Mandatory)][array]$RequiredResourceAccess
    )

    $app = Get-ApplicationByDisplayName -DisplayName $DisplayName
    $body = @{
        requiredResourceAccess = @($RequiredResourceAccess)
    }

    if ($app) {
        Write-Step "Updating app registration: $DisplayName"
        Invoke-MgGraphRequest -Method PATCH -Uri "https://graph.microsoft.com/v1.0/applications/$((Get-GrcObjectProperty -InputObject $app -Name 'id'))" -Body $body -ErrorAction Stop | Out-Null
        return Get-ApplicationByDisplayName -DisplayName $DisplayName
    }

    Write-Step "Creating app registration: $DisplayName"
    $body.displayName = $DisplayName
    $body.signInAudience = 'AzureADMyOrg'
    Invoke-MgGraphRequest -Method POST -Uri 'https://graph.microsoft.com/v1.0/applications' -Body $body -ErrorAction Stop | Out-Null
    Start-Sleep -Seconds 5
    return Get-ApplicationByDisplayName -DisplayName $DisplayName
}

function Set-ApplicationCertificateCredential {
    param(
        [Parameter(Mandatory)]$Application,
        [Parameter(Mandatory)]$CertificateBundle,
        [Parameter(Mandatory)][string]$DisplayName
    )

    $applicationId = Get-GrcObjectProperty -InputObject $Application -Name 'id'
    if (-not $applicationId) { throw 'Application object id is missing.' }

    $keyCredential = @{
        customKeyIdentifier = [Convert]::ToBase64String($CertificateBundle.certificate.GetCertHash())
        displayName = $DisplayName
        endDateTime = $CertificateBundle.endDateTime
        key = $CertificateBundle.cerBase64
        startDateTime = $CertificateBundle.startDateTime
        type = 'AsymmetricX509Cert'
        usage = 'Verify'
    }

    Write-Step "Writing certificate credential: $DisplayName"
    # Deliberately replace the keyCredentials collection for these script-owned bootstrap applications.
    # Re-sending existing keyCredentials from Graph can fail because Graph does not return the key material.
    Invoke-MgGraphRequest -Method PATCH -Uri "https://graph.microsoft.com/v1.0/applications/$($applicationId)" -Body @{ keyCredentials = @($keyCredential) } -ErrorAction Stop | Out-Null
}

function Ensure-ClientServicePrincipal {
    param([Parameter(Mandatory)]$Application)

    $clientAppId = Get-GrcObjectProperty -InputObject $Application -Name 'appId'
    $displayName = Get-GrcObjectProperty -InputObject $Application -Name 'displayName' -Default $clientAppId
    if (-not $clientAppId) { throw 'Client appId is missing.' }

    $sp = Get-ServicePrincipalByAppId -AppId $clientAppId
    if ($sp) { return $sp }

    Write-Step "Creating client service principal for $displayName"
    Invoke-MgGraphRequest -Method POST -Uri 'https://graph.microsoft.com/v1.0/servicePrincipals' -Body @{ appId = $clientAppId } -ErrorAction Stop | Out-Null
    Start-Sleep -Seconds 8

    return Get-ServicePrincipalByAppId -AppId $clientAppId
}

function Grant-ApplicationRoles {
    param(
        [Parameter(Mandatory)]$ClientServicePrincipal,
        [Parameter(Mandatory)]$ResourceServicePrincipal,
        [Parameter(Mandatory)][array]$ResourceAccess
    )

    $clientSpId = Get-GrcObjectProperty -InputObject $ClientServicePrincipal -Name 'id'
    $resourceSpId = Get-GrcObjectProperty -InputObject $ResourceServicePrincipal -Name 'id'
    $resourceName = Get-GrcObjectProperty -InputObject $ResourceServicePrincipal -Name 'displayName' -Default $resourceSpId
    $clientName = Get-GrcObjectProperty -InputObject $ClientServicePrincipal -Name 'displayName' -Default $clientSpId

    $roleIds = @($ResourceAccess | Where-Object { $_.type -eq 'Role' } | ForEach-Object { [string]$_.id })
    if ($roleIds.Count -eq 0) { return }

    $existing = Invoke-GraphPagedGet -Uri "https://graph.microsoft.com/v1.0/servicePrincipals/$($clientSpId)/appRoleAssignments"

    foreach ($roleId in $roleIds) {
        $already = @(
            $existing | Where-Object {
                [string](Get-GrcObjectProperty -InputObject $_ -Name 'resourceId') -eq [string]$resourceSpId -and
                [string](Get-GrcObjectProperty -InputObject $_ -Name 'appRoleId') -eq $roleId
            }
        ).Count -gt 0

        if ($already) { continue }

        Write-Step "Granting application role on $resourceName to $clientName"
        Invoke-MgGraphRequest -Method POST -Uri "https://graph.microsoft.com/v1.0/servicePrincipals/$($clientSpId)/appRoleAssignments" -Body @{
            principalId = $clientSpId
            resourceId = $resourceSpId
            appRoleId = $roleId
        } -ErrorAction Stop | Out-Null
    }
}

if (-not (Get-Module -ListAvailable -Name Microsoft.Graph.Authentication)) {
    Install-Module Microsoft.Graph.Authentication -Scope CurrentUser -Force -AllowClobber
}
Import-Module Microsoft.Graph.Authentication -ErrorAction Stop

if (-not [System.IO.Path]::IsPathRooted($OutputDirectory)) {
    $OutputDirectory = Join-Path (Get-Location).Path $OutputDirectory
}
New-Item -ItemType Directory -Path $OutputDirectory -Force | Out-Null

$scopes = @('Application.ReadWrite.All','AppRoleAssignment.ReadWrite.All','Directory.Read.All')
Write-Step "Connecting to Microsoft Graph tenant $TenantId"
Connect-MgGraph -TenantId $TenantId -Scopes $scopes -NoWelcome -ErrorAction Stop

$graphAppId = '00000003-0000-0000-c000-000000000000'
$workIqAppId = 'fdcc1f02-fc51-4226-8753-f668596af7f7'

$graphSp = Ensure-ServicePrincipalByAppId -AppId $graphAppId -Name 'Microsoft Graph'
$workIqSp = Ensure-ServicePrincipalByAppId -AppId $workIqAppId -Name 'WorkIQ prerequisite resource'

$profiles = @(
    [pscustomobject]@{
        Name = 'Reader'
        DisplayName = "$AppPrefix - Reader"
        SecretPrefix = 'CAG_READER'
        Short = 'reader'
        GraphApplicationPermissions = @('Reports.Read.All','Directory.Read.All','Application.Read.All','AuditLog.Read.All','Policy.Read.All','AgentRegistration.Read.All')
        GraphDelegatedScopes = @('Reports.Read.All','AgentRegistration.Read.All','CopilotPackages.Read.All')
        WorkIqDelegatedScopes = @()
    },
    [pscustomobject]@{
        Name = 'AgentStatusAction'
        DisplayName = "$AppPrefix - Agent Status Action"
        SecretPrefix = 'CAG_STATUS'
        Short = 'status'
        GraphApplicationPermissions = @('Reports.Read.All','Directory.Read.All','Application.Read.All','AgentRegistration.ReadWrite.All','AgentRegistration.Read.All','CopilotPackages.ReadWrite.All')
        GraphDelegatedScopes = @('CopilotSettings-LimitedMode.Read','CopilotSettings-LimitedMode.ReadWrite','CopilotPolicySettings.Read','CopilotPolicySettings.ReadWrite','Reports.Read.All','AgentRegistration.ReadWrite.All','AgentRegistration.Read.All','CopilotPackages.Read.All','CopilotPackages.ReadWrite.All')
        WorkIqDelegatedScopes = @('WorkIQAgent.Ask')
    },
    [pscustomobject]@{
        Name = 'BillingChange'
        DisplayName = "$AppPrefix - Billing Change"
        SecretPrefix = 'CAG_BILLING'
        Short = 'billing'
        GraphApplicationPermissions = @('Reports.Read.All','Directory.Read.All','Application.Read.All','AgentRegistration.ReadWrite.All','AgentRegistration.Read.All','CopilotPackages.ReadWrite.All')
        GraphDelegatedScopes = @('CopilotSettings-LimitedMode.Read','CopilotSettings-LimitedMode.ReadWrite','CopilotPolicySettings.Read','CopilotPolicySettings.ReadWrite','Reports.Read.All','AgentRegistration.ReadWrite.All','AgentRegistration.Read.All','CopilotPackages.Read.All','CopilotPackages.ReadWrite.All')
        WorkIqDelegatedScopes = @('WorkIQAgent.Ask')
    }
)

$summary = @()
$secretMap = @{}
$unresolvedAll = @()

foreach ($profile in $profiles) {
    Write-Step "Processing profile: $($profile.Name)"

    $graphResolved = Resolve-ResourceAccess -ResourceServicePrincipal $graphSp -ApplicationPermissions $profile.GraphApplicationPermissions -DelegatedScopes $profile.GraphDelegatedScopes -ResourceName 'Microsoft Graph'
    $workIqResolved = Resolve-ResourceAccess -ResourceServicePrincipal $workIqSp -ApplicationPermissions @() -DelegatedScopes $profile.WorkIqDelegatedScopes -ResourceName 'WorkIQ'

    $unresolved = @($graphResolved.unresolved + $workIqResolved.unresolved)
    if ($unresolved.Count -gt 0) {
        $unresolvedAll += @($unresolved | ForEach-Object { "$($profile.Name): $_" })
        if (-not $AllowUnresolvedPermissions) {
            throw "Unresolved permissions for $($profile.Name): $($unresolved -join '; ')"
        }
    }

    $requiredResourceAccess = @()
    if (@($graphResolved.access).Count -gt 0) {
        $requiredResourceAccess += @{
            resourceAppId = $graphAppId
            resourceAccess = @($graphResolved.access)
        }
    }
    if (@($workIqResolved.access).Count -gt 0) {
        $requiredResourceAccess += @{
            resourceAppId = $workIqAppId
            resourceAccess = @($workIqResolved.access)
        }
    }

    $app = Ensure-ApplicationRegistration -DisplayName $profile.DisplayName -RequiredResourceAccess $requiredResourceAccess
    $clientSp = Ensure-ClientServicePrincipal -Application $app

    $certBundle = New-LocalCertificateBundle -SubjectName ($profile.DisplayName -replace '[^A-Za-z0-9 -]','') -OutputBaseName $profile.Short -OutputDirectory $OutputDirectory -Years $CertificateYears
    Set-ApplicationCertificateCredential -Application $app -CertificateBundle $certBundle -DisplayName "Agent Compliance Bootstrap $($profile.Name)"

    if ($GrantApplicationAdminConsent) {
        Grant-ApplicationRoles -ClientServicePrincipal $clientSp -ResourceServicePrincipal $graphSp -ResourceAccess $graphResolved.access
    }

    $clientId = Get-GrcObjectProperty -InputObject $app -Name 'appId'

    $secretMap["$($profile.SecretPrefix)_CLIENT_ID"] = $clientId
    $secretMap["$($profile.SecretPrefix)_CERTIFICATE_BASE64"] = $certBundle.pfxBase64
    $secretMap["$($profile.SecretPrefix)_CERTIFICATE_PASSWORD"] = $certBundle.password

    $summary += [pscustomobject]@{
        profile = $profile.Name
        displayName = $profile.DisplayName
        applicationObjectId = Get-GrcObjectProperty -InputObject $app -Name 'id'
        clientId = $clientId
        servicePrincipalId = Get-GrcObjectProperty -InputObject $clientSp -Name 'id'
        certificateFile = $certBundle.pfxPath
        certificateEndDateTime = $certBundle.endDateTime
        unresolvedPermissions = $unresolved
        adminConsentGrantedForApplicationRoles = [bool]$GrantApplicationAdminConsent
    }
}

$summaryPath = Join-Path $OutputDirectory 'entra-bootstrap-summary.json'
$secretsPath = Join-Path $OutputDirectory 'github-secrets.json'
$secretScriptPath = Join-Path $OutputDirectory 'set-github-secrets.ps1'

$summary | ConvertTo-Json -Depth 20 | Set-Content -Path $summaryPath -Encoding UTF8
$secretMap | ConvertTo-Json -Depth 20 | Set-Content -Path $secretsPath -Encoding UTF8

$scriptLines = @()
$scriptLines += '$ErrorActionPreference = ''Stop'''
if ($GitHubRepository) { $scriptLines += '$Repo = ''' + $GitHubRepository + '''' } else { $scriptLines += '$Repo = ''<OWNER>/<REPO>''' }
$scriptLines += '$Secrets = Get-Content -Raw -Path (Join-Path $PSScriptRoot ''github-secrets.json'') | ConvertFrom-Json'
$scriptLines += 'foreach ($p in $Secrets.PSObject.Properties) {'
$scriptLines += '    $p.Value | gh secret set $p.Name --repo $Repo'
$scriptLines += '}'
$scriptLines | Set-Content -Path $secretScriptPath -Encoding UTF8

Write-Step "Wrote summary: $summaryPath"
Write-Step "Wrote local GitHub secret values: $secretsPath"
Write-Step "Wrote GitHub secret setter: $secretScriptPath"

if ($unresolvedAll.Count -gt 0) {
    Write-Warning "Unresolved permissions: $($unresolvedAll -join '; ')"
}

Write-Host ''
Write-Host 'Next steps:' -ForegroundColor Green
Write-Host "1. Review $summaryPath"
Write-Host "2. Run $secretScriptPath after gh auth login"
Write-Host '3. Run GitHub workflow 20 - Check Permissions with skip_certificate_secret_checks=false'
