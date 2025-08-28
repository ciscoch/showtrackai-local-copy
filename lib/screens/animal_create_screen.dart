import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/animal.dart';
import '../services/animal_service.dart';
import '../services/auth_service.dart';

class AnimalCreateScreen extends StatefulWidget {
  const AnimalCreateScreen({Key? key}) : super(key: key);

  @override
  State<AnimalCreateScreen> createState() => _AnimalCreateScreenState();
}

class _AnimalCreateScreenState extends State<AnimalCreateScreen> {
  final _formKey = GlobalKey<FormState>();
  final _animalService = AnimalService();
  final _authService = AuthService();
  
  // Form controllers
  final _nameController = TextEditingController();
  final _tagController = TextEditingController();
  final _breedController = TextEditingController();
  final _purchaseWeightController = TextEditingController();
  final _purchasePriceController = TextEditingController();
  final _descriptionController = TextEditingController();
  
  // Form state
  AnimalSpecies _selectedSpecies = AnimalSpecies.cattle;
  AnimalGender? _selectedGender;
  DateTime? _birthDate;
  DateTime? _purchaseDate;
  bool _isLoading = false;
  bool _isCheckingTag = false;
  String? _tagError;
  
  // Simplified gender options - only Male and Female
  List<AnimalGender> get _genderOptions {
    return [
      AnimalGender.male,
      AnimalGender.female,
    ];
  }
  
  @override
  void dispose() {
    _nameController.dispose();
    _tagController.dispose();
    _breedController.dispose();
    _purchaseWeightController.dispose();
    _purchasePriceController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }
  
  // Validate tag uniqueness
  Future<void> _validateTag(String? value) async {
    if (value == null || value.isEmpty) {
      setState(() => _tagError = null);
      return;
    }
    
    setState(() {
      _isCheckingTag = true;
      _tagError = null;
    });
    
    try {
      final isAvailable = await _animalService.isTagAvailable(value);
      if (mounted) {
        setState(() {
          _tagError = isAvailable ? null : 'This tag is already in use';
          _isCheckingTag = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _tagError = 'Error checking tag availability';
          _isCheckingTag = false;
        });
      }
    }
  }
  
