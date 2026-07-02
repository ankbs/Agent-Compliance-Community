# Berechtigungsmodell

## Grundsatz

Für den MOC werden ausschließlich Berechtigungen verwendet, die für Copilot-, Agent-, KI-, Verbrauchs-, Abrechnungs- und Governance-Daten benötigt werden.

Nicht enthalten:

- Exchange Online Application Permissions
- Exchange.ManageAsApp
- Mailbox-Zugriffe
- Exchange Online PowerShell

## App-Profile

### Reader App

Zweck: Dashboard, Reports, Checks, Verbrauchs- und Governance-Transparenz.

### Agent Status Action App

Zweck: Agent stoppen, blockieren, deaktivieren, Review starten, Owner erinnern.

### Billing Change App

Zweck: Budgets, Limits, Billing Policies und PAYG-nahe Konfigurationen ändern. Diese App ist im MOC verpflichtend, aber jede Ausführung erfolgt über Freigabe und Audit.

## UPNs

- Authorized Reader UPN
- Authorized Status Admin UPN
- Authorized Change Admin UPN

Diese UPNs werden in Community als Governance- und Freigabeparameter genutzt. Application Permissions werden nicht automatisch auf einzelne UPNs beschränkt; die Durchsetzung erfolgt über GitHub Environments, Reviewer und Workflow-Gates.
