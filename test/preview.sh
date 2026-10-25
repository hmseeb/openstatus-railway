#!/bin/sh
# Contract test for images/cron/preview.py (the onboarding "first check" stand-in). Needs python3, curl.
set -eu
cd "$(dirname "$0")"
CRON_SECRET=s3cret RAILWAY_REPLICA_REGION=europe-west4-drams3a PREVIEW_PORT=18798 python3 ../images/cron/preview.py >/dev/null & PID=$!
trap 'kill $PID 2>/dev/null' EXIT
python3 -m http.server 18797 --bind 127.0.0.1 --directory . >/dev/null 2>&1 & WEB=$!
trap 'kill $PID $WEB 2>/dev/null' EXIT
sleep 1
post() { curl -s -X POST -H "Authorization: Basic $1" -H 'content-type: application/json' -d "$3" "http://[::1]:18798/ping/$2"; }
fail() { echo "FAIL: $1"; exit 1; }
U='{"url":"http://127.0.0.1:18797/auto.sh","method":"GET"}'

post wrong railway_europe-west4-drams3a "$U" | grep -q unauthorized || fail "wrong secret accepted"
post s3cret iad "$U" | grep -q '"state": "error"' || fail "fly region must be an error row"
post s3cret railway_us-west2 "$U" | grep -q '"state": "error"' || fail "other railway region must be an error row"
r=$(post s3cret railway_europe-west4-drams3a "$U")
printf "%s" "$r" | python3 -c 'import json,sys; d=json.load(sys.stdin); assert d["state"]=="success" and d["status"]==200 and d["latency"]>=0 and d["timing"]["transferDone"]>=d["timing"]["dnsStart"] and "os-admin auto" in d["body"], d' || fail "own region check: $r"
post s3cret railway_europe-west4-drams3a '{"url":"http://127.0.0.1:1/","method":"GET"}' | grep -q '"state": "error"' || fail "unreachable URL must be an error"
curl -s -4 -o /dev/null -w '%{http_code}' -X POST "http://127.0.0.1:18798/ping/x" | grep -q 401 || fail "IPv4 not served"
echo "preview.sh: all checks passed"
