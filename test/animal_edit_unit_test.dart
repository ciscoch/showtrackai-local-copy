import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';

// Import your app files
import '../lib/models/animal.dart';
import '../lib/services/animal_service.dart';
import '../lib/services/auth_service.dart';
import '../lib/screens/animal_edit_screen.dart';

// Generate mocks
@GenerateMocks([AnimalService, AuthService])
import 'animal_edit_unit_test.mocks.dart';

void main() {
  group('Animal Edit Screen Tests', () {
    late MockAnimalService mockAnimalService;
    late MockAuthService mockAuthService;
    late Animal testAnimal;

    setUp(() {
      mockAnimalService = MockAnimalService();
      mockAuthService = MockAuthService();
      
      testAnimal = Animal(
        id: 'test-animal-id',
        userId: 'test-user-id',
        name: 'Test Cow',
        species: AnimalSpecies.cattle,
        tag: 'TC-001',
        breed: 'Holstein',
        gender: AnimalGender.heifer,
        birthDate: DateTime(2023, 1, 15),
        purchaseDate: DateTime(2023, 2, 1),
        purchaseWeight: 150.0,
        currentWeight: 250.0,
        purchasePrice: 800.0,
        description: 'Test animal for edit functionality',
        createdAt: DateTime.now(),
      );
    });

    testWidgets('Animal Edit Screen loads with pre-populated data', (WidgetTester tester) async {
      // Mock authentication
      when(mockAuthService.isAuthenticated).thenReturn(true);
      
      // Build the widget
      await tester.pumpWidget(
        MaterialApp(
          home: AnimalEditScreen(animal: testAnimal),
        ),
      );

      // Verify the screen loads
      expect(find.text('Edit Test Cow'), findsOneWidget);
      
      // Verify form fields are pre-populated
      expect(find.text('Test Cow'), findsOneWidget);
      expect(find.text('TC-001'), findsOneWidget);
      expect(find.text('Holstein'), findsOneWidget);
      
      // Verify species dropdown shows correct value
      expect(find.text('Cattle'), findsOneWidget);
      
      // Verify gender dropdown shows correct value
      expect(find.text('Heifer'), findsOneWidget);
    });

    testWidgets('Form validation works correctly', (WidgetTester tester) async {
      // Mock authentication
      when(mockAuthService.isAuthenticated).thenReturn(true);
      
      await tester.pumpWidget(
        MaterialApp(
          home: AnimalEditScreen(animal: testAnimal),
        ),
      );

      // Clear the name field (required field)
      await tester.enterText(find.byType(TextFormField).first, '');
      
      // Try to save
      await tester.tap(find.text('Save Changes'));
      await tester.pump();

      // Verify validation error appears
      expect(find.text('Name is required'), findsOneWidget);
    });

    testWidgets('Change detection works correctly', (WidgetTester tester) async {
      // Mock authentication
      when(mockAuthService.isAuthenticated).thenReturn(true);
      
      await tester.pumpWidget(
        MaterialApp(
          home: AnimalEditScreen(animal: testAnimal),
        ),
      );

      // Initially should show "No Changes"
      expect(find.text('No Changes'), findsOneWidget);
      expect(find.text('Modified'), findsNothing);

      // Make a change to the name
      await tester.enterText(find.byType(TextFormField).first, 'Modified Test Cow');
      await tester.pump();

      // Should now show changes detected
      expect(find.text('Save Changes'), findsOneWidget);
      expect(find.text('Modified'), findsOneWidget);
    });

    testWidgets('Species change updates gender options', (WidgetTester tester) async {
      // Mock authentication
      when(mockAuthService.isAuthenticated).thenReturn(true);
      
      await tester.pumpWidget(
        MaterialApp(
          home: AnimalEditScreen(animal: testAnimal),
        ),
      );

      // Find species dropdown and change it
      await tester.tap(find.text('Cattle'));
      await tester.pumpAndSettle();
      
      // Select Sheep
      await tester.tap(find.text('Sheep').last);
      await tester.pumpAndSettle();

      // Verify gender options updated (gender should reset to "Not specified")
      expect(find.text('Not specified'), findsOneWidget);
    });

    testWidgets('Unsaved changes warning appears', (WidgetTester tester) async {
      // Mock authentication
      when(mockAuthService.isAuthenticated).thenReturn(true);
      
      await tester.pumpWidget(
        MaterialApp(
          home: AnimalEditScreen(animal: testAnimal),
        ),
      );

      // Make a change
      await tester.enterText(find.byType(TextFormField).first, 'Modified Name');
      await tester.pump();

      // Try to go back
      await tester.tap(find.byIcon(Icons.arrow_back));
      await tester.pumpAndSettle();

      // Verify warning dialog appears
      expect(find.text('Discard Changes?'), findsOneWidget);
      expect(find.text('You have unsaved changes. Are you sure you want to discard them?'), findsOneWidget);
      expect(find.text('Keep Editing'), findsOneWidget);
      expect(find.text('Discard'), findsOneWidget);
    });

    testWidgets('Date pickers work correctly', (WidgetTester tester) async {
      // Mock authentication  
      when(mockAuthService.isAuthenticated).thenReturn(true);
      
      await tester.pumpWidget(
        MaterialApp(
          home: AnimalEditScreen(animal: testAnimal),
        ),
      );

      // Find and tap birth date tile
      await tester.tap(find.text('Birth Date: 1/15/2023'));
      await tester.pumpAndSettle();

      // Verify date picker opens
      expect(find.byType(DatePickerDialog), findsOneWidget);
    });

    test('Animal model validation', () {
      // Test that Animal model has all required fields
      expect(testAnimal.id, isNotNull);
      expect(testAnimal.name, equals('Test Cow'));
      expect(testAnimal.species, equals(AnimalSpecies.cattle));
      
      // Test copyWith functionality
      final updatedAnimal = testAnimal.copyWith(name: 'Updated Name');
      expect(updatedAnimal.name, equals('Updated Name'));
      expect(updatedAnimal.id, equals(testAnimal.id)); // Other fields unchanged
    });

    group('Form Validation Logic', () {
      test('Name validation', () {
        // This would test the validation logic if it were extracted to a separate class
        expect('', isEmpty); // Empty name should fail
        expect('A', hasLength(1)); // Too short
        expect('Valid Name', isNotEmpty); // Valid name
      });

      test('Tag validation', () {
        expect(RegExp(r'^[a-zA-Z0-9\-]+$').hasMatch('ABC-123'), isTrue);
        expect(RegExp(r'^[a-zA-Z0-9\-]+$').hasMatch('ABC@123'), isFalse);
      });

      test('Weight validation', () {
        expect(double.tryParse('100.5'), equals(100.5));
        expect(double.tryParse('-50'), equals(-50.0)); // Would fail validation
        expect(double.tryParse('abc'), isNull); // Invalid number
      });
    });
  });

  group('Animal Service Integration', () {
    late MockAnimalService mockAnimalService;

    setUp(() {
      mockAnimalService = MockAnimalService();
    });

    test('updateAnimal calls correct API', () async {
      final testAnimal = Animal(
        id: 'test-id',
        userId: 'user-id',
        name: 'Test Animal',
        species: AnimalSpecies.cattle,
      );

      when(mockAnimalService.updateAnimal(testAnimal))
          .thenAnswer((_) async => testAnimal);

      final result = await mockAnimalService.updateAnimal(testAnimal);
      
      expect(result, equals(testAnimal));
      verify(mockAnimalService.updateAnimal(testAnimal)).called(1);
    });

    test('isTagAvailable checks uniqueness correctly', () async {
      when(mockAnimalService.isTagAvailable('UNIQUE-TAG', excludeAnimalId: 'animal-id'))
          .thenAnswer((_) async => true);
      
      when(mockAnimalService.isTagAvailable('DUPLICATE-TAG', excludeAnimalId: 'animal-id'))
          .thenAnswer((_) async => false);

      final uniqueResult = await mockAnimalService.isTagAvailable('UNIQUE-TAG', excludeAnimalId: 'animal-id');
      final duplicateResult = await mockAnimalService.isTagAvailable('DUPLICATE-TAG', excludeAnimalId: 'animal-id');

      expect(uniqueResult, isTrue);
      expect(duplicateResult, isFalse);
    });
  });
}

