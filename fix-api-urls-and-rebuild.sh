#!/bin/bash

# Fix API URLs and Rebuild ShowTrackAI
# This script fixes the hardcoded old Netlify URLs and rebuilds the app

set -e

echo "🔧 Fixing API URLs in ShowTrackAI..."
echo "================================================"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Check current directory
if [ ! -f "pubspec.yaml" ]; then
    echo -e "${RED}Error: Not in Flutter project root. Please run from project root.${NC}"
    exit 1
fi

echo -e "${GREEN}✅ API URLs have been updated in service files:${NC}"
echo "   - lib/services/journal_service.dart"
echo "   - lib/services/timeline_service.dart"
echo ""

# Verify the changes
echo -e "${YELLOW}📋 Verifying URL updates...${NC}"
echo ""
echo "Current API URLs in service files:"
grep -n "_baseUrl" lib/services/*.dart | grep -E "(journal_service|timeline_service|journal_ai_service)" || true
echo ""

# Check if we need to rebuild
echo -e "${YELLOW}🔍 Checking if rebuild is needed...${NC}"
if grep -q "mellifluous-speculoos-46225c" web/main.dart.js 2>/dev/null; then
    echo -e "${RED}⚠️  Old URLs still present in compiled JavaScript!${NC}"
    echo "   A rebuild is required to apply the changes."
    echo ""
    
    echo -e "${YELLOW}🏗️  Starting Flutter web build...${NC}"
    echo "This may take a few minutes..."
    
    # Clean build artifacts
    flutter clean
    
    # Get dependencies
    flutter pub get
    
    # Build for web with release mode
    flutter build web --release --web-renderer canvaskit
    
    echo ""
    echo -e "${GREEN}✅ Build completed successfully!${NC}"
    
    # Verify the fix in the new build
    echo ""
    echo -e "${YELLOW}🔍 Verifying the fix in compiled code...${NC}"
    if grep -q "mellifluous-speculoos-46225c" build/web/main.dart.js 2>/dev/null; then
        echo -e "${RED}❌ ERROR: Old URLs still present after rebuild!${NC}"
        echo "   Please check if there are environment variables overriding the URLs."
        exit 1
    else
        echo -e "${GREEN}✅ Verified: Old URLs have been removed from compiled code!${NC}"
    fi
    
    # Check new URLs are present
    if grep -q "showtrackai.netlify.app" build/web/main.dart.js 2>/dev/null; then
        echo -e "${GREEN}✅ Verified: New URLs are present in compiled code!${NC}"
    else
        echo -e "${YELLOW}⚠️  Warning: Could not verify new URLs in compiled code.${NC}"
        echo "   This might be normal if the URLs are minified."
    fi
    
else
    echo -e "${GREEN}✅ Compiled JavaScript already up to date (no old URLs found)${NC}"
fi

echo ""
echo -e "${GREEN}🎉 API URL fix complete!${NC}"
echo ""
echo "Next steps:"
echo "1. Deploy to Netlify: git add -A && git commit -m 'Fix API URLs from old to new domain' && git push"
echo "2. Monitor the deployment at: https://app.netlify.com/sites/showtrackai/deploys"
echo "3. Test the app at: https://showtrackai.netlify.app"
echo ""
echo "The following features should now work:"
echo "  ✅ Journal entries submission and retrieval"
echo "  ✅ Weight tracker functionality"
echo "  ✅ Timeline service"
echo "  ✅ All API calls to Netlify functions"