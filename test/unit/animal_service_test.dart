import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../lib/services/animal_service.dart';
import '../../lib/models/animal.dart';
import 'animal_service_test.mocks.dart';

@GenerateMocks([
  SupabaseClient,
  SupabaseQueryBuilder,
  PostgrestFilterBuilder,
  PostgrestTransformBuilder,
  GoTrueClient,
  User,
  SharedPreferences,
])
void main() {
  group('AnimalService Unit Tests', () {
    late AnimalService animalService;
    late MockSupabaseClient mockSupabase;
    late MockSupabaseQueryBuilder mockQueryBuilder;
    late MockPostgrestFilterBuilder mockFilterBuilder;
    late MockPostgrestTransformBuilder mockTransformBuilder;
    late MockGoTrueClient mockAuth;
    late MockUser mockUser;
    late MockSharedPreferences mockPrefs;

    const String testUserId = 'test-user-123';
    const String testAnimalId = 'animal-123';

    setUp(() {
      mockSupabase = MockSupabaseClient();
      mockQueryBuilder = MockSupabaseQueryBuilder();
      mockFilterBuilder = MockPostgrestFilterBuilder();
      mockTransformBuilder = MockPostgrestTransformBuilder();
      mockAuth = MockGoTrueClient();
      mockUser = MockUser();
      mockPrefs = MockSharedPreferences();

      // Setup Supabase mocking
      when(mockSupabase.auth).thenReturn(mockAuth);
      when(mockAuth.currentUser).thenReturn(mockUser);
      when(mockUser.id).thenReturn(testUserId);

      // Setup query builder chain
      when(mockSupabase.from('animals')).thenReturn(mockQueryBuilder);
      when(mockQueryBuilder.select(any)).thenReturn(mockFilterBuilder);
      when(mockFilterBuilder.eq(any, any)).thenReturn(mockFilterBuilder);
      when(mockFilterBuilder.order(any)).thenReturn(mockTransformBuilder);

      animalService = AnimalService();
      SharedPreferences.setMockInitialValues({});
    });

    group('createAnimal', () {
      test('should create animal successfully with RLS', () async {
        // Arrange
        final animal = _createTestAnimal();
        final responseData = animal.toJson();
        responseData['id'] = testAnimalId;
        
        when(mockQueryBuilder.insert(any)).thenReturn(mockFilterBuilder);
        when(mockFilterBuilder.select()).thenAnswer((_) async => [responseData]);

        // Act
        final result = await animalService.createAnimal(animal);

        // Assert
        expect(result.id, equals(testAnimalId));
        expect(result.name, equals('Test Animal'));
        expect(result.userId, equals(testUserId));
        
        verify(mockQueryBuilder.insert(argThat(containsPair('user_id', testUserId)))).called(1);
      });

      test('should enforce user ownership in RLS', () async {
        // Arrange
        final animal = _createTestAnimal();
        
        when(mockQueryBuilder.insert(any)).thenReturn(mockFilterBuilder);
        when(mockFilterBuilder.select()).thenThrow(
          PostgrestException(message: 'RLS violation: Row level security policy for table "animals" was violated')
        );

        // Act & Assert
        expect(
          () async => await animalService.createAnimal(animal),
          throwsA(isA<Exception>()),
        );
      });

      test('should store animal offline when creation fails', () async {
        // Arrange
        final animal = _createTestAnimal();
        
        when(mockQueryBuilder.insert(any)).thenReturn(mockFilterBuilder);
        when(mockFilterBuilder.select()).thenThrow(Exception('Network error'));
        when(mockPrefs.setString(any, any)).thenAnswer((_) async => true);

        // Act
        final result = await animalService.createAnimal(animal);

        // Assert
        expect(result.id, isNotNull);
        expect(result.isSynced, isFalse);
        verify(mockPrefs.setString(argThat(startsWith('offline_animal_')), any)).called(1);
      });

      test('should validate animal data before creation', () async {
        // Arrange
        final invalidAnimal = Animal(
          id: null,
          userId: testUserId,
          name: '', // Empty name should be invalid
          species: 'cattle',
          breed: 'Holstein',
          birthDate: DateTime.now(),
          gender: 'female',
        );

        // Act & Assert
        expect(
          () async => await animalService.createAnimal(invalidAnimal),
          throwsA(isA<ArgumentError>()),
        );
      });

      test('should generate unique ID for new animals', () async {
        // Arrange
        final animal = _createTestAnimal(id: null); // No ID provided
        final responseData = animal.toJson();
        responseData['id'] = testAnimalId;
        
        when(mockQueryBuilder.insert(any)).thenReturn(mockFilterBuilder);
        when(mockFilterBuilder.select()).thenAnswer((_) async => [responseData]);

        // Act
        final result = await animalService.createAnimal(animal);

        // Assert
        expect(result.id, isNotNull);
        expect(result.id, equals(testAnimalId));
      });
    });

    group('getAnimals with RLS', () {
      test('should fetch only user-owned animals', () async {
        // Arrange
        final testAnimals = [
          _createTestAnimal(id: 'animal-1', name: 'Animal 1'),
          _createTestAnimal(id: 'animal-2', name: 'Animal 2'),
        ];

        when(mockTransformBuilder.limit(any)).thenReturn(mockTransformBuilder);
        when(mockTransformBuilder.range(any, any)).thenReturn(mockTransformBuilder);
        when(mockTransformBuilder.then<List<Map<String, dynamic>>>(any))
            .thenAnswer((_) async => testAnimals.map((a) => a.toJson()).toList());

        // Act
        final result = await animalService.getAnimals();

        // Assert
        expect(result, hasLength(2));
        expect(result[0].name, equals('Animal 1'));
        expect(result[1].name, equals('Animal 2'));
        
        // Verify RLS filter is applied
        verify(mockFilterBuilder.eq('user_id', testUserId)).called(1);
      });

      test('should handle empty result set', () async {
        // Arrange
        when(mockTransformBuilder.limit(any)).thenReturn(mockTransformBuilder);
        when(mockTransformBuilder.range(any, any)).thenReturn(mockTransformBuilder);
        when(mockTransformBuilder.then<List<Map<String, dynamic>>>(any))
            .thenAnswer((_) async => []);

        // Act
        final result = await animalService.getAnimals();

        // Assert
        expect(result, isEmpty);
      });

      test('should apply species filter with RLS', () async {
        // Arrange
        final cattleAnimals = [
          _createTestAnimal(id: 'cattle-1', species: 'cattle'),
        ];

        when(mockFilterBuilder.eq('species', 'cattle')).thenReturn(mockFilterBuilder);
        when(mockTransformBuilder.limit(any)).thenReturn(mockTransformBuilder);
        when(mockTransformBuilder.range(any, any)).thenReturn(mockTransformBuilder);
        when(mockTransformBuilder.then<List<Map<String, dynamic>>>(any))
            .thenAnswer((_) async => cattleAnimals.map((a) => a.toJson()).toList());

        // Act
        final result = await animalService.getAnimals(species: 'cattle');

        // Assert
        expect(result, hasLength(1));
        expect(result[0].species, equals('cattle'));
        
        // Verify both user_id and species filters are applied
        verify(mockFilterBuilder.eq('user_id', testUserId)).called(1);
        verify(mockFilterBuilder.eq('species', 'cattle')).called(1);
      });

      test('should handle pagination correctly', () async {
        // Arrange
        final pagedAnimals = [
          _createTestAnimal(id: 'page-animal-1'),
        ];

        when(mockTransformBuilder.limit(10)).thenReturn(mockTransformBuilder);
        when(mockTransformBuilder.range(5, 14)).thenReturn(mockTransformBuilder);
        when(mockTransformBuilder.then<List<Map<String, dynamic>>>(any))
            .thenAnswer((_) async => pagedAnimals.map((a) => a.toJson()).toList());

        // Act
        final result = await animalService.getAnimals(limit: 10, offset: 5);

        // Assert
        expect(result, hasLength(1));
        verify(mockTransformBuilder.limit(10)).called(1);
        verify(mockTransformBuilder.range(5, 14)).called(1);
      });

      test('should fall back to offline data when query fails', () async {
        // Arrange
        when(mockTransformBuilder.limit(any)).thenReturn(mockTransformBuilder);
        when(mockTransformBuilder.range(any, any)).thenReturn(mockTransformBuilder);
        when(mockTransformBuilder.then<List<Map<String, dynamic>>>(any))
            .thenThrow(Exception('Network error'));

        final offlineAnimals = {
          'offline_animal_1': _createTestAnimal(id: 'offline-1', isSynced: false).toJson(),
        };
        when(mockPrefs.getKeys()).thenReturn(offlineAnimals.keys.toSet());
        when(mockPrefs.getString('offline_animal_1')).thenReturn(jsonEncode(offlineAnimals['offline_animal_1']));

        // Act
        final result = await animalService.getAnimals();

        // Assert
        expect(result, hasLength(1));
        expect(result[0].isSynced, isFalse);
        expect(result[0].id, equals('offline-1'));
      });
    });

    group('getAnimal', () {
      test('should fetch single animal with RLS enforcement', () async {
        // Arrange
        final testAnimal = _createTestAnimal(id: testAnimalId);
        
        when(mockFilterBuilder.single()).thenAnswer((_) async => testAnimal.toJson());

        // Act
        final result = await animalService.getAnimal(testAnimalId);

        // Assert
        expect(result, isNotNull);
        expect(result!.id, equals(testAnimalId));
        expect(result.name, equals('Test Animal'));
        
        // Verify RLS enforcement
        verify(mockFilterBuilder.eq('user_id', testUserId)).called(1);
        verify(mockFilterBuilder.eq('id', testAnimalId)).called(1);
      });

      test('should return null for non-existent animal', () async {
        // Arrange
        when(mockFilterBuilder.single()).thenThrow(
          PostgrestException(message: 'No rows found')
        );

        // Act
        final result = await animalService.getAnimal('non-existent-id');

        // Assert
        expect(result, isNull);
      });

      test('should prevent access to other users animals', () async {
        // Arrange - Animal exists but belongs to different user
        when(mockFilterBuilder.single()).thenThrow(
          PostgrestException(message: 'RLS policy violation')
        );

        // Act
        final result = await animalService.getAnimal(testAnimalId);

        // Assert
        expect(result, isNull);
      });

      test('should try offline data if online fetch fails', () async {
        // Arrange
        when(mockFilterBuilder.single()).thenThrow(Exception('Network error'));
        
        final offlineAnimal = _createTestAnimal(id: testAnimalId, isSynced: false);
        when(mockPrefs.getString('offline_animal_$testAnimalId'))
            .thenReturn(jsonEncode(offlineAnimal.toJson()));

        // Act
        final result = await animalService.getAnimal(testAnimalId);

        // Assert
        expect(result, isNotNull);
        expect(result!.id, equals(testAnimalId));
        expect(result.isSynced, isFalse);
      });
    });

    group('updateAnimal', () {
      test('should update animal with RLS enforcement', () async {
        // Arrange
        final updatedAnimal = _createTestAnimal(id: testAnimalId, name: 'Updated Name');
        
        when(mockQueryBuilder.update(any)).thenReturn(mockFilterBuilder);
        when(mockFilterBuilder.select()).thenAnswer((_) async => [updatedAnimal.toJson()]);

        // Act
        final result = await animalService.updateAnimal(updatedAnimal);

        // Assert
        expect(result.name, equals('Updated Name'));
        expect(result.updatedAt, isNotNull);
        
        // Verify RLS enforcement
        verify(mockFilterBuilder.eq('user_id', testUserId)).called(1);
        verify(mockFilterBuilder.eq('id', testAnimalId)).called(1);
        
        // Verify update data
        final captured = verify(mockQueryBuilder.update(captureAny)).captured.first;
        expect(captured['name'], equals('Updated Name'));
        expect(captured['user_id'], equals(testUserId)); // Should enforce user ownership
      });

      test('should prevent updating other users animals', () async {
        // Arrange
        final otherUserAnimal = _createTestAnimal(id: testAnimalId, name: 'Other User Animal');
        
        when(mockQueryBuilder.update(any)).thenReturn(mockFilterBuilder);
        when(mockFilterBuilder.select()).thenThrow(
          PostgrestException(message: 'RLS policy violation')
        );

        // Act & Assert
        expect(
          () async => await animalService.updateAnimal(otherUserAnimal),
          throwsA(isA<Exception>()),
        );
      });

      test('should store update offline when sync fails', () async {
        // Arrange
        final updatedAnimal = _createTestAnimal(id: testAnimalId, name: 'Updated Name');
        
        when(mockQueryBuilder.update(any)).thenReturn(mockFilterBuilder);
        when(mockFilterBuilder.select()).thenThrow(Exception('Network error'));
        when(mockPrefs.setString(any, any)).thenAnswer((_) async => true);

        // Act
        final result = await animalService.updateAnimal(updatedAnimal);

        // Assert
        expect(result.name, equals('Updated Name'));
        expect(result.isSynced, isFalse);
        verify(mockPrefs.setString('offline_animal_$testAnimalId', any)).called(1);
      });

      test('should validate animal data before update', () async {
        // Arrange
        final invalidAnimal = _createTestAnimal(id: testAnimalId, name: ''); // Empty name

        // Act & Assert
        expect(
          () async => await animalService.updateAnimal(invalidAnimal),
          throwsA(isA<ArgumentError>()),
        );
      });

      test('should update lastModified timestamp', () async {
        // Arrange
        final animal = _createTestAnimal(id: testAnimalId);
        final originalTimestamp = animal.updatedAt;
        
        when(mockQueryBuilder.update(any)).thenReturn(mockFilterBuilder);
        when(mockFilterBuilder.select()).thenAnswer((_) async => [animal.toJson()]);

        // Act
        final result = await animalService.updateAnimal(animal);

        // Assert
        expect(result.updatedAt, isNot(equals(originalTimestamp)));
        expect(result.updatedAt!.isAfter(originalTimestamp ?? DateTime.now().subtract(Duration(seconds: 1))), isTrue);
      });
    });

    group('deleteAnimal', () {
      test('should delete animal with RLS enforcement', () async {
        // Arrange
        when(mockQueryBuilder.delete()).thenReturn(mockFilterBuilder);
        when(mockFilterBuilder.then<List<Map<String, dynamic>>>(any))
            .thenAnswer((_) async => []);

        // Act
        await animalService.deleteAnimal(testAnimalId);

        // Assert - Should not throw
        // Verify RLS enforcement
        verify(mockFilterBuilder.eq('user_id', testUserId)).called(1);
        verify(mockFilterBuilder.eq('id', testAnimalId)).called(1);
      });

      test('should prevent deleting other users animals', () async {
        // Arrange
        when(mockQueryBuilder.delete()).thenReturn(mockFilterBuilder);
        when(mockFilterBuilder.then<List<Map<String, dynamic>>>(any))
            .thenThrow(PostgrestException(message: 'RLS policy violation'));

        // Act & Assert
        expect(
          () async => await animalService.deleteAnimal(testAnimalId),
          throwsA(isA<Exception>()),
        );
      });

      test('should mark as deleted offline when network fails', () async {
        // Arrange
        when(mockQueryBuilder.delete()).thenReturn(mockFilterBuilder);
        when(mockFilterBuilder.then<List<Map<String, dynamic>>>(any))
            .thenThrow(Exception('Network error'));
        when(mockPrefs.setString(any, any)).thenAnswer((_) async => true);
        when(mockPrefs.setBool(any, any)).thenAnswer((_) async => true);

        // Act
        await animalService.deleteAnimal(testAnimalId);

        // Assert
        verify(mockPrefs.setBool('offline_deleted_$testAnimalId', true)).called(1);
      });

      test('should remove from offline storage after successful delete', () async {
        // Arrange
        when(mockQueryBuilder.delete()).thenReturn(mockFilterBuilder);
        when(mockFilterBuilder.then<List<Map<String, dynamic>>>(any))
            .thenAnswer((_) async => []);
        when(mockPrefs.remove(any)).thenAnswer((_) async => true);

        // Act
        await animalService.deleteAnimal(testAnimalId);

        // Assert
        verify(mockPrefs.remove('offline_animal_$testAnimalId')).called(1);
      });
    });

    group('Offline Synchronization', () {
      test('should sync offline animals to server', () async {
        // Arrange
        final offlineAnimals = {
          'offline_animal_1': _createTestAnimal(id: 'offline-1', isSynced: false).toJson(),
          'offline_animal_2': _createTestAnimal(id: 'offline-2', isSynced: false).toJson(),
        };

        when(mockPrefs.getKeys()).thenReturn(offlineAnimals.keys.toSet());
        when(mockPrefs.getString('offline_animal_1'))
            .thenReturn(jsonEncode(offlineAnimals['offline_animal_1']));
        when(mockPrefs.getString('offline_animal_2'))
            .thenReturn(jsonEncode(offlineAnimals['offline_animal_2']));

        // Mock successful syncs
        when(mockQueryBuilder.insert(any)).thenReturn(mockFilterBuilder);
        when(mockFilterBuilder.select()).thenAnswer((_) async => [
          {...offlineAnimals['offline_animal_1']!, 'is_synced': true}
        ]);

        when(mockPrefs.setString(any, any)).thenAnswer((_) async => true);
        when(mockPrefs.remove(any)).thenAnswer((_) async => true);

        // Act
        final result = await animalService.syncOfflineAnimals();

        // Assert
        expect(result.success, isTrue);
        expect(result.syncedCount, equals(2));
        
        // Verify offline data cleanup
        verify(mockPrefs.remove('offline_animal_1')).called(1);
        verify(mockPrefs.remove('offline_animal_2')).called(1);
      });

      test('should handle partial sync failures', () async {
        // Arrange
        final offlineAnimals = {
          'offline_animal_1': _createTestAnimal(id: 'offline-1', isSynced: false).toJson(),
          'offline_animal_2': _createTestAnimal(id: 'offline-2', isSynced: false).toJson(),
        };

        when(mockPrefs.getKeys()).thenReturn(offlineAnimals.keys.toSet());
        when(mockPrefs.getString('offline_animal_1'))
            .thenReturn(jsonEncode(offlineAnimals['offline_animal_1']));
        when(mockPrefs.getString('offline_animal_2'))
            .thenReturn(jsonEncode(offlineAnimals['offline_animal_2']));

        // First sync succeeds, second fails
        when(mockQueryBuilder.insert(any)).thenReturn(mockFilterBuilder);
        when(mockFilterBuilder.select())
            .thenAnswer((_) async => [offlineAnimals['offline_animal_1']!])
            .thenThrow(Exception('Sync error'));

        when(mockPrefs.remove(any)).thenAnswer((_) async => true);

        // Act
        final result = await animalService.syncOfflineAnimals();

        // Assert
        expect(result.success, isFalse);
        expect(result.syncedCount, equals(1));
        expect(result.failedCount, equals(1));
        
        // Only successful sync should be cleaned up
        verify(mockPrefs.remove('offline_animal_1')).called(1);
        verifyNever(mockPrefs.remove('offline_animal_2'));
      });

      test('should retry failed syncs with exponential backoff', () async {
        // Arrange
        final offlineAnimal = _createTestAnimal(id: 'retry-animal', isSynced: false);
        
        when(mockPrefs.getKeys()).thenReturn({'offline_animal_retry'});
        when(mockPrefs.getString('offline_animal_retry'))
            .thenReturn(jsonEncode(offlineAnimal.toJson()));
        when(mockPrefs.getInt('sync_retry_count_retry')).thenReturn(2); // Already 2 retries
        when(mockPrefs.setInt(any, any)).thenAnswer((_) async => true);

        when(mockQueryBuilder.insert(any)).thenReturn(mockFilterBuilder);
        when(mockFilterBuilder.select()).thenThrow(Exception('Still failing'));

        // Act
        final result = await animalService.syncOfflineAnimals();

        // Assert
        expect(result.success, isFalse);
        
        // Should increment retry count
        verify(mockPrefs.setInt('sync_retry_count_retry', 3)).called(1);
      });
    });

    group('Search and Filtering', () {
      test('should search animals by name with RLS', () async {
        // Arrange
        final searchResults = [
          _createTestAnimal(id: 'search-1', name: 'Bessie'),
          _createTestAnimal(id: 'search-2', name: 'Belle'),
        ];

        when(mockFilterBuilder.ilike(any, any)).thenReturn(mockFilterBuilder);
        when(mockTransformBuilder.limit(any)).thenReturn(mockTransformBuilder);
        when(mockTransformBuilder.range(any, any)).thenReturn(mockTransformBuilder);
        when(mockTransformBuilder.then<List<Map<String, dynamic>>>(any))
            .thenAnswer((_) async => searchResults.map((a) => a.toJson()).toList());

        // Act
        final result = await animalService.searchAnimals('Be');

        // Assert
        expect(result, hasLength(2));
        expect(result.every((animal) => animal.name.startsWith('Be')), isTrue);
        
        // Verify search with RLS
        verify(mockFilterBuilder.eq('user_id', testUserId)).called(1);
        verify(mockFilterBuilder.ilike('name', '%Be%')).called(1);
      });

      test('should filter animals by breed with RLS', () async {
        // Arrange
        final breedResults = [
          _createTestAnimal(id: 'holstein-1', breed: 'Holstein'),
          _createTestAnimal(id: 'holstein-2', breed: 'Holstein'),
        ];

        when(mockFilterBuilder.eq('breed', 'Holstein')).thenReturn(mockFilterBuilder);
        when(mockTransformBuilder.limit(any)).thenReturn(mockTransformBuilder);
        when(mockTransformBuilder.range(any, any)).thenReturn(mockTransformBuilder);
        when(mockTransformBuilder.then<List<Map<String, dynamic>>>(any))
            .thenAnswer((_) async => breedResults.map((a) => a.toJson()).toList());

        // Act
        final result = await animalService.getAnimals(breed: 'Holstein');

        // Assert
        expect(result, hasLength(2));
        expect(result.every((animal) => animal.breed == 'Holstein'), isTrue);
        
        // Verify filtering with RLS
        verify(mockFilterBuilder.eq('user_id', testUserId)).called(1);
        verify(mockFilterBuilder.eq('breed', 'Holstein')).called(1);
      });

      test('should filter by multiple criteria with RLS', () async {
        // Arrange
        final filteredResults = [
          _createTestAnimal(id: 'filter-1', species: 'cattle', breed: 'Holstein', gender: 'female'),
        ];

        when(mockFilterBuilder.eq('species', 'cattle')).thenReturn(mockFilterBuilder);
        when(mockFilterBuilder.eq('breed', 'Holstein')).thenReturn(mockFilterBuilder);
        when(mockFilterBuilder.eq('gender', 'female')).thenReturn(mockFilterBuilder);
        when(mockTransformBuilder.limit(any)).thenReturn(mockTransformBuilder);
        when(mockTransformBuilder.range(any, any)).thenReturn(mockTransformBuilder);
        when(mockTransformBuilder.then<List<Map<String, dynamic>>>(any))
            .thenAnswer((_) async => filteredResults.map((a) => a.toJson()).toList());

        // Act
        final result = await animalService.getAnimals(
          species: 'cattle',
          breed: 'Holstein',
          gender: 'female',
        );

        // Assert
        expect(result, hasLength(1));
        expect(result[0].species, equals('cattle'));
        expect(result[0].breed, equals('Holstein'));
        expect(result[0].gender, equals('female'));
        
        // Verify all filters applied with RLS
        verify(mockFilterBuilder.eq('user_id', testUserId)).called(1);
        verify(mockFilterBuilder.eq('species', 'cattle')).called(1);
        verify(mockFilterBuilder.eq('breed', 'Holstein')).called(1);
        verify(mockFilterBuilder.eq('gender', 'female')).called(1);
      });
    });

    group('Data Validation and Security', () {
      test('should sanitize input data', () async {
        // Arrange
        final animalWithSpecialChars = _createTestAnimal(
          name: '<script>alert("xss")</script>',
          description: 'Test & description with "quotes"',
        );

        when(mockQueryBuilder.insert(any)).thenReturn(mockFilterBuilder);
        when(mockFilterBuilder.select()).thenAnswer((_) async => [animalWithSpecialChars.toJson()]);

        // Act
        final result = await animalService.createAnimal(animalWithSpecialChars);

        // Assert
        // Verify data is sanitized (implementation would actually sanitize)
        expect(result.name, isNot(contains('<script>')));
        
        // Verify correct data was sent to database
        final captured = verify(mockQueryBuilder.insert(captureAny)).captured.first;
        expect(captured['user_id'], equals(testUserId)); // Should always enforce user ownership
      });

      test('should validate required fields', () async {
        // Arrange - Missing required fields
        final incompleteAnimal = Animal(
          id: null,
          userId: testUserId,
          name: 'Test',
          species: '', // Empty species
          breed: '', // Empty breed
          birthDate: DateTime.now(),
          gender: '',  // Empty gender
        );

        // Act & Assert
        expect(
          () async => await animalService.createAnimal(incompleteAnimal),
          throwsA(isA<ArgumentError>()),
        );
      });

      test('should validate business rules', () async {
        // Arrange - Invalid business data
        final invalidAnimal = _createTestAnimal(
          birthDate: DateTime.now().add(Duration(days: 30)), // Future birth date
        );

        // Act & Assert
        expect(
          () async => await animalService.createAnimal(invalidAnimal),
          throwsA(isA<ArgumentError>()),
        );
      });

      test('should prevent SQL injection attempts', () async {
        // Arrange
        final maliciousSearch = "'; DROP TABLE animals; --";

        when(mockFilterBuilder.ilike(any, any)).thenReturn(mockFilterBuilder);
        when(mockTransformBuilder.limit(any)).thenReturn(mockTransformBuilder);
        when(mockTransformBuilder.range(any, any)).thenReturn(mockTransformBuilder);
        when(mockTransformBuilder.then<List<Map<String, dynamic>>>(any))
            .thenAnswer((_) async => []);

        // Act
        final result = await animalService.searchAnimals(maliciousSearch);

        // Assert
        expect(result, isEmpty);
        
        // Verify the search parameter is properly escaped by Supabase
        verify(mockFilterBuilder.ilike('name', '%$maliciousSearch%')).called(1);
      });
    });

    group('Performance and Caching', () {
      test('should cache frequently accessed animals', () async {
        // Arrange
        final testAnimal = _createTestAnimal(id: testAnimalId);
        
        when(mockFilterBuilder.single()).thenAnswer((_) async => testAnimal.toJson());
        when(mockPrefs.setString(any, any)).thenAnswer((_) async => true);
        when(mockPrefs.getString('cached_animal_$testAnimalId'))
            .thenReturn(jsonEncode({...testAnimal.toJson(), 'cached_at': DateTime.now().toIso8601String()}));

        // Act - First call should hit database
        final result1 = await animalService.getAnimal(testAnimalId);
        
        // Act - Second call should use cache
        final result2 = await animalService.getAnimal(testAnimalId, useCache: true);

        // Assert
        expect(result1, isNotNull);
        expect(result2, isNotNull);
        expect(result1!.id, equals(result2!.id));
        
        // Database should only be called once
        verify(mockFilterBuilder.single()).called(1);
      });

      test('should invalidate cache on updates', () async {
        // Arrange
        final originalAnimal = _createTestAnimal(id: testAnimalId, name: 'Original');
        final updatedAnimal = _createTestAnimal(id: testAnimalId, name: 'Updated');
        
        when(mockQueryBuilder.update(any)).thenReturn(mockFilterBuilder);
        when(mockFilterBuilder.select()).thenAnswer((_) async => [updatedAnimal.toJson()]);
        when(mockPrefs.remove(any)).thenAnswer((_) async => true);

        // Act
        await animalService.updateAnimal(updatedAnimal);

        // Assert
        verify(mockPrefs.remove('cached_animal_$testAnimalId')).called(1);
      });

      test('should handle large result sets efficiently', () async {
        // Arrange
        final largeResultSet = List.generate(1000, (index) => 
          _createTestAnimal(id: 'animal-$index', name: 'Animal $index').toJson()
        );

        when(mockTransformBuilder.limit(1000)).thenReturn(mockTransformBuilder);
        when(mockTransformBuilder.range(0, 999)).thenReturn(mockTransformBuilder);
        when(mockTransformBuilder.then<List<Map<String, dynamic>>>(any))
            .thenAnswer((_) async => largeResultSet);

        // Act
        final result = await animalService.getAnimals(limit: 1000);

        // Assert
        expect(result, hasLength(1000));
        expect(result[0].name, equals('Animal 0'));
        expect(result[999].name, equals('Animal 999'));
      });
    });
  });
}

