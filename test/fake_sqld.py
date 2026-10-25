#!/usr/bin/env python3
"""sqld's legacy HTTP API (POST / {"statements":[...]}) over sqlite3, enough for os-admin. Usage: fake_sqld.py <db> <port>"""
import json, sqlite3, sys
from http.server import BaseHTTPRequestHandler, HTTPServer

db = sqlite3.connect(sys.argv[1], check_same_thread=False, isolation_level=None)


class H(BaseHTTPRequestHandler):
    def do_POST(self):
        out = []
        for s in json.loads(self.rfile.read(int(self.headers["Content-Length"])))["statements"]:
            try:
                cur = db.execute(s)
                out.append({"results": {"columns": [d[0] for d in cur.description or []], "rows": cur.fetchall()}})
            except sqlite3.Error as e:
                out.append({"error": {"message": str(e)}})
        body = json.dumps(out).encode()
        self.send_response(200)
        self.end_headers()
        self.wfile.write(body)

    def log_message(self, *a):
        pass


HTTPServer(("127.0.0.1", int(sys.argv[2])), H).serve_forever()
