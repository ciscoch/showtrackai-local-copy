#!/bin/bash

echo "🔍 Checking for duplicate Flutter initialization..."
echo "================================================"

cd /Users/francisco/Documents/CALUDE/showtrackai-local-copy/build/web

echo ""
echo "1. Checking index.html for duplicate script tags..."
FLUTTER_JS_COUNT=$(grep -c 'src="flutter.js"' index.html)
BOOTSTRAP_COUNT=$(grep -c 'flutter_bootstrap.js' index.html)
MAIN_DART_COUNT=$(grep -c 'main.dart.js' index.html)

if [ "$FLUTTER_JS_COUNT" -eq 1 ]; then
    echo "✅ flutter.js loaded once"
else
    echo "❌ flutter.js loaded $FLUTTER_JS_COUNT times"
fi

if [ "$BOOTSTRAP_COUNT" -eq 0 ]; then
    echo "✅ No manual flutter_bootstrap.js references"
else
    echo "❌ flutter_bootstrap.js manually referenced $BOOTSTRAP_COUNT times"
fi

if [ "$MAIN_DART_COUNT" -eq 0 ]; then
    echo "✅ No manual main.dart.js references"
else
    echo "❌ main.dart.js manually referenced $MAIN_DART_COUNT times"
fi

echo ""
echo "2. Checking for initialization functions..."
INIT_FLUTTER_COUNT=$(grep -c 'initializeFlutter' index.html)
LOADER_ENTRYPOINT=$(grep -c '_flutter.loader.loadEntrypoint' index.html)

if [ "$INIT_FLUTTER_COUNT" -eq 0 ]; then
    echo "✅ No custom initializeFlutter functions"
else
    echo "⚠️  Found $INIT_FLUTTER_COUNT initializeFlutter references"
fi

if [ "$LOADER_ENTRYPOINT" -eq 0 ]; then
    echo "✅ No manual _flutter.loader.loadEntrypoint calls"
else
    echo "❌ Found $LOADER_ENTRYPOINT _flutter.loader.loadEntrypoint calls"
fi

echo ""
echo "3. Checking for safeguards..."
if grep -q "__STA_BOOTED__" index.html; then
    echo "✅ Double-boot prevention guard found"
else
    echo "⚠️  No double-boot prevention guard"
fi

if grep -q "flutter-first-frame" index.html; then
    echo "✅ Flutter first-frame listener found"
else
    echo "❌ No flutter-first-frame listener"
fi

if grep -q "pointer-events: none" index.html; then
    echo "✅ Splash has pointer-events: none (won't block clicks)"
else
    echo "⚠️  Splash might block clicks"
fi

echo ""
echo "4. Checking element IDs..."
if grep -q 'id="splash"' index.html; then
    echo "✅ Using splash ID for loading screen"
elif grep -q 'id="loading"' index.html; then
    echo "⚠️  Using 'loading' ID instead of 'splash'"
else
    echo "❌ No splash/loading element found"
fi

echo ""
echo "================================================"
echo "✅ Verification complete!"
echo ""
echo "To test in browser, open: http://localhost:8087"
echo "Then check console with: http://localhost:8087/check-flutter-state.html"