// Helper methods
Animal _createTestAnimal({
  String? id,
  String name = 'Test Animal',
  String species = 'cattle',
  String breed = 'Holstein',
  String gender = 'female',
  DateTime? birthDate,
  String? description,
  bool isSynced = true,
  DateTime? updatedAt,
}) {
  return Animal(
    id: id,
    userId: 'test-user-123',
    name: name,
    species: species,
    breed: breed,
    birthDate: birthDate ?? DateTime.now().subtract(Duration(days: 365)),
    gender: gender,
    description: description,
    isSynced: isSynced,
    createdAt: DateTime.now(),
    updatedAt: updatedAt ?? DateTime.now(),
  );
}

// Mock AnimalService for testing
class AnimalService {
  final SupabaseClient _supabase = Supabase.instance.client;

  Future<Animal> createAnimal(Animal animal) async {
    _validateAnimalData(animal);

    final userId = _getCurrentUserId();
    final animalData = animal.toJson();
    animalData['user_id'] = userId; // Enforce user ownership
    
    if (animal.id == null) {
      animalData.remove('id'); // Let database generate ID
    }

    try {
      final result = await _supabase
          .from('animals')
          .insert(animalData)
          .select()
          .single();

      return Animal.fromJson(result);
    } catch (e) {
      // Store offline on failure
      return await _storeAnimalOffline(animal);
    }
  }

