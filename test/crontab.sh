#!/bin/sh
# The cron sidecar may only call workflows routes that exist in the pinned OpenStatus build
# (apps/workflows/src/cron/index.ts). Since 9620756 external-status lives in its own app
# (apps/external-status, no published image), so workflows answers /cron/external-status with 404.
set -eu
cd "$(dirname "$0")"
E=../images/cron/entrypoint.sh
fail() { echo "FAIL: $1"; exit 1; }
routes=$(grep -oE 'openstatus-cron /cron/[a-z/-]+' "$E" | sed 's#openstatus-cron /cron/##' | sort -u)
[ -n "$routes" ] || fail "no cron routes found in $E"
for r in $routes; do
  case "$r" in
    private-location-health) ;;
    *) fail "entrypoint schedules /cron/$r, which workflows 9620756 does not serve" ;;
  esac
done
grep -q 'external-status' "$E" && fail "stale external-status mention in $E"
echo "crontab.sh: all checks passed"
