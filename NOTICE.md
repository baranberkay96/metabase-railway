# NOTICE — Metabase template

This is a community template. It is not affiliated with or endorsed by Metabase, Inc. "Metabase" is a trademark of Metabase, Inc.

## Upstream sources checked (2026-11-14)

| Source | Version / path | License | Use |
|---|---|---|---|
| metabase/metabase | `v0.65.4.4`: `bin/docker/Dockerfile`, `bin/docker/run_metabase.sh` | AGPL-3.0 (OSS edition) | Image layout, entrypoint, `JAVA_OPTS` handling, default Jetty host |
| metabase/metabase | `v0.65.4.4`: `src/metabase/setup_rest/api.clj`, `src/metabase/util/password.clj` | AGPL-3.0 | First-run setup endpoint and request body, password complexity rules |
| Metabase docs | Running Metabase on Docker, environment variables, application database, encryption of database details | — | `MB_DB_*`, `MB_ENCRYPTION_SECRET_KEY`, `MB_SITE_URL`, heap guidance |

## Market templates reviewed

| Code | Use |
|---|---|
| `metabase` (1.1k active) | Reviewed service layout (Metabase image + Railway Postgres, `/api/health`). Nothing copied. |
| `metabase-open-source-ai-analytics` | Reviewed; `metabase:latest`, Postgres with a public TCP proxy. Nothing copied. |
| `metabase-updated-jul-26` (repo `shruti060701/metabase-railway`, no license) | Read only; nothing copied. |

## Railway base services

`Postgres` follows `templates/_railway-base/postgres.json` (image pinned to `ghcr.io/railwayapp-templates/postgres-ssl:18.6` by digest).

## Runtime images

- `metabase/metabase:v0.65.4.4` — Metabase open-source edition, AGPL-3.0. The image is used unmodified; the launcher in `services/metabase/railway/` only wraps its run script. Source: https://github.com/metabase/metabase
- `ghcr.io/railwayapp-templates/postgres-ssl:18.6` (PostgreSQL License)

All files in this repository (launcher, Dockerfile, documentation) were written for this template.
