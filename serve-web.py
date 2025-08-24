#!/usr/bin/env python3
"""
Simple HTTP server to serve Flutter web app on localhost:8087
"""

import http.server
import socketserver
import os
import sys
from urllib.parse import urlparse, unquote

class FlutterWebHandler(http.server.SimpleHTTPRequestHandler):
    def end_headers(self):
        # Add headers to prevent caching of Flutter files
        self.send_header('Cache-Control', 'no-cache, no-store, must-revalidate')
        self.send_header('Pragma', 'no-cache')
        self.send_header('Expires', '0')
        super().end_headers()

    def guess_type(self, path):
        mime_type, _ = super().guess_type(path)
        # Fix MIME types for Flutter files
        if path.endswith('.js'):
            return 'application/javascript'
        elif path.endswith('.wasm'):
            return 'application/wasm'
        elif path.endswith('.json'):
            return 'application/json'
        return mime_type

def serve_flutter_web():
    # Change to the build/web directory
    web_dir = os.path.join(os.path.dirname(__file__), 'build', 'web')
    
    if not os.path.exists(web_dir):
        print(f"ERROR: Web build directory not found: {web_dir}")
        print("Please run 'flutter build web' first")
        sys.exit(1)
    
    os.chdir(web_dir)
    print(f"Serving from: {web_dir}")
    
    # Start server on port 8087
    PORT = 8087
    
    with socketserver.TCPServer(("", PORT), FlutterWebHandler) as httpd:
        print(f"🚀 Flutter web app serving at http://localhost:{PORT}")
        print("Press Ctrl+C to stop the server")
        try:
            httpd.serve_forever()
        except KeyboardInterrupt:
            print("\n👋 Server stopped")

if __name__ == "__main__":
    serve_flutter_web()