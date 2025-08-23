#!/bin/bash

echo "🔍 Verifying ShowTrackAI deployment..."
echo "========================================="

URL="https://mellifluous-speculoos-46225c.netlify.app"

# Test flutter_bootstrap.js
echo ""
echo "📄 Testing flutter_bootstrap.js..."
RESPONSE=$(curl -sI "$URL/flutter_bootstrap.js" | head -20)
echo "$RESPONSE" | grep -E "HTTP|Content-Type|Content-Encoding|Content-Length"

# Check file size
SIZE=$(curl -sI "$URL/flutter_bootstrap.js" | grep -i content-length | awk '{print $2}' | tr -d '\r')
if [ -n "$SIZE" ] && [ "$SIZE" -gt 0 ]; then
    echo "✅ File size: $SIZE bytes"
else
    echo "❌ File appears to be empty or missing"
fi

# Test main.dart.js
echo ""
echo "📄 Testing main.dart.js..."
curl -sI "$URL/main.dart.js" | grep -E "HTTP|Content-Type|Content-Encoding|Content-Length" | head -5

# Test if page loads
echo ""
echo "🌐 Testing page load..."
HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" "$URL")
if [ "$HTTP_CODE" = "200" ]; then
    echo "✅ Page returns 200 OK"
else
    echo "❌ Page returns $HTTP_CODE"
fi

# Check for JavaScript errors
echo ""
echo "🔧 Quick content check..."
CONTENT=$(curl -s "$URL" | head -100)
if echo "$CONTENT" | grep -q "flutter"; then
    echo "✅ Flutter references found in HTML"
else
    echo "⚠️  No Flutter references found"
fi

echo ""
echo "========================================="
echo "📝 Summary:"
echo "- If all checks pass, the app should load"
echo "- Check browser console for any remaining errors"
echo "- URL: $URL"