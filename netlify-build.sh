#!/usr/bin/env bash
# netlify-build.sh
# Flutter web build script for Netlify

set -e  # exit on first error

echo "▶️  Starting Flutter web build"

# Print build info
echo "🔍 Build Information:"
echo "   Git Commit: $(git rev-parse HEAD || echo 'unknown')"
echo "   Git Branch: ${BRANCH:-unknown}"
echo "   Build Time: $(date -u '+%Y-%m-%d %H:%M:%S UTC')"

# Install Flutter if not already present
if [ ! -d "$HOME/flutter/bin" ]; then
  echo "⤵️  Installing Flutter (${FLUTTER_CHANNEL:-stable})…"
  git clone --branch ${FLUTTER_CHANNEL:-stable} https://github.com/flutter/flutter.git $HOME/flutter
fi

export PATH="$HOME/flutter/bin:$PATH"
flutter --version

# Enable Flutter web if not already
flutter config --enable-web

# Clean & fetch dependencies
echo "🧹 flutter clean"
flutter clean
echo "📚 flutter pub get"
flutter pub get

# Build Flutter web app with optimized settings for Netlify
echo "🏗️  flutter build web --release"
flutter build web --release \
  --dart-define SUPABASE_URL=${SUPABASE_URL} \
  --dart-define SUPABASE_ANON_KEY=${SUPABASE_ANON_KEY} \
  --dart-define OPENWEATHER_API_KEY=${OPENWEATHER_API_KEY} \
  --dart-define FLUTTER_ENVIRONMENT=production \
  --dart-define NETLIFY=true \
  --dart-define DEMO_EMAIL=${DEMO_EMAIL} \
  --dart-define DEMO_PASSWORD=${DEMO_PASSWORD}

# Check if build was successful
if [ ! -d "build/web" ] || [ ! -f "build/web/index.html" ]; then
  echo "❌ Build failed - build/web directory or index.html not found"
  exit 1
fi

# Verify build output
echo "🔍 Verifying build output:"
ls -la build/web/
echo "✅ Build completed. Files in build/web/"

# Create build info file for debugging
echo "Build completed at: $(date -u '+%Y-%m-%d %H:%M:%S UTC')" > build/web/build-info.txt
echo "Git commit: $(git rev-parse HEAD || echo 'unknown')" >> build/web/build-info.txt
echo "Git branch: ${BRANCH:-unknown}" >> build/web/build-info.txt