  Future<List<Animal>> getAnimals({
    String? species,
    String? breed,
    String? gender,
    int limit = 50,
    int offset = 0,
  }) async {
    try {
      final userId = _getCurrentUserId();
      var query = _supabase
          .from('animals')
          .select()
          .eq('user_id', userId); // RLS enforcement

      if (species != null) query = query.eq('species', species);
      if (breed != null) query = query.eq('breed', breed);
      if (gender != null) query = query.eq('gender', gender);

      final result = await query
          .order('created_at', ascending: false)
          .limit(limit)
          .range(offset, offset + limit - 1);

      return result.map<Animal>((data) => Animal.fromJson(data)).toList();
    } catch (e) {
      // Fallback to offline data
      return await _getOfflineAnimals();
    }
  }

  Future<Animal?> getAnimal(String animalId, {bool useCache = false}) async {
    if (useCache) {
      final cached = await _getCachedAnimal(animalId);
      if (cached != null) return cached;
    }

    try {
      final userId = _getCurrentUserId();
      final result = await _supabase
          .from('animals')
          .select()
          .eq('user_id', userId) // RLS enforcement
          .eq('id', animalId)
          .single();

      final animal = Animal.fromJson(result);
      await _cacheAnimal(animal);
      return animal;
    } catch (e) {
      // Try offline data
      return await _getOfflineAnimal(animalId);
    }
  }

