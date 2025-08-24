// Flutter Web Rendering Debug Script
// Run this in browser console to diagnose black screen issues

console.log('🔍 Flutter Web Rendering Debug Analysis');
console.log('=====================================');

// 1. Check Flutter loader availability
console.log('\n1. Flutter Loader Check:');
console.log('_flutter available:', typeof _flutter !== 'undefined');
console.log('_flutter.loader available:', !!(window._flutter && window._flutter.loader));

// 2. Check build configuration
console.log('\n2. Build Configuration:');
if (window._flutter && window._flutter.buildConfig) {
  console.log('Build config:', JSON.stringify(window._flutter.buildConfig, null, 2));
} else {
  console.log('❌ Build config not found!');
}

// 3. Check for Flutter DOM elements
console.log('\n3. Flutter DOM Elements:');
const flutterSelectors = [
  'flt-glass-pane',
  'flt-scene-host',
  'flutter-view',
  '[class*="flt-"]',
  '[id*="flt-"]'
];

flutterSelectors.forEach(selector => {
  const elements = document.querySelectorAll(selector);
  console.log(`${selector}: ${elements.length} found`);
  if (elements.length > 0) {
    console.log('  Elements:', Array.from(elements).map(el => ({
      tagName: el.tagName,
      className: el.className,
      id: el.id,
      style: {
        display: el.style.display,
        visibility: el.style.visibility,
        opacity: el.style.opacity,
        width: el.offsetWidth,
        height: el.offsetHeight
      }
    })));
  }
});

// 4. Check CSS rendering issues
console.log('\n4. CSS & Rendering Check:');
const bodyStyles = window.getComputedStyle(document.body);
const htmlStyles = window.getComputedStyle(document.documentElement);

console.log('Body styles:', {
  background: bodyStyles.background,
  backgroundColor: bodyStyles.backgroundColor,
  color: bodyStyles.color,
  display: bodyStyles.display,
  visibility: bodyStyles.visibility
});

console.log('HTML styles:', {
  background: htmlStyles.background,
  backgroundColor: htmlStyles.backgroundColor,
  height: htmlStyles.height,
  minHeight: htmlStyles.minHeight
});

// 5. Check for canvas elements (CanvasKit renderer)
console.log('\n5. Canvas Elements Check:');
const canvases = document.querySelectorAll('canvas');
console.log(`Canvas elements found: ${canvases.length}`);
canvases.forEach((canvas, index) => {
  console.log(`Canvas ${index}:`, {
    width: canvas.width,
    height: canvas.height,
    offsetWidth: canvas.offsetWidth,
    offsetHeight: canvas.offsetHeight,
    style: {
      display: canvas.style.display,
      visibility: canvas.style.visibility,
      opacity: canvas.style.opacity
    },
    parent: canvas.parentElement?.tagName
  });
});

// 6. Check for service worker issues
console.log('\n6. Service Worker Check:');
if ('serviceWorker' in navigator) {
  navigator.serviceWorker.getRegistrations().then(registrations => {
    console.log(`Service worker registrations: ${registrations.length}`);
    registrations.forEach((registration, index) => {
      console.log(`SW ${index}:`, {
        scope: registration.scope,
        state: registration.active?.state,
        scriptURL: registration.active?.scriptURL
      });
    });
  });
} else {
  console.log('Service Worker not supported');
}

// 7. Check for JavaScript errors
console.log('\n7. Error Monitoring:');
const originalError = console.error;
console.error = function(...args) {
  console.log('🚨 JavaScript Error detected:', ...args);
  originalError.apply(console, args);
};

// 8. Flutter initialization status
console.log('\n8. Flutter Initialization:');
if (window.flutterApp) {
  console.log('✅ Flutter app instance found');
} else {
  console.log('❌ Flutter app instance not found');
}

// 9. Check viewport and sizing
console.log('\n9. Viewport & Sizing:');
console.log('Window size:', {
  innerWidth: window.innerWidth,
  innerHeight: window.innerHeight,
  outerWidth: window.outerWidth,
  outerHeight: window.outerHeight
});

console.log('Document size:', {
  clientWidth: document.documentElement.clientWidth,
  clientHeight: document.documentElement.clientHeight,
  scrollWidth: document.documentElement.scrollWidth,
  scrollHeight: document.documentElement.scrollHeight
});

// 10. Manual Flutter restart function
console.log('\n10. Manual Flutter Restart Function:');
window.restartFlutter = function() {
  console.log('🔄 Attempting to restart Flutter...');
  
  // Remove existing Flutter elements
  const existingElements = document.querySelectorAll('[class*="flt-"], flt-glass-pane, flutter-view');
  existingElements.forEach(el => el.remove());
  
  // Force reload Flutter
  if (window._flutter && window._flutter.loader) {
    window._flutter.loader.load({
      serviceWorkerSettings: {
        serviceWorkerVersion: Date.now().toString() // Force cache bust
      }
    }).then(engineInitializer => {
      console.log('🎯 Flutter engine initializer loaded');
      return engineInitializer.initializeEngine({
        renderer: "html" // Force HTML renderer
      });
    }).then(appRunner => {
      console.log('🎯 Flutter engine initialized');
      return appRunner.runApp();
    }).then(() => {
      console.log('✅ Flutter app restarted successfully!');
    }).catch(error => {
      console.error('❌ Flutter restart failed:', error);
    });
  } else {
    console.error('❌ Flutter loader not available for restart');
  }
};

console.log('Use restartFlutter() to manually restart Flutter with HTML renderer');

// 11. Theme and MaterialApp check
console.log('\n11. Theme Analysis:');
setTimeout(() => {
  // Look for Material App indicators
  const materialElements = document.querySelectorAll('[class*="material"], [class*="scaffold"]');
  console.log(`Material Design elements: ${materialElements.length}`);
  
  // Check for theme-related CSS
  const stylesheets = Array.from(document.styleSheets);
  console.log(`Stylesheets loaded: ${stylesheets.length}`);
  
  stylesheets.forEach((sheet, index) => {
    try {
      if (sheet.cssRules) {
        const rules = Array.from(sheet.cssRules);
        const themeRules = rules.filter(rule => 
          rule.selectorText && (
            rule.selectorText.includes('flutter') ||
            rule.selectorText.includes('flt-') ||
            rule.selectorText.includes('material')
          )
        );
        if (themeRules.length > 0) {
          console.log(`Stylesheet ${index} Flutter rules:`, themeRules.length);
        }
      }
    } catch (e) {
      console.log(`Stylesheet ${index}: Cannot access rules (CORS)`);
    }
  });
}, 2000);

console.log('\n🔍 Debug analysis complete. Check the console output above for issues.');
console.log('💡 If you see a black screen, try calling restartFlutter() in the console.');