  // Input validators
  String? _validateName(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Name is required';
    }
    if (value.trim().length < 2) {
      return 'Name must be at least 2 characters';
    }
    if (value.trim().length > 50) {
      return 'Name must be less than 50 characters';
    }
    // Only allow letters, numbers, spaces, hyphens, and apostrophes
    if (!RegExp(r"^[a-zA-Z0-9\s\-']+$").hasMatch(value)) {
      return 'Name contains invalid characters';
    }
    return null;
  }
  
  String? _validateTagField(String? value) {
    if (value != null && value.isNotEmpty) {
      if (value.length > 20) {
        return 'Tag must be less than 20 characters';
      }
      // Only allow alphanumeric and hyphens
      if (!RegExp(r'^[a-zA-Z0-9\-]+$').hasMatch(value)) {
        return 'Tag can only contain letters, numbers, and hyphens';
      }
    }
    return _tagError;
  }
  
  String? _validateWeight(String? value) {
    if (value != null && value.isNotEmpty) {
      final weight = double.tryParse(value);
      if (weight == null) {
        return 'Please enter a valid number';
      }
      if (weight <= 0) {
        return 'Weight must be greater than 0';
      }
      if (weight > 5000) {
        return 'Weight seems too high. Please verify.';
      }
    }
    return null;
  }
  
  String? _validatePrice(String? value) {
    if (value != null && value.isNotEmpty) {
      final price = double.tryParse(value);
      if (price == null) {
        return 'Please enter a valid number';
      }
      if (price < 0) {
        return 'Price cannot be negative';
      }
      if (price > 100000) {
        return 'Price seems too high. Please verify.';
      }
    }
    return null;
  }
  
  Future<void> _selectDate(BuildContext context, bool isBirthDate) async {
    final initialDate = isBirthDate ? _birthDate : _purchaseDate;
    final firstDate = DateTime(2000);
    final lastDate = DateTime.now();
    
    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate ?? DateTime.now(),
      firstDate: firstDate,
      lastDate: lastDate,
      helpText: isBirthDate ? 'Select Birth Date' : 'Select Purchase Date',
    );
    
    if (picked != null) {
      setState(() {
        if (isBirthDate) {
          _birthDate = picked;
        } else {
          _purchaseDate = picked;
        }
      });
    }
  }
  
  void _showSuccessDialog(Animal savedAnimal) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Row(
            children: [
              Icon(
                Icons.check_circle,
                color: Colors.green,
                size: 28,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Animal Created!',
                  style: TextStyle(
                    color: Colors.green,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${savedAnimal.name} has been successfully added to your livestock.',
                style: const TextStyle(fontSize: 16),
              ),
              const SizedBox(height: 16),
              const Text(
                'Would you like to create your first journal entry for this animal?',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey,
                ),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: Colors.blue.withOpacity(0.3),
                    width: 1,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.lightbulb_outline,
                      color: Colors.blue,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Journal entries help track your animal\'s progress and meet FFA requirements.',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.blue.shade700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(); // Close dialog
                Navigator.of(context).pop(savedAnimal); // Return to previous screen
              },
              child: const Text('Maybe Later'),
            ),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.of(context).pop(); // Close dialog
                _navigateToJournalEntry(savedAnimal);
              },
              icon: const Icon(Icons.book),
              label: const Text('Create Journal Entry'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.primary,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _navigateToJournalEntry(Animal savedAnimal) async {
    try {
      // Navigate to journal entry form with pre-populated animal data
      final result = await Navigator.of(context).pushNamed(
        '/journal/new',
        arguments: {
          'animalId': savedAnimal.id,
          'animalName': savedAnimal.name,
          'fromAnimalCreation': true,
          'suggestedTitle': 'Welcome ${savedAnimal.name} - Day 1',
          'suggestedDescription': 'Today I added ${savedAnimal.name} to my livestock project. '
              '${savedAnimal.breed != null ? 'This ${savedAnimal.breed} ' : 'This '}${savedAnimal.speciesDisplay.toLowerCase()} '
              '${savedAnimal.gender != null ? '(${savedAnimal.genderDisplay.toLowerCase()}) ' : ''}'
              'will be part of my agricultural education journey.',
        },
      );
      
      // Navigate back to previous screen after journal entry is created (or cancelled)
      if (mounted) {
        Navigator.of(context).pop(savedAnimal);
      }
    } catch (e) {
      // Handle navigation error gracefully
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not open journal entry: ${e.toString()}'),
            backgroundColor: Colors.orange,
          ),
        );
        Navigator.of(context).pop(savedAnimal);
      }
    }
  }

  Future<void> _saveAnimal() async {
    // Validate form
    if (!_formKey.currentState!.validate()) {
      return;
    }
    
    // Check authentication
    if (!_authService.isAuthenticated) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('You must be logged in to create an animal'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    
    setState(() => _isLoading = true);
    
    try {
      // Create animal object
      final animal = Animal(
        userId: _authService.currentUser!.id,
        name: _nameController.text.trim(),
        tag: _tagController.text.trim().isNotEmpty ? _tagController.text.trim() : null,
        species: _selectedSpecies,
        breed: _breedController.text.trim().isNotEmpty ? _breedController.text.trim() : null,
        gender: _selectedGender,
        birthDate: _birthDate,
        purchaseWeight: _purchaseWeightController.text.isNotEmpty
            ? double.tryParse(_purchaseWeightController.text)
            : null,
        currentWeight: _purchaseWeightController.text.isNotEmpty
            ? double.tryParse(_purchaseWeightController.text)
            : null,
        purchaseDate: _purchaseDate,
        purchasePrice: _purchasePriceController.text.isNotEmpty
            ? double.tryParse(_purchasePriceController.text)
            : null,
        description: _descriptionController.text.trim().isNotEmpty
            ? _descriptionController.text.trim()
            : null,
      );
      
      // Save to database
      final savedAnimal = await _animalService.createAnimal(animal);
      
      if (mounted) {
        // Show success message with option to create journal entry
        _showSuccessDialog(savedAnimal);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error creating animal: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }
  
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Add Animal'),
        backgroundColor: theme.colorScheme.primary,
        foregroundColor: Colors.white,
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16.0),
          children: [
            // Basic Information Card
            Card(
              elevation: 2,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Basic Information',
                      style: theme.textTheme.titleLarge?.copyWith(
                        color: theme.colorScheme.primary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    
                    // Name field
                    TextFormField(
                      controller: _nameController,
                      decoration: const InputDecoration(
                        labelText: 'Animal Name *',
                        hintText: 'Enter animal name',
                        prefixIcon: Icon(Icons.pets),
                      ),
                      textCapitalization: TextCapitalization.words,
                      validator: _validateName,
                      inputFormatters: [
                        LengthLimitingTextInputFormatter(50),
                      ],
                    ),
                    const SizedBox(height: 16),
                    
                    // Tag field with async validation
                    TextFormField(
                      controller: _tagController,
                      decoration: InputDecoration(
                        labelText: 'Tag Number',
                        hintText: 'Enter tag number (optional)',
                        prefixIcon: const Icon(Icons.tag),
                        suffixIcon: _isCheckingTag
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : _tagError != null
                                ? const Icon(Icons.error, color: Colors.red)
                                : _tagController.text.isNotEmpty
                                    ? const Icon(Icons.check, color: Colors.green)
                                    : null,
                      ),
                      textCapitalization: TextCapitalization.characters,
                      onChanged: (value) {
                        // Debounce tag validation
                        Future.delayed(const Duration(milliseconds: 500), () {
                          if (_tagController.text == value) {
                            _validateTag(value);
                          }
                        });
                      },
                      validator: _validateTagField,
                      inputFormatters: [
                        LengthLimitingTextInputFormatter(20),
                        FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z0-9\-]')),
                      ],
                    ),
                    const SizedBox(height: 16),
                    
                    // Species dropdown
                    DropdownButtonFormField<AnimalSpecies>(
                      value: _selectedSpecies,
                      decoration: const InputDecoration(
                        labelText: 'Species *',
                        prefixIcon: Icon(Icons.category),
                      ),
                      items: AnimalSpecies.values.map((species) {
                        return DropdownMenuItem(
                          value: species,
                          child: Text(_getSpeciesDisplay(species)),
                        );
                      }).toList(),
                      onChanged: (value) {
                        setState(() {
                          _selectedSpecies = value!;
                          // Reset gender if current selection is not in simplified options
                          if (!_genderOptions.contains(_selectedGender)) {
                            _selectedGender = null;
                          }
                        });
                      },
                    ),
                    const SizedBox(height: 16),
                    
                    // Breed field
                    TextFormField(
                      controller: _breedController,
                      decoration: const InputDecoration(
                        labelText: 'Breed',
                        hintText: 'Enter breed (optional)',
                        prefixIcon: Icon(Icons.pets),
                      ),
                      textCapitalization: TextCapitalization.words,
                      inputFormatters: [
                        LengthLimitingTextInputFormatter(50),
                      ],
                    ),
                    const SizedBox(height: 16),
                    
                    // Gender dropdown
                    DropdownButtonFormField<AnimalGender?>(
                      value: _selectedGender,
                      decoration: const InputDecoration(
                        labelText: 'Gender',
                        prefixIcon: Icon(Icons.wc),
                      ),
                      items: [
                        const DropdownMenuItem(
                          value: null,
                          child: Text('Not specified'),
                        ),
                        ..._genderOptions.map((gender) {
                          return DropdownMenuItem(
                            value: gender,
                            child: Text(_getGenderDisplay(gender)),
                          );
                        }),
                      ],
                      onChanged: (value) {
                        setState(() {
                          _selectedGender = value;
                        });
                      },
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            
            // Dates Card
            Card(
              elevation: 2,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Important Dates',
                      style: theme.textTheme.titleLarge?.copyWith(
                        color: theme.colorScheme.primary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    
                    // Birth date picker
                    ListTile(
                      leading: const Icon(Icons.cake),
                      title: Text(_birthDate == null
                          ? 'Select Birth Date'
                          : 'Birth Date: ${_formatDate(_birthDate!)}'),
                      subtitle: _birthDate == null
                          ? const Text('Optional')
                          : Text('Age: ${_calculateAge(_birthDate!)}'),
                      trailing: IconButton(
                        icon: Icon(_birthDate == null ? Icons.calendar_today : Icons.clear),
                        onPressed: _birthDate == null
                            ? () => _selectDate(context, true)
                            : () => setState(() => _birthDate = null),
                      ),
                      onTap: () => _selectDate(context, true),
                    ),
                    
                    // Purchase date picker
                    ListTile(
                      leading: const Icon(Icons.shopping_cart),
                      title: Text(_purchaseDate == null
                          ? 'Select Purchase Date'
                          : 'Purchase Date: ${_formatDate(_purchaseDate!)}'),
                      subtitle: const Text('Optional'),
                      trailing: IconButton(
                        icon: Icon(_purchaseDate == null ? Icons.calendar_today : Icons.clear),
                        onPressed: _purchaseDate == null
                            ? () => _selectDate(context, false)
                            : () => setState(() => _purchaseDate = null),
                      ),
                      onTap: () => _selectDate(context, false),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            
            // Purchase Information Card
            Card(
              elevation: 2,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Purchase Information',
                      style: theme.textTheme.titleLarge?.copyWith(
                        color: theme.colorScheme.primary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    
                    // Purchase weight
                    TextFormField(
                      controller: _purchaseWeightController,
                      decoration: const InputDecoration(
                        labelText: 'Purchase Weight (lbs)',
                        hintText: 'Enter weight in pounds',
                        prefixIcon: Icon(Icons.scale),
                      ),
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      validator: _validateWeight,
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
                      ],
                    ),
                    const SizedBox(height: 16),
                    
                    // Purchase price
                    TextFormField(
                      controller: _purchasePriceController,
                      decoration: const InputDecoration(
                        labelText: 'Purchase Price (\$)',
                        hintText: 'Enter price in dollars',
                        prefixIcon: Icon(Icons.attach_money),
                      ),
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      validator: _validatePrice,
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            
            // Notes Card
            Card(
              elevation: 2,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Additional Notes',
                      style: theme.textTheme.titleLarge?.copyWith(
                        color: theme.colorScheme.primary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _descriptionController,
                      decoration: const InputDecoration(
                        labelText: 'Description / Notes',
                        hintText: 'Enter any additional information',
                        alignLabelWithHint: true,
                      ),
                      maxLines: 3,
                      maxLength: 500,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            
            // Action buttons
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _isLoading ? null : () => Navigator.of(context).pop(),
                    child: const Text('Cancel'),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _saveAnimal,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: theme.colorScheme.primary,
                      foregroundColor: Colors.white,
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : const Text('Save Animal'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
  
  String _getSpeciesDisplay(AnimalSpecies species) {
    switch (species) {
      case AnimalSpecies.cattle:
        return 'Cattle';
      case AnimalSpecies.swine:
        return 'Swine';
      case AnimalSpecies.sheep:
        return 'Sheep';
      case AnimalSpecies.goat:
        return 'Goat';
      case AnimalSpecies.poultry:
        return 'Poultry';
      case AnimalSpecies.rabbit:
        return 'Rabbit';
      case AnimalSpecies.other:
        return 'Other';
    }
  }
  
  String _getGenderDisplay(AnimalGender gender) {
    switch (gender) {
      case AnimalGender.male:
        return 'Male';
      case AnimalGender.female:
        return 'Female';
      case AnimalGender.steer:
        return 'Steer';
      case AnimalGender.heifer:
        return 'Heifer';
      case AnimalGender.barrow:
        return 'Barrow';
      case AnimalGender.gilt:
        return 'Gilt';
      case AnimalGender.wether:
        return 'Wether';
      case AnimalGender.doe:
        return 'Doe';
      case AnimalGender.buck:
        return 'Buck';
      case AnimalGender.ewe:
        return 'Ewe';
      case AnimalGender.ram:
        return 'Ram';
    }
  }
  
  String _formatDate(DateTime date) {
    return '${date.month}/${date.day}/${date.year}';
  }
  
  String _calculateAge(DateTime birthDate) {
    final now = DateTime.now();
    final difference = now.difference(birthDate);
    final days = difference.inDays;
    
    if (days < 30) {
      return '$days days';
    } else if (days < 365) {
      return '${(days / 30).floor()} months';
    } else {
      final years = (days / 365).floor();
      final months = ((days % 365) / 30).floor();
      return months > 0 ? '$years yr $months mo' : '$years year${years > 1 ? 's' : ''}';
    }
  }
}