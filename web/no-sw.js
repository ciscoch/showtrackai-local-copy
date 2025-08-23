// Explicitly disable service worker
if ('serviceWorker' in navigator) {
  navigator.serviceWorker.getRegistrations().then(function(registrations) {
    for(let registration of registrations) {
      console.log('Unregistering service worker:', registration.scope);
      registration.unregister();
    }
  }).catch(function(error) {
    console.log('Service worker unregistration failed:', error);
  });
}

// Prevent any Flutter service worker registration
window.addEventListener('load', function() {
  // Clear any cached service worker
  if ('caches' in window) {
    caches.keys().then(function(cacheNames) {
      return Promise.all(
        cacheNames.map(function(cacheName) {
          console.log('Deleting cache:', cacheName);
          return caches.delete(cacheName);
        })
      );
    });
  }
});