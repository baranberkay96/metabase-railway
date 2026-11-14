# Deploy and Host Metabase with Railway

[![Deploy on Railway](https://railway.com/button.svg)](https://railway.com/deploy/metabase-65-bi-dashboards-postgres?referralCode=20H68q)

Metabase is an open-source business intelligence tool: connect your databases, ask questions with SQL or a no-code query builder, and share dashboards, alerts and embedded charts. This community template runs Metabase 65 (open-source edition) with PostgreSQL as its application database and creates the administrator for you on first start.

## About Hosting Metabase

Metabase is a Java application. It stores its own data (users, questions, dashboards, saved connection details) in an application database; the embedded H2 file database is meant for trials only, so this template uses PostgreSQL 18 from the start. Connection passwords for your data sources are encrypted with a generated key. On first start the launcher completes Metabase's setup with your administrator email and a generated password before the site goes live, so nobody else can claim the instance through the setup wizard. The Java heap is sized from the service's memory limit, so the same template runs on small and large plans.

## Common Use Cases

- Self-service dashboards on top of Postgres, MySQL, BigQuery, Snowflake and other databases.
- SQL editor and saved questions for analysts, with a no-code query builder for everyone else.
- Scheduled dashboard subscriptions and alerts for KPIs.
- Embedding charts in internal tools.
- A shared reporting layer for a startup or a single team.

## Dependencies for Metabase Hosting

- Metabase open-source edition (`metabase/metabase:v0.65.4.4`)
- PostgreSQL 18 (application database)
- The databases you want to analyse (added in Admin settings after login)

### Deployment Dependencies

- Metabase documentation: https://www.metabase.com/docs/latest/
- Running Metabase on Docker: https://www.metabase.com/docs/latest/installation-and-operation/running-metabase-on-docker
- Environment variables: https://www.metabase.com/docs/latest/configuring-metabase/environment-variables
- Application database: https://www.metabase.com/docs/latest/installation-and-operation/configuring-application-database
- Metabase releases: https://github.com/metabase/metabase/releases

### Implementation Details

| Service | Image | Role |
|---|---|---|
| `Metabase` | `metabase/metabase:v0.65.4.4` + Railway launcher | Web app, query engine, scheduler |
| `Postgres` | `postgres-ssl:18.6` | Application database (volume) |

**First login.** Wait until `Metabase` is healthy (the first start runs database migrations and takes 2–5 minutes), open its domain and sign in with `METABASE_ADMIN_EMAIL` (default `admin@example.com`) and `METABASE_ADMIN_PASSWORD` from the Metabase service's Variables tab. Set your own email before deploying, or change it later in Account settings. The password variable is applied on the first start only; afterwards change your password in Metabase. The Sample Database is included for a first look.

**If the password is rejected.** Metabase requires at least 6 characters including a digit and rejects common passwords. If the value you typed fails, the account is created with a random password and the deploy log explains how to reset it with `java -jar /app/metabase.jar reset-password {email}` from a Railway shell.

**Setup wizard instead.** Set `METABASE_AUTO_SETUP=false` before the first deploy to use Metabase's own wizard. Then the first visitor of the URL becomes administrator, so complete it right away.

**Encryption key.** `MB_ENCRYPTION_SECRET_KEY` encrypts the credentials of the databases you connect. Keep it; if it changes, saved connections must be re-entered.

**Memory and plans.** The launcher sizes the Java heap from the service's memory limit: below 2 GB it uses 40% of the limit with lean JVM settings, above that 60%, capped at 2 GB. Set `JAVA_OPTS=-Xmx3g` (for example) to choose it yourself. Measured on Railway: with a 1 GB limit (Trial) Metabase starts, completes setup and runs sample queries, using nearly the whole limit, so it suits light use only; on Hobby it idles at about 1.6 GB. Postgres idles at about 0.1–0.2 GB. The Free plan's 0.5 GB per service is not enough for Metabase. Hobby or Pro is recommended for teams and larger queries.

**Email.** Dashboard subscriptions and alerts need SMTP (Admin settings → Email). Railway allows outbound SMTP on the Pro plan only.

**Scaling.** Give Metabase more memory and CPU as dashboards and users grow. All state is in Postgres, so you can add replicas of the Metabase service.

**Pinning and upgrades.** The version is the `FROM` line in `services/metabase/Dockerfile` of the template repository. Back up Postgres, read the release notes, change the tag and redeploy; Metabase migrates its database on start. Downgrades are not supported.

### Why Deploy Metabase on Railway?

Railway runs Metabase and its PostgreSQL database together on a private network with HTTPS, a persistent volume and usage-based pricing. You get a working BI tool with an administrator already in place in one deploy, and can raise memory as your dashboards grow.
