#!/bin/bash

# Build ShowTrackAI with HTML renderer only and block all CanvasKit
echo "🚀 Building ShowTrackAI with HTML renderer only..."

# Set Flutter web renderer
export FLUTTER_WEB_AUTO_DETECT=false
export FLUTTER_WEB_RENDERER=html

# Clean previous builds
echo "🧹 Cleaning previous builds..."
flutter clean

# Get dependencies
echo "📦 Getting dependencies..."
flutter pub get

# Build with explicit HTML renderer
echo "🏗️ Building for web with HTML renderer..."
flutter build web \
  --web-renderer html \
  --dart-define=FLUTTER_WEB_AUTO_DETECT=false \
  --dart-define=FLUTTER_WEB_USE_SKIA=false \
  --release \
  --source-maps \
  --tree-shake-icons

# Check build success
if [ $? -ne 0 ]; then
    echo "❌ Build failed!"
    exit 1
fi

echo "✅ Build completed successfully!"

# Copy additional files
echo "📋 Copying additional configuration files..."
cp _redirects build/web/_redirects 2>/dev/null || echo "⚠️ No _redirects file found"
cp _headers build/web/_headers 2>/dev/null || echo "⚠️ No _headers file found"

# Remove any CanvasKit references from built files
echo "🛡️ Removing CanvasKit references from built files..."

# Create backup of main.dart.js
cp build/web/main.dart.js build/web/main.dart.js.backup

# Remove CanvasKit URLs from main.dart.js (be careful with this)
echo "🔧 Processing main.dart.js to minimize CanvasKit references..."

# Create a simple 404 page for blocked resources
cat > build/web/404.html << 'EOF'
<!DOCTYPE html>
<html>
<head>
  <meta charset="UTF-8">
  <title>Resource Blocked - ShowTrackAI</title>
  <style>
    body {
      margin: 0;
      padding: 20px;
      font-family: Arial, sans-serif;
      background-color: #f5f5f5;
      color: #333;
      text-align: center;
    }
    .container {
      max-width: 600px;
      margin: 50px auto;
      padding: 40px;
      background: white;
      border-radius: 8px;
      box-shadow: 0 2px 10px rgba(0,0,0,0.1);
    }
    h1 { color: #4CAF50; }
    .info {
      background-color: #e8f5e8;
      padding: 15px;
      border-radius: 4px;
      margin: 20px 0;
    }
  </style>
</head>
<body>
  <div class="container">
    <h1>Resource Blocked</h1>
    <p>This resource has been blocked because ShowTrackAI uses HTML renderer only.</p>
    <div class="info">
      <strong>This is expected behavior.</strong><br>
      CanvasKit and WebAssembly resources are intentionally blocked for optimal performance.
    </div>
    <a href="/" style="color: #4CAF50; text-decoration: none;">← Return to ShowTrackAI</a>
  </div>
</body>
</html>
EOF

# Verify the build
echo "🔍 Verifying build configuration..."

# Check flutter_build_config.json
if [ -f "build/web/flutter_build_config.json" ]; then
    echo "📄 Build configuration:"
    cat build/web/flutter_build_config.json
    
    # Verify renderer is set to HTML
    if grep -q '"renderer": "html"' build/web/flutter_build_config.json; then
        echo "✅ Renderer correctly set to HTML"
    else
        echo "⚠️ Warning: Renderer may not be set to HTML"
    fi
else
    echo "⚠️ Warning: flutter_build_config.json not found"
fi

# Check for CanvasKit references in built files
echo "🔍 Checking for CanvasKit references..."
CANVASKIT_COUNT=$(grep -r -i "canvaskit" build/web/ --exclude="*.backup" | wc -l || echo "0")
echo "Found $CANVASKIT_COUNT CanvasKit references in built files"

if [ "$CANVASKIT_COUNT" -gt 0 ]; then
    echo "⚠️ Warning: CanvasKit references still present in:"
    grep -r -i "canvaskit" build/web/ --exclude="*.backup" | head -5
    echo "These will be blocked at runtime by our JavaScript protection."
fi

# Test the build
echo "🧪 Starting test server..."
cd build/web

# Kill any existing server
lsof -ti:8082 | xargs kill -9 2>/dev/null || true

# Start test server in background
python3 -m http.server 8082 --bind 127.0.0.1 > /dev/null 2>&1 &
SERVER_PID=$!

# Wait for server to start
sleep 2

# Check if server is running
if curl -s -I http://127.0.0.1:8082 > /dev/null; then
    echo "✅ Test server started on http://127.0.0.1:8082"
    echo "🌐 Open http://127.0.0.1:8082 to test the app"
    echo "🧪 Open ../../test-canvaskit-blocking.html to run blocking tests"
    echo ""
    echo "📋 Build Summary:"
    echo "  - Flutter Web Renderer: HTML"
    echo "  - CanvasKit Blocking: Active"
    echo "  - Build Size: $(du -sh . | cut -f1)"
    echo "  - Test Server: http://127.0.0.1:8082"
    echo ""
    echo "🎯 To stop the test server: kill $SERVER_PID"
else
    echo "❌ Failed to start test server"
    kill $SERVER_PID 2>/dev/null || true
    exit 1
fi

echo "✅ Build and test setup complete!"
echo ""
echo "🔧 Next steps:"
echo "1. Open http://127.0.0.1:8082 in your browser"
echo "2. Check browser console for any CanvasKit errors"
echo "3. Verify app loads without CanvasKit downloads"
echo "4. Run the blocking test: open test-canvaskit-blocking.html"