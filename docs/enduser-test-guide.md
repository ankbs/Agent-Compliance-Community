# Enduser-Testanleitung: Community Edition

Diese Anleitung beschreibt den neuen Enduser-Test der Community Edition. Der Tester startet nicht mehr direkt aus dem privaten Entwicklungsrepository, sondern über eine Bootstrap-Seite.

## Zielbild

Der Ablauf ist:

1. Bootstrap-Seite öffnen.
2. Enduser-Repository aus einem öffentlichen Community-Template erzeugen.
3. Tenant ID, Tenant Domain und berechtigte UPNs erfassen.
4. GitHub Repository Variables im Enduser-Repository setzen.
5. Initiale GitHub Actions Workflows im Enduser-Repository starten.
6. Artefakte und Reports im Enduser-Repository prüfen.

## Bootstrap-Seite

Für diesen Ablauf wurde ergänzt:

```text
setup/enduser-bootstrap.html
```

Diese Seite ist für den späteren öffentlichen Betrieb vorgesehen. Für lokale Tests kann sie direkt geöffnet werden:

```powershell
Invoke-Item .\setup\enduser-bootstrap.html
```

## Abgefragte Daten

| Bereich | Felder |
|---|---|
| Template | Template Owner, Template Repository |
| Enduser-Repo | Ziel-Owner, Ziel-Repository, Sichtbarkeit |
| Microsoft Tenant | Tenant ID, Tenant Domain |
| Berechtigte Personen | Reader UPN, Status Admin UPN, Change Admin UPN |
| Benachrichtigung | Notification Mail |

## Automatischer Initiallauf

Die Bootstrap-Seite kann den ersten Lauf anstoßen:

1. Repository-Kopie aus Template erstellen,
2. Repository Variables setzen,
3. `10-bootstrap-plan.yml` starten,
4. `00-validate-worker-requirements.yml` starten,
5. `20-check-permissions.yml` starten.

Für den ersten Test ohne vorhandene App-Secrets wird verwendet:

```text
skip_certificate_secret_checks = true
```

Damit prüft der Workflow Struktur, Variables, Manifeste, Exchange-Ausschluss und App-Profil-Logik, aber noch nicht die Zertifikats-Secrets.

## App-Profile

| App-Profil | Pflicht im MOC | Zweck |
|---|---:|---|
| Reader App | Ja | Lesen, Reports, Dashboards, Kosten-/Verbrauchstransparenz |
| Agent Status Action App | Ja | Agent stoppen, blockieren, deaktivieren, Review starten |
| Billing Change App | Ja | Budgets, Limits, Billing Policies und PAYG-nahe Konfigurationen |

## Ausschlüsse im MOC

Folgende Workloads und Rechte sind im MOC nicht enthalten:

- Exchange Online Application Permissions,
- `Exchange.ManageAsApp`,
- Mailbox-Zugriffe,
- Exchange Online PowerShell,
- automatische destruktive Aktionen ohne Freigabe.

## Volltest

Nach Erstellung der drei App Registrations und Zertifikate müssen die Client IDs und Zertifikatswerte als GitHub Secrets gesetzt werden. Danach wird `20 - Check Permissions` erneut ausgeführt mit:

```text
skip_certificate_secret_checks = false
```

## Nächster Ausbau

Nach erfolgreichem Initialtest folgen:

1. öffentliches Community-Template finalisieren,
2. Cloud-Shell-Bootstrap für App-Erstellung,
3. automatische Erzeugung der drei Entra Apps,
4. Setzen der GitHub Secrets,
5. echte API-Probes für Copilot-/Agent-/Billing-Zugriffe,
6. Dashboard-Build aus Check- und Collector-Artefakten.