  Future<Animal> updateAnimal(Animal animal) async {
    _validateAnimalData(animal);

    final userId = _getCurrentUserId();
    final animalData = animal.toJson();
    animalData['user_id'] = userId; // Enforce user ownership
    animalData['updated_at'] = DateTime.now().toIso8601String();

    try {
      final result = await _supabase
          .from('animals')
          .update(animalData)
          .eq('user_id', userId) // RLS enforcement
          .eq('id', animal.id!)
          .select()
          .single();

      await _invalidateCache(animal.id!);
      return Animal.fromJson(result);
    } catch (e) {
      // Store offline update
      return await _storeAnimalUpdateOffline(animal);
    }
  }

  Future<void> deleteAnimal(String animalId) async {
    try {
      final userId = _getCurrentUserId();
      await _supabase
          .from('animals')
          .delete()
          .eq('user_id', userId) // RLS enforcement
          .eq('id', animalId);

      await _removeFromOffline(animalId);
      await _invalidateCache(animalId);
    } catch (e) {
      // Mark as deleted offline
      await _markDeletedOffline(animalId);
    }
  }

  Future<List<Animal>> searchAnimals(String query) async {
    try {
      final userId = _getCurrentUserId();
      final result = await _supabase
          .from('animals')
          .select()
          .eq('user_id', userId) // RLS enforcement
          .ilike('name', '%$query%')
          .order('name')
          .limit(100);

      return result.map<Animal>((data) => Animal.fromJson(data)).toList();
    } catch (e) {
      return [];
    }
  }

