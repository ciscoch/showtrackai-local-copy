#!/bin/bash

echo "📝 Creating minimal Flutter bootstrap..."

# Create a minimal flutter_bootstrap.js that just loads main.dart.js
cat > build/web/flutter_bootstrap.js << 'EOF'
// Minimal Flutter Bootstrap - HTML Renderer Only
(function() {
  "use strict";
  
  // Skip all fancy loaders and just load main.dart.js directly
  console.log("Loading ShowTrackAI with HTML renderer...");
  
  // Create a simple script loader
  function loadScript(src, onLoad, onError) {
    var script = document.createElement('script');
    script.type = 'application/javascript';
    script.src = src;
    script.async = true;
    
    if (onLoad) script.onload = onLoad;
    if (onError) script.onerror = onError;
    
    document.head.appendChild(script);
  }
  
  // Define minimal Flutter configuration
  window._flutter = window._flutter || {};
  window._flutter.loader = {
    loadEntrypoint: function(options) {
      console.log("Loading Flutter app...");
      return Promise.resolve();
    },
    didCreateEngineInitializer: function(engineInitializer) {
      console.log("Engine initializer created");
      if (engineInitializer && engineInitializer.initializeEngine) {
        engineInitializer.initializeEngine({
          renderer: "html",
          assetBase: ""
        }).then(function(appRunner) {
          console.log("Running app...");
          return appRunner.runApp();
        });
      }
    }
  };
  
  // Load main.dart.js
  console.log("Loading main.dart.js...");
  loadScript('main.dart.js', function() {
    console.log("main.dart.js loaded successfully");
  }, function(error) {
    console.error("Failed to load main.dart.js:", error);
  });
  
})();
EOF

echo "✅ Minimal bootstrap created"

# Also ensure the file is not empty
if [ -f "build/web/flutter_bootstrap.js" ]; then
  SIZE=$(wc -c < build/web/flutter_bootstrap.js)
  echo "📊 Bootstrap file size: $SIZE bytes"
  if [ "$SIZE" -lt 100 ]; then
    echo "❌ Bootstrap file is too small, something went wrong!"
    exit 1
  fi
else
  echo "❌ Failed to create bootstrap file!"
  exit 1
fi