# Executive Domains UI Patch

Changes:

- Tenant name/domain/id moves into a second header row.
- Adds executive orientation for CISO, CFO and CIO.
- Adds domain cards for:
  - M365 Admin & Copilot
  - Agent Registry & Governance
  - Power Platform
  - Azure AI / BYO Models
  - Cost & Billing
  - Security & Governance
  - M365 Usage Reporting
  - Reports
- Adds live Microsoft Graph read probes for organization, SKUs, users, groups, applications, service principals, directory roles, conditional access and reports.
- Explicitly marks Power Platform, Azure AI and Azure Cost as planned/RBAC-required until those APIs are wired.

Apply:

```powershell
Set-Location "C:\Users\Micha\OneDrive - Cloud Security and Compliance Services\Dokumente\_Agent-Compliance"

Expand-Archive "$env:USERPROFILE\Downloads\Agent-Compliance-ExecutiveDomainsUIPatch.zip" -DestinationPath . -Force

.\scripts\local\Invoke-InstallExecutiveDomainsUI.ps1 `
  -Commit `
  -PublishTemplate `
  -PatchTarget `
  -TargetRepositoryFullName "ankbs/Agent-Compliance-Community"
```
