# SETUP — cms-oauth-kit

Shared Decap GitHub OAuth proxy. Production is Oracle Coolify behind the API gateway at `https://api.singletonsd.com/v1/cms-auth`.

## Production

| Item          | Value                                                                       |
| ------------- | --------------------------------------------------------------------------- |
| Public origin | `https://api.singletonsd.com/v1/cms-auth`                                   |
| Auth          | `GET https://api.singletonsd.com/v1/cms-auth/auth`                          |
| Callback      | `GET https://api.singletonsd.com/v1/cms-auth/callback`                      |
| Host          | Oracle Coolify (`cms-auth` upstream; gateway in `singleton-sd/api-gateway`) |
| Key Vault     | `ssd-global-kv-prod-ae` (ADR-007: Azure is Key Vault only)                  |

This repository does **not** deploy the Azure Function App. The old Function (`ssd-cmsoauth-func-prod-ae` / `auth.singletonsd.com`), App Service plan, storage account, and Function Key Vault role assignment are removed from git here; live Azure deletion is a separate infra change ([SSD-1124](https://app.clickup.com/t/14ymjnwbrct)).

## Human steps (once)

### 1. GitHub OAuth App

GitHub → Settings → Developer settings → OAuth Apps → New (or update the existing marketing Decap app):

- Name: `Singleton SD CMS OAuth`
- Homepage: `https://singletonsd.com`
- Authorization callback URL: `https://api.singletonsd.com/v1/cms-auth/callback`

Put the **client secret** in Key Vault:

```bash
az keyvault secret set \
  --vault-name ssd-global-kv-prod-ae \
  --name github-decap-oauth-client-secret \
  --value '<secret>'
```

Never put the secret in git or GitHub Secrets.

### 2. Coolify

CMS auth is already the Coolify `cms-auth` service in front of APISIX. App images and gateway routes live in their own repos (`singleton-sd/decap-oauth`, `singleton-sd/api-gateway`). Do not add Azure Function zip-deploy or Bicep back into this kit.

Smoke:

```bash
curl -sS https://api.singletonsd.com/v1/cms-auth/auth -o /dev/null -w '%{http_code} %{redirect_url}\n'
```

`GET /v1/cms-auth/auth` must 302 to GitHub with `redirect_uri=https://api.singletonsd.com/v1/cms-auth/callback`.

## Local

Requires [Azure Functions Core Tools](https://learn.microsoft.com/azure/azure-functions/functions-run-local) v4. There is no Dockerfile in this repository; `pnpm start` still uses the Functions host.

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
