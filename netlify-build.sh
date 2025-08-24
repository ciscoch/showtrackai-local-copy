#!/usr/bin/env bash
# netlify-build.sh
# Clean Flutter web build script for Netlify - HTML renderer only

set -e  # exit on first error

echo "🚀 Starting Fresh Flutter Web Build (HTML Renderer Only)"

# Print build info
echo "📋 Build Information:"
echo "   Git Commit: $(git rev-parse HEAD || echo 'unknown')"
echo "   Git Branch: ${BRANCH:-unknown}"
echo "   Build Time: $(date -u '+%Y-%m-%d %H:%M:%S UTC')"

# Install Flutter if not already present
if [ ! -d "$HOME/flutter/bin" ]; then
  echo "⤵️  Installing Flutter stable..."
  git clone --branch stable https://github.com/flutter/flutter.git $HOME/flutter
fi

export PATH="$HOME/flutter/bin:$PATH"
flutter --version

# Enable Flutter web
flutter config --enable-web

# Clean everything thoroughly
echo "🧹 Deep clean..."
flutter clean
rm -rf build/ .dart_tool/ .flutter-plugins-dependencies || true

# Get dependencies
echo "📚 flutter pub get"
flutter pub get

# Verify environment variables
echo "🔍 Checking environment variables:"
echo "   SUPABASE_URL: ${SUPABASE_URL:0:30}..."
echo "   SUPABASE_ANON_KEY: ${SUPABASE_ANON_KEY:0:30}..."
echo "   OPENWEATHER_API_KEY: ${OPENWEATHER_API_KEY:0:10}..."

# Build for web with HTML renderer (configured in web/index.html)
echo "🏗️  Building Flutter web app (HTML renderer, no external dependencies)..."
flutter build web --release \
  --no-web-resources-cdn \
  --csp \
  --dart-define SUPABASE_URL="${SUPABASE_URL}" \
  --dart-define SUPABASE_ANON_KEY="${SUPABASE_ANON_KEY}" \
  --dart-define OPENWEATHER_API_KEY="${OPENWEATHER_API_KEY}" \
  --dart-define FLUTTER_ENVIRONMENT=production \
  --dart-define NETLIFY=true \
  --dart-define DEMO_EMAIL="${DEMO_EMAIL}" \
  --dart-define DEMO_PASSWORD="${DEMO_PASSWORD}"

# Verify build was successful
if [ ! -d "build/web" ] || [ ! -f "build/web/index.html" ]; then
  echo "❌ Build failed - build/web directory or index.html not found"
  exit 1
fi

# Clean up for HTML renderer deployment
echo "🔧 Optimizing for HTML renderer..."

# Remove CanvasKit files completely (not needed for HTML renderer)
echo "🗑️  Removing CanvasKit files..."
rm -rf build/web/canvaskit/ || true

# Remove any WASM files
find build/web -name "*.wasm" -type f -delete 2>/dev/null || true

# Remove any source maps to reduce size
find build/web -name "*.map" -type f -delete 2>/dev/null || true

# Ensure flutter_bootstrap.js is in build output
echo "📋 Copying flutter_bootstrap.js..."
cp web/flutter_bootstrap.js build/web/ || echo "⚠️  flutter_bootstrap.js not found in web/"

# Verify no CanvasKit references in main.dart.js
echo "🔍 Checking for CanvasKit references..."
if grep -q "canvaskit\|CanvasKit" build/web/main.dart.js 2>/dev/null; then
    echo "⚠️  CanvasKit references found in main.dart.js - this should be HTML renderer only"
else
    echo "✅ No CanvasKit references found - clean HTML renderer build"
fi

# Verify critical files exist
echo "✅ Verifying build output:"
ls -la build/web/
echo ""

# Check for main files
if [ -f "build/web/flutter.js" ]; then
  echo "✅ flutter.js found"
else
  echo "❌ flutter.js missing!"
  exit 1
fi

if [ -f "build/web/main.dart.js" ]; then
  echo "✅ main.dart.js found"
else
  echo "❌ main.dart.js missing!"
  exit 1
fi

# Create build info file
echo "Build completed: $(date -u '+%Y-%m-%d %H:%M:%S UTC')" > build/web/build-info.txt
echo "Git commit: $(git rev-parse HEAD || echo 'unknown')" >> build/web/build-info.txt
echo "Git branch: ${BRANCH:-unknown}" >> build/web/build-info.txt
echo "Renderer: HTML only" >> build/web/build-info.txt

# Display build size info
echo "📊 Build size information:"
du -sh build/web/
echo ""

echo "✅ Clean Flutter web build completed successfully!"
echo "🎯 Ready for deployment with HTML renderer only"