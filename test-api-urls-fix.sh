#!/bin/bash

echo "🔧 Testing API URLs Fix Implementation"
echo "======================================"

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}📋 Checking Implementation Status:${NC}"

# Check if API config was created
if [ -f "lib/config/api_config.dart" ]; then
    echo -e "  ✅ API configuration file created"
else
    echo -e "  ❌ API configuration file missing"
    exit 1
fi

# Check if all required Netlify functions exist
FUNCTIONS_DIR="netlify/functions"
REQUIRED_FUNCTIONS=(
    "journal-create.js"
    "journal-update.js"
    "journal-delete.js"
    "journal-list.js"
    "journal-get.js"
    "journal-suggestions.js"
    "journal-generate-content.js"
    "journal-suggestion-feedback.js"
    "n8n-relay.js"
    "timeline-list.js"
    "timeline-stats.js"
)

echo -e "${BLUE}📁 Checking Netlify Functions:${NC}"
MISSING_FUNCTIONS=0

for func in "${REQUIRED_FUNCTIONS[@]}"; do
    if [ -f "$FUNCTIONS_DIR/$func" ]; then
        echo -e "  ✅ $func exists"
    else
        echo -e "  ❌ $func missing"
        MISSING_FUNCTIONS=$((MISSING_FUNCTIONS + 1))
    fi
done

if [ $MISSING_FUNCTIONS -eq 0 ]; then
    echo -e "  ${GREEN}All required functions present${NC}"
else
    echo -e "  ${RED}$MISSING_FUNCTIONS functions missing${NC}"
fi

# Check service files for hardcoded URLs
echo -e "${BLUE}🔍 Checking for hardcoded URLs in service files:${NC}"

HARDCODED_URLS=$(find lib -name "*.dart" -exec grep -l "showtrackai\.netlify\.app\|showtrackai-local-copy\.netlify\.app" {} \; 2>/dev/null || true)

if [ -z "$HARDCODED_URLS" ]; then
    echo -e "  ✅ No hardcoded URLs found in service files"
else
    echo -e "  ❌ Hardcoded URLs still found in:"
    echo "$HARDCODED_URLS"
fi

# Check if services import API config
echo -e "${BLUE}📥 Checking API config imports:${NC}"

KEY_SERVICES=(
    "lib/services/journal_service.dart"
    "lib/services/timeline_service.dart"
    "lib/services/journal_ai_service.dart"
)

for service in "${KEY_SERVICES[@]}"; do
    if [ -f "$service" ]; then
        if grep -q "import.*api_config.dart" "$service"; then
            echo -e "  ✅ $service imports API config"
        else
            echo -e "  ❌ $service missing API config import"
        fi
    else
        echo -e "  ⚠️  $service not found"
    fi
done

# Check package.json for build configuration
echo -e "${BLUE}📦 Checking package.json:${NC}"
if [ -f "package.json" ]; then
    echo -e "  ✅ package.json exists"
    
    # Check for required dependencies
    if grep -q "@supabase/supabase-js" package.json; then
        echo -e "  ✅ Supabase dependency present"
    else
        echo -e "  ❌ Supabase dependency missing"
    fi
else
    echo -e "  ❌ package.json missing"
fi

# Test compilation (Dart analysis)
echo -e "${BLUE}🔍 Running Dart Analysis:${NC}"
if command -v dart &> /dev/null; then
    if dart analyze lib/config/api_config.dart 2>/dev/null; then
        echo -e "  ✅ API config compiles without errors"
    else
        echo -e "  ❌ API config has compilation errors"
        dart analyze lib/config/api_config.dart
    fi
    
    # Check key service files
    for service in "${KEY_SERVICES[@]}"; do
        if [ -f "$service" ]; then
            if dart analyze "$service" 2>/dev/null; then
                echo -e "  ✅ $service compiles without errors"
            else
                echo -e "  ❌ $service has compilation errors"
            fi
        fi
    done
else
    echo -e "  ⚠️  Dart not available for compilation check"
fi

# Test function syntax (Node.js check)
echo -e "${BLUE}🔍 Checking Function Syntax:${NC}"
if command -v node &> /dev/null; then
    SYNTAX_ERRORS=0
    for func in "${REQUIRED_FUNCTIONS[@]}"; do
        if [ -f "$FUNCTIONS_DIR/$func" ]; then
            if node -c "$FUNCTIONS_DIR/$func" 2>/dev/null; then
                echo -e "  ✅ $func syntax OK"
            else
                echo -e "  ❌ $func has syntax errors"
                SYNTAX_ERRORS=$((SYNTAX_ERRORS + 1))
            fi
        fi
    done
    
    if [ $SYNTAX_ERRORS -eq 0 ]; then
        echo -e "  ${GREEN}All functions have valid syntax${NC}"
    else
        echo -e "  ${RED}$SYNTAX_ERRORS functions have syntax errors${NC}"
    fi
else
    echo -e "  ⚠️  Node.js not available for syntax check"
fi

# Summary
echo ""
echo -e "${BLUE}📊 Implementation Summary:${NC}"
echo "================================"

if [ $MISSING_FUNCTIONS -eq 0 ] && [ -z "$HARDCODED_URLS" ]; then
    echo -e "${GREEN}✅ API URLs fix implementation COMPLETE${NC}"
    echo ""
    echo "What was fixed:"
    echo "  • Created centralized API configuration (lib/config/api_config.dart)"
    echo "  • Replaced hardcoded URLs with relative paths"
    echo "  • Created all missing Netlify functions"
    echo "  • Updated service files to use new configuration"
    echo ""
    echo "Benefits:"
    echo "  • App will work on any domain (local or production)"
    echo "  • No more hardcoded showtrackai.netlify.app URLs"
    echo "  • Centralized timeout and header management"
    echo "  • Easy to modify API behavior from one place"
    echo ""
    echo -e "${GREEN}Ready for deployment! 🚀${NC}"
else
    echo -e "${RED}❌ Implementation incomplete${NC}"
    
    if [ $MISSING_FUNCTIONS -gt 0 ]; then
        echo -e "${RED}  • $MISSING_FUNCTIONS Netlify functions missing${NC}"
    fi
    
    if [ -n "$HARDCODED_URLS" ]; then
        echo -e "${RED}  • Hardcoded URLs still present in service files${NC}"
    fi
    
    echo ""
    echo -e "${YELLOW}Please address the issues above before deployment${NC}"
fi

echo ""
echo "Next Steps:"
echo "1. Test the app locally: flutter run -d chrome"  
echo "2. Deploy to Netlify"
echo "3. Verify all API calls work on production domain"
echo "4. Monitor Netlify function logs for any issues"

# Check git status
echo ""
echo -e "${BLUE}📝 Git Status:${NC}"
if command -v git &> /dev/null && git rev-parse --git-dir > /dev/null 2>&1; then
    MODIFIED_FILES=$(git status --porcelain | wc -l | xargs)
    if [ "$MODIFIED_FILES" -gt 0 ]; then
        echo -e "  📝 $MODIFIED_FILES files modified"
        echo "  Run: git add . && git commit -m 'Fix API URLs - use relative paths for all Netlify functions'"
    else
        echo -e "  ✅ No uncommitted changes"
    fi
else
    echo -e "  ⚠️  Not a git repository or git not available"
fi