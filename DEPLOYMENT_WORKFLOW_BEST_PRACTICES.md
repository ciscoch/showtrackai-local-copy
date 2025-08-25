# ShowTrackAI Deployment Workflow - Best Practices

## 🎯 Current Situation
- ✅ **Local Version**: Working on main branch
- ✅ **Fix Branch**: `fix-netlify-deployment` pushed to origin
- ❌ **Production**: Broken deployment on Netlify
- 🎯 **Goal**: Safe deployment with proper testing and rollback strategy

## 🚀 Complete Deployment Workflow

### Phase 1: Branch Deploy Testing (BEFORE merging to main)

#### Step 1: Enable Netlify Branch Deploys
1. Go to Netlify Dashboard → Site Settings → Build & Deploy
2. Under "Deploy contexts", set:
   - **Production branch**: `main`
   - **Branch deploys**: `All`
   - **Deploy previews**: `Any pull request`

#### Step 2: Test Fix Branch Deployment
```bash
# Ensure fix branch is up to date
git checkout fix-netlify-deployment
git pull origin fix-netlify-deployment

# Add any uncommitted deployment files
git add NETLIFY_DEPLOYMENT_GUIDE.md
git commit -m "Add deployment documentation"
git push origin fix-netlify-deployment
```

**Expected Result**: Netlify will automatically deploy `fix-netlify-deployment` to:
`https://fix-netlify-deployment--your-site-name.netlify.app`

#### Step 3: Comprehensive Testing of Branch Deploy
```bash
# Run local verification first
./verify-deployment-ready.sh

# Test the branch deployment URL
# Manual testing checklist:
# ✅ App loads without black screen
# ✅ Login functionality works
# ✅ Dashboard displays correctly
# ✅ Journal entries can be created
# ✅ FFA progress displays
# ✅ No console errors
# ✅ Mobile responsive design works
```

### Phase 2: Pull Request Creation and Review

#### Step 4: Create Pull Request
```bash
# Create PR script
cat > create-deployment-pr.sh << 'EOF'
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
- ✅ Branch deploy tested: https://fix-netlify-deployment--your-site-name.netlify.app
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

Closes #[issue-number-if-exists]" \
        --base main \
        --head fix-netlify-deployment
        
    echo "✅ PR created successfully!"
else
    echo "📝 GitHub CLI not found. Please create PR manually:"
    echo "   Base: main"
    echo "   Head: fix-netlify-deployment"
    echo "   Title: 🔧 Fix Netlify Deployment Issues"
fi
EOF

chmod +x create-deployment-pr.sh
./create-deployment-pr.sh
```

### Phase 3: Pre-Merge Safety Checks

#### Step 5: Final Verification Before Merge
```bash
# Create comprehensive pre-merge check
cat > pre-merge-verification.sh << 'EOF'
#!/bin/bash

echo "🔍 Running pre-merge verification..."

# 1. Verify fix branch is ready
echo "1. Checking fix branch status..."
git checkout fix-netlify-deployment
git pull origin fix-netlify-deployment

# 2. Run all verification scripts
echo "2. Running deployment verification..."
if [ -f "./verify-deployment-ready.sh" ]; then
    ./verify-deployment-ready.sh
else
    echo "⚠️ Deployment verification script not found"
fi

# 3. Check for merge conflicts with main
echo "3. Checking for merge conflicts..."
git fetch origin main
CONFLICTS=$(git merge-tree $(git merge-base HEAD origin/main) HEAD origin/main | grep -c "<<<<<<< ")
if [ $CONFLICTS -gt 0 ]; then
    echo "❌ Merge conflicts detected. Resolve before proceeding."
    exit 1
else
    echo "✅ No merge conflicts detected"
fi

# 4. Verify critical files exist
echo "4. Verifying critical deployment files..."
CRITICAL_FILES=(
    "web/index.html"
    "web/flutter_bootstrap.js"
    "netlify.toml"
    "_headers"
    "build/web/main.dart.js"
)

for file in "${CRITICAL_FILES[@]}"; do
    if [ -f "$file" ]; then
        echo "✅ $file exists"
    else
        echo "❌ $file missing"
        exit 1
    fi
done

# 5. Test build process
echo "5. Testing build process..."
flutter build web --web-renderer html --release
if [ $? -eq 0 ]; then
    echo "✅ Build successful"
else
    echo "❌ Build failed"
    exit 1
fi

echo "🎉 Pre-merge verification completed successfully!"
echo "✅ Safe to merge fix-netlify-deployment → main"
EOF

chmod +x pre-merge-verification.sh
./pre-merge-verification.sh
```

