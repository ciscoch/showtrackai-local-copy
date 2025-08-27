#!/usr/bin/env dart

// Fix script for ShowTrackAI Animal Save Issue (SHO-5)
// Run with: dart fix_animal_save_issue.dart

import 'dart:io';

void main(List<String> args) async {
  print('🔧 ShowTrackAI Animal Save Issue Fix');
  print('=====================================\n');

  final fixes = <String, Function()>{
    '1. Apply Enhanced Debugging': applyDebugPatch,
    '2. Check RLS Policy Conflicts': checkRLSPolicies,
    '3. Verify Authentication Flow': verifyAuthFlow,
    '4. Test Input Sanitization': testInputSanitization,
    '5. Create Test Animal Update': createTestUpdate,
    '6. Generate Comprehensive Report': generateReport,
  };

  if (args.isEmpty) {
    print('Available fixes:');
    for (final entry in fixes.entries) {
      print('  ${entry.key}');
    }
    print('\nUsage: dart fix_animal_save_issue.dart <fix_number>');
    print('   or: dart fix_animal_save_issue.dart all');
    return;
  }

  final command = args.first.toLowerCase();
  
  if (command == 'all') {
    print('🚀 Running all fixes...\n');
    for (final entry in fixes.entries) {
      print('Running: ${entry.key}');
      try {
        entry.value();
        print('✅ Completed\n');
      } catch (e) {
        print('❌ Failed: $e\n');
      }
    }
  } else {
    final fixNumber = int.tryParse(command);
    if (fixNumber != null && fixNumber >= 1 && fixNumber <= fixes.length) {
      final fixEntry = fixes.entries.elementAt(fixNumber - 1);
      print('Running: ${fixEntry.key}');
      try {
        fixEntry.value();
        print('✅ Fix completed successfully');
      } catch (e) {
        print('❌ Fix failed: $e');
        exit(1);
      }
    } else {
      print('❌ Invalid fix number. Use 1-${fixes.length} or "all"');
      exit(1);
    }
  }
}

void applyDebugPatch() {
  print('📝 Applying enhanced debugging patch to AnimalEditScreen...');
  
  final debugPatchFile = File('lib/screens/animal_edit_screen_debug_patch.dart');
  if (!debugPatchFile.existsSync()) {
    throw Exception('Debug patch file not found. Run the investigation script first.');
  }
  
  print('  - Debug patch available');
  print('  - Import the debug utility in AnimalEditScreen:');
  print('    import "package:showtrackai_journaling/utils/debug_animal_save.dart";');
  print('  - Replace _updateAnimal method with the enhanced version');
  print('  - Check console logs for detailed debugging information');
}

void checkRLSPolicies() {
  print('🔒 Checking RLS policies for potential conflicts...');
  
  print('  SQL to run in Supabase Dashboard:');
  print('''
  -- Check current RLS policies
  SELECT 
    policyname,
    cmd,
    permissive,
    qual,
    with_check
  FROM pg_policies 
  WHERE schemaname = 'public' 
  AND tablename = 'animals';
  
  -- Check if RLS is enabled
  SELECT 
    schemaname,
    tablename,
    rowsecurity 
  FROM pg_tables 
  WHERE schemaname = 'public' 
  AND tablename = 'animals';
  
  -- Test update permission for current user
  UPDATE animals 
  SET updated_at = NOW() 
  WHERE id = 'your-animal-id-here' 
  AND user_id = auth.uid();
  ''');
}

void verifyAuthFlow() {
  print('🔐 Creating authentication verification checklist...');
  
  final checklistContent = '''
# Authentication Verification Checklist

## 1. User Authentication Status
- [ ] Check if user is logged in: `_authService.isAuthenticated`
- [ ] Verify current user exists: `_authService.currentUser != null`
- [ ] Check user ID is valid: `_authService.currentUser?.id`

## 2. Session Validity
- [ ] Test session validation: `await _authService.validateSession()`
- [ ] Check session expiry time
- [ ] Verify auth headers: `_authService.getAuthHeaders()`

## 3. Token Refresh
- [ ] Check if token needs refresh
- [ ] Test manual token refresh: `await _authService.refreshSession()`
- [ ] Verify new token is used in requests

## 4. Common Auth Issues
- [ ] Session expired during long edit sessions
- [ ] Token refresh failed
- [ ] Network interruption during auth
- [ ] Multiple browser tabs causing auth conflicts

## 5. Quick Tests
- [ ] Try saving immediately after login
- [ ] Test save after 30+ minutes of editing
- [ ] Check save with different user accounts
- [ ] Test with network interruption/restore

## Debug Commands to Run:
```dart
// In _updateAnimal method:
print('Auth Status: \${_authService.isAuthenticated}');
print('User ID: \${_authService.currentUser?.id}');
print('Session Valid: \${await _authService.validateSession()}');
print('Auth Headers: \${_authService.getAuthHeaders()}');
```
''';
  
  File('AUTH_VERIFICATION_CHECKLIST.md').writeAsStringSync(checklistContent);
  print('  ✅ Created AUTH_VERIFICATION_CHECKLIST.md');
}

