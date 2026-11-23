# AGENTS.md — cms-oauth-kit

Shared GitHub OAuth proxy for **Decap CMS** (`/admin`) on Singleton SD sites.

GitHub: `singleton-sd/cms-oauth-kit`
Public origin: `https://api.singletonsd.com/v1/cms-auth` (Oracle Coolify behind the API gateway)
Azure: Key Vault only (ADR-007), vault `ssd-global-kv-prod-ae`

This repository **is** the OAuth proxy library/service code. Do not add Contact forms, marketing APIs, or product HTTP here. Production traffic is not served by the retired Azure Function; it is served from Coolify at the public origin above.

## Consumer contract

In the site’s Decap `config.yml`:

```yaml
backend:
  name: github
  repo: singleton-sd/<consumer-repo>
  branch: main
  base_url: https://api.singletonsd.com
  auth_endpoint: v1/cms-auth/auth
```

That is the whole client change. Editors need **write** access to `backend.repo`. The service only brokers GitHub OAuth; the token is the editor’s.

Open `/admin` on a hostname allowed by `ORIGINS`. Do not open it on a raw `*.azurestaticapps.net` default host.

### ORIGINS (locked)

```text
*.singletonsd.com,*.patoperpetua.com,singletonsd.com,patoperpetua.com,localhost:4321
```

- `*.example.com` does **not** match the apex `example.com` — both are listed.
- Nested subdomains match (`plattform-kit.poc.singletonsd.com`, `www.patoperpetua.com`).
- `localhost:4321` is for local `pnpm dev` + this app on `:7071`.
- Do **not** add `*.azurestaticapps.net`.

A new site on `*.singletonsd.com` or `*.patoperpetua.com` does **not** need an ORIGINS PR in this repo. A site on any other parent domain does — change the Coolify `cms-auth` / API gateway allowlist (not Azure Bicep; that template is gone).

### Local

```bash
cp local.settings.json.example local.settings.json
# fill OAUTH_CLIENT_ID / OAUTH_CLIENT_SECRET (never commit)
pnpm install
pnpm test
pnpm start # http://localhost:7071/auth (Azure Functions Core Tools)
```

Point local Decap `base_url` at `http://localhost:7071` only when testing this process itself. Production `/admin` always uses `https://api.singletonsd.com` with `auth_endpoint: v1/cms-auth/auth`.

## What this service serves

| Path            | Role                                                         |
| --------------- | ------------------------------------------------------------ |
| `GET /auth`     | 302 to GitHub authorize (`redirect_uri` from `REDIRECT_URL`) |
| `GET /callback` | Exchange code; HTML `postMessage` handshake for Decap        |
| `GET /health`   | `{ "status": "ok", "service": "cms-oauth-kit" }`             |

On Coolify the gateway mounts those routes at `/v1/cms-auth/*`. GitHub OAuth Apps have **one** callback URL. All Decap sites share one OAuth App; production callback is `https://api.singletonsd.com/v1/cms-auth/callback`.

## Deploy

Production is **Oracle Coolify** (`https://api.singletonsd.com/v1/cms-auth`), not Azure Functions.

This repository no longer contains the GitHub Actions “Deploy Function” workflow, `infra/main.bicep`, or Azure zip-deploy scripts. Do not add them back.

Azure resources created by the old template (`ssd-cmsoauth-func-prod-ae`, plan, storage, and the Function’s Key Vault role assignment) are deleted separately by infra — not in this repo.

Secrets: Key Vault `ssd-global-kv-prod-ae` / `github-decap-oauth-client-secret`. Never git or GitHub Secrets.

## Engineering workflow

- GitHub Issues in **this** repo are the work units after bootstrap (`singleton-sd/marketing#6` is the extraction tracker).
- One independently mergeable issue per branch and PR. PR body: `Closes #N`.
- Branch: `<type>/<issue-number>-<kebab-title>`.
- Humans merge. Do not add product routes to “make a consumer easier”.

## Commands

```bash
pnpm install
pnpm test
pnpm format:check
pnpm build
```
