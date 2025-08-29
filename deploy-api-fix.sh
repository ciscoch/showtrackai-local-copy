#!/bin/bash

echo "🚀 Deploying API URLs Fix to Production"
echo "======================================"

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Check if we're in a git repository
if ! git rev-parse --git-dir > /dev/null 2>&1; then
    echo -e "${RED}❌ Not in a git repository${NC}"
    exit 1
fi

# Check if there are uncommitted changes
MODIFIED_FILES=$(git status --porcelain | wc -l | xargs)
if [ "$MODIFIED_FILES" -eq 0 ]; then
    echo -e "${YELLOW}⚠️  No modified files to commit${NC}"
    echo "Either changes are already committed or no changes were made."
    
    # Ask if user wants to proceed anyway
    read -p "Do you want to push current branch to trigger deployment? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "Deployment cancelled."
        exit 0
    fi
else
    echo -e "${BLUE}📁 Found $MODIFIED_FILES modified files${NC}"
    
    # Show modified files
    echo "Modified files:"
    git status --porcelain | head -10
    if [ "$MODIFIED_FILES" -gt 10 ]; then
        echo "... and $(($MODIFIED_FILES - 10)) more files"
    fi
    echo
    
    # Ask for confirmation
    read -p "Commit and deploy these changes? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "Deployment cancelled."
        exit 0
    fi
    
    echo -e "${BLUE}📝 Staging all changes...${NC}"
    git add .
    
    echo -e "${BLUE}💾 Committing changes...${NC}"
    git commit -m "Fix API URLs - use relative paths for all Netlify functions

- Create centralized API configuration (lib/config/api_config.dart)
- Add missing Netlify functions for journal and timeline operations  
- Update service files to use relative URLs instead of hardcoded domains
- Implement proper CORS, auth, and error handling in all functions
- Add trace ID support for better debugging

This fixes the issue where the app was calling hardcoded showtrackai.netlify.app
URLs that no longer work. Now all API calls use relative paths that work on any domain.

Resolves API 404 errors and enables proper functionality on production domain."
    
    if [ $? -ne 0 ]; then
        echo -e "${RED}❌ Failed to commit changes${NC}"
        exit 1
    fi
    
    echo -e "${GREEN}✅ Changes committed successfully${NC}"
fi

# Get current branch
CURRENT_BRANCH=$(git branch --show-current)
echo -e "${BLUE}📡 Pushing to branch: $CURRENT_BRANCH${NC}"

# Push to remote
git push origin "$CURRENT_BRANCH"

if [ $? -ne 0 ]; then
    echo -e "${RED}❌ Failed to push to remote repository${NC}"
    echo "Please check your git configuration and network connection."
    exit 1
fi

echo -e "${GREEN}✅ Successfully pushed to remote repository${NC}"
echo

echo -e "${BLUE}🏗️  Netlify Deployment Status${NC}"
echo "============================="
echo "Your changes have been pushed and will trigger a new Netlify build."
echo
echo "What's happening now:"
echo "1. 🔄 Netlify detected the git push"
echo "2. 🏗️  Starting new build with updated functions"
echo "3. 🚀 Deploying to production domain"
echo "4. ✅ API URLs will now work correctly"
echo

echo -e "${YELLOW}📋 Monitoring Steps:${NC}"
echo "1. Check Netlify dashboard for build status"
echo "2. Test app functionality at: https://showtrackai.netlify.app"  
echo "3. Monitor function logs in Netlify dashboard"
echo "4. Verify all API calls work correctly"
echo

echo -e "${BLUE}🧪 Quick Tests After Deployment:${NC}"
echo "================================="
echo "Test these URLs once deployment completes:"
echo
echo "1. App loads: https://showtrackai.netlify.app"
echo "2. Journal functions:"
echo "   curl -H 'Authorization: Bearer TOKEN' https://showtrackai.netlify.app/.netlify/functions/journal-list"
echo "3. Timeline functions:"  
echo "   curl -H 'Authorization: Bearer TOKEN' https://showtrackai.netlify.app/.netlify/functions/timeline-list"
echo

echo -e "${GREEN}🎉 Deployment initiated successfully!${NC}"
echo
echo "The API URLs fix should resolve the following issues:"
echo "✅ No more 404 errors on API calls"
echo "✅ App works correctly on production domain"
echo "✅ All journal and timeline operations functional"
echo "✅ Better error handling and debugging"
echo
echo -e "${BLUE}Next: Monitor the deployment and test the app once it's live.${NC}"

# Get git remote URL for reference
REMOTE_URL=$(git remote get-url origin 2>/dev/null || echo "No remote configured")
echo
echo "Git remote: $REMOTE_URL"
echo "Branch pushed: $CURRENT_BRANCH"
echo "Commit hash: $(git rev-parse --short HEAD)"