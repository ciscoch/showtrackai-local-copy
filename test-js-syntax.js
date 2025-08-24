#!/usr/bin/env node

// Test if main.dart.js has syntax errors
const fs = require('fs');
const path = require('path');

const jsFile = '/Users/francisco/Documents/CALUDE/showtrackai-local-copy/build/web/main.dart.js';

try {
  console.log('Reading main.dart.js...');
  const content = fs.readFileSync(jsFile, 'utf8');
  
  console.log('File size:', content.length, 'characters');
  console.log('First 100 characters:', content.substring(0, 100));
  
  // Try to evaluate just the first function declaration to check syntax
  const firstFunction = content.substring(0, 1000);
  console.log('Testing syntax of first 1000 characters...');
  
  // Don't actually run it, just check if it's valid syntax
  new Function(firstFunction.replace('dartProgram(){', 'return function dartProgram(){') + '}');
  
  console.log('✅ JavaScript syntax appears valid');
  
  // Check if it's a complete file
  if (content.includes('dartProgram()') || content.includes('main(')) {
    console.log('✅ File appears to have main function calls');
  } else {
    console.log('⚠️  No main function call found at end of file');
  }
  
} catch (error) {
  console.error('❌ JavaScript syntax error:', error.message);
  process.exit(1);
}