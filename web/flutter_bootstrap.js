/**
 * Flutter Bootstrap for HTML Renderer (Netlify Compatible)
 * This file handles Flutter initialization with proper HTML renderer configuration
 * Fixes: buildConfig setup, proper loader API usage, Netlify compatibility
 */

(function() {
  'use strict';
  
  console.log('🚀 Flutter Bootstrap v2.0 starting...');
  
  // Set up _flutter.buildConfig early - this is critical for newer Flutter versions
  window._flutter = window._flutter || {};
  window._flutter.buildConfig = {
    "renderer": "html",
    "canvasKitBaseUrl": null,
    "useLocalCanvasKit": false,
    "serviceWorkerSettings": null
  };
  
  console.log('✅ Flutter buildConfig set:', window._flutter.buildConfig);
  
  // Configuration for HTML renderer only
  const engineConfig = {
    renderer: "html",
    hostElement: document.body,
    useColorEmoji: true,
    // Disable CanvasKit completely
    canvasKitBaseUrl: null,
    useLocalCanvasKit: false,
  };
  
  // Function to load Flutter with proper error handling
  function loadFlutter() {
    console.log('🔄 Loading Flutter with HTML renderer...');
    
    // Check if flutter.js is already loaded
    if (window._flutter && window._flutter.loader) {
      console.log('✅ Flutter loader already available');
      initializeFlutter();
      return;
    }
    
    // Load flutter.js
    const flutterScript = document.createElement('script');
    flutterScript.src = 'flutter.js';
    flutterScript.type = 'application/javascript';
    flutterScript.async = true;
    
    flutterScript.onload = function() {
      console.log('✅ flutter.js loaded successfully');
      // Give Flutter a moment to set up
      setTimeout(initializeFlutter, 100);
    };
    
    flutterScript.onerror = function(error) {
      console.error('❌ Failed to load flutter.js:', error);
      handleFlutterError('flutter.js loading failed');
    };
    
    document.head.appendChild(flutterScript);
  }
  
  // Initialize Flutter with HTML renderer
  function initializeFlutter() {
    console.log('🔧 Initializing Flutter...');
    
    try {
      // Check for modern Flutter loader API
      if (window._flutter && window._flutter.loader) {
        console.log('🎯 Using modern Flutter loader API...');
        
        // Use the newer load() method with proper configuration
        window._flutter.loader.load({
          config: window._flutter.buildConfig,
          onEntrypointLoaded: async function(engineInitializer) {
            console.log('✅ Flutter entrypoint loaded via modern API');
            
            try {
              console.log('🔧 Initializing engine with config:', engineConfig);
              const appRunner = await engineInitializer.initializeEngine(engineConfig);
              
              console.log('✅ Flutter engine initialized');
              
              await appRunner.runApp();
              console.log('✅ Flutter app started successfully!');
              
              // Mark Flutter as successfully loaded
              window.flutterApp = appRunner;
              
              // Dispatch events for loading screen management
              window.dispatchEvent(new CustomEvent('flutter-first-frame'));
              window.dispatchEvent(new CustomEvent('flutter-initialized'));
              
            } catch (error) {
              console.error('❌ Failed to initialize Flutter engine:', error);
              handleFlutterError('Engine initialization failed: ' + error.message);
            }
          }
        });
      } else if (window._flutter && window._flutter.loader && window._flutter.loader.loadEntrypoint) {
        // Fallback for older Flutter versions using loadEntrypoint
        console.log('🔄 Using legacy Flutter loader API (loadEntrypoint)...');
        
        window._flutter.loader.loadEntrypoint({
          config: window._flutter.buildConfig,
          onEntrypointLoaded: async function(engineInitializer) {
            console.log('✅ Flutter entrypoint loaded via legacy API');
            
            try {
              const appRunner = await engineInitializer.initializeEngine(engineConfig);
              await appRunner.runApp();
              
              window.flutterApp = appRunner;
              window.dispatchEvent(new CustomEvent('flutter-first-frame'));
              
              console.log('✅ Flutter app started via legacy API!');
            } catch (error) {
              console.error('❌ Legacy API initialization failed:', error);
              handleFlutterError('Legacy initialization failed: ' + error.message);
            }
          }
        });
      } else if (window.flutter && window.flutter.loader) {
        // Even older Flutter version fallback
        console.log('🔄 Using very old Flutter loader API...');
        
        window.flutter.loader.loadEntrypoint({
          onEntrypointLoaded: async function(engineInitializer) {
            const appRunner = await engineInitializer.initializeEngine(engineConfig);
            await appRunner.runApp();
            window.dispatchEvent(new CustomEvent('flutter-first-frame'));
          }
        });
      } else {
        console.error('❌ No Flutter loader found - checking window._flutter:', window._flutter);
        console.error('❌ Checking window.flutter:', window.flutter);
        handleFlutterError('Flutter loader not available after script load');
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
  
  // Enhanced safety checks with better timeout handling
  window.addEventListener('load', function() {
    console.log('🔍 Window load event - checking Flutter initialization status...');
    
    setTimeout(() => {
      // Check multiple ways Flutter might be available
      const flutterDetected = !!(
        window.flutterApp || 
        window._flutter?.app || 
        window._flutter?.loader?.didCreateEngineInitializer ||
        document.querySelector('flutter-view')
      );
      
      if (!flutterDetected) {
        console.warn('⚠️ Flutter app not detected after window load - giving more time...');
        
        // Give Flutter more time, but with progressive checks
        let attempts = 0;
        const maxAttempts = 10;
        const checkInterval = 1000; // 1 second intervals
        
        const progressiveCheck = setInterval(() => {
          attempts++;
          
          const nowDetected = !!(
            window.flutterApp || 
            window._flutter?.app ||
            document.querySelector('flutter-view') ||
            document.querySelector('.flutter-view')
          );
          
          if (nowDetected) {
            console.log('✅ Flutter detected after', attempts, 'attempts');
            clearInterval(progressiveCheck);
          } else if (attempts >= maxAttempts) {
            console.error('❌ Flutter failed to initialize after', attempts, 'attempts');
            clearInterval(progressiveCheck);
            handleFlutterError('Flutter app failed to initialize within extended timeout (' + (maxAttempts * checkInterval / 1000) + 's)');
          } else {
            console.log('🔍 Flutter check attempt', attempts + '/' + maxAttempts);
          }
        }, checkInterval);
      } else {
        console.log('✅ Flutter detected successfully on window load');
      }
    }, 2000);
  });
  
  console.log('✅ Flutter Bootstrap setup complete');
})();