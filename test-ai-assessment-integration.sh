#!/bin/bash

# ============================================================================
# AI Assessment Integration Test Script
# Tests the complete N8N → Edge Function → Database flow
# ============================================================================

echo "🧪 AI Assessment Integration Test"
echo "=================================="

# Configuration
SUPABASE_PROJECT_ID="zifbuzsdhparxlhsifdi"
EDGE_FUNCTION_URL="https://$SUPABASE_PROJECT_ID.supabase.co/functions/v1/spar-callback"
N8N_WEBHOOK_URL="https://showtrackai.app.n8n.cloud/webhook/4b52c2de-4d37-4752-aa5c-5741bd9e493d"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Test 1: Verify database schema
echo -e "${BLUE}Test 1: Database Schema Verification${NC}"
echo "======================================"

supabase db reset --db-url "postgresql://postgres:[PASSWORD]@db.$SUPABASE_PROJECT_ID.supabase.co:5432/postgres" || {
    echo -e "${YELLOW}⚠️  Could not connect to database. Run manually:${NC}"
    echo "   psql -h db.$SUPABASE_PROJECT_ID.supabase.co -U postgres -d postgres -f verify-ai-assessment-schema.sql"
}

# Test 2: Check Edge Function deployment
echo -e "${BLUE}Test 2: Edge Function Availability${NC}"
echo "===================================="

response=$(curl -s -o /dev/null -w "%{http_code}" -X POST \
    "$EDGE_FUNCTION_URL" \
    -H "Content-Type: application/json" \
    -H "x-spar-auth: invalid-test-auth" \
    -d '{"runId": "test", "status": "test"}' \
    --max-time 10)

if [ "$response" = "401" ]; then
    echo -e "${GREEN}✅ Edge Function deployed and responding (401 = auth required)${NC}"
elif [ "$response" = "200" ]; then
    echo -e "${YELLOW}⚠️  Edge Function deployed but not requiring auth${NC}"
else
    echo -e "${RED}❌ Edge Function not responding (HTTP $response)${NC}"
    echo "   Deploy with: ./deploy-spar-callback.sh"
fi

# Test 3: N8N Webhook availability
echo -e "${BLUE}Test 3: N8N Webhook Availability${NC}"
echo "=================================="

n8n_response=$(curl -s -o /dev/null -w "%{http_code}" -X POST \
    "$N8N_WEBHOOK_URL" \
    -H "Content-Type: application/json" \
    -d '{"test": true}' \
    --max-time 15)

if [ "$n8n_response" = "200" ]; then
    echo -e "${GREEN}✅ N8N webhook responding${NC}"
else
    echo -e "${YELLOW}⚠️  N8N webhook response: HTTP $n8n_response${NC}"
    echo "   This may be normal if workflow requires specific data format"
fi

# Test 4: Complete integration test with real data
echo -e "${BLUE}Test 4: Integration Test with Sample Data${NC}"
echo "=========================================="

# Generate test data
TEST_RUN_ID="test_$(date +%s)"
TEST_USER_ID="test-user-$(date +%s)"

# Sample journal entry data for N8N
TEST_JOURNAL_DATA='{
    "requestId": "test_request_'$TEST_RUN_ID'",
    "traceId": "'$TEST_RUN_ID'",
    "timestamp": "'$(date -u +%Y-%m-%dT%H:%M:%S.%3NZ)'",
    "journalEntry": {
        "id": "test_journal_'$TEST_RUN_ID'",
        "userId": "'$TEST_USER_ID'",
        "title": "Morning Animal Care - Integration Test",
        "description": "Fed the calves, checked water systems, and observed behavior. All animals appeared healthy with good appetites.",
        "content": "Completed morning feeding routine. Provided 3 lbs of grain per calf and fresh hay. Water systems functioning properly. No signs of illness observed.",
        "category": "daily_care",
        "objectives": "Maintain animal health through proper nutrition and care",
        "duration": 45
    },
    "sparSettings": {
        "enabled": true,
        "route": {
            "intent": "edu_context"
        }
    },
    "processingOptions": {
        "includeFFAStandards": true,
        "includeCompetencyMapping": true,
        "ageAppropriate": true
    }
}'

echo "📤 Sending test data to N8N webhook..."
echo "   Run ID: $TEST_RUN_ID"
echo "   User ID: $TEST_USER_ID"

