#!/bin/bash

echo "🚨 EMERGENCY ROLLBACK OPTIONS FOR SHOWTRACKAI"
echo "============================================="
echo "Use these options if production deployment fails"
echo ""

# Check current branch and status
echo "📊 Current Status:"
echo "Current branch: $(git branch --show-current)"
echo "Last commit: $(git log --oneline -1)"
echo "Remote status: $(git status -uno --porcelain | wc -l) uncommitted changes"
echo ""

echo "🔄 ROLLBACK OPTIONS (Choose one):"
echo ""

echo "1️⃣  GIT REVERT (RECOMMENDED - Safest)"
echo "   Creates a new commit that undoes the merge"
echo "   Preserves history and is easily reversible"
echo "   Command:"
echo "   git revert HEAD --no-edit"
echo "   git push origin main"
echo ""

echo "2️⃣  HARD RESET (Use with caution)"
echo "   Completely removes the problematic commit"
echo "   Cannot be undone easily"
echo "   Command:"
echo "   git reset --hard HEAD~1"
echo "   git push --force origin main"
echo ""

echo "3️⃣  NETLIFY DEPLOY ROLLBACK (Instant)"
echo "   Rolls back through Netlify interface"
echo "   Doesn't change git history"
echo "   Steps:"
echo "   1. Go to: https://app.netlify.com/sites/showtrackai/deploys"
echo "   2. Find the last working deploy"
echo "   3. Click on it"
echo "   4. Click 'Publish deploy'"
echo "   5. Site immediately reverts to that version"
echo ""

echo "4️⃣  TEMPORARY SITE DISABLE"
echo "   Stops auto-publishing to prevent further issues"
echo "   Steps:"
echo "   1. Netlify Dashboard → Site Settings"
echo "   2. Build & Deploy → Continuous Deployment" 
echo "   3. Stop auto publishing"
echo "   4. Fix issues locally"
echo "   5. Re-enable when ready"
echo ""

echo "5️⃣  BRANCH PROTECTION (Prevention)"
echo "   Create a stable branch for emergency rollback"
echo "   Commands:"
echo "   git checkout main"
echo "   git pull origin main"
echo "   git checkout -b stable/backup-$(date +%Y-%m-%d)"
echo "   git push origin stable/backup-$(date +%Y-%m-%d)"
echo ""

echo "⚡ QUICK ACTION SCRIPTS:"
echo ""

# Create quick revert script
cat > quick-revert.sh << 'EOF'
#!/bin/bash
echo "🔄 Performing quick revert..."
git checkout main
git revert HEAD --no-edit
git push origin main
echo "✅ Revert completed - check site in 2-3 minutes"
EOF

# Create quick reset script  
cat > quick-reset.sh << 'EOF'
#!/bin/bash
echo "⚠️  DESTRUCTIVE: This will force-push and lose commit history"
read -p "Are you absolutely sure? Type 'YES' to continue: " confirm
if [ "$confirm" = "YES" ]; then
    git checkout main
    git reset --hard HEAD~1
    git push --force origin main
    echo "✅ Hard reset completed - check site in 2-3 minutes"
else
    echo "Cancelled"
fi
EOF

# Create backup current state script
cat > backup-current-state.sh << 'EOF'
#!/bin/bash
BACKUP_BRANCH="emergency-backup-$(date +%Y%m%d-%H%M%S)"
echo "💾 Creating backup branch: $BACKUP_BRANCH"
git checkout -b "$BACKUP_BRANCH"
git push origin "$BACKUP_BRANCH"
echo "✅ Current state backed up to: $BACKUP_BRANCH"
EOF

chmod +x quick-revert.sh quick-reset.sh backup-current-state.sh

echo "Created quick action scripts:"
echo "  ./quick-revert.sh     - Safe revert"
echo "  ./quick-reset.sh      - Hard reset (dangerous)"
echo "  ./backup-current-state.sh - Backup current state"
echo ""

echo "🔍 DEBUGGING COMMANDS:"
echo "Check site status:    curl -I https://showtrackai.netlify.app"
echo "Check deploy logs:    https://app.netlify.com/sites/showtrackai/deploys"
echo "Check recent commits: git log --oneline -10"
echo "Check file changes:   git show --name-only"
echo ""

echo "📞 POST-ROLLBACK CHECKLIST:"
echo "1. ✅ Verify site loads: https://showtrackai.netlify.app"
echo "2. ✅ Check core functionality (login, dashboard)"
echo "3. ✅ Monitor for 10-15 minutes"
echo "4. ✅ Document what went wrong"
echo "5. ✅ Create new fix branch for proper solution"
echo ""

echo "🛠️  AFTER ROLLBACK - NEXT STEPS:"
echo "1. Investigate the issue thoroughly"
echo "2. Create a new fix branch: git checkout -b hotfix/deployment-v2"
echo "3. Test thoroughly on branch deploy"
echo "4. Use the deployment workflow again"
echo ""

read -p "Which option would you like to use? (1-5, or 'q' to quit): " choice

case $choice in
    1)
        echo "Executing Option 1: Git Revert"
        ./quick-revert.sh
        ;;
    2)
        echo "Executing Option 2: Hard Reset"
        ./quick-reset.sh
        ;;
    3)
        echo "Opening Netlify Dashboard for manual rollback..."
        if command -v open &> /dev/null; then
            open "https://app.netlify.com/sites/showtrackai/deploys"
        else
            echo "Please open: https://app.netlify.com/sites/showtrackai/deploys"
        fi
        ;;
    4)
        echo "Opening Netlify Settings to disable auto-publishing..."
        if command -v open &> /dev/null; then
            open "https://app.netlify.com/sites/showtrackai/settings/deploys"
        else
            echo "Please open: https://app.netlify.com/sites/showtrackai/settings/deploys"
        fi
        ;;
    5)
        echo "Creating stable backup branch..."
        ./backup-current-state.sh
        ;;
    q)
        echo "Exiting - no action taken"
        ;;
    *)
        echo "Invalid option. Please run the script again and choose 1-5 or 'q'"
        ;;
esac