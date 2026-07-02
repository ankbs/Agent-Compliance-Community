# Billing Change App Access Checks

Generated: 2026-06-30T14:12:19.5034984Z

Total: **7** | Passed: **2** | Failed: **5**

| Status | Severity | Category | Check | Message | Remediation |
|---|---|---|---|---|---|
| ❌ | High | Configuration | Required value: TENANT_ID | Value 'TENANT_ID' is missing. | Set the required value 'TENANT_ID' as a repository variable, secret or workflow input. |
| ❌ | High | Configuration | Required value: TENANT_DOMAIN | Value 'TENANT_DOMAIN' is missing. | Set the required value 'TENANT_DOMAIN' as a repository variable, secret or workflow input. |
| ❌ | High | Configuration | Required value: AUTHORIZED_CHANGE_ADMIN_UPN | Value 'AUTHORIZED_CHANGE_ADMIN_UPN' is missing. | Set the required value 'AUTHORIZED_CHANGE_ADMIN_UPN' as a repository variable, secret or workflow input. |
| ❌ | High | Configuration | Required value: CAG_BILLING_CLIENT_ID | Value 'CAG_BILLING_CLIENT_ID' is missing. | Set the required value 'CAG_BILLING_CLIENT_ID' as a repository variable, secret or workflow input. |
| ❌ | Info | Permission | User assigned to Enterprise App | Billing App credentials are not configured or connection failed. |  |
| ✅ | Info | Configuration | Billing Change App is mandatory in MOC | The Billing Change App is part of the MOC, but changes require dry-run, approval and audit. |  |
| ✅ | Info | Action | Dry-run required for billing changes | Billing and limit changes must first run in dry-run mode. |  |
