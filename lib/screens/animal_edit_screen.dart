import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/animal.dart';
import '../services/animal_service.dart';
import '../services/auth_service.dart';
import '../utils/input_sanitizer.dart';

class AnimalEditScreen extends StatefulWidget {
  final Animal animal;
  
  const AnimalEditScreen({
    super.key,
    required this.animal,
  });

  @override
  State<AnimalEditScreen> createState() => _AnimalEditScreenState();
}

class _AnimalEditScreenState extends State<AnimalEditScreen> {
  final _formKey = GlobalKey<FormState>();
  final _animalService = AnimalService();
  final _authService = AuthService();
  
  // Form controllers
  late final TextEditingController _nameController;
  late final TextEditingController _tagController;
  late final TextEditingController _breedController;
  late final TextEditingController _purchaseWeightController;
  late final TextEditingController _currentWeightController;
  late final TextEditingController _purchasePriceController;
  late final TextEditingController _descriptionController;
  
  // Form state
  late AnimalSpecies _selectedSpecies;
  AnimalGender? _selectedGender;
  DateTime? _birthDate;
  DateTime? _purchaseDate;
  bool _isLoading = false;
  bool _isCheckingTag = false;
  String? _tagError;
  bool _hasChanges = false;
  
  // Debouncing and cancellation for tag validation
  Debouncer? _tagDebouncer;
  CancellationToken? _tagValidationToken;
  
  // Original values for change tracking
  late final String _originalTag;
  late final Animal _originalAnimal;
  
  // Simplified gender options - only Male and Female
  List<AnimalGender> get _genderOptions {
    return [
      AnimalGender.male,
      AnimalGender.female,
    ];
  }
  
  @override
  void initState() {
    super.initState();
    _originalAnimal = widget.animal;
    _originalTag = widget.animal.tag ?? '';
    
    // Initialize debouncer for tag validation
    _tagDebouncer = Debouncer(milliseconds: 500);
    
    // Initialize controllers with existing animal data
    _nameController = TextEditingController(text: widget.animal.name);
    _tagController = TextEditingController(text: widget.animal.tag ?? '');
    _breedController = TextEditingController(text: widget.animal.breed ?? '');
    _purchaseWeightController = TextEditingController(
      text: widget.animal.purchaseWeight?.toString() ?? '',
    );
    _currentWeightController = TextEditingController(
      text: widget.animal.currentWeight?.toString() ?? '',
    );
    _purchasePriceController = TextEditingController(
      text: widget.animal.purchasePrice?.toString() ?? '',
    );
    _descriptionController = TextEditingController(text: widget.animal.description ?? '');
    
    _selectedSpecies = widget.animal.species;
    _selectedGender = widget.animal.gender;
    _birthDate = widget.animal.birthDate;
    _purchaseDate = widget.animal.purchaseDate;
    
    // Add listeners to track changes
    _nameController.addListener(_checkForChanges);
    _tagController.addListener(_checkForChanges);
    _breedController.addListener(_checkForChanges);
    _purchaseWeightController.addListener(_checkForChanges);
    _currentWeightController.addListener(_checkForChanges);
    _purchasePriceController.addListener(_checkForChanges);
    _descriptionController.addListener(_checkForChanges);
  }
  
  @override
  void dispose() {
    _nameController.dispose();
    _tagController.dispose();
    _breedController.dispose();
    _purchaseWeightController.dispose();
    _currentWeightController.dispose();
    _purchasePriceController.dispose();
    _descriptionController.dispose();
    
    // Clean up debouncer and cancellation token
    _tagDebouncer?.dispose();
    _tagValidationToken?.cancel();
    
    super.dispose();
  }
  
  void _checkForChanges() {
    final hasChanges = _nameController.text != _originalAnimal.name ||
        _tagController.text != (_originalAnimal.tag ?? '') ||
        _breedController.text != (_originalAnimal.breed ?? '') ||
        _purchaseWeightController.text != (_originalAnimal.purchaseWeight?.toString() ?? '') ||
        _currentWeightController.text != (_originalAnimal.currentWeight?.toString() ?? '') ||
        _purchasePriceController.text != (_originalAnimal.purchasePrice?.toString() ?? '') ||
        _descriptionController.text != (_originalAnimal.description ?? '') ||
        _selectedSpecies != _originalAnimal.species ||
        _selectedGender != _originalAnimal.gender ||
        _birthDate != _originalAnimal.birthDate ||
        _purchaseDate != _originalAnimal.purchaseDate;
    
    if (hasChanges != _hasChanges) {
      setState(() {
        _hasChanges = hasChanges;
      });
    }
  }
  
