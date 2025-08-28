#!/bin/bash

echo "🧪 Testing Flutter Bootstrap Fix"
echo "================================="

# Change to the project directory
cd "$(dirname "$0")"

echo ""
echo "1. Checking required Flutter files..."
required_files=("web/flutter.js" "web/main.dart.js" "web/flutter_bootstrap.js" "web/flutter_build_config.json")
missing_files=()

for file in "${required_files[@]}"; do
    if [[ -f "$file" ]]; then
        echo "✅ $file - Found"
    else
        echo "❌ $file - Missing"
        missing_files+=("$file")
    fi
done

if [[ ${#missing_files[@]} -eq 0 ]]; then
    echo "✅ All required files present"
else
    echo ""
    echo "❌ Missing files detected. Attempting to fix..."
    
    # Try to rebuild or copy from build directory
    if [[ -d "build/web" ]]; then
        echo "📂 Found build/web directory, copying missing files..."
        
        for file in "${missing_files[@]}"; do
            filename=$(basename "$file")
            if [[ -f "build/web/$filename" ]]; then
                cp "build/web/$filename" "web/$filename"
                echo "✅ Copied $filename from build/web"
            else
                echo "❌ $filename not found in build/web either"
            fi
        done
    else
        echo "❌ build/web directory not found. Please run 'flutter build web' first."
        exit 1
    fi
fi

echo ""
echo "2. Checking buildConfig structure in index.html..."
if grep -q "_flutter.buildConfig" web/index.html; then
    echo "✅ buildConfig setup found in index.html"
else
    echo "❌ buildConfig setup not found in index.html"
fi

echo ""
echo "3. Checking flutter_bootstrap.js for 'builds' array fix..."
if grep -q "builds.*\[\]" web/flutter_bootstrap.js; then
    echo "✅ builds array fix found in flutter_bootstrap.js"
else
    echo "❌ builds array fix not found in flutter_bootstrap.js"
fi

echo ""
echo "4. Starting local test server..."

# Check if Python is available
if command -v python3 &> /dev/null; then
    echo "🌐 Starting Python HTTP server on port 8080..."
    echo "📱 Open http://localhost:8080/test-flutter-bootstrap-fix.html to test the fix"
    echo "📱 Open http://localhost:8080/ to test the main app"
    echo ""
    echo "Press Ctrl+C to stop the server"
    echo ""
    
    cd web && python3 -m http.server 8080
elif command -v python &> /dev/null; then
    echo "🌐 Starting Python HTTP server on port 8080..."
    echo "📱 Open http://localhost:8080/test-flutter-bootstrap-fix.html to test the fix"
    echo "📱 Open http://localhost:8080/ to test the main app"
    echo ""
    echo "Press Ctrl+C to stop the server"
    echo ""
    
    cd web && python -m SimpleHTTPServer 8080
else
    echo "❌ Python not found. Please install Python or use another HTTP server."
    echo "📝 You can also use 'flutter run -d web-server --web-port 8080'"
    exit 1
fi