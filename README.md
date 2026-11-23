# cms-oauth-kit

Shared GitHub OAuth proxy for Decap CMS admin on Singleton SD sites.

Production CMS auth runs on Oracle Coolify behind the API gateway:

- **Public URL:** https://api.singletonsd.com/v1/cms-auth
- **Auth:** https://api.singletonsd.com/v1/cms-auth/auth
- **Callback:** https://api.singletonsd.com/v1/cms-auth/callback

The Azure Function App (`ssd-cmsoauth-func-prod-ae`, host `auth.singletonsd.com`) is no longer deployed from this repository. Azure resource deletion is handled separately by infra ([SSD-1124](https://app.clickup.com/t/14ymjnwbrct)). Per ADR-007, Azure is used only for Key Vault.

```yaml
backend:
  name: github
  repo: singleton-sd/<your-repo>
  branch: main
  base_url: https://api.singletonsd.com
  auth_endpoint: v1/cms-auth/auth
```

Read [AGENTS.md](./AGENTS.md) (how to use) and [SETUP.md](./SETUP.md) (how to deploy).

Do not add product HTTP (contact forms, APIs) to this service.
