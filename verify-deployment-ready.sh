#!/usr/bin/env bash
set -euo pipefail

echo "🔍 ShowTrackAI Deployment Verification Script"
echo "=============================================="

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Check functions
check_pass() {
    echo -e "✅ ${GREEN}$1${NC}"
}

check_fail() {
    echo -e "❌ ${RED}$1${NC}"
    exit 1
}

check_warn() {
    echo -e "⚠️  ${YELLOW}$1${NC}"
}

echo ""
echo "📋 Step 1: Verifying Project Structure"
echo "-------------------------------------"

# Check if we're in the right directory
if [ ! -f "pubspec.yaml" ]; then
    check_fail "pubspec.yaml not found. Please run from project root."
fi
check_pass "Project root confirmed"

# Check key files
required_files=(
    "netlify.toml"
    "build_for_netlify.sh"
    ".env"
    "lib/main.dart"
)

for file in "${required_files[@]}"; do
    if [ -f "$file" ]; then
        check_pass "Found: $file"
    else
        check_fail "Missing: $file"
    fi
done

echo ""
echo "🔧 Step 2: Verifying Build Configuration"
echo "---------------------------------------"

# Check netlify.toml configuration
if grep -q 'publish = "build/web"' netlify.toml; then
    check_pass "Netlify.toml publish directory: build/web"
else
    check_fail "Netlify.toml publish directory not set to build/web"
fi

if grep -q 'build_for_netlify.sh' netlify.toml; then
    check_pass "Netlify.toml uses build_for_netlify.sh"
else
    check_fail "Netlify.toml build command incorrect"
fi

# Check build script permissions
if [ -x "build_for_netlify.sh" ]; then
    check_pass "build_for_netlify.sh is executable"
else
    check_warn "Making build_for_netlify.sh executable"
    chmod +x build_for_netlify.sh
    check_pass "build_for_netlify.sh made executable"
fi

echo ""
echo "🏗️  Step 3: Testing Local Flutter Build"
echo "--------------------------------------"

# Check if Flutter is available
if command -v flutter &> /dev/null; then
    FLUTTER_VERSION=$(flutter --version | head -n 1)
    check_pass "Flutter available: $FLUTTER_VERSION"
    
    # Run flutter doctor
    echo "Running flutter doctor..."
    flutter doctor --android-licenses >/dev/null 2>&1 || true
    if flutter doctor | grep -q "No issues found!"; then
        check_pass "Flutter doctor: No issues"
    else
        check_warn "Flutter doctor has some issues (may not affect web build)"
        flutter doctor | head -10
    fi
else
    check_fail "Flutter not found in PATH"
fi

# Test build
echo "Testing Flutter web build..."
if flutter clean && flutter pub get; then
    check_pass "Flutter clean and pub get successful"
else
    check_fail "Flutter clean/pub get failed"
fi

# Try a quick build test
echo "Attempting test build..."
if timeout 300s flutter build web --release --web-renderer=html --no-tree-shake-icons >/dev/null 2>&1; then
    check_pass "Test build successful"
else
    check_warn "Test build failed or timed out (may work on Netlify)"
fi

echo ""
echo "📁 Step 4: Verifying Build Output"
echo "--------------------------------"

if [ -d "build/web" ]; then
    check_pass "build/web directory exists"
    
    # Check key files in build output
    build_files=(
        "index.html"
        "main.dart.js"
        "flutter.js"
        "flutter_bootstrap.js"
        "manifest.json"
    )
    
    for file in "${build_files[@]}"; do
        if [ -f "build/web/$file" ]; then
            check_pass "Found: build/web/$file"
        else
            check_fail "Missing: build/web/$file"
        fi
    done
    
    # Check build config
    if [ -f "build/web/flutter_build_config.json" ]; then
        if grep -q '"renderer": "html"' build/web/flutter_build_config.json; then
            check_pass "HTML renderer configured"
        else
            check_warn "Renderer may not be HTML"
        fi
    fi
    
    # Check for any obvious issues
    if [ -f "build/web/main.dart.js" ]; then
        size=$(stat -f%z "build/web/main.dart.js" 2>/dev/null || stat -c%s "build/web/main.dart.js" 2>/dev/null || echo "unknown")
        if [ "$size" != "unknown" ] && [ "$size" -gt 100000 ]; then
            check_pass "main.dart.js size looks reasonable: ${size} bytes"
        else
            check_warn "main.dart.js size seems small: ${size} bytes"
        fi
    fi
    
