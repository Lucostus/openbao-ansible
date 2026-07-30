#!/usr/bin/env python3
import base64
import gzip
import json
import os
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from urllib.parse import parse_qs, urlparse


DATA_FILE = Path(os.environ.get("OPENSEARCH_MOCK_DATA", "/var/lib/opensearch-mock/events.ndjson"))
USERNAME = os.environ.get("OPENSEARCH_MOCK_USERNAME", "openbao-vector")
PASSWORD = os.environ.get("OPENSEARCH_MOCK_PASSWORD", "lab-password")
PORT = int(os.environ.get("OPENSEARCH_MOCK_PORT", "9200"))


def load_events():
    if not DATA_FILE.exists():
        return []

    events = []
    with DATA_FILE.open("r", encoding="utf-8") as event_file:
        for line in event_file:
            line = line.strip()
            if not line:
                continue
            events.append(json.loads(line))
    return events


def event_matches_query(event, query):
    if not query or ":" not in query:
        return True

    field, value = query.split(":", 1)
    current = event
    for part in field.split("."):
        if not isinstance(current, dict) or part not in current:
            return False
        current = current[part]
    return str(current) == value


class Handler(BaseHTTPRequestHandler):
    server_version = "OpenBaoLabOpenSearchMock/1.0"

    def log_message(self, fmt, *args):
        print("%s - %s" % (self.address_string(), fmt % args), flush=True)

    def authenticated(self):
        expected = "Basic " + base64.b64encode(f"{USERNAME}:{PASSWORD}".encode()).decode()
        if self.headers.get("Authorization", "") == expected:
            return True

        self.send_response(401)
        self.send_header("WWW-Authenticate", 'Basic realm="opensearch-mock"')
        self.end_headers()
        return False

    def send_json(self, status, payload):
        body = json.dumps(payload).encode("utf-8")
        self.send_response(status)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def do_GET(self):
        if not self.authenticated():
            return

        parsed = urlparse(self.path)
        if parsed.path in ("", "/"):
            self.send_json(200, {"cluster_name": "openbao-lab-opensearch-mock", "version": {"number": "2.0.0"}})
            return

        if parsed.path in ("/_count", "/_search"):
            query = parse_qs(parsed.query).get("q", [""])[0]
            events = [event for event in load_events() if event_matches_query(event.get("_source", {}), query)]
            if parsed.path == "/_count":
                self.send_json(200, {"count": len(events)})
            else:
                self.send_json(200, {"hits": {"total": {"value": len(events)}, "hits": events[-100:]}})
            return

        self.send_json(404, {"error": "not_found"})

    def do_POST(self):
        if not self.authenticated():
            return

        parsed = urlparse(self.path)
        if not parsed.path.endswith("/_bulk"):
            self.send_json(200, {"acknowledged": True})
            return

        body = self.rfile.read(int(self.headers.get("Content-Length", "0")))
        if self.headers.get("Content-Encoding", "").lower() == "gzip":
            body = gzip.decompress(body)

        lines = [line for line in body.decode("utf-8").splitlines() if line.strip()]
        indexed = []
        for index in range(0, len(lines), 2):
            action = json.loads(lines[index])
            source = json.loads(lines[index + 1]) if index + 1 < len(lines) else {}
            action_type, action_meta = next(iter(action.items()))
            indexed.append(
                {
                    "_action": action_type,
                    "_index": action_meta.get("_index", "openbao-lab"),
                    "_source": source,
                }
            )

        DATA_FILE.parent.mkdir(parents=True, exist_ok=True)
        with DATA_FILE.open("a", encoding="utf-8") as event_file:
            for event in indexed:
                event_file.write(json.dumps(event, separators=(",", ":")) + "\n")

        self.send_json(
            200,
            {
                "took": 1,
                "errors": False,
                "items": [
                    {event["_action"]: {"_index": event["_index"], "status": 201}}
                    for event in indexed
                ],
            },
        )


if __name__ == "__main__":
    ThreadingHTTPServer(("0.0.0.0", PORT), Handler).serve_forever()
