#!/usr/bin/env python3
"""Tinybird Local (2026-10-23 and later) refuses to create a datasource whose TTL is
shorter than its partition period. OpenStatus pairs toYYYYMM partitions with 1-30 day
TTLs, so those datasources get daily partitions instead. Storage layout only; queries
and the 45/90 day datasources are untouched.
shortcut: drop this once upstream packages/tinybird fixes its partition keys."""
import pathlib
import re
import sys

root = pathlib.Path(sys.argv[1] if len(sys.argv) > 1 else "datasources")
patched = 0
for f in sorted(root.glob("*.datasource")):
    s = f.read_text()
    ttl = re.search(r'^ENGINE_TTL ".*toIntervalDay\((\d+)\)"', s, re.M)
    if ttl and int(ttl.group(1)) <= 30 and re.search(r'^ENGINE_PARTITION_KEY "toYYYYMM\(', s, re.M):
        f.write_text(re.sub(r'^ENGINE_PARTITION_KEY "toYYYYMM\(', 'ENGINE_PARTITION_KEY "toYYYYMMDD(', s, flags=re.M))
        patched += 1
print(f"patch_ttl: {patched} datasources moved to daily partitions")
assert patched, "nothing patched: upstream changed, re-check patch_ttl.py"
