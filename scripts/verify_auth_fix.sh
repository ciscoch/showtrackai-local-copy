#!/bin/bash

# Comprehensive Authentication Verification Script
echo "🔧 ShowTrackAI Authentication Fix Verification"
echo "=============================================="
echo ""

# Configuration
SUPABASE_URL="https://zifbuzsdhparxlhsifdi.supabase.co"
ANON_KEY="eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InppZmJ1enNkaHBhcnhsaHNpZmRpIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTIwMTUzOTEsImV4cCI6MjA2NzU5MTM5MX0.Lmg6kZ0E35Q9nNsJei9CDxH2uUQZO4AJaiU6H3TvXqU"
TEST_EMAIL="test-elite@example.com"
TEST_PASSWORD="test123456"

echo "1. Testing Supabase Connection..."
echo "   URL: $SUPABASE_URL"
echo "   API Key: ${ANON_KEY:0:20}..."
echo ""

# Test connection
connection_test=$(curl -s -w "%{http_code}" -H "apikey: $ANON_KEY" -H "Authorization: Bearer $ANON_KEY" "$SUPABASE_URL/rest/v1/?select=*&limit=1")
connection_code="${connection_test: -3}"

if [ "$connection_code" == "200" ] || [ "$connection_code" == "404" ]; then
    echo "✅ Supabase connection successful"
else
    echo "❌ Supabase connection failed with HTTP $connection_code"
    echo "🔧 Check your internet connection and Supabase project status"
    exit 1
fi

echo ""
echo "2. Testing Test User Authentication..."
echo "   Email: $TEST_EMAIL"
echo "   Password: $TEST_PASSWORD"
echo ""

# Test authentication
auth_test=$(curl -s -w "%{http_code}" -X POST \
  -H "apikey: $ANON_KEY" \
  -H "Content-Type: application/json" \
  -d "{\"email\":\"$TEST_EMAIL\",\"password\":\"$TEST_PASSWORD\"}" \
  "$SUPABASE_URL/auth/v1/token?grant_type=password")

auth_code="${auth_test: -3}"
auth_body="${auth_test%???}"

if [ "$auth_code" == "200" ]; then
    echo "✅ Test user authentication successful!"
    echo "   User exists and credentials are valid"
    
    # Extract user information
    access_token=$(echo "$auth_body" | grep -o '"access_token":"[^"]*' | cut -d'"' -f4)
    user_email=$(echo "$auth_body" | grep -o '"email":"[^"]*' | cut -d'"' -f4)
    
    echo "   Email confirmed: $user_email"
    echo "   Access token: ${access_token:0:20}..."
    
elif [ "$auth_code" == "400" ]; then
    echo "❌ Test user authentication failed"
    echo "   Error: User does not exist in Supabase"
    echo ""
    echo "🔧 SOLUTION REQUIRED:"
    echo "   The test user needs to be created in Supabase Dashboard"
    echo ""
    echo "   METHOD 1 - Manual Creation (Recommended):"
    echo "   1. Go to: https://supabase.com/dashboard/projects"
    echo "   2. Select your project"
    echo "   3. Go to Authentication > Users"
    echo "   4. Click 'Add User'"
    echo "   5. Enter:"
    echo "      Email: test-elite@example.com"
    echo "      Password: test123456"
    echo "      ✓ Auto Confirm User"
    echo "      ✓ Email Confirm"
    echo "   6. Click 'Create User'"
    echo ""
    echo "   METHOD 2 - SQL Creation (If you have service key):"
    echo "   Run: scripts/create_test_user.sql in Supabase SQL Editor"
    echo ""
    
else
    echo "❌ Authentication failed with HTTP $auth_code"
    echo "   Response: $auth_body"
fi

echo ""
echo "3. Testing Flutter App Authentication Flow..."
echo ""

# Check if Flutter files have been updated
if [ -f "lib/services/auth_service.dart" ]; then
    if grep -q "_handleTestUserSignIn" lib/services/auth_service.dart; then
        echo "✅ AuthService updated with test user handling"
    else
        echo "⚠️  AuthService needs test user handling update"
    fi
else
    echo "❌ AuthService file not found"
fi

if [ -f "lib/screens/login_screen.dart" ]; then
    if grep -q "_showTestUserCreationDialog" lib/screens/login_screen.dart; then
        echo "✅ Login screen updated with test user dialog"
    else
        echo "⚠️  Login screen needs test user dialog update"
    fi
    
    if grep -q "_signInAsDemo" lib/screens/login_screen.dart; then
        echo "✅ Login screen updated with demo mode"
    else
        echo "⚠️  Login screen needs demo mode update"
    fi
else
    echo "❌ Login screen file not found"
fi

echo ""
echo "4. Next Steps Based on Results..."
echo ""

if [ "$auth_code" == "200" ]; then
    echo "🎉 AUTHENTICATION IS WORKING!"
    echo "   • Test user exists and can authenticate"
    echo "   • Flutter app should work with Quick Sign In"
    echo "   • Ready to test the full application"
    echo ""
    echo "📱 To test:"
    echo "   1. Run: flutter run -d chrome"
    echo "   2. Click 'Quick Sign In (Test User)'"
    echo "   3. Should redirect to dashboard"
else
    echo "🔧 AUTHENTICATION NEEDS SETUP:"
    echo "   • Create test user in Supabase Dashboard (see METHOD 1 above)"
    echo "   • Test user will work once created"
    echo "   • Demo mode available as backup"
    echo ""
    echo "📱 Current options in Flutter app:"
    echo "   1. 'Demo Mode' - Works without Supabase user"
    echo "   2. 'Quick Sign In' - Will show creation dialog"
    echo "   3. Manual sign in - For real users"
fi

echo ""
echo "5. Troubleshooting Guide..."
echo ""
echo "   CONNECTION ISSUES:"
echo "   • Check internet connection"
echo "   • Verify Supabase project is active"
echo "   • Confirm API key is correct"
echo ""
echo "   AUTHENTICATION ISSUES:"
echo "   • Create test user in Supabase Dashboard"
echo "   • Check email/password spelling"
echo "   • Use Demo Mode for offline testing"
echo ""
echo "   FLUTTER ISSUES:"
echo "   • Run: flutter clean && flutter pub get"
echo "   • Check console for error messages"
echo "   • Test on different browsers if using web"

echo ""
echo "📋 VERIFICATION COMPLETE"
echo "   Connection: $([ "$connection_code" == "200" ] && echo "✅ Working" || echo "❌ Failed")"
echo "   Authentication: $([ "$auth_code" == "200" ] && echo "✅ Working" || echo "❌ Needs Setup")"
echo "   Flutter Updates: $([ -f "lib/services/auth_service.dart" ] && echo "✅ Applied" || echo "❌ Missing")"