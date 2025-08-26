import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/journal_entry.dart';
import '../models/animal.dart';
import '../models/location_weather.dart';
import '../services/journal_service.dart';
import '../services/animal_service.dart';
import '../services/weather_service.dart';
import '../services/geolocation_service.dart';
import '../services/n8n_webhook_service.dart';
import '../theme/app_theme.dart';

class JournalEntryFormPage extends StatefulWidget {
  final String? animalId;
  final JournalEntry? existingEntry;

  const JournalEntryFormPage({
    super.key,
    this.animalId,
    this.existingEntry,
  });

  @override
  State<JournalEntryFormPage> createState() => _JournalEntryFormPageState();
}

class _JournalEntryFormPageState extends State<JournalEntryFormPage> {
  final _formKey = GlobalKey<FormState>();
  final _scrollController = ScrollController();

  // Form controllers
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _objectivesController = TextEditingController();
  final _challengesController = TextEditingController();
  final _improvementsController = TextEditingController();
  final _tagsController = TextEditingController();
  final _currentWeightController = TextEditingController();
  final _targetWeightController = TextEditingController();

  // Form state
  DateTime _selectedDate = DateTime.now();
  String? _selectedAnimalId;
  String _selectedCategory = 'daily_care';
  int _duration = 30;
  List<String> _selectedFFAStandards = [];
  List<String> _selectedAETSkills = [];
  List<String> _learningObjectives = [];
  String? _ffaDegreeType;
  String? _saeType;
  bool _countsForDegree = false;
  double? _hoursLogged;
  double? _financialValue;
  String? _evidenceType;

  // Location and Weather
  LocationData? _locationData;
  WeatherData? _weatherData;
  bool _isLoadingWeather = false;
  bool _isLoadingLocation = false;
  bool _hasLocationPermission = false;

  // Data loading
  List<Animal> _animals = [];
  bool _isLoadingAnimals = true;
  bool _isSubmitting = false;
  bool _showWeightPanel = false;
  DateTime? _nextWeighInDate;

  // Services
  final _weatherService = WeatherService();

