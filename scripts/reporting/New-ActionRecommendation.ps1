[CmdletBinding()]
param([string]$ModelPath='data/processed/agent-governance-model.json',[string]$OutputPath='data/processed/action-recommendations.json')
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
function Arr($v){if($null -eq $v){@()}elseif($v -is [Array]){@($v)}else{@($v)}}
$dir=Split-Path -Parent $OutputPath; if($dir -and -not(Test-Path $dir)){New-Item -ItemType Directory -Path $dir -Force|Out-Null}
$model=if(Test-Path $ModelPath){Get-Content $ModelPath -Raw|ConvertFrom-Json}else{$null}
$recommendations=New-Object System.Collections.Generic.List[object]; $i=1
if($model){
  foreach($agent in @(Arr $model.agents)){if($agent.risk -eq 'High' -or $agent.status -match 'Review'){$recommendations.Add([pscustomobject]@{id=('ACT-{0:000}'-f $i);severity='High';appProfile='AgentStatusAction';action='Review / Limit prüfen';target=$agent.name;reason='Live erkannter Agent/App-Kandidat benötigt Governance-Review.';requiresApproval=$true})|Out-Null;$i++}}
  foreach($probe in @((Arr $model.domainProbes)|?{$_.status -match 'blocked|missing|error|not-implemented|requires|partial'}|Select -First 12)){$severity=if($probe.status -match 'blocked|missing|error'){'High'}elseif($probe.status -match 'requires|partial'){'Medium'}else{'Info'};$recommendations.Add([pscustomobject]@{id=('ACT-{0:000}'-f $i);severity=$severity;appProfile='Reader';action='Datenquelle prüfen';target="$($probe.domain): $($probe.capability)";reason=$probe.message;requiresApproval=$false})|Out-Null;$i++}
}
if($recommendations.Count -eq 0){$recommendations.Add([pscustomobject]@{id='ACT-001';severity='Info';appProfile='Reader';action='Monitoring fortsetzen';target='Tenant';reason='Keine kritischen Findings aus Live-Daten ableitbar.';requiresApproval=$false})|Out-Null}
$recommendations|ConvertTo-Json -Depth 20|Set-Content $OutputPath -Encoding UTF8
Write-Host "Wrote $OutputPath"
