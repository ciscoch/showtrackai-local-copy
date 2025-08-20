#!/bin/bash

# Netlify build script for Flutter web app
echo "🚀 Starting Flutter web build for ShowTrackAI..."

# Exit on error
set -e

# Install Flutter if not already installed
if [ ! -d "$HOME/flutter" ]; then
  echo "📦 Installing Flutter..."
  git clone https://github.com/flutter/flutter.git -b stable --depth 1 $HOME/flutter
fi

# Add Flutter to PATH
export PATH="$HOME/flutter/bin:$PATH"

# Verify Flutter installation
flutter --version

# Enable web support
flutter config --enable-web

# Clean and get dependencies
echo "🧹 Cleaning and getting dependencies..."
flutter clean
flutter pub get

# Build for web with Supabase configuration
echo "🔨 Building Flutter web app..."
# Note: Flutter 3.35.1+ uses --web-renderer-mode instead of --web-renderer
flutter build web --release \
  --dart-define=SUPABASE_URL=$SUPABASE_URL \
  --dart-define=SUPABASE_ANON_KEY=$SUPABASE_ANON_KEY

echo "✅ Build complete!"

# The output will be in build/web which Netlify will deploy