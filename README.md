# Agent Compliance Community Template

Public template for Agent Compliance Governance.

This repository is intended for end-user deployment. It must not contain local development artifacts, temporary build folders, patch packages, personal paths, certificates, tenant data, customer data, or internal working directories.

## End-user flow

1. Create a repository from this template.
2. Open the published setup page.
3. Run the Entra bootstrap command shown by the setup page.
4. Confirm Admin Consent.
5. Upload the locally generated github-secrets.json in the setup page.
6. Start the final permission check.

## Security boundaries

- No local PowerShell module installation is performed by the end-user bootstrap.
- No NuGet package installation is performed by the end-user bootstrap.
- GitHub tokens are not stored in the repository.
- Certificates and generated JSON files remain local and must not be committed.
- GitHub repository secrets are encrypted in the browser before being sent to GitHub.

## Repository hygiene

The public template intentionally excludes:

- .tmp
- 	mp
- eplacement
- patch package folders
- scripts/local
- local render/build folders
- certificate files
- Office/PDF exports
- compressed patch archives

