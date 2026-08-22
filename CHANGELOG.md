# Changelog

## 0.1.0 — 2026-08-23

- Bootstrap shared Decap GitHub OAuth Azure Function (`/auth`, `/callback`, `/health`).
- Deploy to `rg-ssd-global` as `ssd-cmsoauth-func-prod-ae` (Linux **B1**, Node 24) with public host `auth.singletonsd.com`. B1 is required for managed TLS on the custom domain.
- ORIGINS: `*.singletonsd.com`, `*.patoperpetua.com`, apex hosts, `localhost:4321`.
