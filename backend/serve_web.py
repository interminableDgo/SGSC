"""Loopback-only preview server; recovery tokens are never written to access logs."""
from functools import partial
from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from urllib.parse import urlsplit


class Handler(SimpleHTTPRequestHandler):
    def end_headers(self):
        self.send_header('Cache-Control','no-store')
        self.send_header('Referrer-Policy','no-referrer')
        self.send_header('X-Content-Type-Options','nosniff')
        super().end_headers()

    def log_request(self, code='-', size='-'):
        self.log_message('%s %s %s',self.command,urlsplit(self.path).path,code)


if __name__=='__main__':
    root=Path(__file__).resolve().parents[1]/'sgsc_ejecutiva/build/web'
    if not (root/'index.html').exists():
        raise SystemExit('Primero compila Flutter web.')
    ThreadingHTTPServer(('127.0.0.1',5173),partial(Handler,directory=str(root))).serve_forever()
