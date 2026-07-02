Set-StrictMode -Version Latest

$script:MicrosoftGraphAppId = '00000003-0000-0000-c000-000000000000'

function ConvertTo-GRCSecureStringFromPlainText {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$PlainText
    )

    ConvertTo-SecureString $PlainText -AsPlainText -Force
}

function Connect-GRCGraph {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$TenantId,
        [Parameter(Mandatory)][string]$ClientId,
        [Parameter(Mandatory)][string]$CertificateBase64,
        [Parameter(Mandatory)][securestring]$CertificatePassword
    )

    if (-not (Get-Module -ListAvailable -Name Microsoft.Graph.Authentication)) {
        throw 'Microsoft.Graph.Authentication is not available on this runner. Run the requirements workflow first.'
    }

    Import-Module Microsoft.Graph.Authentication -ErrorAction Stop

    $bytes = [Convert]::FromBase64String($CertificateBase64)
    $cert = [System.Security.Cryptography.X509Certificates.X509Certificate2]::new(
        $bytes,
        $CertificatePassword,
        [System.Security.Cryptography.X509Certificates.X509KeyStorageFlags]::EphemeralKeySet
    )

    Connect-MgGraph -TenantId $TenantId -ClientId $ClientId -Certificate $cert -NoWelcome -ErrorAction Stop
}

function Connect-GRCGraphDelegated {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$TenantId,
        [string[]]$Scopes = @('Application.ReadWrite.All','AppRoleAssignment.ReadWrite.All','Directory.Read.All')
    )

    if (-not (Get-Module -ListAvailable -Name Microsoft.Graph.Authentication)) {
        throw 'Microsoft.Graph.Authentication is not available. Install it in Cloud Shell or run the requirements workflow on a runner.'
    }

    Import-Module Microsoft.Graph.Authentication -ErrorAction Stop
    Connect-MgGraph -TenantId $TenantId -Scopes $Scopes -NoWelcome -ErrorAction Stop
}

function Invoke-GRCGraphRequest {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][ValidateSet('GET','POST','PATCH','DELETE')][string]$Method,
        [Parameter(Mandatory)][string]$Uri,
        [AllowNull()][object]$Body = $null
    )

    $params = @{
        Method = $Method
        Uri = $Uri
        ErrorAction = 'Stop'
    }

    if ($null -ne $Body) {
        $params.Body = ($Body | ConvertTo-Json -Depth 50)
        $params.ContentType = 'application/json'
    }

    Invoke-MgGraphRequest @params
}

function Invoke-GRCGraphGet {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$Uri
    )

    Invoke-GRCGraphRequest -Method GET -Uri $Uri
}

function Get-GRCGraphServicePrincipal {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$AppId
    )

    $encodedFilter = [uri]::EscapeDataString("appId eq '$AppId'")
    $response = Invoke-GRCGraphGet -Uri "https://graph.microsoft.com/v1.0/servicePrincipals?`$filter=$encodedFilter"
    $sp = @($response.value | Select-Object -First 1)
    if (-not $sp) {
        throw "Service principal for appId '$AppId' was not found."
    }

    $sp
}

function Get-GRCGraphAppRole {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]$ServicePrincipal,
        [Parameter(Mandatory)][string]$PermissionValue
    )

    $role = @($ServicePrincipal.appRoles | Where-Object { $_.value -eq $PermissionValue -and $_.allowedMemberTypes -contains 'Application' } | Select-Object -First 1)
    if (-not $role) {
        throw "Application permission '$PermissionValue' was not found on resource appId '$($ServicePrincipal.appId)'."
    }

    $role
}

function Get-GRCPermissionManifest {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][ValidateSet('Reader','AgentStatusAction','BillingChange')][string]$AppProfile,
        [string]$RepositoryRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
    )

    $fileName = switch ($AppProfile) {
        'Reader' { 'reader.permissions.json' }
        'AgentStatusAction' { 'agent-status.permissions.json' }
        'BillingChange' { 'billing-change.permissions.json' }
    }

    $path = Join-Path $RepositoryRoot "config/permissions/$fileName"
    if (-not (Test-Path $path)) {
        throw "Permission manifest not found: $path"
    }

    Get-Content -Path $path -Raw | ConvertFrom-Json
}

function New-GRCGraphApplication {
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory)][string]$DisplayName,
        [ValidateSet('AzureADMyOrg','AzureADMultipleOrgs')][string]$SignInAudience = 'AzureADMyOrg'
    )

    $body = @{
        displayName = $DisplayName
        signInAudience = $SignInAudience
    }

    if ($PSCmdlet.ShouldProcess($DisplayName, 'Create Microsoft Entra application registration')) {
        Invoke-GRCGraphRequest -Method POST -Uri 'https://graph.microsoft.com/v1.0/applications' -Body $body
    }
}

function Set-GRCGraphApplicationCertificate {
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory)][string]$ApplicationObjectId,
        [Parameter(Mandatory)][string]$CertificateDisplayName,
        [Parameter(Mandatory)][string]$CertificateRawDataBase64,
        [Parameter(Mandatory)][string]$CustomKeyIdentifierBase64,
        [Parameter(Mandatory)][datetime]$StartDateTime,
        [Parameter(Mandatory)][datetime]$EndDateTime
    )

    $keyCredential = @{
        displayName = $CertificateDisplayName
        type = 'AsymmetricX509Cert'
        usage = 'Verify'
        key = $CertificateRawDataBase64
        customKeyIdentifier = $CustomKeyIdentifierBase64
        startDateTime = $StartDateTime.ToUniversalTime().ToString('o')
        endDateTime = $EndDateTime.ToUniversalTime().ToString('o')
    }

    $body = @{ keyCredentials = @($keyCredential) }

    if ($PSCmdlet.ShouldProcess($ApplicationObjectId, 'Attach certificate key credential')) {
        Invoke-GRCGraphRequest -Method PATCH -Uri "https://graph.microsoft.com/v1.0/applications/$ApplicationObjectId" -Body $body | Out-Null
    }
}

