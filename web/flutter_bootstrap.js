/**
 * Flutter Bootstrap for HTML Renderer (Netlify Compatible)
 * This file handles Flutter initialization with proper HTML renderer configuration
 * Fixes: buildConfig setup, proper loader API usage, Netlify compatibility
 */

(function() {
  'use strict';
  
  console.log('🚀 Flutter Bootstrap v4.0 starting...');
  
  // Ensure buildConfig exists with proper structure
  if (!window._flutter) {
    window._flutter = {};
  }
  
  if (!window._flutter.buildConfig) {
    console.log('⚠️ buildConfig not found, creating default...');
    window._flutter.buildConfig = {
      "engineRevision": "stable",
      "builds": [
        {
          "compileTarget": "dart2js",
          "renderer": "html",
          "mainJsPath": "main.dart.js"
        }
      ]
    };
  }
  
  // Ensure builds array exists
  if (!window._flutter.buildConfig.builds || !Array.isArray(window._flutter.buildConfig.builds)) {
    console.log('⚠️ builds array not found or invalid, creating default...');
    window._flutter.buildConfig.builds = [
      {
        "compileTarget": "dart2js",
        "renderer": "html",
        "mainJsPath": "main.dart.js"
      }
    ];
  }
  
  console.log('✅ Flutter buildConfig verified:', window._flutter.buildConfig);
  
  // Configuration for HTML renderer
  const engineConfig = {
    renderer: "html",
    hostElement: document.body,
    useColorEmoji: true
  };
  
  // Wait for Flutter loader to be ready
  function waitForFlutterLoader() {
    console.log('🔄 Waiting for Flutter loader...');
    
    if (window._flutter && window._flutter.loader && typeof window._flutter.loader.load === 'function') {
      console.log('✅ Flutter loader ready');
      initializeFlutter();
    } else {
      setTimeout(waitForFlutterLoader, 100);
    }
  }
  
  // Initialize Flutter
  function initializeFlutter() {
    console.log('🔧 Initializing Flutter with new loader API...');
    
    try {
      // Use the new Flutter 3.x loader API
      window._flutter.loader.load({
        config: engineConfig,
        onEntrypointLoaded: async function(engineInitializer) {
          console.log('✅ Flutter entrypoint loaded');
          
          try {
            console.log('🔧 Initializing engine with config:', engineConfig);
            const appRunner = await engineInitializer.initializeEngine(engineConfig);
            
            console.log('✅ Flutter engine initialized');
            
            await appRunner.runApp();
            console.log('✅ Flutter app started successfully!');
            
            // Store reference
            window.flutterApp = appRunner;
            
            // Fire events
            window.dispatchEvent(new CustomEvent('flutter-first-frame'));
            window.dispatchEvent(new CustomEvent('flutter-initialized'));
            
          } catch (error) {
            console.error('❌ Failed to initialize Flutter engine:', error);
            handleError('Engine initialization failed: ' + error.message);
          }
        }
      });
    } catch (error) {
      console.error('❌ Flutter loader error:', error);
      handleError('Loader error: ' + error.message);
    }
  }
  
  // Error handler
  function handleError(message) {
    console.error('❌ Flutter Error:', message);
    
    // Remove splash
    const splash = document.getElementById('splash');
    if (splash) {
      splash.style.display = 'none';
    }
    
    // Show error UI
    setTimeout(() => {
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
            There was an issue loading the application. Please refresh the page.
          </p>
          <p style="font-size: 12px; color: #999; margin-top: 20px;">
            ${message}
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
    }, 500);
  }
  
  // Start initialization
  function startInitialization() {
    console.log('🚀 Starting Flutter initialization...');
    waitForFlutterLoader();
  }
  
  // Wait for DOM
  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', startInitialization);
  } else {
    startInitialization();
  }
  
  // Safety check after load
  window.addEventListener('load', function() {
    console.log('🔍 Window loaded - verifying Flutter...');
    
    setTimeout(() => {
      const flutterElements = !!(
        window.flutterApp ||
        document.querySelector('flutter-view') ||
        document.querySelector('flt-glass-pane') ||
        document.querySelector('[flt-scene-host]')
      );
      
      if (!flutterElements) {
        console.warn('⚠️ Flutter not detected after 5 seconds');
        
        // Retry initialization once
        if (window._flutter?.loader && !window.flutterApp) {
          console.log('🔄 Retrying Flutter initialization...');
          initializeFlutter();
        }
      } else {
        console.log('✅ Flutter detected and running');
      }
    }, 5000);
  });
  
  console.log('✅ Flutter Bootstrap setup complete');
})();