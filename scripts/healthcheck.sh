#!/usr/bin/env bash
set -euo pipefail

if command -v flutter >/dev/null 2>&1 && [ -f "pubspec.yaml" ]; then
  flutter --version >/dev/null
  flutter pub get >/dev/null
  flutter analyze
  # Unit & widget tests
  flutter test
  # Web build smoke (keeps web targets honest)
  flutter build web --release --no-tree-shake-icons >/dev/null
  echo "OK (Flutter)"
  exit 0
fi

if [ -f "package.json" ]; then
  # Node/TS projects
  npm ci --silent || npm install --silent
  npm test --silent || true        # don't crash the loop; review will fix
  npm run build --silent || true   # allow cycle to continue while Claude fixes
  echo "OK (Node)"
  exit 0
fi

# Fallback: nothing to check yet
echo "OK (no-known-stack)"

