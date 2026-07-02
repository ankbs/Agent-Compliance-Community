# GitHub Pages Automation

## Ziel

Die Community Edition soll für Enduser nicht mehr mit einer lokalen HTML-Datei starten, sondern über eine GitHub Page. Die Seite dient als Setup Wizard und kann die ersten GitHub-Actions-Schritte automatisieren.

## Veröffentlichung

Der Workflow `Deploy Setup Page` veröffentlicht die Datei `setup/index.html` als statische GitHub Page.

Erwartete Projekt-URL:

```text
https://mkn1411.github.io/Agent-Compliance/
```

Wenn die Seite beim ersten Versuch noch nicht erreichbar ist, muss in den Repository Settings unter **Pages** als Source **GitHub Actions** ausgewählt und danach der Workflow erneut gestartet werden.

## Automatische Vorbefüllung

Die Setup-Seite kann Werte automatisch übernehmen aus:

1. der GitHub-Pages-URL,
2. URL-Query-Parametern,
3. lokalem Browser Storage für nicht geheime Eingaben.

Beispiel:

```text
https://mkn1411.github.io/Agent-Compliance/?tenantId=00000000-0000-0000-0000-000000000000&tenantDomain=contoso.onmicrosoft.com&readerUpn=reader@contoso.com&statusAdminUpn=ai-status-admin@contoso.com&changeAdminUpn=billing-admin@contoso.com&notificationMail=m365-governance@contoso.com
```

Unterstützte Parameter:

| Parameter | Zielwert |
|---|---|
| `owner` / `githubOwner` | GitHub Owner |
| `repo` / `githubRepo` | GitHub Repository |
| `tenantId` / `tenant_id` | Microsoft Entra Tenant ID |
| `tenantDomain` / `tenant_domain` | Primäre Tenant Domain |
| `readerUpn` / `reader_upn` | Berechtigter Reader |
| `statusAdminUpn` / `status_admin_upn` | Berechtigter Status Admin |
| `changeAdminUpn` / `change_admin_upn` | Berechtigter Change Admin |
| `notificationMail` / `notification_mail` | Benachrichtigungsempfänger |
| `mode` | `initial` oder `full` |
| `ref` / `branchRef` | Branch oder Ref, Standard `main` |

## GitHub API Automatisierung

Die Seite kann mit einem kurzlebigen GitHub Token:

- Repository Variables setzen oder aktualisieren,
- `10-bootstrap-plan.yml` starten,
- `00-validate-worker-requirements.yml` starten,
- `20-check-permissions.yml` starten.

Erforderliche Fine-grained PAT Rechte für das Zielrepository:

- Metadata: read
- Variables: read/write
- Actions: read/write

Der Token wird nicht gespeichert, nicht in der URL abgelegt und nicht in das Repository geschrieben.

## Workflow-Reihenfolge

Der automatische Initiallauf führt aus:

1. Repository Variables setzen,
2. `10 - Bootstrap Plan` starten,
3. `00 - Validate Worker Requirements` starten,
4. `20 - Check Permissions` starten.

Beim Initialtest wird `skip_certificate_secret_checks=true` verwendet. Dadurch kann geprüft werden, ob Repo-Struktur, Manifeste und Governance-Parameter korrekt sind, auch wenn die Entra Apps und Zertifikats-Secrets noch nicht existieren.

## Sicherheitsgrenzen

Die GitHub Page kann nur GitHub-seitige Initialisierung automatisieren. Für Microsoft Entra ist weiterhin ein initialer Trust erforderlich.

Noch nicht vollständig automatisiert:

- Entra App Registrations erstellen,
- API Permissions je App-Profil setzen,
- Admin Consent erteilen,
- Zertifikate erzeugen und an App Registrations hängen,
- erzeugte Client IDs und Zertifikatsdaten als GitHub Secrets setzen.

Diese Schritte werden als nächstes über einen Cloud-Shell-Bootstrap vorbereitet.

## Warum kein Token in der URL?

Der GitHub Token darf niemals in Query-Parametern, Deep Links, Commits oder Workflow-Inputs abgelegt werden. Query-Parameter können in Browser-Historie, Logs oder Screenshots landen. Deshalb nutzt die Seite ein Passwortfeld und hält den Token nur temporär im Browser-Kontext.
