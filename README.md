# OpenStatus on Railway

[![Deploy on Railway](https://railway.com/button.svg)](https://railway.com/deploy/openstatus-auto-setup)

Images, tests and the build sheet for the OpenStatus Railway template. The deployer guide below is the same text as the marketplace listing.


OpenStatus is an open-source status page and uptime monitoring platform. It runs HTTP, TCP and DNS checks from probes you control, records response times and uptime, alerts your team over email, Slack, Discord, PagerDuty and more, and publishes status pages with incidents, maintenance windows and subscriber updates.

## About Hosting OpenStatus

This template runs the whole OpenStatus stack inside one Railway project, with no outside accounts: the dashboard, the public status page, the API server, the workflows worker, a libSQL database, a Tinybird Local analytics engine, the ingest server, four monitoring probes, and two one-shot jobs that load the database and analytics schemas.

There is nothing to run after the deploy. A small cron service unlocks every feature on your workspace, registers the four probes as private locations, and attaches each new monitor to all of them, within a minute of you creating it. You never need the Railway CLI or a shell.

Every image is pinned to one tested OpenStatus build, so a redeploy never pulls a surprise upgrade.

## Common Use Cases

- A public status page for your product, with incidents, maintenance notices and email subscribers
- Uptime and latency checks on your own APIs and websites from up to four regions, alerting on Slack, Discord, PagerDuty or email
- Monitoring services on your Railway private network that public monitoring vendors cannot reach
- Keeping monitoring data on infrastructure you control

## Dependencies for OpenStatus Hosting

- libSQL server for application data, on a Railway volume
- Tinybird Local (ClickHouse) for check results, on a Railway volume
- The OpenStatus container images from GitHub Container Registry

### Deployment Dependencies

- [OpenStatus repository](https://github.com/openstatusHQ/openstatus)
- [OpenStatus self-hosting guide](https://docs.openstatus.dev/guides/self-hosting-openstatus/)
- [Tinybird Local](https://www.tinybird.co/docs/forward/install-tinybird/local)
- [Template source, images and tests](https://github.com/hmseeb/openstatus-railway)

### Implementation Details

**First login (about 5 minutes after deploy)**

1. Wait until `db-migrate` and `tinybird-deploy` show Completed and the other services are green. Tinybird Local takes the longest.
2. Open the `dashboard` service's URL and go to `/login`. Enter your email and request a magic link.
3. The link is not emailed. Open the `dashboard` service's **Deploy Logs**, find the line starting with `>>> Magic Link:`, and open that URL.
4. Create your workspace. Within a minute it is unlocked and the probes `railway-us-east`, `railway-us-west`, `railway-eu-west` and `railway-asia` appear under Settings, Private Locations.

Only people who can read your Railway logs can log in, which is what keeps the instance yours. If you add a real Resend key (below), anyone who knows the URL can request a link by email, but only the first workspace (yours) gets probes and features, so their monitors never run.


**Monitors**

The onboarding screen's first check runs once from inside your project and shows a single Railway row with real status and latency (the 27-region wording is upstream's copy; self-hosted checks only run from your own probes). Your probes then pick the monitor up within about 10 minutes.

Create further monitors as usual. Any monitor with no private location selected is attached to all four probes automatically. If you pick specific probes, your choice is kept. OpenStatus's own cloud regions do not exist self-hosted, so only the private locations run checks. The shortest check interval is 1 minute.

**Spread the probes across regions**

All four probes start in your project's default region. Railway templates cannot set a region per service yet, so move three of them once in each service's Settings, Deploy, Regions: `probe-us-west` to US West, `probe-eu-west` to EU West, `probe-asia` to Southeast Asia. The probe names are labels: `railway-us-east` stays wherever your project's default region is. Delete any probe you do not want; nothing else depends on it.

**Status pages**

On Railway a status page is served on a hostname, not a path. After creating a page, map the `status-page` service's domain (or a custom domain you add to that service) to it from the `cron` service's shell:

```
os-admin page-domain <page-slug> <hostname>
```

The dashboard's custom-domain form talks to Vercel and does not work self-hosted. Icon uploads need Vercel Blob; use `os-admin page-icon <page-slug> <image-url>` instead.

**Optional settings**

Add these on the `dashboard` service at any time:

- `RESEND_API_KEY`: a real [Resend](https://resend.com) key sends login links, alerts and subscriber emails. The other services read it from the dashboard.
- `AUTH_GITHUB_ID`, `AUTH_GITHUB_SECRET` or `AUTH_GOOGLE_ID`, `AUTH_GOOGLE_SECRET`: social login. Callback URL `https://<dashboard-domain>/api/auth/callback/github` (or `/google`).
- `AUTH_OIDC_ISSUER`, `AUTH_OIDC_ID`, `AUTH_OIDC_SECRET`: any OIDC provider.

After adding a custom domain to the dashboard, update its `AUTH_URL` and `NEXT_PUBLIC_URL`.

**Sizing**

Tinybird Local uses about 1 GB of memory at rest; the whole stack idles around 2 GB. Hobby plan or higher.

**Troubleshooting**

- Login page loads but no magic link line appears: request the link again after `db-migrate` shows Completed.
- A monitor shows no data: check that it has at least one `railway-*` private location, and that the probe services are running.
- Never give `libsql` or `tinybird-local` a public domain. They have no authentication beyond the private network.

**Toolbox**

The `cron` service ships `os-admin`: `workspaces`, `users`, `probes`, `pages`, `setup <workspace-id>` (unlock another workspace on purpose), `page-domain`, `page-icon`, `sql "<statement>"`.

## Why Deploy OpenStatus on Railway?

Railway is a singular platform to deploy your infrastructure stack. Railway will host your infrastructure so you don't have to deal with configuration, while allowing you to vertically and horizontally scale it.

By deploying OpenStatus on Railway, you are one step closer to supporting a complete full-stack application with minimal burden. Host your servers, databases, AI agents, and more on Railway.
## For maintainers

- `template.json` is the build sheet; every non-obvious choice carries a `$note`. `upsert.py` writes it to Railway directly (no `templateGenerate`).
- `images/` builds three images to GHCR on push (`.github/workflows/build.yml`). Bump the `-rN` tag in both the workflow and `template.json`.
- `test/auto.sh` checks the `os-admin auto` contract and `test/preview.sh` the onboarding preview checker (python3, sqlite3, curl, jq).
- Upgrading OpenStatus: pick a commit whose short sha is tagged on all six `ghcr.io/openstatushq/openstatus-*` images, update `template.json` and `OPENSTATUS_REF` in `images/tinybird-deploy/Dockerfile`, then redeploy `db-migrate` and `tinybird-deploy` first.

OpenStatus is AGPL-3.0; this repository holds deployment configuration only (MIT). See NOTICE.
