# Metabase 65 BI Dashboards (Postgres) — composer spec

| Field | Value |
|---|---|
| Listing name | **Metabase 65 BI Dashboards (Postgres)** (`65` = Metabase's own release number; tag `v0.65.4.4`) |
| Description | Open-source BI: SQL and no-code questions, dashboards, alerts. Postgres DB. (75 chars) |
| Category | Analytics |
| Tags | metabase, bi, business-intelligence, dashboards, analytics, sql, data-visualization |
| Repo | `baranberkay96/metabase-railway` (this folder is the repo root) |
| Upstream checked | Metabase `v0.65.4.4` (hotfix of 65.4, released 2026-11-13; `v0.65.4` is the GitHub release), `bin/docker/Dockerfile`, `bin/docker/run_metabase.sh`, `src/metabase/setup_rest/api.clj`, `src/metabase/util/password.clj`. Pinned 2026-11-14. |

## Market

| Code | Active / recent deploys | Notes |
|---|---|---|
| `metabase` | 1,127 / 81 | Floating `metabase/metabase`, Railway Postgres with a public TCP proxy, `MB_PASSWORD_COMPLEXITY=strong`. No encryption key, no heap sizing; first visitor runs the setup wizard. Health 80. |
| `metabase-open-source-ai-analytics` | 35 / 8 | `metabase:latest`, Postgres 17 with a public TCP proxy. |
| `metabase-updated-jul-26` | 8 / 11 | Repo build from an unlicensed repo; no site URL, no encryption key. |

## Services

| Service | Source | Start | Healthcheck | Volume | Restart |
|---|---|---|---|---|---|
| `Metabase` | repo `/services/metabase` (`FROM metabase/metabase:v0.65.4.4@sha256:06b66bf5…`) | ENTRYPOINT `/app/railway/start.sh` | `/api/health`, 900 s | — (state in Postgres) | ALWAYS |
| `Postgres` | `ghcr.io/railwayapp-templates/postgres-ssl:18.6@sha256:4fc833b4…` | image | — | `/var/lib/postgresql/data` | ALWAYS |

## Launcher (`services/metabase/railway/start.sh`)

1. **Heap.** Reads the cgroup memory limit and passes `-Xmx` = 60% of it, clamped to 256 MB–4 GB (Railway's Hobby/Pro limits are far above what Metabase needs, so the cap keeps idle RAM, and the bill, reasonable). A `-Xmx` or `MaxRAMPercentage` in `JAVA_OPTS` wins. Below 900 MiB it logs a warning.
2. **Encryption key guard.** `MB_ENCRYPTION_SECRET_KEY` shorter than 16 characters (Metabase would refuse it) is replaced by its SHA-256, with a warning (STANDARD rule 29).
3. Starts the image's `/app/run_metabase.sh` (unchanged: drops to the `metabase` user, `MB_JETTY_HOST=0.0.0.0`).
4. **Automatic setup** (`METABASE_AUTO_SETUP=true`): polls `127.0.0.1:3000/api/health` every second; when Metabase answers and `has-user-setup` is false, it reads the setup token from `/api/session/properties` and posts `/api/setup` with `METABASE_ADMIN_EMAIL` / `METABASE_ADMIN_PASSWORD` and `METABASE_SITE_NAME`. This happens within about a second of Metabase becoming healthy, i.e. before or together with Railway's first passing healthcheck, so the public URL never serves an open setup wizard in practice.
   - Invalid email → `admin@example.com` with a warning.
   - Password rejected by Metabase (complexity or common-password list) → the admin is created with a random password nobody knows (login locked) and the log prints the `reset-password` CLI recovery steps. The deploy never fails.
   - Already set up → nothing to do. The password variable is applied on first setup only.
5. Forwards SIGTERM to Metabase and exits with its status.

Helper variables use the `METABASE_` prefix, not `MB_`: Metabase maps every `MB_*` variable to a setting, and `MB_ADMIN_EMAIL` would turn the `admin-email` setting read-only and break the setup call (same lesson as STANDARD 8.18).

## Variables (Metabase)

| Variable | Default | Notes |
|---|---|---|
| `METABASE_ADMIN_EMAIL` | `admin@example.com` | Admin login. |
| `METABASE_ADMIN_PASSWORD` | `secret(20, alnum)` + `secret(4, digits)` | Always contains a digit, so Metabase's default ("normal") complexity accepts it. |
| `METABASE_AUTO_SETUP` | `true` | `false` = Metabase's own wizard. |
| `METABASE_SITE_NAME` | `Metabase` | |
| `MB_DB_TYPE` / `MB_DB_HOST` / `MB_DB_PORT` / `MB_DB_DBNAME` / `MB_DB_USER` / `MB_DB_PASS` | `postgres`, references to `Postgres` | Private network. |
| `MB_ENCRYPTION_SECRET_KEY` | `secret(48, alnum)` | Never change. |
| `MB_SITE_URL` | `https://${{RAILWAY_PUBLIC_DOMAIN}}` | |
| `MB_ANON_TRACKING_ENABLED` | `false` | |
| `MB_CHECK_FOR_UPDATES` | `true` | |
| `JAVA_TIMEZONE` | `UTC` | |
| `PORT` / `MB_JETTY_PORT` | `3000` | |

## Improvements over market templates

| Area | Market | This template |
|---|---|---|
| Version | Floating `metabase/metabase` / `:latest` | `v0.65.4.4` by digest |
| First run | Setup wizard open to the first visitor | Admin created at boot with a generated password |
| Secrets | No `MB_ENCRYPTION_SECRET_KEY` (connection passwords stored in plain text in the app DB) | Generated encryption key |
| Memory | JVM default (25% of a large plan limit) | Heap from the service limit, capped at 4 GB |
| Postgres | Public TCP proxy on the app DB | Private network only |
| Telemetry | On | Anonymous tracking off |

## Resource profile and cost

Filled from the Railway measurement (see README): Metabase ~0.75 GB idle, Postgres ~0.1 GB. Idle ≈ $9–10/month; a team with a few dashboards ≈ $15–30/month. Trial (1 GB/service) works for light use; Free (0.5 GB/service) cannot run Metabase.

## Verification checklist

- [ ] `Metabase` SUCCESS, `/api/health` 200, log shows "Setup: administrator … created".
- [ ] `/api/session/properties` shows `has-user-setup: true` and no setup token.
- [ ] Login with the generated credentials works; a guessed password for `admin@example.com` fails.
- [ ] Sample Database is listed and a table can be queried.
- [ ] Redeploy: dashboards and users persist.

## Open questions

- Dashboard subscriptions need SMTP (Railway Pro).
