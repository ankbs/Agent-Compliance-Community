# Architektur - Agent Compliance Governance

## Community-to-Prod Zielbild

Die Community Edition ist eine Self-Service-Variante mit eigenem GitHub Repository des Endnutzers. Sie nutzt GitHub Actions als Worker und Cloudflare/GitHub Pages optional als statisches Dashboard-Hosting.

Die Managed-Service-Variante übernimmt die gleichen Fachmodule, ersetzt jedoch GitHub Secrets durch Azure Key Vault, JSON-Artefakte durch eine Datenbank und Community-Workflows durch partnerkontrollierte Worker.

## App-Profile

| App | Zweck | Änderungsrechte |
|---|---|---|
| Reader App | Lesen, Checks, Reporting, Dashboard | Keine |
| Agent Status Action App | Agent stoppen/blockieren/deaktivieren, Review starten | Nur Agent-Status |
| Billing Change App | Limits, Budgets, Billing Policies, PAYG-Verwaltung | Billing-/Limit-Änderungen |

## Nicht enthalten im MOC

- Exchange Online PowerShell
- Exchange.ManageAsApp
- Mailbox-Zugriffe
- Purview-Schreibaktionen
- unspezifische Vollzugriffe
