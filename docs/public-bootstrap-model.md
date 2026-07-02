# Public Bootstrap Model für private Repositories

## Ausgangslage

Das Hauptrepository `MKN1411/Agent-Compliance` kann privat bleiben. Für einen externen oder kostenlosen Enduser-Flow ist GitHub Pages aus diesem privaten Entwicklungsrepository jedoch nicht als universeller Einstieg geeignet.

Deshalb wird der Community-Einstieg in drei Ebenen getrennt:

| Ebene | Zweck | Sichtbarkeit |
|---|---|---|
| Privates Entwicklungsrepo | Entwicklung, interne Qualitätssicherung, Architektur, Vorlagenpflege | privat |
| Öffentliches Community-Template | bereinigte Enduser-Version ohne Secrets und ohne interne Inhalte | public / template |
| Enduser-Repository | Kopie im GitHub-Account des Endusers; dort laufen GitHub Actions | private oder public nach Wahl des Endusers |

## Neuer Enduser-Ablauf

Der Enduser startet nicht direkt im privaten Entwicklungsrepo, sondern über eine öffentliche Bootstrap-Seite oder eine lokal bereitgestellte HTML-Datei.

Der Ablauf ist:

1. Enduser öffnet die Bootstrap-Seite.
2. Enduser gibt GitHub Owner, Zielrepository und Tenant-/UPN-Daten ein.
3. Enduser fügt einen kurzlebigen GitHub PAT ein.
4. Die Seite erzeugt ein neues Enduser-Repository aus dem öffentlichen Community-Template.
5. Die Seite setzt GitHub Repository Variables im Enduser-Repository.
6. Die Seite startet die ersten Workflows:
   - `10-bootstrap-plan.yml`
   - `00-validate-worker-requirements.yml`
   - `20-check-permissions.yml`
7. Der Enduser prüft die GitHub Actions Artefakte im eigenen Repository.

## Neue Bootstrap-Seite

Im Entwicklungsrepo wurde eine neue Seite ergänzt:

```text
setup/enduser-bootstrap.html
```

Diese Seite ist für die Veröffentlichung in einem öffentlichen Bootstrap- oder Template-Repository vorbereitet. Sie kann auch lokal geöffnet werden.

## Warum ein öffentliches Community-Template erforderlich ist

Ein Enduser ohne Zugriff auf das private Entwicklungsrepository kann daraus keine GitHub-Repository-Kopie erzeugen. Deshalb muss ein bereinigtes Community-Template bereitgestellt werden, zum Beispiel:

```text
MKN1411/Agent-Compliance-Community-Template
```

Dieses Template darf enthalten:

- Setup-Seiten,
- Workflows,
- Permission-Manifeste,
- Common-Module,
- Check-/Collector-/Reporting-Skripte,
- Dashboard-Grundgerüst,
- öffentliche Dokumentation.

Dieses Template darf nicht enthalten:

- Secrets,
- Tenantdaten,
- Zertifikate,
- Kundendaten,
- interne P3- oder Kundendokumente,
- private Roadmap- oder Angebotsinformationen.

## GitHub Token für den Browser-Flow

Der Token wird nur im Browser für GitHub API-Aufrufe verwendet. Er wird nicht gespeichert, nicht in die URL geschrieben und nicht ins Repository committet.

Für den vollautomatischen Flow benötigt der Token Rechte für:

- Repository aus Template erzeugen,
- Repository Variables setzen,
- GitHub Actions Workflows starten.

Für den manuellen Fallback kann der Enduser stattdessen GitHub UI oder GitHub CLI verwenden.

## Aktuelle Grenzen

Die Bootstrap-Seite automatisiert die GitHub-Seite des MOC. Die Microsoft Entra App Registrations werden dadurch noch nicht vollständig erzeugt.

Noch offen für den nächsten Ausbau:

1. Cloud-Shell-Bootstrap für drei Entra App Registrations,
2. App Permissions je Profil setzen,
3. Zertifikate erzeugen,
4. Admin Consent URLs erzeugen,
5. Client IDs und Zertifikatswerte als GitHub Secrets in das Enduser-Repo schreiben.

## App-Profile bleiben unverändert

Auch im Enduser-Flow bleiben drei App-Profile verpflichtend:

| App-Profil | Zweck |
|---|---|
| Reader App | Lesen, Reporting, Copilot-/Agent-/Kosten-/Verbrauchstransparenz |
| Agent Status Action App | Agent stoppen, blockieren, deaktivieren, Review starten |
| Billing Change App | Budgets, Limits, Billing Policies und PAYG-nahe Änderungen |

Exchange Online bleibt im MOC ausgeschlossen:

- keine Exchange Online Application Permissions,
- kein `Exchange.ManageAsApp`,
- keine Mailbox-Zugriffe,
- keine Exchange Online PowerShell.
