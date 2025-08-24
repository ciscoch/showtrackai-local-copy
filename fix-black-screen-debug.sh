#!/bin/bash

echo "🔧 Flutter Black Screen Debug & Fix Script"
echo "=========================================="

cd /Users/francisco/Documents/CALUDE/showtrackai-local-copy

echo "📋 Step 1: Clean previous build..."
flutter clean

echo "📋 Step 2: Get dependencies..."
flutter pub get

echo "📋 Step 3: Build with HTML renderer (forced)..."
flutter build web --release --verbose

echo "📋 Step 4: Copy diagnostic files to build..."
cp build/web/flutter-black-screen-diagnostic.html build/web/diagnostic.html

echo "📋 Step 5: Start local server..."
echo "Starting server at http://localhost:8087"
echo "Main app: http://localhost:8087"
echo "Diagnostic: http://localhost:8087/diagnostic.html"

# Start Python server in background
python3 -m http.server 8087 --directory build/web &
SERVER_PID=$!

echo "🌐 Server started with PID: $SERVER_PID"
echo ""
echo "🔍 DEBUGGING STEPS TO FOLLOW:"
echo "1. Open http://localhost:8087 in browser"
echo "2. Open browser dev tools (F12)"
echo "3. Check console for Flutter logs"
echo "4. If black screen, try http://localhost:8087/diagnostic.html"
echo "5. Use diagnostic tool buttons to debug"
echo ""
echo "📊 Expected results:"
echo "✅ If you see colorful diagnostic screen = Flutter works, theme issue"
echo "❌ If still black screen = Flutter initialization problem"
echo ""
echo "Press Ctrl+C to stop server when done debugging"

# Keep script running until Ctrl+C
trap "kill $SERVER_PID 2>/dev/null; exit" INT
wait $SERVER_PID