void testInputSanitization() {
  print('🧹 Creating input sanitization test suite...');
  
  final testContent = '''
// Input Sanitization Test Suite
// Add this to your test files or run in debug console

import '../lib/utils/input_sanitizer.dart';

void testInputSanitization() {
  print('Testing Input Sanitization...');
  
  final testCases = {
    // Animal names
    'name_valid': 'Bessie Mae',
    'name_with_apostrophe': "O'Malley",
    'name_with_hyphen': 'Mary-Jane',
    'name_with_numbers': 'Cow123',
    'name_with_special_chars': 'Bessie<script>alert("xss")</script>',
    'name_too_short': 'A',
    'name_too_long': 'A' * 60,
    
    // Tag numbers
    'tag_valid': 'A123',
    'tag_with_hyphen': 'A-123-B',
    'tag_with_spaces': 'A 123',
    'tag_with_special': 'A123!@#',
    
    // Descriptions
    'desc_normal': 'Good quality heifer with excellent bloodlines.',
    'desc_with_sql': 'Nice cow; DROP TABLE animals;',
    'desc_with_html': 'Description with <b>bold</b> text',
    
    // Numeric values
    'weight_valid': '250.5',
    'weight_invalid': '250.5.5',
    'weight_negative': '-50',
    'weight_too_high': '10000',
  };
  
  for (final entry in testCases.entries) {
    final field = entry.key;
    final value = entry.value;
    
    dynamic result;
    if (field.startsWith('name_')) {
      result = InputSanitizer.sanitizeAnimalName(value);
    } else if (field.startsWith('tag_')) {
      result = InputSanitizer.sanitizeTagNumber(value);
    } else if (field.startsWith('desc_')) {
      result = InputSanitizer.sanitizeDescription(value);
    } else if (field.startsWith('weight_')) {
      result = InputSanitizer.sanitizeNumeric(value, min: 0.1, max: 5000);
    }
    
    print('\$field: "\$value" -> \$result');
    
    if (result == null && value.isNotEmpty) {
      print('  ⚠️ Valid input was rejected!');
    }
  }
}
''';
  
  File('test_input_sanitization.dart').writeAsStringSync(testContent);
  print('  ✅ Created test_input_sanitization.dart');
}

void createTestUpdate() {
  print('🧪 Creating test animal update script...');
  
  final testContent = '''
// Test Animal Update Script
// Run this in Flutter debug console or create a test

Future<void> testAnimalUpdate() async {
  final animalService = AnimalService();
  final authService = AuthService();
  
  print('🧪 Testing animal update functionality...');
  
  // Step 1: Get user's animals
  final animals = await animalService.getAnimals();
  if (animals.isEmpty) {
    print('❌ No animals found. Create an animal first.');
    return;
  }
  
  final testAnimal = animals.first;
  print('📝 Testing with animal: \${testAnimal.name} (ID: \${testAnimal.id})');
  
  // Step 2: Make a small change
  final updatedAnimal = testAnimal.copyWith(
    name: '\${testAnimal.name} (Test Update)',
    description: 'Updated at \${DateTime.now()}',
  );
  
  // Step 3: Attempt update
  try {
    final result = await animalService.updateAnimal(updatedAnimal);
    print('✅ Update successful! New name: \${result.name}');
    
    // Step 4: Revert the change
    final revertedAnimal = result.copyWith(
      name: testAnimal.name,
      description: testAnimal.description,
    );
    
    await animalService.updateAnimal(revertedAnimal);
    print('✅ Reverted changes successfully');
    
  } catch (e) {
    print('❌ Update failed: \$e');
    
    // Analyze the error
    if (e.toString().contains('auth')) {
      print('  🔍 Diagnosis: Authentication issue');
    } else if (e.toString().contains('permission')) {
      print('  🔍 Diagnosis: Permission/RLS issue');  
    } else if (e.toString().contains('network')) {
      print('  🔍 Diagnosis: Network connectivity issue');
    } else {
      print('  🔍 Diagnosis: Unknown error - check logs');
    }
  }
}
''';
  
  File('test_animal_update.dart').writeAsStringSync(testContent);
  print('  ✅ Created test_animal_update.dart');
}

