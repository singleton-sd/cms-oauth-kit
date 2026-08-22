# cms-oauth-kit

Shared GitHub OAuth proxy for Decap CMS admin on Singleton SD sites.

- **Public URL:** https://auth.singletonsd.com
- **Health:** https://auth.singletonsd.com/health
- **Azure:** `rg-ssd-global` / Function `ssd-cmsoauth-func-prod-ae`

```yaml
backend:
  name: github
  repo: singleton-sd/<your-repo>
  branch: main
  base_url: https://auth.singletonsd.com
  auth_endpoint: auth
```

Read [AGENTS.md](./AGENTS.md) (how to use) and [SETUP.md](./SETUP.md) (how to deploy).

Do not add product HTTP (contact forms, APIs) to this service.
