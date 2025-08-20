#!/bin/bash

# ShowTrackAI Geolocation Feature - Pull Request Creation Script
# This script helps you push the feature branch and create a PR

echo "=================================================="
echo "🚀 ShowTrackAI Geolocation Feature PR Setup"
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

# Get GitHub repository URL
echo "📝 Please provide your GitHub repository information:"
echo ""
read -p "GitHub username or organization: " GITHUB_USER
read -p "Repository name (e.g., showtrackai): " REPO_NAME

# Construct the repository URL
REPO_URL="https://github.com/${GITHUB_USER}/${REPO_NAME}.git"

echo ""
echo "Repository URL: $REPO_URL"
read -p "Is this correct? (y/n): " CONFIRM

if [ "$CONFIRM" != "y" ]; then
    echo "Exiting. Please run the script again with correct information."
    exit 1
fi

# Add remote origin
echo ""
echo "🔗 Adding remote origin..."
git remote add origin "$REPO_URL" 2>/dev/null || {
    echo -e "${YELLOW}Remote 'origin' already exists. Updating URL...${NC}"
    git remote set-url origin "$REPO_URL"
}

echo -e "${GREEN}✅ Remote configured${NC}"

# Push the feature branch
echo ""
echo "📤 Pushing feature branch to GitHub..."
echo "   This will push: feature/geolocation-journal-integration"
echo ""

git push -u origin feature/geolocation-journal-integration || {
    echo -e "${RED}❌ Push failed!${NC}"
    echo ""
    echo "Possible issues:"
    echo "1. Repository doesn't exist - Create it on GitHub first"
    echo "2. Authentication failed - Set up GitHub credentials"
    echo "3. Network issues - Check your connection"
    echo ""
    echo "To set up GitHub credentials:"
    echo "  - Using SSH: git remote set-url origin git@github.com:${GITHUB_USER}/${REPO_NAME}.git"
    echo "  - Using HTTPS with token: Use a Personal Access Token as password"
    exit 1
}

echo ""
echo -e "${GREEN}✅ Branch pushed successfully!${NC}"
echo ""
echo "=================================================="
echo "📋 Next Steps to Create Pull Request:"
echo "=================================================="
echo ""
echo "1. Open your browser and go to:"
echo "   ${YELLOW}https://github.com/${GITHUB_USER}/${REPO_NAME}${NC}"
echo ""
echo "2. You should see a banner saying:"
echo "   'feature/geolocation-journal-integration had recent pushes'"
echo "   Click the ${GREEN}'Compare & pull request'${NC} button"
echo ""
echo "3. Fill in the PR details:"
echo ""
echo "   ${YELLOW}Title:${NC} feat: Add comprehensive geolocation and weather tracking for journal entries"
echo ""
echo "   ${YELLOW}Description:${NC}"
cat << 'EOF'

## 🚀 Overview
This PR implements comprehensive geolocation and weather tracking capabilities for the ShowTrackAI journal feature, enabling location-aware agricultural activity tracking.

## ✨ Features Added
- 📍 **GPS Location Capture**: Automatic location detection with manual fallback
- 🌤️ **Weather Integration**: Real-time weather data from OpenWeatherMap
- 🗺️ **Reverse Geocoding**: Convert coordinates to human-readable addresses
- 🔒 **Privacy Controls**: Optional location tracking with user consent
- 📱 **Cross-Platform**: Full support for iOS, Android, and Web
- 🧪 **Testing Dashboard**: Interactive local testing interface

## 🔧 Technical Implementation

### Database Changes
- Added location fields (latitude, longitude, address, accuracy)
- Added weather fields (temperature, condition, humidity, wind speed)
- Created spatial indexes for efficient queries
- Added validation constraints

### Flutter Components
- `LocationService`: GPS capture and reverse geocoding
- `WeatherService`: Weather API integration with caching
- `LocationInputField`: UI widget for location capture
- Enhanced `JournalEntry` model with location/weather data

### Integration
- N8N webhook integration for data processing
- Netlify relay function for CORS handling
- Comprehensive error handling and fallbacks

## 📝 Documentation
- Deployment guide: `GEOLOCATION_DEPLOYMENT_GUIDE.md`
- Implementation review: `GEOLOCATION_IMPLEMENTATION_REVIEW.md`
- Local testing guide: `GEOLOCATION_LOCAL_TEST_GUIDE.md`

## 🧪 Testing
- Run local tests: `./test-local-geolocation.sh`
- Interactive dashboard: Open `geolocation-test-server.html`
- Python test server: `python3 start-test-server.py`

## 📸 Screenshots
[Add screenshots of the feature in action]

## ✅ Checklist
- [x] Code follows Flutter best practices
- [x] Database migration included
- [x] Tests created
- [x] Documentation updated
- [x] No .env files or secrets included
- [x] Cross-platform compatibility verified

## 🔄 Migration Notes
Run the Supabase migration before deployment:
```sql
-- Apply migration at: supabase/migrations/20250119_add_geolocation_weather_to_journal_entries.sql
```

## 🌟 Next Steps
After merging, configure the following in production:
1. Set OpenWeatherMap API key in environment variables
2. Run Supabase migration
3. Configure N8N webhook endpoint
4. Test on production environment

---
**Ready for review!** 🎉
EOF

echo ""
echo "4. Select reviewers and add labels:"
echo "   - Label: ${GREEN}enhancement${NC}"
echo "   - Label: ${GREEN}feature${NC}"
echo "   - Label: ${GREEN}ready-for-review${NC}"
echo ""
echo "5. Click ${GREEN}'Create pull request'${NC}"
echo ""
echo "=================================================="
echo ""
echo "Optional: Install GitHub CLI for easier PR creation:"
echo "  ${YELLOW}brew install gh${NC}"
echo "  ${YELLOW}gh auth login${NC}"
echo "  ${YELLOW}gh pr create --title \"feat: Add geolocation\" --body \"...\"${NC}"
echo ""
echo "=================================================="
echo "✨ Your feature branch is ready for PR creation!"
echo "=================================================="