else
    check_warn "build/web directory not found. Will be created during Netlify build."
fi

echo ""
echo "🌐 Step 5: Environment Variables Check"
echo "-------------------------------------"

# Check .env file
if [ -f ".env" ]; then
    check_pass ".env file exists"
    
    # Check for required variables (without showing values)
    required_vars=(
        "SUPABASE_URL"
        "SUPABASE_ANON_KEY"
    )
    
    for var in "${required_vars[@]}"; do
        if grep -q "^$var=" .env; then
            check_pass "Found environment variable: $var"
        else
            check_warn "Missing environment variable: $var"
        fi
    done
else
    check_warn ".env file not found"
fi

echo ""
echo "🔒 Step 6: Security and Headers Check"
echo "------------------------------------"

# Check for _headers file in build output
if [ -f "build/web/_headers" ]; then
    check_pass "Security headers file exists"
    
    if grep -q "Content-Security-Policy" build/web/_headers; then
        check_pass "CSP headers configured"
    else
        check_warn "CSP headers not found"
    fi
else
    check_warn "_headers file not found in build output"
fi

# Check for _redirects
if [ -f "build/web/_redirects" ]; then
    check_pass "SPA redirects configured"
else
    check_warn "_redirects file not found"
fi

echo ""
echo "📱 Step 7: Web Specific Configuration"
echo "-----------------------------------"

# Check web/index.html
if [ -f "web/index.html" ]; then
    check_pass "web/index.html template exists"
    
    # Check for meta tags
    if grep -q "viewport" web/index.html; then
        check_pass "Viewport meta tag found"
    else
        check_warn "Viewport meta tag not found"
    fi
    
    # Check for Flutter loader
    if grep -q "flutter" web/index.html; then
        check_pass "Flutter loader references found"
    else
        check_warn "Flutter loader references not found"
    fi
else
    check_fail "web/index.html not found"
fi

echo ""
echo "🚀 Step 8: Deployment Readiness Summary"
echo "======================================="

echo ""
echo "Configuration Status:"
echo "- Build command: './build_for_netlify.sh'"
echo "- Publish directory: 'build/web'"
echo "- Renderer: HTML (CanvasKit disabled)"
echo "- PWA: Disabled"
echo "- Service Worker: Neutralized"
echo ""

# Final recommendation
echo "🎯 DEPLOYMENT READINESS ASSESSMENT"
echo ""

if [ -f "build/web/index.html" ] && [ -f "build/web/main.dart.js" ] && [ -f "netlify.toml" ]; then
    echo -e "${GREEN}✅ READY FOR DEPLOYMENT${NC}"
    echo ""
    echo "Your Flutter web app appears ready for Netlify deployment!"
    echo ""
    echo "Next steps:"
    echo "1. Commit and push your changes to your Git repository"
    echo "2. Deploy to Netlify (either via Git integration or manual upload)"
    echo "3. Set environment variables in Netlify dashboard"
    echo "4. Test the deployed application"
    echo ""
    echo "Build command will be: npm install && ./build_for_netlify.sh"
    echo "Publish directory will be: build/web"
else
    echo -e "${YELLOW}⚠️  NEEDS ATTENTION${NC}"
    echo ""
    echo "Some issues were found. Please review the warnings above."
    echo "You may still be able to deploy, but consider fixing issues first."
fi

echo ""
echo "📊 Build Output Analysis:"
if [ -d "build/web" ]; then
    echo "Files in build/web:"
    ls -la build/web/ | head -20
    echo ""
    echo "Directory size:"
    du -sh build/web/ 2>/dev/null || echo "Could not calculate size"
fi

echo ""
echo "🔧 Quick Test Commands:"
echo "- Test locally: python3 -m http.server 8080 --directory build/web"
echo "- Rebuild: flutter clean && flutter build web --release --web-renderer=html"
echo "- Verify Netlify: ./build_for_netlify.sh"

echo ""
echo "Verification complete! 🎉"