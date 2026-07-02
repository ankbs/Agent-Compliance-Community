# Entra Web Invoke Bootstrap

This bootstrap flow mirrors the earlier GRC-M365-Asset pattern: the setup page asks for tenant/repository data and displays an Invoke command. The administrator runs the command in PowerShell 7 and completes Microsoft Graph delegated sign-in in the browser/device login flow.

## Files

- `setup/entra-bootstrap.html` generates the Invoke command.
- `scripts/bootstrap/Invoke-GRCEntraAppBootstrap.ps1` creates or updates the Entra app registrations.
- `.out/entra-bootstrap/entra-bootstrap-summary.json` contains the result including Admin Consent URLs.
- `.out/entra-bootstrap/github-secrets.json` contains values for later GitHub secret import and must never be committed.

## Standard flow

1. Open `setup/entra-bootstrap.html` from the GitHub Page.
2. Fill Tenant ID, Tenant Domain and repository values.
3. Copy the generated Invoke command.
4. Run it in PowerShell 7.
5. Complete Microsoft Graph login.
6. Open the printed Admin Consent URLs.
7. Import `github-secrets.json` through the setup page secret-import process.
8. Run `20 - Check Permissions` with `skip_certificate_secret_checks=false`.

## Security

The `.out/` directory contains certificates, passwords and secret import JSON. It must remain local/private and must not be committed.
