#!/bin/bash

# Build Flutter web app with HTML renderer specifically
echo "🚀 Building Flutter web app with HTML renderer..."

# Clean previous builds
echo "🧹 Cleaning previous builds..."
flutter clean

# Get dependencies
echo "📦 Getting dependencies..."
flutter pub get

# Build web with HTML renderer
echo "🔨 Building web app with HTML renderer..."
flutter build web \
  --base-href "/" \
  --dart-define=FLUTTER_WEB_USE_SKIA=false \
  --dart-define=FLUTTER_WEB_AUTO_DETECT=false \
  --release

echo "✅ Build complete!"
echo "📁 Built files are in: build/web/"
echo "🌐 Test at: http://localhost:8087"