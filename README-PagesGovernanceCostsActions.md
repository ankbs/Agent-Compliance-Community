# Governance / Costs / Actions Pages Patch

Adds dedicated pages for Governance, Costs and Actions.

- Governance shows real Graph policy/role/directory signals from collector output.
- Costs shows real M365 SKU data and marks missing PAYG/Azure Budget/Token cost sources as unavailable.
- Actions shows findings/recommendations and is no longer a dashboard anchor.
- Navigation links point to real pages instead of broken/misleading anchors.

Apply:

```powershell
Set-Location "C:\Users\Micha\OneDrive - Cloud Security and Compliance Services\Dokumente\_Agent-Compliance"

Expand-Archive "$env:USERPROFILE\Downloads\Agent-Compliance-PagesGovernanceCostsActionsPatch.zip" -DestinationPath . -Force

.\scripts\local\Invoke-InstallPagesGovernanceCostsActions.ps1 `
  -Commit `
  -PatchTarget `
  -RunReport `
  -TargetRepositoryFullName "ankbs/Agent-Compliance-Community"
```
