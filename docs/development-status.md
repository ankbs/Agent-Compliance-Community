# Development Status

## Current implementation focus

- Worker-first execution with GitHub Actions.
- No local Microsoft module installation for end users.
- No Exchange Online workload dependencies in the MOC.
- Three mandatory Microsoft Entra app profiles:
  - Reader App
  - Agent Status Action App
  - Billing Change App

## Implemented in first development pass

- Check result helper module extended with required-value checks and Markdown summaries.
- Microsoft Graph helper module extended for bootstrap-oriented app profile work.
- Certificate generation hardened with random password and explicit certificate metadata.
- Community setup documentation updated with the current workflow sequence.
- Bootstrap planning workflow added.
- Reader, Status Action and Billing Change check scripts changed from pure placeholders to configuration checks.

## Next steps

1. Harden runner validation workflow with artifacts.
2. Complete Cloud Shell bootstrap script.
3. Wire GitHub Variables and Secrets into the permission-check workflow.
4. Add real API probes after the first Entra app bootstrap has been completed.
5. Add dashboard data model validation.
