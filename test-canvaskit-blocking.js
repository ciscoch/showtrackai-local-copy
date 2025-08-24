// Test script to verify CanvasKit blocking is working
const puppeteer = require('puppeteer');

async function testCanvasKitBlocking() {
  console.log('🧪 Testing CanvasKit blocking...');
  
  const browser = await puppeteer.launch({
    headless: false,
    devtools: true,
    args: ['--disable-web-security', '--allow-running-insecure-content']
  });
  
  const page = await browser.newPage();
  
  // Collect console messages
  const consoleMessages = [];
  const networkRequests = [];
  const blockedRequests = [];
  
  page.on('console', msg => {
    consoleMessages.push({
      type: msg.type(),
      text: msg.text()
    });
    console.log(`📝 Console [${msg.type()}]:`, msg.text());
  });
  
  page.on('request', request => {
    const url = request.url();
    networkRequests.push(url);
    
    if (url.includes('canvaskit') || url.includes('CanvasKit') || url.includes('.wasm')) {
      blockedRequests.push(url);
      console.log(`🚫 Blocked request:`, url);
    } else {
      console.log(`✅ Allowed request:`, url);
    }
  });
  
  page.on('requestfailed', request => {
    const url = request.url();
    if (url.includes('canvaskit') || url.includes('CanvasKit') || url.includes('.wasm')) {
      console.log(`✅ Successfully blocked:`, url);
    } else {
      console.log(`❌ Unexpected failure:`, url);
    }
  });
  
  try {
    console.log('📱 Loading ShowTrackAI...');
    await page.goto('http://127.0.0.1:8081', { 
      waitUntil: 'networkidle0',
      timeout: 30000 
    });
    
    // Wait for Flutter to load
    console.log('⏳ Waiting for Flutter to initialize...');
    await page.waitForTimeout(5000);
    
    // Check if Flutter app loaded successfully
    const flutterLoaded = await page.evaluate(() => {
      return window._flutter && window._flutter.loader;
    });
    
    // Check for CanvasKit references
    const canvasKitFound = await page.evaluate(() => {
      return window.flutterCanvasKit || window.flutterCanvasKitLoaded;
    });
    
    // Summary
    console.log('\n📊 TEST RESULTS:');
    console.log('================');
    console.log(`Flutter Loaded: ${flutterLoaded ? '✅' : '❌'}`);
    console.log(`CanvasKit Prevented: ${!canvasKitFound ? '✅' : '❌'}`);
    console.log(`Total Requests: ${networkRequests.length}`);
    console.log(`Blocked Requests: ${blockedRequests.length}`);
    
    // Show blocked requests
    if (blockedRequests.length > 0) {
      console.log('\n🚫 Blocked CanvasKit/WASM Requests:');
      blockedRequests.forEach(url => console.log(`  - ${url}`));
    }
    
    // Show warning messages
    const warnings = consoleMessages.filter(msg => 
      msg.text.includes('Blocked') || 
      msg.text.includes('CanvasKit') ||
      msg.type === 'warning'
    );
    
    if (warnings.length > 0) {
      console.log('\n⚠️ Warning Messages:');
      warnings.forEach(msg => console.log(`  [${msg.type}] ${msg.text}`));
    }
    
    // Check for errors
    const errors = consoleMessages.filter(msg => msg.type === 'error');
    if (errors.length > 0) {
      console.log('\n❌ Error Messages:');
      errors.forEach(msg => console.log(`  ${msg.text}`));
    }
    
    console.log('\n🎉 Test completed successfully!');
    console.log('   The app should now load without CanvasKit.');
    
    // Keep browser open for manual inspection
    console.log('\n👀 Browser will stay open for manual inspection...');
    console.log('   Close the browser when done.');
    
    // Wait for manual close
    await new Promise(resolve => {
      process.on('SIGINT', () => {
        console.log('\n🔚 Closing browser...');
        browser.close();
        resolve();
      });
    });
    
  } catch (error) {
    console.error('❌ Test failed:', error.message);
  } finally {
    if (!browser._process.killed) {
      await browser.close();
    }
  }
}

if (require.main === module) {
  testCanvasKitBlocking().catch(console.error);
}

module.exports = { testCanvasKitBlocking };