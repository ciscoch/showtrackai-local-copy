// Enhanced _updateAnimal method with comprehensive debugging
// Replace the existing _updateAnimal method in AnimalEditScreen with this version

import '../utils/debug_animal_save.dart';

// Add this method to replace the existing _updateAnimal method in AnimalEditScreen
Future<void> _updateAnimal() async {
  // Step 1: Validate form
  if (!_formKey.currentState!.validate()) {
    print('❌ Form validation failed');
    return;
  }

  // Step 2: Check for changes
  if (!_hasChanges) {
    print('ℹ️ No changes detected, navigating back');
    Navigator.of(context).pop();
    return;
  }

  // Step 3: Check authentication
  if (!_authService.isAuthenticated) {
    print('❌ User not authenticated');
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('You must be logged in to update an animal'),
        backgroundColor: Colors.red,
      ),
    );
    return;
  }

  setState(() => _isLoading = true);

  try {
    print('🐄 Starting animal update process...');

    // Step 4: Collect form values for debugging
    final formValues = {
      'name': _nameController.text,
      'tag': _tagController.text,
      'breed': _breedController.text,
      'weight_purchase': _purchaseWeightController.text,
      'weight_current': _currentWeightController.text,
      'price': _purchasePriceController.text,
      'description': _descriptionController.text,
    };

    // Step 5: Sanitize inputs with detailed logging
    print('🧹 Sanitizing inputs...');
    
    final sanitizedName = InputSanitizer.sanitizeAnimalName(_nameController.text);
    print('📝 Name: "${_nameController.text}" -> "$sanitizedName"');
    
    if (sanitizedName == null || sanitizedName.isEmpty) {
      throw Exception('Invalid animal name after sanitization');
    }

    final sanitizedTag = InputSanitizer.sanitizeTagNumber(_tagController.text);
    print('🏷️ Tag: "${_tagController.text}" -> "$sanitizedTag"');

    final sanitizedBreed = InputSanitizer.sanitizeBreed(_breedController.text);
    print('🧬 Breed: "${_breedController.text}" -> "$sanitizedBreed"');

    final sanitizedDescription = InputSanitizer.sanitizeDescription(_descriptionController.text);
    print('📄 Description sanitized: ${sanitizedDescription != null}');

    // Step 6: Create updated animal object with sanitized data
    final updatedAnimal = widget.animal.copyWith(
      name: sanitizedName,
      tag: sanitizedTag,
      species: _selectedSpecies,
      breed: sanitizedBreed,
      gender: _selectedGender,
      birthDate: _birthDate,
      purchaseWeight: InputSanitizer.sanitizeNumeric(
        _purchaseWeightController.text,
        min: 0.1,
        max: 5000,
      ),
      currentWeight: InputSanitizer.sanitizeNumeric(
        _currentWeightController.text,
        min: 0.1,
        max: 5000,
      ),
      purchaseDate: _purchaseDate,
      purchasePrice: InputSanitizer.sanitizeNumeric(
        _purchasePriceController.text,
        min: 0,
        max: 100000,
      ),
      description: sanitizedDescription,
    );

    print('🔧 Updated animal object created');
    print('🆔 Animal ID: ${updatedAnimal.id}');
    print('👤 User ID: ${updatedAnimal.userId}');

    // Step 7: Run comprehensive debug check
    if (kDebugMode) {
      print('🔍 Running comprehensive debug check...');
      final debugResults = await AnimalSaveDebugger.debugSaveAttempt(
        originalAnimal: widget.animal,
        updatedAnimal: updatedAnimal,
        authService: _authService,
        animalService: _animalService,
        formValues: formValues,
      );

      final issues = debugResults['assessment'] as Map<String, String>?;
      if (issues != null && issues.isNotEmpty) {
        print('🚨 Pre-save issues detected:');
        for (final entry in issues.entries) {
          print('   ${entry.key}: ${entry.value}');
        }
        
        // Show critical issues to user
        if (issues.keys.any((key) => key.startsWith('AUTH_'))) {
          throw Exception('Authentication issue detected. Please try logging in again.');
        }
        if (issues.keys.any((key) => key.startsWith('PERM_'))) {
          throw Exception('Permission denied. You may not have access to this animal.');
        }
        if (issues.keys.any((key) => key.startsWith('NET_'))) {
          throw Exception('Network connection issue. Please check your internet connection.');
        }
      }
    }

    // Step 8: Attempt the save with timing
    final saveStartTime = DateTime.now();
    print('💾 Attempting to save animal...');
    
    final savedAnimal = await _animalService.updateAnimal(updatedAnimal);
    
    final saveEndTime = DateTime.now();
    final saveDuration = saveEndTime.difference(saveStartTime);
    print('✅ Animal saved successfully in ${saveDuration.inMilliseconds}ms');
    
    if (mounted) {
      // Show success message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${savedAnimal.name} has been updated!'),
          backgroundColor: Colors.green,
        ),
      );

      // Navigate back with updated animal
      Navigator.of(context).pop(savedAnimal);
    }
    
  } catch (e) {
    print('❌ Animal save failed: $e');
    
    // Enhanced error analysis
    String userFriendlyError = InputSanitizer.createUserFriendlyError(e.toString());
    
    // Additional specific error handling
    if (e.toString().toLowerCase().contains('jwt') || 
        e.toString().toLowerCase().contains('token')) {
      userFriendlyError = 'Your session has expired. Please refresh the page and try again.';
    } else if (e.toString().toLowerCase().contains('rls') ||
               e.toString().toLowerCase().contains('policy')) {
      userFriendlyError = 'Permission denied. Please make sure you are logged in correctly.';
    } else if (e.toString().toLowerCase().contains('unique') ||
               e.toString().toLowerCase().contains('duplicate')) {
      userFriendlyError = 'This tag number is already in use. Please choose a different tag.';
    } else if (e.toString().toLowerCase().contains('connection') ||
               e.toString().toLowerCase().contains('network')) {
      userFriendlyError = 'Network error. Please check your connection and try again.';
    } else if (e.toString().toLowerCase().contains('timeout')) {
      userFriendlyError = 'The save operation timed out. Please try again.';
    }
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(userFriendlyError),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 5),
        ),
      );
    }
    
  } finally {
    if (mounted) {
      setState(() => _isLoading = false);
    }
  }
}