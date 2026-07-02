# Sicherheitsgrenzen

## Community Edition

- Der GitHub PAT wird nur für das Bootstrap verwendet.
- Der PAT darf nicht gespeichert werden.
- Microsoft-Zugriffe erfolgen über getrennte App-Profile.
- Es werden im MOC keine Exchange-Online-Berechtigungen angefordert.
- Jede Status- oder Billing-Änderung benötigt einen manuellen Freigabeschritt.
- Secrets liegen im Repository des Endnutzers und später im Managed Service in Azure Key Vault.
- Aktionen werden mit Zeitstempel, Workflow Run ID und Freigabeperson protokolliert.

## Destruktive Aktionen

Community Standard:

- Standardmodus = Dry Run.
- Änderungen nur über explizites `workflow_dispatch`.
- Environment Protection Rules für Status- und Billing-Workflows.
