#!/usr/bin/env python3
"""
mock_callback_server.py — Simple HTTP server to receive EDA callback responses.

Usage:
    python3 tests/mock_callback_server.py [--port 8888]

Then in another terminal, trigger an EDA event with this server as callback_url:
    curl -X POST http://<eda-activation-url> \
      -H "Content-Type: application/json" \
      -d '{
        "request_id": "test-1234",
        "callback_url": "http://<your-ip>:8888/callback",
        "action": "check",
        "resource": "web-server-01",
        "requestor": "test@example.com"
      }'

This server will display the response when EDA calls back.
"""

import json
import argparse
import uuid
from http.server import HTTPServer, BaseHTTPRequestHandler
from datetime import datetime


class CallbackHandler(BaseHTTPRequestHandler):
    def do_POST(self):
        content_length = int(self.headers.get("Content-Length", 0))
        body = self.rfile.read(content_length).decode("utf-8")

        print("\n" + "=" * 60)
        print(f"  EDA CALLBACK RECEIVED at {datetime.utcnow().isoformat()}Z")
        print(f"  Path: {self.path}")
        print(f"  Headers:")
        for key, val in self.headers.items():
            if key.lower().startswith("x-eda"):
                print(f"    {key}: {val}")
        print(f"  Body:")
        try:
            data = json.loads(body)
            print(json.dumps(data, indent=4))
            status = data.get("status", "unknown")
            request_id = data.get("request_id", "unknown")
            message = data.get("message", "")
            print(f"\n  → Request ID: {request_id}")
            print(f"  → Status:     {status.upper()}")
            print(f"  → Message:    {message}")
        except json.JSONDecodeError:
            print(f"  (raw): {body}")
        print("=" * 60)

        # ACK back to EDA playbook
        self.send_response(200)
        self.send_header("Content-Type", "application/json")
        self.end_headers()
        self.wfile.write(json.dumps({"ack": "received"}).encode())

    def log_message(self, format, *args):
        pass  # Suppress default access log


def main():
    parser = argparse.ArgumentParser(description="EDA callback mock server")
    parser.add_argument("--port", type=int, default=8888)
    parser.add_argument("--host", default="0.0.0.0")
    args = parser.parse_args()

    server = HTTPServer((args.host, args.port), CallbackHandler)
    print(f"Mock callback server listening on http://{args.host}:{args.port}")
    print("Waiting for EDA callbacks... (Ctrl+C to stop)\n")

    # Print a sample test command
    test_id = str(uuid.uuid4())[:8]
    print(f"Sample test command:")
    print(f'  curl -X POST http://<EDA-URL> \\')
    print(f'    -H "Content-Type: application/json" \\')
    print(f'    -d \'{{"request_id":"{test_id}","callback_url":"http://$(hostname -I | cut -d" " -f1):{args.port}/callback","action":"check","resource":"my-vm","requestor":"test"}}\'')
    print()

    try:
        server.serve_forever()
    except KeyboardInterrupt:
        print("\nShutting down mock callback server")


if __name__ == "__main__":
    main()
