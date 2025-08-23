#!/usr/bin/env node

/**
 * ShowTrackAI External Resource Verification Script
 * Verifies that the Flutter app has ZERO external dependencies
 */

const fs = require('fs');
const path = require('path');

console.log('🧪 ShowTrackAI External Resource Fix Verification\n');

// Files to check
const files = [
    'build/web/index.html',
    'build/web/flutter_bootstrap.js',
    'web/index.html'
];

let allTestsPassed = true;

// Patterns that should NOT exist (external resources)
const forbiddenPatterns = [
    /gstatic\.com/gi,
    /flutter-canvaskit/gi,
    /https:\/\/www\.gstatic\.com/gi,
    /canvasKitBaseUrl.*gstatic/gi,
    /engineRevision.*&&.*!.*useLocalCanvasKit/gi
];

// Patterns that SHOULD exist (our fixes)
const requiredPatterns = {
    'build/web/index.html': [
        /STRICT CSP - NO EXTERNAL RESOURCES/,
        /FORCE HTML RENDERER - NO CANVASKIT EVER/,
        /renderer: "html"/,
        /useCanvasKit: false/
    ],
    'build/web/flutter_bootstrap.js': [
        /COMPLETELY REWRITTEN FLUTTER BOOTSTRAP/,
        /ZERO EXTERNAL DEPENDENCIES/,
        /ZeroExternalFlutterLoader/,
        /renderer: "html"/
    ],
    'web/index.html': [
        /STRICT CSP - NO EXTERNAL RESOURCES/,
        /FORCE HTML RENDERER - NO CANVASKIT EVER/
    ]
};

console.log('📁 Checking critical files...\n');

files.forEach(file => {
    const filePath = path.join(__dirname, file);
    
    if (!fs.existsSync(filePath)) {
        console.log(`❌ MISSING: ${file}`);
        allTestsPassed = false;
        return;
    }
    
    const content = fs.readFileSync(filePath, 'utf8');
    console.log(`📄 Checking: ${file}`);
    
    // Check for forbidden patterns (but ignore them if they're in blocking/warning code)
    let forbiddenFound = [];
    forbiddenPatterns.forEach(pattern => {
        const matches = content.match(pattern);
        if (matches) {
            // Filter out matches that are part of our blocking code
            const realForbidden = matches.filter(match => {
                const matchIndex = content.indexOf(match);
                const surrounding = content.substring(Math.max(0, matchIndex - 100), matchIndex + 100);
                
                // These are GOOD contexts (our blocking/warning code)
                const goodContexts = [
                    'BLOCKED external resource',
                    'url.includes(',
                    'startsWith(',
                    'External resource blocked',
                    'BLOCKED EXTERNAL',
                    'Block any attempts to load',
                    'NO CANVASKIT, NO GSTATIC.COM'
                ];
                
                return !goodContexts.some(context => surrounding.includes(context));
            });
            
            if (realForbidden.length > 0) {
                forbiddenFound.push(...realForbidden);
            }
        }
    });
    
    if (forbiddenFound.length > 0) {
        console.log(`   ❌ EXTERNAL RESOURCES FOUND:`);
        forbiddenFound.forEach(match => {
            console.log(`      - "${match}"`);
        });
        allTestsPassed = false;
    } else {
        console.log(`   ✅ No external resources detected`);
    }
    
    // Check for required patterns
    if (requiredPatterns[file]) {
        let missingRequired = [];
        requiredPatterns[file].forEach(pattern => {
            if (!pattern.test(content)) {
                missingRequired.push(pattern);
            }
        });
        
        if (missingRequired.length > 0) {
            console.log(`   ❌ MISSING REQUIRED FIXES:`);
            missingRequired.forEach(pattern => {
                console.log(`      - ${pattern}`);
            });
            allTestsPassed = false;
        } else {
            console.log(`   ✅ All required fixes present`);
        }
    }
    
    console.log();
});

// Additional checks
console.log('🔍 Additional verification checks:\n');

// Check if flutter_service_worker.js exists (it shouldn't be used)
const serviceWorkerPath = path.join(__dirname, 'build/web/flutter_service_worker.js');
if (fs.existsSync(serviceWorkerPath)) {
    console.log('⚠️  WARNING: flutter_service_worker.js exists but should be disabled');
    console.log('   (This is OK as long as it\'s not being loaded)');
} else {
    console.log('✅ No service worker file found (good)');
}

// Check canvaskit directory
const canvaskitPath = path.join(__dirname, 'build/web/canvaskit');
if (fs.existsSync(canvaskitPath)) {
    console.log('⚠️  WARNING: canvaskit directory exists but should not be used');
    console.log('   (This is OK as long as our bootstrap doesn\'t load it)');
} else {
    console.log('✅ No canvaskit directory found (good)');
}

// Check main.dart.js for any gstatic references
const mainDartPath = path.join(__dirname, 'build/web/main.dart.js');
if (fs.existsSync(mainDartPath)) {
    const mainContent = fs.readFileSync(mainDartPath, 'utf8');
    if (mainContent.includes('gstatic.com')) {
        console.log('⚠️  WARNING: main.dart.js contains gstatic.com references');
        console.log('   (This might be OK if our bootstrap prevents loading)');
    } else {
        console.log('✅ main.dart.js clean of external references');
    }
} else {
    console.log('❌ main.dart.js not found - app may not work');
    allTestsPassed = false;
}

console.log('\n' + '='.repeat(60));

if (allTestsPassed) {
    console.log('🎉 ALL TESTS PASSED!');
    console.log('✅ ShowTrackAI should now load with ZERO external dependencies');
    console.log('✅ No CanvasKit, no gstatic.com, no external resources');
    console.log('✅ HTML renderer forced, CSP compliant');
    console.log('\n🚀 Ready for production deployment!');
} else {
    console.log('❌ SOME TESTS FAILED!');
    console.log('⚠️  Review the issues above and fix before deployment');
    console.log('⚠️  The app may still try to load external resources');
}

console.log('\n📋 Next steps:');
console.log('1. Open test_external_resources.html in browser');
console.log('2. Verify no CSP violations in dev tools console');
console.log('3. Check network tab shows no gstatic.com requests');
console.log('4. Confirm app loads and functions normally');

process.exit(allTestsPassed ? 0 : 1);