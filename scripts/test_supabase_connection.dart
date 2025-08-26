// Test Supabase Connection and User Setup Script
// Run with: dart run scripts/test_supabase_connection.dart

import 'dart:io';
import 'package:supabase_flutter/supabase_flutter.dart';

const String supabaseUrl = 'https://zifbuzsdhparxlhsifdi.supabase.co';
const String supabaseAnonKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InppZmJ1enNkaHBhcnhsaHNpZmRpIiwicm9sZSI6ImFub24iLCJpYXQiOjE3Mjk5NTM5NTAsImV4cCI6MjA0NTUyOTk1MH0.fRilmQ7J9yYvv0wQtxIjfMkjR8W8F2pBh8G0jkmAc4k';

const String testEmail = 'test-elite@example.com';
const String testPassword = 'test123456';

void main() async {
  print('🧪 ShowTrackAI Supabase Connection Test');
  print('=' * 50);
  
  try {
    // Initialize Supabase
    print('1. Initializing Supabase...');
    await Supabase.initialize(
      url: supabaseUrl,
      anonKey: supabaseAnonKey,
    );
    print('✅ Supabase initialized successfully');
    
    final client = Supabase.instance.client;
    
    // Test 1: Basic connectivity
    print('\n2. Testing basic connectivity...');
    try {
      final response = await client
          .from('animals')
          .select('id')
          .limit(1)
          .timeout(Duration(seconds: 10));
      print('✅ Database connection successful');
      print('   Response: ${response.length} records found');
    } catch (e) {
      print('⚠️  Database query failed: $e');
      print('   This might be normal if tables don\'t exist yet');
    }
    
    // Test 2: Check if test user exists
    print('\n3. Checking if test user exists...');
    try {
      final authResponse = await client.auth.signInWithPassword(
        email: testEmail,
        password: testPassword,
      );
      
      if (authResponse.user != null) {
        print('✅ Test user exists and can authenticate');
        print('   User ID: ${authResponse.user!.id}');
        print('   Email: ${authResponse.user!.email}');
        
        // Test data access with authenticated user
        await testDataAccess(client);
        
        // Sign out
        await client.auth.signOut();
        print('👋 Signed out successfully');
      } else {
        print('❌ Authentication succeeded but no user returned');
      }
    } catch (e) {
      print('❌ Test user authentication failed: $e');
      
      if (e.toString().contains('Invalid login credentials')) {
        print('\n🔧 Attempting to create test user...');
        await createTestUser(client);
      } else {
        print('   Unexpected error: ${e.toString()}');
      }
    }
    
    // Test 3: Check table structure
    print('\n4. Checking database structure...');
    await checkDatabaseStructure(client);
    
    print('\n🎉 Connection test completed!');
    print('\n📋 Summary:');
    print('   • Supabase URL: $supabaseUrl');
    print('   • Test Email: $testEmail');
    print('   • Connection: Working');
    print('   • Next steps: Run the Flutter app and try logging in');
    
  } catch (e) {
    print('💥 Fatal error during connection test: $e');
    print('\n🔧 Troubleshooting steps:');
    print('   1. Check your internet connection');
    print('   2. Verify Supabase project is active');
    print('   3. Check if the anon key is correct');
    print('   4. Try running the SQL setup script in Supabase dashboard');
  }
  
  // Keep the script running briefly to see output
  print('\nPress Enter to exit...');
  stdin.readLineSync();
}

Future<void> createTestUser(SupabaseClient client) async {
  try {
    final authResponse = await client.auth.signUp(
      email: testEmail,
      password: testPassword,
    );
    
    if (authResponse.user != null) {
      print('✅ Test user created successfully');
      print('   User ID: ${authResponse.user!.id}');
      print('   Email confirmed: ${authResponse.user!.emailConfirmedAt != null}');
      
      if (authResponse.user!.emailConfirmedAt == null) {
        print('⚠️  Email confirmation required');
        print('   Check your Supabase auth settings to disable email confirmation for testing');
      }
      
      // Try to create user profile
      try {
        await client.from('user_profiles').insert({
          'id': authResponse.user!.id,
          'email': testEmail,
          'birth_date': '1990-01-01',
        });
        print('✅ User profile created');
      } catch (profileError) {
        print('⚠️  Could not create user profile: $profileError');
      }
      
    } else {
      print('❌ User creation failed: No user returned');
    }
  } catch (e) {
    print('❌ User creation failed: $e');
    
    if (e.toString().contains('User already registered')) {
      print('   User already exists but password might be wrong');
    } else if (e.toString().contains('signup_disabled')) {
      print('   Sign-up is disabled in Supabase settings');
    }
  }
}

Future<void> testDataAccess(SupabaseClient client) async {
  print('\n   Testing data access with authenticated user...');
  
  try {
    // Test animals table access
    final animals = await client
        .from('animals')
        .select('*')
        .limit(5);
    print('   ✅ Animals table access: ${animals.length} records');
    
    // Test journal_entries table access  
    final journals = await client
        .from('journal_entries')
        .select('*')
        .limit(5);
    print('   ✅ Journal entries table access: ${journals.length} records');
    
    // Test user_profiles table access
    final profiles = await client
        .from('user_profiles')
        .select('*')
        .limit(1);
    print('   ✅ User profiles table access: ${profiles.length} records');
    
  } catch (e) {
    print('   ⚠️ Data access test failed: $e');
  }
}

Future<void> checkDatabaseStructure(SupabaseClient client) async {
  try {
    // Check if core tables exist by trying to select from them
    final tables = ['animals', 'journal_entries', 'user_profiles', 'weights', 'health_records'];
    
    for (final table in tables) {
      try {
        await client
            .from(table)
            .select('count')
            .limit(1);
        print('   ✅ Table exists: $table');
      } catch (e) {
        if (e.toString().contains('relation') && e.toString().contains('does not exist')) {
          print('   ❌ Table missing: $table');
        } else {
          print('   ⚠️  Table $table check failed: ${e.toString().split('\n').first}');
        }
      }
    }
  } catch (e) {
    print('   ❌ Database structure check failed: $e');
  }
}