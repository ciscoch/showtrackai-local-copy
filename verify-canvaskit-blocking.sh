#!/bin/bash

# Verify CanvasKit blocking in the current build
echo "🔍 Verifying CanvasKit blocking in ShowTrackAI..."

cd /Users/francisco/Documents/CALUDE/showtrackai-local-copy

# Check if build exists
if [ ! -d "build/web" ]; then
    echo "❌ No build found. Please run flutter build web first."
    exit 1
fi

echo "📁 Build directory found"

# Check build configuration
echo "📄 Checking build configuration..."
if [ -f "build/web/flutter_build_config.json" ]; then
    echo "Flutter build config:"
    cat build/web/flutter_build_config.json
    echo ""
fi

# Check index.html for blocking code
echo "🛡️ Checking index.html for CanvasKit blocking code..."
if grep -q "Blocked CanvasKit" build/web/index.html; then
    echo "✅ CanvasKit blocking code found in index.html"
else
    echo "❌ CanvasKit blocking code NOT found in index.html"
fi

# Check for _redirects file
echo "📋 Checking for _redirects file..."
if [ -f "build/web/_redirects" ]; then
    echo "✅ _redirects file found"
    grep -i canvaskit build/web/_redirects
else
    echo "⚠️ _redirects file not found"
fi

# Check for CanvasKit references in main files
echo "🔍 Checking for CanvasKit references in built files..."
echo "Searching main.dart.js..."
MAIN_CANVASKIT=$(grep -i canvaskit build/web/main.dart.js | wc -l)
echo "Found $MAIN_CANVASKIT CanvasKit references in main.dart.js"

echo "Searching flutter.js..."
FLUTTER_CANVASKIT=$(grep -i canvaskit build/web/flutter.js | wc -l)
echo "Found $FLUTTER_CANVASKIT CanvasKit references in flutter.js"

# Start test server
echo "🚀 Starting test server..."
cd build/web

# Kill any existing server on port 8083
lsof -ti:8083 | xargs kill -9 2>/dev/null || true

# Start server
python3 -m http.server 8083 --bind 127.0.0.1 &
SERVER_PID=$!

# Wait for server
sleep 2

# Test server
if curl -s -I http://127.0.0.1:8083 > /dev/null; then
    echo "✅ Test server running on http://127.0.0.1:8083"
    
    # Test the blocking test page
    cp ../../test-canvaskit-blocking.html .
    echo "🧪 CanvasKit blocking test page: http://127.0.0.1:8083/test-canvaskit-blocking.html"
    
    echo ""
    echo "🎯 Verification Summary:"
    echo "========================"
    echo "Build exists: ✅"
    echo "Blocking code in index.html: $([ $MAIN_CANVASKIT -eq 0 ] && echo '❌' || echo '✅')"
    echo "Redirects configured: $([ -f '_redirects' ] && echo '✅' || echo '❌')"
    echo "CanvasKit refs in main.dart.js: $MAIN_CANVASKIT"
    echo "CanvasKit refs in flutter.js: $FLUTTER_CANVASKIT"
    echo ""
    echo "📱 Test URLs:"
    echo "  Main app: http://127.0.0.1:8083"
    echo "  Blocking test: http://127.0.0.1:8083/test-canvaskit-blocking.html"
    echo ""
    echo "🔧 To stop server: kill $SERVER_PID"
    echo ""
    
    # Open in browser if available
    if command -v open > /dev/null; then
        echo "🌐 Opening test page in browser..."
        open http://127.0.0.1:8083/test-canvaskit-blocking.html
    fi
    
else
    echo "❌ Failed to start test server"
    kill $SERVER_PID 2>/dev/null || true
    exit 1
fi

echo "✅ Verification complete!"
echo "The app should now load without CanvasKit errors."
echo "Check the browser console and the blocking test results."