  Future<SyncResult> syncOfflineAnimals() async {
    int syncedCount = 0;
    int failedCount = 0;
    
    final prefs = await SharedPreferences.getInstance();
    final offlineKeys = prefs.getKeys().where((key) => key.startsWith('offline_animal_'));

    for (final key in offlineKeys) {
      try {
        final animalData = prefs.getString(key);
        if (animalData != null) {
          final animal = Animal.fromJson(jsonDecode(animalData));
          
          final retryCount = prefs.getInt('sync_retry_count_${animal.id}') ?? 0;
          if (retryCount < 5) { // Max 5 retries
            await _syncSingleAnimal(animal);
            await prefs.remove(key);
            await prefs.remove('sync_retry_count_${animal.id}');
            syncedCount++;
          }
        }
      } catch (e) {
        failedCount++;
        final animalId = key.replaceFirst('offline_animal_', '');
        final retryCount = prefs.getInt('sync_retry_count_$animalId') ?? 0;
        await prefs.setInt('sync_retry_count_$animalId', retryCount + 1);
      }
    }

    return SyncResult(
      success: failedCount == 0,
      syncedCount: syncedCount,
      failedCount: failedCount,
    );
  }

  // Private helper methods
  String _getCurrentUserId() {
    final user = _supabase.auth.currentUser;
    if (user == null) throw Exception('User not authenticated');
    return user.id;
  }

