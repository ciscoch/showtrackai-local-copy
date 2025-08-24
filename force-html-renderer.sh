#!/bin/bash

echo "🔧 Forcing HTML Renderer for Flutter Web"
echo "========================================"

cd /Users/francisco/Documents/CALUDE/showtrackai-local-copy/build/web

# Backup the original file
cp flutter_bootstrap.js flutter_bootstrap.js.backup

echo "📋 Step 1: Modifying flutter_bootstrap.js to force HTML renderer..."

# Replace canvaskit with html in the build config
sed -i '' 's/"renderer":"canvaskit"/"renderer":"html"/g' flutter_bootstrap.js

echo "📋 Step 2: Verifying the change..."
if grep -q '"renderer":"html"' flutter_bootstrap.js; then
    echo "✅ Successfully changed renderer to HTML"
else
    echo "❌ Failed to change renderer, restoring backup"
    cp flutter_bootstrap.js.backup flutter_bootstrap.js
    exit 1
fi

echo "📋 Step 3: Also forcing HTML renderer in the config..."
# Create a more explicit fix
cat > flutter_bootstrap_fix.js << 'EOF'
// Force HTML renderer override
if (window._flutter && window._flutter.buildConfig) {
    console.log('🔧 Original renderer:', window._flutter.buildConfig.builds[0].renderer);
    window._flutter.buildConfig.builds[0].renderer = 'html';
    console.log('✅ Forced renderer to:', window._flutter.buildConfig.builds[0].renderer);
}
EOF

# Inject the fix into the beginning of flutter_bootstrap.js
cat flutter_bootstrap_fix.js > flutter_bootstrap_temp.js
echo "" >> flutter_bootstrap_temp.js
cat flutter_bootstrap.js >> flutter_bootstrap_temp.js
mv flutter_bootstrap_temp.js flutter_bootstrap.js
rm flutter_bootstrap_fix.js

echo "✅ HTML renderer fix applied successfully!"

echo "📋 Step 4: Copy diagnostic file..."
cp ../flutter-black-screen-diagnostic.html ./diagnostic.html

echo "📋 Step 5: Starting server..."
echo "🌐 Main app: http://localhost:8087"
echo "🔍 Diagnostic: http://localhost:8087/diagnostic.html"
echo "📱 Test should show colorful minimal app if working"
echo ""
echo "Expected behavior:"
echo "✅ Colorful test screen = Flutter working correctly"
echo "❌ Black screen = Still has issues"
echo "⚠️ White screen = Theme problems"
echo ""

# Start server
python3 -m http.server 8087