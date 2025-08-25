#!/bin/bash

echo "🚀 Building ShowTrackAI for Netlify deployment..."

# Clean previous builds
echo "🧹 Cleaning previous builds..."
flutter clean

# Get dependencies
echo "📦 Getting dependencies..."
flutter pub get

# Build for web with HTML renderer (more compatible)
echo "🔨 Building for web with HTML renderer..."
flutter build web --release

# Copy our custom bootstrap files to build directory
echo "📋 Copying custom bootstrap files..."
cp web/flutter_bootstrap.js build/web/
cp web/index.html build/web/
cp web/flutter_build_metadata.json build/web/

# Ensure proper permissions
chmod -R 755 build/web/

# Create _redirects file for Netlify SPA routing
echo "/* /index.html 200" > build/web/_redirects

# Create _headers file to handle CSP and permissions
cat > build/web/_headers << EOF
/*
  X-Frame-Options: DENY
  X-Content-Type-Options: nosniff
  Referrer-Policy: strict-origin-when-cross-origin
  Permissions-Policy: camera=(), microphone=(), geolocation=()
EOF

echo "✅ Build complete! Ready for Netlify deployment."
echo "📁 Build output: build/web/"