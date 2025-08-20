#!/bin/bash

# Optimized Netlify build script for Flutter web app
echo "🚀 Starting Flutter web build for ShowTrackAI..."

# Exit on any error, treat unset variables as error, catch pipe failures
set -euo pipefail

# Function to log with timestamp
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1"
}

# Function to handle errors
handle_error() {
    log "❌ Error occurred on line $1"
    log "Build failed. Check logs above for details."
    exit 1
}

# Set error trap
trap 'handle_error $LINENO' ERR

# Set default values for environment variables
export FLUTTER_VERSION=${FLUTTER_VERSION:-"stable"}
export FLUTTER_CHANNEL=${FLUTTER_CHANNEL:-"stable"}
export FLUTTER_ROOT=${FLUTTER_ROOT:-"$HOME/flutter"}
export FLUTTER_BIN="$FLUTTER_ROOT/bin"

log "📋 Build environment info:"
log "  - Node version: $(node --version 2>/dev/null || echo 'Not installed')"
log "  - Current directory: $(pwd)"
log "  - User: $(whoami)"
log "  - Flutter version: ${FLUTTER_VERSION}"
log "  - Flutter channel: ${FLUTTER_CHANNEL}"

# Try to use existing Flutter installation first
if [ -d "$FLUTTER_ROOT" ] && [ -f "$FLUTTER_BIN/flutter" ]; then
    log "✅ Using existing Flutter installation"
    export PATH="$FLUTTER_BIN:$PATH"
else
    # Install Flutter if not found
    log "📦 Installing Flutter $FLUTTER_VERSION..."
    
    # Remove any partial installation
    if [ -d "$FLUTTER_ROOT" ]; then
        rm -rf "$FLUTTER_ROOT"
    fi
    
    # Create flutter directory
    mkdir -p "$HOME"
    
    # Download and extract Flutter with optimizations
    cd "$HOME"
    
    # Use wget if available (faster), otherwise git
    if command -v wget >/dev/null 2>&1; then
        log "Using wget for faster download..."
        FLUTTER_URL="https://storage.googleapis.com/flutter_infra_release/releases/stable/linux/flutter_linux_3.19.0-stable.tar.xz"
        wget -q --show-progress -O flutter.tar.xz "$FLUTTER_URL"
        tar xf flutter.tar.xz
        rm flutter.tar.xz
    else
        log "Using git clone..."
        git clone https://github.com/flutter/flutter.git -b $FLUTTER_CHANNEL --depth 1 flutter
    fi
    
    export PATH="$FLUTTER_BIN:$PATH"
    log "✅ Flutter installed successfully"
fi

# Verify Flutter installation
if ! command -v flutter >/dev/null 2>&1; then
    log "❌ Flutter command not found in PATH"
    exit 1
fi

# Show Flutter version
log "📋 Flutter version info:"
flutter --version

# Preconfigure Flutter to avoid interactive prompts
log "⚙️ Configuring Flutter..."
flutter config --no-analytics --no-cli-animations
flutter config --enable-web

# Check if this is a Flutter project
if [ ! -f "pubspec.yaml" ]; then
    log "❌ pubspec.yaml not found. This doesn't appear to be a Flutter project."
    exit 1
fi

# Clean previous builds
log "🧹 Cleaning previous builds..."
if [ -d "build" ]; then
    rm -rf build
fi

# Clear Flutter cache to avoid version conflicts
flutter clean

# Update dependencies with retry logic
log "📦 Getting dependencies..."
for i in {1..3}; do
    if flutter pub get; then
        log "✅ Dependencies resolved successfully"
        break
    else
        log "⚠️ Attempt $i failed, retrying..."
        if [ $i -eq 3 ]; then
            log "❌ Failed to get dependencies after 3 attempts"
            exit 1
        fi
        sleep 5
    fi
done

# Check if web directory exists, create if needed
if [ ! -d "web" ]; then
    log "⚠️ Web directory not found, creating..."
    flutter create --platform web .
fi

# Verify essential web files exist
REQUIRED_FILES=("web/index.html" "web/manifest.json")
for file in "${REQUIRED_FILES[@]}"; do
    if [ ! -f "$file" ]; then
        log "❌ Required file $file is missing"
        exit 1
    fi
done

log "✅ All required web files present"

# Set build arguments
BUILD_ARGS="--release --no-tree-shake-icons"

# Add environment variables if they exist
if [ -n "${SUPABASE_URL:-}" ]; then
    BUILD_ARGS="$BUILD_ARGS --dart-define=SUPABASE_URL=$SUPABASE_URL"
    log "✅ SUPABASE_URL configured"
fi

if [ -n "${SUPABASE_ANON_KEY:-}" ]; then
    BUILD_ARGS="$BUILD_ARGS --dart-define=SUPABASE_ANON_KEY=$SUPABASE_ANON_KEY"
    log "✅ SUPABASE_ANON_KEY configured"
fi

# Build the Flutter web app
log "🔨 Building Flutter web app with args: $BUILD_ARGS"
flutter build web $BUILD_ARGS

# Verify build output
if [ ! -d "build/web" ]; then
    log "❌ Build directory not created"
    exit 1
fi

if [ ! -f "build/web/index.html" ]; then
    log "❌ index.html not found in build output"
    exit 1
fi

# Show build output size
BUILD_SIZE=$(du -sh build/web 2>/dev/null | cut -f1 || echo "Unknown")
log "📊 Build output size: $BUILD_SIZE"

# List key files in build directory
log "📋 Build output contents:"
ls -la build/web/ | head -10

# Verify critical files exist in build
CRITICAL_FILES=("build/web/index.html" "build/web/flutter.js" "build/web/flutter_bootstrap.js")
for file in "${CRITICAL_FILES[@]}"; do
    if [ -f "$file" ]; then
        log "✅ $file exists"
    else
        log "⚠️ $file missing (may be normal for newer Flutter versions)"
    fi
done

# Create a simple health check file
echo "Build completed at $(date)" > build/web/build-info.txt
echo "Flutter version: $(flutter --version | head -n1)" >> build/web/build-info.txt
echo "Build size: $BUILD_SIZE" >> build/web/build-info.txt

log "✅ Flutter web build completed successfully!"
log "📤 Build output is ready in build/web directory"

# Final verification
if [ "$(ls -A build/web)" ]; then
    log "✅ Build directory is not empty"
    exit 0
else
    log "❌ Build directory is empty"
    exit 1
fi