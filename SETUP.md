# SETUP — cms-oauth-kit

Shared Decap GitHub OAuth proxy at `https://auth.singletonsd.com`.

## Azure

| Item           | Value                                                                                                                        |
| -------------- | ---------------------------------------------------------------------------------------------------------------------------- |
| Subscription   | `01c0bb8b-3770-4765-979a-cb13ae7e3dd2`                                                                                       |
| Resource group | `rg-ssd-global`                                                                                                              |
| Function App   | `ssd-cmsoauth-func-prod-ae`                                                                                                  |
| Plan           | `ssd-cmsoauth-plan-prod-ae` **B1** (required for `auth.singletonsd.com` managed TLS; Y1 cannot present a custom-domain cert) |
| Storage        | `ssdcmsoauthstprod`                                                                                                          |
| Key Vault      | `ssd-global-kv-prod-ae` (existing)                                                                                           |
| Custom domain  | `auth.singletonsd.com`                                                                                                       |

## Human steps (once)

### 1. GitHub OAuth App

GitHub → Settings → Developer settings → OAuth Apps → New (or update the existing marketing Decap app):

- Name: `Singleton SD CMS OAuth`
- Homepage: `https://singletonsd.com`
- Authorization callback URL: `https://auth.singletonsd.com/callback`

Put the **client secret** in Key Vault:

```bash
az keyvault secret set \
  --vault-name ssd-global-kv-prod-ae \
  --name github-decap-oauth-client-secret \
  --value '<secret>'
```

Set GitHub repo Variable `DECAP_OAUTH_CLIENT_ID` to the client id (non-secret). Optionally also store the id in KV as `github-decap-oauth-client-id`.

Never put the secret in git or GitHub Secrets.

### 2. Entra OIDC for GitHub Actions

Create/federate an Entra app so `azure/login@v2` works for this repo:

- `repo:singleton-sd/cms-oauth-kit:ref:refs/heads/main`
- `repo:singleton-sd/cms-oauth-kit:pull_request` (optional)

Grant the identity rights to deploy into `rg-ssd-global` and read the KV secret (`Key Vault Secrets User` is also assigned to the Function’s managed identity by Bicep).

Repo Variables (IDs only):

- `AZURE_CLIENT_ID`
- `AZURE_TENANT_ID`
- `AZURE_SUBSCRIPTION_ID` = `01c0bb8b-3770-4765-979a-cb13ae7e3dd2`
- `DECAP_OAUTH_CLIENT_ID`

### 3. Deploy Function

```bash
az account set --subscription 01c0bb8b-3770-4765-979a-cb13ae7e3dd2
./scripts/deploy.sh --oauth-client-id '<client-id>'
```

Default SKU is **B1** so `auth.singletonsd.com` can use an App Service managed certificate. Do not switch to Y1 unless you are dropping the custom domain.

Smoke the default host:

```bash
curl -sS https://ssd-cmsoauth-func-prod-ae.azurewebsites.net/health
```

### 4. DNS + custom domain

```bash
./scripts/bind-custom-domain.sh --print-dns
```

Create in Route53 (`singletonsd.com`):

- `CNAME auth` → `ssd-cmsoauth-func-prod-ae.azurewebsites.net`
- `TXT asuid.auth` → the printed verification id

Then:

```bash
./scripts/bind-custom-domain.sh
curl -sS https://auth.singletonsd.com/health
```

`GET /auth` must 302 to GitHub with `redirect_uri=https://auth.singletonsd.com/callback`.

## Local

Requires [Azure Functions Core Tools](https://learn.microsoft.com/azure/azure-functions/functions-run-local) v4.

```bash
pnpm install
cp local.settings.json.example local.settings.json
pnpm test
pnpm start
```

## Consumers

See [AGENTS.md](./AGENTS.md). Cutover tickets:

- Company marketing: `singleton-sd/marketing#7`
- Platform Kit: `singleton-sd/poc-plattform-kit#283`
- InkAds: `singleton-sd/poc-inkads-marketing#30`
