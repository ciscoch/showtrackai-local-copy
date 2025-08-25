/**
 * Flutter Fallback Loader for Netlify
 * This provides a simpler initialization path when the main loader fails
 */

(function() {
  'use strict';
  
  console.log('🔄 Flutter Fallback Loader v1.0');
  
  // Ensure _flutter object exists
  window._flutter = window._flutter || {};
  
  // Provide minimal buildConfig if missing
  if (!window._flutter.buildConfig) {
    console.log('📦 Creating fallback buildConfig');
    window._flutter.buildConfig = {
      engineRevision: "ef0cd000916d64fa0c5d09cc809fa7ad244a5767",
      builds: [{
        compileTarget: "dart2js",
        renderer: "html",
        mainJsPath: "main.dart.js"
      }]
    };
  }
  
  // Simple loader function
  function loadFlutterApp() {
    console.log('🚀 Attempting simple Flutter load...');
    
    // Check if main.dart.js exists
    const script = document.createElement('script');
    script.src = 'main.dart.js';
    script.type = 'application/javascript';
    script.defer = true;
    
    script.onload = function() {
      console.log('✅ main.dart.js loaded successfully');
      
      // Hide loading screen after a delay
      setTimeout(() => {
        const loadingElement = document.getElementById('loading');
        if (loadingElement) {
          loadingElement.style.display = 'none';
          console.log('✅ Loading screen hidden');
        }
      }, 2000);
    };
    
    script.onerror = function(e) {
      console.error('❌ Failed to load main.dart.js:', e);
      showError('Failed to load application resources');
    };
    
    document.body.appendChild(script);
  }
  
  // Error display function
  function showError(message) {
    const loadingElement = document.getElementById('loading');
    if (loadingElement) {
      loadingElement.innerHTML = `
        <div style="text-align: center; padding: 40px;">
          <h2 style="color: #d32f2f;">Loading Error</h2>
          <p>${message}</p>
          <button onclick="location.reload()" style="
            background: #4CAF50;
            color: white;
            border: none;
            padding: 10px 20px;
            border-radius: 5px;
            cursor: pointer;
            font-size: 16px;
          ">Retry</button>
        </div>
      `;
    }
  }
  
  // Try loading after a short delay
  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', loadFlutterApp);
  } else {
    setTimeout(loadFlutterApp, 100);
  }
  
})();