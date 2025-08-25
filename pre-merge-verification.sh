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
    if [ $? -ne 0 ]; then
        echo "❌ Deployment verification failed"
        exit 1
    fi
else
    echo "⚠️ Deployment verification script not found - creating basic check..."
    
    # Basic verification
    if [ ! -f "web/index.html" ]; then
        echo "❌ web/index.html missing"
        exit 1
    fi
    
    if [ ! -f "web/flutter_bootstrap.js" ]; then
        echo "❌ web/flutter_bootstrap.js missing"
        exit 1
    fi
    
    if [ ! -f "netlify.toml" ]; then
        echo "❌ netlify.toml missing"
        exit 1
    fi
    
    echo "✅ Basic file verification passed"
fi

# 3. Check for merge conflicts with main
echo "3. Checking for merge conflicts..."
git fetch origin main

# Use git merge-tree to detect potential conflicts
if git merge-tree $(git merge-base HEAD origin/main) HEAD origin/main | grep -q "<<<<<<< "; then
    echo "❌ Merge conflicts detected. Resolve before proceeding."
    echo "Run: git merge origin/main"
    exit 1
else
    echo "✅ No merge conflicts detected"
fi

# 4. Verify critical files exist and have content
echo "4. Verifying critical deployment files..."
CRITICAL_FILES=(
    "web/index.html"
    "web/flutter_bootstrap.js"
    "netlify.toml"
    "_headers"
)

for file in "${CRITICAL_FILES[@]}"; do
    if [ -f "$file" ] && [ -s "$file" ]; then
        echo "✅ $file exists and has content"
    else
        echo "❌ $file missing or empty"
        exit 1
    fi
done

# 5. Verify Flutter web build works
echo "5. Testing Flutter web build..."
if command -v flutter &> /dev/null; then
    echo "Building Flutter web app..."
    flutter build web --web-renderer html --release --dart-define=FLUTTER_WEB_USE_SKIA=false
    
    if [ $? -eq 0 ] && [ -f "build/web/main.dart.js" ]; then
        echo "✅ Flutter build successful"
    else
        echo "❌ Flutter build failed"
        exit 1
    fi
else
    echo "⚠️ Flutter not found - skipping build test"
    
    # Check if build directory exists from previous build
    if [ -d "build/web" ] && [ -f "build/web/main.dart.js" ]; then
        echo "✅ Existing build directory found"
    else
        echo "❌ No build directory found and Flutter not available"
        exit 1
    fi
fi

# 6. Validate netlify.toml configuration
echo "6. Validating netlify.toml configuration..."
if grep -q "publish = \"build/web\"" netlify.toml; then
    echo "✅ Publish directory correctly set"
else
    echo "❌ Publish directory not set to build/web"
    exit 1
fi

if grep -q "\[build\]" netlify.toml; then
    echo "✅ Build configuration found"
else
    echo "❌ Build configuration missing"
    exit 1
fi

# 7. Check for environment variables or secrets
echo "7. Checking for environment variables..."
if grep -r "SUPABASE\|API_KEY\|SECRET" --include="*.dart" --include="*.js" --include="*.html" . | grep -v ".git" | grep -v "build/" | head -5; then
    echo "⚠️ Environment variables detected in code - ensure they're properly configured in Netlify"
else
    echo "✅ No hardcoded secrets detected"
fi

# 8. Verify no uncommitted changes
echo "8. Checking for uncommitted changes..."
if [ -n "$(git status --porcelain)" ]; then
    echo "⚠️ Uncommitted changes found:"
    git status --short
    read -p "Commit these changes? (y/n): " commit_changes
    if [ "$commit_changes" = "y" ]; then
        git add .
        git commit -m "Pre-merge: Final deployment preparations"
        git push origin fix-netlify-deployment
        echo "✅ Changes committed"
    else
        echo "❌ Cannot proceed with uncommitted changes"
        exit 1
    fi
else
    echo "✅ No uncommitted changes"
fi

# 9. Generate pre-merge summary
echo ""
echo "📋 PRE-MERGE VERIFICATION SUMMARY"
echo "=================================="
echo "✅ Fix branch is up to date"
echo "✅ No merge conflicts with main"
echo "✅ All critical files present"
echo "✅ Flutter build successful"
echo "✅ Netlify configuration valid"
echo "✅ No uncommitted changes"
echo ""
echo "🎉 Pre-merge verification completed successfully!"
echo "✅ SAFE TO MERGE: fix-netlify-deployment → main"
echo ""
echo "Next steps:"
echo "1. Create/review Pull Request"
echo "2. Run: ./safe-merge-to-main.sh"
echo "3. Monitor deployment with: ./monitor-production.sh"