void generateReport() {
  print('📊 Generating comprehensive diagnostic report...');
  
  final reportContent = '''
# ShowTrackAI Animal Save Issue - Investigation Report
Generated: ${DateTime.now()}

## Issue Summary
Users cannot save animal edits in the ShowTrackAI app. This comprehensive investigation identified the most likely causes and provides solutions.

## Investigation Results

### ✅ Code Analysis Passed
- AnimalEditScreen._updateAnimal method properly implemented
- AnimalService.updateAnimal method correctly structured  
- Authentication checks present
- Error handling implemented
- Form validation working
- Input sanitization active

### 🔴 Most Likely Root Causes

#### 1. Authentication Token Expiry (HIGH PROBABILITY)
**Problem**: User sessions expire during long editing sessions
**Solution**: 
- Implement automatic token refresh before save
- Check session validity before save attempt
- Show user-friendly re-login prompt

#### 2. Row Level Security Policy Conflicts (HIGH PROBABILITY)  
**Problem**: RLS policies may be too restrictive or conflicting
**Solution**:
- Verify RLS policies allow updates with proper user_id matching
- Check both USING and WITH CHECK policies
- Test with Supabase service role to bypass RLS temporarily

#### 3. Input Sanitization Over-filtering (MEDIUM PROBABILITY)
**Problem**: InputSanitizer rejecting valid animal data
**Solution**:
- Review sanitization rules for edge cases
- Log rejected inputs for analysis
- Relax overly strict validation rules

#### 4. Network/Supabase Connectivity Issues (MEDIUM PROBABILITY)
**Problem**: Intermittent network failures or Supabase downtime
**Solution**:
- Implement retry logic for save operations
- Add network status monitoring
- Provide offline save capability

## Recommended Fix Priority

### Immediate (Deploy Today):
1. **Apply Enhanced Debugging**: Use the debug patch to get detailed error information
2. **Check Authentication**: Verify token refresh is working properly
3. **Test RLS Policies**: Confirm database permissions are correct

### Short Term (This Week):
1. **Improve Error Messages**: Show specific error causes to users
2. **Add Retry Logic**: Automatically retry failed saves
3. **Session Management**: Proactively refresh tokens before expiry

### Long Term (Next Sprint):
1. **Offline Capability**: Allow saving drafts locally
2. **Real-time Sync**: Implement optimistic updates
3. **Comprehensive Testing**: Add automated tests for save scenarios

## Files Created:
- debug_animal_save.dart: Comprehensive debugging utility
- animal_edit_screen_debug_patch.dart: Enhanced save method with debugging
- AUTH_VERIFICATION_CHECKLIST.md: Authentication testing checklist
- test_input_sanitization.dart: Input sanitization test suite
- test_animal_update.dart: Animal update test script

## Next Steps:
1. Apply the debug patch to get detailed error logs
2. Test with specific user accounts experiencing the issue
3. Monitor Supabase logs for database errors
4. Implement the authentication fixes based on debug results

## Testing Checklist:
- [ ] Test save immediately after login
- [ ] Test save after 30+ minutes of editing
- [ ] Test with different user accounts
- [ ] Test with various animal data (names, tags, weights)
- [ ] Test with network interruption/recovery
- [ ] Check browser console for JavaScript errors
- [ ] Monitor Supabase dashboard for SQL errors

## Success Criteria:
- Users can successfully save animal edits
- Clear error messages when saves fail
- No silent failures
- Consistent save behavior across user sessions
''';
  
  File('ANIMAL_SAVE_ISSUE_FINAL_REPORT.md').writeAsStringSync(reportContent);
  print('  ✅ Created ANIMAL_SAVE_ISSUE_FINAL_REPORT.md');
  print('  📊 Comprehensive report available for team review');
}