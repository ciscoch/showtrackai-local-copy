/**
 * Flutter Bootstrap for HTML Renderer (Netlify Compatible)
 * This file handles Flutter initialization with proper HTML renderer configuration
 * Fixes: buildConfig setup, proper loader API usage, Netlify compatibility
 */

(function() {
  'use strict';
  
  console.log('🚀 Flutter Bootstrap v3.0 starting...');
  
  // Verify buildConfig was set (should be set in index.html before this script)
  if (!window._flutter) {
    window._flutter = {};
  }
  
  if (!window._flutter.buildConfig) {
    console.warn('⚠️ Flutter buildConfig not found, setting default configuration');
    window._flutter.buildConfig = {
      "renderer": "html",
      "canvasKitBaseUrl": null,
      "useLocalCanvasKit": false,
      "serviceWorkerSettings": null,
      "hostElement": null,
      "useColorEmoji": true,
      "builds": [] // Add builds array to prevent 'find' errors
    };
  }
  
  // Ensure builds array exists to prevent 'find' method errors
  if (!window._flutter.buildConfig.builds) {
    window._flutter.buildConfig.builds = [];
  }
  
  console.log('✅ Flutter buildConfig verified:', window._flutter.buildConfig);
  
  // Configuration for HTML renderer only  
  const engineConfig = {
    renderer: "html",
    hostElement: document.body,
    useColorEmoji: true
  };
  
  // Simplified Flutter initialization
  function initializeFlutterWhenReady() {
    console.log('🔄 Checking if Flutter loader is ready...');
    
    // Wait for flutter.js to load and setup window._flutter.loader
    if (window._flutter && window._flutter.loader && typeof window._flutter.loader.load === 'function') {
      console.log('✅ Flutter loader is ready, initializing...');
      initializeFlutter();
    } else {
      console.log('⏳ Flutter loader not ready yet, retrying...');
      // Retry after a short delay
      setTimeout(initializeFlutterWhenReady, 100);
    }
  }
  
  // Initialize Flutter with HTML renderer
  function initializeFlutter() {
    console.log('🔧 Initializing Flutter...');
    
    try {
      console.log('🎯 Using Flutter loader API with buildConfig...');
      
      // Use the buildConfig-based initialization approach
      window._flutter.loader.load({
        onEntrypointLoaded: async function(engineInitializer) {
          console.log('✅ Flutter entrypoint loaded');
          
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
  
  // Start Flutter initialization when ready
  function startFlutterInitialization() {
    console.log('🚀 Starting Flutter initialization process...');
    
    // Start checking for Flutter loader
    initializeFlutterWhenReady();
  }
  
  // Start when DOM is ready
  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', startFlutterInitialization);
  } else {
    // DOM is already ready
    startFlutterInitialization();
  }
  
  // Safety check with timeout
  window.addEventListener('load', function() {
    console.log('🔍 Window load event - setting up Flutter safety checks...');
    
    setTimeout(() => {
      const flutterDetected = !!(
        window.flutterApp || 
        window._flutter?.app || 
        document.querySelector('flutter-view') ||
        document.querySelector('flt-glass-pane')
      );
      
      if (!flutterDetected) {
        console.warn('⚠️ Flutter app not detected, starting recovery process...');
        
        let attempts = 0;
        const maxAttempts = 5;
        const checkInterval = 2000;
        
        const recoveryCheck = setInterval(() => {
          attempts++;
          
          const nowDetected = !!(
            window.flutterApp || 
            window._flutter?.app ||
            document.querySelector('flutter-view') ||
            document.querySelector('flt-glass-pane')
          );
          
          if (nowDetected) {
            console.log('✅ Flutter recovered after', attempts, 'attempts');
            clearInterval(recoveryCheck);
          } else if (attempts >= maxAttempts) {
            console.error('❌ Flutter failed to recover after', attempts, 'attempts');
            clearInterval(recoveryCheck);
            handleFlutterError('Flutter failed to initialize after ' + (maxAttempts * checkInterval / 1000) + ' seconds');
          } else {
            console.log('🔄 Recovery attempt', attempts + '/' + maxAttempts);
            // Try to reinitialize
            if (window._flutter?.loader && typeof window._flutter.loader.load === 'function') {
              console.log('🔄 Attempting Flutter reinitialization...');
              initializeFlutter();
            }
          }
        }, checkInterval);
      } else {
        console.log('✅ Flutter detected successfully');
      }
    }, 3000);
  });
  
  console.log('✅ Flutter Bootstrap setup complete');
})();