# AGENTS.md — cms-oauth-kit

Shared GitHub OAuth proxy for **Decap CMS** (`/admin`) on Singleton SD sites.

GitHub: `singleton-sd/cms-oauth-kit`
Public origin: `https://auth.singletonsd.com`
Azure: subscription `01c0bb8b-3770-4765-979a-cb13ae7e3dd2`, resource group `rg-ssd-global`, Function `ssd-cmsoauth-func-prod-ae`

This repository **is** the OAuth service. Do not add Contact forms, marketing APIs, or product HTTP here.

## Consumer contract

In the site’s Decap `config.yml`:

```yaml
backend:
  name: github
  repo: singleton-sd/<consumer-repo>
  branch: main
  base_url: https://auth.singletonsd.com
  auth_endpoint: auth
```

That is the whole client change. Editors need **write** access to `backend.repo`. The Function only brokers GitHub OAuth; the token is the editor’s.

Open `/admin` on a hostname allowed by `ORIGINS`. Do not open it on a raw `*.azurestaticapps.net` default host.

### ORIGINS (locked)

```text
*.singletonsd.com,*.patoperpetua.com,singletonsd.com,patoperpetua.com,localhost:4321
```

- `*.example.com` does **not** match the apex `example.com` — both are listed.
- Nested subdomains match (`plattform-kit.poc.singletonsd.com`, `www.patoperpetua.com`).
- `localhost:4321` is for local `pnpm dev` + this Function on `:7071`.
- Do **not** add `*.azurestaticapps.net`.

A new site on `*.singletonsd.com` or `*.patoperpetua.com` does **not** need an ORIGINS PR. A site on any other parent domain does — change Bicep `origins` in this repo.

### Local

```bash
cp local.settings.json.example local.settings.json
# fill OAUTH_CLIENT_ID / OAUTH_CLIENT_SECRET (never commit)
pnpm install
pnpm test
pnpm start   # http://localhost:7071/auth  (Azure Functions Core Tools)
```

Point local Decap `base_url` at `http://localhost:7071` only when testing the proxy itself. Production `/admin` always uses `https://auth.singletonsd.com`.

## What this Function serves

| Path            | Role                                                                           |
| --------------- | ------------------------------------------------------------------------------ |
| `GET /auth`     | 302 to GitHub authorize (`redirect_uri=https://auth.singletonsd.com/callback`) |
| `GET /callback` | Exchange code; HTML `postMessage` handshake for Decap                          |
| `GET /health`   | `{ "status": "ok", "service": "cms-oauth-kit" }`                               |

GitHub OAuth Apps have **one** callback URL. All Decap sites share this Function and one OAuth App.

## Deploy (bash only)

No PowerShell in this repo.

```bash
./scripts/deploy.sh --oauth-client-id '<github-oauth-app-client-id>'
./scripts/bind-custom-domain.sh --print-dns   # CNAME + TXT to create in Route53
./scripts/bind-custom-domain.sh               # after DNS exists
```

Secrets: Key Vault `ssd-global-kv-prod-ae` / `github-decap-oauth-client-secret`. Never git or GitHub Secrets.

CI on `main` deploys via OIDC when Variables `AZURE_CLIENT_ID`, `AZURE_TENANT_ID`, `AZURE_SUBSCRIPTION_ID`, and `DECAP_OAUTH_CLIENT_ID` are set; otherwise the deploy job skips.

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
