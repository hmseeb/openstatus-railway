#!/usr/bin/env python3
"""Stands in for OpenStatus's cloud checkers during onboarding ("Run first check").

The dashboard image is patched to POST /ping/<region> here instead of to
openstatus-checker.fly.dev, koyeb.app and railway-proxy (which a self-hosted
install cannot use, and which would receive this deploy's CRON_SECRET). One real
check runs from this container, answered only for the Railway region it is in;
every other region gets an error, which the onboarding table hides.
"""
import json
import os
import socket
import subprocess
import tempfile
import time
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

SECRET = os.environ.get("CRON_SECRET", "")
KNOWN = {"us-west2", "us-east4-eqdc4a", "europe-west4-drams3a", "asia-southeast1-eqsg3a"}
here = os.environ.get("RAILWAY_REPLICA_REGION", "")
# shortcut: a region OpenStatus does not list is reported as us-east4; add it here when OpenStatus does.
REGION = "railway_" + (here if here in KNOWN else "us-east4-eqdc4a")


def check(req):
    """One HTTP check with curl, shaped like the cloud checker's response."""
    with tempfile.TemporaryDirectory() as d:
        cmd = ["curl", "-sS", "-o", f"{d}/body", "-D", f"{d}/head", "--max-time", "9",
               "-X", req.get("method") or "GET", "-w", "%{json}"]
        for k, v in (req.get("headers") or {}).items():
            cmd += ["-H", f"{k}: {v}"]
        if req.get("body"):
            cmd += ["--data-binary", req["body"]]
        start = int(time.time() * 1000)
        out = subprocess.run(cmd + ["--", req["url"]], capture_output=True, text=True)
        w = json.loads(out.stdout or "{}")
        if out.returncode or not w.get("http_code"):
            return {"state": "error", "message": (out.stderr.strip() or "request failed")[:200]}
        at = lambda key: start + round(w.get(key, 0) * 1000)  # noqa: E731
        headers = {}
        for line in open(f"{d}/head", errors="replace").read().splitlines()[1:]:
            k, _, v = line.partition(":")
            if v:
                headers[k.strip()] = v.strip()
        return {
            "state": "success", "status": w["http_code"], "latency": round(w["time_total"] * 1000),
            "timestamp": start, "headers": headers,
            "body": open(f"{d}/body", errors="replace").read(1000),
            "timing": {
                "dnsStart": start, "dnsDone": at("time_namelookup"),
                "connectStart": at("time_namelookup"), "connectDone": at("time_connect"),
                "tlsHandshakeStart": at("time_connect"),
                "tlsHandshakeDone": at("time_appconnect") if w.get("time_appconnect") else at("time_connect"),
                "firstByteStart": at("time_pretransfer"), "firstByteDone": at("time_starttransfer"),
                "transferStart": at("time_starttransfer"), "transferDone": at("time_total"),
            },
        }


class Handler(BaseHTTPRequestHandler):
    def do_POST(self):
        if not SECRET or self.headers.get("Authorization") != f"Basic {SECRET}":
            return self.reply(401, {"state": "error", "message": "unauthorized"})
        region = self.path.rstrip("/").rsplit("/", 1)[-1]
        if not self.path.startswith("/ping/") or region != REGION:
            return self.reply(200, {"state": "error", "message": "no self-hosted probe in this region"})
        try:
            req = json.loads(self.rfile.read(int(self.headers.get("Content-Length") or 0)))
            self.reply(200, check(req))
        except (ValueError, KeyError) as e:
            self.reply(400, {"state": "error", "message": str(e)[:200]})

    def reply(self, code, obj):
        body = json.dumps(obj).encode()
        self.send_response(code)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def log_message(self, format, *args):  # noqa: A002
        pass


class DualStack(ThreadingHTTPServer):
    address_family = socket.AF_INET6

    def server_bind(self):
        # Railway's private network is IPv6; one socket for both stacks.
        self.socket.setsockopt(socket.IPPROTO_IPV6, socket.IPV6_V6ONLY, 0)
        super().server_bind()


if __name__ == "__main__":
    port = int(os.environ.get("PREVIEW_PORT", "8081"))
    print(f"preview checker on :{port}, answering for {REGION}", flush=True)
    DualStack(("::", port), Handler).serve_forever()