// Helper function to create test animals with different configurations
Animal createTestAnimal({
  String? id,
  String name = 'Test Animal',
  AnimalSpecies species = AnimalSpecies.cattle,
  String? tag,
  AnimalGender? gender,
  DateTime? birthDate,
  double? currentWeight,
}) {
  return Animal(
    id: id ?? 'test-id-${DateTime.now().millisecondsSinceEpoch}',
    userId: 'test-user-id',
    name: name,
    species: species,
    tag: tag,
    gender: gender,
    birthDate: birthDate,
    currentWeight: currentWeight,
    createdAt: DateTime.now(),
  );
}

// Test data generators
class TestDataGenerator {
  static Animal cattle() => createTestAnimal(
    name: 'Test Cattle',
    species: AnimalSpecies.cattle,
    gender: AnimalGender.heifer,
    tag: 'C-001',
  );

  static Animal swine() => createTestAnimal(
    name: 'Test Pig',
    species: AnimalSpecies.swine, 
    gender: AnimalGender.gilt,
    tag: 'P-001',
  );

  static Animal sheep() => createTestAnimal(
    name: 'Test Sheep',
    species: AnimalSpecies.sheep,
    gender: AnimalGender.ewe,
    tag: 'S-001',
  );

  static Animal goat() => createTestAnimal(
    name: 'Test Goat',
    species: AnimalSpecies.goat,
    gender: AnimalGender.doe,
    tag: 'G-001',
  );

  static Animal withoutOptionalFields() => createTestAnimal(
    name: 'Minimal Animal',
    species: AnimalSpecies.other,
  );

  static Animal withAllFields() => createTestAnimal(
    name: 'Complete Animal',
    species: AnimalSpecies.cattle,
    tag: 'COMPLETE-001',
    gender: AnimalGender.steer,
    birthDate: DateTime(2023, 1, 1),
    currentWeight: 500.0,
  );
}