#!/usr/bin/env bash
set -euo pipefail

echo "▶️  Starting Flutter web build"

# Git information for debugging
echo "🔍 Build Information:"
echo "   Git Commit: $(git rev-parse HEAD 2>/dev/null || echo 'unknown')"
echo "   Git Branch: $(git branch --show-current 2>/dev/null || echo 'unknown')"
echo "   Build Time: $(date -u +"%Y-%m-%d %H:%M:%S UTC")"

# Which Flutter channel to use (defaults to stable)
FLUTTER_CHANNEL="${FLUTTER_CHANNEL:-stable}"
FLUTTER_REPO="/opt/buildhome/flutter"

# Install Flutter if missing
if [ ! -x "$FLUTTER_REPO/bin/flutter" ]; then
  echo "⤵️  Installing Flutter ($FLUTTER_CHANNEL)…"
  git clone --depth 1 -b "$FLUTTER_CHANNEL" https://github.com/flutter/flutter.git "$FLUTTER_REPO"
fi

export PATH="$FLUTTER_REPO/bin:$PATH"

flutter --version
flutter config --enable-web

# Validate code state before building
echo "🔍 Validating code state..."
if [ -f "lib/services/database/database_error_handler.dart" ]; then
  echo "❌ ERROR: Found outdated file lib/services/database/database_error_handler.dart"
  echo "   This indicates you're building from cached/outdated code."
  exit 1
fi
if [ -f "lib/services/database/database_startup_service.dart" ]; then
  echo "❌ ERROR: Found outdated file lib/services/database/database_startup_service.dart"
  echo "   This indicates you're building from cached/outdated code."
  exit 1
fi
echo "✅ Code validation passed"

echo "🧹 flutter clean"
flutter clean

echo "📚 flutter pub get"
flutter pub get

# Prepare optional flags safely (handle older/newer CLIs)
EXTRA_ARGS=()

# Only add --web-renderer if this Flutter supports it
if flutter build web -h | grep -q -- "--web-renderer"; then
  RENDERER="${FLUTTER_WEB_RENDERER:-auto}"   # html | canvaskit | auto
  case "$RENDERER" in
    html|canvaskit|auto) EXTRA_ARGS+=(--web-renderer "$RENDERER");;
    *) echo "⚠️ Unknown FLUTTER_WEB_RENDERER='$RENDERER' (expected html|canvaskit|auto). Using 'auto'."; EXTRA_ARGS+=(--web-renderer auto);;
  esac
else
  echo "ℹ️  This Flutter version doesn't support --web-renderer; using defaults."
fi

# Optional: strip source maps for smaller output
if [ "${REMOVE_SOURCE_MAPS:-false}" = "true" ]; then
  EXTRA_ARGS+=(--no-source-maps)
fi

# Dart defines (Supabase, environment, etc.)
DEFINES=(
  --dart-define SUPABASE_URL="${SUPABASE_URL:-}"
  --dart-define SUPABASE_ANON_KEY="${SUPABASE_ANON_KEY:-}"
  --dart-define OPENWEATHER_API_KEY="${OPENWEATHER_API_KEY:-}"
  --dart-define FLUTTER_ENVIRONMENT="${FLUTTER_ENVIRONMENT:-production}"
  --dart-define NETLIFY=true
)

# Optional demo creds you’ve been using
if [ -n "${DEMO_EMAIL:-}" ]; then
  DEFINES+=(--dart-define DEMO_EMAIL="${DEMO_EMAIL}")
fi
if [ -n "${DEMO_PASSWORD:-}" ]; then
  DEFINES+=(--dart-define DEMO_PASSWORD="${DEMO_PASSWORD}")
fi
# Pass through CanvasKit URL if you set it
if [ -n "${FLUTTER_WEB_CANVASKIT_URL:-}" ]; then
  # ensure trailing slash to avoid double path join issues
  DEFINES+=(--dart-define FLUTTER_WEB_CANVASKIT_URL="${FLUTTER_WEB_CANVASKIT_URL%/}/")
fi

echo "🏗️  flutter build web --release ${EXTRA_ARGS[*]} ${DEFINES[*]}"
flutter build web --release "${EXTRA_ARGS[@]}" "${DEFINES[@]}"

# Verify output exists
if [ -d "build/web" ]; then
  echo "✅ Build finished. Output in build/web"
else
  echo "❌ Build output not found"
  exit 1
fi
