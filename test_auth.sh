#!/bin/bash

# Test Supabase Authentication directly
echo "🧪 Testing Supabase Authentication API"
echo "======================================"

# Configuration
SUPABASE_URL="https://zifbuzsdhparxlhsifdi.supabase.co"
ANON_KEY_1="eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InppZmJ1enNkaHBhcnhsaHNpZmRpIiwicm9sZSI6ImFub24iLCJpYXQiOjE3Mjk5NTM5NTAsImV4cCI6MjA0NTUyOTk1MH0.fRilmQ7J9yYvv0wQtxIjfMkjR8W8F2pBh8G0jkmAc4k"
ANON_KEY_2="eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InppZmJ1enNkaHBhcnhsaHNpZmRpIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTIwMTUzOTEsImV4cCI6MjA2NzU5MTM5MX0.Lmg6kZ0E35Q9nNsJei9CDxH2uUQZO4AJaiU6H3TvXqU"
TEST_EMAIL="test-elite@example.com"
TEST_PASSWORD="test123456"

echo "1. Testing connection to Supabase..."

# Test both API keys to find the correct one
for i in {1..2}; do
    ANON_KEY_VAR="ANON_KEY_$i"
    ANON_KEY="${!ANON_KEY_VAR}"
    
    echo "   Testing API key $i..."
    response=$(curl -s -w "%{http_code}" -H "apikey: $ANON_KEY" -H "Authorization: Bearer $ANON_KEY" "$SUPABASE_URL/rest/v1/?select=*&limit=1")
    http_code="${response: -3}"
    response_body="${response%???}"
    
    if [ "$http_code" == "200" ] || [ "$http_code" == "404" ]; then
        echo "✅ API key $i works!"
        WORKING_ANON_KEY="$ANON_KEY"
        break
    elif [ "$http_code" == "401" ]; then
        echo "❌ API key $i failed - Invalid API key"
    else
        echo "⚠️  API key $i returned HTTP $http_code: $response_body"
    fi
done

if [ -n "$WORKING_ANON_KEY" ]; then
    echo "✅ Found working API key"
    ANON_KEY="$WORKING_ANON_KEY"
else
    echo "❌ No working API keys found"
    echo "🔧 You need to get the correct anon key from Supabase Dashboard > Settings > API"
    exit 1
fi

echo ""
echo "2. Testing user authentication..."
auth_response=$(curl -s -w "%{http_code}" -X POST \
  -H "apikey: $ANON_KEY" \
  -H "Content-Type: application/json" \
  -d "{\"email\":\"$TEST_EMAIL\",\"password\":\"$TEST_PASSWORD\"}" \
  "$SUPABASE_URL/auth/v1/token?grant_type=password")

auth_http_code="${auth_response: -3}"
auth_response_body="${auth_response%???}"

if [ "$auth_http_code" == "200" ]; then
    echo "✅ User authentication successful"
    echo "   User exists and credentials are valid"
    
    # Extract access token for further tests
    access_token=$(echo "$auth_response_body" | grep -o '"access_token":"[^"]*' | cut -d'"' -f4)
    if [ -n "$access_token" ]; then
        echo "   Access token received (length: ${#access_token})"
        
        # Test authenticated request
        echo ""
        echo "3. Testing authenticated data access..."
        data_response=$(curl -s -w "%{http_code}" \
          -H "apikey: $ANON_KEY" \
          -H "Authorization: Bearer $access_token" \
          "$SUPABASE_URL/rest/v1/animals?select=*&limit=5")
        
        data_http_code="${data_response: -3}"
        data_response_body="${data_response%???}"
        
        if [ "$data_http_code" == "200" ]; then
            echo "✅ Authenticated data access successful"
            echo "   Data: $data_response_body"
        else
            echo "❌ Authenticated data access failed with HTTP $data_http_code"
            echo "   Response: $data_response_body"
        fi
    fi
    
elif [ "$auth_http_code" == "400" ]; then
    echo "❌ User authentication failed"
    echo "   Error: Invalid login credentials"
    echo "   The test user probably doesn't exist in Supabase"
    echo ""
    echo "🔧 To fix this:"
    echo "   1. Go to Supabase Dashboard > Authentication > Users"
    echo "   2. Click 'Add User'"
    echo "   3. Enter: $TEST_EMAIL / $TEST_PASSWORD"
    echo "   4. Click 'Create User'"
    
elif [ "$auth_http_code" == "422" ]; then
    echo "❌ User authentication failed"
    echo "   Error: Signup disabled or email confirmation required"
else
    echo "❌ Authentication failed with HTTP $auth_http_code"
    echo "   Response: $auth_response_body"
fi

echo ""
echo "📋 Summary:"
echo "   • Supabase URL: $SUPABASE_URL"
echo "   • Test Email: $TEST_EMAIL"
echo "   • API Key: ${ANON_KEY:0:20}..."
echo "   • Connection Status: $([ "$http_code" == "200" ] && echo "✅ Working" || echo "❌ Failed")"
echo "   • Auth Status: $([ "$auth_http_code" == "200" ] && echo "✅ Working" || echo "❌ Failed")"

echo ""
echo "🚀 Next Steps:"
echo "   1. If connection failed: Check internet and Supabase project status"
echo "   2. If auth failed: Create test user in Supabase dashboard"
echo "   3. If successful: Run Flutter app and test login"