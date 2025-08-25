#!/bin/bash

echo "🔀 Starting safe merge to main..."

# Verify we're ready to merge
if [ ! -f "pre-merge-verification.sh" ]; then
    echo "❌ Pre-merge verification script not found"
    echo "Please run pre-merge verification first"
    exit 1
fi

read -p "Have you run ./pre-merge-verification.sh successfully? (y/n): " verified
if [ "$verified" != "y" ]; then
    echo "Please run ./pre-merge-verification.sh first"
    exit 1
fi

# 1. Create rollback point
echo "1. Creating rollback point..."
git checkout main
git pull origin main

ROLLBACK_COMMIT=$(git rev-parse HEAD)
ROLLBACK_DATE=$(date +"%Y-%m-%d_%H-%M-%S")
echo "📍 Rollback point: $ROLLBACK_COMMIT"
echo "🕐 Rollback date: $ROLLBACK_DATE"

# 2. Create rollback script
echo "2. Creating rollback script..."
cat > rollback-deployment.sh << EOL
#!/bin/bash
echo "🔄 Rolling back to previous main..."
echo "Rollback point: $ROLLBACK_COMMIT"
echo "Rollback date: $ROLLBACK_DATE"

read -p "Are you sure you want to rollback? (y/n): " confirm
if [ "\$confirm" = "y" ]; then
    git checkout main
    git reset --hard $ROLLBACK_COMMIT
    git push --force origin main
    echo "✅ Rollback completed to commit: $ROLLBACK_COMMIT"
    echo "🚨 Production site reverted to previous working version"
else
    echo "Rollback cancelled"
fi
EOL
chmod +x rollback-deployment.sh

# 3. Create alternative rollback using revert
cat > rollback-with-revert.sh << EOL
#!/bin/bash
echo "🔄 Rolling back using git revert (safer option)..."

git checkout main
git revert HEAD --no-edit
git push origin main

echo "✅ Rollback completed using revert"
echo "This creates a new commit that undoes the merge"
EOL
chmod +x rollback-with-revert.sh

# 4. Show current status
echo "3. Current status before merge..."
echo "📊 Main branch commits:"
git log --oneline -3 main

echo ""
echo "📊 Fix branch commits:"
git log --oneline -3 fix-netlify-deployment

echo ""
echo "📊 Files that will be merged:"
git diff --name-only main fix-netlify-deployment

# 5. Confirm merge
echo ""
read -p "Ready to merge fix-netlify-deployment into main? (y/n): " confirm_merge
if [ "$confirm_merge" != "y" ]; then
    echo "Merge cancelled"
    exit 1
fi

# 6. Perform merge
echo "4. Merging fix branch..."
git merge fix-netlify-deployment --no-ff -m "🔧 Fix Netlify deployment issues

- Resolve CanvasKit blocking initialization
- Update CSP headers for Flutter web
- Fix Flutter bootstrap API compatibility  
- Add comprehensive error handling and fallbacks
- Implement proper HTML renderer configuration

Changes include:
- Updated web/flutter_bootstrap.js with modern Flutter API
- Enhanced web/index.html with proper CSP headers
- Improved netlify.toml build configuration
- Added _headers file for security policies
- Created comprehensive testing and verification scripts

Tested on branch deploy: fix-netlify-deployment
Rollback commit available: $ROLLBACK_COMMIT
Deploy date: $ROLLBACK_DATE"

if [ $? -ne 0 ]; then
    echo "❌ Merge failed!"
    echo "Please resolve conflicts manually"
    exit 1
fi

# 7. Final verification before push
echo "5. Final verification before pushing..."
if [ -f "./verify-deployment-ready.sh" ]; then
    ./verify-deployment-ready.sh
    if [ $? -ne 0 ]; then
        echo "❌ Post-merge verification failed"
        echo "🔄 Reverting merge..."
        git reset --hard HEAD~1
        exit 1
    fi
fi

# 8. Push to main
echo "6. Pushing to main..."
git push origin main

if [ $? -eq 0 ]; then
    echo ""
    echo "🎉 MERGE COMPLETED SUCCESSFULLY!"
    echo "================================="
    echo "✅ fix-netlify-deployment merged into main"
    echo "🚀 Production deployment starting automatically"
    echo ""
    echo "📋 Next Steps:"
    echo "1. Monitor Netlify deployment: https://app.netlify.com"
    echo "2. Run: ./monitor-production.sh"
    echo "3. Test production site thoroughly"
    echo ""
    echo "🔧 Rollback Options Available:"
    echo "- Quick rollback: ./rollback-with-revert.sh"
    echo "- Hard rollback: ./rollback-deployment.sh"
    echo ""
    echo "📍 Rollback point saved: $ROLLBACK_COMMIT"
else
    echo "❌ Push failed!"
    echo "Please check network connection and try again"
    exit 1
fi