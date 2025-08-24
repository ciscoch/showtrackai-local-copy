#!/bin/bash

# Test script to verify Netlify deployment fixes
echo "🧪 Testing Netlify Deployment Fixes"
echo "=================================="

# Check 1: Verify flutter_bootstrap.js exists
echo "1. Checking flutter_bootstrap.js..."
if [ -f "web/flutter_bootstrap.js" ]; then
    echo "✅ flutter_bootstrap.js exists in web/"
    file_size=$(wc -c < web/flutter_bootstrap.js)
    echo "   File size: $file_size bytes"
else
    echo "❌ flutter_bootstrap.js missing from web/"
fi

# Check 2: Verify HTML renderer configuration
echo ""
echo "2. Checking Flutter HTML renderer config..."
if grep -q '"renderer": "html"' web/flutter_build_config.json; then
    echo "✅ HTML renderer configured in flutter_build_config.json"
else
    echo "❌ HTML renderer not properly configured"
fi

# Check 3: Check CSP for Google Fonts
echo ""
echo "3. Checking CSP for Google Fonts..."
if grep -q "https://fonts.googleapis.com" netlify.toml && grep -q "https://fonts.gstatic.com" netlify.toml; then
    echo "✅ Google Fonts domains allowed in CSP"
else
    echo "❌ Google Fonts domains not found in CSP"
fi

# Check 4: Verify index.html has proper font loading
echo ""
echo "4. Checking font loading in index.html..."
if grep -q "fonts.googleapis.com" web/index.html; then
    echo "✅ Google Fonts preload configured"
else
    echo "❌ Google Fonts preload missing"
fi

# Check 5: Check for CanvasKit removal in build script
echo ""
echo "5. Checking CanvasKit removal in build script..."
if grep -q "rm -rf.*canvaskit" netlify-build.sh; then
    echo "✅ CanvasKit removal configured in build script"
else
    echo "❌ CanvasKit removal not found in build script"
fi

# Check 6: Verify loading screen management
echo ""
echo "6. Checking loading screen management..."
if grep -q "flutter-first-frame" web/index.html; then
    echo "✅ Loading screen properly configured"
else
    echo "❌ Loading screen management missing"
fi

# Check 7: Build script syntax check
echo ""
echo "7. Checking build script syntax..."
if bash -n netlify-build.sh 2>/dev/null; then
    echo "✅ Build script syntax is valid"
else
    echo "❌ Build script has syntax errors"
    bash -n netlify-build.sh
fi

# Check 8: Flutter bootstrap syntax check
echo ""
echo "8. Checking flutter_bootstrap.js syntax..."
if node -c web/flutter_bootstrap.js 2>/dev/null; then
    echo "✅ flutter_bootstrap.js syntax is valid"
else
    echo "❌ flutter_bootstrap.js has syntax errors"
    node -c web/flutter_bootstrap.js
fi

echo ""
echo "🎯 Summary:"
echo "   - All critical files should exist"
echo "   - HTML renderer should be enforced"
echo "   - Google Fonts should be allowed"
echo "   - Loading screen should be managed properly"
echo "   - CanvasKit should be completely removed"
echo ""
echo "Next steps: Test locally with 'flutter build web --web-renderer html'"
echo "Then deploy to Netlify branch for testing"