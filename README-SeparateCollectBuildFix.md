# Separate Collect and Build Patch

This patch restores the original architecture:

- `30 - Run Collectors` collects data only and uploads `raw-agent-compliance-data`.
- `40 - Build Report` downloads the latest successful collector artifact and builds/publishes the dashboard.
- `40 - Build Report` no longer executes collectors.
- `Get-DomainReadinessData.ps1` is fixed to avoid the previous PowerShell argument type mismatch.

Apply:

```powershell
Set-Location "C:\Users\Micha\OneDrive - Cloud Security and Compliance Services\Dokumente\_Agent-Compliance"

Expand-Archive "$env:USERPROFILE\Downloads\Agent-Compliance-SeparateCollectBuildFixPatch.zip" -DestinationPath . -Force

.\scripts\local\Invoke-InstallSeparateCollectBuildFix.ps1 `
  -Commit `
  -PublishTemplate `
  -PatchTarget `
  -RunCollectorsThenReport `
  -TargetRepositoryFullName "ankbs/Agent-Compliance-Community"
```
