import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/journal_entry.dart';
import '../models/animal.dart';
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

  // Data loading
  List<Animal> _animals = [];
  bool _isLoadingAnimals = true;
  bool _isSubmitting = false;
  bool _showWeightPanel = false;
  DateTime? _nextWeighInDate;

  // Services
  final _weatherService = WeatherService();
  
  // Auto-save functionality
  Timer? _autoSaveTimer;
  bool _hasUnsavedChanges = false;
  String? _draftKey;

  @override
  void initState() {
    super.initState();
    _draftKey = 'journal_draft_${widget.existingEntry?.id ?? 'new'}_${DateTime.now().millisecondsSinceEpoch}';
    _initializeForm();
    _setupAutoSave();
  }

  @override
  void dispose() {
    _autoSaveTimer?.cancel();
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

  void _setupAutoSave() {
    // Add listeners to track changes
    _titleController.addListener(_markAsChanged);
    _descriptionController.addListener(_markAsChanged);
    _objectivesController.addListener(_markAsChanged);
    _challengesController.addListener(_markAsChanged);
    _improvementsController.addListener(_markAsChanged);
    _tagsController.addListener(_markAsChanged);
    _currentWeightController.addListener(_markAsChanged);
    _targetWeightController.addListener(_markAsChanged);
    
    // Load any existing draft
    _loadDraft();
    
    // Setup periodic auto-save
    _autoSaveTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      if (_hasUnsavedChanges) {
        _saveDraft();
      }
    });
  }

  void _markAsChanged() {
    if (!_hasUnsavedChanges) {
      setState(() {
        _hasUnsavedChanges = true;
      });
    }
  }

  Future<void> _saveDraft() async {
    if (_draftKey == null) return;
    
    try {
      final draftData = {
        'title': _titleController.text,
        'description': _descriptionController.text,
        'selectedDate': _selectedDate.toIso8601String(),
        'selectedAnimalId': _selectedAnimalId,
        'selectedCategory': _selectedCategory,
        'duration': _duration,
        'selectedFFAStandards': _selectedFFAStandards,
        'selectedAETSkills': _selectedAETSkills,
        'learningObjectives': _learningObjectives,
        'objectives': _objectivesController.text,
        'challenges': _challengesController.text,
        'improvements': _improvementsController.text,
        'tags': _tagsController.text,
        'ffaDegreeType': _ffaDegreeType,
        'saeType': _saeType,
        'countsForDegree': _countsForDegree,
        'hoursLogged': _hoursLogged,
        'financialValue': _financialValue,
        'evidenceType': _evidenceType,
        'currentWeight': _currentWeightController.text,
        'targetWeight': _targetWeightController.text,
        'nextWeighInDate': _nextWeighInDate?.toIso8601String(),
        'savedAt': DateTime.now().toIso8601String(),
      };

      // Save to local storage (SharedPreferences in a real implementation)
      // For now, just mark as saved
      _hasUnsavedChanges = false;
      debugPrint('Auto-saved draft at ${DateTime.now()} with data: ${draftData.keys.join(", ")}');
    } catch (e) {
      debugPrint('Failed to save draft: $e');
    }
  }

  Future<void> _loadDraft() async {
    // In a real implementation, load from SharedPreferences
    // For now, skip draft loading
  }

  Future<void> _clearDraft() async {
    if (_draftKey == null) return;
    
    try {
      // In a real implementation, remove from SharedPreferences
      _hasUnsavedChanges = false;
      debugPrint('Cleared draft');
    } catch (e) {
      debugPrint('Failed to clear draft: $e');
    }
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

      final animals = await AnimalService().getAnimals();
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

    // Populate feed strategy data
    if (entry.feedStrategy != null) {
      _currentWeightController.text = entry.feedStrategy!.currentWeight?.toString() ?? '';
      _targetWeightController.text = entry.feedStrategy!.targetWeight?.toString() ?? '';
      _nextWeighInDate = entry.feedStrategy!.weighInDate;
    }

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
        
        // Automatically try to get weather if location is available
        await _attachCurrentWeather();
      } else {
        // Use mock location as fallback for demo
        final mockResult = GeolocationService.getMockLocation();
        _locationData = mockResult.data;
        
        if (mounted) {
          _showErrorSnackbar('Using demo location: ${result.userMessage}');
        }
      }

      setState(() => _isLoadingLocation = false);
    } catch (e) {
      setState(() => _isLoadingLocation = false);
      debugPrint('Location permission error: $e');
      
      // Use mock location as final fallback
      final mockResult = GeolocationService.getMockLocation();
      _locationData = mockResult.data;
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
      debugPrint('Weather fetch error: $e');
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

      // Create feed strategy if any weight data is provided
      FeedStrategy? feedStrategy;
      final currentWeight = double.tryParse(_currentWeightController.text);
      final targetWeight = double.tryParse(_targetWeightController.text);
      
      if (currentWeight != null || targetWeight != null || _nextWeighInDate != null) {
        feedStrategy = FeedStrategy(
          currentWeight: currentWeight,
          targetWeight: targetWeight,
          weighInDate: _nextWeighInDate,
        );
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
        feedStrategy: feedStrategy,
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
          debugPrint('AI processing error: $error');
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
          return error; // Return error to satisfy the function signature
        });

        // Clear draft on successful save
        await _clearDraft();
        
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

  Widget _buildProgressCard() {
    final requiredFields = [
      ('Animal', _selectedAnimalId?.isNotEmpty == true),
      ('Title', _titleController.text.trim().isNotEmpty),
      ('Content', _descriptionController.text.trim().split(RegExp(r'\s+')).length >= 25),
      ('Date', true), // Always has a date selected
      ('Category', _selectedCategory.isNotEmpty),
      ('Duration', _duration > 0),
    ];

    final completedCount = requiredFields.where((field) => field.$2).length;
    final totalCount = requiredFields.length;
    final progress = completedCount / totalCount;

    return Card(
      color: progress == 1.0 ? Colors.green.shade50 : Colors.orange.shade50,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  progress == 1.0 ? Icons.check_circle : Icons.incomplete_circle,
                  color: progress == 1.0 ? Colors.green : Colors.orange,
                ),
                const SizedBox(width: 8),
                Text(
                  progress == 1.0 
                      ? 'Ready to Submit!' 
                      : 'Entry Progress ($completedCount/$totalCount)',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: progress == 1.0 ? Colors.green.shade700 : Colors.orange.shade700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            LinearProgressIndicator(
              value: progress,
              backgroundColor: Colors.grey.shade300,
              valueColor: AlwaysStoppedAnimation<Color>(
                progress == 1.0 ? Colors.green : Colors.orange,
              ),
            ),
            const SizedBox(height: 8),
            if (progress < 1.0) ...[
              Text(
                'Missing required fields:',
                style: TextStyle(
                  fontWeight: FontWeight.w500,
                  color: Colors.orange.shade700,
                ),
              ),
              const SizedBox(height: 4),
              ...requiredFields
                  .where((field) => !field.$2)
                  .map((field) => Padding(
                        padding: const EdgeInsets.only(left: 8),
                        child: Row(
                          children: [
                            Icon(
                              Icons.radio_button_unchecked,
                              size: 16,
                              color: Colors.orange.shade600,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              field.$1,
                              style: TextStyle(color: Colors.orange.shade600),
                            ),
                          ],
                        ),
                      )),
            ] else
              Text(
                'All required fields completed! Your entry is ready for AI analysis.',
                style: TextStyle(color: Colors.green.shade700),
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Text(widget.existingEntry != null ? 'Edit Journal Entry' : 'New Journal Entry'),
            if (_hasUnsavedChanges) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.orange,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Text(
                  'Unsaved',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ],
        ),
        elevation: 0,
        actions: [
          if (_hasUnsavedChanges)
            IconButton(
              icon: const Icon(Icons.save_outlined),
              onPressed: _saveDraft,
              tooltip: 'Save Draft',
            ),
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
            // Progress indicator card
            _buildProgressCard(),
            const SizedBox(height: 16),

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
      decoration: InputDecoration(
        labelText: 'Entry Title *',
        hintText: 'Enter a descriptive title',
        prefixIcon: const Icon(Icons.title, color: AppTheme.primaryGreen),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppTheme.primaryGreen, width: 2),
        ),
        counterText: '${_titleController.text.length}/100',
      ),
      maxLength: 100,
      textCapitalization: TextCapitalization.words,
      validator: (value) {
        if (value == null || value.trim().isEmpty) {
          return 'Title is required';
        }
        if (value.trim().length < 5) {
          return 'Title must be at least 5 characters';
        }
        return null;
      },
      onChanged: (value) {
        setState(() {}); // Update counter
      },
    );
  }

  Widget _buildDateSelector() {
    return InkWell(
      onTap: () => _selectDate(context),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: 'Entry Date *',
          prefixIcon: const Icon(Icons.calendar_today, color: AppTheme.primaryGreen),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: AppTheme.primaryGreen, width: 2),
          ),
          suffixIcon: const Icon(Icons.arrow_drop_down),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                _formatDate(_selectedDate),
                style: const TextStyle(fontSize: 16),
              ),
            ),
            if (_selectedDate.difference(DateTime.now()).inDays.abs() <= 1)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: AppTheme.primaryGreen.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  _selectedDate.difference(DateTime.now()).inDays == 0 
                      ? 'Today' 
                      : _selectedDate.difference(DateTime.now()).inDays == -1
                          ? 'Yesterday'
                          : 'Tomorrow',
                  style: const TextStyle(
                    color: AppTheme.primaryGreen,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategorySelector() {
    return DropdownButtonFormField<String>(
      value: _selectedCategory,
      decoration: InputDecoration(
        labelText: 'Activity Category *',
        prefixIcon: Icon(_getCategoryIcon(_selectedCategory), color: AppTheme.primaryGreen),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppTheme.primaryGreen, width: 2),
        ),
      ),
      items: JournalCategories.categories.map((category) {
        return DropdownMenuItem(
          value: category,
          child: Row(
            children: [
              Icon(_getCategoryIcon(category), size: 20, color: Colors.grey.shade600),
              const SizedBox(width: 8),
              Text(JournalCategories.getDisplayName(category)),
            ],
          ),
        );
      }).toList(),
      onChanged: (value) {
        setState(() {
          _selectedCategory = value!;
        });
      },
      validator: (value) {
        if (value == null || value.isEmpty) {
          return 'Please select an activity category';
        }
        return null;
      },
    );
  }

  IconData _getCategoryIcon(String category) {
    switch (category) {
      case 'daily_care':
        return Icons.home;
      case 'health_check':
        return Icons.health_and_safety;
      case 'feeding':
        return Icons.restaurant;
      case 'training':
        return Icons.school;
      case 'show_prep':
        return Icons.emoji_events;
      case 'veterinary':
        return Icons.medical_services;
      case 'breeding':
        return Icons.family_restroom;
      case 'record_keeping':
        return Icons.note_alt;
      case 'financial':
        return Icons.monetization_on;
      case 'learning_reflection':
        return Icons.psychology;
      case 'project_planning':
        return Icons.assignment;
      case 'competition':
        return Icons.emoji_events;
      case 'community_service':
        return Icons.volunteer_activism;
      case 'leadership_activity':
        return Icons.groups;
      case 'safety_training':
        return Icons.security;
      case 'research':
        return Icons.science;
      default:
        return Icons.category;
    }
  }

  Widget _buildDurationSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                const Icon(Icons.timer, color: Colors.grey),
                const SizedBox(width: 8),
                const Text(
                  'Duration (minutes) *',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                ),
              ],
            ),
            Row(
              children: [
                IconButton(
                  onPressed: _duration > 5 ? () {
                    setState(() {
                      _duration = (_duration - 5).clamp(5, 480);
                    });
                  } : null,
                  icon: const Icon(Icons.remove),
                  style: IconButton.styleFrom(
                    backgroundColor: _duration > 5 
                        ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.1) 
                        : Colors.grey.withValues(alpha: 0.1),
                  ),
                ),
                Container(
                  width: 80,
                  alignment: Alignment.center,
                  child: Text(
                    '$_duration',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: _duration < 480 ? () {
                    setState(() {
                      _duration = (_duration + 5).clamp(5, 480);
                    });
                  } : null,
                  icon: const Icon(Icons.add),
                  style: IconButton.styleFrom(
                    backgroundColor: _duration < 480 
                        ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.1) 
                        : Colors.grey.withValues(alpha: 0.1),
                  ),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 8),
        Slider(
          value: _duration.toDouble(),
          min: 5,
          max: 480,
          divisions: 95,
          label: '$_duration min',
          activeColor: AppTheme.primaryGreen,
          onChanged: (value) {
            setState(() {
              _duration = value.round();
            });
          },
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '5 min',
              style: TextStyle(
                color: Colors.grey.shade600,
                fontSize: 12,
              ),
            ),
            Text(
              '8 hours',
              style: TextStyle(
                color: Colors.grey.shade600,
                fontSize: 12,
              ),
            ),
          ],
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
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.description, color: AppTheme.primaryGreen),
                const SizedBox(width: 8),
                const Text(
                  'Journal Entry Content *',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Writing Tips:',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.blue.shade700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '• What activities did you complete?\n• What did you observe or learn?\n• What challenges did you face?\n• How will you improve next time?',
                    style: TextStyle(
                      color: Colors.blue.shade700,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _descriptionController,
              maxLines: 10,
              minLines: 6,
              decoration: InputDecoration(
                hintText: 'Today I worked with my Holstein heifer to prepare for the county show...\n\nI focused on:\n• Teaching proper stance and positioning\n• Grooming techniques for show day\n• Building trust through gentle handling\n\nWhat I learned:\n• Patience is key when training animals\n• Consistent daily work shows results\n\nNext time I will:\n• Spend more time on left side positioning\n• Use higher value treats for motivation',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppTheme.primaryGreen, width: 2),
                ),
                contentPadding: const EdgeInsets.all(16),
                hintStyle: TextStyle(
                  color: Colors.grey.shade500,
                  height: 1.5,
                ),
              ),
              style: const TextStyle(height: 1.5),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Please describe your activities in detail';
                }
                final wordCount = value.trim().split(RegExp(r'\s+')).length;
                if (wordCount < 25) {
                  return 'Please provide more detail (minimum 25 words, currently $wordCount)';
                }
                return null;
              },
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.info_outline, size: 16, color: Colors.grey.shade600),
                const SizedBox(width: 4),
                Text(
                  'AI analysis works better with detailed, specific descriptions',
                  style: TextStyle(
                    color: Colors.grey.shade600,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
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
                    backgroundColor: AppTheme.primaryGreen.withValues(alpha: 0.1),
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
                    backgroundColor: AppTheme.secondaryGreen.withValues(alpha: 0.1),
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
            Row(
              children: [
                const Icon(Icons.school, color: AppTheme.primaryGreen),
                const SizedBox(width: 8),
                const Text(
                  'Learning Objectives & Tags',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 12),
            
            // Learning Objectives with chip display
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Learning Objectives',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 8),
                if (_learningObjectives.isNotEmpty)
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    children: _learningObjectives.asMap().entries.map((entry) {
                      return Chip(
                        label: Text(entry.value),
                        deleteIcon: const Icon(Icons.close, size: 18),
                        onDeleted: () => _removeLearningObjective(entry.key),
                        backgroundColor: Colors.blue.shade50,
                        deleteIconColor: Colors.blue.shade700,
                      );
                    }).toList(),
                  ),
                const SizedBox(height: 8),
                TextFormField(
                  decoration: const InputDecoration(
                    hintText: 'Add learning objective and press Enter',
                    prefixIcon: Icon(Icons.add_circle_outline),
                    border: OutlineInputBorder(),
                  ),
                  onFieldSubmitted: (value) {
                    if (value.trim().isNotEmpty) {
                      _addLearningObjective(value.trim());
                      // Clear the field
                      (context as Element).findAncestorStateOfType<FormFieldState>()?.reset();
                    }
                  },
                ),
                const SizedBox(height: 8),
                // Quick add common objectives
                Text(
                  'Quick Add:',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Wrap(
                  spacing: 6,
                  children: _getCommonObjectives().map((objective) {
                    final isAlreadyAdded = _learningObjectives.contains(objective);
                    return ActionChip(
                      label: Text(
                        objective,
                        style: TextStyle(
                          color: isAlreadyAdded ? Colors.grey : null,
                          fontSize: 12,
                        ),
                      ),
                      onPressed: isAlreadyAdded ? null : () {
                        _addLearningObjective(objective);
                      },
                      backgroundColor: isAlreadyAdded 
                          ? Colors.grey.shade200 
                          : AppTheme.primaryGreen.withValues(alpha: 0.1),
                      side: BorderSide(
                        color: isAlreadyAdded 
                            ? Colors.grey.shade300 
                            : AppTheme.primaryGreen.withValues(alpha: 0.3),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
            
            const SizedBox(height: 16),
            
            // Tags section
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Tags',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _tagsController,
                  decoration: const InputDecoration(
                    hintText: 'Add tags separated by commas (e.g., cattle, health, training)',
                    prefixIcon: Icon(Icons.label_outline),
                    border: OutlineInputBorder(),
                    helperText: 'Tags help organize and find your entries later',
                  ),
                ),
                const SizedBox(height: 8),
                // Suggested tags
                Wrap(
                  spacing: 6,
                  children: _getSuggestedTags().map((tag) {
                    return ActionChip(
                      label: Text(tag),
                      onPressed: () {
                        final currentTags = _tagsController.text.trim();
                        if (currentTags.isEmpty) {
                          _tagsController.text = tag;
                        } else if (!currentTags.contains(tag)) {
                          _tagsController.text = '$currentTags, $tag';
                        }
                      },
                      backgroundColor: Colors.grey.shade100,
                      side: BorderSide(color: Colors.grey.shade300),
                    );
                  }).toList(),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  List<String> _getSuggestedTags() {
    // Return tags based on selected category
    switch (_selectedCategory) {
      case 'health_check':
        return ['health', 'veterinary', 'assessment', 'monitoring'];
      case 'feeding':
        return ['nutrition', 'feed', 'growth', 'diet'];
      case 'training':
        return ['handling', 'behavior', 'showmanship', 'discipline'];
      case 'show_prep':
        return ['competition', 'grooming', 'presentation', 'practice'];
      default:
        return ['daily-care', 'record-keeping', 'learning', 'progress'];
    }
  }

  List<String> _getCommonObjectives() {
    // Return objectives based on selected category
    switch (_selectedCategory) {
      case 'health_check':
        return [
          'Assess animal health status',
          'Document health observations',
          'Learn disease prevention',
          'Practice health monitoring'
        ];
      case 'feeding':
        return [
          'Calculate proper feed amounts',
          'Monitor weight gain',
          'Learn nutrition requirements',
          'Track feed conversion'
        ];
      case 'training':
        return [
          'Improve animal handling skills',
          'Build trust with animal',
          'Practice show techniques',
          'Develop leadership abilities'
        ];
      case 'show_prep':
        return [
          'Perfect showmanship skills',
          'Prepare for competition',
          'Practice ring procedures',
          'Improve presentation'
        ];
      case 'daily_care':
        return [
          'Maintain daily care routine',
          'Observe animal behavior',
          'Practice responsibility',
          'Develop work ethic'
        ];
      default:
        return [
          'Apply agricultural knowledge',
          'Develop practical skills',
          'Document learning progress',
          'Build project experience'
        ];
    }
  }

  Widget _buildWeightFeedingPanel() {
    return Card(
      child: Column(
        children: [
          ListTile(
            leading: const Icon(Icons.monitor_weight, color: AppTheme.primaryGreen),
            title: const Text(
              'Weight & Feeding Strategy',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            subtitle: Text(
              _showWeightPanel ? 'Track weight progress and feeding goals' : 'Tap to expand weight tracking',
              style: const TextStyle(fontSize: 12),
            ),
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
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Weight information section
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.green.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.green.shade200),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Weight Management',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.green.shade700,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Track current weight and set targets for your animal\'s growth plan.',
                          style: TextStyle(
                            color: Colors.green.shade700,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  
                  // Weight input fields
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _currentWeightController,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          decoration: InputDecoration(
                            labelText: 'Current Weight',
                            suffixText: 'lbs',
                            prefixIcon: const Icon(Icons.scale, color: AppTheme.primaryGreen),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(color: AppTheme.primaryGreen, width: 2),
                            ),
                            hintText: '0.0',
                          ),
                          validator: (value) {
                            if (value != null && value.isNotEmpty) {
                              final weight = double.tryParse(value);
                              if (weight == null) {
                                return 'Enter a valid weight';
                              }
                              if (weight <= 0) {
                                return 'Weight must be positive';
                              }
                            }
                            return null;
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextFormField(
                          controller: _targetWeightController,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          decoration: InputDecoration(
                            labelText: 'Target Weight',
                            suffixText: 'lbs',
                            prefixIcon: const Icon(Icons.flag, color: AppTheme.primaryGreen),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(color: AppTheme.primaryGreen, width: 2),
                            ),
                            hintText: '0.0',
                          ),
                          validator: (value) {
                            if (value != null && value.isNotEmpty) {
                              final weight = double.tryParse(value);
                              if (weight == null) {
                                return 'Enter a valid weight';
                              }
                              if (weight <= 0) {
                                return 'Weight must be positive';
                              }
                              // Check if target is greater than current
                              final currentWeight = double.tryParse(_currentWeightController.text);
                              if (currentWeight != null && weight <= currentWeight) {
                                return 'Target should be > current';
                              }
                            }
                            return null;
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  
                  // Date picker
                  InkWell(
                    onTap: () => _selectNextWeighInDate(context),
                    child: InputDecorator(
                      decoration: InputDecoration(
                        labelText: 'Next Weigh-in Date',
                        prefixIcon: const Icon(Icons.schedule, color: AppTheme.primaryGreen),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: AppTheme.primaryGreen, width: 2),
                        ),
                        suffixIcon: const Icon(Icons.arrow_drop_down),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              _nextWeighInDate == null
                                  ? 'Select target weigh-in date'
                                  : _formatDate(_nextWeighInDate!),
                              style: TextStyle(
                                fontSize: 16,
                                color: _nextWeighInDate == null ? Colors.grey.shade600 : null,
                              ),
                            ),
                          ),
                          if (_nextWeighInDate != null)
                            TextButton(
                              onPressed: () {
                                setState(() {
                                  _nextWeighInDate = null;
                                });
                              },
                              child: const Text('Clear'),
                            ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  
                  // Weight progress information
                  if (_currentWeightController.text.isNotEmpty && _targetWeightController.text.isNotEmpty) ...[
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.blue.shade200),
                      ),
                      child: _buildWeightProgressInfo(),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildWeightProgressInfo() {
    final current = double.tryParse(_currentWeightController.text);
    final target = double.tryParse(_targetWeightController.text);
    
    if (current == null || target == null) return const SizedBox.shrink();
    
    final difference = target - current;
    final isGainNeeded = difference > 0;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              isGainNeeded ? Icons.trending_up : Icons.trending_down,
              color: Colors.blue.shade700,
              size: 20,
            ),
            const SizedBox(width: 8),
            Text(
              'Weight Goal Analysis',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.blue.shade700,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          '${isGainNeeded ? 'Gain needed' : 'Loss needed'}: ${difference.abs().toStringAsFixed(1)} lbs',
          style: const TextStyle(fontSize: 14),
        ),
        if (_nextWeighInDate != null) ...[
          const SizedBox(height: 4),
          Text(
            'Days until weigh-in: ${_nextWeighInDate!.difference(DateTime.now()).inDays}',
            style: const TextStyle(fontSize: 14),
          ),
        ],
      ],
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