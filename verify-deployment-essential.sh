#!/usr/bin/env bash
set -euo pipefail

echo "🚀 ShowTrackAI Essential Deployment Check"
echo "=========================================="

# Color codes
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

check_pass() { echo -e "✅ ${GREEN}$1${NC}"; }
check_fail() { echo -e "❌ ${RED}$1${NC}"; exit 1; }
check_warn() { echo -e "⚠️  ${YELLOW}$1${NC}"; }

echo ""
echo "1️⃣ Essential Files Check"
echo "------------------------"

# Check critical files
if [ -f "netlify.toml" ]; then check_pass "netlify.toml exists"; else check_fail "netlify.toml missing"; fi
if [ -f "build_for_netlify.sh" ]; then check_pass "build_for_netlify.sh exists"; else check_fail "build script missing"; fi
if [ -f "pubspec.yaml" ]; then check_pass "pubspec.yaml exists"; else check_fail "Not a Flutter project"; fi
if [ -f ".env" ]; then check_pass ".env file exists"; else check_warn ".env file missing"; fi

echo ""
echo "2️⃣ Configuration Check"
echo "----------------------"

# Check netlify.toml settings
if grep -q 'publish = "build/web"' netlify.toml; then
    check_pass "Publish directory: build/web"
else
    check_fail "Wrong publish directory in netlify.toml"
fi

if grep -q 'build_for_netlify.sh' netlify.toml; then
    check_pass "Build script configured"
else
    check_fail "Build command not set correctly"
fi

# Check build script is executable
if [ -x "build_for_netlify.sh" ]; then
    check_pass "Build script is executable"
else
    chmod +x build_for_netlify.sh
    check_pass "Made build script executable"
fi

echo ""
echo "3️⃣ Build Output Check"
echo "---------------------"

if [ -d "build/web" ]; then
    check_pass "build/web directory exists"
    
    # Check essential build files
    if [ -f "build/web/index.html" ]; then check_pass "index.html present"; else check_fail "index.html missing"; fi
    if [ -f "build/web/main.dart.js" ]; then check_pass "main.dart.js present"; else check_fail "main.dart.js missing"; fi
    if [ -f "build/web/flutter.js" ]; then check_pass "flutter.js present"; else check_fail "flutter.js missing"; fi
    
    # Check build config
    if [ -f "build/web/flutter_build_config.json" ]; then
        if grep -q '"renderer": "html"' build/web/flutter_build_config.json; then
            check_pass "HTML renderer configured"
        else
            check_warn "Build config may not use HTML renderer"
        fi
    fi
    
    # Check file sizes
    if [ -f "build/web/main.dart.js" ]; then
        size=$(stat -f%z "build/web/main.dart.js" 2>/dev/null || stat -c%s "build/web/main.dart.js" 2>/dev/null || echo "0")
        if [ "$size" -gt 50000 ]; then
            check_pass "main.dart.js size looks good: $(echo $size | numfmt --to=iec)B"
        else
            check_warn "main.dart.js seems small: ${size}B"
        fi
    fi
else
    check_warn "No build/web directory found - will be created during deployment"
fi

echo ""
echo "4️⃣ Environment Variables"
echo "------------------------"

if [ -f ".env" ]; then
    if grep -q "SUPABASE_URL=" .env; then check_pass "SUPABASE_URL configured"; else check_warn "SUPABASE_URL not found"; fi
    if grep -q "SUPABASE_ANON_KEY=" .env; then check_pass "SUPABASE_ANON_KEY configured"; else check_warn "SUPABASE_ANON_KEY not found"; fi
fi

echo ""
echo "5️⃣ Web Configuration"
echo "--------------------"

if [ -f "web/index.html" ]; then
    check_pass "web/index.html template exists"
    if grep -q "viewport" web/index.html; then check_pass "Viewport meta tag found"; fi
else
    check_fail "web/index.html template missing"
fi

echo ""
echo "🎯 DEPLOYMENT STATUS"
echo "==================="

# Final assessment
build_ready=true

if [ ! -f "netlify.toml" ] || [ ! -f "build_for_netlify.sh" ] || [ ! -f "pubspec.yaml" ]; then
    build_ready=false
fi

if [ "$build_ready" = true ]; then
    echo -e "${GREEN}"
    echo "✅ READY FOR NETLIFY DEPLOYMENT"
    echo -e "${NC}"
    echo ""
    echo "Your configuration looks good! Here's what will happen on Netlify:"
    echo ""
    echo "1. Netlify will run: npm install && ./build_for_netlify.sh"
    echo "2. Build script will install Flutter and build for web"  
    echo "3. Output will be published from: build/web/"
    echo "4. HTML renderer will be used (better compatibility)"
    echo "5. Service worker will be neutralized (avoids caching issues)"
    echo ""
    echo "Next steps:"
    echo "- Push your code to your Git repository"
    echo "- Set up Netlify deployment (connect to your repo)" 
    echo "- Configure environment variables in Netlify dashboard"
    echo "- Deploy and test!"
    
else
    echo -e "${RED}"
    echo "❌ NOT READY - Fix issues above first"
    echo -e "${NC}"
fi

echo ""
echo "📊 Current Build Stats:"
if [ -d "build/web" ]; then
    echo "Build files:"
    ls -la build/web/ | head -10
    echo ""
    total_size=$(du -sh build/web 2>/dev/null | cut -f1 || echo "unknown")
    echo "Total build size: $total_size"
fi

echo ""
echo "🔧 Quick Commands:"
echo "- Test build: ./build_for_netlify.sh"
echo "- Local server: python3 -m http.server 8080 --directory build/web"
echo "- Clean rebuild: flutter clean && flutter build web --release --web-renderer=html"

echo ""
echo "Done! 🎉"