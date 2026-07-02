[CmdletBinding()]
param([string]$OutputPath = 'data/raw/DomainReadinessData.json')
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
Import-Module (Join-Path $repoRoot 'common/GRC-M365-Common.psm1') -Force
function Env([string]$Name){ [Environment]::GetEnvironmentVariable($Name) }
function Probe($Domain,$Capability,$Api,$Status,$Message,$Metrics,$Audience='CIO/CISO/CFO'){
  if($null -eq $Metrics){$Metrics=[pscustomobject]@{}}
  if($Metrics -is [hashtable]){$Metrics=[pscustomobject]$Metrics}
  [pscustomobject]@{domain=$Domain;capability=$Capability;api=$Api;status=$Status;message=$Message;audience=$Audience;metrics=$Metrics}
}
function Invoke-Probe($Domain,$Capability,$Api,$Uri,[scriptblock]$MetricBuilder,$Audience='CIO/CISO/CFO'){
  try{ $r=Invoke-GRCGraphGet -Uri $Uri; $m=if($MetricBuilder){& $MetricBuilder $r}else{[pscustomobject]@{}}; Probe $Domain $Capability $Api 'live' 'Read access successful.' $m $Audience }
  catch{ Probe $Domain $Capability $Api 'blocked-or-missing-permission' $_.Exception.Message ([pscustomobject]@{}) $Audience }
}
$dir=Split-Path -Parent $OutputPath; if($dir -and -not(Test-Path $dir)){New-Item -ItemType Directory -Path $dir -Force|Out-Null}
$tenantId=Env TENANT_ID; $tenantDomain=Env TENANT_DOMAIN; $clientId=Env CAG_READER_CLIENT_ID; $cert64=Env CAG_READER_CERTIFICATE_BASE64; $certPwd=Env CAG_READER_CERTIFICATE_PASSWORD
$probes=@()
if([string]::IsNullOrWhiteSpace($tenantId)-or[string]::IsNullOrWhiteSpace($clientId)-or[string]::IsNullOrWhiteSpace($cert64)-or[string]::IsNullOrWhiteSpace($certPwd)){
  $probes += Probe 'Platform' 'Reader App Authentication' 'GitHub Secrets / Entra App' 'not-configured' 'Reader app credentials are missing.' ([pscustomobject]@{}) 'CIO/CISO'
}else{
  try{
    $secure=ConvertTo-SecureString $certPwd -AsPlainText -Force
    Connect-GRCGraph -TenantId $tenantId -ClientId $clientId -CertificateBase64 $cert64 -CertificatePassword $secure|Out-Null
    $probes += Invoke-Probe 'M365 Admin & Copilot' 'Tenant organization' 'Microsoft Graph /organization' 'https://graph.microsoft.com/v1.0/organization' {param($r)$o=@($r.value|select -First 1);[pscustomobject]@{organization=$o.displayName;id=$o.id}} 'CIO/CFO'
    $probes += Invoke-Probe 'M365 Admin & Copilot' 'Subscribed SKUs / licensing' 'Microsoft Graph /subscribedSkus' 'https://graph.microsoft.com/v1.0/subscribedSkus' {param($r)[pscustomobject]@{skuCount=@($r.value).Count;consumedUnits=[int](@($r.value|Measure consumedUnits -Sum).Sum);enabledUnits=[int](@($r.value|%{$_.prepaidUnits.enabled}|Measure -Sum).Sum)}} 'CFO/CIO'
    $probes += Invoke-Probe 'M365 Admin & Copilot' 'User inventory' 'Microsoft Graph /users' "https://graph.microsoft.com/v1.0/users?`$top=999&`$select=id,displayName,userPrincipalName,accountEnabled,userType" {param($r)[pscustomobject]@{usersVisible=@($r.value).Count;enabledUsers=@($r.value|?{$_.accountEnabled -eq $true}).Count;guestUsers=@($r.value|?{$_.userType -eq 'Guest'}).Count}} 'CIO/CISO'
    $probes += Invoke-Probe 'Security & Governance' 'Groups and collaboration objects' 'Microsoft Graph /groups' "https://graph.microsoft.com/v1.0/groups?`$top=999&`$select=id,displayName,groupTypes,securityEnabled,mailEnabled" {param($r)[pscustomobject]@{groupsVisible=@($r.value).Count;m365Groups=@($r.value|?{$_.groupTypes -contains 'Unified'}).Count;securityGroups=@($r.value|?{$_.securityEnabled -eq $true}).Count}} 'CISO/CIO'
    $probes += Invoke-Probe 'Agent Registry & Governance' 'Application registrations' 'Microsoft Graph /applications' "https://graph.microsoft.com/v1.0/applications?`$top=999&`$select=id,appId,displayName,createdDateTime" {param($r)$c=@($r.value|?{$_.displayName -match '(?i)copilot|agent|openai|power|bot|assistant|studio'});[pscustomobject]@{applicationsVisible=@($r.value).Count;agentCandidates=$c.Count}} 'CISO/CIO'
    $probes += Invoke-Probe 'Agent Registry & Governance' 'Service principals / Enterprise apps' 'Microsoft Graph /servicePrincipals' "https://graph.microsoft.com/v1.0/servicePrincipals?`$top=999&`$select=id,appId,displayName,servicePrincipalType,accountEnabled" {param($r)$c=@($r.value|?{$_.displayName -match '(?i)copilot|agent|openai|power|bot|assistant|studio'});[pscustomobject]@{servicePrincipalsVisible=@($r.value).Count;agentCandidates=$c.Count;disabledServicePrincipals=@($r.value|?{$_.accountEnabled -eq $false}).Count}} 'CISO/CIO'
    $probes += Invoke-Probe 'Security & Governance' 'Directory roles' 'Microsoft Graph /directoryRoles' 'https://graph.microsoft.com/v1.0/directoryRoles' {param($r)[pscustomobject]@{activeDirectoryRoles=@($r.value).Count}} 'CISO'
    $probes += Invoke-Probe 'Security & Governance' 'Conditional Access policies' 'Microsoft Graph /identity/conditionalAccess/policies' 'https://graph.microsoft.com/v1.0/identity/conditionalAccess/policies' {param($r)[pscustomobject]@{conditionalAccessPolicies=@($r.value).Count;enabledPolicies=@($r.value|?{$_.state -eq 'enabled'}).Count;reportOnlyPolicies=@($r.value|?{$_.state -eq 'enabledForReportingButNotEnforced'}).Count}} 'CISO/CIO'
  }catch{ $probes += Probe 'Platform' 'Reader App Authentication' 'Microsoft Graph' 'error' $_.Exception.Message ([pscustomobject]@{}) 'CIO/CISO' }
  finally{try{Disconnect-MgGraph -ErrorAction SilentlyContinue|Out-Null}catch{}}
}
$probes += Probe 'M365 Usage Reporting' 'M365 usage report endpoints' 'Microsoft Graph /reports' 'not-implemented' 'This collector is not implemented yet. No usage values are estimated or faked.' ([pscustomobject]@{endpoint='getM365AppUserDetail';period='D30';source='not-implemented'}) 'CIO/CFO'
$probes += Probe 'Power Platform' 'Environment, app and flow inventory' 'Power Platform Admin APIs' 'not-implemented' 'Power Platform API collector is not implemented yet. No values are estimated or faked.' ([pscustomobject]@{}) 'CIO/CISO'
$probes += Probe 'Azure AI / BYO Models' 'Azure OpenAI, Foundry and token cost inventory' 'Azure Resource Manager / Cost Management' 'not-implemented' 'Azure AI and Cost Management collector is not implemented yet. Azure RBAC and ARM token flow are required.' ([pscustomobject]@{}) 'CFO/CIO'
$probes += Probe 'Cost & Billing' 'PAYG, budget and chargeback' 'Microsoft Graph billing + Azure Cost Management' 'partial' 'M365 SKU data is live via Graph. PAYG, budget and Azure token costs are not implemented yet.' ([pscustomobject]@{m365SkuSource='live';azureCostSource='not-implemented'}) 'CFO'
$probes += Probe 'Reports' 'Management and detail reporting' 'GitHub Pages / PDF rendering' 'live' 'Static dashboard and report pages are published. PDF rendering is attempted in workflow 40 and browser print is available.' ([pscustomobject]@{html=1;pdf='best-effort'}) 'CISO/CFO/CIO'
[pscustomobject]@{collector='Domain Readiness and Executive API Coverage';status='live-partial';generatedAt=(Get-Date).ToUniversalTime().ToString('o');tenantId=$tenantId;tenantDomain=$tenantDomain;probes=@($probes)}|ConvertTo-Json -Depth 50|Set-Content $OutputPath -Encoding UTF8
Write-Host "Wrote $OutputPath"
