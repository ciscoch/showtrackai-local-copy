import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';

// Import services and models (assuming they exist)
import '../../lib/services/animal_service.dart';
import '../../lib/services/auth_service.dart';

// Generate mocks
@GenerateMocks([AnimalService, AuthService])
import 'animal_create_form_test.mocks.dart';

/// Animal Create Form Widget Test
/// 
/// This widget would handle animal creation/registration including:
/// - Species and breed selection
/// - Basic information (name, age, weight, etc.)
/// - Identification details (ear tags, registration numbers)
/// - Photos and documentation
/// - FFA/SAE categorization
/// - Show eligibility settings
/// 
/// Since the actual widget doesn't exist yet, this test defines the expected
/// behavior and interface for the animal creation form component.
class MockAnimalCreateForm extends StatefulWidget {
  final VoidCallback? onAnimalCreated;
  final bool isEditMode;
  final Map<String, dynamic>? initialData;

  const MockAnimalCreateForm({
    Key? key,
    this.onAnimalCreated,
    this.isEditMode = false,
    this.initialData,
  }) : super(key: key);

  @override
  State<MockAnimalCreateForm> createState() => _MockAnimalCreateFormState();
}

class _MockAnimalCreateFormState extends State<MockAnimalCreateForm> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _identificationController = TextEditingController();
  final _weightController = TextEditingController();
  final _notesController = TextEditingController();

  String? _selectedSpecies;
  String? _selectedBreed;
  String? _selectedGender;
  DateTime? _birthDate;
  DateTime? _acquisitionDate;
  List<String> _selectedPhotos = [];
  bool _isShowEligible = false;
  bool _countsForDegree = false;
  String? _saeType;
  double? _purchasePrice;
  bool _isLoading = false;
  String? _error;

  // Mock data for dropdowns
  final List<String> _species = [
    'Cattle',
    'Swine',
    'Sheep',
    'Goat',
    'Poultry',
    'Horse',
    'Rabbit',
    'Other'
  ];

  final Map<String, List<String>> _breedsBySpecies = {
    'Cattle': [
      'Angus',
      'Holstein',
      'Hereford',
      'Charolais',
      'Limousin',
      'Simmental',
      'Other'
    ],
    'Swine': [
      'Yorkshire',
      'Duroc',
      'Hampshire',
      'Berkshire',
      'Chester White',
      'Landrace',
      'Other'
    ],
    'Sheep': [
      'Suffolk',
      'Hampshire',
      'Dorper',
      'Columbia',
      'Corriedale',
      'Romney',
      'Other'
    ],
    'Goat': [
      'Boer',
      'Nubian',
      'Alpine',
      'Saanen',
      'LaMancha',
      'Angora',
      'Other'
    ],
    'Poultry': [
      'Rhode Island Red',
      'Leghorn',
      'Plymouth Rock',
      'Brahma',
      'Wyandotte',
      'Orpington',
      'Other'
    ],
  };

  final List<String> _genders = ['Male', 'Female', 'Castrated Male'];
  final List<String> _saeTypes = [
    'Entrepreneurship',
    'Placement',
    'Research',
    'Exploratory',
    'Service Learning',
    'School-Based Enterprise'
  ];

  @override
  void initState() {
    super.initState();
    _initializeForm();
  }

  void _initializeForm() {
    if (widget.initialData != null) {
      final data = widget.initialData!;
      _nameController.text = data['name'] ?? '';
      _identificationController.text = data['identification'] ?? '';
      _weightController.text = data['weight']?.toString() ?? '';
      _notesController.text = data['notes'] ?? '';
      _selectedSpecies = data['species'];
      _selectedBreed = data['breed'];
      _selectedGender = data['gender'];
      _birthDate = data['birthDate'];
      _acquisitionDate = data['acquisitionDate'];
      _selectedPhotos = List<String>.from(data['photos'] ?? []);
      _isShowEligible = data['showEligible'] ?? false;
      _countsForDegree = data['countsForDegree'] ?? false;
      _saeType = data['saeType'];
      _purchasePrice = data['purchasePrice']?.toDouble();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.isEditMode ? 'Edit Animal' : 'Add New Animal'),
        actions: [
          IconButton(
            icon: const Icon(Icons.help_outline),
            onPressed: () => _showHelpDialog(),
            tooltip: 'Help',
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (_error != null) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red.shade100,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.red.shade300),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.error, color: Colors.red),
                      const SizedBox(width: 8),
                      Expanded(child: Text(_error!)),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => setState(() => _error = null),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // Basic Information Section
              _buildSectionHeader('Basic Information'),
              _buildNameField(),
              const SizedBox(height: 16),
              _buildSpeciesSelector(),
              const SizedBox(height: 16),
              _buildBreedSelector(),
              const SizedBox(height: 16),
              _buildGenderSelector(),
              const SizedBox(height: 16),

              // Identification Section
              _buildSectionHeader('Identification'),
              _buildIdentificationField(),
              const SizedBox(height: 16),

              // Physical Information Section
              _buildSectionHeader('Physical Information'),
              _buildWeightField(),
              const SizedBox(height: 16),
              _buildDatePicker(
                'Birth Date',
                _birthDate,
                (date) => setState(() => _birthDate = date),
              ),
              const SizedBox(height: 16),
              _buildDatePicker(
                'Acquisition Date',
                _acquisitionDate,
                (date) => setState(() => _acquisitionDate = date),
              ),
              const SizedBox(height: 16),

              // FFA/SAE Information Section
              _buildSectionHeader('FFA/SAE Information'),
              _buildSAETypeSelector(),
              const SizedBox(height: 16),
              _buildPurchasePriceField(),
              const SizedBox(height: 16),
              _buildSwitchTile(
                'Counts for FFA Degree',
                _countsForDegree,
                (value) => setState(() => _countsForDegree = value),
              ),
              _buildSwitchTile(
                'Show Eligible',
                _isShowEligible,
                (value) => setState(() => _isShowEligible = value),
              ),
              const SizedBox(height: 16),

              // Photos Section
              _buildSectionHeader('Photos'),
              _buildPhotoSection(),
              const SizedBox(height: 16),

              // Notes Section
              _buildSectionHeader('Additional Notes'),
              _buildNotesField(),
              const SizedBox(height: 32),

              // Action Buttons
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
                      onPressed: _isLoading ? null : _handleSubmit,
                      child: _isLoading
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Text(widget.isEditMode ? 'Update' : 'Create'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: Colors.green,
        ),
      ),
    );
  }

  Widget _buildNameField() {
    return TextFormField(
      controller: _nameController,
      decoration: const InputDecoration(
        labelText: 'Animal Name *',
        hintText: 'Enter animal name',
        border: OutlineInputBorder(),
      ),
      validator: (value) {
        if (value == null || value.trim().isEmpty) {
          return 'Animal name is required';
        }
        if (value.trim().length < 2) {
          return 'Name must be at least 2 characters';
        }
        return null;
      },
      textCapitalization: TextCapitalization.words,
    );
  }

  Widget _buildSpeciesSelector() {
    return DropdownButtonFormField<String>(
      value: _selectedSpecies,
      decoration: const InputDecoration(
        labelText: 'Species *',
        border: OutlineInputBorder(),
      ),
      items: _species.map((species) {
        return DropdownMenuItem(
          value: species,
          child: Text(species),
        );
      }).toList(),
      onChanged: (value) {
        setState(() {
          _selectedSpecies = value;
          _selectedBreed = null; // Reset breed when species changes
        });
      },
      validator: (value) {
        if (value == null || value.isEmpty) {
          return 'Please select a species';
        }
        return null;
      },
    );
  }

  Widget _buildBreedSelector() {
    final breeds = _selectedSpecies != null
        ? (_breedsBySpecies[_selectedSpecies!] ?? ['Other'])
        : <String>[];

    return DropdownButtonFormField<String>(
      value: _selectedBreed,
      decoration: const InputDecoration(
        labelText: 'Breed *',
        border: OutlineInputBorder(),
      ),
      items: breeds.map((breed) {
        return DropdownMenuItem(
          value: breed,
          child: Text(breed),
        );
      }).toList(),
      onChanged: breeds.isNotEmpty
          ? (value) => setState(() => _selectedBreed = value)
          : null,
      validator: (value) {
        if (value == null || value.isEmpty) {
          return 'Please select a breed';
        }
        return null;
      },
    );
  }

  Widget _buildGenderSelector() {
    return DropdownButtonFormField<String>(
      value: _selectedGender,
      decoration: const InputDecoration(
        labelText: 'Gender *',
        border: OutlineInputBorder(),
      ),
      items: _genders.map((gender) {
        return DropdownMenuItem(
          value: gender,
          child: Text(gender),
        );
      }).toList(),
      onChanged: (value) => setState(() => _selectedGender = value),
      validator: (value) {
        if (value == null || value.isEmpty) {
          return 'Please select a gender';
        }
        return null;
      },
    );
  }

  Widget _buildIdentificationField() {
    return TextFormField(
      controller: _identificationController,
      decoration: const InputDecoration(
        labelText: 'Identification (Ear Tag, Registration #)',
        hintText: 'Enter ear tag number or registration',
        border: OutlineInputBorder(),
      ),
      textCapitalization: TextCapitalization.characters,
    );
  }

  Widget _buildWeightField() {
    return TextFormField(
      controller: _weightController,
      decoration: const InputDecoration(
        labelText: 'Current Weight (lbs)',
        hintText: 'Enter current weight',
        border: OutlineInputBorder(),
        suffixText: 'lbs',
      ),
      keyboardType: TextInputType.number,
      validator: (value) {
        if (value != null && value.isNotEmpty) {
          final weight = double.tryParse(value);
          if (weight == null || weight <= 0) {
            return 'Enter a valid weight';
          }
          if (weight > 10000) {
            return 'Weight seems too high';
          }
        }
        return null;
      },
    );
  }

  Widget _buildDatePicker(String label, DateTime? selectedDate, Function(DateTime?) onChanged) {
    return InkWell(
      onTap: () async {
        final date = await showDatePicker(
          context: context,
          initialDate: selectedDate ?? DateTime.now(),
          firstDate: DateTime(1900),
          lastDate: DateTime.now(),
        );
        if (date != null) {
          onChanged(date);
        }
      },
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
          suffixIcon: const Icon(Icons.calendar_today),
        ),
        child: Text(
          selectedDate != null
              ? '${selectedDate.month}/${selectedDate.day}/${selectedDate.year}'
              : 'Select date',
          style: TextStyle(
            color: selectedDate != null ? null : Colors.grey.shade600,
          ),
        ),
      ),
    );
  }

  Widget _buildSAETypeSelector() {
    return DropdownButtonFormField<String>(
      value: _saeType,
      decoration: const InputDecoration(
        labelText: 'SAE Type',
        border: OutlineInputBorder(),
      ),
      items: _saeTypes.map((type) {
        return DropdownMenuItem(
          value: type,
          child: Text(type),
        );
      }).toList(),
      onChanged: (value) => setState(() => _saeType = value),
    );
  }

  Widget _buildPurchasePriceField() {
    return TextFormField(
      decoration: const InputDecoration(
        labelText: 'Purchase Price',
        hintText: 'Enter purchase price',
        border: OutlineInputBorder(),
        prefixText: '\$',
      ),
      keyboardType: TextInputType.number,
      onChanged: (value) {
        _purchasePrice = double.tryParse(value);
      },
      validator: (value) {
        if (value != null && value.isNotEmpty) {
          final price = double.tryParse(value);
          if (price == null || price < 0) {
            return 'Enter a valid price';
          }
        }
        return null;
      },
    );
  }

  Widget _buildSwitchTile(String title, bool value, Function(bool) onChanged) {
    return SwitchListTile(
      title: Text(title),
      value: value,
      onChanged: onChanged,
      contentPadding: EdgeInsets.zero,
    );
  }

  Widget _buildPhotoSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            ElevatedButton.icon(
              icon: const Icon(Icons.camera_alt),
              label: const Text('Take Photo'),
              onPressed: () => _addPhoto('camera'),
            ),
            const SizedBox(width: 8),
            OutlinedButton.icon(
              icon: const Icon(Icons.photo_library),
              label: const Text('From Gallery'),
              onPressed: () => _addPhoto('gallery'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (_selectedPhotos.isNotEmpty)
          SizedBox(
            height: 100,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: _selectedPhotos.length,
              itemBuilder: (context, index) {
                return Container(
                  margin: const EdgeInsets.only(right: 8),
                  child: Stack(
                    children: [
                      Container(
                        width: 100,
                        height: 100,
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.photo, size: 40),
                      ),
                      Positioned(
                        top: 4,
                        right: 4,
                        child: GestureDetector(
                          onTap: () => _removePhoto(index),
                          child: Container(
                            padding: const EdgeInsets.all(2),
                            decoration: const BoxDecoration(
                              color: Colors.red,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.close,
                              color: Colors.white,
                              size: 16,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
      ],
    );
  }

  Widget _buildNotesField() {
    return TextFormField(
      controller: _notesController,
      decoration: const InputDecoration(
        labelText: 'Additional Notes',
        hintText: 'Any additional information about this animal...',
        border: OutlineInputBorder(),
      ),
      maxLines: 3,
      textCapitalization: TextCapitalization.sentences,
    );
  }

  void _addPhoto(String source) {
    setState(() {
      _selectedPhotos.add('photo_${_selectedPhotos.length + 1}_$source.jpg');
    });
  }

  void _removePhoto(int index) {
    setState(() {
      _selectedPhotos.removeAt(index);
    });
  }

  void _showHelpDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Help'),
        content: const Text(
          'Fill out the animal information form:\n\n'
          '• Name, Species, and Breed are required\n'
          '• Use identification for ear tags or registration numbers\n'
          '• SAE Type helps categorize your project\n'
          '• Mark "Counts for FFA Degree" if this counts toward degree requirements\n'
          '• Add photos to help identify your animal',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Got it'),
          ),
        ],
      ),
    );
  }

  void _handleSubmit() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      // Simulate API call
      await Future.delayed(const Duration(seconds: 1));

      // In real implementation, this would create/update the animal
      final animalData = {
        'name': _nameController.text.trim(),
        'species': _selectedSpecies,
        'breed': _selectedBreed,
        'gender': _selectedGender,
        'identification': _identificationController.text.trim(),
        'weight': double.tryParse(_weightController.text),
        'birthDate': _birthDate,
        'acquisitionDate': _acquisitionDate,
        'saeType': _saeType,
        'purchasePrice': _purchasePrice,
        'countsForDegree': _countsForDegree,
        'showEligible': _isShowEligible,
        'photos': _selectedPhotos,
        'notes': _notesController.text.trim(),
      };

      if (widget.onAnimalCreated != null) {
        widget.onAnimalCreated!();
      }

      if (mounted) {
        Navigator.of(context).pop(animalData);
      }
    } catch (e) {
      setState(() {
        _error = 'Failed to ${widget.isEditMode ? 'update' : 'create'} animal: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _identificationController.dispose();
    _weightController.dispose();
    _notesController.dispose();
    super.dispose();
  }
}

void main() {
  group('Animal Create Form Widget Tests', () {
    late MockAnimalService mockAnimalService;
    late MockAuthService mockAuthService;

    setUp(() {
      mockAnimalService = MockAnimalService();
      mockAuthService = MockAuthService();
    });

    testWidgets('displays create form with all required fields', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: MockAnimalCreateForm(),
        ),
      );

      // Check app bar
      expect(find.text('Add New Animal'), findsOneWidget);
      expect(find.byIcon(Icons.help_outline), findsOneWidget);

      // Check required fields
      expect(find.text('Animal Name *'), findsOneWidget);
      expect(find.text('Species *'), findsOneWidget);
      expect(find.text('Breed *'), findsOneWidget);
      expect(find.text('Gender *'), findsOneWidget);

      // Check optional fields
      expect(find.text('Identification (Ear Tag, Registration #)'), findsOneWidget);
      expect(find.text('Current Weight (lbs)'), findsOneWidget);
      expect(find.text('Birth Date'), findsOneWidget);
      expect(find.text('Acquisition Date'), findsOneWidget);

      // Check action buttons
      expect(find.text('Cancel'), findsOneWidget);
      expect(find.text('Create'), findsOneWidget);
    });

    testWidgets('displays edit form when in edit mode', (WidgetTester tester) async {
      final initialData = {
        'name': 'Bessie',
        'species': 'Cattle',
        'breed': 'Holstein',
        'gender': 'Female',
        'weight': 150.0,
      };

      await tester.pumpWidget(
        MaterialApp(
          home: MockAnimalCreateForm(
            isEditMode: true,
            initialData: initialData,
          ),
        ),
      );

      expect(find.text('Edit Animal'), findsOneWidget);
      expect(find.text('Update'), findsOneWidget);

      // Check that initial data is populated
      expect(find.text('Bessie'), findsOneWidget);
    });

    testWidgets('validates required fields', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: MockAnimalCreateForm(),
        ),
      );

      // Try to submit without filling required fields
      await tester.tap(find.text('Create'));
      await tester.pumpAndSettle();

      expect(find.text('Animal name is required'), findsOneWidget);
      expect(find.text('Please select a species'), findsOneWidget);
    });

    testWidgets('species selection updates breed options', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: MockAnimalCreateForm(),
        ),
      );

      // Select species
      await tester.tap(find.text('Species *'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cattle').last);
      await tester.pumpAndSettle();

      // Check breed options are updated
      await tester.tap(find.text('Breed *'));
      await tester.pumpAndSettle();
      expect(find.text('Holstein'), findsOneWidget);
      expect(find.text('Angus'), findsOneWidget);
    });

    testWidgets('handles photo addition and removal', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: MockAnimalCreateForm(),
        ),
      );

      // Add photo from camera
      await tester.tap(find.text('Take Photo'));
      await tester.pumpAndSettle();

      // Check photo was added
      expect(find.byIcon(Icons.photo), findsOneWidget);

      // Add photo from gallery
      await tester.tap(find.text('From Gallery'));
      await tester.pumpAndSettle();

      // Check both photos are present
      expect(find.byIcon(Icons.photo), findsNWidgets(2));

      // Remove first photo
      await tester.tap(find.byIcon(Icons.close).first);
      await tester.pumpAndSettle();

      // Check only one photo remains
      expect(find.byIcon(Icons.photo), findsOneWidget);
    });

    testWidgets('date picker works correctly', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: MockAnimalCreateForm(),
        ),
      );

      // Tap birth date field
      await tester.tap(find.text('Birth Date'));
      await tester.pumpAndSettle();

      // Check date picker appears
      expect(find.byType(DatePickerDialog), findsOneWidget);

      // Select a date (tap OK to confirm)
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();

      // Check that "Select date" text is replaced
      expect(find.text('Select date'), findsOneWidget); // Only acquisition date now shows this
    });

    testWidgets('validates weight input', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: MockAnimalCreateForm(),
        ),
      );

      // Enter invalid weight
      await tester.enterText(find.byType(TextFormField).at(3), 'invalid');
      await tester.tap(find.text('Create'));
      await tester.pumpAndSettle();

      expect(find.text('Enter a valid weight'), findsOneWidget);

      // Clear and enter negative weight
      await tester.enterText(find.byType(TextFormField).at(3), '-50');
      await tester.tap(find.text('Create'));
      await tester.pumpAndSettle();

      expect(find.text('Enter a valid weight'), findsOneWidget);
    });

    testWidgets('validates purchase price input', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: MockAnimalCreateForm(),
        ),
      );

      // Scroll to find purchase price field
      await tester.dragUntilVisible(
        find.text('Purchase Price'),
        find.byType(SingleChildScrollView),
        const Offset(0, -100),
      );

      // Enter invalid price
      await tester.enterText(
        find.ancestor(
          of: find.text('Purchase Price'),
          matching: find.byType(TextFormField),
        ),
        'invalid',
      );
      
      await tester.tap(find.text('Create'));
      await tester.pumpAndSettle();

      expect(find.text('Enter a valid price'), findsOneWidget);
    });

    testWidgets('toggles switches correctly', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: MockAnimalCreateForm(),
        ),
      );

      // Scroll to find switches
      await tester.dragUntilVisible(
        find.text('Counts for FFA Degree'),
        find.byType(SingleChildScrollView),
        const Offset(0, -100),
      );

      // Initially both should be off
      final degreeSwitch = find.ancestor(
        of: find.text('Counts for FFA Degree'),
        matching: find.byType(SwitchListTile),
      );
      final showSwitch = find.ancestor(
        of: find.text('Show Eligible'),
        matching: find.byType(SwitchListTile),
      );

      expect(tester.widget<SwitchListTile>(degreeSwitch).value, isFalse);
      expect(tester.widget<SwitchListTile>(showSwitch).value, isFalse);

      // Toggle degree switch
      await tester.tap(degreeSwitch);
      await tester.pumpAndSettle();

      expect(tester.widget<SwitchListTile>(degreeSwitch).value, isTrue);
    });

    testWidgets('shows help dialog', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: MockAnimalCreateForm(),
        ),
      );

      await tester.tap(find.byIcon(Icons.help_outline));
      await tester.pumpAndSettle();

      expect(find.text('Help'), findsOneWidget);
      expect(find.text('Fill out the animal information form:'), findsOneWidget);
      expect(find.text('Got it'), findsOneWidget);

      await tester.tap(find.text('Got it'));
      await tester.pumpAndSettle();

      expect(find.text('Help'), findsNothing);
    });

    testWidgets('handles form submission successfully', (WidgetTester tester) async {
      bool callbackCalled = false;

      await tester.pumpWidget(
        MaterialApp(
          home: MockAnimalCreateForm(
            onAnimalCreated: () => callbackCalled = true,
          ),
        ),
      );

      // Fill required fields
      await tester.enterText(find.byType(TextFormField).first, 'Test Animal');
      
      await tester.tap(find.text('Species *'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cattle').last);
      await tester.pumpAndSettle();

      await tester.tap(find.text('Breed *'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Holstein').last);
      await tester.pumpAndSettle();

      await tester.tap(find.text('Gender *'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Female').last);
      await tester.pumpAndSettle();

      // Submit form
      await tester.tap(find.text('Create'));
      await tester.pump(); // Start loading
      
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      
      await tester.pumpAndSettle(); // Complete submission

      expect(callbackCalled, isTrue);
    });

    testWidgets('shows loading state during submission', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: MockAnimalCreateForm(),
        ),
      );

      // Fill required fields
      await tester.enterText(find.byType(TextFormField).first, 'Test Animal');
      
      await tester.tap(find.text('Species *'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cattle').last);
      await tester.pumpAndSettle();

      await tester.tap(find.text('Breed *'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Holstein').last);
      await tester.pumpAndSettle();

      await tester.tap(find.text('Gender *'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Female').last);
      await tester.pumpAndSettle();

      // Submit form
      await tester.tap(find.text('Create'));
      await tester.pump();

      // Check loading state
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      
      // Buttons should be disabled during loading
      final createButton = tester.widget<ElevatedButton>(
        find.ancestor(
          of: find.byType(CircularProgressIndicator),
          matching: find.byType(ElevatedButton),
        ),
      );
      expect(createButton.onPressed, isNull);
    });

    testWidgets('handles form submission error', (WidgetTester tester) async {
      // This would test error handling in a real implementation
      await tester.pumpWidget(
        const MaterialApp(
          home: MockAnimalCreateForm(),
        ),
      );

      // In a real test, you would mock the service to throw an error
      // and verify that the error message is displayed correctly
    });

    testWidgets('name field validates minimum length', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: MockAnimalCreateForm(),
        ),
      );

      // Enter name that's too short
      await tester.enterText(find.byType(TextFormField).first, 'A');
      await tester.tap(find.text('Create'));
      await tester.pumpAndSettle();

      expect(find.text('Name must be at least 2 characters'), findsOneWidget);
    });

    testWidgets('cancel button works correctly', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const MockAnimalCreateForm(),
                  ),
                ),
                child: const Text('Open Form'),
              ),
            ),
          ),
        ),
      );

      // Open the form
      await tester.tap(find.text('Open Form'));
      await tester.pumpAndSettle();

      // Tap cancel
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      // Should be back to the original screen
      expect(find.text('Open Form'), findsOneWidget);
      expect(find.text('Add New Animal'), findsNothing);
    });

    group('Accessibility Tests', () {
      testWidgets('form fields have proper labels', (WidgetTester tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: MockAnimalCreateForm(),
          ),
        );

        // Check that form fields have accessible labels
        expect(find.text('Animal Name *'), findsOneWidget);
        expect(find.text('Species *'), findsOneWidget);
        expect(find.text('Breed *'), findsOneWidget);
        expect(find.text('Gender *'), findsOneWidget);
      });

      testWidgets('buttons have proper tooltips', (WidgetTester tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: MockAnimalCreateForm(),
          ),
        );

        // Long press help button to show tooltip
        await tester.longPress(find.byIcon(Icons.help_outline));
        await tester.pump();
        expect(find.text('Help'), findsOneWidget);
      });
    });

    group('Form State Tests', () {
      testWidgets('maintains form state during rebuild', (WidgetTester tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: MockAnimalCreateForm(),
          ),
        );

        // Fill out form
        await tester.enterText(find.byType(TextFormField).first, 'Test Animal');
        
        await tester.tap(find.text('Species *'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Cattle').last);
        await tester.pumpAndSettle();

        // Force rebuild
        await tester.pumpWidget(
          const MaterialApp(
            home: MockAnimalCreateForm(),
          ),
        );

        // Check that form data is maintained
        expect(find.text('Test Animal'), findsOneWidget);
      });
    });
  });
}