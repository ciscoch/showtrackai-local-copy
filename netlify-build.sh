#!/bin/bash
set -e

echo "🚀 Starting ShowTrackAI build for Netlify"
echo "📍 Current directory: $(pwd)"
echo "📦 Flutter version: ${FLUTTER_VERSION:-3.27.1}"

# Install Flutter if not cached
if [ ! -d "$HOME/flutter" ]; then
  echo "📥 Installing Flutter ${FLUTTER_VERSION:-3.27.1}..."
  git clone https://github.com/flutter/flutter.git -b stable --depth 1 "$HOME/flutter"
fi

# Add Flutter to PATH
export PATH="$HOME/flutter/bin:$PATH"

# Show Flutter version
flutter --version

# Enable web support
flutter config --enable-web

# Clean previous build
echo "🧹 Cleaning previous build..."
flutter clean

# Get dependencies
echo "📚 Getting dependencies..."
flutter pub get

# Build for web
echo "🏗️ Building Flutter web app..."
flutter build web --release \
  --dart-define=SUPABASE_URL=${SUPABASE_URL} \
  --dart-define=SUPABASE_ANON_KEY=${SUPABASE_ANON_KEY} \
  --dart-define=FLUTTER_ENVIRONMENT=production \
  --dart-define=DEMO_EMAIL=${DEMO_EMAIL} \
  --dart-define=DEMO_PASSWORD=${DEMO_PASSWORD}

echo "✅ Build completed successfully!"
echo "📁 Output directory: build/web"
ls -la build/web/