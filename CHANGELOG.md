# Changelog

## Unreleased

- Retire the Azure Function deploy path (GitHub Actions “Deploy Function” workflow, `infra/main.bicep`, and Azure-only deploy/bind scripts). Production CMS auth is Oracle Coolify at `https://api.singletonsd.com/v1/cms-auth`. Live Azure resource deletion is a separate infra change.

## 0.1.0 — 2026-08-23

- Bootstrap shared Decap GitHub OAuth Azure Function (`/auth`, `/callback`, `/health`).
- Deploy to `rg-ssd-global` as `ssd-cmsoauth-func-prod-ae` (Linux **B1**, Node 24) with public host `auth.singletonsd.com`. B1 is required for managed TLS on the custom domain.
- ORIGINS: `*.singletonsd.com`, `*.patoperpetua.com`, apex hosts, `localhost:4321`.