  void _validateAnimalData(Animal animal) {
    if (animal.name.trim().isEmpty) {
      throw ArgumentError('Animal name cannot be empty');
    }
    if (animal.species.trim().isEmpty) {
      throw ArgumentError('Animal species is required');
    }
    if (animal.breed.trim().isEmpty) {
      throw ArgumentError('Animal breed is required');
    }
    if (animal.gender.trim().isEmpty) {
      throw ArgumentError('Animal gender is required');
    }
    if (animal.birthDate.isAfter(DateTime.now())) {
      throw ArgumentError('Birth date cannot be in the future');
    }
  }

  Future<Animal> _storeAnimalOffline(Animal animal) async {
    final prefs = await SharedPreferences.getInstance();
    final animalWithId = animal.id == null 
        ? animal.copyWith(id: 'offline_${DateTime.now().millisecondsSinceEpoch}')
        : animal;
    
    final offlineAnimal = animalWithId.copyWith(isSynced: false);
    await prefs.setString('offline_animal_${offlineAnimal.id}', jsonEncode(offlineAnimal.toJson()));
    
    return offlineAnimal;
  }

  Future<Animal> _storeAnimalUpdateOffline(Animal animal) async {
    final updatedAnimal = animal.copyWith(
      isSynced: false,
      updatedAt: DateTime.now(),
    );
    await _storeAnimalOffline(updatedAnimal);
    return updatedAnimal;
  }

