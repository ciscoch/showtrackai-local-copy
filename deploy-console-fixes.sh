#!/bin/bash

# ShowTrackAI Console Errors Fix Deployment Script
# Fixes critical production errors identified in console logs

echo "🚀 Deploying ShowTrackAI console error fixes..."

# Build the Flutter web app with the fixes
echo "📦 Building Flutter web app..."
flutter clean
flutter pub get
flutter build web --web-renderer html --dart-define=FLUTTER_WEB_USE_SKIA=false

if [ $? -ne 0 ]; then
    echo "❌ Flutter build failed"
    exit 1
fi

echo "✅ Flutter build completed successfully"

# Deploy to Netlify
echo "🌐 Deploying to Netlify..."
netlify deploy --prod --dir=build/web

if [ $? -ne 0 ]; then
    echo "❌ Netlify deployment failed"
    exit 1
fi

echo "✅ Netlify deployment completed successfully"

echo ""
echo "🎉 Console fixes deployed successfully!"
echo ""
echo "Fixed Issues:"
echo "✅ Added Content Security Policy headers for external API access"
echo "✅ Enhanced Flutter error handling with detailed logging"
echo "✅ Improved web initialization with user-friendly error messages"
echo ""
echo "⚠️  Still needed:"
echo "   - Apply database migration: 20250828_fix_console_errors.sql"
echo "   - Test birth_date and get_user_journal_stats functions"
echo ""
echo "Next steps:"
echo "1. Apply the database migration in Supabase dashboard"
echo "2. Test the application at https://showtrackai.netlify.app"
echo "3. Monitor console for remaining errors"