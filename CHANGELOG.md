# Changelog

Breaking changes are listed first in each entry.

## 2026-11-24: first release (upstream commit 3cde269)

- Open Agent Connector at upstream `main` commit `3cde26911964ebbd4b7cb6206535b8629aa2a7ce` (2026-11-16; upstream has no release tags or images).
- Two services: `web` (Next.js console + Caddy front door, public) and `api` (FastAPI, private, SQLite on a volume at `/app/data`).
- Generated admin token and encryption key; anonymous MCP and admin-token exposure are always off.
- Sized for 0.5 GB RAM per service: the provider catalogue is stored minified, one API worker, Node heap and Caddy threads sized from the container limits.
- Either service exits non-zero if its app process stops, so Railway restarts it.
