#!/bin/bash
set -e

echo "🔍 Verifying Netlify Deployment Fixes..."
echo "========================================"

# Check if we're in the right directory
if [ ! -f "pubspec.yaml" ]; then
    echo "❌ pubspec.yaml not found. Are you in the project root?"
    exit 1
fi

echo "✅ Project root detected"

# Check package.json exists for Netlify Functions
echo
echo "📦 Checking Node.js dependencies..."
if [ ! -f "package.json" ]; then
    echo "❌ package.json not found - Netlify Functions will fail"
    exit 1
fi

echo "✅ package.json found"

# Verify @supabase/supabase-js is listed as dependency
if grep -q "@supabase/supabase-js" package.json; then
    echo "✅ @supabase/supabase-js dependency found"
else
    echo "❌ @supabase/supabase-js dependency not found in package.json"
    exit 1
fi

# Check asset directories exist (should have .gitkeep files)
echo
echo "📁 Checking asset directories..."
if [ -f "assets/images/.gitkeep" ]; then
    echo "✅ assets/images/ directory properly configured"
else
    echo "❌ assets/images/ directory missing or not configured"
    exit 1
fi

if [ -f "assets/icons/.gitkeep" ]; then
    echo "✅ assets/icons/ directory properly configured"
else
    echo "❌ assets/icons/ directory missing or not configured"
    exit 1
fi

# Check that problematic geolocator packages are disabled
echo
echo "🌍 Checking geolocation package configuration..."
if grep -q "# geolocator:" pubspec.yaml; then
    echo "✅ Problematic geolocator packages are disabled"
else
    echo "❌ Geolocator packages may still be enabled (could cause WebAssembly issues)"
    exit 1
fi

# Check Netlify configuration
echo
echo "⚙️  Checking Netlify configuration..."
if [ ! -f "netlify.toml" ]; then
    echo "❌ netlify.toml not found"
    exit 1
fi

echo "✅ netlify.toml found"

if grep -q "npm install" netlify.toml; then
    echo "✅ npm install configured in build command"
else
    echo "❌ npm install not found in netlify.toml build command"
    exit 1
fi

if grep -q 'functions = "netlify/functions"' netlify.toml; then
    echo "✅ Functions directory configured"
else
    echo "❌ Functions directory not configured in netlify.toml"
    exit 1
fi

# Check Netlify Functions exist
echo
echo "🔧 Checking Netlify Functions..."
if [ ! -d "netlify/functions" ]; then
    echo "❌ netlify/functions directory not found"
    exit 1
fi

echo "✅ netlify/functions directory found"

function_count=$(ls netlify/functions/*.js 2>/dev/null | wc -l)
if [ "$function_count" -gt 0 ]; then
    echo "✅ Found $function_count Netlify Functions"
else
    echo "❌ No Netlify Functions found"
    exit 1
fi

# Test Node.js dependency import (if Node.js is available)
echo
echo "🧪 Testing Node.js dependency imports..."
if command -v node >/dev/null 2>&1; then
    if [ -f "test-netlify-function-deps.js" ]; then
        echo "Running dependency test..."
        node test-netlify-function-deps.js
    else
        echo "⚠️  Dependency test script not found, skipping test"
    fi
else
    echo "⚠️  Node.js not available, skipping import test"
fi

echo
echo "🎉 All deployment fixes verified successfully!"
echo "✅ Ready for Netlify deployment"
echo
echo "📋 Summary of fixes applied:"
echo "   • Added package.json with @supabase/supabase-js dependency"
echo "   • Fixed empty asset directories with .gitkeep files"
echo "   • Disabled problematic geolocator packages for web compatibility"
echo "   • Updated netlify.toml to install npm dependencies"
echo "   • Configured functions directory path"
echo
echo "🚀 Next steps:"
echo "   1. Commit these changes to your repository"
echo "   2. Push to trigger Netlify deployment"
echo "   3. Monitor build logs for any remaining issues"