  @override
  void initState() {
    super.initState();
    _initializeForm();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _objectivesController.dispose();
    _challengesController.dispose();
    _improvementsController.dispose();
    _tagsController.dispose();
    _currentWeightController.dispose();
    _targetWeightController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _initializeForm() async {
    try {
      // Load user's animals
      await _loadAnimals();

      // Set default values
      if (widget.animalId != null) {
        _selectedAnimalId = widget.animalId;
      } else if (_animals.isNotEmpty) {
        _selectedAnimalId = _animals.first.id;
      }

      // Pre-populate if editing existing entry
      if (widget.existingEntry != null) {
        _populateFromExistingEntry();
      } else {
        // Set default title for new entry
        _titleController.text = 'Journal Entry - ${_formatDate(_selectedDate)}';
      }

      // Request location permission and get current location
      await _requestLocationPermission();

      setState(() {});
    } catch (e) {
      if (mounted) {
        _showErrorSnackbar('Failed to initialize form: ${e.toString()}');
      }
    }
  }

  Future<void> _loadAnimals() async {
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) return;

      final animals = await AnimalService.getUserAnimals(user.id);
      setState(() {
        _animals = animals;
        _isLoadingAnimals = false;
      });
    } catch (e) {
      setState(() {
        _isLoadingAnimals = false;
      });
    }
  }

  void _populateFromExistingEntry() {
    final entry = widget.existingEntry!;
    _titleController.text = entry.title;
    _descriptionController.text = entry.description;
    _selectedDate = entry.date;
    _selectedAnimalId = entry.animalId;
    _selectedCategory = entry.category;
    _duration = entry.duration;
    _selectedFFAStandards = List.from(entry.ffaStandards ?? []);
    _selectedAETSkills = List.from(entry.aetSkills);
    _learningObjectives = List.from(entry.objectives ?? []);
    _objectivesController.text = _learningObjectives.join('\n');
    _challengesController.text = entry.challenges ?? '';
    _improvementsController.text = entry.improvements ?? '';
    _ffaDegreeType = entry.ffaDegreeType;
    _saeType = entry.saType;
    _countsForDegree = entry.countsForDegree;
    _hoursLogged = entry.hoursLogged;
    _financialValue = entry.financialValue;
    _evidenceType = entry.evidenceType;
    _locationData = entry.locationData;
    _weatherData = entry.weatherData;

    if (entry.tags != null) {
      _tagsController.text = entry.tags!.join(', ');
    }
  }

  Future<void> _requestLocationPermission() async {
    setState(() => _isLoadingLocation = true);

    try {
      // Use real geolocation service
      final result = await GeolocationService.getCurrentLocation(
        requestPermissionIfNeeded: true,
        timeout: const Duration(seconds: 10),
      );

      if (result.isSuccess && result.data != null) {
        _locationData = result.data;
        _hasLocationPermission = true;
        
        // Automatically try to get weather if location is available
        await _attachCurrentWeather();
      } else {
        // Use mock location as fallback for demo
        final mockResult = GeolocationService.getMockLocation();
        _locationData = mockResult.data;
        _hasLocationPermission = false; // Mark as mock
        
        if (mounted) {
          _showErrorSnackbar('Using demo location: ${result.userMessage}');
        }
      }

      setState(() => _isLoadingLocation = false);
    } catch (e) {
      setState(() => _isLoadingLocation = false);
      print('Location permission error: $e');
      
      // Use mock location as final fallback
      final mockResult = GeolocationService.getMockLocation();
      _locationData = mockResult.data;
      _hasLocationPermission = false;
    }
  }

  Future<void> _attachCurrentWeather() async {
    if (_locationData == null) return;

    setState(() => _isLoadingWeather = true);

    try {
      // Try to get weather data
      final weather = await _weatherService.getWeatherByLocation(
        _locationData!.latitude!,
        _locationData!.longitude!,
      );

      if (weather != null) {
        setState(() {
          _weatherData = weather;
          _isLoadingWeather = false;
        });
      } else {
        // Use mock weather data for demonstration
        setState(() {
          _weatherData = WeatherData(
            temperature: 22.5,
            condition: 'partly_cloudy',
            humidity: 65,
            windSpeed: 8.5,
            description: 'Partly cloudy with light breeze',
          );
          _isLoadingWeather = false;
        });
      }
    } catch (e) {
      setState(() => _isLoadingWeather = false);
      print('Weather fetch error: $e');
    }
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 7)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: Theme.of(context).colorScheme.copyWith(
                  primary: AppTheme.primaryGreen,
                ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
        // Update default title if it hasn't been customized
        if (_titleController.text.startsWith('Journal Entry - ')) {
          _titleController.text = 'Journal Entry - ${_formatDate(_selectedDate)}';
        }
      });
    }
  }

  Future<void> _selectNextWeighInDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _nextWeighInDate ?? DateTime.now().add(const Duration(days: 7)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );

    if (picked != null) {
      setState(() {
        _nextWeighInDate = picked;
      });
    }
  }

  void _addFFAStandard(String standard) {
    if (!_selectedFFAStandards.contains(standard)) {
      setState(() {
        _selectedFFAStandards.add(standard);
      });
    }
  }

  void _removeFFAStandard(String standard) {
    setState(() {
      _selectedFFAStandards.remove(standard);
    });
  }

  void _addAETSkill(String skill) {
    if (!_selectedAETSkills.contains(skill)) {
      setState(() {
        _selectedAETSkills.add(skill);
      });
    }
  }

  void _removeAETSkill(String skill) {
    setState(() {
      _selectedAETSkills.remove(skill);
    });
  }

  void _addLearningObjective(String objective) {
    if (objective.trim().isNotEmpty && !_learningObjectives.contains(objective.trim())) {
      setState(() {
        _learningObjectives.add(objective.trim());
      });
    }
  }

  void _removeLearningObjective(int index) {
    setState(() {
      _learningObjectives.removeAt(index);
    });
  }

  Future<void> _submitJournal() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSubmitting = true);

    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) {
        throw Exception('User not authenticated');
      }

      // Parse tags from text input
      final tags = _tagsController.text
          .split(',')
          .map((tag) => tag.trim())
          .where((tag) => tag.isNotEmpty)
          .toList();

      // Parse objectives from text input if updated
      final objectivesText = _objectivesController.text.trim();
      if (objectivesText.isNotEmpty) {
        _learningObjectives = objectivesText
            .split('\n')
            .map((obj) => obj.trim())
            .where((obj) => obj.isNotEmpty)
            .toList();
      }

      final entry = JournalEntry(
        id: widget.existingEntry?.id,
        userId: user.id,
        title: _titleController.text.trim(),
        description: _descriptionController.text.trim(),
        date: _selectedDate,
        duration: _duration,
        category: _selectedCategory,
        animalId: _selectedAnimalId,
        aetSkills: _selectedAETSkills,
        ffaStandards: _selectedFFAStandards,
        objectives: _learningObjectives.isNotEmpty ? _learningObjectives : null,
        challenges: _challengesController.text.trim().isEmpty
            ? null
            : _challengesController.text.trim(),
        improvements: _improvementsController.text.trim().isEmpty
            ? null
            : _improvementsController.text.trim(),
        tags: tags.isNotEmpty ? tags : null,
        locationData: _locationData,
        weatherData: _weatherData,
        ffaDegreeType: _ffaDegreeType,
        saType: _saeType,
        countsForDegree: _countsForDegree,
        hoursLogged: _hoursLogged,
        financialValue: _financialValue,
        evidenceType: _evidenceType,
        isPublic: false,
        isSynced: false,
        createdAt: widget.existingEntry?.createdAt,
      );

      // Save to database
      JournalEntry savedEntry;
      if (widget.existingEntry != null) {
        savedEntry = await JournalService.updateEntry(entry);
      } else {
        savedEntry = await JournalService.createEntry(entry);
      }

      if (mounted) {
        // Show success message with AI processing indicator
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    widget.existingEntry != null
                        ? 'Journal entry updated! AI analysis processing...'
                        : 'Journal entry created! AI analysis processing...',
                  ),
                ),
              ],
            ),
            backgroundColor: AppTheme.secondaryGreen,
            duration: const Duration(seconds: 3),
            action: SnackBarAction(
              label: 'View',
              textColor: Colors.white,
              onPressed: () {
                // TODO: Navigate to entry detail view
              },
            ),
          ),
        );

        // Start AI processing in background (don't wait for completion)
        N8NWebhookService.processJournalEntry(savedEntry).catchError((error) {
          print('AI processing error: $error');
          // Show a subtle notification that AI processing failed
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Entry saved! AI analysis will retry when online.'),
                backgroundColor: Colors.orange,
                duration: Duration(seconds: 2),
              ),
            );
          }
        });

        Navigator.of(context).pop(savedEntry);
      }
    } catch (e) {
      if (mounted) {
        _showErrorSnackbar('Error saving entry: ${e.toString()}');
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  void _showErrorSnackbar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 4),
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.month}/${date.day}/${date.year}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.existingEntry != null ? 'Edit Journal Entry' : 'New Journal Entry'),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.help_outline),
            onPressed: () => _showHelpDialog(),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          controller: _scrollController,
          padding: const EdgeInsets.all(16),
          children: [
            // Animal Selection
            _buildAnimalSelector(),
            const SizedBox(height: 16),

            // Title and Date Row
            Row(
              children: [
                Expanded(
                  flex: 2,
                  child: _buildTitleField(),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildDateSelector(),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Category and Duration Row
            Row(
              children: [
                Expanded(
                  child: _buildCategorySelector(),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildDurationSelector(),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Location and Weather Card
            _buildLocationWeatherCard(),
            const SizedBox(height: 16),

            // Description Field
            _buildDescriptionField(),
            const SizedBox(height: 16),

            // FFA Standards Section
            _buildFFAStandardsSection(),
            const SizedBox(height: 16),

            // AET Skills Section
            _buildAETSkillsSection(),
            const SizedBox(height: 16),

            // Learning Objectives Section
            _buildLearningObjectivesSection(),
            const SizedBox(height: 16),

            // Weight/Feeding Panel (Collapsible)
            _buildWeightFeedingPanel(),
            const SizedBox(height: 16),

            // Additional Fields Section
            _buildAdditionalFieldsSection(),
            const SizedBox(height: 16),

            // FFA Degree Information
            _buildFFADegreeSection(),
            const SizedBox(height: 32),

            // Submit Button
            _buildSubmitButton(),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildAnimalSelector() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Animal *',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            if (_isLoadingAnimals)
              const Center(child: CircularProgressIndicator())
            else if (_animals.isEmpty)
              Card(
                color: Colors.orange.shade50,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      Icon(Icons.info, color: Colors.orange.shade700),
                      const SizedBox(width: 8),
                      const Expanded(
                        child: Text('No animals found. Add an animal first to create journal entries.'),
                      ),
                    ],
                  ),
                ),
              )
            else
              DropdownButtonFormField<String>(
                value: _selectedAnimalId,
                decoration: const InputDecoration(
                  hintText: 'Select an animal',
                  prefixIcon: Icon(Icons.pets),
                ),
                items: _animals.map((animal) {
                  return DropdownMenuItem(
                    value: animal.id,
                    child: Row(
                      children: [
                        Icon(
                          _getAnimalIcon(animal.species),
                          size: 20,
                          color: Theme.of(context).primaryColor,
                        ),
                        const SizedBox(width: 8),
                        Text('${animal.name} (${animal.speciesDisplay})'),
                      ],
                    ),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() {
                    _selectedAnimalId = value;
                  });
                },
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please select an animal';
                  }
                  return null;
                },
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildTitleField() {
    return TextFormField(
      controller: _titleController,
      decoration: const InputDecoration(
        labelText: 'Title *',
        hintText: 'Enter a descriptive title',
        prefixIcon: Icon(Icons.title),
      ),
      validator: (value) {
        if (value == null || value.trim().isEmpty) {
          return 'Title is required';
        }
        return null;
      },
    );
  }

  Widget _buildDateSelector() {
    return InkWell(
      onTap: () => _selectDate(context),
      child: InputDecorator(
        decoration: const InputDecoration(
          labelText: 'Date *',
          prefixIcon: Icon(Icons.calendar_today),
        ),
        child: Text(_formatDate(_selectedDate)),
      ),
    );
  }

  Widget _buildCategorySelector() {
    return DropdownButtonFormField<String>(
      value: _selectedCategory,
      decoration: const InputDecoration(
        labelText: 'Category *',
        prefixIcon: Icon(Icons.category),
      ),
      items: JournalCategories.categories.map((category) {
        return DropdownMenuItem(
          value: category,
          child: Text(JournalCategories.getDisplayName(category)),
        );
      }).toList(),
      onChanged: (value) {
        setState(() {
          _selectedCategory = value!;
        });
      },
    );
  }

  Widget _buildDurationSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.timer, color: Colors.grey),
            const SizedBox(width: 8),
            Text('Duration: $_duration minutes'),
          ],
        ),
        Slider(
          value: _duration.toDouble(),
          min: 5,
          max: 480,
          divisions: 95,
          label: '$_duration min',
          onChanged: (value) {
            setState(() {
              _duration = value.round();
            });
          },
        ),
      ],
    );
  }

  Widget _buildLocationWeatherCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text(
                  'Location & Weather',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                if (_weatherData == null)
                  TextButton.icon(
                    onPressed: _isLoadingWeather ? null : _attachCurrentWeather,
                    icon: _isLoadingWeather
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.cloud),
                    label: Text(_isLoadingWeather ? 'Loading...' : 'Attach Weather'),
                  ),
              ],
            ),
            const SizedBox(height: 8),

            // Location Info
            if (_locationData != null) ...[
              Row(
                children: [
                  const Icon(Icons.location_on, size: 20, color: Colors.green),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _locationData!.address ?? 'Location captured',
                      style: const TextStyle(fontWeight: FontWeight.w500),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
            ],

            // Weather Info
            if (_weatherData != null) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue.shade200),
                ),
                child: Row(
                  children: [
                    Icon(
                      _getWeatherIcon(_weatherData!.condition),
                      color: Colors.blue.shade700,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${_weatherData!.temperature?.round() ?? '--'}°C',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.blue.shade700,
                            ),
                          ),
                          Text(
                            _weatherData!.description ?? 'Weather attached',
                            style: TextStyle(color: Colors.blue.shade600),
                          ),
                        ],
                      ),
                    ),
                    TextButton(
                      onPressed: () {
                        setState(() {
                          _weatherData = null;
                        });
                      },
                      child: const Text('Remove'),
                    ),
                  ],
                ),
              ),
            ] else if (_isLoadingLocation) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Row(
                  children: [
                    SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                    SizedBox(width: 12),
                    Text('Getting location...'),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildDescriptionField() {
    return TextFormField(
      controller: _descriptionController,
      maxLines: 8,
      decoration: const InputDecoration(
        labelText: 'Entry Content *',
        hintText: 'Describe your activities in detail...\n\nBe specific about:\n• What you did\n• What you observed\n• What you learned\n• Any challenges faced',
        alignLabelWithHint: true,
        prefixIcon: Padding(
          padding: EdgeInsets.only(bottom: 120),
          child: Icon(Icons.description),
        ),
      ),
      validator: (value) {
        if (value == null || value.trim().isEmpty) {
          return 'Please describe your activities';
        }
        if (value.trim().split(' ').length < 20) {
          return 'Please provide more detail (minimum 20 words)';
        }
        return null;
      },
    );
  }

  Widget _buildFFAStandardsSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text(
                  'FFA Standards',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                TextButton.icon(
                  onPressed: _showFFAStandardsDialog,
                  icon: const Icon(Icons.add),
                  label: const Text('Add Standard'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (_selectedFFAStandards.isEmpty)
              const Text(
                'Select FFA standards that relate to your activities',
                style: TextStyle(color: Colors.grey),
              )
            else
              Wrap(
                spacing: 8,
                children: _selectedFFAStandards.map((standard) {
                  return Chip(
                    label: Text(standard),
                    deleteIcon: const Icon(Icons.close, size: 18),
                    onDeleted: () => _removeFFAStandard(standard),
                    backgroundColor: AppTheme.primaryGreen.withOpacity(0.1),
                  );
                }).toList(),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildAETSkillsSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text(
                  'AET Skills',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                TextButton.icon(
                  onPressed: _showAETSkillsDialog,
                  icon: const Icon(Icons.add),
                  label: const Text('Add Skills'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (_selectedAETSkills.isEmpty)
              const Text(
                'Select AET skills you demonstrated',
                style: TextStyle(color: Colors.grey),
              )
            else
              Wrap(
                spacing: 8,
                children: _selectedAETSkills.map((skill) {
                  return Chip(
                    label: Text(skill),
                    deleteIcon: const Icon(Icons.close, size: 18),
                    onDeleted: () => _removeAETSkill(skill),
                    backgroundColor: AppTheme.secondaryGreen.withOpacity(0.1),
                  );
                }).toList(),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildLearningObjectivesSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Learning Objectives & Tags',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _objectivesController,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Learning Objectives',
                hintText: 'What did you aim to learn or accomplish?\nEnter each objective on a new line',
                prefixIcon: Icon(Icons.school),
                alignLabelWithHint: true,
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _tagsController,
              decoration: const InputDecoration(
                labelText: 'Tags',
                hintText: 'Add tags separated by commas (e.g., cattle, health, training)',
                prefixIcon: Icon(Icons.label),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWeightFeedingPanel() {
    return Card(
      child: Column(
        children: [
          ListTile(
            leading: const Icon(Icons.monitor_weight),
            title: const Text('Weight & Feeding Tracking'),
            trailing: IconButton(
              icon: Icon(_showWeightPanel ? Icons.expand_less : Icons.expand_more),
              onPressed: () {
                setState(() {
                  _showWeightPanel = !_showWeightPanel;
                });
              },
            ),
          ),
          if (_showWeightPanel) ...[
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _currentWeightController,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          decoration: const InputDecoration(
                            labelText: 'Current Weight (lbs)',
                            prefixIcon: Icon(Icons.scale),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextFormField(
                          controller: _targetWeightController,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          decoration: const InputDecoration(
                            labelText: 'Target Weight (lbs)',
                            prefixIcon: Icon(Icons.target),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  InkWell(
                    onTap: () => _selectNextWeighInDate(context),
                    child: InputDecorator(
                      decoration: const InputDecoration(
                        labelText: 'Next Weigh-in Date',
                        prefixIcon: Icon(Icons.schedule),
                      ),
                      child: Text(
                        _nextWeighInDate == null
                            ? 'Select date'
                            : _formatDate(_nextWeighInDate!),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildAdditionalFieldsSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Additional Information',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _challengesController,
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: 'Challenges Faced',
                hintText: 'What difficulties did you encounter?',
                prefixIcon: Icon(Icons.warning_amber),
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _improvementsController,
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: 'Improvements Planned',
                hintText: 'What will you do differently next time?',
                prefixIcon: Icon(Icons.trending_up),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFFADegreeSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'FFA Degree Information',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: _ffaDegreeType,
              decoration: const InputDecoration(
                labelText: 'FFA Degree Type',
                prefixIcon: Icon(Icons.school),
              ),
              items: FFAConstants.degreeTypes.map((type) {
                return DropdownMenuItem(value: type, child: Text(type));
              }).toList(),
              onChanged: (value) {
                setState(() {
                  _ffaDegreeType = value;
                });
              },
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: _saeType,
              decoration: const InputDecoration(
                labelText: 'SAE Type',
                prefixIcon: Icon(Icons.agriculture),
              ),
              items: FFAConstants.saeTypes.map((type) {
                return DropdownMenuItem(value: type, child: Text(type));
              }).toList(),
              onChanged: (value) {
                setState(() {
                  _saeType = value;
                });
              },
            ),
            const SizedBox(height: 12),
            SwitchListTile(
              title: const Text('Counts for FFA Degree'),
              value: _countsForDegree,
              onChanged: (value) {
                setState(() {
                  _countsForDegree = value;
                });
              },
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                      labelText: 'Hours Logged',
                      prefixIcon: Icon(Icons.timer),
                    ),
                    onChanged: (value) {
                      _hoursLogged = double.tryParse(value);
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                      labelText: 'Financial Value (\$)',
                      prefixIcon: Icon(Icons.attach_money),
                    ),
                    onChanged: (value) {
                      _financialValue = double.tryParse(value);
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: _evidenceType,
              decoration: const InputDecoration(
                labelText: 'Evidence Type',
                prefixIcon: Icon(Icons.assignment),
              ),
              items: FFAConstants.evidenceTypes.map((type) {
                return DropdownMenuItem(value: type, child: Text(type));
              }).toList(),
              onChanged: (value) {
                setState(() {
                  _evidenceType = value;
                });
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSubmitButton() {
    return SizedBox(
      width: double.infinity,
      height: 54,
      child: ElevatedButton(
        onPressed: _isSubmitting ? null : _submitJournal,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppTheme.primaryGreen,
          foregroundColor: Colors.white,
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: _isSubmitting
            ? const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2,
                    ),
                  ),
                  SizedBox(width: 12),
                  Text('Saving Entry...', style: TextStyle(fontSize: 16)),
                ],
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.save),
                  const SizedBox(width: 8),
                  Text(
                    widget.existingEntry != null ? 'Update Entry' : 'Create Entry',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
      ),
    );
  }

  void _showFFAStandardsDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Select FFA Standards'),
        content: SizedBox(
          width: double.maxFinite,
          height: 400,
          child: SingleChildScrollView(
            child: Column(
              children: _getCommonFFAStandards().map((standard) {
                final isSelected = _selectedFFAStandards.contains(standard);
                return CheckboxListTile(
                  title: Text(standard),
                  value: isSelected,
                  onChanged: (selected) {
                    setState(() {
                      if (selected == true) {
                        _addFFAStandard(standard);
                      } else {
                        _removeFFAStandard(standard);
                      }
                    });
                    Navigator.of(context).pop();
                    _showFFAStandardsDialog(); // Refresh dialog
                  },
                );
              }).toList(),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Done'),
          ),
        ],
      ),
    );
  }

  void _showAETSkillsDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Select AET Skills'),
        content: SizedBox(
          width: double.maxFinite,
          height: 400,
          child: SingleChildScrollView(
            child: Column(
              children: AETSkills.getAllSkills().map((skill) {
                final isSelected = _selectedAETSkills.contains(skill);
                return CheckboxListTile(
                  title: Text(skill),
                  value: isSelected,
                  onChanged: (selected) {
                    setState(() {
                      if (selected == true) {
                        _addAETSkill(skill);
                      } else {
                        _removeAETSkill(skill);
                      }
                    });
                    Navigator.of(context).pop();
                    _showAETSkillsDialog(); // Refresh dialog
                  },
                );
              }).toList(),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Done'),
          ),
        ],
      ),
    );
  }

  void _showHelpDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Journal Entry Tips'),
        content: const SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Creating Quality Entries:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 8),
              Text('• Be detailed and specific in your descriptions'),
              Text('• Include measurements, observations, and outcomes'),
              Text('• Document challenges and what you learned'),
              Text('• Select relevant FFA standards and AET skills'),
              SizedBox(height: 12),
              Text(
                'AI Analysis:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 8),
              Text('• Your entry will be analyzed for quality and learning'),
              Text('• AI provides feedback and suggestions for improvement'),
              Text('• FFA standards and competency levels are automatically mapped'),
              SizedBox(height: 12),
              Text(
                'Weather & Location:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 8),
              Text('• Weather conditions are automatically captured'),
              Text('• Location helps provide context for your activities'),
              Text('• Both are optional but improve AI analysis'),
            ],
          ),
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

  List<String> _getCommonFFAStandards() {
    return [
      'AS.01.01 - Analyze the role of animals in agriculture',
      'AS.01.02 - Demonstrate animal husbandry practices',
      'AS.02.01 - Analyze animal nutrition and feeding',
      'AS.02.02 - Calculate feed requirements and costs',
      'AS.07.01 - Demonstrate animal health maintenance',
      'AS.07.02 - Identify signs of animal diseases',
      'AS.03.01 - Demonstrate animal training techniques',
      'AS.04.01 - Prepare animals for exhibition',
      'AS.05.01 - Demonstrate animal breeding practices',
      'AB.01.01 - Maintain agricultural records',
      'AB.02.01 - Analyze agricultural financial data',
    ];
  }

  IconData _getAnimalIcon(AnimalSpecies species) {
    switch (species) {
      case AnimalSpecies.cattle:
        return Icons.pets;
      case AnimalSpecies.swine:
        return Icons.pets;
      case AnimalSpecies.sheep:
        return Icons.pets;
      case AnimalSpecies.goat:
        return Icons.pets;
      case AnimalSpecies.poultry:
        return Icons.flutter_dash;
      case AnimalSpecies.rabbit:
        return Icons.cruelty_free;
      case AnimalSpecies.other:
        return Icons.pets;
    }
  }

  IconData _getWeatherIcon(String? condition) {
    if (condition == null) return Icons.wb_sunny;
    
    switch (condition.toLowerCase()) {
      case 'sunny':
      case 'clear':
        return Icons.wb_sunny;
      case 'partly_cloudy':
      case 'partly cloudy':
        return Icons.wb_cloudy;
      case 'cloudy':
      case 'overcast':
        return Icons.cloud;
      case 'rain':
      case 'rainy':
        return Icons.umbrella;
      case 'snow':
      case 'snowy':
        return Icons.ac_unit;
      default:
        return Icons.wb_sunny;
    }
  }
}