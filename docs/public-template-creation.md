# Public Community Template erstellen

Diese Anleitung behebt den Fehler:

```text
POST https://api.github.com/repos/MKN1411/Agent-Compliance-Community-Template/generate -> 404 Not Found
```

Der Fehler bedeutet: Das angegebene Template-Repository existiert nicht, ist nicht erreichbar oder ist nicht als Template-Repository markiert.

## Zielmodell

| Repository | Sichtbarkeit | Zweck |
|---|---|---|
| `MKN1411/Agent-Compliance` | privat | Entwicklungsrepo |
| `MKN1411/Agent-Compliance-Community-Template` | public | bereinigtes Community Template |
| `<ENDUSER_OWNER>/Agent-Compliance-Community` | private/public | Enduser-Kopie |

Das private Entwicklungsrepo darf nicht direkt als Enduser-Einstieg verwendet werden. Die Enduser-Bootstrap-Seite erzeugt stattdessen eine Kopie aus dem öffentlichen Community-Template.

## Datenschutz bei Pfadbeispielen

Öffentliche Dateien dürfen keine personenbezogenen lokalen Pfade enthalten. Verwende in Dokumentation und Code Variablen oder Platzhalter:

```powershell
$LocalRepoRoot = Join-Path $env:USERPROFILE "Documents\Agent-Compliance"
Set-Location $LocalRepoRoot
```

Konkrete interne Pfade werden nur in direkten Ausführungsbefehlen außerhalb öffentlicher Dateien verwendet.

## Variante A: automatisiert per Skript

Im lokalen Entwicklungsrepo ausführen:

```powershell
$LocalRepoRoot = Join-Path $env:USERPROFILE "Documents\Agent-Compliance"
Set-Location $LocalRepoRoot

.\scripts\local\New-CommunityTemplateRepository.ps1 `
  -TemplateRepositoryFullName "MKN1411/Agent-Compliance-Community-Template" `
  -Visibility public `
  -Force
```

Das Skript erstellt eine bereinigte Kopie, pusht sie in das Template-Repository und markiert das Repository per GitHub API als Template.

## Variante B: manuell mit GitHub CLI

```powershell
$LocalRepoRoot = Join-Path $env:USERPROFILE "Documents\Agent-Compliance"
Set-Location $LocalRepoRoot

$TemplatePath = Join-Path $env:TEMP "Agent-Compliance-Community-Template"
Remove-Item $TemplatePath -Recurse -Force -ErrorAction SilentlyContinue
New-Item -ItemType Directory -Path $TemplatePath -Force | Out-Null

robocopy . $TemplatePath /MIR /XD .git node_modules data\raw data\processed data\reports /XF *.pfx *.cer *.key .env

Set-Location $TemplatePath
git init
git add .
git commit -m "Initial public community template"

gh repo create MKN1411/Agent-Compliance-Community-Template --public --description "Community template for Agent Compliance Governance" --source . --remote origin --push

gh api -X PATCH repos/MKN1411/Agent-Compliance-Community-Template -f is_template=true
```

## Nach dem Erstellen prüfen

```powershell
gh repo view MKN1411/Agent-Compliance-Community-Template --json name,visibility,isTemplate,url
```

Erwartung:

```json
{
  "name": "Agent-Compliance-Community-Template",
  "visibility": "PUBLIC",
  "isTemplate": true
}
```

## Danach Bootstrap erneut testen

1. `setup/enduser-bootstrap.html` erneut öffnen.
2. Template Owner: `MKN1411`
3. Template Repository: `Agent-Compliance-Community-Template`
4. Enduser Owner: z. B. `<ENDUSER_OWNER>`
5. Zielrepo: `Agent-Compliance-Community`
6. GitHub PAT einfügen.
7. **Enduser-Repo erstellen + konfigurieren + Workflows starten** erneut ausführen.

## Sicherheitsgrenzen

Vor dem Veröffentlichen des Template-Repos prüfen:

- keine Tenant-spezifischen Secrets,
- keine Zertifikate,
- keine `.env` Dateien,
- keine PFX-/CER-/KEY-Dateien,
- keine Rohdaten unter `data/raw`,
- keine verarbeiteten Kundendaten unter `data/processed`,
- keine Report-Artefakte unter `data/reports`,
- keine internen P3-/Kundendokumente,
- keine personenbezogenen lokalen Pfade oder Benutzerprofilnamen.
