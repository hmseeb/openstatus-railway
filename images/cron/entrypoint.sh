#!/bin/sh
# BusyBox crond does not pass the container environment to jobs, so the
# values are written into the job scripts at start.
set -eu

: "${CRON_SECRET:?CRON_SECRET is required}"
: "${WORKFLOWS_URL:?WORKFLOWS_URL is required (e.g. http://workflows.railway.internal:3000)}"
: "${DATABASE_URL:?DATABASE_URL is required (e.g. http://libsql.railway.internal:8080)}"

cat > /usr/local/bin/openstatus-cron <<SCRIPT
#!/bin/sh
path="\$1"
: > /tmp/cron.out
code=\$(curl -sS -o /tmp/cron.out -w '%{http_code}' -H "Authorization: ${CRON_SECRET}" "${WORKFLOWS_URL}\${path}" 2>/tmp/cron.err) || code="000"
echo "\$(date -u +%FT%TZ) \${path} -> \${code} \$(head -c 300 /tmp/cron.out) \$(head -c 200 /tmp/cron.err)"
SCRIPT

# Replaces the manual `os-admin setup` step: unlocks the first workspace and
# keeps its monitors attached to the bundled probes.
cat > /usr/local/bin/openstatus-auto <<SCRIPT
#!/bin/sh
export DATABASE_URL='${DATABASE_URL}' PROBE_KEYS='${PROBE_KEYS:-}'
os-admin auto 2>&1 | sed "s/^/\$(date -u +%FT%TZ) auto: /"
SCRIPT
chmod +x /usr/local/bin/openstatus-cron /usr/local/bin/openstatus-auto

cat > /etc/crontabs/root <<CRONTAB
* * * * * /usr/local/bin/openstatus-auto
*/5 * * * * /usr/local/bin/openstatus-cron /cron/private-location-health
*/10 * * * * /usr/local/bin/openstatus-cron /cron/external-status
CRONTAB

echo "openstatus cron sidecar: auto-setup every minute, private-location-health every 5 min, external-status every 10 min via ${WORKFLOWS_URL}"
/usr/local/bin/openstatus-auto || true
/usr/local/bin/openstatus-cron /cron/private-location-health || true
crond -l 8 -L /dev/stdout
# Onboarding's first check (the dashboard image points its checker URLs here).
# It is the foreground process, so a crash restarts the container and crond with it.
exec python3 -u /usr/local/bin/preview.py
