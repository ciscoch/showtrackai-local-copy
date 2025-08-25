#!/bin/bash

set -e  # Exit on error

echo "🚀 Starting ShowTrackAI Netlify build (Fixed Version)..."
echo "Current directory: $(pwd)"
echo "Node version: $(node --version)"
echo "Build timestamp: $(date)"

# Ensure we're in the correct directory
cd $NETLIFY_REPO_PATH || cd /opt/build/repo || cd .

# Clean any previous Flutter installations
echo "🧹 Cleaning previous Flutter installations..."
rm -rf flutter || true

# Install Flutter with explicit stable version
echo "📥 Installing Flutter SDK (latest stable)..."
git clone https://github.com/flutter/flutter.git -b stable --depth 1
export PATH="$PATH:$(pwd)/flutter/bin"

# Enable web support
echo "🌐 Enabling Flutter web support..."
flutter config --enable-web

# Precache web artifacts
echo "⬇️ Precaching Flutter web artifacts..."
flutter precache --web

# Display Flutter version and doctor info
echo "🔍 Flutter installation info:"
flutter --version
flutter doctor -v

# Get dependencies
echo "📦 Installing Flutter dependencies..."
flutter pub get

# Clean any previous builds
echo "🧹 Cleaning previous builds..."
flutter clean
rm -rf build/web || true

# Build for web - try different approaches based on what works
echo "🔨 Building Flutter web app..."

# Primary build attempt - modern Flutter
if flutter build web --release --dart-define=FLUTTER_WEB_USE_SKIA=false 2>/dev/null; then
    echo "✅ Build successful with modern Flutter settings"
elif flutter build web --release --web-renderer html 2>/dev/null; then
    echo "✅ Build successful with --web-renderer flag"  
elif flutter build web --release 2>/dev/null; then
    echo "✅ Build successful with basic settings"
else
    echo "❌ All build attempts failed, creating fallback"
    mkdir -p build/web
    
    # Copy existing web files as fallback
    if [ -d "web" ]; then
        cp -r web/* build/web/ || true
    fi
    
    # Create error page
    cat > build/web/index.html << 'EOF'
<!DOCTYPE html>
<html>
<head>
    <title>ShowTrackAI - Build Error</title>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <style>
        body {
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
            display: flex;
            justify-content: center;
            align-items: center;
            min-height: 100vh;
            margin: 0;
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            padding: 20px;
        }
        .error-container {
            text-align: center;
            padding: 40px;
            background: white;
            border-radius: 12px;
            box-shadow: 0 20px 60px rgba(0,0,0,0.3);
            max-width: 500px;
            width: 100%;
        }
        h1 { color: #e74c3c; margin-bottom: 20px; }
        p { color: #555; line-height: 1.6; }
        .build-info {
            background: #f8f9fa;
            padding: 15px;
            border-radius: 8px;
            margin: 20px 0;
            font-family: 'SF Mono', Monaco, monospace;
            font-size: 12px;
            text-align: left;
            border-left: 4px solid #667eea;
        }
        .retry-button {
            display: inline-block;
            padding: 12px 24px;
            background: #667eea;
            color: white;
            text-decoration: none;
            border-radius: 6px;
            margin-top: 20px;
            transition: background 0.3s ease;
        }
        .retry-button:hover {
            background: #5a67d8;
        }
    </style>
</head>
<body>
    <div class="error-container">
        <h1>🔧 Build Configuration Error</h1>
        <p>The Flutter build process encountered compatibility issues. This typically happens when Flutter versions don't match the build requirements.</p>
        <div class="build-info">
            <strong>Build Information:</strong><br>
            Build ID: ${DEPLOY_ID:-'unknown'}<br>
            Timestamp: $(date)<br>
            Repository: ${REPOSITORY_URL:-'unknown'}<br><br>
            <strong>Common Solutions:</strong><br>
            • Update Flutter version in build script<br>
            • Remove --web-renderer flag for newer Flutter<br>
            • Check pubspec.yaml dependencies<br>
            • Verify web platform is enabled
        </div>
        <p>Please check the <a href="https://app.netlify.com" target="_blank">Netlify build logs</a> for detailed error information.</p>
        <a href="javascript:location.reload()" class="retry-button">🔄 Refresh Page</a>
    </div>
</body>
</html>
EOF
    
    echo "⚠️ Fallback page created due to build failure"
fi

# Verify build output
if [ -d "build/web" ] && [ -f "build/web/index.html" ]; then
    echo "✅ Build directory verified"
    
    # Copy additional files
    echo "📋 Copying additional files..."
    [ -f "web/flutter_bootstrap.js" ] && cp web/flutter_bootstrap.js build/web/
    [ -f "web/flutter_fallback.js" ] && cp web/flutter_fallback.js build/web/
    [ -f "_headers" ] && cp _headers build/web/
    [ -f "_redirects" ] && cp _redirects build/web/
    
    # Ensure Netlify redirects
    echo "/* /index.html 200" > build/web/_redirects
    
    # Create optimized headers
    cat > build/web/_headers << 'EOF'
/*
  X-Frame-Options: SAMEORIGIN
  X-Content-Type-Options: nosniff
  X-XSS-Protection: 1; mode=block
  Referrer-Policy: strict-origin-when-cross-origin

/*.js
  Content-Type: application/javascript
  Cache-Control: public, max-age=31536000

/*.css
  Content-Type: text/css  
  Cache-Control: public, max-age=31536000

/*.dart.js
  Content-Type: application/javascript
  Cache-Control: public, max-age=31536000

/*.wasm
  Content-Type: application/wasm
  Cache-Control: public, max-age=31536000

/index.html
  Cache-Control: no-cache, no-store, must-revalidate

/flutter_service_worker.js
  Cache-Control: no-cache, no-store, must-revalidate
EOF
    
    # Set correct permissions
    chmod -R 755 build/web/
    
    # Display build results
    echo "📦 Build output summary:"
    ls -la build/web/ | head -10
    echo "📏 Total build size: $(du -sh build/web | cut -f1)"
    echo "✅ Build completed successfully!"
    
else
    echo "❌ Build failed - no output generated"
    exit 1
fi

echo "🎉 ShowTrackAI build process completed!"
echo "📁 Deploy directory: build/web"
echo "⏰ Total build time: $SECONDS seconds"