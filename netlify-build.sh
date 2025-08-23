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

# Build for web (HTML renderer configured in web/index.html)
echo "🏗️ Building Flutter web app..."
flutter build web --release \
  --no-tree-shake-icons \
  --dart-define=SUPABASE_URL=${SUPABASE_URL} \
  --dart-define=SUPABASE_ANON_KEY=${SUPABASE_ANON_KEY} \
  --dart-define=FLUTTER_ENVIRONMENT=production \
  --dart-define=DEMO_EMAIL=${DEMO_EMAIL} \
  --dart-define=DEMO_PASSWORD=${DEMO_PASSWORD}

# Remove service worker files to prevent caching issues
echo "🧹 Removing service worker files..."
rm -f build/web/flutter_service_worker.js
# Keep canvaskit directory - it's needed for Flutter Web

# Create a dummy service worker that does nothing
echo "📝 Creating no-op service worker..."
cat > build/web/flutter_service_worker.js << 'EOF'
// No-op service worker to prevent caching issues
self.addEventListener('install', function(event) {
  console.log('No-op service worker installed');
  self.skipWaiting();
});

self.addEventListener('activate', function(event) {
  console.log('No-op service worker activated');
  // Clear all caches
  event.waitUntil(
    caches.keys().then(function(cacheNames) {
      return Promise.all(
        cacheNames.map(function(cacheName) {
          console.log('Deleting cache:', cacheName);
          return caches.delete(cacheName);
        })
      );
    })
  );
  return self.clients.claim();
});

self.addEventListener('fetch', function(event) {
  // Pass through all requests without caching
  event.respondWith(fetch(event.request));
});
EOF

echo "✅ Build completed successfully!"
echo "📁 Output directory: build/web"

# Ensure flutter_bootstrap.js exists and has content
if [ ! -f "build/web/flutter_bootstrap.js" ]; then
  echo "⚠️ flutter_bootstrap.js not found, checking for flutter.js..."
  if [ -f "build/web/flutter.js" ]; then
    echo "📝 Found flutter.js, copying to flutter_bootstrap.js..."
    cp build/web/flutter.js build/web/flutter_bootstrap.js
  fi
fi

# Verify file sizes
echo "🔍 Checking critical files..."
for file in flutter_bootstrap.js flutter.js main.dart.js; do
  if [ -f "build/web/$file" ]; then
    SIZE=$(stat -f%z "build/web/$file" 2>/dev/null || stat -c%s "build/web/$file" 2>/dev/null || echo "0")
    echo "  - $file: $SIZE bytes"
    if [ "$SIZE" = "0" ]; then
      echo "    ⚠️ Warning: $file is empty!"
    fi
  else
    echo "  - $file: NOT FOUND"
  fi
done

ls -la build/web/