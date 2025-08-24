<<<<<<< HEAD
[build]
  command = "bash ./netlify-build.sh"
  publish = "build/web"

[build.environment]
  FLUTTER_VERSION = "3.27.1"
  NODE_VERSION = "18"

[context.production.environment]
  FLUTTER_ENVIRONMENT = "production"

# ---------- Security & CSP (HTML renderer, no external fonts/Canvaskit) ----------
[[headers]]
  for = "/*"
  [headers.values]
    X-Frame-Options = "DENY"
    X-XSS-Protection = "1; mode=block"
    X-Content-Type-Options = "nosniff"
    Referrer-Policy = "strict-origin-when-cross-origin"
    Strict-Transport-Security = "max-age=31536000; includeSubDomains; preload"
    # If you later decide to allow Google Fonts, see the "Optional: allow external fonts" note below.
    Content-Security-Policy = "default-src 'self' data: blob:; base-uri 'self'; object-src 'none'; frame-ancestors 'self'; img-src 'self' data: https:; style-src 'self' 'unsafe-inline'; font-src 'self' data:; script-src 'self' 'unsafe-inline' 'unsafe-eval'; connect-src 'self' https://*.supabase.co https://*.supabase.in wss://*.supabase.co wss://*.supabase.in https://showtrackai.app.n8n.cloud; worker-src 'self' blob:;"

# App shell: always revalidate
[[headers]]
  for = "/index.html"
  [headers.values]
    Cache-Control = "public, max-age=0, must-revalidate"

[[headers]]
  for = "/flutter_service_worker.js"
  [headers.values]
    Cache-Control = "public, max-age=0, must-revalidate"

[[headers]]
  for = "/version.json"
  [headers.values]
    Cache-Control = "public, max-age=0, must-revalidate"

# Top-level JS/CSS: revalidate (these filenames aren’t hashed)
[[headers]]
  for = "/*.js"
  [headers.values]
    Cache-Control = "public, max-age=0, must-revalidate"

[[headers]]
  for = "/*.css"
  [headers.values]
    Cache-Control = "public, max-age=0, must-revalidate"

# Immutable hashed assets
[[headers]]
  for = "/assets/*"
  [headers.values]
    Cache-Control = "public, max-age=31536000, immutable"

# CanvasKit & WASM (kept harmless even if unused)
[[headers]]
  for = "/canvaskit/*"
  [headers.values]
    Cache-Control = "public, max-age=31536000, immutable"

[[headers]]
  for = "/*.wasm"
  [headers.values]
    Cache-Control = "public, max-age=31536000, immutable"
    Content-Type = "application/wasm"

# Web fonts (if you ever ship local .woff2 in /assets/)
[[headers]]
  for = "/*.woff2"
  [headers.values]
    Cache-Control = "public, max-age=31536000, immutable"

# SPA fallback
[[redirects]]
  from = "/*"
  to   = "/index.html"
  status = 200
=======
// ShowTrackAI Bootstrap - HTML Renderer ONLY - Zero External Dependencies
(function() {
  "use strict";
  
  console.log("ShowTrackAI Bootstrap - HTML Renderer Only, No Geolocation");
  
  // Block any CanvasKit attempts
  Object.defineProperty(window, 'CanvasKit', {
    get: function() { 
      console.warn('CanvasKit access blocked'); 
      return null; 
    },
    set: function() { 
      console.warn('CanvasKit assignment blocked'); 
    }
  });
  
  // Define minimal Flutter loader
  window._flutter = window._flutter || {};
  
  // Simple script loader
  function loadMainDart() {
    console.log("Loading main.dart.js...");
    
    const script = document.createElement('script');
    script.type = 'application/javascript';
    script.src = 'main.dart.js';
    script.async = true;
    
    script.onload = function() {
      console.log("main.dart.js loaded successfully");
      // Dispatch event to signal app loaded
      window.dispatchEvent(new Event('flutter-first-frame'));
    };
    
    script.onerror = function(error) {
      console.error("Failed to load main.dart.js:", error);
      // Still dispatch event to remove loading screen
      window.dispatchEvent(new Event('flutter-first-frame'));
    };
    
    document.head.appendChild(script);
  }
  
  // Build config for HTML renderer only
  _flutter.buildConfig = {
    engineRevision: "html",
    builds: [{
      compileTarget: "dart2js",
      renderer: "html",
      mainJsPath: "main.dart.js"
    }]
  };
  
  // Minimal loader that does nothing fancy
  _flutter.loader = {
    loadEntrypoint: function(options) {
      console.log("Loading entrypoint with HTML renderer");
      return Promise.resolve();
    },
    load: function(config) {
      console.log("Loading Flutter with HTML renderer");
      loadMainDart();
      return Promise.resolve();
    },
    didCreateEngineInitializer: function(engineInitializer) {
      console.log("Engine initializer ready");
      if (engineInitializer && engineInitializer.initializeEngine) {
        engineInitializer.initializeEngine({
          renderer: "html",
          assetBase: "",
          hostElement: document.getElementById('app-container')
        }).then(function(appRunner) {
          if (appRunner && appRunner.runApp) {
            console.log("Running Flutter app");
            return appRunner.runApp();
          }
        }).catch(function(error) {
          console.error("Engine initialization error:", error);
          // Still signal app loaded to remove loading screen
          window.dispatchEvent(new Event('flutter-first-frame'));
        });
      }
    }
  };
  
  // Start loading immediately
  console.log("Starting ShowTrackAI with HTML renderer - No geolocation");
  _flutter.loader.load({
    renderer: "html",
    useCanvasKit: false
  });
  
})();
>>>>>>> aeea336 (feat: Remove all geolocation and replace with simple text input)
