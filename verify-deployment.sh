#!/bin/bash

echo "🔍 Verifying ShowTrackAI Deployment..."
echo "======================================="

# Check if build exists
if [ -d "build/web" ]; then
    echo "✅ Build directory exists"
else
    echo "❌ Build directory missing"
    exit 1
fi

# Check critical files
FILES=("flutter.js" "main.dart.js" "index.html" "manifest.json")
for file in "${FILES[@]}"; do
    if [ -f "build/web/$file" ]; then
        echo "✅ $file exists"
    else
        echo "❌ $file missing"
        exit 1
    fi
done

# Check base href
BASE_HREF=$(grep '<base href' build/web/index.html | grep -o 'href="[^"]*"' | cut -d'"' -f2)
if [ "$BASE_HREF" = "./" ]; then
    echo "✅ Base href is correct: $BASE_HREF"
else
    echo "⚠️  Base href is: $BASE_HREF (should be ./)"
fi

# Check if server is running
if curl -s -I http://localhost:8087 > /dev/null 2>&1; then
    echo "✅ Server is running on port 8087"
else
    echo "❌ Server not responding on port 8087"
fi

# Test file accessibility
echo ""
echo "Testing file accessibility:"
for file in "flutter.js" "main.dart.js"; do
    STATUS=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:8087/$file)
    if [ "$STATUS" = "200" ]; then
        echo "✅ $file: HTTP $STATUS"
    else
        echo "❌ $file: HTTP $STATUS"
    fi
done

echo ""
echo "======================================="
echo "🚀 Open http://localhost:8087 in your browser"
echo "📋 Check browser console for debugging info"
echo ""
echo "If the app doesn't load, look for:"
echo "1. Console errors (F12 -> Console tab)"
echo "2. Network errors (F12 -> Network tab)"
echo "3. The debugging messages added to track loading"