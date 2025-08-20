#!/bin/bash

# ShowTrackAI Geolocation Feature - Direct Push Script
# This script helps you push the feature branch to GitHub

echo "=================================================="
echo "🚀 ShowTrackAI Geolocation Feature - Push to GitHub"
echo "=================================================="
echo ""

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Check if we're on the correct branch
CURRENT_BRANCH=$(git branch --show-current)
if [ "$CURRENT_BRANCH" != "feature/geolocation-journal-integration" ]; then
    echo -e "${RED}❌ Not on the feature branch!${NC}"
    echo "   Current branch: $CURRENT_BRANCH"
    echo "   Expected: feature/geolocation-journal-integration"
    exit 1
fi

echo -e "${GREEN}✅ On feature branch: $CURRENT_BRANCH${NC}"
echo ""

# Show current commits
echo "📋 Commits ready to push:"
echo "------------------------"
git log --oneline -5
echo ""

# Common GitHub repository URLs
echo "🔗 Choose your GitHub repository setup:"
echo ""
echo "1) francisco/showtrackai"
echo "2) francisco/ShowTrackAI"
echo "3) Custom repository"
echo ""
read -p "Select option (1-3): " OPTION

case $OPTION in
    1)
        GITHUB_USER="francisco"
        REPO_NAME="showtrackai"
        ;;
    2)
        GITHUB_USER="francisco"
        REPO_NAME="ShowTrackAI"
        ;;
    3)
        read -p "GitHub username: " GITHUB_USER
        read -p "Repository name: " REPO_NAME
        ;;
    *)
        echo "Invalid option"
        exit 1
        ;;
esac

# Try different remote URL formats
echo ""
echo "📡 Setting up remote..."

# Check if origin exists
if git remote | grep -q "^origin$"; then
    echo -e "${YELLOW}Remote 'origin' exists. Updating...${NC}"
    git remote remove origin
fi

# Let user choose authentication method
echo ""
echo "🔐 Choose authentication method:"
echo "1) HTTPS (username/password or token)"
echo "2) SSH (recommended if configured)"
echo ""
read -p "Select option (1-2): " AUTH_METHOD

if [ "$AUTH_METHOD" == "2" ]; then
    REPO_URL="git@github.com:${GITHUB_USER}/${REPO_NAME}.git"
    echo "Using SSH: $REPO_URL"
else
    REPO_URL="https://github.com/${GITHUB_USER}/${REPO_NAME}.git"
    echo "Using HTTPS: $REPO_URL"
fi

# Add remote
git remote add origin "$REPO_URL"
echo -e "${GREEN}✅ Remote configured${NC}"

# Push the branch
echo ""
echo "📤 Pushing to GitHub..."
echo "   Branch: feature/geolocation-journal-integration"
echo ""

if git push -u origin feature/geolocation-journal-integration; then
    echo ""
    echo -e "${GREEN}✅ Successfully pushed to GitHub!${NC}"
    echo ""
    echo "=================================================="
    echo "📋 Next Steps to Create Pull Request:"
    echo "=================================================="
    echo ""
    echo "1. Open your browser and go to:"
    echo "   ${YELLOW}https://github.com/${GITHUB_USER}/${REPO_NAME}${NC}"
    echo ""
    echo "2. You should see a yellow banner:"
    echo "   'feature/geolocation-journal-integration had recent pushes'"
    echo "   Click the ${GREEN}'Compare & pull request'${NC} button"
    echo ""
    echo "3. Use this PR title:"
    echo "   ${YELLOW}feat: Add comprehensive geolocation and weather tracking for journal entries${NC}"
    echo ""
    echo "4. The PR description template is ready in create-pr.sh"
    echo ""
    echo "=================================================="
    echo "✨ Your feature is ready for review!"
    echo "=================================================="
else
    echo ""
    echo -e "${RED}❌ Push failed!${NC}"
    echo ""
    echo "Troubleshooting:"
    echo ""
    echo "1. If repository doesn't exist:"
    echo "   - Go to https://github.com/new"
    echo "   - Create repository named: ${REPO_NAME}"
    echo "   - Make it private or public as needed"
    echo "   - DON'T initialize with README"
    echo ""
    echo "2. If authentication failed:"
    echo ""
    echo "   For HTTPS (with Personal Access Token):"
    echo "   - Go to: https://github.com/settings/tokens"
    echo "   - Generate new token with 'repo' scope"
    echo "   - Use token as password when prompted"
    echo ""
    echo "   For SSH:"
    echo "   - Check SSH key: ssh -T git@github.com"
    echo "   - Add SSH key: https://github.com/settings/keys"
    echo ""
    echo "3. Try manual push:"
    echo "   git push -u origin feature/geolocation-journal-integration"
    echo ""
fi