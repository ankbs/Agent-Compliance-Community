# Agent Compliance Template Hygiene Patch

This patch cleans the public community template and hardens the publisher so patch artifacts do not get copied again.

It removes/excludes:

- `.tmp`
- `tmp`
- `replacement`
- `Agent-Compliance-*Patch*`
- `Agent-Compliance-*SecretFlow*`
- `Agent-Compliance-Fix*`
- `scripts/local`
- local render/build folders
- Office/PDF/ZIP artifacts
- certificates and local secret material

It also writes a professional public template README during template generation.

## Apply

```powershell
Set-Location "C:\Users\Micha\OneDrive - Cloud Security and Compliance Services\Dokumente\_Agent-Compliance"

Expand-Archive "$env:USERPROFILE\Downloads\Agent-Compliance-TemplateHygienePatch.zip" -DestinationPath . -Force

.\scripts\local\Invoke-ApplyTemplateHygiene.ps1 -Commit

.\scripts\local\New-CommunityTemplateRepository.ps1 `
  -TemplateRepositoryFullName "MKN1411/Agent-Compliance-Community-Template" `
  -Visibility public `
  -Force
```

## Verify

The public template repository must no longer contain:

- `.tmp`
- `replacement`
- `Agent-Compliance-BrowserSecretImportPatch`
- `Agent-Compliance-OfficialLibsodiumJsPatch`
- any other `Agent-Compliance-*Patch*` folder
