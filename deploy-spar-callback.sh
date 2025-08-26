#!/bin/bash

# Deploy SPAR Callback Edge Function
echo "🚀 Deploying SPAR Callback Edge Function..."

# Navigate to project directory
cd /Users/francisco/Documents/CALUDE/showtrackai-local-copy

# Link to Supabase project (if not already linked)
if [ ! -f .supabaserc ]; then
    echo "📝 Linking to Supabase project..."
    supabase link --project-ref zifbuzsdhparxlhsifdi
fi

# Deploy the Edge Function
echo "🔧 Deploying spar-callback function..."
supabase functions deploy spar-callback

# Set the callback secret (use environment variable or prompt)
if [ -z "$SPAR_CALLBACK_SECRET" ]; then
    echo "🔑 Setting callback secret..."
    read -s -p "Enter SPAR callback secret: " SPAR_CALLBACK_SECRET
    echo
fi

supabase secrets set SPAR_CALLBACK_SECRET="$SPAR_CALLBACK_SECRET"

echo "✅ SPAR Callback Edge Function deployed successfully!"
echo "📍 Function URL: https://zifbuzsdhparxlhsifdi.supabase.co/functions/v1/spar-callback"
echo "🔒 Secret configured for authentication"

# Test the function
echo "🧪 Testing Edge Function availability..."
curl -X POST \
  https://zifbuzsdhparxlhsifdi.supabase.co/functions/v1/spar-callback \
  -H "Content-Type: application/json" \
  -H "x-spar-auth: test-invalid-auth" \
  -d '{"runId": "test", "status": "test"}' \
  --max-time 10

echo ""
echo "✅ Deployment complete! Edge Function ready to receive N8N callbacks."