# Send to N8N
n8n_full_response=$(curl -s -X POST \
    "$N8N_WEBHOOK_URL" \
    -H "Content-Type: application/json" \
    -H "X-Test-Integration: true" \
    -H "X-Trace-ID: $TEST_RUN_ID" \
    -d "$TEST_JOURNAL_DATA" \
    --max-time 30)

echo "N8N Response: $n8n_full_response"

if [[ "$n8n_full_response" =~ "success" || "$n8n_full_response" =~ "accepted" || "$n8n_full_response" =~ "processing" ]]; then
    echo -e "${GREEN}✅ N8N accepted the test data${NC}"
    echo "   Monitoring for callback..."
    
    # Wait for potential callback (give N8N time to process)
    echo "   Waiting 30 seconds for AI processing..."
    sleep 30
    
    # Check if SPAR run was created (this would require database access)
    echo -e "${YELLOW}📊 Check SPAR runs table for entry: $TEST_RUN_ID${NC}"
    echo "   SELECT * FROM spar_runs WHERE run_id = '$TEST_RUN_ID';"
    
else
    echo -e "${RED}❌ N8N did not accept test data${NC}"
fi

# Test 5: Direct Edge Function callback test
echo -e "${BLUE}Test 5: Direct Edge Function Callback Test${NC}"
echo "============================================="

if [ -z "$SPAR_CALLBACK_SECRET" ]; then
    echo -e "${YELLOW}⚠️  SPAR_CALLBACK_SECRET not set. Using placeholder.${NC}"
    SPAR_CALLBACK_SECRET="your-secret-key-here"
fi

CALLBACK_TEST_DATA='{
    "runId": "'$TEST_RUN_ID'",
    "status": "completed",
    "results": {
        "quality_score": 8.5,
        "engagement_score": 7.8,
        "learning_depth_score": 8.2,
        "competencies": ["AS.01.01", "AS.07.01"],
        "ffa_standards": ["CRP.02", "CRP.04"],
        "strengths": ["Strong observation skills", "Good technical knowledge"],
        "growth_areas": ["Include more reflection", "Add quantitative measurements"],
        "recommendations": ["Take photos of key observations", "Include feed weights"],
        "confidence_score": 0.85,
        "model_used": "gpt-4"
    },
    "plan": {
        "steps": ["analyze", "evaluate", "recommend"],
        "estimated_time": 15
    }
}'

echo "📞 Testing direct Edge Function callback..."

callback_response=$(curl -s -X POST \
    "$EDGE_FUNCTION_URL" \
    -H "Content-Type: application/json" \
    -H "x-spar-auth: $SPAR_CALLBACK_SECRET" \
    -d "$CALLBACK_TEST_DATA" \
    --max-time 15)

echo "Callback Response: $callback_response"

if [[ "$callback_response" =~ "success" ]]; then
    echo -e "${GREEN}✅ Edge Function callback successful${NC}"
else
    echo -e "${RED}❌ Edge Function callback failed${NC}"
    echo "   Check SPAR_CALLBACK_SECRET and Edge Function deployment"
fi

# Final summary
echo ""
echo -e "${BLUE}=========================================${NC}"
echo -e "${BLUE}🎯 INTEGRATION TEST SUMMARY${NC}"
echo -e "${BLUE}=========================================${NC}"
echo ""
echo -e "1. Database Schema: ${GREEN}Verify manually with SQL script${NC}"
echo -e "2. Edge Function: ${GREEN}$([ "$response" = "401" ] && echo "✅ Deployed" || echo "❌ Check deployment")${NC}"
echo -e "3. N8N Webhook: ${GREEN}$([ "$n8n_response" = "200" ] && echo "✅ Available" || echo "⚠️  Response: $n8n_response")${NC}"
echo -e "4. Full Integration: ${GREEN}Check SPAR runs table${NC}"
echo -e "5. Direct Callback: ${GREEN}$(echo "$callback_response" | grep -q "success" && echo "✅ Working" || echo "❌ Failed")${NC}"
echo ""
echo -e "${YELLOW}📋 Next Steps:${NC}"
echo "1. Run: psql -f verify-ai-assessment-schema.sql"
echo "2. Check SPAR runs: SELECT * FROM spar_runs WHERE run_id = '$TEST_RUN_ID';"
echo "3. Check assessments: SELECT * FROM journal_entry_ai_assessments WHERE n8n_run_id = '$TEST_RUN_ID';"
echo ""
echo -e "${GREEN}🎉 Integration test completed!${NC}"