### Phase 4: Merge and Deploy

#### Step 6: Merge to Main (Only After All Tests Pass)
```bash
# Safe merge script with rollback preparation
cat > safe-merge-to-main.sh << 'EOF'
#!/bin/bash

echo "🔀 Starting safe merge to main..."

# 1. Create rollback point
echo "1. Creating rollback point..."
git checkout main
git pull origin main
ROLLBACK_COMMIT=$(git rev-parse HEAD)
echo "📍 Rollback point: $ROLLBACK_COMMIT"

# 2. Create rollback script
cat > rollback-deployment.sh << EOL
#!/bin/bash
echo "🔄 Rolling back to previous main..."
git checkout main
git reset --hard $ROLLBACK_COMMIT
git push --force origin main
echo "✅ Rollback completed to commit: $ROLLBACK_COMMIT"
EOL
chmod +x rollback-deployment.sh

# 3. Perform merge
echo "2. Merging fix branch..."
git merge fix-netlify-deployment --no-ff -m "🔧 Fix Netlify deployment issues

- Resolve CanvasKit blocking initialization
- Update CSP headers for Flutter web
- Fix Flutter bootstrap API compatibility
- Add comprehensive error handling

Tested on branch deploy: fix-netlify-deployment
Rollback commit: $ROLLBACK_COMMIT"

# 4. Push to main
echo "3. Pushing to main..."
git push origin main

echo "✅ Merge completed!"
echo "🚀 Production deployment will start automatically"
echo "⚠️  Monitor deployment at: https://app.netlify.com"
echo "🔄 Rollback available: ./rollback-deployment.sh"
EOF

chmod +x safe-merge-to-main.sh
```

### Phase 5: Post-Deploy Monitoring

#### Step 7: Production Monitoring and Verification
```bash
# Create post-deploy monitoring script
cat > monitor-production.sh << 'EOF'
#!/bin/bash

SITE_URL="https://your-site-name.netlify.app"
DEPLOY_LOG_URL="https://app.netlify.com/sites/your-site-name/deploys"

echo "🔍 Monitoring production deployment..."
echo "📊 Deploy logs: $DEPLOY_LOG_URL"
echo "🌐 Site URL: $SITE_URL"

# Function to check site health
check_site_health() {
    local url=$1
    local response=$(curl -s -w "%{http_code}" -o /dev/null "$url")
    
    if [ "$response" = "200" ]; then
        echo "✅ Site responding (HTTP $response)"
        return 0
    else
        echo "❌ Site not responding (HTTP $response)"
        return 1
    fi
}

# Function to check for Flutter app initialization
check_flutter_init() {
    local url=$1
    local content=$(curl -s "$url")
    
    if echo "$content" | grep -q "flutter-view"; then
        echo "✅ Flutter app structure detected"
        return 0
    else
        echo "❌ Flutter app structure not found"
        return 1
    fi
}

# Monitor deployment for 10 minutes
echo "⏱️  Starting 10-minute monitoring period..."
for i in {1..20}; do
    echo "Check $i/20..."
    
    if check_site_health "$SITE_URL" && check_flutter_init "$SITE_URL"; then
        echo "🎉 Deployment successful!"
        
        # Additional checks
        echo "🔍 Running additional checks..."
        echo "   - Check browser console for errors"
        echo "   - Test login functionality"
        echo "   - Verify dashboard loads"
        echo "   - Test mobile responsiveness"
        
        break
    else
        if [ $i -eq 20 ]; then
            echo "❌ Deployment failed after 10 minutes"
            echo "🔄 Consider running: ./rollback-deployment.sh"
            exit 1
        fi
        sleep 30
    fi
done
EOF

chmod +x monitor-production.sh
```

### Phase 6: Testing Checklist and Rollback

