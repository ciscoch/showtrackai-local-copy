// Debug script to test animal save functionality
// Run with: dart debug_animal_save.dart

import 'dart:io';

void main() {
  print('=== ShowTrackAI Animal Save Debug ===\n');
  
  print('Checking key files for potential issues...\n');
  
  // Check if key files exist
  final files = [
    'lib/screens/animal_edit_screen.dart',
    'lib/services/animal_service.dart',
    'lib/services/auth_service.dart',
    'lib/models/animal.dart',
    'lib/utils/input_sanitizer.dart',
  ];
  
  for (final file in files) {
    if (File(file).existsSync()) {
      print('✅ $file exists');
    } else {
      print('❌ $file missing');
    }
  }
  
  print('\n=== Analyzing AnimalEditScreen._updateAnimal method ===');
  
  try {
    final content = File('lib/screens/animal_edit_screen.dart').readAsStringSync();
    
    // Check for common issues in the save method
    if (content.contains('_updateAnimal') && content.contains('updateAnimal')) {
      print('✅ _updateAnimal method exists and calls AnimalService.updateAnimal');
    } else {
      print('❌ _updateAnimal method or service call missing');
    }
    
    if (content.contains('_authService.isAuthenticated')) {
      print('✅ Authentication check present');
    } else {
      print('⚠️  Authentication check may be missing');
    }
    
    if (content.contains('try {') && content.contains('catch (e)')) {
      print('✅ Error handling present');
    } else {
      print('⚠️  Error handling may be missing');
    }
    
    if (content.contains('ScaffoldMessenger') && content.contains('SnackBar')) {
      print('✅ User feedback via SnackBar present');
    } else {
      print('⚠️  User feedback may be missing');
    }
    
    if (content.contains('setState(() => _isLoading = true)') && 
        content.contains('setState(() => _isLoading = false)')) {
      print('✅ Loading state management present');
    } else {
      print('⚠️  Loading state management may be incomplete');
    }
    
    // Check for form validation
    if (content.contains('_formKey.currentState!.validate()')) {
      print('✅ Form validation present');
    } else {
      print('⚠️  Form validation may be missing');
    }
    
  } catch (e) {
    print('❌ Error analyzing AnimalEditScreen: $e');
  }
  
  print('\n=== Analyzing AnimalService.updateAnimal method ===');
  
  try {
    final content = File('lib/services/animal_service.dart').readAsStringSync();
    
    if (content.contains('Future<Animal> updateAnimal(Animal animal)')) {
      print('✅ updateAnimal method signature correct');
    } else {
      print('❌ updateAnimal method signature incorrect or missing');
    }
    
    if (content.contains('_currentUserId == null')) {
      print('✅ Authentication check in service present');
    } else {
      print('⚠️  Authentication check in service may be missing');
    }
    
    if (content.contains('animal.id == null')) {
      print('✅ Animal ID validation present');
    } else {
      print('⚠️  Animal ID validation may be missing');
    }
    
    if (content.contains('.update(updateData)') && content.contains('.eq(\'user_id\', _currentUserId!)')) {
      print('✅ Update query with user_id filter present');
    } else {
      print('⚠️  Update query or user_id filter may be incorrect');
    }
    
    if (content.contains('updated_at')) {
      print('✅ updated_at timestamp handling present');
    } else {
      print('⚠️  updated_at timestamp may be missing');
    }
    
  } catch (e) {
    print('❌ Error analyzing AnimalService: $e');
  }
  
  print('\n=== Common Issues to Check ===');
  print('1. Is the user properly authenticated?');
  print('2. Does the user have permission to update this animal?');
  print('3. Are there any RLS policy conflicts?');
  print('4. Is the animal.id correctly set?');
  print('5. Are input validation errors preventing the save?');
  print('6. Is there a network connectivity issue?');
  print('7. Are there any Supabase errors in the console?');
  
  print('\n=== Next Steps for Debugging ===');
  print('1. Check browser/app console for JavaScript/Dart errors');
  print('2. Check Supabase dashboard logs for SQL errors');
  print('3. Test with a simple animal update (just name change)');
  print('4. Verify the user_id matches between frontend and database');
  print('5. Check network tab for failed HTTP requests');
  
  print('\n=== Debug Complete ===');
}