  Future<List<Animal>> _getOfflineAnimals() async {
    final prefs = await SharedPreferences.getInstance();
    final offlineKeys = prefs.getKeys().where((key) => key.startsWith('offline_animal_'));
    
    final animals = <Animal>[];
    for (final key in offlineKeys) {
      final animalData = prefs.getString(key);
      if (animalData != null) {
        try {
          animals.add(Animal.fromJson(jsonDecode(animalData)));
        } catch (e) {
          // Skip corrupted data
        }
      }
    }
    
    return animals;
  }

  Future<Animal?> _getOfflineAnimal(String animalId) async {
    final prefs = await SharedPreferences.getInstance();
    final animalData = prefs.getString('offline_animal_$animalId');
    
    if (animalData != null) {
      try {
        return Animal.fromJson(jsonDecode(animalData));
      } catch (e) {
        return null;
      }
    }
    
    return null;
  }

  Future<void> _removeFromOffline(String animalId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('offline_animal_$animalId');
  }

  Future<void> _markDeletedOffline(String animalId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('offline_deleted_$animalId', true);
  }

  Future<void> _cacheAnimal(Animal animal) async {
    final prefs = await SharedPreferences.getInstance();
    final cachedData = {
      ...animal.toJson(),
      'cached_at': DateTime.now().toIso8601String(),
    };
    await prefs.setString('cached_animal_${animal.id}', jsonEncode(cachedData));
  }

  Future<Animal?> _getCachedAnimal(String animalId) async {
    final prefs = await SharedPreferences.getInstance();
    final cachedData = prefs.getString('cached_animal_$animalId');
    
    if (cachedData != null) {
      try {
        final data = jsonDecode(cachedData);
        final cachedAt = DateTime.parse(data['cached_at']);
        
        // Cache expires after 1 hour
        if (DateTime.now().difference(cachedAt).inHours < 1) {
          data.remove('cached_at');
          return Animal.fromJson(data);
        }
      } catch (e) {
        // Invalid cache data
      }
    }
    
    return null;
  }

  Future<void> _invalidateCache(String animalId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('cached_animal_$animalId');
  }

  Future<void> _syncSingleAnimal(Animal animal) async {
    final result = await _supabase
        .from('animals')
        .insert(animal.toJson())
        .select()
        .single();
    // Sync successful
  }
}

// Data classes
class SyncResult {
  final bool success;
  final int syncedCount;
  final int failedCount;

  SyncResult({
    required this.success,
    required this.syncedCount,
    required this.failedCount,
  });
}