# Agent Compliance Live Dashboard V1 Patch

Purpose:

- Match the provided dashboard direction more closely.
- Publish visible pages for dashboard, agents, config and reports.
- Add live Microsoft Graph tenant inventory collection via the Reader app.
- Add PDF-ready reports and headless PDF rendering in GitHub Actions.
- Keep agent-specific Copilot and cost API sections visibly marked as preview until those APIs are wired.

## Apply

```powershell
Set-Location "C:\Users\Micha\OneDrive - Cloud Security and Compliance Services\Dokumente\_Agent-Compliance"

Expand-Archive "$env:USERPROFILE\Downloads\Agent-Compliance-LiveDashboardV1Patch.zip" -DestinationPath . -Force

.\scripts\local\Invoke-InstallLiveDashboardV1.ps1 `
  -Commit `
  -PublishTemplate `
  -PatchTarget `
  -TargetRepositoryFullName "ankbs/Agent-Compliance-Community"
```

Then watch:

```text
https://github.com/ankbs/Agent-Compliance-Community/actions/workflows/40-build-report.yml
```

Pages:

```text
https://ankbs.github.io/Agent-Compliance-Community/dashboard/
https://ankbs.github.io/Agent-Compliance-Community/agents/
https://ankbs.github.io/Agent-Compliance-Community/config/
https://ankbs.github.io/Agent-Compliance-Community/reports/
```
