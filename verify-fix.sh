#!/bin/bash

# Flutter Initialization Fix Verification Script
# Checks if the duplicate initialization safeguards are properly implemented

echo "🔍 Verifying Flutter initialization fix..."

# Check if build directory exists
if [ ! -d "build/web" ]; then
    echo "❌ build/web directory not found. Run './build-fixed.sh' first."
    exit 1
fi

echo ""
echo "1️⃣  Checking required files..."

# Check for required files
REQUIRED_FILES=(
    "build/web/index.html"
    "build/web/flutter_bootstrap.js"
    "build/web/flutter.js"
    "build/web/main.dart.js"
)

ALL_FILES_EXIST=true

for file in "${REQUIRED_FILES[@]}"; do
    if [ -f "$file" ]; then
        echo "✅ $file"
    else
        echo "❌ $file - Missing!"
        ALL_FILES_EXIST=false
    fi
done

if [ "$ALL_FILES_EXIST" = false ]; then
    echo "❌ Required files missing. Please run './build-fixed.sh'"
    exit 1
fi

echo ""
echo "2️⃣  Checking safeguard implementation..."

# Check index.html for safeguard system
if grep -q "Flutter Initialization Safeguard System" build/web/index.html; then
    echo "✅ Index.html safeguard system - Found"
else
    echo "❌ Index.html safeguard system - Missing!"
    exit 1
fi

if grep -q "initializeFlutterSafely" build/web/index.html; then
    echo "✅ Index.html safeguard function - Found"
else
    echo "❌ Index.html safeguard function - Missing!"
    exit 1
fi

# Check flutter_bootstrap.js for safeguards
if grep -q "Flutter Bootstrap Initialization Safeguard" build/web/flutter_bootstrap.js; then
    echo "✅ Bootstrap safeguard system - Found"
else
    echo "❌ Bootstrap safeguard system - Missing!"
    exit 1
fi

if grep -q "initializeFlutterSafely" build/web/flutter_bootstrap.js; then
    echo "✅ Bootstrap safeguard usage - Found"
else
    echo "❌ Bootstrap safeguard usage - Missing!"
    exit 1
fi

echo ""
echo "3️⃣  Checking HTML renderer configuration..."

# Check for HTML renderer in configuration
if grep -q '"renderer": "html"' build/web/flutter_bootstrap.js; then
    echo "✅ HTML renderer forced - Confirmed"
elif grep -q '"renderer":"html"' build/web/flutter_bootstrap.js; then
    echo "✅ HTML renderer forced - Confirmed (no spaces)"
else
    echo "⚠️  HTML renderer - Cannot verify automatically"
    echo "   Please check flutter_bootstrap.js manually for 'renderer' setting"
fi

# Check for CanvasKit prevention
if grep -q "flutterConfiguration" build/web/index.html; then
    echo "✅ Flutter configuration - Found"
else
    echo "❌ Flutter configuration - Missing!"
fi

echo ""
echo "4️⃣  Checking console logging setup..."

# Check for proper logging
if grep -q "console.log.*Flutter Init" build/web/index.html; then
    echo "✅ Index.html initialization logging - Found"
else
    echo "❌ Index.html initialization logging - Missing!"
fi

if grep -q "console.log.*Flutter Bootstrap" build/web/flutter_bootstrap.js; then
    echo "✅ Bootstrap initialization logging - Found"
else
    echo "❌ Bootstrap initialization logging - Missing!"
fi

echo ""
echo "5️⃣  Checking state management..."

# Check for state management
if grep -q "flutterInitializationState" build/web/index.html; then
    echo "✅ Initialization state management - Found"
else
    echo "❌ Initialization state management - Missing!"
fi

# Check for state usage in bootstrap
if grep -q "flutterInitializationState" build/web/flutter_bootstrap.js; then
    echo "✅ Bootstrap state integration - Found"
else
    echo "❌ Bootstrap state integration - Missing!"
fi

echo ""
echo "6️⃣  Checking file sizes..."

