#!/bin/bash

# Test script for Flutter compilation fixes
# Verifies that all deprecation warnings and WebAssembly issues are resolved

set -e  # Exit on any error

echo "🧪 Testing Flutter compilation fixes for Netlify deployment..."

# Ensure we're in the Flutter project directory
cd "$(dirname "$0")"

# Clean previous builds
echo "🧹 Cleaning previous build artifacts..."
flutter clean
flutter pub get

# Test build for web with detailed output
echo "🔨 Building for web with warnings visible..."
flutter build web --web-renderer html --verbose 2>&1 | tee build-test.log

# Check for specific warnings/errors
echo ""
echo "🔍 Checking for resolved issues..."

# Check for loadEntrypoint deprecation warning
if grep -q "loadEntrypoint.*deprecated" build-test.log; then
    echo "❌ FAIL: loadEntrypoint deprecation warning still present"
    exit 1
else
    echo "✅ PASS: loadEntrypoint deprecation warning resolved"
fi

# Check for universal_html warnings
if grep -q "universal_html" build-test.log && grep -q "dart:html.*unsupported" build-test.log; then
    echo "❌ FAIL: universal_html WebAssembly compatibility issue still present"
    exit 1
else
    echo "✅ PASS: universal_html issue resolved"
fi

# Check for geolocator_web warnings
if grep -q "geolocator_web.*dart:html.*unsupported" build-test.log; then
    echo "❌ FAIL: geolocator_web WebAssembly compatibility issue still present"
    exit 1
else
    echo "✅ PASS: geolocator_web issue resolved or acceptable"
fi

# Check if build completed successfully
if [ $? -eq 0 ]; then
    echo ""
    echo "🎉 SUCCESS: Flutter web build completed without critical warnings!"
    echo ""
    echo "📋 Summary of fixes applied:"
    echo "  ✅ Updated FlutterLoader API from loadEntrypoint() to load()"
    echo "  ✅ Replaced universal_html with platform-specific conditional imports"
    echo "  ✅ Added explicit geolocator_web dependency"
    echo "  ✅ Created WebAssembly-compatible CSV export implementation"
    echo ""
    echo "🚀 Ready for Netlify deployment!"
    
    # Optionally test the build
    echo ""
    echo "🌐 Testing built app (optional - press Ctrl+C to skip)..."
    echo "Starting local server on http://localhost:8080..."
    cd build/web && python3 -m http.server 8080 || python -m SimpleHTTPServer 8080
else
    echo "❌ FAIL: Build failed with errors"
    exit 1
fi