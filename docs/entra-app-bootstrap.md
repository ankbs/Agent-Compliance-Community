# Entra App Bootstrap

This package creates the Agent Compliance Community Entra app registrations.

## Apps

- Agent Compliance Community - Reader
- Agent Compliance Community - Agent Status Action
- Agent Compliance Community - Billing Change

## WorkIQ prerequisite

The WorkIQ service principal is a Microsoft resource prerequisite and is not one of our apps.

Resource AppId:

```text
fdcc1f02-fc51-4226-8753-f668596af7f7
```

The bootstrap checks if the service principal exists and creates it if needed. This requires `Application.ReadWrite.All`.

## Diagnostic run

```powershell
$Out = Join-Path (Get-Location).Path ".out\entra-bootstrap"
New-Item -ItemType Directory -Path $Out -Force | Out-Null

.\scripts\bootstrap\Invoke-EntraAppBootstrap.ps1 `
  -TenantId "<TENANT_ID>" `
  -TenantDomain "<TENANT_DOMAIN>" `
  -GitHubRepository "<OWNER>/<REPO>" `
  -OutputDirectory $Out `
  -AllowUnresolvedPermissions
```

## Secret upload

```powershell
.\.out\entra-bootstrap\set-github-secrets.ps1
```

## Consent run

After the diagnostic run succeeds, rerun with:

```powershell
-GrantApplicationAdminConsent
```

## Notes

- `.out/entra-bootstrap` contains certificates, passwords and GitHub secret values.
- Do not commit `.out/`.
- Default certificate validity is one year to avoid Graph key credential lifetime validation issues.
