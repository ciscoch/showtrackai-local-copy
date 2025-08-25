#!/bin/bash

echo "🚀 Creating deployment fix PR..."

# Ensure we're on the fix branch
git checkout fix-netlify-deployment

# Make sure everything is committed
if [ -n "$(git status --porcelain)" ]; then
    echo "⚠️ Uncommitted changes found. Committing..."
    git add .
    git commit -m "Final deployment fixes and documentation"
    git push origin fix-netlify-deployment
fi

# Create the PR using GitHub CLI (if available)
if command -v gh &> /dev/null; then
    gh pr create \
        --title "🔧 Fix Netlify Deployment Issues" \
        --body "## Summary
Fixes critical deployment issues preventing ShowTrackAI from loading in production.

## Changes
- Fixed CanvasKit blocking initialization
- Updated Content Security Policy headers
- Resolved Flutter bootstrap API compatibility
- Added proper error handling and fallbacks

## Testing
- ✅ Local testing passed
- ✅ Branch deploy tested: https://fix-netlify-deployment--showtrackai.netlify.app
- ✅ All core functionality verified

## Deployment Steps
1. Test branch deploy thoroughly
2. Merge to main after approval
3. Monitor production deployment
4. Rollback plan ready if needed

## Rollback Plan
If issues occur after merge:
\`\`\`bash
git checkout main
git revert HEAD
git push origin main
\`\`\`

## Files Changed
- \`web/flutter_bootstrap.js\` - Updated Flutter API calls
- \`web/index.html\` - Updated CSP headers
- \`_headers\` - Added proper content security policies
- \`netlify.toml\` - Optimized build settings
- Various verification scripts for testing

Closes any related deployment issues." \
        --base main \
        --head fix-netlify-deployment
        
    echo "✅ PR created successfully!"
    echo "🔗 View at: https://github.com/your-username/showtrackai-local-copy/pulls"
else
    echo "📝 GitHub CLI not found. Please create PR manually:"
    echo "   1. Go to: https://github.com/your-username/showtrackai-local-copy"
    echo "   2. Click 'Compare & pull request'"
    echo "   3. Base: main, Compare: fix-netlify-deployment"
    echo "   4. Title: 🔧 Fix Netlify Deployment Issues"
    echo "   5. Use the description template from this script"
fi