#!/bin/bash

set -e  # Exit on error

echo "🚀 Building ShowTrackAI for Netlify deployment..."
echo "Current directory: $(pwd)"
echo "Contents: $(ls -la)"

# Install Flutter if not present on Netlify
if ! command -v flutter &> /dev/null; then
    echo "📥 Installing Flutter SDK for Netlify build..."
    
    # Download Flutter stable branch
    git clone https://github.com/flutter/flutter.git -b stable --depth 1
    export PATH="$PATH:$(pwd)/flutter/bin"
    
    # Verify installation
    flutter --version
    flutter doctor -v
else
    echo "✅ Flutter already installed"
    flutter --version
fi

# Clean previous builds
echo "🧹 Cleaning previous builds..."
rm -rf build/web || true
flutter clean || true

# Get dependencies
echo "📦 Getting dependencies..."
flutter pub get

# Build for web with HTML renderer (more compatible)
echo "🔨 Building for web with HTML renderer..."
flutter build web --release --web-renderer html --no-tree-shake-icons

# Verify build directory exists
if [ ! -d "build/web" ]; then
    echo "⚠️ Build directory not created, creating fallback..."
    mkdir -p build/web
    
    # Copy web files as emergency fallback
    if [ -d "web" ]; then
        echo "📋 Using web directory as fallback..."
        cp -r web/* build/web/ 2>/dev/null || true
    fi
    
    # Create error page if build completely failed
    if [ ! -f "build/web/index.html" ]; then
        cat > build/web/index.html << 'HTML'
<!DOCTYPE html>
<html>
<head>
    <title>ShowTrackAI - Build Error</title>
    <meta charset="UTF-8">
    <style>
        body {
            font-family: Arial, sans-serif;
            display: flex;
            justify-content: center;
            align-items: center;
            height: 100vh;
            margin: 0;
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
        }
        .error-container {
            text-align: center;
            padding: 40px;
            background: white;
            border-radius: 10px;
            box-shadow: 0 10px 40px rgba(0,0,0,0.2);
            max-width: 500px;
        }
        h1 { color: #e74c3c; }
        p { color: #555; line-height: 1.6; }
        .details {
            background: #f8f9fa;
            padding: 15px;
            border-radius: 5px;
            margin: 20px 0;
            font-family: monospace;
            font-size: 12px;
            text-align: left;
        }
        a {
            color: #667eea;
            text-decoration: none;
            font-weight: bold;
        }
    </style>
</head>
<body>
    <div class="error-container">
        <h1>Build Configuration Error</h1>
        <p>The Flutter build process encountered an issue during deployment.</p>
        <div class="details">
            <strong>Possible causes:</strong><br>
            • Flutter SDK installation failed<br>
            • Missing dependencies in pubspec.yaml<br>
            • Build configuration error<br>
            • Memory limit exceeded during build<br><br>
            Please check the Netlify build logs for details.
        </div>
        <p><a href="/test.html">View Test Page</a> | <a href="https://app.netlify.com">Netlify Dashboard</a></p>
    </div>
</body>
</html>
HTML
    fi
else
    echo "✅ Build directory created successfully"
fi

# Copy custom files if they exist and build succeeded
if [ -d "build/web" ]; then
    echo "📋 Copying custom files..."
    [ -f "web/flutter_bootstrap.js" ] && cp web/flutter_bootstrap.js build/web/ 2>/dev/null || true
    [ -f "web/flutter_fallback.js" ] && cp web/flutter_fallback.js build/web/ 2>/dev/null || true
    [ -f "web/test.html" ] && cp web/test.html build/web/ 2>/dev/null || true
    
    # Only overwrite index.html if we have a custom one and build likely failed
    if [ -f "web/index.html" ] && [ ! -f "build/web/main.dart.js" ]; then
        echo "⚠️ main.dart.js not found, using custom index.html"
        cp web/index.html build/web/
    fi
fi

# Ensure proper permissions
chmod -R 755 build/web/ 2>/dev/null || true

# Create _redirects file for Netlify SPA routing
echo "/* /index.html 200" > build/web/_redirects

# Create _headers file to handle CSP and permissions
cat > build/web/_headers << 'EOF'
/*
  X-Frame-Options: SAMEORIGIN
  X-Content-Type-Options: nosniff
  Referrer-Policy: strict-origin-when-cross-origin
  Permissions-Policy: camera=(), microphone=(), geolocation=()
  Content-Security-Policy: default-src 'self' https://*.netlify.com https://*.netlify.app; script-src 'self' 'unsafe-inline' 'unsafe-eval' https://*.netlify.com; style-src 'self' 'unsafe-inline'; img-src 'self' data: https:; font-src 'self' data:; connect-src 'self' https://*.supabase.co https://*.netlify.com wss://*.supabase.co; frame-src 'self' https://*.netlify.com https://*.netlify.app;
EOF

# List build output for debugging
echo "📦 Build directory contents:"
ls -la build/web/ | head -20

echo "✅ Build script complete!"
echo "📁 Build output: build/web/"
echo "📏 Size: $(du -sh build/web 2>/dev/null | cut -f1 || echo 'unknown')"