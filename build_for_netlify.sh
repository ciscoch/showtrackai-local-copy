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

echo "🔧 which flutter: $(which flutter)"
flutter --version || true
flutter config --no-analytics 2>/dev/null || true
flutter doctor -v || true

# --- Clean & deps ---
echo "🧹 Cleaning previous builds..."
rm -rf build/web || true
flutter clean || true

echo "📦 flutter pub get ..."
flutter pub get

flutter config --enable-web 2>/dev/null || true

# --- Detect build flag support (older Flutter may not have them) ---
WEB_HELP="$(flutter build web -h 2>&1 || true)"
HAS_WEB_RENDERER=0
HAS_PWA_STRATEGY=0
HAS_NO_WASM_DRY_RUN=0

echo "$WEB_HELP" | grep -q -- '--web-renderer'      && HAS_WEB_RENDERER=1
echo "$WEB_HELP" | grep -q -- '--pwa-strategy'      && HAS_PWA_STRATEGY=1
echo "$WEB_HELP" | grep -q -- '--no-wasm-dry-run'   && HAS_NO_WASM_DRY_RUN=1

echo "🔎 Flag support: web-renderer=$HAS_WEB_RENDERER, pwa-strategy=$HAS_PWA_STRATEGY, no-wasm-dry-run=$HAS_NO_WASM_DRY_RUN"

# --- Build command (compose safely for any Flutter) ---
BUILD_ARGS=(build web --release --no-tree-shake-icons)
[ "$HAS_WEB_RENDERER"   -eq 1 ] && BUILD_ARGS+=("--web-renderer=html")
[ "$HAS_NO_WASM_DRY_RUN" -eq 1 ] && BUILD_ARGS+=("--no-wasm-dry-run")
[ "$HAS_PWA_STRATEGY"   -eq 1 ] && BUILD_ARGS+=("--pwa-strategy=none")

echo "🔨 flutter ${BUILD_ARGS[*]}"
if ! flutter "${BUILD_ARGS[@]}"; then
  echo "⚠️ Primary build failed. Retrying with minimal flags…"
  flutter build web --release || { echo "❌ Build failed"; exit 1; }
fi

# --- Verify output ---
[ -f "build/web/main.dart.js" ] || { echo "❌ build/web/main.dart.js missing"; exit 1; }
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

# --- SPA routing ---
echo "/* /index.html 200" > build/web/_redirects

# --- Runtime headers (authoritative; Netlify warns if toml headers are malformed) ---
cat > build/web/_headers <<'HEADERS'
/*
  X-Frame-Options: SAMEORIGIN
  X-Content-Type-Options: nosniff
  Referrer-Policy: strict-origin-when-cross-origin
  Permissions-Policy: camera=(), microphone=(), geolocation=()
  # CSP fits HTML renderer path; fonts/CDNs allowed if used.
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

chmod -R 755 build/web || true
echo "📦 build/web (top 30):"
ls -la build/web | head -30

echo "✅ Done. Publish dir: build/web"
