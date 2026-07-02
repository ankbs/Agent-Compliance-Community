# Status Action App Access Checks

Generated: 2026-06-30T14:12:18.7842862Z

Total: **7** | Passed: **2** | Failed: **5**

| Status | Severity | Category | Check | Message | Remediation |
|---|---|---|---|---|---|
| ❌ | High | Configuration | Required value: TENANT_ID | Value 'TENANT_ID' is missing. | Set the required value 'TENANT_ID' as a repository variable, secret or workflow input. |
| ❌ | High | Configuration | Required value: TENANT_DOMAIN | Value 'TENANT_DOMAIN' is missing. | Set the required value 'TENANT_DOMAIN' as a repository variable, secret or workflow input. |
| ❌ | High | Configuration | Required value: AUTHORIZED_STATUS_ADMIN_UPN | Value 'AUTHORIZED_STATUS_ADMIN_UPN' is missing. | Set the required value 'AUTHORIZED_STATUS_ADMIN_UPN' as a repository variable, secret or workflow input. |
| ❌ | High | Configuration | Required value: CAG_STATUS_CLIENT_ID | Value 'CAG_STATUS_CLIENT_ID' is missing. | Set the required value 'CAG_STATUS_CLIENT_ID' as a repository variable, secret or workflow input. |
| ❌ | Info | Permission | User assigned to Enterprise App | Status App credentials are not configured or connection failed. |  |
| ✅ | Info | Permission | Status App cannot change billing budgets | Status actions are isolated from billing and budget changes. |  |
| ✅ | Info | Action | Manual approval required | Status actions must be run through an approval-gated workflow. |  |
