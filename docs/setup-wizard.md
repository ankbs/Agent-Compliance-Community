# Setup-Seite / Community Wizard

Die Community Edition enthält zwei Setup-Seiten:

```text
setup/enduser-bootstrap.html
setup/index.html
```

## Welche Seite wofür?

| Seite | Zweck |
|---|---|
| `setup/enduser-bootstrap.html` | Neuer Enduser-Einstieg: zuerst Enduser-Repository aus einem Community-Template erzeugen, danach Daten setzen und Workflows starten |
| `setup/index.html` | Konfiguration eines bereits vorhandenen Repositorys, lokal oder aus einer Page heraus |

## Warum der neue Enduser Bootstrap nötig ist

Das Hauptrepository kann privat bleiben. Eine GitHub Page aus einem privaten Entwicklungsrepository ist für Enduser aber kein verlässlicher Community-Einstieg, insbesondere wenn der Enduser keinen Zugriff auf das private Repository hat.

Deshalb ist der geplante Community-Flow:

1. öffentliche Bootstrap-Seite öffnen,
2. Kopie aus einem öffentlichen Community-Template im GitHub-Account des Endusers erstellen,
3. Tenant-/UPN-Daten erfassen,
4. GitHub Repository Variables im Enduser-Repo setzen,
5. Initial-Workflows im Enduser-Repo starten.

## `setup/enduser-bootstrap.html`

Diese Seite ist für den späteren öffentlichen Betrieb gedacht. Sie kann aus einem öffentlichen Bootstrap- oder Template-Repository als GitHub Page bereitgestellt werden.

Sie kann:

- ein neues Enduser-Repository aus einem GitHub Template erzeugen,
- Tenant ID, Tenant Domain und UPNs per Formular oder URL-Parameter übernehmen,
- GitHub Repository Variables im Enduser-Repository setzen,
- initiale GitHub Actions Workflows starten,
- Fallback-Befehle für GitHub CLI ausgeben.

## `setup/index.html`

Diese Seite bleibt für lokale Tests und für bereits vorhandene Zielrepositories bestehen.

Sie erzeugt:

- Workflow-Inputs für `10 - Bootstrap Plan`,
- GitHub Variables für Tenant- und UPN-Werte,
- GitHub Secrets-Platzhalter für die drei App-Profile,
- Admin-Consent-URL-Vorlagen,
- lokale Testbefehle,
- eine verständliche Testreihenfolge.

## Datenschutz / Sicherheit

Beide Seiten laufen rein clientseitig im Browser.

Der GitHub Token wird nicht gespeichert, nicht in die URL geschrieben und nicht ins Repository committet. Er wird nur für die direkten GitHub API-Aufrufe im Browser verwendet. Nach dem Test sollte der Token widerrufen werden.

Tenant- und UPN-Werte können als GitHub Repository Variables gespeichert werden. Zertifikate und Client IDs werden später als GitHub Secrets gesetzt.

## App-Profile

Die Setup-Seiten bilden die drei verpflichtenden MOC-App-Profile ab:

1. Reader App
2. Agent Status Action App
3. Billing Change App

Exchange Online ist im Setup ausdrücklich ausgeschlossen.

## Initialtest

Für den ersten Test ohne bestehende App-Secrets wird empfohlen:

```text
20 - Check Permissions
skip_certificate_secret_checks = true
```

Damit können Repository-Struktur, Variables, Permission-Manifeste und MOC-Sicherheitsgrenzen geprüft werden, bevor echte App-Registrierungen und Zertifikate vorhanden sind.

## Volltest

Nach Erstellung der App Registrations und Secrets wird erneut geprüft:

```text
20 - Check Permissions
skip_certificate_secret_checks = false
```

Dann müssen alle drei App-Profile mit ihren Client IDs und Zertifikatssecrets vorhanden sein.
