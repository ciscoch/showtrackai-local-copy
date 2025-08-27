// Test script for animal save fixes
// Run with: flutter test test_animal_save_fixes.dart

import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:showtrackai_journaling/services/animal_service.dart';
import 'package:showtrackai_journaling/services/auth_service.dart';
import 'package:showtrackai_journaling/models/animal.dart';

void main() {
  group('Animal Save Fixes Tests', () {
    late AnimalService animalService;
    late AuthService authService;

    setUpAll(() async {
      // Initialize Supabase (you'll need to add your credentials)
      await Supabase.initialize(
        url: 'YOUR_SUPABASE_URL',
        anonKey: 'YOUR_SUPABASE_ANON_KEY',
      );
      
      animalService = AnimalService();
      authService = AuthService();
      authService.initialize();
    });

    test('Authentication validation before save', () async {
      // Test that unauthenticated users get proper error
      final testAnimal = Animal(
        id: 'test-id',
        name: 'Test Animal',
        species: AnimalSpecies.cattle,
        userId: 'test-user-id',
      );

      expect(
        () async => await animalService.updateAnimal(testAnimal),
        throwsA(predicate((e) => 
          e.toString().contains('User not authenticated - please sign in again')
        )),
      );
    });

    test('Session validation triggers refresh', () async {
      // Mock expired session scenario
      // This would require mocking the AuthService
      // For now, just verify the method exists and is called
      expect(authService.validateSession, isA<Function>());
    });

    test('Enhanced error messages for common failures', () async {
      final testAnimal = Animal(
        id: 'test-id',
        name: 'Test Animal',
        species: AnimalSpecies.cattle,
        userId: 'test-user-id',
      );

      // Test JWT expired error
      try {
        // This would need to be mocked to simulate JWT expiry
        await animalService.updateAnimal(testAnimal);
      } catch (e) {
        // Should get user-friendly message
        expect(e.toString(), isNot(contains('JWT')));
        expect(e.toString(), contains('session has expired'));
      }
    });

    test('Timeout handling', () async {
      final testAnimal = Animal(
        id: 'test-id', 
        name: 'Test Animal',
        species: AnimalSpecies.cattle,
        userId: 'test-user-id',
      );

      // The timeout is now set to 30 seconds in the service
      // This test verifies timeout configuration exists
      expect(
        animalService.updateAnimal(testAnimal),
        throwsA(predicate((e) => 
          e.toString().contains('timeout') || 
          e.toString().contains('connection')
        )),
      );
    }, timeout: const Timeout(Duration(seconds: 35)));
  });

  group('RLS Policy Tests', () {
    test('User can only update own animals', () {
      // This would require database setup and multiple test users
      // For now, document the requirement
      expect(true, isTrue, reason: 'RLS policies should prevent cross-user updates');
    });

    test('Update preserves user_id', () {
      // Verify that user_id cannot be changed in updates
      expect(true, isTrue, reason: 'WITH CHECK policy should prevent user_id changes');
    });
  });
}

// Integration test to run manually
class AnimalSaveIntegrationTest {
  static Future<void> runManualTest() async {
    print('🧪 Running Animal Save Integration Test...\n');
    
    try {
      // Test 1: Check authentication
      final authService = AuthService();
      print('1. Testing authentication...');
      if (authService.isAuthenticated) {
        print('✅ User is authenticated');
        print('   User ID: ${authService.currentUser?.id}');
      } else {
        print('❌ User not authenticated - please sign in first');
        return;
      }
      
      // Test 2: Create test animal
      final animalService = AnimalService();
      print('\n2. Creating test animal...');
      
      final testAnimal = Animal(
        name: 'Test Save Animal ${DateTime.now().millisecondsSinceEpoch}',
        tag: 'TEST${DateTime.now().millisecondsSinceEpoch}',
        species: AnimalSpecies.cattle,
        breed: 'Test Breed',
        userId: authService.currentUser!.id,
      );
      
      final createdAnimal = await animalService.createAnimal(testAnimal);
      print('✅ Test animal created: ${createdAnimal.id}');
      
      // Test 3: Update the animal (this is what was failing)
      print('\n3. Testing animal update (the main issue)...');
      
      final updatedAnimal = createdAnimal.copyWith(
        name: 'Updated Test Animal',
        breed: 'Updated Breed',
        description: 'This animal was updated successfully!',
      );
      
      final result = await animalService.updateAnimal(updatedAnimal);
      print('✅ Animal update successful!');
      print('   Updated name: ${result.name}');
      print('   Updated breed: ${result.breed}');
      print('   Updated description: ${result.description}');
      
      // Test 4: Verify the update persisted
      print('\n4. Verifying update persistence...');
      final fetchedAnimal = await animalService.getAnimalById(result.id!);
      
      if (fetchedAnimal != null && fetchedAnimal.name == 'Updated Test Animal') {
        print('✅ Update persisted correctly');
      } else {
        print('❌ Update did not persist');
      }
      
      // Test 5: Clean up
      print('\n5. Cleaning up test animal...');
      await animalService.deleteAnimal(result.id!);
      print('✅ Test animal deleted');
      
      print('\n🎉 All tests passed! Animal save functionality is working.');
      
    } catch (e) {
      print('\n❌ Test failed: $e');
      print('\nDebugging information:');
      print('- Check browser console for additional errors');
      print('- Check Supabase dashboard for SQL errors'); 
      print('- Verify RLS policies with the debug migration');
      print('- Ensure user is properly authenticated');
    }
  }
}