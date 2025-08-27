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
  print('📝 Testing with animal: ${testAnimal.name} (ID: ${testAnimal.id})');
  
  // Step 2: Make a small change
  final updatedAnimal = testAnimal.copyWith(
    name: '${testAnimal.name} (Test Update)',
    description: 'Updated at ${DateTime.now()}',
  );
  
  // Step 3: Attempt update
  try {
    final result = await animalService.updateAnimal(updatedAnimal);
    print('✅ Update successful! New name: ${result.name}');
    
    // Step 4: Revert the change
    final revertedAnimal = result.copyWith(
      name: testAnimal.name,
      description: testAnimal.description,
    );
    
    await animalService.updateAnimal(revertedAnimal);
    print('✅ Reverted changes successfully');
    
  } catch (e) {
    print('❌ Update failed: $e');
    
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
