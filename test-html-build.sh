#!/bin/bash
set -e

echo "🧪 Testing HTML renderer build locally..."

# Clean previous build
echo "🧹 Cleaning..."
flutter clean

# Get dependencies
echo "📚 Getting dependencies..."
flutter pub get

# Build for web with HTML renderer
echo "🏗️ Building with HTML renderer..."
flutter build web --release \
  --web-renderer html \
  --no-tree-shake-icons \
  --dart-define=SUPABASE_URL=dummy \
  --dart-define=SUPABASE_ANON_KEY=dummy

# Check build output
echo "📋 Build output contents:"
ls -la build/web/

# Check if CanvasKit files exist (they shouldn't)
if [ -d "build/web/canvaskit" ]; then
  echo "❌ CanvasKit directory still exists - removing it"
  rm -rf build/web/canvaskit/
else
  echo "✅ No CanvasKit directory found"
fi

# Check flutter_bootstrap.js for renderer setting
echo "📝 Checking flutter_bootstrap.js for renderer..."
if grep -q '"renderer":"html"' build/web/flutter_bootstrap.js; then
  echo "✅ HTML renderer configured in flutter_bootstrap.js"
else
  echo "⚠️  Checking for renderer configuration..."
  grep -n "renderer" build/web/flutter_bootstrap.js || echo "No explicit renderer found"
fi

# Remove original service worker and create no-op version
echo "🧹 Removing service worker..."
rm -f build/web/flutter_service_worker.js

# Create no-op service worker
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

echo "✅ Build test completed!"
echo "🌐 You can now serve build/web/ with any HTTP server"
echo "💡 Try: python3 -m http.server 8000 --directory build/web"