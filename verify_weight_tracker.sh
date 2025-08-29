#!/bin/bash

echo "🔍 Verifying Weight Tracker Integration"
echo "======================================="

# Check if files exist
echo "📁 Checking Weight Tracker files..."
files_to_check=(
    "lib/models/weight.dart"
    "lib/models/weight_goal.dart"
    "lib/services/weight_service.dart"
    "lib/screens/weight_tracker_screen.dart"
    "lib/widgets/weight/weight_form.dart"
    "lib/widgets/weight/weight_history_list.dart"
    "lib/widgets/weight/weight_chart.dart"
    "lib/widgets/weight/weight_goal_card.dart"
    "lib/widgets/weight/weight_analytics_card.dart"
)

all_exist=true
for file in "${files_to_check[@]}"; do
    if [ -f "$file" ]; then
        echo "✅ $file exists"
    else
        echo "❌ $file MISSING"
        all_exist=false
    fi
done

echo ""
echo "📍 Checking route registration..."
if grep -q "'/weight-tracker'" lib/main.dart; then
    echo "✅ Weight Tracker route registered in main.dart"
    grep "weight-tracker" lib/main.dart | head -1
else
    echo "❌ Weight Tracker route NOT registered"
fi

echo ""
echo "🎯 Checking dashboard integration..."
if grep -q "Weight Tracker" lib/screens/dashboard_screen.dart; then
    echo "✅ Weight Tracker card in dashboard"
    grep -n "Weight Tracker" lib/screens/dashboard_screen.dart | head -1
else
    echo "❌ Weight Tracker NOT in dashboard"
fi

echo ""
echo "🔗 Checking animal detail integration..."
if grep -q "weight-tracker\|Weight Tracker" lib/screens/animal_detail_screen.dart; then
    echo "✅ Weight Tracker linked from animal detail"
    grep -n "weight-tracker\|Weight Tracker" lib/screens/animal_detail_screen.dart | head -1
else
    echo "❌ Weight Tracker NOT linked from animal detail"
fi

echo ""
echo "📦 Checking imports..."
if grep -q "weight_tracker_screen" lib/main.dart; then
    echo "✅ WeightTrackerScreen imported in main.dart"
else
    echo "❌ WeightTrackerScreen NOT imported"
fi

echo ""
echo "🔍 Checking for compilation issues..."
# Check for any TODO or FIXME related to weight
if grep -r "TODO.*weight\|FIXME.*weight" lib/; then
    echo "⚠️  Found weight-related TODOs/FIXMEs"
else
    echo "✅ No weight-related TODOs/FIXMEs"
fi

echo ""
echo "📊 Summary:"
if [ "$all_exist" = true ]; then
    echo "✅ All Weight Tracker files present"
    echo ""
    echo "🚀 To deploy to Netlify:"
    echo "1. Ensure you're on main branch: git checkout main"
    echo "2. Pull latest: git pull origin main"
    echo "3. Clear Netlify cache in dashboard: Deploys → Trigger deploy → Clear cache and deploy site"
    echo "4. Or force rebuild: git commit --allow-empty -m 'chore: trigger rebuild for Weight Tracker'"
else
    echo "❌ Some Weight Tracker files missing - deployment will fail"
fi

echo ""
echo "📝 Git status:"
git log --oneline -5 | grep -i weight || echo "No weight-related commits in last 5"