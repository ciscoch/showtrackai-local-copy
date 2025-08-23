#!/bin/bash

echo "🔨 FORCING HTML RENDERER - ELIMINATING CANVASKIT PERMANENTLY"

# This script creates a flutter_bootstrap.js that NEVER loads external resources

cat > build/web/flutter_bootstrap.js << 'BOOTSTRAP_END'
// ShowTrackAI Bootstrap - HTML Renderer ONLY - Zero External Dependencies
(function() {
  "use strict";
  
  console.log("ShowTrackAI Bootstrap - HTML Renderer Only");
  
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
  console.log("Starting ShowTrackAI with HTML renderer");
  _flutter.loader.load({
    renderer: "html",
    useCanvasKit: false
  });
  
})();
BOOTSTRAP_END

echo "✅ HTML-only bootstrap created"

# Verify the file was created and has content
if [ -f "build/web/flutter_bootstrap.js" ]; then
  SIZE=$(wc -c < build/web/flutter_bootstrap.js)
  echo "📊 Bootstrap file size: $SIZE bytes"
  
  # Also copy to web directory for source control
  cp build/web/flutter_bootstrap.js web/flutter_bootstrap.js
  echo "📝 Copied bootstrap to web/ directory"
else
  echo "❌ Failed to create bootstrap file!"
  exit 1
fi

echo "🎉 CANVASKIT ELIMINATED - HTML RENDERER FORCED"