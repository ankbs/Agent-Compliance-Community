# Production Flow No Demo Patch

Implements:

- 30 - Run Collectors collects only.
- 40 - Build Report does not run collectors.
- 40 starts automatically only after 30 completed successfully (`workflow_run`).
- Manual 40 downloads the latest successful collector artifact.
- Demo agents, demo credits, demo costs and fake budgets are removed.
- Missing APIs show as `Nicht verfügbar`, `Nicht implementiert` or `Berechtigung fehlt`.

Apply:

```powershell
Set-Location "C:\Users\Micha\OneDrive - Cloud Security and Compliance Services\Dokumente\_Agent-Compliance"

Expand-Archive "$env:USERPROFILE\Downloads\Agent-Compliance-ProductionFlowNoDemoPatch.zip" -DestinationPath . -Force

.\scripts\local\Invoke-InstallProductionFlowNoDemo.ps1 `
  -Commit `
  -PublishTemplate `
  -PatchTarget `
  -RunCollectors `
  -TargetRepositoryFullName "ankbs/Agent-Compliance-Community"
```
