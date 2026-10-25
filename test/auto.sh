#!/bin/sh
# Contract test for `os-admin auto` (the cron sidecar's every-minute job). Needs python3, curl, jq.
set -eu
cd "$(dirname "$0")"
T=$(mktemp -d); trap 'kill $PID 2>/dev/null; rm -rf "$T"' EXIT
sqlite3 "$T/db" "CREATE TABLE workspace (id INTEGER PRIMARY KEY, slug TEXT, name TEXT, plan TEXT, paid_until INT, ends_at INT, limits TEXT NOT NULL DEFAULT '{}');
CREATE TABLE monitor (id INTEGER PRIMARY KEY, workspace_id INT);
CREATE TABLE private_location (id INTEGER PRIMARY KEY, name TEXT, token TEXT, status TEXT, workspace_id INT, last_seen_at INT);
CREATE TABLE private_location_to_monitor (private_location_id INT, monitor_id INT);"
python3 fake_sqld.py "$T/db" 18799 & PID=$!; sleep 1
export DATABASE_URL=http://127.0.0.1:18799 PROBE_KEYS="a=k1,b=k2,c=k3,d=k4"
A=../images/cron/os-admin  # must be executable: it re-invokes itself via $0
q() { sqlite3 "$T/db" "$1"; }
fail() { echo "FAIL: $1"; exit 1; }

$A auto; [ "$(q 'SELECT count(*) FROM private_location')" = 0 ] || fail "no workspace yet must be a no-op"

q "INSERT INTO workspace (id, slug) VALUES (1,'mine'),(2,'stranger'); INSERT INTO monitor VALUES (10,1),(11,1),(20,2);"
$A auto >/dev/null
[ "$(q "SELECT plan FROM workspace WHERE id=1")" = team ] || fail "first workspace not on team plan"
q "SELECT json_extract(limits,'\$.\"private-locations\"') FROM workspace WHERE id=1" | grep -qx 1 || fail "private-locations not unlocked"
q "SELECT limits FROM workspace WHERE id=1" | grep -q '"30s"' && fail "30s periodicity must stay off"
[ "$(q "SELECT limits FROM workspace WHERE id=2")" = '{}' ] || fail "second workspace must keep empty limits"
[ "$(q "SELECT count(*) FROM private_location WHERE workspace_id=1")" = 4 ] || fail "4 probes expected on workspace 1"
[ "$(q "SELECT count(*) FROM private_location_to_monitor WHERE monitor_id IN (10,11)")" = 8 ] || fail "both monitors on all 4 probes"
[ "$(q "SELECT count(*) FROM private_location_to_monitor WHERE monitor_id=20")" = 0 ] || fail "stranger monitor must not run"

# deployer narrows monitor 10 to one probe and edits limits; a new monitor appears
q "DELETE FROM private_location_to_monitor WHERE monitor_id=10 AND private_location_id>1; UPDATE workspace SET limits='{\"monitors\":3}' WHERE id=1; INSERT INTO monitor VALUES (12,1);"
out=$($A auto)
[ -z "$out" ] || fail "steady-state run should be silent, got: $out"
[ "$(q "SELECT count(*) FROM private_location_to_monitor WHERE monitor_id=10")" = 1 ] || fail "deployer's probe choice overwritten"
[ "$(q "SELECT count(*) FROM private_location_to_monitor WHERE monitor_id=12")" = 4 ] || fail "new monitor not attached"
[ "$(q "SELECT limits FROM workspace WHERE id=1")" = '{"monitors":3}' ] || fail "edited limits overwritten"
[ "$(q 'SELECT count(*) FROM private_location')" = 4 ] || fail "probes duplicated"
echo "auto.sh: all checks passed"