# Check file sizes (should be reasonable)
INDEX_SIZE=$(stat -f%z build/web/index.html 2>/dev/null || stat -c%s build/web/index.html 2>/dev/null)
BOOTSTRAP_SIZE=$(stat -f%z build/web/flutter_bootstrap.js 2>/dev/null || stat -c%s build/web/flutter_bootstrap.js 2>/dev/null)

if [ "$INDEX_SIZE" -gt 5000 ] && [ "$INDEX_SIZE" -lt 15000 ]; then
    echo "✅ Index.html size reasonable: ${INDEX_SIZE} bytes"
else
    echo "⚠️  Index.html size: ${INDEX_SIZE} bytes (may be unusual)"
fi

if [ "$BOOTSTRAP_SIZE" -gt 10000 ] && [ "$BOOTSTRAP_SIZE" -lt 25000 ]; then
    echo "✅ Bootstrap.js size reasonable: ${BOOTSTRAP_SIZE} bytes"
else
    echo "⚠️  Bootstrap.js size: ${BOOTSTRAP_SIZE} bytes (may be unusual)"
fi

echo ""
echo "📊 VERIFICATION SUMMARY"
echo "======================="

# Count checks
TOTAL_CHECKS=0
PASSED_CHECKS=0

# Re-run checks and count
CHECKS=(
    "grep -q 'Flutter Initialization Safeguard System' build/web/index.html"
    "grep -q 'initializeFlutterSafely' build/web/index.html"
    "grep -q 'Flutter Bootstrap Initialization Safeguard' build/web/flutter_bootstrap.js"
    "grep -q 'initializeFlutterSafely' build/web/flutter_bootstrap.js"
    "grep -q 'flutterConfiguration' build/web/index.html"
    "grep -q 'console.log.*Flutter Init' build/web/index.html"
    "grep -q 'console.log.*Flutter Bootstrap' build/web/flutter_bootstrap.js"
    "grep -q 'flutterInitializationState' build/web/index.html"
)

for check in "${CHECKS[@]}"; do
    TOTAL_CHECKS=$((TOTAL_CHECKS + 1))
    if eval "$check" > /dev/null 2>&1; then
        PASSED_CHECKS=$((PASSED_CHECKS + 1))
    fi
done

echo "Checks passed: $PASSED_CHECKS / $TOTAL_CHECKS"

if [ "$PASSED_CHECKS" -eq "$TOTAL_CHECKS" ]; then
    echo "✅ ALL CHECKS PASSED!"
    echo ""
    echo "🚀 Flutter initialization fix is properly implemented!"
    echo ""
    echo "Next steps:"
    echo "1. Test locally: python3 -m http.server 8080 --directory build/web"
    echo "2. Check browser console for initialization logs"
    echo "3. Test route navigation (especially /#/login)"
    echo "4. Deploy to production when satisfied"
    echo ""
    echo "Expected console output:"
    echo "  [Flutter Init] Attempt to initialize via flutter_bootstrap.js"
    echo "  [Flutter Init] Starting initialization via flutter_bootstrap.js"
    echo "  [Flutter Bootstrap] Using main safeguard system"
    echo "  [Flutter Init] Completed via flutter_bootstrap.js"
else
    echo "❌ Some checks failed!"
    echo ""
    echo "To fix issues:"
    echo "1. Run './build-fixed.sh' to rebuild with safeguards"
    echo "2. If problems persist, check the build scripts"
    echo "3. Verify no manual edits conflicted with safeguards"
    echo ""
    echo "For help, check FLUTTER_INITIALIZATION_FIX.md"
fi

echo ""
echo "📁 Related files:"
echo "   - build/web/index.html (main safeguard system)"
echo "   - build/web/flutter_bootstrap.js (bootstrap safeguards)"  
echo "   - fix-flutter-bootstrap.sh (fix script)"
echo "   - build-fixed.sh (build script)"
echo "   - FLUTTER_INITIALIZATION_FIX.md (documentation)"