function Set-GRCGraphApplicationPermissions {
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory)][string]$ApplicationObjectId,
        [Parameter(Mandatory)][ValidateSet('Reader','AgentStatusAction','BillingChange')][string]$AppProfile,
        [string]$RepositoryRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
    )

    $manifest = Get-GRCPermissionManifest -AppProfile $AppProfile -RepositoryRoot $RepositoryRoot
    $graphSp = Get-GRCGraphServicePrincipal -AppId $script:MicrosoftGraphAppId
    $resourceAccess = New-Object System.Collections.Generic.List[object]
    $skipped = New-Object System.Collections.Generic.List[object]

    foreach ($permission in $manifest.permissions) {
        if ($permission.resource -ne 'Microsoft Graph') {
            $skipped.Add([pscustomobject]@{
                resource = $permission.resource
                permission = $permission.permission
                reason = 'Non-Microsoft Graph permission is tracked in the manifest but not applied through requiredResourceAccess.'
            }) | Out-Null
            continue
        }

        if ($permission.permission -match 'Placeholder') {
            $skipped.Add([pscustomobject]@{
                resource = $permission.resource
                permission = $permission.permission
                reason = 'Placeholder permission. It must be replaced by a validated API permission before bootstrap can apply it.'
            }) | Out-Null
            continue
        }

        $role = Get-GRCGraphAppRole -ServicePrincipal $graphSp -PermissionValue $permission.permission
        $resourceAccess.Add(@{
            id = $role.id
            type = 'Role'
        }) | Out-Null
    }

    $body = @{
        requiredResourceAccess = @(
            @{
                resourceAppId = $script:MicrosoftGraphAppId
                resourceAccess = @($resourceAccess)
            }
        )
    }

    if ($PSCmdlet.ShouldProcess($ApplicationObjectId, "Set requiredResourceAccess for $AppProfile")) {
        Invoke-GRCGraphRequest -Method PATCH -Uri "https://graph.microsoft.com/v1.0/applications/$ApplicationObjectId" -Body $body | Out-Null
    }

    [pscustomobject]@{
        appProfile = $AppProfile
        appliedGraphApplicationPermissions = @($resourceAccess).Count
        skippedPermissions = @($skipped)
        adminConsentRequired = $true
    }
}

function Get-GRCAdminConsentUrl {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$TenantIdOrDomain,
        [Parameter(Mandatory)][string]$ClientId
    )

    "https://login.microsoftonline.com/$TenantIdOrDomain/adminconsent?client_id=$ClientId"
}

function Test-GRCUserAppAssignment {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$UserUpn,
        [Parameter(Mandatory)][string]$AppClientId
    )

    Write-Verbose "Checking App Role Assignment for UPN - $UserUpn on App ClientId - $AppClientId"
    
    $user = $null
    try {
        $encodedUpn = [uri]::EscapeDataString($UserUpn)
        $user = Invoke-GRCGraphGet -Uri "https://graph.microsoft.com/v1.0/users/$encodedUpn"
    } catch {
        Write-Warning "User '$UserUpn' could not be resolved in Microsoft Entra ID - $_"
        return $false
    }
    
    if (-not $user -or -not $user.id) {
        return $false
    }
    $userId = $user.id

    $sp = $null
    try {
        $sp = Get-GRCGraphServicePrincipal -AppId $AppClientId
    } catch {
        Write-Warning "Service Principal for App ClientId '$AppClientId' not found - $_"
        return $false
    }
    
    $spId = $sp.id

    $assignments = Invoke-GRCGraphGet -Uri "https://graph.microsoft.com/v1.0/servicePrincipals/$spId/appRoleAssignedTo?`$top=999"
    if (-not $assignments -or -not $assignments.value) {
        Write-Verbose "No users or groups assigned to the application."
        return $false
    }

    $userAssignment = $assignments.value | Where-Object { $_.principalId -eq $userId }
    if ($userAssignment) {
        Write-Verbose "User is directly assigned to the application."
        return $true
    }

    $assignedGroups = $assignments.value | Where-Object { $_.principalType -eq 'Group' }
    foreach ($group in $assignedGroups) {
        $groupId = $group.principalId
        try {
            $members = Invoke-GRCGraphGet -Uri "https://graph.microsoft.com/v1.0/groups/$groupId/members?`$top=999"
            if ($members -and $members.value -and ($members.value | Where-Object { $_.id -eq $userId })) {
                Write-Verbose "User is assigned via Group membership ($($group.principalDisplayName))."
                return $true
            }
        } catch {
            Write-Warning "Failed to check membership of group $groupId - $_"
        }
    }

    return $false
}

Export-ModuleMember -Function ConvertTo-GRCSecureStringFromPlainText, Connect-GRCGraph, Connect-GRCGraphDelegated, Invoke-GRCGraphRequest, Invoke-GRCGraphGet, Get-GRCGraphServicePrincipal, Get-GRCGraphAppRole, Get-GRCPermissionManifest, New-GRCGraphApplication, Set-GRCGraphApplicationCertificate, Set-GRCGraphApplicationPermissions, Get-GRCAdminConsentUrl, Test-GRCUserAppAssignment