  // Validate tag uniqueness (excluding current animal)
  Future<void> _validateTag(String? value) async {
    // Cancel any previous validation
    _tagValidationToken?.cancel();
    _tagValidationToken = CancellationToken();
    
    // Sanitize the input
    final sanitizedTag = InputSanitizer.sanitizeTagNumber(value);
    
    if (sanitizedTag == null || sanitizedTag.isEmpty || sanitizedTag == _originalTag) {
      setState(() => _tagError = null);
      return;
    }
    
    setState(() {
      _isCheckingTag = true;
      _tagError = null;
    });
    
    try {
      // Check if cancelled before making the request
      _tagValidationToken!.throwIfCancelled();
      
      final isAvailable = await _animalService.isTagAvailable(sanitizedTag, excludeAnimalId: widget.animal.id);
      
      // Check if cancelled after the request
      _tagValidationToken!.throwIfCancelled();
      
      if (mounted) {
        setState(() {
          _tagError = isAvailable ? null : 'This tag is already in use';
          _isCheckingTag = false;
        });
      }
    } catch (e) {
      // Only show error if not cancelled
      if (mounted && !_tagValidationToken!.isCancelled) {
        setState(() {
          _tagError = InputSanitizer.createUserFriendlyError(e.toString());
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
    
    // Sanitize the input
    final sanitized = InputSanitizer.sanitizeAnimalName(value);
    
    if (sanitized == null || sanitized.isEmpty) {
      return 'Name contains invalid characters';
    }
    
    if (sanitized.length < 2) {
      return 'Name must be at least 2 characters';
    }
    
    if (sanitized.length > 50) {
      return 'Name must be less than 50 characters';
    }
    
    return null;
  }
  
  String? _validateTagField(String? value) {
    if (value != null && value.isNotEmpty) {
      // Sanitize the input
      final sanitized = InputSanitizer.sanitizeTagNumber(value);
      
      if (sanitized == null) {
        return 'Tag contains invalid characters';
      }
      
      if (sanitized.length > 20) {
        return 'Tag must be less than 20 characters';
      }
    }
    return _tagError;
  }
  
  String? _validateWeight(String? value) {
    if (value != null && value.isNotEmpty) {
      final weight = InputSanitizer.sanitizeNumeric(value, min: 0.1, max: 5000);
      
      if (weight == null) {
        return 'Please enter a valid weight';
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
      final price = InputSanitizer.sanitizeNumeric(value, min: 0, max: 100000);
      
      if (price == null) {
        return 'Please enter a valid price';
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
      _checkForChanges();
    }
  }
  
  Future<bool> _showDiscardChangesDialog() async {
    if (!_hasChanges) return true;
    
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Discard Changes?'),
        content: const Text(
          'You have unsaved changes. Are you sure you want to discard them?'
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Keep Editing'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Discard'),
          ),
        ],
      ),
    );
    
    return result ?? false;
  }
  
  Future<void> _updateAnimal() async {
    // Validate form
    if (!_formKey.currentState!.validate()) {
      return;
    }
    
    // Check for changes
    if (!_hasChanges) {
      Navigator.of(context).pop();
      return;
    }
    
    // Check authentication
    if (!_authService.isAuthenticated) {
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
      // Sanitize all inputs before saving
      final sanitizedName = InputSanitizer.sanitizeAnimalName(_nameController.text);
      if (sanitizedName == null || sanitizedName.isEmpty) {
        throw Exception('Invalid animal name');
      }
      
      // Create updated animal object with sanitized data
      final updatedAnimal = widget.animal.copyWith(
        name: sanitizedName,
        tag: InputSanitizer.sanitizeTagNumber(_tagController.text),
        species: _selectedSpecies,
        breed: InputSanitizer.sanitizeBreed(_breedController.text),
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
        description: InputSanitizer.sanitizeDescription(_descriptionController.text),
      );
      
      // Save to database
      final savedAnimal = await _animalService.updateAnimal(updatedAnimal);
      
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
      if (mounted) {
        // Use user-friendly error message
        final friendlyError = InputSanitizer.createUserFriendlyError(e.toString());
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(friendlyError),
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
    
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (!didPop) {
          final shouldPop = await _showDiscardChangesDialog();
          if (shouldPop && context.mounted) {
            Navigator.of(context).pop();
          }
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text('Edit ${widget.animal.name}'),
          backgroundColor: theme.colorScheme.primary,
          foregroundColor: Colors.white,
          actions: [
            if (_hasChanges)
              Container(
                margin: const EdgeInsets.only(right: 8),
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.orange,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Text(
                      'Modified',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ),
          ],
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
                        decoration: InputDecoration(
                          labelText: 'Animal Name *',
                          hintText: 'Enter animal name',
                          prefixIcon: const Icon(Icons.pets),
                          suffixIcon: _nameController.text != _originalAnimal.name
                              ? const Icon(Icons.edit, color: Colors.orange, size: 16)
                              : null,
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
                                  : _tagController.text.isNotEmpty && _tagController.text != _originalTag
                                      ? const Icon(Icons.check, color: Colors.green)
                                      : _tagController.text != (_originalAnimal.tag ?? '')
                                          ? const Icon(Icons.edit, color: Colors.orange, size: 16)
                                          : null,
                        ),
                        textCapitalization: TextCapitalization.characters,
                        onChanged: (value) {
                          // Use proper debouncing with cancellation
                          _tagDebouncer?.run(() {
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
                        decoration: InputDecoration(
                          labelText: 'Species *',
                          prefixIcon: const Icon(Icons.category),
                          suffixIcon: _selectedSpecies != _originalAnimal.species
                              ? const Icon(Icons.edit, color: Colors.orange, size: 16)
                              : null,
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
                          _checkForChanges();
                        },
                      ),
                      const SizedBox(height: 16),
                      
                      // Breed field
                      TextFormField(
                        controller: _breedController,
                        decoration: InputDecoration(
                          labelText: 'Breed',
                          hintText: 'Enter breed (optional)',
                          prefixIcon: const Icon(Icons.pets),
                          suffixIcon: _breedController.text != (_originalAnimal.breed ?? '')
                              ? const Icon(Icons.edit, color: Colors.orange, size: 16)
                              : null,
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
                        decoration: InputDecoration(
                          labelText: 'Gender',
                          prefixIcon: const Icon(Icons.wc),
                          suffixIcon: _selectedGender != _originalAnimal.gender
                              ? const Icon(Icons.edit, color: Colors.orange, size: 16)
                              : null,
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
                          _checkForChanges();
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
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (_birthDate != _originalAnimal.birthDate)
                              const Icon(Icons.edit, color: Colors.orange, size: 16),
                            const SizedBox(width: 8),
                            IconButton(
                              icon: Icon(_birthDate == null ? Icons.calendar_today : Icons.clear),
                              onPressed: _birthDate == null
                                  ? () => _selectDate(context, true)
                                  : () {
                                      setState(() => _birthDate = null);
                                      _checkForChanges();
                                    },
                            ),
                          ],
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
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (_purchaseDate != _originalAnimal.purchaseDate)
                              const Icon(Icons.edit, color: Colors.orange, size: 16),
                            const SizedBox(width: 8),
                            IconButton(
                              icon: Icon(_purchaseDate == null ? Icons.calendar_today : Icons.clear),
                              onPressed: _purchaseDate == null
                                  ? () => _selectDate(context, false)
                                  : () {
                                      setState(() => _purchaseDate = null);
                                      _checkForChanges();
                                    },
                            ),
                          ],
                        ),
                        onTap: () => _selectDate(context, false),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              
              // Weight Information Card
              Card(
                elevation: 2,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Weight Information',
                        style: theme.textTheme.titleLarge?.copyWith(
                          color: theme.colorScheme.primary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),
                      
                      // Purchase weight
                      TextFormField(
                        controller: _purchaseWeightController,
                        decoration: InputDecoration(
                          labelText: 'Purchase Weight (lbs)',
                          hintText: 'Enter weight in pounds',
                          prefixIcon: const Icon(Icons.scale),
                          suffixIcon: _purchaseWeightController.text != (_originalAnimal.purchaseWeight?.toString() ?? '')
                              ? const Icon(Icons.edit, color: Colors.orange, size: 16)
                              : null,
                        ),
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        validator: _validateWeight,
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
                        ],
                      ),
                      const SizedBox(height: 16),
                      
                      // Current weight
                      TextFormField(
                        controller: _currentWeightController,
                        decoration: InputDecoration(
                          labelText: 'Current Weight (lbs)',
                          hintText: 'Enter current weight in pounds',
                          prefixIcon: const Icon(Icons.scale),
                          suffixIcon: _currentWeightController.text != (_originalAnimal.currentWeight?.toString() ?? '')
                              ? const Icon(Icons.edit, color: Colors.orange, size: 16)
                              : null,
                        ),
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        validator: _validateWeight,
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
                        ],
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
                      
                      // Purchase price
                      TextFormField(
                        controller: _purchasePriceController,
                        decoration: InputDecoration(
                          labelText: 'Purchase Price (\$)',
                          hintText: 'Enter price in dollars',
                          prefixIcon: const Icon(Icons.attach_money),
                          suffixIcon: _purchasePriceController.text != (_originalAnimal.purchasePrice?.toString() ?? '')
                              ? const Icon(Icons.edit, color: Colors.orange, size: 16)
                              : null,
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
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              'Additional Notes',
                              style: theme.textTheme.titleLarge?.copyWith(
                                color: theme.colorScheme.primary,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          if (_descriptionController.text != (_originalAnimal.description ?? ''))
                            const Icon(Icons.edit, color: Colors.orange, size: 16),
                        ],
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
                      onPressed: _isLoading ? null : () async {
                        final shouldPop = await _showDiscardChangesDialog();
                        if (shouldPop && context.mounted) {
                          Navigator.of(context).pop();
                        }
                      },
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _updateAnimal,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _hasChanges 
                            ? theme.colorScheme.primary 
                            : Colors.grey,
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
                          : Text(_hasChanges ? 'Save Changes' : 'No Changes'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 32),
            ],
          ),
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