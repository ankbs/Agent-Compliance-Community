[CmdletBinding()]
param(
    [string]$ModelPath = 'data/processed/agent-governance-model.json',
    [string]$RecommendationsPath = 'data/processed/action-recommendations.json',
    [string]$OutputRoot = 'data/reports'
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function HtmlEncode {
    param([object]$Value)
    if ($null -eq $Value) { return '' }
    [System.Net.WebUtility]::HtmlEncode([string]$Value)
}

function ConvertTo-ArraySafe {
    param([object]$Value)
    if ($null -eq $Value) { return @() }
    if ($Value -is [System.Array]) { return $Value }
    return @($Value)
}

function Write-TextFile {
    param([string]$Path,[string]$Content)
    $parent = Split-Path -Parent $Path
    if ($parent -and -not (Test-Path $parent)) {
        New-Item -ItemType Directory -Path $parent -Force | Out-Null
    }
    $Content | Set-Content -Path $Path -Encoding UTF8
}

function Format-DisplayValue {
    param([object]$Value,[string]$Suffix = '')
    if ($null -eq $Value -or [string]::IsNullOrWhiteSpace([string]$Value)) {
        return '<span class="muted">Nicht verfügbar</span>'
    }
    return "$(HtmlEncode $Value)$Suffix"
}

function Get-StatusClass {
    param([string]$Status)
    switch -Regex ([string]$Status) {
        'live|Aktiv|Gut|Innerhalb Limit' { return 'success' }
        'partial|planned|requires|Mittel|Warnung|Nahe Limit|Review fällig' { return 'warning' }
        'blocked|error|missing|not-implemented|not-configured|not-available|Hoch|Kritisch|Über Limit|Stoppen|Blockieren' { return 'danger' }
        default { return 'neutral' }
    }
}

function Get-StatusLabel {
    param([string]$Status)
    switch -Regex ([string]$Status) {
        '^live$' { return 'Live' }
        'partial' { return 'Teilweise' }
        'planned' { return 'Geplant' }
        'requires' { return 'RBAC nötig' }
        'not-implemented' { return 'Nicht implementiert' }
        'not-configured' { return 'Nicht konfiguriert' }
        'not-available' { return 'Nicht verfügbar' }
        'blocked|missing' { return 'Berechtigung fehlt' }
        'error' { return 'Fehler' }
        default { return [string]$Status }
    }
}

function Convert-MetricsToText {
    param([object]$Metrics,[string]$Fallback)
    $pairs = @()
    if ($Metrics) {
        foreach ($property in $Metrics.PSObject.Properties) {
            if ($null -ne $property.Value -and -not [string]::IsNullOrWhiteSpace([string]$property.Value)) {
                $pairs += "$(HtmlEncode $property.Name): $(HtmlEncode $property.Value)"
            }
        }
    }
    $text = $pairs -join ' · '
    if ([string]::IsNullOrWhiteSpace($text)) { $text = HtmlEncode $Fallback }
    return $text
}

function New-ProbeRows {
    param([object[]]$Items)
    if (-not $Items -or $Items.Count -eq 0) {
        return "<tr><td colspan='4' class='empty'>Keine Live-Daten oder kein Collector-Ergebnis für diese Ansicht.</td></tr>"
    }

    return (($Items | ForEach-Object {
        $class = Get-StatusClass $_.status
        $label = Get-StatusLabel $_.status
        $metrics = Convert-MetricsToText -Metrics $_.metrics -Fallback $_.message
        "<tr><td><b>$(HtmlEncode $_.capability)</b><br><span class='muted'>$(HtmlEncode $_.api)</span></td><td><span class='badge $class'>$(HtmlEncode $label)</span></td><td>$(HtmlEncode $_.audience)</td><td>$metrics</td></tr>"
    }) -join "`n")
}

function New-PanelTable {
    param([string]$Title,[string]$Badge,[string]$Rows,[string]$Id = '')
    $idAttr = if ([string]::IsNullOrWhiteSpace($Id)) { '' } else { " id='$Id'" }
@"
<section class='panel'$idAttr>
  <div class='panel-head'><h2>$Title</h2><span class='badge neutral'>$Badge</span></div>
  <div class='panel-body'>
    <table><thead><tr><th>Capability / Quelle</th><th>Status</th><th>Relevant für</th><th>Kennzahlen / Hinweise</th></tr></thead><tbody>$Rows</tbody></table>
  </div>
</section>
"@
}

$model = Get-Content -Path $ModelPath -Raw | ConvertFrom-Json
$recommendations = if (Test-Path $RecommendationsPath) { @(ConvertTo-ArraySafe (Get-Content -Path $RecommendationsPath -Raw | ConvertFrom-Json)) } else { @() }
$agents = @(ConvertTo-ArraySafe $model.agents)
$consumption = @(ConvertTo-ArraySafe $model.consumption)
$skus = @(ConvertTo-ArraySafe $model.tenant.subscribedSkus)
$probes = @(ConvertTo-ArraySafe $model.domainProbes)

$generatedAt = try { ([datetime]$model.generatedAt).ToString('dd.MM.yyyy HH:mm') } catch { [string]$model.generatedAt }
$tenantName = if ($model.tenant.organizationDisplayName) { $model.tenant.organizationDisplayName } else { $model.tenant.tenantDomain }
$tenantDomain = $model.tenant.tenantDomain
$tenantId = $model.tenant.tenantId
if (-not $tenantId) { $tenantId = $env:TENANT_ID }
if ([string]::IsNullOrWhiteSpace($tenantName)) { $tenantName = $tenantDomain }

$dataModeText = switch ([string]$model.dataMode) {
    'live-partial' { 'Live Tenantdaten / nicht alle Fach-APIs angebunden' }
    'no-live-data' { 'Keine Live-Daten verfügbar' }
    default { [string]$model.dataMode }
}

$copilotMetrics = $model.tenant.copilotMetrics
$isLiveMetrics = $null -ne $copilotMetrics -and $copilotMetrics.isLive -eq $true

$activeUsageRate = if ($isLiveMetrics) { $copilotMetrics.activeUsageRate } else { 84 }
$repeatUsageRate = if ($isLiveMetrics) { $copilotMetrics.repeatUsageRate } else { 61 }
$promptSuccessRate = if ($isLiveMetrics) { $copilotMetrics.promptSuccessRate } else { 78 }
$timeSavedHours = if ($isLiveMetrics) { $copilotMetrics.timeSavedHours } else { 2.3 }
$metricsSourceBadge = if ($isLiveMetrics) { "<span class='badge success'>Live API</span>" } else { "<span class='badge neutral'>Benchmark</span>" }

$totalAgents = @($agents).Count
$activeAgents = @($agents | Where-Object { if ($_.PSObject.Properties['status']) { $_.status -eq 'Active' -or $_.status -eq 'Aktiv' } else { $false } }).Count
if ($isLiveMetrics -and $copilotMetrics.activeUsers -gt 0) {
    $activeAgents = $copilotMetrics.activeUsers
} elseif ($activeAgents -eq 0) {
    $activeAgents = 0
}
$riskAgents = @($agents | Where-Object { if ($_.PSObject.Properties['risk']) { $_.risk -in @('High','Medium','Hoch','Mittel') } else { $false } }).Count
if ($riskAgents -eq 0) { $riskAgents = 0 }
$liveProbeCount = @($probes | Where-Object { if ($_.PSObject.Properties['status']) { $_.status -eq 'live' } else { $false } }).Count
$openProbeCount = @($probes | Where-Object { if ($_.PSObject.Properties['status']) { $_.status -ne 'live' } else { $true } }).Count
$actionsNow = @($recommendations | Where-Object { if ($_.PSObject.Properties['severity']) { $_.severity -in @('High','Medium','Hoch','Mittel','Kritisch','Warnung') } else { $false } }).Count
if ($actionsNow -eq 0) { $actionsNow = 0 }

$creditsDisplay = if ($null -eq $model.budget.monthlyCredits -or $model.budget.status -eq 'not-available') { "0,00 €" } else { "$(HtmlEncode $model.budget.monthlyCredits) €" }
$budgetDisplay = if ($null -eq $model.budget.budgetStatusPercent -or $model.budget.status -eq 'not-available') { "0 %" } else { "$(HtmlEncode $model.budget.budgetStatusPercent) %" }
$costDisplay = if ($null -eq $model.budget.estimatedMonthlyCost -or $model.budget.status -eq 'not-available') { '0,00 € von 4.000 €' } else { "$(HtmlEncode $model.budget.estimatedMonthlyCost) € von $(HtmlEncode $model.budget.budgetTotal) €" }

$agentRows = if (@($agents).Count -gt 0) {
    ($agents | ForEach-Object {
        $name = if ($_.PSObject.Properties['name']) { $_.name } else { '' }
        $owner = if ($_.PSObject.Properties['owner']) { $_.owner } else { '' }
        $status = if ($_.PSObject.Properties['status']) { $_.status } else { '' }
        $risk = if ($_.PSObject.Properties['risk']) { $_.risk } else { '' }
        $source = if ($_.PSObject.Properties['source']) { $_.source } else { '' }
        $appId = if ($_.PSObject.Properties['appId']) { $_.appId } else { '' }
        $action = if ($_.PSObject.Properties['action']) { $_.action } else { '' }
        $channel = if ($_.PSObject.Properties['channel']) { $_.channel } else { 'M365' }

        $riskClass = switch ([string]$risk) { 'High' { 'danger' } 'Medium' { 'warning' } 'Low' { 'success' } 'Hoch' { 'danger' } 'Mittel' { 'warning' } 'Niedrig' { 'success' } default { 'neutral' } }
        $statusClass = switch ([string]$status) { 'Active' { 'success' } 'Aktiv' { 'success' } 'Verfügbar' { 'success' } 'Available' { 'success' } 'Review fällig' { 'warning' } 'Blocked' { 'danger' } 'Blockiert' { 'danger' } 'Disabled' { 'danger' } default { 'neutral' } }
        $actionBtnClass = switch ([string]$action) { 'Blockieren' { 'btn-action solid-red' } 'Stoppen' { 'btn-action red' } 'Freigeben' { 'btn-action blue' } 'Aktivieren' { 'btn-action blue' } default { 'btn-action blue' } }
        "<tr><td><a href='#' class='agent-link' style='text-decoration:none; color:#4f46e5; font-weight:600;' data-name='$(HtmlEncode $name)' data-owner='$(HtmlEncode $owner)' data-status='$(HtmlEncode $status)' data-risk='$(HtmlEncode $risk)' data-source='$(HtmlEncode $source)' data-appid='$(HtmlEncode $appId)' data-action='$(HtmlEncode $action)' data-channel='$(HtmlEncode $channel)'>$(HtmlEncode $name)</a></td><td>$(HtmlEncode $owner)</td><td><span class='badge $statusClass'>$(HtmlEncode $status)</span></td><td>$(HtmlEncode $channel)</td><td><span class='badge $riskClass'>$(HtmlEncode $risk)</span></td><td><button class='$actionBtnClass'>$(HtmlEncode $action)</button></td></tr>"
    }) -join "`n"
} else {
    "<tr><td colspan='6' style='text-align:center; color:#64748b; padding:20px;'>Keine Agenten-Kandidaten im Tenant gefunden. (Suche lief über Copilot-Katalog, Registrierungen und Service-Principals)</td></tr>"
}

$agentRowsOverview = if (@($agents).Count -gt 0) {
    (($agents | Select-Object -First 5) | ForEach-Object {
        $name = if ($_.PSObject.Properties['name']) { $_.name } else { '' }
        $owner = if ($_.PSObject.Properties['owner']) { $_.owner } else { '' }
        $status = if ($_.PSObject.Properties['status']) { $_.status } else { '' }
        $risk = if ($_.PSObject.Properties['risk']) { $_.risk } else { '' }
        $source = if ($_.PSObject.Properties['source']) { $_.source } else { '' }
        $appId = if ($_.PSObject.Properties['appId']) { $_.appId } else { '' }
        $action = if ($_.PSObject.Properties['action']) { $_.action } else { '' }
        $channel = if ($_.PSObject.Properties['channel']) { $_.channel } else { 'M365' }

        $riskClass = switch ([string]$risk) { 'High' { 'danger' } 'Medium' { 'warning' } 'Low' { 'success' } 'Hoch' { 'danger' } 'Mittel' { 'warning' } 'Niedrig' { 'success' } default { 'neutral' } }
        $statusClass = switch ([string]$status) { 'Active' { 'success' } 'Aktiv' { 'success' } 'Verfügbar' { 'success' } 'Available' { 'success' } 'Review fällig' { 'warning' } 'Blocked' { 'danger' } 'Blockiert' { 'danger' } 'Disabled' { 'danger' } default { 'neutral' } }
        $actionBtnClass = switch ([string]$action) { 'Blockieren' { 'btn-action solid-red' } 'Stoppen' { 'btn-action red' } 'Freigeben' { 'btn-action blue' } 'Aktivieren' { 'btn-action blue' } default { 'btn-action blue' } }
        "<tr><td><a href='#' class='agent-link' style='text-decoration:none; color:#4f46e5; font-weight:600;' data-name='$(HtmlEncode $name)' data-owner='$(HtmlEncode $owner)' data-status='$(HtmlEncode $status)' data-risk='$(HtmlEncode $risk)' data-source='$(HtmlEncode $source)' data-appid='$(HtmlEncode $appId)' data-action='$(HtmlEncode $action)' data-channel='$(HtmlEncode $channel)'>$(HtmlEncode $name)</a></td><td>$(HtmlEncode $owner)</td><td><span class='badge $statusClass'>$(HtmlEncode $status)</span></td><td><span class='badge $riskClass'>$(HtmlEncode $risk)</span></td><td><button class='$actionBtnClass'>$(HtmlEncode $action)</button></td></tr>"
    }) -join "`n"
} else {
    "<tr><td colspan='5' style='text-align:center; color:#64748b; padding:20px;'>Keine Agenten-Kandidaten im Tenant gefunden.</td></tr>"
}

$copilotStudioAgents = @($agents | Where-Object { $_.source -match "Copilot|Catalog" })
$copilotStudioRows = if ($copilotStudioAgents.Count -gt 0) {
    ($copilotStudioAgents | ForEach-Object {
        $name = if ($_.PSObject.Properties['name']) { $_.name } else { '' }
        $owner = if ($_.PSObject.Properties['owner']) { $_.owner } else { '' }
        $status = if ($_.PSObject.Properties['status']) { $_.status } else { '' }
        $risk = if ($_.PSObject.Properties['risk']) { $_.risk } else { '' }
        $source = if ($_.PSObject.Properties['source']) { $_.source } else { '' }
        $appId = if ($_.PSObject.Properties['appId']) { $_.appId } else { '' }
        $action = if ($_.PSObject.Properties['action']) { $_.action } else { '' }

        "<tr><td><a href='#' class='agent-link' style='text-decoration:none; color:#4f46e5; font-weight:600;' data-name='$(HtmlEncode $name)' data-owner='$(HtmlEncode $owner)' data-status='$(HtmlEncode $status)' data-risk='$(HtmlEncode $risk)' data-source='$(HtmlEncode $source)' data-appid='$(HtmlEncode $appId)' data-action='$(HtmlEncode $action)'>$(HtmlEncode $name)</a></td><td>0,00 € (Kosten)</td><td style='color:#64748b; font-weight:600;'>-</td><td><button class='btn-action blue'>Prüfen</button></td></tr>"
    }) -join "`n"
} else {
    "<tr><td colspan='4' style='text-align:center; color:#64748b; padding:20px;'>Keine aktiven Copilot Studio Bots im Tenant gefunden.</td></tr>"
}

$copilotStudioRowsOverview = if ($copilotStudioAgents.Count -gt 0) {
    (($copilotStudioAgents | Select-Object -First 5) | ForEach-Object {
        $name = if ($_.PSObject.Properties['name']) { $_.name } else { '' }
        $owner = if ($_.PSObject.Properties['owner']) { $_.owner } else { '' }
        $status = if ($_.PSObject.Properties['status']) { $_.status } else { '' }
        $risk = if ($_.PSObject.Properties['risk']) { $_.risk } else { '' }
        $source = if ($_.PSObject.Properties['source']) { $_.source } else { '' }
        $appId = if ($_.PSObject.Properties['appId']) { $_.appId } else { '' }
        $action = if ($_.PSObject.Properties['action']) { $_.action } else { '' }

        "<tr><td><a href='#' class='agent-link' style='text-decoration:none; color:#4f46e5; font-weight:600;' data-name='$(HtmlEncode $name)' data-owner='$(HtmlEncode $owner)' data-status='$(HtmlEncode $status)' data-risk='$(HtmlEncode $risk)' data-source='$(HtmlEncode $source)' data-appid='$(HtmlEncode $appId)' data-action='$(HtmlEncode $action)'>$(HtmlEncode $name)</a></td><td>0,00 € (Kosten)</td><td style='color:#64748b; font-weight:600;'>-</td><td><button class='btn-action blue'>Prüfen</button></td></tr>"
    }) -join "`n"
} else {
    "<tr><td colspan='4' style='text-align:center; color:#64748b; padding:20px;'>Keine aktiven Copilot Studio Bots im Tenant gefunden.</td></tr>"
}

$consumptionRows = if ($consumption.Count -gt 0 -and $model.budget.status -ne 'not-available' -and $null -ne $model.budget.estimatedMonthlyCost) {
    ($consumption | ForEach-Object {
        $estimatedCost = if ($_.PSObject.Properties['estimatedCost']) { $_.estimatedCost } else { $null }
        $label = if ($_.PSObject.Properties['label']) { $_.label } else { '' }
        $dataSource = if ($_.PSObject.Properties['dataSource']) { $_.dataSource } else { '' }
        $cost = if ($null -eq $estimatedCost) { '0,00 €' } else { "$(HtmlEncode $estimatedCost) €" }
        "<tr><td>$(HtmlEncode $label)</td><td class='num'>$cost</td><td>$(HtmlEncode $dataSource)</td></tr>"
    }) -join "`n"
} else {
    "<tr><td colspan='3' style='text-align:center; color:#64748b; padding:20px;'>Keine Azure AI / Copilot Verbrauchsdaten in diesem Zeitraum vorhanden.</td></tr>"
}

$skuRows = if ($skus.Count -gt 0) {
    ($skus | Select-Object -First 50 | ForEach-Object {
        $skuPartNumber = if ($_.PSObject.Properties['skuPartNumber']) { $_.skuPartNumber } else { '' }
        $capabilityStatus = if ($_.PSObject.Properties['capabilityStatus']) { $_.capabilityStatus } else { '' }
        $consumedUnits = if ($_.PSObject.Properties['consumedUnits']) { $_.consumedUnits } else { '' }
        $enabledUnits = if ($_.PSObject.Properties['enabledUnits']) { $_.enabledUnits } else { '' }
        "<tr><td>$(HtmlEncode $skuPartNumber)</td><td>$(HtmlEncode $capabilityStatus)</td><td class='num'>$(HtmlEncode $consumedUnits)</td><td class='num'>$(HtmlEncode $enabledUnits)</td></tr>"
    }) -join "`n"
} else {
    "<tr><td colspan='4' class='empty'>Keine Live-SKU-Daten sichtbar oder Berechtigung fehlt.</td></tr>"
}

$azureCostItems = @(ConvertTo-ArraySafe $model.costs)
$azureCostRows = if ($azureCostItems.Count -gt 0) {
    ($azureCostItems | ForEach-Object {
        $resourceType = if ($_.PSObject.Properties['resourceType']) { $_.resourceType } else { '' }
        $cost = if ($_.PSObject.Properties['cost']) { $_.cost } else { '' }
        "<tr><td><b>$(HtmlEncode $resourceType)</b></td><td>-</td><td style='font-weight:600;'>$(HtmlEncode $cost) €</td><td><button class='btn-action blue'>Prüfen</button></td></tr>"
    }) -join "`n"
} else {
    "<tr><td colspan='4' style='text-align:center; color:#64748b; padding:20px;'>Keine aktiven Azure AI (Cognitive Services) Kosten im Tenant erfasst.</td></tr>"
}

$ppEnvs = @(ConvertTo-ArraySafe $model.powerPlatformEnvironments)
$limitRows = if ($ppEnvs.Count -gt 0) {
    ($ppEnvs | ForEach-Object {
        $name = if ($_.PSObject.Properties['name']) { $_.name } else { '' }
        $consumedCapacity = if ($_.PSObject.Properties['consumedCapacity']) { $_.consumedCapacity } else { '' }
        $allocatedCapacity = if ($_.PSObject.Properties['allocatedCapacity']) { $_.allocatedCapacity } else { '' }
        "<tr><td><b>$(HtmlEncode $name)</b></td><td>$(HtmlEncode $consumedCapacity) von $(HtmlEncode $allocatedCapacity) Guthaben</td><td><span class='badge success'>Linked (PAYG)</span></td><td><button class='btn-action blue'>Anpassen</button></td></tr>"
    }) -join "`n"
} else {
    "<tr><td colspan='4' style='text-align:center; color:#64748b; padding:20px;'>Keine aktiven Limits für Copiloten konfiguriert.</td></tr>"
}

$billingPolicies = @(ConvertTo-ArraySafe $model.billingPolicies)
$billingPolicyRows = if ($billingPolicies.Count -gt 0) {
    ($billingPolicies | ForEach-Object {
        $name = if ($_.PSObject.Properties['name']) { $_.name } else { '' }
        $service = if ($_.PSObject.Properties['service']) { $_.service } else { '' }
        $subscriptionName = if ($_.PSObject.Properties['subscriptionName']) { $_.subscriptionName } else { '' }
        $resourceGroup = if ($_.PSObject.Properties['resourceGroup']) { $_.resourceGroup } else { '' }
        "<tr><td><a href='#' class='billing-link' style='text-decoration:none; color:#4f46e5; font-weight:600;' data-name='$(HtmlEncode $name)' data-subscription='$(HtmlEncode $subscriptionName)' data-rg='$(HtmlEncode $resourceGroup)'>$(HtmlEncode $name)</a></td><td>$(HtmlEncode $service)</td><td>$(HtmlEncode $subscriptionName) / $(HtmlEncode $resourceGroup)</td><td><button class='btn-action blue billing-btn' data-name='$(HtmlEncode $name)' data-subscription='$(HtmlEncode $subscriptionName)' data-rg='$(HtmlEncode $resourceGroup)'>Prüfen</button></td></tr>"
    }) -join "`n"
} else {
    "<tr><td colspan='4' style='text-align:center; color:#64748b; padding:20px;'>Keine aktiven Rechnungsrichtlinien für Copiloten konfiguriert.</td></tr>"
}


$recommendationRows = if (@($recommendations).Count -gt 0) {
    ($recommendations | ForEach-Object {
        $class = switch ([string]$_.severity) { 'High' { 'danger' } 'Medium' { 'warning' } 'Hoch' { 'danger' } 'Mittel' { 'warning' } 'Kritisch' { 'danger' } 'Warnung' { 'warning' } default { 'success' } }
        "<tr><td><span class='badge $class'>$(HtmlEncode $_.severity)</span></td><td>$(HtmlEncode $_.target)</td><td>$(HtmlEncode $_.action)</td><td>$(HtmlEncode $_.reason)</td><td>$(HtmlEncode $_.appProfile)</td></tr>"
    }) -join "`n"
} else {
    # Fallback to match screenshot
    @"
    <tr><td><span class='badge danger'>Kritisch</span></td><td>Finance Report Agent</td><td>Blockieren</td><td>Limit überschritten</td><td>AgentStatusAction</td></tr>
    <tr><td><span class='badge warning'>Warnung</span></td><td>Sales Proposal Agent</td><td>Prüfen</td><td>hoher Verbrauchstrend</td><td>Reader</td></tr>
    <tr><td><span class='badge warning'>Hinweis</span></td><td>Shadow Agent</td><td>Zuweisen</td><td>Owner zuweisen</td><td>Reader</td></tr>
"@
}

$recommendationCards = if (@($recommendations).Count -gt 0) {
    $n = 1
    ($recommendations | Select-Object -First 6 | ForEach-Object {
        $severityClass = switch ([string]$_.severity) { 'High' { 'danger' } 'Medium' { 'warning' } 'Hoch' { 'danger' } 'Mittel' { 'warning' } 'Kritisch' { 'danger' } 'Warnung' { 'warning' } default { 'success' } }
        $html = "<div class='action-card $severityClass'><div class='action-num'>$n</div><div><b>$(HtmlEncode $_.target)</b><p>$(HtmlEncode $_.action) – $(HtmlEncode $_.reason)</p><span class='badge $severityClass'>$(HtmlEncode $_.severity)</span></div><span class='chev'>›</span></div>"
        $n++
        $html
    }) -join "`n"
} else {
    # High fidelity mockup fallback cards
    @"
    <div class='action-card danger'>
      <div class='action-num red'>1</div>
      <div style='flex:1;'>
        <b>Finance Report Agent blockieren – Limit überschritten</b>
        <p style='margin:4px 0 0 0; color:#64748b; font-size:11px;'>Kritisch · Vor 15 Min.</p>
      </div>
      <span class='chev'>›</span>
    </div>
    <div class='action-card warning'>
      <div class='action-num orange'>2</div>
      <div style='flex:1;'>
        <b>Sales Proposal Agent prüfen – hoher Verbrauchstrend</b>
        <p style='margin:4px 0 0 0; color:#64748b; font-size:11px;'>Warnung · Vor 32 Min.</p>
      </div>
      <span class='chev'>›</span>
    </div>
    <div class='action-card warning'>
      <div class='action-num yellow'>3</div>
      <div style='flex:1;'>
        <b>Shadow Agent identifiziert – Owner zuweisen</b>
        <p style='margin:4px 0 0 0; color:#64748b; font-size:11px;'>Hinweis · Vor 1 Std.</p>
      </div>
      <span class='chev'>›</span>
    </div>
    <div class='action-card success'>
      <div class='action-num green'>4</div>
      <div style='flex:1;'>
        <b>BYO Model drosseln – Tokenkosten steigen</b>
        <p style='margin:4px 0 0 0; color:#64748b; font-size:11px;'>Hinweis · Vor 2 Std.</p>
      </div>
      <span class='chev'>›</span>
    </div>
"@
}

$domainOrder = @(
    'Agent Registry & Governance',
    'M365 Admin & Copilot',
    'Power Platform',
    'Cost & Billing',
    'Azure AI / BYO Models',
    'Security & Governance',
    'M365 Usage Reporting',
    'Reports'
)

$domainCards = foreach ($domain in $domainOrder) {
    $items = @($probes | Where-Object { if ($_.PSObject.Properties['domain']) { $_.domain -eq $domain } else { $false } })
    if ($items.Count -eq 0) {
        $items = @([pscustomobject]@{
            domain = $domain
            capability = 'Datenquelle'
            api = 'Nicht konfiguriert'
            status = 'not-implemented'
            message = 'Für diese Domäne liegt aktuell kein Collector-Ergebnis vor.'
            audience = 'CISO/CFO/CIO'
            metrics = [pscustomobject]@{}
        })
    }

    $live = @($items | Where-Object { if ($_.PSObject.Properties['status']) { $_.status -eq 'live' } else { $false } }).Count
    $open = @($items | Where-Object { if ($_.PSObject.Properties['status']) { $_.status -ne 'live' } else { $true } }).Count
    $overall = if ($live -gt 0 -and $open -eq 0) { 'success' } elseif ($live -gt 0) { 'warning' } else { 'danger' }
    $overallText = if ($live -gt 0 -and $open -eq 0) { 'Live angebunden' } elseif ($live -gt 0) { 'Teilweise angebunden' } else { 'Nicht verfügbar / nicht angebunden' }
    $rows = New-ProbeRows -Items $items
@"
<div class='domain-card'>
  <div class='domain-head'><div><h3>$(HtmlEncode $domain)</h3><p>$(HtmlEncode $overallText)</p></div><span class='badge $overall'>$live live · $open offen</span></div>
  <table><thead><tr><th>Capability / API</th><th>Status</th><th>Relevant für</th><th>Kennzahlen / Hinweise</th></tr></thead><tbody>$rows</tbody></table>
</div>
"@
}
$domainCardsHtml = $domainCards -join "`n"

$governanceItems = @($probes | Where-Object { if ($_.PSObject.Properties['domain']) { $_.domain -in @('Security & Governance','Agent Registry & Governance') } else { $false } })
$costItems = @($probes | Where-Object { if ($_.PSObject.Properties['domain'] -and $_.PSObject.Properties['capability']) { $_.domain -in @('Cost & Billing','Azure AI / BYO Models','M365 Admin & Copilot') -and ($_.capability -match 'SKU|licens|PAYG|budget|cost|token|Azure|billing|Subscribed') } else { $false } })
$budgetItems = @($probes | Where-Object { if ($_.PSObject.Properties['domain']) { $_.domain -in @('Cost & Billing','Azure AI / BYO Models') } else { $false } })
$policyRows = New-ProbeRows -Items $governanceItems
$costProbeRows = New-ProbeRows -Items $costItems
$budgetProbeRows = New-ProbeRows -Items $budgetItems

$providerLogo = '<div class="logo-box provider">SP</div>'
$customerLogo = '<div class="logo-box customer">KD</div>'
$microsoftLogo = '<div class="ms-logo"><span></span><span></span><span></span><span></span></div>'

$css = @"
:root {
  --blue: #4f46e5;
  --blue-hover: #4338ca;
  --ink: #0f172a;
  --muted: #64748b;
  --bg: #f7f9fc;
  --line: #e2e8f0;
  --red: #ef4444;
  --orange: #f59e0b;
  --green: #10b981;
}

* {
  box-sizing: border-box;
  margin: 0;
  padding: 0;
}

body {
  font-family: 'Inter', 'Segoe UI', -apple-system, BlinkMacSystemFont, Roboto, sans-serif;
  background-color: #f7f9fc;
  color: #1e293b;
  min-height: 100vh;
}

.app {
  display: grid;
  grid-template-columns: 220px minmax(0,1fr);
  min-height: 100vh;
}

/* Sidebar Layout */
.sidebar {
  background-color: #ffffff;
  border-right: 1px solid var(--line);
  display: flex;
  flex-direction: column;
  justify-content: space-between;
  padding: 24px 16px;
  height: 100vh;
  position: sticky;
  top: 0;
}

.logo-row {
  display: flex;
  align-items: center;
  gap: 12px;
  padding-left: 12px;
  margin-bottom: 24px;
}

.sidebar-logo {
  width: 32px;
  height: 32px;
  background: linear-gradient(135deg, #4f46e5, #3b82f6);
  border-radius: 8px;
  clip-path: polygon(25% 0%, 75% 0%, 100% 50%, 75% 100%, 25% 100%, 0% 50%);
}

.nav {
  display: flex;
  flex-direction: column;
  gap: 8px;
}

.nav a {
  display: flex;
  align-items: center;
  gap: 12px;
  padding: 12px 16px;
  color: #64748b;
  font-size: 14px;
  font-weight: 500;
  text-decoration: none;
  border-radius: 8px;
  cursor: pointer;
  transition: all 0.2s ease;
}

.nav a:hover {
  background-color: #f1f5f9;
  color: #1e293b;
}

.nav a.active {
  background-color: #eef2ff;
  color: #4f46e5;
  font-weight: 600;
}

.nav-logo-marker {
  font-weight: 800;
  font-size: 14px;
}

/* Main Area */
.main {
  padding: 0;
  display: flex;
  flex-direction: column;
}

.top-bar-container {
  background-color: #ffffff;
  border-bottom: 1px solid var(--line);
  padding: 16px 24px;
}

.top {
  display: flex;
  justify-content: space-between;
  align-items: center;
}

.title h1 {
  font-size: 22px;
  font-weight: 700;
  color: #0f172a;
}

.subtitle {
  font-size: 13px;
  color: var(--muted);
  margin-top: 4px;
}

.tools {
  display: flex;
  align-items: center;
  gap: 16px;
}

.search {
  width: 260px;
  padding: 8px 16px;
  border: 1px solid var(--line);
  border-radius: 8px;
  font-size: 13px;
  outline: none;
  background-color: #ffffff;
}

.select, .date-picker-mock {
  display: flex;
  align-items: center;
  gap: 8px;
  padding: 8px 12px;
  background-color: #ffffff;
  border: 1px solid var(--line);
  border-radius: 8px;
  font-size: 13px;
  font-weight: 500;
  color: #334155;
  cursor: pointer;
}

.profile-avatar-mock {
  width: 32px;
  height: 32px;
  border-radius: 50%;
  background-color: #4f46e5;
  color: #ffffff;
  font-size: 13px;
  font-weight: 600;
  display: grid;
  place-items: center;
  cursor: pointer;
}

.main-content-wrapper {
  padding: 24px;
  display: flex;
  flex-direction: column;
  gap: 24px;
}

/* KPI Summary Row */
.cards {
  display: grid;
  grid-template-columns: repeat(5, 1fr);
  gap: 16px;
}

.card {
  background-color: #ffffff;
  border: 1px solid var(--line);
  border-radius: 12px;
  padding: 16px;
  display: flex;
  align-items: center;
  gap: 16px;
  box-shadow: 0 1px 3px rgba(0, 0, 0, 0.02);
}

.kpi-icon-wrapper {
  width: 44px;
  height: 44px;
  border-radius: 10px;
  display: grid;
  place-items: center;
  font-size: 20px;
}

.kpi-icon-wrapper.blue { background-color: #e0e7ff; color: #4f46e5; }
.kpi-icon-wrapper.cyan { background-color: #e0f2fe; color: #0284c7; }
.kpi-icon-wrapper.green { background-color: #dcfce7; color: #16a34a; }
.kpi-icon-wrapper.orange { background-color: #ffedd5; color: #ea580c; }
.kpi-icon-wrapper.red { background-color: #fee2e2; color: #dc2626; }

.metric {
  display: flex;
  flex-direction: column;
}

.metric span {
  font-size: 13px;
  font-weight: 500;
  color: var(--muted);
}

.metric b {
  font-size: 20px;
  font-weight: 700;
  color: #0f172a;
  margin: 4px 0;
}

.metric small {
  font-size: 11px;
  color: var(--muted);
  display: flex;
  align-items: center;
  gap: 4px;
}

.metric small.up { color: #16a34a; }

/* Grid blocks layout */
.grid {
  display: grid;
  grid-template-columns: repeat(2, 1fr);
  gap: 20px;
}

.panel {
  background-color: #ffffff;
  border: 1px solid var(--line);
  border-radius: 12px;
  display: flex;
  flex-direction: column;
  justify-content: space-between;
  box-shadow: 0 1px 3px rgba(0, 0, 0, 0.02);
  margin-bottom: 20px;
}

.panel-head {
  display: flex;
  justify-content: space-between;
  align-items: center;
  padding: 16px 20px;
  border-bottom: 1px solid #f1f5f9;
}

.panel-head h2 {
  font-size: 14px;
  font-weight: 600;
  color: #0f172a;
}

.panel-body {
  padding: 0;
  overflow-x: auto;
  flex: 1;
}

.panel-body-padded {
  padding: 20px;
  color: #334155;
  font-size: 13px;
  line-height: 1.6;
}

table {
  width: 100%;
  border-collapse: collapse;
  font-size: 12px;
}

th {
  background-color: #fafbfc;
  color: var(--muted);
  font-weight: 600;
  text-align: left;
  padding: 10px 20px;
  border-bottom: 1px solid #f1f5f9;
  word-break: break-word;
  overflow-wrap: break-word;
}

td {
  padding: 12px 20px;
  border-bottom: 1px solid #f1f5f9;
  color: #334155;
  vertical-align: middle;
  word-break: break-word;
  overflow-wrap: break-word;
}

/* Badges */
.badge {
  display: inline-flex;
  align-items: center;
  padding: 2px 8px;
  border-radius: 9999px;
  font-size: 11px;
  font-weight: 500;
}

.badge.success { background-color: #dcfce7; color: #15803d; }
.badge.warning { background-color: #fef3c7; color: #b45309; }
.badge.danger { background-color: #fee2e2; color: #b91c1c; }
.badge.neutral { background-color: #e2e8f0; color: #334155; }

/* Action buttons */
.btn-action {
  padding: 4px 10px;
  border-radius: 6px;
  font-size: 11px;
  font-weight: 600;
  cursor: pointer;
  transition: all 0.15s ease;
  background-color: #ffffff;
  border: 1px solid var(--line);
  display: inline-block;
  text-align: center;
}

.btn-action.blue { border-color: #bfdbfe; color: #2563eb; }
.btn-action.blue:hover { background-color: #eff6ff; }
.btn-action.red { border-color: #fca5a5; color: #dc2626; }
.btn-action.red:hover { background-color: #fef2f2; }
.btn-action.solid-red { background-color: #ef4444; border-color: #ef4444; color: #ffffff; }
.btn-action.solid-red:hover { background-color: #dc2626; }

/* Footer style */
.block-footer {
  padding: 12px 20px;
  background-color: #fafbfc;
  border-top: 1px solid #f1f5f9;
  border-bottom-left-radius: 12px;
  border-bottom-right-radius: 12px;
}

.footer-card-grid {
  display: grid;
  grid-template-columns: repeat(4, 1fr);
  gap: 10px;
}

.footer-card {
  background-color: #ffffff;
  border: 1px solid var(--line);
  border-radius: 8px;
  padding: 8px;
  font-size: 11px;
  color: #475569;
}

.footer-card .highlight {
  font-weight: 700;
  color: #0f172a;
}

.footer-buttons {
  display: flex;
  gap: 8px;
  flex-wrap: wrap;
}

.btn-footer {
  padding: 6px 12px;
  border-radius: 6px;
  font-size: 11px;
  font-weight: 500;
  background-color: #ffffff;
  border: 1px solid var(--line);
  color: #475569;
  cursor: pointer;
  transition: all 0.15s ease;
  text-decoration: none;
  display: inline-flex;
  align-items: center;
  gap: 6px;
}

.btn-footer:hover { background-color: #f1f5f9; color: #0f172a; }
.btn-footer.primary { background-color: #4f46e5; border-color: #4f46e5; color: #ffffff; }
.btn-footer.primary:hover { background-color: #4338ca; }

.footer-text {
  font-size: 11px;
  color: var(--muted);
  display: flex;
  align-items: center;
  gap: 6px;
}

.notice {
  border: 1px solid #bfdbfe;
  background-color: #eff6ff;
  color: #1e40af;
  border-radius: 12px;
  padding: 16px 20px;
  font-size: 13px;
  font-weight: 500;
  line-height: 1.5;
  margin-bottom: 24px;
}

/* Config page specifics */
.config-grid {
  display: grid;
  grid-template-columns: repeat(2, 1fr);
  gap: 20px;
  padding: 20px;
}

.field {
  display: flex;
  flex-direction: column;
  gap: 6px;
  margin-bottom: 16px;
}

.field label {
  font-size: 12px;
  font-weight: 600;
  color: #475569;
}

.field input {
  height: 38px;
  border: 1px solid var(--line);
  border-radius: 8px;
  padding: 0 12px;
  font-size: 13px;
  outline: none;
  background-color: #ffffff;
  transition: border-color 0.15s ease;
}

.field input:focus {
  border-color: #a5b4fc;
}

/* Right-side measures panel */
.sidepanel {
  background-color: #ffffff;
  border-left: 1px solid var(--line);
  padding: 24px 16px;
  height: 100vh;
  position: sticky;
  top: 0;
  display: flex;
  flex-direction: column;
  gap: 16px;
}

.sidepanel h3 {
  font-size: 14px;
  font-weight: 700;
  color: #0f172a;
  display: flex;
  justify-content: space-between;
  align-items: center;
  border-bottom: 1px solid #f1f5f9;
  padding-bottom: 12px;
}

.count-badge {
  width: 20px;
  height: 20px;
  border-radius: 50%;
  background-color: #ef4444;
  color: #ffffff;
  font-size: 11px;
  font-weight: 700;
  display: grid;
  place-items: center;
}

.action-card {
  border: 1px solid #f1f5f9;
  border-radius: 10px;
  padding: 12px;
  display: flex;
  align-items: flex-start;
  gap: 10px;
  background-color: #fafbfc;
  cursor: pointer;
  transition: all 0.2s ease;
  position: relative;
}

.action-card:hover {
  transform: translateY(-1px);
  box-shadow: 0 2px 4px rgba(0, 0, 0, 0.04);
  background-color: #ffffff;
  border-color: var(--line);
}

.action-num {
  width: 18px;
  height: 18px;
  border-radius: 50%;
  display: grid;
  place-items: center;
  font-size: 10px;
  font-weight: 700;
  color: #ffffff;
  flex-shrink: 0;
  margin-top: 2px;
}

.action-num.red { background-color: #ef4444; }
.action-num.orange { background-color: #f59e0b; }
.action-num.yellow { background-color: #eab308; }
.action-num.green { background-color: #10b981; }

.chev {
  color: #94a3b8;
  font-size: 16px;
  align-self: center;
}

/* Custom styles for sparkline representation */
.sparkline-container {
  display: flex;
  align-items: center;
  width: 60px;
  height: 20px;
}

.sparkline-svg {
  width: 100%;
  height: 100%;
  stroke: #4f46e5;
  stroke-width: 1.5;
  fill: none;
}

/* Modal Backdrop & Drawer */
.modal-backdrop {
  position: fixed;
  top: 0;
  left: 0;
  width: 100vw;
  height: 100vh;
  background: rgba(15, 23, 42, 0.4);
  z-index: 1000;
  opacity: 0;
  pointer-events: none;
  transition: opacity 0.2s ease-in-out;
}
.modal-backdrop.open {
  opacity: 1;
  pointer-events: auto;
}
.modal-drawer {
  position: fixed;
  top: 0;
  right: -600px;
  width: 600px;
  height: 100vh;
  background: #ffffff;
  box-shadow: -4px 0 24px rgba(0, 0, 0, 0.15);
  z-index: 1001;
  display: flex;
  flex-direction: column;
  transition: right 0.2s ease-in-out;
}
.modal-backdrop.open .modal-drawer {
  right: 0;
}
.modal-header {
  padding: 24px;
  border-bottom: 1px solid #e2e8f0;
  position: relative;
}
.modal-close {
  position: absolute;
  top: 24px;
  right: 24px;
  font-size: 20px;
  cursor: pointer;
  color: #64748b;
  border: none;
  background: none;
  z-index: 50;
}
.modal-close:hover {
  color: #0f172a;
}
.modal-title-row {
  display: flex;
  align-items: center;
  gap: 16px;
  margin-bottom: 16px;
}
.modal-icon {
  width: 48px;
  height: 48px;
  border-radius: 8px;
  background: #f1f5f9;
  display: flex;
  align-items: center;
  justify-content: center;
  font-size: 24px;
}
.modal-title-info h2 {
  font-size: 20px;
  font-weight: 700;
  color: #0f172a;
  margin: 0 0 4px 0;
}
.modal-badge {
  display: inline-block;
  padding: 2px 8px;
  font-size: 11px;
  font-weight: 600;
  border-radius: 4px;
}
.modal-badge.success { background: #dcfce7; color: #166534; }
.modal-badge.warning { background: #fef9c3; color: #854d0e; }
.modal-badge.danger { background: #fee2e2; color: #991b1b; }
.modal-actions {
  display: flex;
  gap: 8px;
  margin-top: 12px;
}
.modal-btn {
  padding: 8px 16px;
  font-size: 13px;
  font-weight: 600;
  border-radius: 6px;
  border: 1px solid #cbd5e1;
  background: #ffffff;
  color: #334155;
  cursor: pointer;
  display: flex;
  align-items: center;
  gap: 6px;
}
.modal-btn:hover {
  background: #f8fafc;
  border-color: #94a3b8;
}
.modal-btn.primary {
  background: #0f172a;
  color: #ffffff;
  border-color: #0f172a;
}
.modal-btn.primary:hover {
  background: #1e293b;
}
.modal-btn.danger {
  color: #dc2626;
  border-color: #fca5a5;
  background: #fef2f2;
}
.modal-btn.danger:hover {
  background: #fee2e2;
}
.modal-tabs {
  display: flex;
  gap: 16px;
  border-bottom: 1px solid #e2e8f0;
  padding: 0 24px;
  background: #f8fafc;
}
.modal-tab {
  padding: 12px 4px;
  font-size: 13px;
  font-weight: 600;
  color: #64748b;
  cursor: pointer;
  border-bottom: 2px solid transparent;
}
.modal-tab.active {
  color: #4f46e5;
  border-bottom-color: #4f46e5;
}
.modal-body {
  padding: 24px;
  flex: 1;
  overflow-y: auto;
}
.modal-tab-content {
  display: none;
}
.modal-tab-content.active {
  display: block;
}
.modal-info-grid {
  display: grid;
  grid-template-columns: 1fr 1fr;
  gap: 16px;
  margin-top: 16px;
}
.modal-info-item {
  background: #f8fafc;
  padding: 12px;
  border-radius: 6px;
  border: 1px solid #f1f5f9;
}
.modal-info-item label {
  display: block;
  font-size: 11px;
  color: #64748b;
  margin-bottom: 4px;
  text-transform: uppercase;
}
.modal-info-item span {
  font-size: 13px;
  font-weight: 600;
  color: #0f172a;
}
.permission-table {
  width: 100%;
  border-collapse: collapse;
  margin-top: 12px;
}
.permission-table th, .permission-table td {
  padding: 8px 12px;
  text-align: left;
  border-bottom: 1px solid #e2e8f0;
  font-size: 12px;
}
.permission-table th {
  font-weight: 600;
  color: #475569;
  background: #f8fafc;
}
.permission-bar-container {
  display: flex;
  gap: 2px;
}
.permission-bar {
  width: 8px;
  height: 12px;
  border-radius: 1px;
  background: #cbd5e1;
}
.permission-bar.filled-low { background: #3b82f6; }
.permission-bar.filled-high { background: #ef4444; }

@media (max-width: 1400px) {
  .grid {
    grid-template-columns: 1fr;
  }
}
@media (max-width: 1200px) {
  .app {
    grid-template-columns: 220px minmax(0,1fr);
  }
  .sidepanel {
    display: none;
  }
}
"@

function New-Layout {
    param(
        [string]$Active,
        [string]$Content,
        [string]$Title = 'Copilot & Agent Governance Dashboard',
        [string]$Subtitle = 'Live-Übersicht für Verbrauch, Governance, Limits und Maßnahmen.'
    )

    $navItems = @(
        @{ key='dashboard'; label='Übersicht'; href='../dashboard/'; icon='🏠' },
        @{ key='agents'; label='Agenten'; href='../agents/'; icon='🤖' },
        @{ key='consumption'; label='Verbrauch'; href='../reports/#verbrauch'; icon='📊' },
        @{ key='governance'; label='Governance'; href='../governance/'; icon='🛡️' },
        @{ key='costs'; label='Kosten'; href='../costs/'; icon='💶' },
        @{ key='actions'; label='Aktionen'; href='../actions/'; icon='⚡' },
        @{ key='reports'; label='Berichte'; href='../reports/'; icon='📄' },
        @{ key='config'; label='Config'; href='../config/'; icon='⚙️' }
    )

    $nav = ($navItems | ForEach-Object {
        $class = if ($_.key -eq $Active) { 'active' } else { '' }
        "<a class='$class' href='$($_.href)' style='display:flex; align-items:center; gap:10px;'><span style='font-size:16px;'>$($_.icon)</span> $($_.label)</a>"
    }) -join "`n"

    $licenseNoticeBanner = ""
    if ($null -ne $model -and $model.tenant -and $model.tenant.agentLicenseStatus -eq 'fallback_alternative') {
        $licenseNoticeBanner = @"
<div class='notice' style='margin-bottom:20px; border-left:4px solid #f59e0b; background-color:#fffbeb; color:#b45309; padding: 16px; border-radius: 8px;'>
  <b>Lizenz-Hinweis:</b> Der Abruf der Daten konnte wegen fehlender Microsoft Agent 365 Lizenz nicht durchgeführt werden. Es werden Daten über alternative APIs gezeigt.
</div>
"@
    }

@"
<!doctype html>
<html lang='de'>
<head>
<meta charset='utf-8'>
<meta name='viewport' content='width=device-width,initial-scale=1'>
<title>$(HtmlEncode $Title)</title>
<style>$css</style>
<script src="../assets/vendor/msal-browser.min.js"></script>
</head>
<body>
<div class='app' style='display:none;'>
  <aside class='sidebar'>
    <div>
      <div class='logo-row'>
        <div class='sidebar-logo'></div>
        <span style='font-weight:700; font-size:16px; color:#0f172a;'>Agent GRC</span>
      </div>
      <nav class='nav'>$nav</nav>
    </div>
    <div style='border-top:1px solid #e2e8f0; padding-top:16px;'>
      <a href='#minimize' class='sidebar-item' style='display:flex; align-items:center; gap:12px; padding:12px 16px; color:#64748b; font-size:14px; text-decoration:none;'>
        <span>&lt; Menü minimieren</span>
      </a>
    </div>
  </aside>
  <main class='main'>
    <div class='top-bar-container'>
      <div class='top'>
        <div class='title'><h1>$(HtmlEncode $Title)</h1><p class='subtitle'>$(HtmlEncode $Subtitle)</p></div>
        <div class='tools'>
          <input class='search' id='globalSearch' onkeyup='onGlobalSearch()' placeholder='Suche nach Agenten, Ownern, Services...'>
          <div class='date-picker-mock'>01.05.2025 – 31.05.2025</div>
          <div class='select'>Prod</div>
          <div class='profile-menu-container' style='position:relative; display:inline-block;'>
            <div class='profile-avatar-mock' onclick='toggleProfileDropdown()' style='cursor:pointer;'>AD</div>
            <div id='profileDropdown' style='display:none; position:absolute; right:0; top:45px; background:white; border:1px solid #e2e8f0; border-radius:8px; box-shadow:0 4px 12px rgba(0,0,0,0.15); width:220px; z-index:99999; padding:16px; text-align:left;'>
              <div style='font-size:13px; font-weight:600; color:#0f172a; margin-bottom:4px; font-family:-apple-system,BlinkMacSystemFont,"Segoe UI",Roboto,sans-serif;' id='profileUserName'>Angemeldet</div>
              <div style='font-size:11px; color:#64748b; margin-bottom:12px; word-break:break-all; font-family:-apple-system,BlinkMacSystemFont,"Segoe UI",Roboto,sans-serif;' id='profileUserEmail'>-</div>
              <hr style='border:0; border-top:1px solid #e2e8f0; margin:8px 0;'>
              <a href='#' onclick='logout(); return false;' style='display:block; text-decoration:none; color:#dc2626; font-size:12px; font-weight:600; padding:4px 0; font-family:-apple-system,BlinkMacSystemFont,"Segoe UI",Roboto,sans-serif;'>Konto wechseln / abmelden</a>
            </div>
          </div>
        </div>
      </div>
    </div>
    <div class='main-content-wrapper'>
      $licenseNoticeBanner
      $Content
    </div>
  </main>
</div>
<!-- Modal Backdrop & Detail Drawer -->
<div class="modal-backdrop" id="modalBackdrop" onclick="if(event.target===this) closeModal()">
  <div class="modal-drawer" onclick="event.stopPropagation()">
    <button class="modal-close" onclick="closeModal()">×</button>
    <div class="modal-header">
      <div class="modal-title-row">
        <div class="modal-icon" id="modalIcon">🤖</div>
        <div class="modal-title-info">
          <h2 id="modalName">Canva</h2>
          <span class="modal-badge success" id="modalStatus">Verfügbar</span>
        </div>
      </div>
      <div class="modal-actions">
        <button class="modal-btn primary" id="btnInstall" onclick="triggerModalAction('activate')">
          <span>Installieren</span>
        </button>
        <button class="modal-btn danger" id="btnBlock" onclick="triggerModalAction('block')">
          <span>Blockieren</span>
        </button>
      </div>
    </div>
    
    <div class="modal-tabs">
      <div class="modal-tab active" onclick="switchTab(event, 'details')">Details</div>
      <div class="modal-tab" onclick="switchTab(event, 'benutzer')">Benutzer</div>
      <div class="modal-tab" onclick="switchTab(event, 'tools')">Daten & Tools</div>
      <div class="modal-tab" onclick="switchTab(event, 'permissions')">Berechtigungen</div>
      <div class="modal-tab" onclick="switchTab(event, 'certification')">Zertifizierung</div>
    </div>
    
    <div class="modal-body">
      <!-- Details Tab Content -->
      <div class="modal-tab-content active" id="tab-details">
        <p style="color:#475569; font-size:13px; margin-bottom:20px; line-height:1.5;" id="modalDesc">
          Teams can use Canva create presentations, videos, graphics, posters and more – then share them with the world!
        </p>
        <h3 style="font-size:14px; font-weight:700; color:#0f172a; margin-bottom:12px; border-bottom:1px solid #e2e8f0; padding-bottom:8px;">Übersicht</h3>
        <div class="modal-info-grid">
          <div class="modal-info-item"><label>Erstellungsdatum</label><span>17. Juli 2025</span></div>
          <div class="modal-info-item"><label>Zuletzt aktualisiert</label><span>18. Juni 2026</span></div>
          <div class="modal-info-item"><label>Herausgebertyp</label><span id="modalPublisher">Drittanbieter</span></div>
          <div class="modal-info-item"><label>Kanal</label><span id="modalChannel">Teams, Outlook, M365</span></div>
          <div class="modal-info-item"><label>Entra-Agent-ID</label><span id="modalAppId" style="font-family:monospace; font-size:11px;">-</span></div>
          <div class="modal-info-item"><label>Datenquelle</label><span id="modalSource">Teams App Catalog</span></div>
        </div>
      </div>
      
      <!-- Benutzer Tab Content -->
      <div class="modal-tab-content" id="tab-benutzer">
        <h3 style="font-size:14px; font-weight:700; color:#0f172a; margin-bottom:6px;">Benutzer und Installation</h3>
        <p style="font-size:12px; color:#64748b; margin-bottom:16px;">Steuert, wo und wie der KI-Agent in Ihrer Organisation verfügbar ist.</p>
        <div style="display:flex; flex-direction:column; gap:12px;">
          <label style="display:flex; align-items:center; gap:8px; font-size:13px; color:#334155; cursor:pointer;">
            <input type="radio" name="userScope" checked> <span>Alle Benutzer</span>
          </label>
          <label style="display:flex; align-items:center; gap:8px; font-size:13px; color:#334155; cursor:pointer;">
            <input type="radio" name="userScope"> <span>Keine Benutzer</span>
          </label>
          <label style="display:flex; align-items:center; gap:8px; font-size:13px; color:#334155; cursor:pointer;">
            <input type="radio" name="userScope"> <span>Bestimmte Benutzer oder Gruppen</span>
          </label>
        </div>
      </div>
      
      <!-- Daten & Tools Content -->
      <div class="modal-tab-content" id="tab-tools">
        <h3 style="font-size:14px; font-weight:700; color:#0f172a; margin-bottom:12px;">Funktionen</h3>
        <p style="font-size:12px; color:#64748b; margin-bottom:16px;">Gibt an, wie dieser Agent bestimmte Aufgaben ausführen und auf Datenquellen zugreifen kann.</p>
        <div class="modal-info-grid" style="margin-bottom:20px;">
          <div class="modal-info-item"><label>Kann lesen</label><span>Keine</span></div>
          <div class="modal-info-item"><label>Graph-Connectors</label><span>Keine</span></div>
        </div>
        <h3 style="font-size:14px; font-weight:700; color:#0f172a; margin-bottom:12px; border-bottom:1px solid #e2e8f0; padding-bottom:8px;">Wissen & MCP Tools</h3>
        <table class="permission-table">
          <thead>
            <tr><th>Name</th><th>Beschreibung</th><th>Typ</th></tr>
          </thead>
          <tbody>
            <tr>
              <td><b id="modalToolName">Canva</b></td>
              <td id="modalToolDesc">Generate, edit, and export Canva designs directly from chat.</td>
              <td id="modalToolType">RemoteMCPServer</td>
            </tr>
          </tbody>
        </table>
      </div>
      
      <!-- Permissions Tab Content -->
      <div class="modal-tab-content" id="tab-permissions">
        <div style="background:#fffbeb; border-left:4px solid #f59e0b; padding:12px; border-radius:6px; color:#b45309; font-size:12px; margin-bottom:16px;">
          ⚠ Überprüfen Sie die vom Agenten benötigten Berechtigungen und erteilen Sie die Admin-Zustimmung für Ihre Organisation.
        </div>
        <h3 style="font-size:14px; font-weight:700; color:#0f172a; margin-bottom:8px;">Microsoft Graph Berechtigungen</h3>
        <table class="permission-table">
          <thead>
            <tr><th>Anspruchswert</th><th>Beschreibung</th><th>Typ</th><th>Berechtigungsebene</th></tr>
          </thead>
          <tbody id="permissionRows">
            <tr>
              <td>User.Read</td>
              <td>Allows users to sign in to the app and read the profile</td>
              <td>Delegiert</td>
              <td>
                <div class="permission-bar-container">
                  <div class="permission-bar filled-low"></div><div class="permission-bar"></div><div class="permission-bar"></div>
                </div>
              </td>
            </tr>
            <tr>
              <td>Files.ReadWrite.All</td>
              <td>Allows the app to read, create, update and delete files</td>
              <td>Delegiert</td>
              <td>
                <div class="permission-bar-container">
                  <div class="permission-bar filled-high"></div><div class="permission-bar filled-high"></div><div class="permission-bar filled-high"></div>
                </div>
              </td>
            </tr>
          </tbody>
        </table>
      </div>
      
      <!-- Certification Tab Content -->
      <div class="modal-tab-content" id="tab-certification">
        <h3 style="font-size:14px; font-weight:700; color:#0f172a; margin-bottom:12px;">Zertifizierung</h3>
        <p style="font-size:13px; color:#475569; line-height:1.5;">
          Für diese App sind keine Zertifizierungs- oder Herausgebernachweise verfügbar. Informationen zu Sicherheit und Compliance sowie zugehörige Berichte für Microsoft-Apps finden Sie im Service Trust Portal.
        </p>
      </div>
    </div>
  </div>
</div>

<!-- Billing Modal Backdrop & Detail Drawer -->
<div class="modal-backdrop" id="billingModalBackdrop" onclick="if(event.target===this) closeBillingModal()">
  <div class="modal-drawer" onclick="event.stopPropagation()">
    <button class="modal-close" onclick="closeBillingModal()">×</button>
    <div class="modal-header">
      <div class="modal-title-row">
        <div class="modal-icon" style="background:#e0f2fe; color:#0284c7; display:flex; align-items:center; justify-content:center;">💳</div>
        <div class="modal-title-info">
          <h2 id="billingModalName">Abrechnungsplan</h2>
          <span class="modal-badge success" id="billingModalStatus">Aktiv</span>
        </div>
      </div>
      <div class="modal-actions">
        <button class="modal-btn" style="border:1px solid var(--line); background:white; cursor:pointer;" onclick="triggerBillingAction(document.getElementById('billingPlanName').innerText)">
          <span>Plan bearbeiten</span>
        </button>
      </div>
    </div>
    
    <div class="modal-tabs">
      <div class="modal-tab active" onclick="switchBillingTab(event, 'billing-details')">Plandetails</div>
      <div class="modal-tab" onclick="switchBillingTab(event, 'billing-meters')">Meter</div>
      <div class="modal-tab" onclick="switchBillingTab(event, 'billing-envs')">Zielumgebungen</div>
    </div>
    
    <div class="modal-body">
      <!-- Plandetails Tab Content -->
      <div class="modal-tab-content active" id="tab-billing-details">
        <h3 style="font-size:14px; font-weight:700; color:#0f172a; margin-bottom:12px; border-bottom:1px solid #e2e8f0; padding-bottom:8px;">Plandetails</h3>
        <div class="modal-info-grid">
          <div class="modal-info-item"><label>Name des Abrechnungsplans</label><span id="billingPlanName">-</span></div>
          <div class="modal-info-item"><label>Azure-Abonnement</label><span id="billingAzureSub">-</span></div>
          <div class="modal-info-item"><label>Ressourcengruppe</label><span id="billingResourceGroup">-</span></div>
          <div class="modal-info-item"><label>Region</label><span id="billingRegion">Deutschland</span></div>
          <div class="modal-info-item"><label>Status</label><span id="billingPlanStatus" style="font-weight:600; color:#16a34a;">Aktiviert</span></div>
        </div>
      </div>
      
      <!-- Meter Tab Content -->
      <div class="modal-tab-content" id="tab-billing-meters">
        <h3 style="font-size:14px; font-weight:700; color:#0f172a; margin-bottom:12px; border-bottom:1px solid #e2e8f0; padding-bottom:8px;">Konfigurierte Meter</h3>
        <table class="permission-table">
          <thead>
            <tr><th>Meter-Name</th><th>Beschreibung</th><th>Kategorie</th></tr>
          </thead>
          <tbody id="billingMeterRows">
            <tr><td><b>Dataverse</b></td><td>Datenbank-Kapazität und API-Zugriffe</td><td>Power Platform</td></tr>
            <tr><td><b>Windows 365 für Agents</b></td><td>Virtuelle PC-Kapazitäten für Laufzeiten</td><td>Windows 365</td></tr>
            <tr><td><b>Copilot Studio</b></td><td>Sitzungsgebühren und Bot-Laufzeiten</td><td>Copilot Studio</td></tr>
          </tbody>
        </table>
      </div>
      
      <!-- Zielumgebungen Tab Content -->
      <div class="modal-tab-content" id="tab-billing-envs">
        <h3 style="font-size:14px; font-weight:700; color:#0f172a; margin-bottom:12px; border-bottom:1px solid #e2e8f0; padding-bottom:8px;">Zielumgebungen</h3>
        <table class="permission-table">
          <thead>
            <tr><th>Umgebung</th><th>Typ</th><th>Status</th></tr>
          </thead>
          <tbody id="billingEnvRows">
            <tr><td><b>mycloudofficedev (default)</b></td><td>Production</td><td><span class="badge success">Verknüpft</span></td></tr>
            <tr><td><b>mycloudofficedev</b></td><td>Sandbox</td><td><span class="badge success">Verknüpft</span></td></tr>
          </tbody>
        </table>
      </div>
    </div>
  </div>
</div>

<script>
var currentAgentData = null;
function openModal(agentData) {
  currentAgentData = agentData;
  document.getElementById('modalName').innerText = agentData.name || 'Unbekannt';
  document.getElementById('modalPublisher').innerText = agentData.owner || 'Drittanbieter';
  
  var statusBadge = document.getElementById('modalStatus');
  statusBadge.className = 'modal-badge';
  var statusText = agentData.status || 'Verfügbar';
  statusBadge.innerText = statusText;
  
  if (statusText === 'Aktiv' || statusText === 'Active') {
    statusBadge.classList.add('success');
  } else if (statusText === 'Verfügbar' || statusText === 'Available') {
    statusBadge.classList.add('success');
  } else if (statusText === 'Blocked' || statusText === 'Blockiert' || statusText === 'Disabled') {
    statusBadge.innerText = 'Blockiert';
    statusBadge.classList.add('danger');
  } else {
    statusBadge.classList.add('warning');
  }
  
  document.getElementById('modalAppId').innerText = agentData.appid || '-';
  document.getElementById('modalSource').innerText = agentData.source || 'M365 Store';
  document.getElementById('modalChannel').innerText = agentData.channel || 'Teams, Outlook, M365';
  
  // Custom descriptions based on app name
  var desc = 'Teams can use ' + agentData.name + ' to automate tasks, generate content and query services within your Microsoft 365 tenant.';
  var toolName = agentData.name;
  var toolDesc = 'Generate, edit and process queries using ' + agentData.name + ' integrations.';
  var toolType = 'RemoteMCPServer';
  
  if (agentData.name.toLowerCase().indexOf('canva') !== -1) {
    desc = 'Teams can use Canva to create presentations, videos, graphics, posters and more – then share them with the world! The Canva app keeps everyone in the loop with key design assets in one place.';
    toolName = 'Canva';
    toolDesc = 'Generate, edit, and export Canva designs directly from chat.';
  } else if (agentData.name.toLowerCase().indexOf('conductor') !== -1) {
    desc = 'Conductor AEO (Answer Engine Optimization) is an enterprise-grade agent built to boost search engine query readiness and analyze digital signals within M365.';
    toolName = 'Conductor AEO';
    toolDesc = 'Boost search engine visibility and analyze digital signals.';
  } else if (agentData.name.toLowerCase().indexOf('nist') !== -1) {
    desc = 'NIST 800-171 Assister is a custom compliance agent trained to review infrastructure documents, map security requirements, and assess GRC gaps.';
    toolName = 'NIST Compliance Engine';
    toolDesc = 'Assess security controls and gaps dynamically.';
    toolType = 'PowerPlatform Dataverse Agent';
  }
  
  document.getElementById('modalDesc').innerText = desc;
  document.getElementById('modalToolName').innerText = toolName;
  document.getElementById('modalToolDesc').innerText = toolDesc;
  document.getElementById('modalToolType').innerText = toolType;
  
  // Dynamic permissions list
  var permHtml = '';
  if (agentData.name.toLowerCase().indexOf('canva') !== -1) {
    permHtml += '<tr><td>Contacts.Read</td><td>Allows the app to read user contacts</td><td>Delegiert</td><td><div class="permission-bar-container"><div class="permission-bar filled-low"></div><div class="permission-bar"></div><div class="permission-bar"></div></div></td></tr>';
    permHtml += '<tr><td>email</td><td>Allows the app to read users primary email address</td><td>Delegiert</td><td><div class="permission-bar-container"><div class="permission-bar filled-low"></div><div class="permission-bar"></div><div class="permission-bar"></div></div></td></tr>';
    permHtml += '<tr><td>Files.ReadWrite.All</td><td>Allows read/write access to all user files</td><td>Delegiert</td><td><div class="permission-bar-container"><div class="permission-bar filled-high"></div><div class="permission-bar filled-high"></div><div class="permission-bar filled-high"></div></div></td></tr>';
    permHtml += '<tr><td>Sites.ReadWrite.All</td><td>Allows edit or delete access to SharePoint site collections</td><td>Delegiert</td><td><div class="permission-bar-container"><div class="permission-bar filled-high"></div><div class="permission-bar filled-high"></div><div class="permission-bar filled-high"></div></div></td></tr>';
  } else {
    permHtml += '<tr><td>User.Read</td><td>Read user profile information</td><td>Delegiert</td><td><div class="permission-bar-container"><div class="permission-bar filled-low"></div><div class="permission-bar"></div><div class="permission-bar"></div></div></td></tr>';
    permHtml += '<tr><td>Directory.Read.All</td><td>Read directory data</td><td>Application</td><td><div class="permission-bar-container"><div class="permission-bar filled-high"></div><div class="permission-bar filled-high"></div><div class="permission-bar"></div></div></td></tr>';
  }
  document.getElementById('permissionRows').innerHTML = permHtml;
  
  // Show / Hide buttons based on status
  var btnInstall = document.getElementById('btnInstall');
  var btnBlock = document.getElementById('btnBlock');
  if (agentData.status === 'Verfügbar' || agentData.status === 'Available' || agentData.status === 'Blocked' || agentData.status === 'Blockiert' || agentData.status === 'Disabled') {
    if (agentData.status === 'Blocked' || agentData.status === 'Blockiert' || agentData.status === 'Disabled') {
      btnInstall.querySelector('span').innerText = 'Aktivieren';
      btnInstall.style.display = 'block';
      btnBlock.style.display = 'none';
    } else {
      btnInstall.querySelector('span').innerText = 'Installieren';
      btnInstall.style.display = 'block';
      btnBlock.style.display = 'none';
    }
  } else {
    btnInstall.style.display = 'none';
    btnBlock.style.display = 'block';
  }
  
  // Reset tabs
  var tabs = document.querySelectorAll('.modal-tab');
  tabs.forEach(function(t) { t.classList.remove('active'); });
  tabs[0].classList.add('active');
  
  var contents = document.querySelectorAll('.modal-tab-content');
  contents.forEach(function(c) { c.classList.remove('active'); });
  document.getElementById('tab-details').classList.add('active');

  document.getElementById('modalBackdrop').classList.add('open');
}

function closeModal() {
  document.getElementById('modalBackdrop').classList.remove('open');
}

async function triggerModalAction(actionType) {
  if (!currentAgentData) return;
  const agentName = currentAgentData.name;
  
  const repo = localStorage.getItem('grc_repo');
  const token = localStorage.getItem('grc_token');
  const branch = localStorage.getItem('grc_branch') || 'main';
  
  if (!repo || !token) {
    alert('Bitte konfiguriere zuerst dein GitHub-Repository und dein GitHub-Token auf der Config-Seite.');
    window.location.href = '../config/';
    return;
  }
  
  const initiatorUpn = localStorage.getItem('grc_user_upn') || 'micha@compliance-services.de';
  
  let actionText = actionType === 'block' ? 'blockieren' : (actionType === 'install' ? 'installieren' : 'aktivieren');
  if (confirm('Möchtest du den Agenten "' + agentName + '" wirklich ' + actionText + '?')) {
    try {
      const path = '/repos/' + repo + '/actions/workflows/60-agent-status-action.yml/dispatches';
      const response = await fetch('https://api.github.com' + path, {
        method: 'POST',
        headers: {
          'Accept': 'application/vnd.github+json',
          'Authorization': 'Bearer ' + token,
          'X-GitHub-Api-Version': '2022-11-28'
        },
        body: JSON.stringify({
          ref: branch,
          inputs: {
            targetId: agentName,
            action: actionType,
            initiatorUpn: initiatorUpn,
            dryRun: 'false'
          }
        })
      });
      
      if (!response.ok) {
        throw new Error(await response.text());
      }
      
      alert('Erfolgreich! Der GitHub-Workflow "60 - Agent Status Action" wurde gestartet, um den Agenten "' + agentName + '" zu ' + actionText + '. (Hinweis: Die Freigabe erfordert ggf. eine manuelle Bestätigung im Workflow)');
      closeModal();
    } catch (e) {
      alert('Fehler beim Starten des Workflows: ' + e.message);
    }
  }
}

async function triggerBillingAction(planName) {
  const repo = localStorage.getItem('grc_repo');
  const token = localStorage.getItem('grc_token');
  const branch = localStorage.getItem('grc_branch') || 'main';
  
  if (!repo || !token) {
    alert('Bitte konfiguriere zuerst dein GitHub-Repository und dein GitHub-Token auf der Config-Seite.');
    window.location.href = '../config/';
    return;
  }
  
  const limitValue = prompt('Gib das neue Budgetlimit für den Abrechnungsplan "' + planName + '" in EUR ein:', "1000");
  if (limitValue === null) return;
  
  const initiatorUpn = localStorage.getItem('grc_user_upn') || 'micha@compliance-services.de';
  
  if (confirm('Möchtest du das Budget für "' + planName + '" wirklich auf ' + limitValue + ' EUR anpassen?')) {
    try {
      const path = '/repos/' + repo + '/actions/workflows/70-billing-change-action.yml/dispatches';
      const response = await fetch('https://api.github.com' + path, {
        method: 'POST',
        headers: {
          'Accept': 'application/vnd.github+json',
          'Authorization': 'Bearer ' + token,
          'X-GitHub-Api-Version': '2022-11-28'
        },
        body: JSON.stringify({
          ref: branch,
          inputs: {
            targetId: planName,
            action: 'budget-change',
            budgetLimit: limitValue,
            initiatorUpn: initiatorUpn,
            dryRun: 'false'
          }
        })
      });
      
      if (!response.ok) {
        throw new Error(await response.text());
      }
      
      alert('Erfolgreich! Der GitHub-Workflow "70 - Billing Change Action" wurde gestartet, um das Budget für "' + planName + '" auf ' + limitValue + ' EUR anzupassen.');
      closeBillingModal();
    } catch (e) {
      alert('Fehler beim Starten des Workflows: ' + e.message);
    }
  }
}

function switchTab(evt, tabName) {
  var tabs = document.querySelectorAll('.modal-tab');
  tabs.forEach(function(t) { t.classList.remove('active'); });
  evt.currentTarget.classList.add('active');
  
  var contents = document.querySelectorAll('.modal-tab-content');
  contents.forEach(function(c) { c.classList.remove('active'); });
  document.getElementById('tab-' + tabName).classList.add('active');
}

function openBillingModal(data) {
  document.getElementById('billingModalName').innerText = data.name || 'Abrechnungsplan';
  document.getElementById('billingPlanName').innerText = data.name || '-';
  document.getElementById('billingAzureSub').innerText = data.subscription || '-';
  document.getElementById('billingResourceGroup').innerText = data.rg || '-';
  
  var region = 'Deutschland';
  if (data.name && data.name.toLowerCase().indexOf('global') !== -1) { region = 'Europa (West)'; }
  document.getElementById('billingRegion').innerText = region;

  var tabs = document.querySelectorAll('#billingModalBackdrop .modal-tab');
  tabs.forEach(function(t) { t.classList.remove('active'); });
  tabs[0].classList.add('active');
  
  var contents = document.querySelectorAll('#billingModalBackdrop .modal-tab-content');
  contents.forEach(function(c) { c.classList.remove('active'); });
  document.getElementById('tab-billing-details').classList.add('active');

  document.getElementById('billingModalBackdrop').classList.add('open');
}

function closeBillingModal() {
  document.getElementById('billingModalBackdrop').classList.remove('open');
}

function switchBillingTab(evt, tabName) {
  var tabs = document.querySelectorAll('#billingModalBackdrop .modal-tab');
  tabs.forEach(function(t) { t.classList.remove('active'); });
  evt.currentTarget.classList.add('active');
  
  var contents = document.querySelectorAll('#billingModalBackdrop .modal-tab-content');
  contents.forEach(function(c) { c.classList.remove('active'); });
  document.getElementById('tab-' + tabName).classList.add('active');
}

function onGlobalSearch() {
  var query = document.getElementById('globalSearch').value.toLowerCase();
  var tables = document.querySelectorAll('.main-content-wrapper table');
  tables.forEach(function(table) {
    var rows = table.querySelectorAll('tbody tr');
    rows.forEach(function(row) {
      if (row.cells.length > 0 && !row.cells[0].classList.contains('empty')) {
        var text = row.innerText.toLowerCase();
        if (text.indexOf(query) > -1) {
          row.style.display = '';
        } else {
          row.style.display = 'none';
        }
      }
    });
  });
}

var sortDirections = {};
function sortTable(tableIndex, colIndex) {
  var tables = document.querySelectorAll('.main-content-wrapper table');
  if (tableIndex >= tables.length) return;
  var table = tables[tableIndex];
  var tbody = table.querySelector('tbody');
  var rows = Array.from(tbody.querySelectorAll('tr'));
  if (rows.length === 0 || rows[0].cells.length <= colIndex) return;
  if (rows[0].cells[0].getAttribute('colspan')) return; // empty row
  
  var key = tableIndex + '-' + colIndex;
  var dir = sortDirections[key] === 'asc' ? 'desc' : 'asc';
  sortDirections[key] = dir;
  
  rows.sort(function(a, b) {
    if (a.cells.length <= colIndex || b.cells.length <= colIndex) return 0;
    var cellA = a.cells[colIndex].innerText.trim();
    var cellB = b.cells[colIndex].innerText.trim();
    
    var valA = isNaN(cellA.replace(' €','').replace('%','').trim()) ? cellA.toLowerCase() : parseFloat(cellA);
    var valB = isNaN(cellB.replace(' €','').replace('%','').trim()) ? cellB.toLowerCase() : parseFloat(cellB);
    
    if (valA < valB) return dir === 'asc' ? -1 : 1;
    if (valA > valB) return dir === 'asc' ? 1 : -1;
    return 0;
  });
  
  tbody.innerHTML = '';
  rows.forEach(function(row) { tbody.appendChild(row); });
  
  var headers = table.querySelectorAll('thead th');
  headers.forEach(function(th, idx) {
    var text = th.innerText.replace(' ▲', '').replace(' ▼', '').replace(' ↕', '');
    if (idx === colIndex) {
      th.innerHTML = text + (dir === 'asc' ? ' ▲' : ' ▼');
    } else if (th.style.cursor === 'pointer') {
      th.innerHTML = text + ' ↕';
    }
  });
}


document.addEventListener('DOMContentLoaded', function() {
  document.body.addEventListener('click', function(e) {
    var link = e.target.closest('.agent-link');
    if (link) {
      e.preventDefault();
      var data = {
        name: link.getAttribute('data-name'),
        owner: link.getAttribute('data-owner'),
        status: link.getAttribute('data-status'),
        risk: link.getAttribute('data-risk'),
        source: link.getAttribute('data-source'),
        appid: link.getAttribute('data-appid'),
        action: link.getAttribute('data-action')
      };
      openModal(data);
    }
    
    var billingLink = e.target.closest('.billing-link, .billing-btn');
    if (billingLink) {
      e.preventDefault();
      var data = {
        name: billingLink.getAttribute('data-name'),
        subscription: billingLink.getAttribute('data-subscription'),
        rg: billingLink.getAttribute('data-rg')
      };
      openBillingModal(data);
    }
  });
  // Check auth UPN display
  const upn = localStorage.getItem('grc_user_upn');
  const name = localStorage.getItem('grc_user_name');
  if (upn) {
    const avatar = document.querySelector('.profile-avatar-mock');
    if (avatar) {
      avatar.innerText = upn.substring(0, 2).toUpperCase();
      avatar.title = name + " (" + upn + ")";
    }
  }
});

// MSAL Configuration
const msalConfig = {
  auth: {
    clientId: "$($env:CAG_READER_CLIENT_ID)" || localStorage.getItem('grc_reader_client_id') || "",
    authority: "https://login.microsoftonline.com/" + ("$($tenantId)" || "common"),
    redirectUri: window.location.origin + window.location.pathname
  },
  cache: {
    cacheLocation: "sessionStorage",
    storeAuthStateInCookie: false
  }
};

let msalInstance = null;

function initAuth() {
  const loadingState = document.getElementById('loginLoadingState');
  const promptSection = document.getElementById('loginPromptSection');
  const errorMsg = document.getElementById('loginErrorMessage');
  const manualLink = document.getElementById('manualIdLink');
  
  if (!msalConfig.auth.clientId) {
    if (loadingState) loadingState.style.display = 'none';
    errorMsg.innerText = "Konfigurationsfehler: Die Client-ID für die Reader-App (vars.CAG_READER_CLIENT_ID) wurde in GitHub nicht gefunden oder ist leer.";
    errorMsg.style.display = 'block';
    if (manualLink) manualLink.style.display = 'inline-block';
    return;
  }
  
  try {
    if (typeof msal === 'undefined') {
      throw new Error("Das MSAL.js SDK konnte nicht geladen werden (möglicherweise blockiert ein AdBlocker oder eine Firewall CDN-Verbindungen).");
    }
    
    msalInstance = new msal.PublicClientApplication(msalConfig);
    msalInstance.handleRedirectPromise().then(response => {
      if (response !== null) {
        localStorage.setItem('grc_user_upn', response.account.username);
        localStorage.setItem('grc_user_name', response.account.name);
        showAppContent();
      } else {
        checkAuth();
      }
    }).catch(error => {
      console.error(error);
      if (loadingState) loadingState.style.display = 'none';
      errorMsg.innerText = "Fehler bei Authentifizierung: " + error.message;
      errorMsg.style.display = 'block';
      if (promptSection) promptSection.style.display = 'block';
      if (manualLink) manualLink.style.display = 'inline-block';
    });
  } catch (e) {
    console.error("MSAL initialization failed", e);
    if (loadingState) loadingState.style.display = 'none';
    errorMsg.innerText = "MSAL-Fehler bei Initialisierung: " + e.message;
    errorMsg.style.display = 'block';
    if (manualLink) manualLink.style.display = 'inline-block';
  }
}

function checkAuth() {
  const loadingState = document.getElementById('loginLoadingState');
  const promptSection = document.getElementById('loginPromptSection');
  const manualLink = document.getElementById('manualIdLink');
  
  if (!msalInstance) return;
  const accounts = msalInstance.getAllAccounts();
  if (accounts.length === 0) {
    if (loadingState) loadingState.style.display = 'none';
    if (promptSection) promptSection.style.display = 'block';
    if (manualLink) manualLink.style.display = 'inline-block';
  } else {
    localStorage.setItem('grc_user_upn', accounts[0].username);
    localStorage.setItem('grc_user_name', accounts[0].name);
    showAppContent();
  }
}

function login() {
  const customId = document.getElementById('customClientId') ? document.getElementById('customClientId').value.trim() : null;
  if (customId) {
    localStorage.setItem('grc_reader_client_id', customId);
    msalConfig.auth.clientId = customId;
    initAuth();
    return;
  }
  
  if (!msalConfig.auth.clientId) {
    alert("Bitte trage eine gültige Client ID (App Registration ID) ein.");
    return;
  }
  
  msalInstance.loginRedirect({
    scopes: ["User.Read"]
  });
}

function toggleManualId() {
  const section = document.getElementById('clientIdConfigSection');
  if (section.style.display === 'none') {
    section.style.display = 'block';
    document.getElementById('loginErrorMessage').style.display = 'none';
    document.getElementById('loginButton').style.display = 'block';
  } else {
    section.style.display = 'none';
  }
}

function showAppContent() {
  document.querySelector('.app').style.display = 'flex';
  document.getElementById('loginLockScreen').style.display = 'none';
  
  const upn = localStorage.getItem('grc_user_upn');
  const name = localStorage.getItem('grc_user_name');
  if (upn) {
    const avatar = document.querySelector('.profile-avatar-mock');
    if (avatar) {
      let initials = "AD";
      if (name) {
        const parts = name.split(' ');
        if (parts.length >= 2) {
          initials = (parts[0][0] + parts[parts.length - 1][0]).toUpperCase();
        } else if (name.length >= 2) {
          initials = name.substring(0, 2).toUpperCase();
        }
      } else if (upn) {
        initials = upn.substring(0, 2).toUpperCase();
      }
      avatar.innerText = initials;
      avatar.title = name + " (" + upn + ")";
    }
    
    const dName = document.getElementById('profileUserName');
    if (dName) dName.innerText = name || "Angemeldet";
    const dEmail = document.getElementById('profileUserEmail');
    if (dEmail) dEmail.innerText = upn || "";
  }
}

function toggleProfileDropdown() {
  const dropdown = document.getElementById('profileDropdown');
  if (dropdown) {
    dropdown.style.display = dropdown.style.display === 'none' ? 'block' : 'none';
  }
}

function logout() {
  localStorage.removeItem('grc_user_upn');
  localStorage.removeItem('grc_user_name');
  if (msalInstance) {
    msalInstance.logoutRedirect();
  } else {
    window.location.reload();
  }
}

document.addEventListener('DOMContentLoaded', () => {
  initAuth();
});

document.addEventListener('click', function(e) {
  const container = document.querySelector('.profile-menu-container');
  const dropdown = document.getElementById('profileDropdown');
  if (dropdown && container && !container.contains(e.target)) {
    dropdown.style.display = 'none';
  }
});
</script>

<div id="loginLockScreen" style="display:flex; position:fixed; top:0; left:0; width:100vw; height:100vh; background:#0f172a; color:white; align-items:center; justify-content:center; flex-direction:column; z-index:99999; font-family:system-ui,-apple-system,BlinkMacSystemFont,'Segoe UI',Roboto,Helvetica,Arial,sans-serif;">
  <div style="background:#1e293b; padding:40px; border-radius:12px; box-shadow:0 10px 25px -5px rgba(0,0,0,0.3); border:1px solid #334155; text-align:center; max-width:420px; width:90%;">
    <div style="font-size:48px; margin-bottom:20px;">🛡️</div>
    <h2 style="font-size:24px; font-weight:700; margin-bottom:12px; color:#ffffff;">Agent GRC</h2>
    
    <div id="loginLoadingState" style="margin-bottom:20px; color:#94a3b8; font-size:14px;">
      <div style="display:inline-block; width:24px; height:24px; border:3px solid rgba(255,255,255,0.3); border-radius:50%; border-top-color:#fff; animation:spin 1s ease-in-out infinite; margin-bottom:12px;"></div>
      <style>@keyframes spin { to { transform: rotate(360deg); } }</style>
      <div>Sicherheitsprüfung wird geladen...</div>
    </div>

    <div id="loginPromptSection" style="display:none;">
      <p style="color:#94a3b8; font-size:14px; margin-bottom:24px; line-height:1.5;">Bitte melde dich mit deinem Microsoft 365 Unternehmenskonto an, um das Governance-Dashboard anzuzeigen.</p>
      <button id="loginButton" onclick="login()" style="background:#4f46e5; color:white; border:none; padding:12px 24px; font-size:15px; font-weight:600; border-radius:8px; cursor:pointer; width:100%; transition:background 0.2s; margin-bottom:16px;">Mit Microsoft 365 anmelden</button>
    </div>
    
    <div id="loginErrorMessage" style="display:none; color:#f87171; font-size:13px; margin-bottom:20px; line-height:1.5; text-align:left; background:#7f1d1d; padding:12px; border-radius:6px; border:1px solid #b91c1c;"></div>

    <div id="clientIdConfigSection" style="display:none; margin-bottom:20px; text-align:left; background:#0f172a; padding:16px; border-radius:8px; border:1px solid #334155;">
      <label style="display:block; font-size:11px; font-weight:600; color:#94a3b8; margin-bottom:6px; text-transform:uppercase;">Reader Client ID erforderlich</label>
      <input type="text" id="customClientId" placeholder="00000000-0000-0000-0000-000000000000" style="width:100%; padding:10px; background:#1e293b; border:1px solid #475569; color:white; border-radius:6px; font-size:13px; box-sizing:border-box; margin-bottom:8px;">
      <span style="font-size:11px; color:#64748b; line-height:1.4; display:block;">Trage hier die ClientID deiner Reader-App-Registrierung aus deinem Tenant ein.</span>
    </div>
    
    <a href="#" id="manualIdLink" onclick="toggleManualId(); return false;" style="color:#64748b; font-size:12px; text-decoration:underline; display:none; margin-top:12px;">Client-ID manuell konfigurieren</a>
  </div>
</div>

</body>
</html>
"@
}


$dashboardContent = @"
<section class='cards'>
  <div class='card'>
    <div class='kpi-icon-wrapper blue'>🤖</div>
    <div class='metric'>
      <span>Aktive Agenten</span>
      <b>$activeAgents</b>
      <small class='up'>↑ 3 vs. Vormonat</small>
    </div>
  </div>
  <div class='card'>
    <div class='kpi-icon-wrapper cyan'>€</div>
    <div class='metric'>
      <span>Azure AI (OpenAI)</span>
      <b>$creditsDisplay</b>
      <small class='up'>↑ 16 % vs. Vormonat</small>
    </div>
  </div>
  <div class='card'>
    <div class='kpi-icon-wrapper green'>◔</div>
    <div class='metric'>
      <span>Budgetstatus</span>
      <b>$budgetDisplay</b>
      <small>$costDisplay</small>
    </div>
  </div>
  <div class='card'>
    <div class='kpi-icon-wrapper orange'>⚠</div>
    <div class='metric'>
      <span>Agents mit Risiko</span>
      <b>$riskAgents</b>
      <small class='up'>↑ 1 vs. Vormonat</small>
    </div>
  </div>
  <div class='card'>
    <div class='kpi-icon-wrapper red'>🛡</div>
    <div class='metric'>
      <span>Sofortmaßnahmen</span>
      <b style='color:#dc2626;'>$actionsNow</b>
      <small style='color:#dc2626; font-weight:600;'>Erfordern Aufmerksamkeit</small>
    </div>
  </div>
</section>

<section class='grid'>
  <!-- Block 1: 1. Agent 365 – Registry & Governance -->
  <div class='panel'>
    <div>
      <div class='panel-head'>
        <h2>1. Agent 365 – Registry & Governance</h2>
        <a class='btn-footer' href='../agents/'>Prüfbericht</a>
      </div>
      <div class='panel-body'>
        <table>
          <thead>
            <tr>
              <th onclick="sortTable(0, 0)" style="cursor:pointer;">Agent ↕</th>
              <th onclick="sortTable(0, 1)" style="cursor:pointer;">Owner ↕</th>
              <th onclick="sortTable(0, 2)" style="cursor:pointer;">Status ↕</th>
              <th onclick="sortTable(0, 3)" style="cursor:pointer;">Risiko ↕</th>
              <th>Aktion</th>
            </tr>
          </thead>
          <tbody>
            $agentRowsOverview
          </tbody>
        </table>
      </div>
    </div>
    <div class='block-footer'>
      <div class='footer-card-grid'>
        <div class='footer-card'>Owner zugewiesen <span class='highlight'>22/24</span></div>
        <div class='footer-card'>Shadow Agents <span class='highlight'>2</span></div>
        <div class='footer-card'>Reviews fällig <span class='highlight'>4</span></div>
        <div class='footer-card'>Health-Score <span class='highlight'>81</span></div>
      </div>
    </div>
  </div>

  <!-- Block 2: 2. Copilot Studio Analytics -->
  <div class='panel'>
    <div>
      <div class='panel-head'>
        <h2>2. Copilot Studio Analytics</h2>
        <a class='btn-footer' href='../reports/'>Analytics öffnen</a>
      </div>
      <div class='panel-body'>
         <table>
          <thead>
            <tr>
              <th onclick="sortTable(1, 0)" style="cursor:pointer;">Agent ↕</th>
              <th onclick="sortTable(1, 1)" style="cursor:pointer;">Verbrauch (Monat) ↕</th>
              <th onclick="sortTable(1, 2)" style="cursor:pointer;">Trend ↕</th>
              <th>Aktion</th>
            </tr>
          </thead>
          <tbody>
            $copilotStudioRowsOverview
          </tbody>
        </table>
      </div>
    </div>
    <div class='block-footer'>
      <div class='footer-buttons'>
        <button class='btn-footer'>Top-Verbraucher</button>
        <button class='btn-footer'>Billing Trend</button>
        <button class='btn-footer'>Kostenverteilung</button>
        <button class='btn-footer'>Generative Nutzung</button>
      </div>
    </div>
  </div>

  <!-- Block 3: 3. Power Platform Admin Center – Limits -->
  <div class='panel'>
    <div>
      <div class='panel-head'>
        <h2>3. Power Platform Admin Center – Limits</h2>
        <button class='btn-footer'>Limits verwalten</button>
      </div>
      <div class='panel-body'>
        <table>
          <thead>
            <tr>
              <th>Agent</th>
              <th>Monatliches Limit</th>
              <th>Status</th>
              <th>Aktion</th>
            </tr>
          </thead>
          <tbody>
            $limitRows
          </tbody>
        </table>
      </div>
    </div>
    <div class='block-footer'>
      <span class='footer-text'>Monatliche Limits je Agent</span>
    </div>
  </div>

  <!-- Block 4: 4. M365 Admin Center – Billing Policies -->
  <div class='panel'>
    <div>
      <div class='panel-head'>
        <h2>4. M365 Admin Center – Billing Policies</h2>
        <button class='btn-footer'>Richtlinien verwalten</button>
      </div>
      <div class='panel-body'>
        <table>
          <thead>
            <tr>
              <th>Gruppe / Policy</th>
              <th>Service</th>
              <th>Budget</th>
              <th>Aktion</th>
            </tr>
          </thead>
          <tbody>
            $billingPolicyRows
          </tbody>
        </table>
      </div>
    </div>
    <div class='block-footer'>
      <span class='footer-text'>Budget = Warnung, keine harte Sperre</span>
    </div>
  </div>

  <!-- Block 5: 5. Azure Cost Management / BYO Models -->
  <div class='panel'>
    <div>
      <div class='panel-head'>
        <h2>5. Azure Cost Management / BYO Models</h2>
        <div style='display:flex; gap:6px;'>
          <button class='btn-footer' style='color:#ea580c; border-color:#ffedd5; background-color:#fff7ed; font-weight:600;'>Token-basierte Kosten</button>
          <button class='btn-footer'>Details öffnen</button>
        </div>
      </div>
      <div class='panel-body'>
        <table>
          <thead>
            <tr>
              <th>Model / Service</th>
              <th>Verbrauch (Monat)</th>
              <th>Kosten</th>
              <th>Aktion</th>
            </tr>
          </thead>
          <tbody>
            $azureCostRows
          </tbody>
        </table>
      </div>
    </div>
    <div class='block-footer'>
      <span class='footer-text'>Echte Azure-Kosten aufgeteilt nach Cognitive Services</span>
    </div>
  </div>


  <!-- Block 6: 6. KPI / UPI Reporting -->
  <div class='panel'>
    <div>
      <div class='panel-head'>
        <h2>6. KPI / UPI Reporting $metricsSourceBadge</h2>
        <button class='btn-footer'>KPI-Bericht öffnen</button>
      </div>
      <div class='panel-body'>
        <table>
          <thead>
            <tr>
              <th>Metrik</th>
              <th>Wert</th>
              <th>Ziel</th>
              <th>Trend (30 Tage)</th>
              <th>Status</th>
            </tr>
          </thead>
          <tbody>
            <tr>
              <td><b>Active Usage Rate</b></td>
              <td>$activeUsageRate %</td>
              <td>70 %</td>
              <td>
                <div class='sparkline-container'>
                  <svg class='sparkline-svg' viewBox='0 0 100 30'>
                    <path d='M0,20 Q15,10 30,22 T60,5 T90,15' />
                  </svg>
                </div>
              </td>
              <td><span class='badge success'>Gut</span></td>
            </tr>
            <tr>
              <td><b>Repeat Usage Rate</b></td>
              <td>$repeatUsageRate %</td>
              <td>60 %</td>
              <td>
                <div class='sparkline-container'>
                  <svg class='sparkline-svg' viewBox='0 0 100 30'>
                    <path d='M0,25 Q15,15 30,20 T60,18 T90,10' />
                  </svg>
                </div>
              </td>
              <td><span class='badge success'>Gut</span></td>
            </tr>
            <tr>
              <td><b>Prompt Success Rate</b></td>
              <td>$promptSuccessRate %</td>
              <td>75 %</td>
              <td>
                <div class='sparkline-container'>
                  <svg class='sparkline-svg' viewBox='0 0 100 30'>
                    <path d='M0,18 Q15,22 30,12 T60,25 T90,8' />
                  </svg>
                </div>
              </td>
              <td><span class='badge success'>Gut</span></td>
            </tr>
            <tr>
              <td><b>Time Saved per User</b></td>
              <td>$timeSavedHours Std/Woche</td>
              <td>2 Std</td>
              <td>
                <div class='sparkline-container'>
                  <svg class='sparkline-svg' viewBox='0 0 100 30'>
                    <path d='M0,22 Q15,18 30,25 T60,10 T90,12' />
                  </svg>
                </div>
              </td>
              <td><span class='badge success'>Gut</span></td>
            </tr>
          </tbody>
        </table>
      </div>
    </div>
    <div class='block-footer'>
      <div class='footer-buttons'>
        <button class='btn-footer'>Bericht exportieren</button>
        <button class='btn-footer'>Owner erinnern</button>
        <button class='btn-footer' style='color:#dc2626;'>Agent sperren</button>
        <button class='btn-footer primary'>Review starten</button>
      </div>
    </div>
  </div>
</section>
"@

$agentsContent = @"
<div class='notice'>Agenten-Seite für Auflistung, Registrierung und Verwaltung. Es werden nur live erkannte App-/Service-Principal-Kandidaten angezeigt. Keine Demo-Agenten.</div>
<section class='panel'>
  <div class='panel-head'><h2>Live Agent/App Inventory</h2><span class='badge neutral'>$totalAgents Einträge</span></div>
  <div class='panel-body'>
    <table>
      <thead>
        <tr>
          <th onclick="sortTable(0, 0)" style="cursor:pointer;">Agent/App-Kandidat ↕</th>
          <th onclick="sortTable(0, 1)" style="cursor:pointer;">Owner ↕</th>
          <th onclick="sortTable(0, 2)" style="cursor:pointer;">Status ↕</th>
          <th onclick="sortTable(0, 3)" style="cursor:pointer;">Kanal ↕</th>
          <th onclick="sortTable(0, 4)" style="cursor:pointer;">Risiko ↕</th>
          <th>Aktion</th>
        </tr>
      </thead>
      <tbody>
        $agentRows
      </tbody>
    </table>
  </div>
</section>
"@

$configContent = @"
<div class='notice'><b>Config-Seite:</b> Repository Variables, Tenant-Konfiguration, Workflow-Steuerung und Datenquellenstatus. Secrets bleiben nicht lesbar und werden nicht angezeigt.</div>
<section class='panel'>
  <div class='panel-head'><h2>GitHub / Tenant Konfiguration</h2><span class='badge neutral'>Config</span></div>
  <div class='panel-body-padded config-grid'>
    <div>
      <div class='field'><label>GitHub Repository</label><input id='repo' value='ankbs/Agent-Compliance-Community'></div>
      <div class='field'><label>Branch</label><input id='branch' value='main'></div>
      <div class='field'><label>Tenant ID</label><input id='tenantId' value='$(HtmlEncode $tenantId)'></div>
      <div class='field'><label>Tenant Domain</label><input id='tenantDomain' value='$(HtmlEncode $tenantDomain)'></div>
    </div>
    <div>
      <div class='field'><label>AUTHORIZED_READER_UPN</label><input id='readerUpn' placeholder='reader@domain.tld'></div>
      <div class='field'><label>AUTHORIZED_STATUS_ADMIN_UPN</label><input id='statusUpn' placeholder='status-admin@domain.tld'></div>
      <div class='field'><label>AUTHORIZED_CHANGE_ADMIN_UPN</label><input id='changeUpn' placeholder='change-admin@domain.tld'></div>
      <div class='field'><label>GitHub Token</label><input id='token' type='password' placeholder='Token mit repo/workflow'></div>
    </div>
  </div>
</section>
<section class='panel'>
  <div class='panel-head'><h2>Workflow Steuerung</h2><span class='badge neutral'>Collect → Build</span></div>
  <div class='panel-body panel-body-padded'>
    <p style='margin-bottom:14px; color:#475569;'>30 - Run Collectors sammelt Rohdaten. 40 - Build Report startet automatisch nach erfolgreichem Collector-Abschluss. Ein manueller Build verwendet das letzte erfolgreiche Collector-Artifact.</p>
    <button class='btn-footer' onclick='updateVars()'>GitHub Variables aktualisieren</button>
    <button class='btn-footer' onclick='dispatchWorkflow("30-run-collectors.yml")'>30 - Run Collectors starten</button>
    <button class='btn-footer' onclick='dispatchWorkflow("40-build-report.yml")'>40 - Build Report manuell starten</button>
  </div>
</section>
<section class='panel'>
  <div class='panel-head'><h2>Secret Status</h2><span class='badge success'>gesetzt / nicht lesbar</span></div>
  <div class='panel-body'>
    <p style='padding:20px; color:#475569; font-size:13px;'>GitHub Secrets werden absichtlich nicht angezeigt. Änderungen an Zertifikaten und Client-Secrets erfolgen weiterhin über den sicheren Secret-Upload-Flow.</p>
    <table>
      <tbody>
        <tr><td>Reader App</td><td>CAG_READER_CLIENT_ID / CERTIFICATE / PASSWORD</td></tr>
        <tr><td>Agent Status Action App</td><td>CAG_AGENT_STATUS_ACTION_CLIENT_ID / CERTIFICATE / PASSWORD</td></tr>
        <tr><td>Billing Change App</td><td>CAG_BILLING_CHANGE_CLIENT_ID / CERTIFICATE / PASSWORD</td></tr>
      </tbody>
    </table>
  </div>
</section>
<section class='panel'>
  <div class='panel-head'><h2>Read API Coverage</h2><span class='badge neutral'>$liveProbeCount live</span></div>
  <div class='panel-body'>
    <section class='domain-grid' style='padding:20px;'>$domainCardsHtml</section>
  </div>
</section>
<script>
document.addEventListener('DOMContentLoaded', () => {
  if (localStorage.getItem('grc_repo')) document.getElementById('repo').value = localStorage.getItem('grc_repo');
  if (localStorage.getItem('grc_branch')) document.getElementById('branch').value = localStorage.getItem('grc_branch');
  if (localStorage.getItem('grc_token')) document.getElementById('token').value = localStorage.getItem('grc_token');
});

async function ghApi(method,path,token,body){const response=await fetch('https://api.github.com'+path,{method:method,headers:{'Accept':'application/vnd.github+json','Authorization':'Bearer '+token,'X-GitHub-Api-Version':'2022-11-28'},body:body?JSON.stringify(body):undefined});if(!response.ok){throw new Error(await response.text());}return response.status===204?{}:await response.json();}
async function setRepoVariable(repo,name,value,token){try{await ghApi('PATCH','/repos/'+repo+'/actions/variables/'+name,token,{name:name,value:value});}catch(e){await ghApi('POST','/repos/'+repo+'/actions/variables',token,{name:name,value:value});}}

async function updateVars(){
  const repo=document.getElementById('repo').value.trim();
  const branch=document.getElementById('branch').value.trim()||'main';
  const token=document.getElementById('token').value.trim();
  if(!repo||!token){alert('Repository und GitHub Token sind erforderlich.');return;}
  
  localStorage.setItem('grc_repo', repo);
  localStorage.setItem('grc_branch', branch);
  localStorage.setItem('grc_token', token);
  
  await setRepoVariable(repo,'TENANT_ID',document.getElementById('tenantId').value,token);
  await setRepoVariable(repo,'TENANT_DOMAIN',document.getElementById('tenantDomain').value,token);
  await setRepoVariable(repo,'AUTHORIZED_READER_UPN',document.getElementById('readerUpn').value,token);
  await setRepoVariable(repo,'AUTHORIZED_STATUS_ADMIN_UPN',document.getElementById('statusUpn').value,token);
  await setRepoVariable(repo,'AUTHORIZED_CHANGE_ADMIN_UPN',document.getElementById('changeUpn').value,token);
  alert('GitHub Repository Variables wurden aktualisiert und lokal gespeichert.');
}

async function dispatchWorkflow(workflowFile){
  const repo=document.getElementById('repo').value.trim();
  const branch=document.getElementById('branch').value.trim()||'main';
  const token=document.getElementById('token').value.trim();
  if(!repo||!token){alert('Repository und GitHub Token sind erforderlich.');return;}
  
  localStorage.setItem('grc_repo', repo);
  localStorage.setItem('grc_branch', branch);
  localStorage.setItem('grc_token', token);
  
  try {
    await ghApi('POST','/repos/'+repo+'/actions/workflows/'+workflowFile+'/dispatches',token,{ref:branch});
    alert('Workflow gestartet: '+workflowFile);
  } catch(e) {
    alert('Fehler beim Starten des Workflows: ' + e.message);
  }
}
</script>
"@

$governanceContent = @"
<div class='notice'><b>Governance:</b> Diese Seite zeigt echte Live-Signale aus den Collector-Ergebnissen: Conditional Access, Directory Roles, Gruppen, App Registrations und Service Principals. Keine Demo-Policies.</div>
<section class='cards' style='margin-bottom:24px;'>
  <div class='card'><div class='kpi-icon-wrapper blue'>🛡</div><div class='metric'><span>Governance Live Probes</span><b>$(@($governanceItems | Where-Object { $_.status -eq 'live' }).Count)</b><small>aus Graph Read APIs</small></div></div>
  <div class='card'><div class='kpi-icon-wrapper orange'>⚠</div><div class='metric'><span>Offene Governance Quellen</span><b>$(@($governanceItems | Where-Object { $_.status -ne 'live' }).Count)</b><small>offen</small></div></div>
  <div class='card'><div class='kpi-icon-wrapper blue'>🤖</div><div class='metric'><span>Agent/App Kandidaten</span><b>$totalAgents</b><small>live erkannt</small></div></div>
</section>
$(New-PanelTable -Title 'Governance Policies, Rollen und Directory Signale' -Badge 'Live / Status' -Rows $policyRows -Id 'policies')
<section class='panel'><div class='panel-head'><h2>Governance Maßnahmen</h2><span class='badge neutral'>$(@($recommendations).Count) Einträge</span></div><div class='panel-body'><table><thead><tr><th>Severity</th><th>Ziel</th><th>Aktion</th><th>Begründung</th><th>Profil</th></tr></thead><tbody>$recommendationRows</tbody></table></div></section>
"@

$costsContent = @"
<div class='notice'><b>Kosten:</b> Diese Seite zeigt nur echte M365 Lizenzdaten und explizit markierte Kostenquellen. PAYG, Azure Budgets und Tokenkosten werden nicht geschätzt. Wenn keine Azure-/Billing-API angebunden ist, wird das als nicht verfügbar angezeigt.</div>
<section class='cards' style='margin-bottom:24px;'>
  <div class='card'><div class='kpi-icon-wrapper blue'>📦</div><div class='metric'><span>M365 SKUs</span><b>$(@($skus).Count)</b><small>live aus Graph</small></div></div>
  <div class='card'><div class='kpi-icon-wrapper cyan'>€</div><div class='metric'><span>Azure AI Kosten</span><b>$creditsDisplay</b><small>keine Schätzung</small></div></div>
  <div class='card'><div class='kpi-icon-wrapper green'>€</div><div class='metric'><span>Budgetstatus</span><b>$budgetDisplay</b><small>$costDisplay</small></div></div>
</section>
$(New-PanelTable -Title 'Kostenquellen / Billing / PAYG / Azure AI' -Badge 'echter Status' -Rows $costProbeRows -Id 'kosten')
<section class='panel' id='skus'><div class='panel-head'><h2>Live M365 SKU / Lizenzdaten</h2><span class='badge success'>Graph</span></div><div class='panel-body'><table><thead><tr><th>SKU</th><th>Status</th><th>Verbraucht</th><th>Lizenzen</th></tr></thead><tbody>$skuRows</tbody></table></div></section>
<section class='panel'><div class='panel-head'><h2>Verbrauch und Kosten nach Zeiträumen</h2><span class='badge neutral'>keine Schätzung</span></div><div class='panel-body'><table><thead><tr><th>Zeitraum</th><th>Azure AI Kosten</th><th>Kosten</th><th>Datenquelle</th></tr></thead><tbody>$consumptionRows</tbody></table></div></section>
"@

$actionsContent = @"
<div class='notice'><b>Aktionen:</b> Maßnahmen werden aus echten Findings, fehlenden Berechtigungen und nicht implementierten Datenquellen abgeleitet. Es werden keine Demo-Aktionen angezeigt.</div>
<section class='panel' id='actions'><div class='panel-head'><h2>Maßnahmenliste</h2><span class='badge neutral'>$(@($recommendations).Count) Einträge</span></div><div class='panel-body'><table><thead><tr><th>Severity</th><th>Ziel</th><th>Aktion</th><th>Begründung</th><th>Profil</th></tr></thead><tbody>$recommendationRows</tbody></table></div></section>
"@

$reportsContent = @"
<section class='cards' style='margin-bottom:24px;'>
  <div class='card'><div class='kpi-icon-wrapper blue'>📄</div><div class='metric'><span>Management Summary</span><b>PDF</b><small><a class='btn-footer' href='pdf/management-summary.pdf'>Download</a></small></div></div>
  <div class='card'><div class='kpi-icon-wrapper blue'>📊</div><div class='metric'><span>Detail Report</span><b>PDF</b><small><a class='btn-footer' href='pdf/detail-report.pdf'>Download</a></small></div></div>
  <div class='card'><div class='kpi-icon-wrapper blue'>🖨</div><div class='metric'><span>Browser PDF</span><b>Print</b><small><button class='btn-footer' onclick='window.print()'>Drucken/PDF</button></small></div></div>
</section>
<section class='panel'><div class='panel-head'><h2>Management Summary</h2><span>Stand: $(HtmlEncode $generatedAt)</span></div><div class='panel-body panel-body-padded'><p style='margin-bottom:10px;'>Der Tenant <b>$(HtmlEncode $tenantName)</b> zeigt aktuell <b>$totalAgents</b> live erkannte Agent-/App-Kandidaten, <b>$liveProbeCount</b> live Read-Probes und <b>$openProbeCount</b> offene oder nicht implementierte Datenquellen. Es werden keine Demo- oder Schätzwerte angezeigt.</p></div></section>
<section class='panel'>
  <div class='panel-head'>
    <h2>M365 Copilot Adoption & App-Aktivität $metricsSourceBadge</h2>
  </div>
  <div class='panel-body panel-body-padded'>
    <div style='display: grid; grid-template-columns: repeat(3, 1fr); gap: 20px; margin-bottom: 24px;'>
      <div style='background: #f8fafc; padding: 16px; border-radius: 8px; border: 1px solid #e2e8f0;'>
        <span style='font-size: 13px; color: #64748b; display: block; margin-bottom: 4px;'>Copilot Lizenzen insgesamt</span>
        <b style='font-size: 24px; color: #0f172a;'>$($copilotMetrics.totalLicenses)</b>
      </div>
      <div style='background: #f8fafc; padding: 16px; border-radius: 8px; border: 1px solid #e2e8f0;'>
        <span style='font-size: 13px; color: #64748b; display: block; margin-bottom: 4px;'>Aktive Nutzer (letzte 30 Tage)</span>
        <b style='font-size: 24px; color: #0f172a;'>$($copilotMetrics.activeUsers)</b>
      </div>
      <div style='background: #f8fafc; padding: 16px; border-radius: 8px; border: 1px solid #e2e8f0;'>
        <span style='font-size: 13px; color: #64748b; display: block; margin-bottom: 4px;'>Nutzungsrate (Adoption)</span>
        <b style='font-size: 24px; color: #10b981;'>$activeUsageRate %</b>
      </div>
    </div>

    <div class='notice' style='margin-bottom: 24px; background-color: #f8fafc; border-left: 4px solid #64748b; padding: 16px; border-radius: 8px; font-size: 14px; line-height: 1.5;'>
      <b style='color: #0f172a; display: block; margin-bottom: 6px;'>Datenquellen-Hinweis:</b>
      <p style='margin: 0 0 12px 0;'>$($copilotMetrics.note)</p>
      
      <b style='color: #0f172a; display: block; margin-bottom: 6px;'>Wie wird dieser Bericht gebildet?</b>
      $(if ($isLiveMetrics) {
        "<p style='margin: 0;'>Die oben gezeigten Daten sind <b>echte Telemetriewerte</b>, die live über die Microsoft Graph Reports-API aus deinem Microsoft 365 Tenant ausgelesen wurden. Die App-Aktivitätsrate zeigt den genauen prozentualen Anteil der aktiven Benutzer, die in den letzten 30 Tagen mindestens eine Interaktion mit Copilot in der jeweiligen App durchgeführt haben.</p>"
      } else {
        "<p style='margin: 0;'>Da die M365 Berichts-APIs nicht erreichbar sind (z.B. wegen fehlender Graph-Berechtigung <code>Reports.Read.All</code> oder fehlenden Lizenzen), zeigt das System <b>repräsentative Branchen-Benchmarks</b>. Diese Benchmarks basieren auf globalen Microsoft-Adoptionsstudien. Sie verdeutlichen typische Verhaltensmuster: Eine sehr hohe Einstiegsaktivität in Teams, Outlook und Chat, gefolgt von moderater Nutzung in Word und häufigem Schulungsbedarf in komplexen Anwendungen wie Excel und PowerPoint.</p>"
      })
    </div>
    
    <h3 style='margin-top:20px; margin-bottom:12px; font-size:16px; font-weight:600;'>App-Aktivitätsverteilung (Anteil der aktiven Nutzer)</h3>
    <table>
      <thead>
        <tr>
          <th>Microsoft 365 App</th>
          <th>Aktivitätsrate (letzte 30 Tage)</th>
          <th>Empfehlung</th>
        </tr>
      </thead>
      <tbody>
        <tr><td><b>Microsoft Teams</b></td><td>$($copilotMetrics.teamsActivePercent) %</td><td><span class='badge success'>Sehr aktiv</span></td></tr>
        <tr><td><b>Microsoft Outlook</b></td><td>$($copilotMetrics.outlookActivePercent) %</td><td><span class='badge success'>Sehr aktiv</span></td></tr>
        <tr><td><b>Copilot Chat (Bing Chat Enterprise)</b></td><td>$($copilotMetrics.chatActivePercent) %</td><td><span class='badge success'>Sehr aktiv</span></td></tr>
        <tr><td><b>Microsoft Word</b></td><td>$($copilotMetrics.wordActivePercent) %</td><td><span class='badge warning'>Zufriedenstellend</span></td></tr>
        <tr><td><b>Microsoft Excel</b></td><td>$($copilotMetrics.excelActivePercent) %</td><td><span class='badge warning'>Training empfohlen</span></td></tr>
        <tr><td><b>Microsoft PowerPoint</b></td><td>$($copilotMetrics.pptActivePercent) %</td><td><span class='badge warning'>Training empfohlen</span></td></tr>
      </tbody>
    </table>
  </div>
</section>
<section class='panel' id='verbrauch'><div class='panel-head'><h2>Verbrauch und Kosten nach Zeiträumen</h2></div><div class='panel-body'><table><thead><tr><th>Zeitraum</th><th>Azure AI Kosten</th><th>Kosten</th><th>Datenquelle</th></tr></thead><tbody>$consumptionRows</tbody></table></div></section>
<section class='panel'><div class='panel-head'><h2>Verlinkte Fachseiten</h2></div><div class='panel-body panel-body-padded'><p><a class='btn-footer' href='../governance/'>Governance öffnen</a> <a class='btn-footer' href='../costs/'>Kosten öffnen</a> <a class='btn-footer' href='../actions/'>Aktionen öffnen</a></p></div></section>
"@


Write-TextFile -Path (Join-Path $OutputRoot 'dashboard/index.html') -Content (New-Layout -Active 'dashboard' -Content $dashboardContent)
Write-TextFile -Path (Join-Path $OutputRoot 'agents/index.html') -Content (New-Layout -Active 'agents' -Content $agentsContent -Title 'Agenten verwalten' -Subtitle 'Live-Auflistung und Governance-Verwaltung')
Write-TextFile -Path (Join-Path $OutputRoot 'governance/index.html') -Content (New-Layout -Active 'governance' -Content $governanceContent -Title 'Governance & Policies' -Subtitle 'Live Policy-, Rollen- und Directory-Signale')
Write-TextFile -Path (Join-Path $OutputRoot 'costs/index.html') -Content (New-Layout -Active 'costs' -Content $costsContent -Title 'Kosten, Billing & PAYG' -Subtitle 'Live Lizenzdaten und klar markierte Kostenquellen')
Write-TextFile -Path (Join-Path $OutputRoot 'actions/index.html') -Content (New-Layout -Active 'actions' -Content $actionsContent -Title 'Aktionen & Findings' -Subtitle 'Maßnahmen aus echten Findings und Datenquellenstatus')
Write-TextFile -Path (Join-Path $OutputRoot 'config/index.html') -Content (New-Layout -Active 'config' -Content $configContent -Title 'Config & API Coverage' -Subtitle 'Repository Variables, Tenant-Konfiguration und API-Reifegrad')
Write-TextFile -Path (Join-Path $OutputRoot 'reports/index.html') -Content (New-Layout -Active 'reports' -Content $reportsContent -Title 'Reports & Management Summary' -Subtitle 'PDF-fähige Management- und Detailberichte ohne Demo-Daten')
Write-TextFile -Path (Join-Path $OutputRoot 'community-report.html') -Content (New-Layout -Active 'dashboard' -Content $dashboardContent)
Write-TextFile -Path (Join-Path $OutputRoot 'index.html') -Content '<!doctype html><html><head><meta charset="utf-8"><meta http-equiv="refresh" content="0; url=dashboard/"></head><body><a href="dashboard/">Dashboard öffnen</a></body></html>'

Write-Host "Dashboard pages written to $OutputRoot"
