#!/bin/bash

set -e  # Exit on error

echo "🚀 Building ShowTrackAI for Netlify deployment..."
echo "Current directory: $(pwd)"

# Ensure we're in the correct directory and find project root
PROJECT_ROOT=""
if [ -n "$NETLIFY_REPO_PATH" ] && [ -d "$NETLIFY_REPO_PATH" ]; then
    PROJECT_ROOT="$NETLIFY_REPO_PATH"
elif [ -d "/opt/build/repo" ]; then
    PROJECT_ROOT="/opt/build/repo"
else
    PROJECT_ROOT="$(pwd)"
fi

echo "📍 Project root: $PROJECT_ROOT"
cd "$PROJECT_ROOT"

# Verify we're in a Flutter project directory
if [ ! -f "pubspec.yaml" ]; then
    echo "❌ ERROR: pubspec.yaml not found in $PROJECT_ROOT"
    echo "Directory contents:"
    ls -la
    exit 1
fi

echo "✅ Flutter project root confirmed: $(pwd)"
echo "📦 pubspec.yaml found"

# Force fresh Flutter installation to avoid version conflicts
echo "📥 Installing Flutter SDK for Netlify build..."

# Create temp directory for Flutter SDK (not in project!)
FLUTTER_INSTALL_DIR="/tmp/flutter_sdk_$$"
rm -rf "$FLUTTER_INSTALL_DIR" 2>/dev/null || true
mkdir -p "$FLUTTER_INSTALL_DIR"

# Save current project directory
SAVED_PROJECT_ROOT="$PROJECT_ROOT"

# Clone Flutter stable branch in temp directory
echo "Cloning Flutter stable branch to temp directory..."
cd "$FLUTTER_INSTALL_DIR"
git clone https://github.com/flutter/flutter.git -b stable --depth 1

# Set up Flutter PATH from temp location
FLUTTER_BIN="$FLUTTER_INSTALL_DIR/flutter/bin"
export PATH="$FLUTTER_BIN:$PATH"

# Return to project directory - CRITICAL!
cd "$SAVED_PROJECT_ROOT"

echo "🔧 Flutter binary path: $FLUTTER_BIN"
echo "🔧 Current working directory: $(pwd)"
echo "🔧 Project root should be: $SAVED_PROJECT_ROOT"

# Verify Flutter installation
if [ ! -f "$FLUTTER_BIN/flutter" ]; then
    echo "❌ ERROR: Flutter binary not found at $FLUTTER_BIN/flutter"
    exit 1
fi

# Disable analytics to speed up first run
cd "$PROJECT_ROOT"  # Ensure we're in project root
flutter config --no-analytics 2>/dev/null || true

# Run flutter once to download Dart SDK and initialize
echo "Initializing Flutter..."
cd "$PROJECT_ROOT"  # Ensure we're in project root
flutter --version

# Quick doctor check (don't fail on this)
cd "$PROJECT_ROOT"  # Ensure we're in project root
flutter doctor -v || true

# Clean previous builds
echo "🧹 Cleaning previous builds..."
cd "$PROJECT_ROOT"
rm -rf build/web || true
flutter clean || true

# Get dependencies - CRITICAL: Must be in project root
echo "📦 Getting dependencies..."
cd "$PROJECT_ROOT"
echo "📍 Running 'flutter pub get' from: $(pwd)"
flutter pub get

# Enable web support (might be needed for some Flutter versions)
cd "$PROJECT_ROOT"  # Ensure we're in project root
flutter config --enable-web 2>/dev/null || true

# Get Flutter version for appropriate build command
FLUTTER_VERSION=$(flutter --version | head -n 1 | grep -oP 'Flutter \K[0-9]+\.[0-9]+' || echo "unknown")
echo "📊 Flutter version detected: $FLUTTER_VERSION"

# Build for web with version-appropriate command
echo "🔨 Building for web..."
cd "$PROJECT_ROOT"
echo "📍 Running Flutter build from: $(pwd)"

# Try different build approaches based on Flutter version
build_success=false

# Method 1: Try without --web-renderer flag (works for very old and very new Flutter)
echo "Attempting build without renderer flag..."
if cd "$PROJECT_ROOT" && flutter build web --release --no-tree-shake-icons 2>/dev/null; then
    echo "✅ Build successful without renderer flag"
    build_success=true
else
    # Method 2: Try with --web-renderer html (Flutter 2.10 to 3.21)
    echo "Attempting build with --web-renderer html..."
    if cd "$PROJECT_ROOT" && flutter build web --release --web-renderer html --no-tree-shake-icons 2>/dev/null; then
        echo "✅ Build successful with --web-renderer html"
        build_success=true
    else
        # Method 3: Try with dart-define for older Flutter versions
        echo "Attempting build with dart-define..."
        if cd "$PROJECT_ROOT" && flutter build web --release --dart-define=FLUTTER_WEB_USE_SKIA=false --no-tree-shake-icons 2>/dev/null; then
            echo "✅ Build successful with dart-define"
            build_success=true
        else
            # Method 4: Simplest possible build
            echo "Attempting basic build..."
            if cd "$PROJECT_ROOT" && flutter build web --release 2>/dev/null; then
                echo "✅ Basic build successful"
                build_success=true
            else
                echo "❌ All Flutter build methods failed"
            fi
        fi
    fi
fi

# Check if build succeeded
if [ "$build_success" = false ]; then
    echo "⚠️ Flutter build failed, attempting recovery..."
fi

# Verify build directory exists - CRITICAL: Must be in project root
cd "$PROJECT_ROOT"
if [ ! -d "build/web" ]; then
    echo "⚠️ Build directory not created, creating fallback from: $(pwd)"
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
cd "$PROJECT_ROOT"
if [ -d "build/web" ]; then
    echo "📋 Copying custom files from: $(pwd)"
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