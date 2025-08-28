#!/usr/bin/env node

/**
 * Test script to verify Netlify Functions dependencies
 * This tests if @supabase/supabase-js can be imported correctly
 */

console.log('🧪 Testing Netlify Functions Dependencies...\n');

try {
  // Test 1: Check if @supabase/supabase-js can be imported
  console.log('1. Testing @supabase/supabase-js import...');
  const { createClient } = require('@supabase/supabase-js');
  console.log('   ✅ @supabase/supabase-js imported successfully');
  
  // Test 2: Verify createClient function exists
  console.log('2. Testing createClient function...');
  if (typeof createClient === 'function') {
    console.log('   ✅ createClient function is available');
  } else {
    throw new Error('createClient is not a function');
  }
  
  // Test 3: Test creating a client instance (with mock values)
  console.log('3. Testing client creation...');
  const testClient = createClient(
    'https://test.supabase.co',
    'test-anon-key'
  );
  
  if (testClient && typeof testClient === 'object') {
    console.log('   ✅ Supabase client created successfully');
  } else {
    throw new Error('Failed to create Supabase client');
  }
  
  console.log('\n🎉 All dependency tests passed!');
  console.log('✅ Netlify Functions should be able to import @supabase/supabase-js');
  
} catch (error) {
  console.error('\n❌ Dependency test failed:');
  console.error('Error:', error.message);
  console.error('\n💡 Make sure to run "npm install" before deploying to Netlify');
  process.exit(1);
}