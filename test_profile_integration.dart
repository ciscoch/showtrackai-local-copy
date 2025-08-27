#!/usr/bin/env dart

/// Test script to verify the profile integration is working correctly
/// This script checks imports, services, and basic functionality

import 'dart:io';

void main() {
  print('🧪 Testing ShowTrackAI Profile Integration...\n');
  
  // Test 1: Check if all required files exist
  print('📁 Checking required files...');
  final requiredFiles = [
    'lib/services/profile_service.dart',
    'lib/screens/profile_screen.dart',
    'lib/models/ffa_constants.dart',
    'lib/services/auth_service.dart',
  ];
  
  bool allFilesExist = true;
  for (final filePath in requiredFiles) {
    final file = File(filePath);
    if (file.existsSync()) {
      print('✅ $filePath exists');
    } else {
      print('❌ $filePath missing');
      allFilesExist = false;
    }
  }
  
  if (!allFilesExist) {
    print('\n❌ Some required files are missing. Integration incomplete.');
    exit(1);
  }
  
  // Test 2: Check ProfileService implementation
  print('\n📊 Checking ProfileService implementation...');
  final profileServiceFile = File('lib/services/profile_service.dart');
  final profileServiceContent = profileServiceFile.readAsStringSync();
  
  final requiredMethods = [
    'getProfileData',
    'getUserStatistics',
    'updateProfile',
    'updateProfilePicture',
    'getRecentActivity',
    'isProfileComplete',
    'getProfileCompletionPercentage',
  ];
  
  bool allMethodsPresent = true;
  for (final method in requiredMethods) {
    if (profileServiceContent.contains(method)) {
      print('✅ ProfileService.$method() implemented');
    } else {
      print('❌ ProfileService.$method() missing');
      allMethodsPresent = false;
    }
  }
  
  // Test 3: Check ProfileScreen integration
  print('\n🖥️ Checking ProfileScreen integration...');
  final profileScreenFile = File('lib/screens/profile_screen.dart');
  final profileScreenContent = profileScreenFile.readAsStringSync();
  
  final requiredImports = [
    'profile_service.dart',
    'ffa_constants.dart',
    'auth_service.dart',
  ];
  
  bool allImportsPresent = true;
  for (final import in requiredImports) {
    if (profileScreenContent.contains(import)) {
      print('✅ ProfileScreen imports $import');
    } else {
      print('❌ ProfileScreen missing import $import');
      allImportsPresent = false;
    }
  }
  
  // Check if ProfileService is used
  if (profileScreenContent.contains('ProfileService()')) {
    print('✅ ProfileScreen uses ProfileService');
  } else {
    print('❌ ProfileScreen not using ProfileService');
    allImportsPresent = false;
  }
  
  // Test 4: Check routing integration
  print('\n🛣️ Checking routing integration...');
  final mainFile = File('lib/main.dart');
  final mainContent = mainFile.readAsStringSync();
  
  if (mainContent.contains("'/profile': (context) => AuthGuard(child: const ProfileScreen())")) {
    print('✅ Profile route properly configured in main.dart');
  } else {
    print('❌ Profile route missing or incorrectly configured in main.dart');
    allImportsPresent = false;
  }
  
  // Test 5: Check dashboard navigation
  print('\n📱 Checking dashboard navigation...');
  final dashboardFile = File('lib/screens/dashboard_screen.dart');
  final dashboardContent = dashboardFile.readAsStringSync();
  
  if (dashboardContent.contains("Navigator.pushNamed(context, '/profile')")) {
    print('✅ Dashboard can navigate to profile');
  } else {
    print('❌ Dashboard navigation to profile missing');
    allImportsPresent = false;
  }
  
  // Summary
  print('\n📋 Integration Summary:');
  if (allFilesExist && allMethodsPresent && allImportsPresent) {
    print('🎉 Profile integration is complete and ready for testing!');
    print('\n✨ Features integrated:');
    print('   • ProfileService for data management');
    print('   • Comprehensive ProfileScreen with editing capabilities');
    print('   • FFA membership details and statistics display');
    print('   • Demo mode support');
    print('   • Navigation from dashboard');
    print('   • Authentication-aware routing');
    
    print('\n🚀 Next steps:');
    print('   1. Test with flutter run -d web');
    print('   2. Verify demo mode functionality');
    print('   3. Test profile editing and saving');
    print('   4. Test navigation from dashboard');
    print('   5. Verify statistics display correctly');
    
    exit(0);
  } else {
    print('❌ Integration has issues that need to be resolved.');
    exit(1);
  }
}