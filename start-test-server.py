#!/usr/bin/env python3
"""
ShowTrackAI Geolocation Test Server
A simple HTTP server for testing geolocation features locally
"""

import http.server
import socketserver
import ssl
import os
import json
import webbrowser
from datetime import datetime
from urllib.parse import urlparse, parse_qs

PORT = 8888
HOST = "localhost"

class GeolocationTestHandler(http.server.SimpleHTTPRequestHandler):
    """Custom handler for geolocation testing with CORS support"""
    
    def do_GET(self):
        """Handle GET requests"""
        parsed_path = urlparse(self.path)
        
        # Serve the main test interface
        if parsed_path.path == '/' or parsed_path.path == '/test':
            self.serve_test_interface()
        # Mock API endpoints for testing
        elif parsed_path.path == '/api/weather':
            self.serve_mock_weather()
        elif parsed_path.path == '/api/location':
            self.serve_mock_location()
        elif parsed_path.path == '/api/journal':
            self.serve_journal_status()
        else:
            # Serve static files
            super().do_GET()
    
    def do_POST(self):
        """Handle POST requests for journal entries"""
        if self.path == '/api/journal/create':
            content_length = int(self.headers['Content-Length'])
            post_data = self.rfile.read(content_length)
            
            try:
                journal_data = json.loads(post_data.decode('utf-8'))
                response = {
                    'success': True,
                    'id': f'journal_{int(datetime.now().timestamp())}',
                    'message': 'Journal entry created successfully',
                    'data': journal_data
                }
                self.send_json_response(response)
            except json.JSONDecodeError:
                self.send_error_response('Invalid JSON data')
    
    def serve_test_interface(self):
        """Serve the main test interface"""
        try:
            with open('geolocation-test-server.html', 'r') as f:
                content = f.read()
            
            self.send_response(200)
            self.send_header('Content-Type', 'text/html')
            self.send_header('Content-Length', len(content))
            self.end_headers()
            self.wfile.write(content.encode())
        except FileNotFoundError:
            self.send_error(404, 'Test interface not found')
    
    def serve_mock_weather(self):
        """Serve mock weather data"""
        weather_data = {
            'temperature': 72.5,
            'temperatureCelsius': 22.5,
            'condition': 'Clear',
            'description': 'Clear sky with light breeze',
            'humidity': 65,
            'windSpeed': 8.5,
            'windDirection': 'NW',
            'pressure': 1013,
            'visibility': 10,
            'feelsLike': 70.2,
            'uvIndex': 5,
            'sunrise': '06:45',
            'sunset': '19:30',
            'timestamp': datetime.now().isoformat()
        }
        self.send_json_response(weather_data)
    
    def serve_mock_location(self):
        """Serve mock location verification"""
        location_data = {
            'verified': True,
            'address': '1234 Farm Road, Ames, IA 50011',
            'locationType': 'Agricultural Facility',
            'nearbyLandmarks': [
                'Iowa State University Farm',
                'Agricultural Research Station',
                'FFA Training Center'
            ],
            'timestamp': datetime.now().isoformat()
        }
        self.send_json_response(location_data)
    
    def serve_journal_status(self):
        """Serve journal system status"""
        status = {
            'system': 'operational',
            'database': 'connected',
            'n8n': 'ready',
            'supabase': 'connected',
            'entriesCount': 42,
            'lastEntry': datetime.now().isoformat()
        }
        self.send_json_response(status)
    
    def send_json_response(self, data):
        """Send JSON response with proper headers"""
        response = json.dumps(data, indent=2)
        self.send_response(200)
        self.send_header('Content-Type', 'application/json')
        self.send_header('Access-Control-Allow-Origin', '*')
        self.send_header('Content-Length', len(response))
        self.end_headers()
        self.wfile.write(response.encode())
    
    def send_error_response(self, message):
        """Send error response"""
        response = json.dumps({'error': message})
        self.send_response(400)
        self.send_header('Content-Type', 'application/json')
        self.send_header('Access-Control-Allow-Origin', '*')
        self.end_headers()
        self.wfile.write(response.encode())
    
    def end_headers(self):
        """Add CORS headers"""
        self.send_header('Access-Control-Allow-Origin', '*')
        self.send_header('Access-Control-Allow-Methods', 'GET, POST, OPTIONS')
        self.send_header('Access-Control-Allow-Headers', 'Content-Type')
        super().end_headers()

def start_server():
    """Start the test server"""
    print("=" * 60)
    print("🚀 ShowTrackAI Geolocation Test Server")
    print("=" * 60)
    print(f"\n📍 Starting server on http://{HOST}:{PORT}")
    print("\n🧪 Available endpoints:")
    print(f"   • http://{HOST}:{PORT}/ - Main test interface")
    print(f"   • http://{HOST}:{PORT}/api/weather - Mock weather data")
    print(f"   • http://{HOST}:{PORT}/api/location - Mock location data")
    print(f"   • http://{HOST}:{PORT}/api/journal - Journal status")
    print("\n⚠️  Note: For production geolocation, HTTPS is required.")
    print("    This server is for local testing only.")
    print("\n🛑 Press Ctrl+C to stop the server")
    print("=" * 60)
    
    # Change to the directory containing the HTML file
    os.chdir(os.path.dirname(os.path.abspath(__file__)))
    
    # Create server
    with socketserver.TCPServer((HOST, PORT), GeolocationTestHandler) as httpd:
        # Auto-open browser
        webbrowser.open(f'http://{HOST}:{PORT}')
        
        try:
            httpd.serve_forever()
        except KeyboardInterrupt:
            print("\n\n🛑 Server stopped by user")
            return

if __name__ == "__main__":
    start_server()