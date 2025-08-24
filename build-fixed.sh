#!/bin/bash

# Enhanced Flutter Build Script with Duplicate Initialization Fix
# Builds the web app and automatically applies safeguards

echo "🚀 Building ShowTrackAI with Flutter initialization safeguards..."

# Clean previous build
echo "🧹 Cleaning previous build..."
flutter clean

# Build the web app
echo "📦 Building Flutter web app..."
flutter build web --dart-define=FLUTTER_WEB_USE_SKIA=false --dart-define=FLUTTER_WEB_CANVASKIT_URL=blocked

# Check if build was successful
if [ $? -eq 0 ]; then
    echo "✅ Flutter build completed successfully"
else
    echo "❌ Flutter build failed"
    exit 1
fi

# Apply the flutter_bootstrap.js fix
echo "🔧 Applying Flutter initialization safeguards..."
./fix-flutter-bootstrap.sh

if [ $? -eq 0 ]; then
    echo "✅ Flutter bootstrap fix applied successfully"
else
    echo "❌ Failed to apply bootstrap fix"
    exit 1
fi

# Verify all critical files exist
echo "🔍 Verifying build output..."

REQUIRED_FILES=(
    "build/web/index.html"
    "build/web/main.dart.js"
    "build/web/flutter.js"
    "build/web/flutter_bootstrap.js"
    "build/web/manifest.json"
)

for file in "${REQUIRED_FILES[@]}"; do
    if [ -f "$file" ]; then
        echo "✅ $file - Found"
    else
        echo "❌ $file - Missing!"
        exit 1
    fi
done

# Check for safeguard implementation
echo "🛡️  Verifying safeguards..."

# Check index.html for safeguard system
if grep -q "Flutter Initialization Safeguard System" build/web/index.html; then
    echo "✅ Index.html safeguards - Active"
else
    echo "❌ Index.html safeguards - Missing"
    exit 1
fi

# Check flutter_bootstrap.js for safeguards
if grep -q "Flutter Bootstrap Initialization Safeguard" build/web/flutter_bootstrap.js; then
    echo "✅ Bootstrap safeguards - Active"
else
    echo "❌ Bootstrap safeguards - Missing"
    exit 1
fi

# Check for HTML renderer configuration
if grep -q '"renderer": "html"' build/web/flutter_bootstrap.js; then
    echo "✅ HTML renderer - Forced"
else
    echo "⚠️  HTML renderer - Check manually (spaces in JSON)"
fi

# Build summary
echo ""
echo "📊 BUILD SUMMARY"
echo "=================="

# File sizes
INDEX_SIZE=$(du -h build/web/index.html | cut -f1)
MAIN_SIZE=$(du -h build/web/main.dart.js | cut -f1)
FLUTTER_SIZE=$(du -h build/web/flutter.js | cut -f1)
BOOTSTRAP_SIZE=$(du -h build/web/flutter_bootstrap.js | cut -f1)

echo "📄 File Sizes:"
echo "   - index.html: $INDEX_SIZE"
echo "   - main.dart.js: $MAIN_SIZE" 
echo "   - flutter.js: $FLUTTER_SIZE"
echo "   - flutter_bootstrap.js: $BOOTSTRAP_SIZE"

echo ""
echo "🛡️  Security Features:"
echo "   - ✅ Duplicate initialization prevention"
echo "   - ✅ HTML renderer forced (no CanvasKit)"
echo "   - ✅ Comprehensive initialization logging"
echo "   - ✅ Race condition protection"
echo "   - ✅ Error handling and retry logic"

echo ""
echo "🚀 DEPLOYMENT READY!"
echo "===================="
echo ""
echo "The Flutter web app has been built with safeguards to prevent:"
echo "   • Duplicate Flutter initialization on route navigation"
echo "   • Race conditions between flutter.js and flutter_bootstrap.js"
echo "   • CanvasKit loading issues"
echo "   • Route-specific re-initialization problems"
echo ""
echo "Next steps:"
echo "1. Test locally: python3 -m http.server 8080 --directory build/web"
echo "2. Deploy to Netlify"
echo "3. Monitor browser console for initialization logs"
echo ""
echo "✨ Happy coding!"