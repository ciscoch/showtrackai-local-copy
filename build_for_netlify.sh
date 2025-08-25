#!/usr/bin/env bash
set -euo pipefail

echo "🚀 Building ShowTrackAI for Netlify"
echo "📍 CWD: $(pwd)"

# --- Resolve project root ---
PROJECT_ROOT="${NETLIFY_REPO_PATH:-/opt/build/repo}"
[ -d "$PROJECT_ROOT" ] || PROJECT_ROOT="$(pwd)"
cd "$PROJECT_ROOT"
echo "📁 Project root: $PROJECT_ROOT"

# --- Sanity: Flutter project? ---
if [ ! -f "pubspec.yaml" ]; then
  echo "❌ pubspec.yaml not found in $PROJECT_ROOT"
  ls -la
  exit 1
fi
echo "✅ pubspec.yaml found"

# --- Install Flutter (stable) into temp dir (keeps repo clean) ---
FLUTTER_INSTALL_DIR="/tmp/flutter_sdk_$$"
rm -rf "$FLUTTER_INSTALL_DIR" || true
mkdir -p "$FLUTTER_INSTALL_DIR"
echo "📥 Cloning Flutter stable to $FLUTTER_INSTALL_DIR ..."
git clone --depth 1 -b stable https://github.com/flutter/flutter.git "$FLUTTER_INSTALL_DIR/flutter" 1>/dev/null
export PATH="$FLUTTER_INSTALL_DIR/flutter/bin:$PATH"
echo "🔧 Flutter: $(flutter --version | head -n1)"

# --- Quiet analytics + doctor (no-fail) ---
flutter config --no-analytics 2>/dev/null || true
flutter doctor -v || true

# --- Clean & fetch deps ---
echo "🧹 Cleaning previous builds..."
rm -rf build/web || true
flutter clean || true

echo "📦 flutter pub get ..."
flutter pub get

# --- Ensure web is enabled (idempotent) ---
flutter config --enable-web 2>/dev/null || true

# --- Build (HTML renderer only) ---
echo "🔨 Building Web (HTML renderer, no WASM dry-run, disable PWA SW)..."
set -x
if ! flutter build web --release \
  --web-renderer=html \
  --no-wasm-dry-run \
  --no-tree-shake-icons \
  --pwa-strategy=none
then
  # Older Flutter may not support --pwa-strategy; retry without it.
  flutter build web --release \
    --web-renderer=html \
    --no-wasm-dry-run \
    --no-tree-shake-icons
fi
set +x

# --- Verify output ---
if [ ! -f "build/web/main.dart.js" ]; then
  echo "❌ build/web/main.dart.js missing; build failed."
  exit 1
fi
echo "✅ Build output present."

# --- Neutralize service worker if generated anyway ---
if [ -f "build/web/flutter_service_worker.js" ]; then
  echo "🧯 Replacing flutter_service_worker.js with no-op"
  cat > build/web/flutter_service_worker.js <<'JS'
// No-op SW to avoid stale caches between deployments.
self.addEventListener('install', e => self.skipWaiting());
self.addEventListener('activate', e => self.clients.claim());
self.addEventListener('fetch', e => {});
JS
fi

# --- SPA routing (_redirects) ---
echo "/* /index.html 200" > build/web/_redirects

# --- Runtime headers (_headers) ---
cat > build/web/_headers <<'HEADERS'
/*
  X-Frame-Options: SAMEORIGIN
  X-Content-Type-Options: nosniff
  Referrer-Policy: strict-origin-when-cross-origin
  Permissions-Policy: camera=(), microphone=(), geolocation=()
  # CSP fits HTML renderer (no CanvasKit). Fonts/CDN allowed if used.
  Content-Security-Policy: default-src 'self' https://*.netlify.com https://*.netlify.app https://www.gstatic.com https://fonts.gstatic.com; script-src 'self' 'unsafe-inline' 'unsafe-eval' https://*.netlify.com https://www.gstatic.com; style-src 'self' 'unsafe-inline' https://fonts.googleapis.com; img-src 'self' data: https:; font-src 'self' data: https://fonts.gstatic.com; connect-src 'self' https://*.supabase.co wss://*.supabase.co https://*.netlify.com https://fonts.gstatic.com https://www.gstatic.com; frame-src 'self' https://*.netlify.com https://*.netlify.app;

/index.html
  Cache-Control: public, max-age=0, must-revalidate

/flutter.js
  Cache-Control: public, max-age=0, must-revalidate

/flutter_bootstrap.js
  Cache-Control: public, max-age=0, must-revalidate

/main.dart.js
  Cache-Control: public, max-age=0, must-revalidate

/flutter_service_worker.js
  Cache-Control: no-cache, no-store, must-revalidate
  Content-Type: application/javascript

/assets/*
  Cache-Control: public, max-age=31536000, immutable

/*.wasm
  Content-Type: application/wasm
  Cache-Control: public, max-age=31536000, immutable
HEADERS

# --- Permissions & debug listing ---
chmod -R 755 build/web || true
echo "📦 build/web (top 30):"
ls -la build/web | head -30

echo "✅ Done. Publish dir: build/web"
