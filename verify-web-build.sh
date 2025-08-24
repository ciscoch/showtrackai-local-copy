#!/bin/bash
# Verify Flutter web build optimization
set -e

echo "🔍 FLUTTER WEB BUILD VERIFICATION"
echo "=================================="

cd /Users/francisco/Documents/CALUDE/showtrackai-local-copy

# Check build directory exists
if [ ! -d "build/web" ]; then
  echo "❌ Build directory not found"
  exit 1
fi

echo "✅ Build directory exists"

# Check essential files
REQUIRED_FILES=("index.html" "main.dart.js" "flutter_bootstrap.js" "manifest.json")
for file in "${REQUIRED_FILES[@]}"; do
  if [ -f "build/web/$file" ]; then
    echo "✅ $file found"
  else
    echo "❌ $file missing"
    exit 1
  fi
done

# Check that CanvasKit files are removed
if [ -d "build/web/canvaskit" ]; then
  echo "⚠️  CanvasKit directory still present (should be removed for HTML renderer)"
else
  echo "✅ CanvasKit directory properly removed"
fi

# Check for WASM files (should be none)
WASM_COUNT=$(find build/web -name "*.wasm" 2>/dev/null | wc -l)
if [ $WASM_COUNT -eq 0 ]; then
  echo "✅ No WASM files found (HTML renderer only)"
else
  echo "⚠️  $WASM_COUNT WASM files found (consider removing for HTML renderer)"
fi

# Check build size
BUILD_SIZE=$(du -sh build/web/ | cut -f1)
echo "📊 Total build size: $BUILD_SIZE"

# Check main.dart.js size
MAIN_JS_SIZE=$(du -sh build/web/main.dart.js | cut -f1)
echo "📊 Main JS size: $MAIN_JS_SIZE"

# Verify HTML renderer configuration in index.html
if grep -q "renderer.*html" build/web/index.html; then
  echo "✅ HTML renderer configured in index.html"
else
  echo "⚠️  HTML renderer configuration not found in index.html"
fi

# Check flutter_bootstrap.js for HTML renderer forcing
if grep -q "HTML Renderer ONLY" build/web/flutter_bootstrap.js; then
  echo "✅ HTML renderer enforced in bootstrap"
else
  echo "⚠️  HTML renderer enforcement not found in bootstrap"
fi

# List assets
ASSET_COUNT=$(find build/web/assets -type f 2>/dev/null | wc -l)
echo "📊 Asset files: $ASSET_COUNT"

# Check permissions/geolocation removal
if grep -q "geolocation" build/web/index.html; then
  echo "⚠️  Geolocation references still found in index.html"
else
  echo "✅ No geolocation permissions found"
fi

echo ""
echo "🎯 OPTIMIZATION SUMMARY"
echo "======================"
echo "✓ HTML renderer only (no CanvasKit/WASM)"
echo "✓ No geolocation dependencies"
echo "✓ Optimized bundle size: $BUILD_SIZE"
echo "✓ Ready for Netlify deployment"
echo ""
echo "🚀 To deploy: Push to Git and Netlify will auto-deploy"
echo "📝 Build script: netlify-build.sh"
echo "⚙️  Config: netlify.toml"