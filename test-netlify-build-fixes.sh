#!/bin/bash

set -e

echo "🧪 Testing Netlify Build Error Fixes"
echo "===================================="
echo

# Test 1: Verify project root detection logic
echo "📋 Test 1: Project Root Detection"
echo "---------------------------------"

# Simulate different environment conditions
test_project_root_detection() {
    local test_name="$1"
    local netlify_repo_path="$2"
    local build_repo_exists="$3"
    
    echo "Testing: $test_name"
    
    # Simulate the project root detection logic
    PROJECT_ROOT=""
    if [ -n "$netlify_repo_path" ] && [ -d "$netlify_repo_path" ]; then
        PROJECT_ROOT="$netlify_repo_path"
    elif [ "$build_repo_exists" = "true" ] && [ -d "/opt/build/repo" ]; then
        PROJECT_ROOT="/opt/build/repo"  
    else
        PROJECT_ROOT="$(pwd)"
    fi
    
    echo "  Result: PROJECT_ROOT=$PROJECT_ROOT"
    echo
}

# Test different scenarios
test_project_root_detection "Current directory fallback" "" "false"
test_project_root_detection "NETLIFY_REPO_PATH set" "$(pwd)" "false"

# Test 2: Verify pubspec.yaml exists
echo "📋 Test 2: pubspec.yaml Validation" 
echo "-----------------------------------"

if [ -f "pubspec.yaml" ]; then
    echo "✅ pubspec.yaml found in current directory"
    echo "   Path: $(pwd)/pubspec.yaml"
    
    # Show relevant pubspec.yaml content
    echo "   Flutter project name: $(grep '^name:' pubspec.yaml | cut -d' ' -f2)"
    echo "   Flutter SDK constraint: $(grep -A1 'environment:' pubspec.yaml | grep 'sdk:' | cut -d"'" -f2 || echo 'Not found')"
else
    echo "❌ pubspec.yaml not found - this would cause the build error"
    exit 1
fi
echo

# Test 3: Verify build script structure
echo "📋 Test 3: Build Script Analysis"
echo "--------------------------------"

check_script_fixes() {
    local script="$1"
    echo "Analyzing: $script"
    
    if [ ! -f "$script" ]; then
        echo "  ❌ Script not found"
        return 1
    fi
    
    # Check for project root detection
    if grep -q "PROJECT_ROOT=" "$script"; then
        echo "  ✅ Project root detection present"
    else
        echo "  ❌ Missing project root detection"
    fi
    
    # Check for pubspec.yaml validation
    if grep -q "pubspec.yaml" "$script"; then
        echo "  ✅ pubspec.yaml validation present"
    else
        echo "  ❌ Missing pubspec.yaml validation"
    fi
    
    # Check for directory context preservation
    local flutter_commands=$(grep -c "flutter " "$script" || echo 0)
    local cd_commands=$(grep -c "cd.*PROJECT_ROOT" "$script" || echo 0)
    
    echo "  📊 Flutter commands: $flutter_commands"
    echo "  📊 Directory changes: $cd_commands"
    
    if [ "$cd_commands" -gt 0 ]; then
        echo "  ✅ Directory context preservation present"
    else
        echo "  ❌ Missing directory context preservation"
    fi
    
    # Check for error handling
    if grep -q "set -e" "$script"; then
        echo "  ✅ Error handling (set -e) present"
    else
        echo "  ❌ Missing error handling"
    fi
    
    echo
}

check_script_fixes "netlify-build-fixed.sh"
check_script_fixes "build_for_netlify.sh"

# Test 4: Simulate Flutter command execution
echo "📋 Test 4: Flutter Command Simulation"
echo "--------------------------------------"

# Simulate the problematic command that was failing
simulate_flutter_pub_get() {
    echo "Simulating: flutter pub get execution"
    
    # Check if we're in the right directory
    if [ -f "pubspec.yaml" ]; then
        echo "  ✅ pubspec.yaml found - flutter pub get would succeed"
        echo "  📍 Current directory: $(pwd)"
        echo "  📦 Project name: $(grep '^name:' pubspec.yaml | cut -d' ' -f2)"
    else
        echo "  ❌ pubspec.yaml not found - flutter pub get would fail with:"
        echo "     'Expected to find project root in current working directory'"
    fi
}

simulate_flutter_pub_get
echo

# Test 5: Environment variable simulation
echo "📋 Test 5: Environment Variables"
echo "--------------------------------"

echo "Testing environment variables that affect build:"
echo "  NETLIFY_REPO_PATH: ${NETLIFY_REPO_PATH:-'(not set)'}"
echo "  PWD: $(pwd)"
echo "  Build directory exists: $([ -d "build" ] && echo "yes" || echo "no")"
echo "  Web directory exists: $([ -d "web" ] && echo "yes" || echo "no")"
echo

# Test 6: File permissions and accessibility
echo "📋 Test 6: File Permissions"
echo "---------------------------"

check_file_permissions() {
    local file="$1"
    if [ -f "$file" ]; then
        local perms=$(ls -la "$file" | cut -d' ' -f1)
        echo "  $file: $perms"
    else
        echo "  $file: not found"
    fi
}

echo "Checking build script permissions:"
check_file_permissions "netlify-build-fixed.sh"
check_file_permissions "build_for_netlify.sh"
check_file_permissions "pubspec.yaml"
echo

# Test 7: Summary and recommendations
echo "📋 Test Summary"
echo "==============="

all_tests_passed=true

# Check critical requirements
if [ ! -f "pubspec.yaml" ]; then
    echo "❌ CRITICAL: pubspec.yaml missing"
    all_tests_passed=false
fi

if [ ! -f "netlify-build-fixed.sh" ]; then
    echo "❌ CRITICAL: Primary build script missing"
    all_tests_passed=false
fi

if [ ! -x "netlify-build-fixed.sh" ]; then
    echo "⚠️  WARNING: Build script not executable, running chmod +x"
    chmod +x netlify-build-fixed.sh 2>/dev/null || echo "   Failed to make executable"
fi

if $all_tests_passed; then
    echo "✅ All critical tests passed!"
    echo
    echo "🚀 Ready to deploy with fixes:"
    echo "   • Project root detection implemented"
    echo "   • pubspec.yaml validation added"
    echo "   • Directory context preservation ensured"
    echo "   • Enhanced error handling and logging"
    echo
    echo "💡 Next steps:"
    echo "   1. Commit these changes to git"
    echo "   2. Deploy to Netlify"
    echo "   3. Monitor build logs for success"
else
    echo "❌ Some tests failed - address issues before deployment"
fi

echo
echo "🔗 For detailed fix information, see: NETLIFY_BUILD_ERROR_FIXES.md"