#!/bin/bash

# ShowTrackAI Geolocation Test Runner
# This script starts the local test server for geolocation features

echo "🚀 ShowTrackAI Geolocation Test Server"
echo "======================================"
echo ""

# Check if Python 3 is installed
if ! command -v python3 &> /dev/null; then
    echo "❌ Python 3 is required but not installed."
    echo "   Please install Python 3 to run the test server."
    exit 1
fi

# Check if the HTML file exists
if [ ! -f "geolocation-test-server.html" ]; then
    echo "❌ Test interface file not found: geolocation-test-server.html"
    echo "   Please ensure you're in the correct directory."
    exit 1
fi

echo "✅ All requirements met. Starting server..."
echo ""

# Option 1: Use Python's built-in HTTP server (simpler)
echo "Choose your server option:"
echo "1) Simple HTTP Server (Python built-in)"
echo "2) Advanced Test Server (with API mocking)"
echo "3) Open HTML file directly in browser"
echo ""
read -p "Enter your choice (1-3): " choice

case $choice in
    1)
        echo "Starting simple HTTP server on http://localhost:8080"
        echo "Opening browser..."
        open http://localhost:8080/geolocation-test-server.html 2>/dev/null || xdg-open http://localhost:8080/geolocation-test-server.html 2>/dev/null
        python3 -m http.server 8080
        ;;
    2)
        echo "Starting advanced test server with API mocking..."
        python3 start-test-server.py
        ;;
    3)
        echo "Opening test interface directly in browser..."
        open geolocation-test-server.html 2>/dev/null || xdg-open geolocation-test-server.html 2>/dev/null
        echo "✅ Opened in browser. Note: Some features may be limited without a server."
        ;;
    *)
        echo "Invalid choice. Exiting."
        exit 1
        ;;
esac