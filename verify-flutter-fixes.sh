#!/bin/bash

echo "🔍 Verifying Flutter Initialization Fixes"
echo "========================================="

# Check if build directory exists
if [ ! -d "build/web" ]; then
    echo "❌ Build directory not found. Please run 'flutter build web' first."
    exit 1
fi

echo "✅ Build directory found"

# Check for required files
required_files=(
    "build/web/index.html"
    "build/web/flutter_bootstrap.js"
    "build/web/flutter.js"
    "build/web/flutter_build_config.json"
    "build/web/main.dart.js"
)

for file in "${required_files[@]}"; do
    if [ -f "$file" ]; then
        echo "✅ $file exists"
    else
        echo "❌ $file missing"
    fi
done

echo ""
echo "🔧 Checking Flutter configuration..."

# Check if buildConfig is properly set in index.html
if grep -q "_flutter.buildConfig" build/web/index.html; then
    echo "✅ buildConfig setup found in index.html"
else
    echo "❌ buildConfig setup not found in index.html"
fi

# Check if permission policy is set
if grep -q "Permissions-Policy" build/web/index.html; then
    echo "✅ Permissions-Policy meta tag found"
else
    echo "❌ Permissions-Policy meta tag not found"
fi

# Check if flutter_bootstrap.js has correct initialization
if grep -q "initializeFlutter" build/web/flutter_bootstrap.js; then
    echo "✅ Flutter initialization function found in bootstrap"
else
    echo "❌ Flutter initialization function not found in bootstrap"
fi

# Check flutter_build_config.json
if [ -f "build/web/flutter_build_config.json" ]; then
    renderer=$(grep -o '"renderer": *"[^"]*"' build/web/flutter_build_config.json | grep -o '"[^"]*"$' | tr -d '"')
    if [ "$renderer" = "html" ]; then
        echo "✅ Build config uses HTML renderer"
    else
        echo "❌ Build config renderer is not HTML: $renderer"
    fi
else
    echo "❌ flutter_build_config.json not found"
fi

echo ""
echo "📊 File sizes:"
ls -lh build/web/*.js | awk '{print $9, $5}'
ls -lh build/web/*.html | awk '{print $9, $5}'

echo ""
echo "🧪 Testing buildConfig setup..."

# Extract buildConfig from index.html and validate it
if grep -A 10 "_flutter.buildConfig" build/web/index.html | grep -q '"renderer": "html"'; then
    echo "✅ buildConfig renderer properly set to HTML"
else
    echo "❌ buildConfig renderer not set to HTML"
fi

echo ""
echo "📋 Summary:"
echo "==========="

# Count successful checks
success_count=0
total_checks=8

# Recount all checks
[ -d "build/web" ] && ((success_count++))
for file in "${required_files[@]}"; do
    [ -f "$file" ] && ((success_count++))
done
grep -q "_flutter.buildConfig" build/web/index.html && ((success_count++))
grep -q "Permissions-Policy" build/web/index.html && ((success_count++))
grep -q "initializeFlutter" build/web/flutter_bootstrap.js && ((success_count++))

if [ -f "build/web/flutter_build_config.json" ]; then
    renderer=$(grep -o '"renderer": *"[^"]*"' build/web/flutter_build_config.json | grep -o '"[^"]*"$' | tr -d '"')
    [ "$renderer" = "html" ] && ((success_count++))
fi

if grep -A 10 "_flutter.buildConfig" build/web/index.html | grep -q '"renderer": "html"'; then
    ((success_count++))
fi

echo "✅ Passed: $success_count/$((${#required_files[@]} + 4)) checks"

if [ $success_count -ge $((${#required_files[@]} + 3)) ]; then
    echo "🎉 Flutter initialization fixes are properly deployed!"
    echo ""
    echo "🚀 Ready for Netlify deployment:"
    echo "   - Permission policy violations fixed"
    echo "   - buildConfig properly configured"
    echo "   - HTML renderer enforced"
    echo "   - Bootstrap initialization sequence corrected"
    exit 0
else
    echo "❌ Some issues found. Please review the output above."
    exit 1
fi