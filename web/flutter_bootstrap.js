/**
 * Flutter Bootstrap for HTML Renderer (Netlify Compatible)
 * This file handles Flutter initialization with proper HTML renderer configuration
 */

(function() {
  'use strict';
  
  console.log('🚀 Flutter Bootstrap starting...');
  
  // Configuration for HTML renderer only
  const flutterConfig = {
    // Force HTML renderer (no CanvasKit)
    renderer: "html",
    
    // Disable CanvasKit completely
    canvasKitBaseUrl: null,
    useLocalCanvasKit: false,
    
    // No service worker for initial deployment
    serviceWorkerSettings: null,
    
    // CDN configuration
    hostElement: document.body,
    
    // Error handling
    onEntrypointLoaded: function(engineInitializer) {
      console.log('✅ Flutter engine loaded, initializing...');
      return engineInitializer.initializeEngine({
        renderer: "html",  // Force HTML renderer
        hostElement: document.body
      });
    }
  };
  
  // Function to load Flutter with proper error handling
  function loadFlutter() {
    console.log('🔄 Loading Flutter with HTML renderer...');
    
    // Check if Flutter is already available
    if (window._flutter) {
      console.log('✅ Flutter already loaded');
      initializeFlutter();
      return;
    }
    
    // Load flutter.js if not already loaded
    if (!window.flutter) {
      const flutterScript = document.createElement('script');
      flutterScript.src = 'flutter.js';
      flutterScript.type = 'application/javascript';
      flutterScript.onload = function() {
        console.log('✅ flutter.js loaded');
        initializeFlutter();
      };
      flutterScript.onerror = function(error) {
        console.error('❌ Failed to load flutter.js:', error);
        handleFlutterError('flutter.js loading failed');
      };
      document.head.appendChild(flutterScript);
    } else {
      initializeFlutter();
    }
  }
  
  // Initialize Flutter with HTML renderer
  function initializeFlutter() {
    console.log('🔧 Initializing Flutter...');
    
    try {
      // Use the global flutter loader
      if (window._flutter && window._flutter.loader) {
        console.log('🎯 Using Flutter loader...');
        
        // Use the newer load API instead of deprecated loadEntrypoint
        window._flutter.loader.load({
          onEntrypointLoaded: async function(engineInitializer) {
            console.log('✅ Flutter entrypoint loaded');
            
            try {
              const appRunner = await engineInitializer.initializeEngine({
                renderer: "html",
                hostElement: document.body,
                useColorEmoji: true
              });
              
              console.log('✅ Flutter engine initialized');
              
              await appRunner.runApp();
              console.log('✅ Flutter app started!');
              
              // Dispatch custom event for loading screen
              window.dispatchEvent(new CustomEvent('flutter-first-frame'));
              
            } catch (error) {
              console.error('❌ Failed to initialize Flutter engine:', error);
              handleFlutterError('Engine initialization failed: ' + error.message);
            }
          }
        });
      } else if (window.flutter && window.flutter.loader) {
        // Fallback for older Flutter versions
        console.log('🔄 Using fallback Flutter loader...');
        
        window.flutter.loader.loadEntrypoint({
          onEntrypointLoaded: async function(engineInitializer) {
            const appRunner = await engineInitializer.initializeEngine(flutterConfig);
            await appRunner.runApp();
            window.dispatchEvent(new CustomEvent('flutter-first-frame'));
          }
        });
      } else {
        console.error('❌ Flutter loader not found');
        handleFlutterError('Flutter loader not available');
      }
    } catch (error) {
      console.error('❌ Flutter initialization error:', error);
      handleFlutterError('Initialization error: ' + error.message);
    }
  }
  
  // Handle Flutter loading errors
  function handleFlutterError(errorMessage) {
    console.error('❌ Flutter Error:', errorMessage);
    
    // Hide loading screen even on error
    setTimeout(() => {
      const loadingElement = document.getElementById('loading');
      if (loadingElement) {
        loadingElement.style.display = 'none';
        console.log('⚠️ Loading screen hidden due to error');
      }
      
      // Show error message
      document.body.innerHTML = `
        <div style="
          position: fixed;
          top: 50%;
          left: 50%;
          transform: translate(-50%, -50%);
          text-align: center;
          font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', sans-serif;
          max-width: 400px;
          padding: 20px;
        ">
          <h2 style="color: #d32f2f;">Loading Error</h2>
          <p style="color: #666;">
            There was an issue loading the application. Please refresh the page to try again.
          </p>
          <p style="font-size: 12px; color: #999; margin-top: 20px;">
            Error: ${errorMessage}
          </p>
          <button 
            onclick="window.location.reload()" 
            style="
              background: #1976d2;
              color: white;
              border: none;
              padding: 10px 20px;
              border-radius: 4px;
              cursor: pointer;
              margin-top: 15px;
            "
          >
            Refresh Page
          </button>
        </div>
      `;
    }, 1000);
  }
  
  // Start the loading process when DOM is ready
  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', loadFlutter);
  } else {
    // DOM is already ready
    loadFlutter();
  }
  
  // Additional safety check
  window.addEventListener('load', function() {
    setTimeout(() => {
      if (!window.flutterApp && !window._flutter?.app) {
        console.warn('⚠️ Flutter app not detected after window load');
        // Don't show error immediately, give it more time
        setTimeout(() => {
          if (!window.flutterApp && !window._flutter?.app) {
            handleFlutterError('Flutter app failed to initialize within timeout');
          }
        }, 5000);
      }
    }, 2000);
  });
  
  console.log('✅ Flutter Bootstrap setup complete');
})();