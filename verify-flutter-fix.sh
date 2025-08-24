#!/bin/bash

echo "🔍 Verifying Flutter HTML Renderer Fix"
echo "====================================="

# Check if build directory exists
if [ ! -d "build/web" ]; then
    echo "❌ Build directory not found. Run './build-html-renderer.sh' first."
    exit 1
fi

# Check if flutter_bootstrap.js exists
if [ ! -f "build/web/flutter_bootstrap.js" ]; then
    echo "❌ flutter_bootstrap.js not found"
    exit 1
fi

echo "📁 Checking build files..."
echo "✅ build/web/ directory exists"
echo "✅ flutter_bootstrap.js exists"

# Check renderer configuration
echo ""
echo "🔧 Checking renderer configuration..."
RENDERER=$(grep -o '"renderer":"[^"]*"' build/web/flutter_bootstrap.js | head -1)
echo "Found: $RENDERER"

if [[ $RENDERER == *'"renderer":"html"'* ]]; then
    echo "✅ HTML renderer configured correctly"
else
    echo "❌ Renderer configuration incorrect: $RENDERER"
    echo "Expected: \"renderer\":\"html\""
fi

# Check for main files
echo ""
echo "📦 Checking main Flutter files..."
FILES=(
    "build/web/index.html"
    "build/web/main.dart.js"
    "build/web/flutter.js"
    "build/web/manifest.json"
)

for file in "${FILES[@]}"; do
    if [ -f "$file" ]; then
        echo "✅ $file exists"
    else
        echo "❌ $file missing"
    fi
done

# Check for CanvasKit files (should exist but not be used)
echo ""
echo "🎨 Checking CanvasKit files (present but not used)..."
if [ -d "build/web/canvaskit" ]; then
    echo "✅ CanvasKit directory exists (fallback available)"
else
    echo "⚠️ CanvasKit directory missing (fallback not available)"
fi

# Test file sizes
echo ""
echo "📊 File sizes:"
echo "flutter_bootstrap.js: $(wc -c < build/web/flutter_bootstrap.js) bytes"
echo "main.dart.js: $(wc -c < build/web/main.dart.js) bytes"
echo "index.html: $(wc -c < build/web/index.html) bytes"

# Check if server is running
echo ""
echo "🌐 Checking local server..."
if curl -s http://localhost:8087 > /dev/null; then
    echo "✅ Local server running on http://localhost:8087"
    echo ""
    echo "🚀 Test URLs:"
    echo "   Main app: http://localhost:8087"
    echo "   Test page: http://localhost:8087/flutter-test.html"
    echo "   Debug: http://localhost:8087/flutter-debug.html"
else
    echo "❌ Local server not running"
    echo "   Start with: python3 -m http.server 8087"
fi

echo ""
echo "🧪 Quick test commands:"
echo "   Open browser: open http://localhost:8087"
echo "   Test renderer: open http://localhost:8087/flutter-test.html"
echo "   Run debug: cat debug-flutter-rendering.js | pbcopy (then paste in console)"

echo ""
if [[ $RENDERER == *'"renderer":"html"'* ]]; then
    echo "✅ Flutter HTML renderer fix appears to be correctly applied!"
    echo "   If you still see a black screen, open the browser console"
    echo "   and run the debug script to identify remaining issues."
else
    echo "❌ Flutter HTML renderer fix needs attention"
    echo "   Run './build-html-renderer.sh' again or manually edit flutter_bootstrap.js"
fi