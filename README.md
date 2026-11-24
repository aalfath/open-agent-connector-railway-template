[![Deploy on Railway](https://railway.com/button.svg)](https://railway.com/new/template/open-agent-connector?utm_medium=integration&utm_source=button&utm_campaign=open-agent-connector)

# Open Agent Connector on Railway

One-click Railway template for [Open Agent Connector](https://github.com/Anil-matcha/open-agent-connector), a self-hosted integration gateway for AI agents (an open alternative to Composio). You connect app accounts once, and your agents discover and run their actions over MCP (`POST /mcp`) or REST (`/v1/*`).

## What it deploys

| Service | Folder | What it does |
|---|---|---|
| `web` (public) | [`web/`](web/) | The Next.js console plus a small Caddy front door on the public domain. It routes `/api`, `/v1`, `/mcp`, `/health`, `/docs`, `/redoc` and `/openapi.json` to `api` over Railway's private network, as upstream's production compose file does. Health check: `/healthz`. |
| `api` (private) | [`server/`](server/) | The FastAPI backend: provider catalogue, connections, OAuth, runtime tokens, MCP gateway and run logs. SQLite database on a volume at `/app/data`. Health check: `/health`. |

**Version:** upstream publishes no release tags or images, so both services build from upstream commit [`3cde269`](https://github.com/Anil-matcha/open-agent-connector/commit/3cde26911964ebbd4b7cb6206535b8629aa2a7ce) (2026-11-16), pinned by full SHA in each Dockerfile. Base images are pinned by version and digest:

- `python:3.11.18-slim@sha256:139bddfb66e90ab739a881d4ce70cd49c22f57837463fba3cd59639091313df1` (api)
- `node:24.22.3-alpine@sha256:116b800c3754b440ee0aa3ed2f20f5bf3d99a554bfd9adeea09ea8017f6e85f5` (web build and runtime)
- `caddy:2.11.9-alpine@sha256:003a97808e781aa9f7e75cc2f43d34d461099031faf5e20faefb9f61126836f0` (Caddy binary)

Python and npm dependencies are locked to exact versions (`server/requirements.lock.txt`, `web/package-lock.json`).

## Variables

Nothing to fill in: every value is generated or derived.

| Service | Variable | Value | Notes |
|---|---|---|---|
| api | `CONNECTOR_ADMIN_TOKEN` | `${{secret(48)}}` | Admin bearer token: sign in to the console with it. |
| api | `CONNECTOR_ENCRYPTION_KEY` | `${{secret(64)}}` | Encrypts stored credentials. **Never change it**: stored connections can't be decrypted without it. |
| api | `CONNECTOR_PUBLIC_ORIGIN` | `https://${{web.RAILWAY_PUBLIC_DOMAIN}}` | Public URL, used for OAuth callbacks. |
| api | `PORT` | `8000` | |
| web | `OAC_SERVER_URL` | `http://${{api.RAILWAY_PRIVATE_DOMAIN}}:${{api.PORT}}` | Where the API is on the private network. |
| web | `PUBLIC_ORIGIN` | `https://${{RAILWAY_PUBLIC_DOMAIN}}` | Public URL baked into the console at start. |
| web | `PORT` | `8080` | |

The API refuses to start without a token and key of at least 32 characters. It always runs with `CONNECTOR_EXPOSE_LOCAL_TOKEN=false` and `CONNECTOR_ALLOW_ANONYMOUS_MCP=false`, so the console and MCP gateway are never open without a token.

## After deploy

1. Copy `CONNECTOR_ADMIN_TOKEN` from the `api` service's **Variables** tab and sign in at your `web` domain.
2. Add a connection (API key or OAuth) on the **Connections** page.
3. Create a scoped runtime token on the **Tokens** page and give it to your agent.

MCP client example:

```json
{
  "mcpServers": {
    "open-agent-connector": {
      "url": "https://YOUR-DOMAIN/mcp",
      "headers": { "Authorization": "Bearer YOUR-RUNTIME-TOKEN" }
    }
  }
}
```

For OAuth providers, register an OAuth app with that provider and use `https://YOUR-DOMAIN/api/oauth/<service>/callback` as the redirect URL.

## Resources

Both services run within Railway's Free plan limit of 0.5 GB RAM per service. Measured on Railway at 0.5 GB / 1 vCPU: `api` about 275 MB after boot and at most 379 MB under 18 concurrent catalogue and action requests (no OOM kill); `web` about 60 MB. The template uses one volume.

## Updates

Railway builds both services from this repo. When we move the pin to a newer upstream commit, the change is merged to `main` with a [CHANGELOG](CHANGELOG.md) entry, and Railway shows everyone who deployed the template an "update available" notice. You choose when to apply it. Data on the volume, and your generated token and key, are kept. The API creates any missing tables on start.

## Licence

Open Agent Connector is Apache-2.0 (© its authors). The wrapper files in this repo are under the same [licence](LICENSE).
