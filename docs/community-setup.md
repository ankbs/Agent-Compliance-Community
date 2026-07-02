# Community Setup

## Ziel

Die Community Edition wird worker-first betrieben. Der lokale Client des Endnutzers bleibt möglichst unverändert. GitHub Actions und Azure Cloud Shell übernehmen die technische Ausführung.

Der Tester startet zunächst mit einem lokalen Repository. Deshalb enthält das Repository jetzt eine lokale Setup-Seite:

```text
setup/index.html
```

Diese Seite kann direkt aus dem Dateisystem geöffnet werden und benötigt keinen lokalen Webserver.

## Datenschutz bei lokalen Pfaden

Öffentliche Dokumentation darf keine personenbezogenen lokalen Windows-, OneDrive- oder Benutzerprofilpfade enthalten. Beispiele verwenden neutrale Platzhalter oder Variablen:

```powershell
$LocalRepoRoot = Join-Path $env:USERPROFILE "Documents\Agent-Compliance"
```

Konkrete interne Pfade werden nur in direkten Ausführungsanweisungen oder lokalen, nicht öffentlichen Notizen verwendet.

## Ablauf für den Enduser-Tester

1. Lokales Repository aktualisieren.
2. Setup-Seite öffnen.
3. Community Edition prüfen und erforderliche Daten erfassen.
4. Workflow-Inputs für `10 - Bootstrap Plan` aus der Setup-Seite übernehmen.
5. GitHub Variables aus der Setup-Seite setzen oder manuell in GitHub eintragen.
6. Workflow `10 - Bootstrap Plan` ausführen.
7. Workflow `00 - Validate Worker Requirements` ausführen.
8. Workflow `20 - Check Permissions` zunächst mit `skip_certificate_secret_checks=true` ausführen.
9. Azure Cloud Shell Bootstrap ausführen oder App-Registrierungen manuell erstellen.
10. GitHub Secrets gemäß [GitHub Actions Configuration](github-actions-configuration.md) setzen.
11. Workflow `20 - Check Permissions` erneut mit `skip_certificate_secret_checks=false` ausführen.
12. Workflow `30 - Run Collectors` ausführen.
13. Dashboard/Report bauen.

## Lokaler Start der Setup-Seite

```powershell
$LocalRepoRoot = Join-Path $env:USERPROFILE "Documents\Agent-Compliance"
Set-Location $LocalRepoRoot
git pull
Invoke-Item .\setup\index.html
```

Die Setup-Seite läuft lokal im Browser. Sie sendet keine Daten an P3, GitHub oder Microsoft. Alle Werte werden nur im Browser erzeugt und zum Kopieren angezeigt.

## Abgefragte Daten

| Feld | Beschreibung |
|---|---|
| GitHub Owner | Benutzer oder Organisation, z. B. `MKN1411` |
| GitHub Repository | Zielrepository, z. B. `Agent-Compliance` |
| Tenant ID | Microsoft Entra Tenant GUID |
| Tenant Domain | Primäre Tenant-Domain, z. B. `contoso.onmicrosoft.com` |
| Reader UPN | berechtigte Person für Reports und Read-only-Zugriffe |
| Status Admin UPN | berechtigte Person für Agent-Statusmaßnahmen |
| Change Admin UPN | berechtigte Person für Billing-/Limit-Änderungen |
| Notification Mail | Mailbox oder Verteiler für Hinweise |
| Lokaler Repo-Pfad | lokaler Sync-Root als frei wählbarer Enduser-Pfad |

## App-Profile im MOC

Alle drei App-Profile sind Bestandteil des MOC:

| App-Profil | Zweck | Änderung erlaubt? |
|---|---|---:|
| Reader App | Reports, Checks, Copilot-/Agent-/KI-/Kosten-Transparenz | Nein |
| Agent Status Action App | Agent stoppen, blockieren, deaktivieren, Review starten | Ja, nur mit Freigabe |
| Billing Change App | Budgets, Limits, Billing Policies und PAYG-nahe Konfigurationen | Ja, nur mit Freigabe und Dry-Run |

## Initialtest ohne App-Secrets

Der Tester kann die ersten Workflows ausführen, bevor die drei Entra Apps und Zertifikats-Secrets vorhanden sind.

### 1. Bootstrap Plan

```text
Actions -> 10 - Bootstrap Plan -> Run workflow
```

Die Werte werden aus der Setup-Seite übernommen.

### 2. Worker Requirements

```text
Actions -> 00 - Validate Worker Requirements -> Run workflow
skip_module_install = false
```

Dieser Workflow installiert bzw. prüft Module nur auf dem GitHub Runner, nicht lokal.

### 3. Permission Checks ohne Zertifikats-Secrets

```text
Actions -> 20 - Check Permissions -> Run workflow
skip_certificate_secret_checks = true
```

Damit werden Repository-Struktur, Variables, Permission-Manifeste, App-Profil-Logik und Exchange-Ausschluss geprüft.

## Volltest mit App-Secrets

Nach App-Erstellung und Secret-Befüllung:

```text
Actions -> 20 - Check Permissions -> Run workflow
skip_certificate_secret_checks = false
```

Dann müssen alle drei App-Profile vollständig konfiguriert sein.

## GitHub Actions Konfiguration

Die Workflows erwarten getrennte Repository Variables und Secrets für die drei App-Profile. Die Details stehen in [GitHub Actions Configuration](github-actions-configuration.md).

Wichtig:

- `TENANT_ID`, `TENANT_DOMAIN` und die drei berechtigten UPNs werden als Repository Variables geführt.
- App-Client-IDs und Zertifikate werden als GitHub Secrets geführt.
- `FEATURE_EXCHANGE_ONLINE` muss für diesen MOC `false` bleiben.

## Keine lokale Modulinstallation

Alle PowerShell-Module werden nur auf dem GitHub Actions Runner oder in Azure Cloud Shell installiert. Der lokale Rechner des Endnutzers wird nicht verändert.

## Sicherheitsgrenze

Exchange Online, Mailbox-Zugriffe und Exchange PowerShell sind im MOC nicht enthalten. Status- und Billing-Aktionen müssen über getrennte Workflows, GitHub Environments, Freigabe und Audit-Log abgesichert werden.