#### Step 8: Manual Testing Checklist
```bash
# Create testing checklist
cat > production-testing-checklist.md << 'EOF'
# Production Testing Checklist

## 🌐 Basic Functionality
- [ ] Site loads without black screen
- [ ] No console errors in browser dev tools
- [ ] Favicon displays correctly
- [ ] Page title shows "ShowTrackAI"

## 🔐 Authentication
- [ ] Login page displays correctly
- [ ] Can create new account
- [ ] Can login with existing account
- [ ] Dashboard loads after login

## 📱 Core Features
- [ ] Dashboard cards display properly
- [ ] FFA Degree Progress shows
- [ ] Journal Entry form works
- [ ] Can submit journal entries
- [ ] Financial tracking displays
- [ ] Animal records accessible

## 📱 Mobile Responsiveness
- [ ] Site works on mobile browsers
- [ ] Touch interactions work
- [ ] Text is readable on small screens
- [ ] Navigation is usable

## ⚡ Performance
- [ ] Initial load time < 5 seconds
- [ ] App is responsive after load
- [ ] No memory leaks in long sessions

## 🔧 Error Handling
- [ ] Graceful handling of network errors
- [ ] Proper error messages shown
- [ ] App recovers from temporary failures

## 📊 Analytics (if enabled)
- [ ] Analytics tracking works
- [ ] No privacy violations
- [ ] Proper consent handling
EOF
```

#### Step 9: Emergency Rollback Process
```bash
# The rollback script was created during merge
# If issues occur, run:
./rollback-deployment.sh

# Additional rollback options:
cat > emergency-rollback-options.sh << 'EOF'
#!/bin/bash

echo "🚨 Emergency Rollback Options"
echo "=============================="

echo "Option 1: Git Revert (Recommended)"
echo "git revert HEAD"
echo "git push origin main"
echo ""

echo "Option 2: Hard Reset (Use with caution)"
echo "git reset --hard HEAD~1"
echo "git push --force origin main"
echo ""

echo "Option 3: Netlify Deploy Rollback"
echo "1. Go to Netlify Dashboard"
echo "2. Click on previous successful deploy"
echo "3. Click 'Publish deploy'"
echo ""

echo "Option 4: Temporary Site Disable"
echo "1. Netlify Dashboard → Site Settings"
echo "2. Danger Zone → Stop auto publishing"
echo ""

echo "⚠️  After rollback, analyze issues and create new fix branch"
EOF

chmod +x emergency-rollback-options.sh
```

## 📋 Complete Workflow Summary

### Before Merge (Safety First)
1. **Branch Deploy Testing**: Test fixes on separate URL
2. **Pull Request Review**: Code review and documentation
3. **Pre-merge Verification**: Comprehensive checks
4. **Rollback Preparation**: Create rollback scripts

### During Merge
1. **Safe Merge Process**: No-fast-forward merge with detailed message
2. **Automatic Deployment**: Netlify deploys main branch
3. **Monitoring Setup**: Prepare monitoring tools

### After Merge
1. **Production Monitoring**: Automated health checks
2. **Manual Testing**: Complete functionality verification
3. **Performance Validation**: Speed and responsiveness checks
4. **Rollback if Needed**: Immediate rollback options available

## 🛡️ Safety Features

### Multiple Rollback Options
- Git revert (cleanest)
- Hard reset (emergency)
- Netlify deploy rollback (instant)
- Site disable (ultimate safety)

### Comprehensive Testing
- Automated build verification
- Branch deploy testing
- Pre-merge conflict checks
- Post-deploy monitoring
- Manual testing checklist

### Documentation and Tracking
- Detailed commit messages
- Rollback point documentation
- Testing results tracking
- Issue documentation for future

## 🎯 Next Steps

1. **Run the workflow**: Follow steps 1-9 in order
2. **Test thoroughly**: Don't skip the testing phases
3. **Monitor closely**: Watch the production deployment
4. **Document issues**: Record any problems for future fixes
5. **Celebrate success**: You've implemented proper DevOps practices!

---

**Remember**: It's better to take extra time testing than to have a broken production site. This workflow ensures your ShowTrackAI deployment is safe, tested, and recoverable.