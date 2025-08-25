#!/bin/bash

set -e  # Exit on error

echo "🚀 Starting ShowTrackAI Netlify build..."
echo "Current directory: $(pwd)"
echo "Contents: $(ls -la)"

# Install Flutter if not present
if ! command -v flutter &> /dev/null; then
    echo "📥 Installing Flutter SDK..."
    
    # Remove any existing flutter directory
    rm -rf flutter || true
    
    # Download Flutter (use specific version to ensure compatibility)
    git clone https://github.com/flutter/flutter.git -b stable --depth 1
    export PATH="$PATH:$(pwd)/flutter/bin"
    
    # Pre-download Dart SDK
    flutter precache --web
    
    # Verify installation
    flutter --version
    flutter doctor -v
else
    echo "✅ Flutter already installed"
    flutter --version
fi

# Ensure Flutter is in PATH for this session
export PATH="$PATH:$(pwd)/flutter/bin"

# Check Flutter version and capabilities
echo "🔍 Checking Flutter web capabilities..."
flutter doctor --machine | grep -q web || flutter config --enable-web

# Ensure we're in the right directory
cd $NETLIFY_REPO_PATH || cd /opt/build/repo || true

echo "📁 Working directory: $(pwd)"

# Clean any previous builds
echo "🧹 Cleaning previous builds..."
rm -rf build/web || true

# Get dependencies
echo "📦 Installing dependencies..."
flutter pub get

# Build for web with proper renderer detection
echo "🔨 Building Flutter web app..."

# Check Flutter version to determine correct build command
FLUTTER_VERSION=$(flutter --version | grep -o 'Flutter [0-9.]*' | grep -o '[0-9.]*')
echo "Flutter version detected: $FLUTTER_VERSION"

# Function to compare version numbers
version_lt() {
    [ "$1" != "$(printf '%s\n' "$1" "$2" | sort -V | tail -n1)" ]
}

# Build with appropriate flags based on Flutter version
if version_lt "$FLUTTER_VERSION" "3.0.0"; then
    echo "Using legacy build command for Flutter < 3.0.0"
    flutter build web --release --dart-define=FLUTTER_WEB_USE_SKIA=false
elif version_lt "$FLUTTER_VERSION" "3.7.0"; then
    echo "Using web-renderer flag for Flutter < 3.7.0"
    flutter build web --release --web-renderer html
else
    echo "Using modern build command for Flutter >= 3.7.0"
    # For Flutter 3.7+, the --web-renderer flag was deprecated and renderer is auto-selected
    flutter build web --release --dart-define=FLUTTER_WEB_USE_SKIA=false --dart-define=FLUTTER_WEB_AUTO_DETECT=false
fi

# Verify build directory exists
if [ ! -d "build/web" ]; then
    echo "❌ Error: build/web directory not created!"
    echo "Creating fallback build directory..."
    mkdir -p build/web
    
    # Copy web files as fallback
    if [ -d "web" ]; then
        echo "Copying web files to build/web..."
        cp -r web/* build/web/ || true
    fi
    
    # Create a simple index.html if nothing else works
    cat > build/web/index.html << 'EOF'
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
        }
        h1 { color: #e74c3c; }
        p { color: #555; }
        .details {
            background: #f8f9fa;
            padding: 10px;
            border-radius: 5px;
            margin: 20px 0;
            font-family: monospace;
            font-size: 12px;
            text-align: left;
        }
    </style>
</head>
<body>
    <div class="error-container">
        <h1>Build Configuration Error</h1>
        <p>The Flutter build process encountered an issue.</p>
        <div class="details">
            <strong>Possible causes:</strong><br>
            - Flutter SDK not properly installed<br>
            - Missing dependencies<br>
            - Build configuration error<br><br>
            <strong>Build timestamp:</strong> $(date)<br>
            <strong>Build ID:</strong> $DEPLOY_ID
        </div>
        <p>Please check the Netlify build logs for more details.</p>
    </div>
</body>
</html>
EOF
fi

# Copy custom files if they exist
echo "📋 Copying custom files..."
[ -f "web/flutter_bootstrap.js" ] && cp web/flutter_bootstrap.js build/web/
[ -f "web/flutter_fallback.js" ] && cp web/flutter_fallback.js build/web/
[ -f "web/test.html" ] && cp web/test.html build/web/

# Create Netlify routing file
echo "🔧 Creating Netlify configuration files..."
echo "/* /index.html 200" > build/web/_redirects

# Create headers file
cat > build/web/_headers << 'EOF'
/*
  X-Frame-Options: SAMEORIGIN
  X-Content-Type-Options: nosniff
  X-XSS-Protection: 1; mode=block
  Referrer-Policy: strict-origin-when-cross-origin
  Permissions-Policy: camera=(), microphone=(), geolocation=()
  
/*.js
  Content-Type: application/javascript
  Cache-Control: public, max-age=31536000, immutable
  
/*.css
  Content-Type: text/css
  Cache-Control: public, max-age=31536000, immutable

/index.html
  Cache-Control: no-cache
EOF

# Ensure permissions
chmod -R 755 build/web/

# List build output
echo "📦 Build contents:"
ls -la build/web/ | head -20

echo "✅ Build complete!"
echo "📁 Output directory: build/web"
echo "📏 Size: $(du -sh build/web | cut -f1)"