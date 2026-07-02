[CmdletBinding(SupportsShouldProcess)]
param(
    [Parameter(Mandatory)][string]$Owner,
    [Parameter(Mandatory)][string]$Repository,
    [Parameter(Mandatory)][hashtable]$Secrets,
    [Parameter(Mandatory)][string]$GitHubToken
)
# TODO: Retrieve repository public key, encrypt secret values with libsodium, write secrets via GitHub REST API.
# The PAT must never be written to disk or logs.
Write-Host "TODO: Set $($Secrets.Count) GitHub Actions secrets for $Owner/$Repository"
