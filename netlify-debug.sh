#!/usr/bin/env bash
# netlify-debug.sh
# Debug script for Flutter web deployment issues

set -e

echo "🔍 Flutter Web Deployment Debug Script"
echo "======================================"

# Check Flutter installation
echo "📋 Flutter Version:"
flutter --version || echo "❌ Flutter not found"

# Check web support
echo ""
echo "📋 Flutter Web Status:"
flutter config | grep -i web || echo "❌ Web support status unclear"

# Check build directory
echo ""
echo "📋 Build Directory Status:"
if [ -d "build/web" ]; then
    echo "✅ build/web exists"
    echo "📁 Build directory contents:"
    ls -la build/web/ | head -10
    
    # Check for critical files
    echo ""
    echo "📋 Critical Files Check:"
    
    files_to_check=(
        "build/web/index.html"
        "build/web/flutter.js"
        "build/web/flutter_bootstrap.js"
        "build/web/main.dart.js"
        "build/web/manifest.json"
    )
    
    for file in "${files_to_check[@]}"; do
        if [ -f "$file" ]; then
            size=$(ls -lh "$file" | awk '{print $5}')
            echo "✅ $file ($size)"
        else
            echo "❌ $file (missing)"
        fi
    done
    
    # Check for canvaskit
    if [ -d "build/web/canvaskit" ]; then
        echo "✅ canvaskit directory exists"
        echo "   Contents: $(ls build/web/canvaskit/ | wc -l) files"
    else
        echo "⚠️  canvaskit directory missing (may cause rendering issues)"
    fi
    
else
    echo "❌ build/web does not exist"
fi

# Environment variables check
echo ""
echo "📋 Environment Variables Check:"
required_vars=(
    "SUPABASE_URL"
    "SUPABASE_ANON_KEY" 
    "OPENWEATHER_API_KEY"
)

for var in "${required_vars[@]}"; do
    if [ -n "${!var}" ]; then
        echo "✅ $var is set"
    else
        echo "❌ $var is not set"
    fi
done

# Check pubspec.lock for potential issues
echo ""
echo "📋 Dependencies Check:"
if [ -f "pubspec.lock" ]; then
    echo "✅ pubspec.lock exists"
    
    # Check for problematic packages
    problematic_packages=("flutter_web_plugins" "js" "html")
    for pkg in "${problematic_packages[@]}"; do
        if grep -q "name: $pkg" pubspec.lock; then
            version=$(grep -A1 "name: $pkg" pubspec.lock | grep "version:" | awk '{print $2}' | tr -d '"')
            echo "📦 $pkg: $version"
        fi
    done
else
    echo "❌ pubspec.lock missing"
fi

# Check for CSP and CORS issues
echo ""
echo "📋 Configuration Files Check:"
if [ -f "netlify.toml" ]; then
    echo "✅ netlify.toml exists"
    if grep -q "Content-Security-Policy" netlify.toml; then
        echo "✅ CSP policy configured"
    else
        echo "⚠️  CSP policy not found"
    fi
    
    if grep -q "gstatic.com" netlify.toml; then
        echo "✅ gstatic.com allowed in CSP"
    else
        echo "❌ gstatic.com not in CSP (Flutter canvaskit will fail)"
    fi
else
    echo "❌ netlify.toml missing"
fi

# Web directory check
echo ""
echo "📋 Web Directory Check:"
if [ -d "web" ]; then
    echo "✅ web/ directory exists"
    
    # Check index.html
    if [ -f "web/index.html" ]; then
        echo "✅ web/index.html exists"
        
        if grep -q "flutterConfiguration" web/index.html; then
            echo "✅ Flutter configuration found in index.html"
        else
            echo "❌ Flutter configuration missing from index.html"
        fi
        
        if grep -q "canvasKitBaseUrl" web/index.html; then
            echo "✅ CanvasKit configuration found"
        else
            echo "❌ CanvasKit configuration missing"
        fi
    else
        echo "❌ web/index.html missing"
    fi
    
    # Check manifest
    if [ -f "web/manifest.json" ]; then
        echo "✅ web/manifest.json exists"
    else
        echo "❌ web/manifest.json missing"
    fi
else
    echo "❌ web/ directory missing"
fi

echo ""
echo "🔍 Debug complete. Check output above for issues."
echo ""

# Provide recommendations
echo "💡 Common Solutions:"
echo "1. If CanvasKit is failing: Check CSP allows *.gstatic.com"
echo "2. If environment vars missing: Set in Netlify dashboard"
echo "3. If build files missing: Run 'flutter clean && flutter build web --release'"
echo "4. If still failing: Try HTML renderer by adding --web-renderer html to build"

echo ""
echo "🌐 Test your live site CSP with:"
echo "curl -I https://your-site.netlify.app"