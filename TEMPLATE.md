# Metabase BI Dashboards (Postgres) — composer spec

| Field | Value |
|---|---|
| Listing name | **Metabase BI Dashboards (Postgres)** (no version label: the open-source tag is `v0.65.4.4` and a new major ships every 6-7 weeks; renamed 2026-11-14, `idSeed` keeps the original name so service ids stay stable) |
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

1. **Heap.** Reads the cgroup memory limit. Below 2 GB: `-Xmx` = 40% of it plus `-XX:+UseSerialGC -XX:ReservedCodeCacheSize=128m -XX:MaxDirectMemorySize=64m` (Metabase's metaspace and code cache need ~0.4–0.5 GB outside the heap). From 2 GB: 60%, capped at 2 GB, with `-XX:+UseG1GC -XX:G1PeriodicGCInterval=60000 -XX:MinHeapFreeRatio=10 -XX:MaxHeapFreeRatio=30` so idle heap goes back to the OS (Railway's Hobby limit is 8 GB; measured idle: 4 GB heap → ~1.9 GB, 2 GB heap → ~2.3 GB, 2 GB heap + these flags → ~1.6 GB and falling). Minimum 256 MB. A `-Xmx` or `MaxRAMPercentage` in `JAVA_OPTS` wins. Below 900 MiB it logs a warning.
   - Measured 2026-11-14: with 60% (571 MiB heap) under the Trial limit (953 MiB) the container was OOM-killed during start-up in a loop; with the small-limit settings (381 MiB heap) it starts in ~55 s, completes setup and runs sample queries.
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

## Resource profile and cost (RAM $10/GB-mo, vCPU $20/mo, volume $0.15/GB-mo)

| Service | Idle RAM (measured) | Typical | Idle CPU |
|---|---|---|---|
| Metabase, Hobby limit (8 GB → 2 GB heap) | ~1.6 GB (after load, falling) | 1.5–2.5 GB | ~0.01 |
| Metabase, Trial limit (1 GB → 381 MiB heap) | ~0.95 GB (fills the limit) | — | ~0.01 |
| Postgres | 0.1–0.2 GB | 0.2–0.4 GB | <0.01 |

Idle on Hobby ≈ $17–18/month; a team with regular dashboards ≈ $20–35/month. Trial (1 GB/service) works for light use; Free (0.5 GB/service) cannot run Metabase.

## Verification checklist

- [x] `Metabase` SUCCESS, `/api/health` 200, log shows "Setup: administrator … created" ~1 s after "Initialization COMPLETE".
- [x] `/api/session/properties` shows `has-user-setup: true` and no setup token.
- [x] Login with the generated credentials works (superuser); a guessed password for `admin@example.com` gets 401.
- [x] Sample Database is listed; `SELECT COUNT(*) FROM ORDERS` returns 18,760; heavier joins run at the 1 GB limit.
- [x] Redeploy: the admin persists ("already has an administrator; nothing to do").

## Open questions

- Dashboard subscriptions need SMTP (Railway Pro).
