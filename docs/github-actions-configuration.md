# GitHub Actions Configuration

This document defines the repository variables and secrets required for the Community MOC worker workflows.

## Repository Variables

Repository variables are not secrets. They are used to steer governance, approvals and reporting.

| Variable | Required | Purpose |
|---|---:|---|
| `TENANT_ID` | Yes | Microsoft Entra tenant GUID. |
| `TENANT_DOMAIN` | Yes | Primary tenant domain, for example `contoso.onmicrosoft.com`. |
| `AUTHORIZED_READER_UPN` | Yes | Person allowed to review dashboard and read-only reports. |
| `AUTHORIZED_STATUS_ADMIN_UPN` | Yes | Person allowed to approve agent status actions. |
| `AUTHORIZED_CHANGE_ADMIN_UPN` | Yes | Person allowed to approve billing, budget and limit changes. |
| `NOTIFICATION_MAIL` | Recommended | Mailbox or distribution list for workflow notifications and reports. |
| `FEATURE_EXCHANGE_ONLINE` | Yes | Must remain `false` for this MOC. |

## Repository Secrets

Repository secrets are used by GitHub Actions workers. Do not commit these values to the repository.

### Reader App

| Secret | Required | Purpose |
|---|---:|---|
| `CAG_READER_CLIENT_ID` | Yes | Client ID of the Reader App registration. |
| `CAG_READER_CERTIFICATE_BASE64` | Yes | Base64 encoded PFX certificate for Reader App app-only auth. |
| `CAG_READER_CERTIFICATE_PASSWORD` | Yes | Password for the Reader App PFX certificate. |

### Agent Status Action App

| Secret | Required | Purpose |
|---|---:|---|
| `CAG_STATUS_CLIENT_ID` | Yes | Client ID of the Agent Status Action App registration. |
| `CAG_STATUS_CERTIFICATE_BASE64` | Yes | Base64 encoded PFX certificate for status action app-only auth. |
| `CAG_STATUS_CERTIFICATE_PASSWORD` | Yes | Password for the status action PFX certificate. |

### Billing Change App

| Secret | Required | Purpose |
|---|---:|---|
| `CAG_BILLING_CLIENT_ID` | Yes | Client ID of the Billing Change App registration. |
| `CAG_BILLING_CERTIFICATE_BASE64` | Yes | Base64 encoded PFX certificate for billing change app-only auth. |
| `CAG_BILLING_CERTIFICATE_PASSWORD` | Yes | Password for the billing change PFX certificate. |

## Workflow Order

Run the workflows in this order:

1. `10 - Bootstrap Plan`
2. Cloud Shell bootstrap or manual Microsoft Entra app registration
3. Set repository variables and secrets
4. `00 - Validate Worker Requirements`
5. `20 - Check Permissions`
6. Collector and report workflows

## Permission Boundary

The MOC intentionally excludes Exchange Online, mailbox access, Exchange Online PowerShell and `Exchange.ManageAsApp`.

The three app profiles are mandatory, but they are separated by purpose:

- Reader App: read-only visibility and reporting.
- Agent Status Action App: stop, block or status-related actions only.
- Billing Change App: budget, billing policy and capacity/limit changes only.

Status and billing actions must use dry-run, explicit approval and audit logging before any live change is added.
