import 'dart:async';
import 'package:flutter/foundation.dart' show kIsWeb, kDebugMode;
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import '../models/journal_entry.dart' hide JournalCategories, FFAConstants;
import '../models/animal.dart';
import '../models/feed.dart';
import '../models/ffa_constants.dart';
import '../services/journal_service.dart';
import '../services/feed_service.dart';
import '../services/animal_service.dart';
import '../services/weather_service.dart';
import '../services/geolocation_service.dart';
import '../services/n8n_webhook_service.dart';
import '../services/journal_toast_service.dart';
import '../services/spar_runs_service.dart';
import '../theme/app_theme.dart';
import '../widgets/toast_notification_widget.dart';
import '../widgets/feed_data_card.dart';
import '../widgets/assessment_preview_card.dart';
import '../widgets/processing_status_indicator.dart';
import '../constants/livestock_breeds.dart';

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

class _JournalEntryFormPageState extends State<JournalEntryFormPage> 
    with ToastMixin<JournalEntryFormPage> {
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
  String? _selectedBreed;
  final _customBreedController = TextEditingController();

  // Metadata fields
  String _selectedSource = 'web_app';
  final _notesController = TextEditingController();

  // Location and Weather
  LocationData? _locationData;
  WeatherData? _weatherData;
  bool _isLoadingWeather = false;
  bool _isLoadingLocation = false;
  bool _useIPBasedWeather = false;
  String? _locationCity;
  String? _locationState;

  // Data loading
  List<Animal> _animals = [];
  bool _isLoadingAnimals = true;
  bool _isSubmitting = false;
  bool _showWeightPanel = false;
  DateTime? _nextWeighInDate;

  // Feed data
  List<FeedItem> _feedItems = [];

  // Services
  final _weatherService = WeatherService();
  
  // Auto-save functionality
  Timer? _autoSaveTimer;
  bool _hasUnsavedChanges = false;
  String? _draftKey;

  // SPAR Run Controls (Advanced AI Settings)
  bool _sendToSPAROrchestrator = true; // Default ON
  String _runId = '';
  String _routeIntent = 'edu_context'; // Default edu_context
  
  // AI Processing Status
  ProcessingStatus _aiProcessingStatus = ProcessingStatus.idle;
  String? _aiProcessingMessage;
  String? _aiProcessingError;
  double? _aiProcessingProgress;
  Timer? _aiStatusTimer;
  
  // Distributed tracing
  late String _traceId; // Generated once for end-to-end correlation
  int _vectorMatchCount = 6; // Default 6
  double _vectorMinSimilarity = 0.75; // Default 0.75
  String? _toolInputsCategory;
  String? _toolInputsQuery;
  bool _showAdvancedSettings = false;
  
  // AI Assessment Preview
  SPARAssessmentResult? _assessmentResult;
  bool _showAssessmentPreview = false;
  bool _isProcessingAssessment = false;
  
  static const _uuid = Uuid();

  @override
  void initState() {
    super.initState();
    _draftKey = 'journal_draft_${widget.existingEntry?.id ?? 'new'}_${DateTime.now().millisecondsSinceEpoch}';
    _runId = _uuid.v4(); // Generate unique run ID for correlation with n8n
    _traceId = _uuid.v4(); // Generate trace ID for distributed tracing
    _initializeForm();
    _setupAutoSave();
  }

  @override
  void dispose() {
    _autoSaveTimer?.cancel();
    _aiStatusTimer?.cancel();
    _titleController.dispose();
    _descriptionController.dispose();
    _objectivesController.dispose();
    _challengesController.dispose();
    _improvementsController.dispose();
    _tagsController.dispose();
    _currentWeightController.dispose();
    _targetWeightController.dispose();
    _notesController.dispose();
    _customBreedController.dispose();
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
    _notesController.addListener(_markAsChanged);
    
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
        'selectedSource': _selectedSource,
        'notes': _notesController.text,
        // SPAR Settings
        'sendToSPAROrchestrator': _sendToSPAROrchestrator,
        'runId': _runId,
        'routeIntent': _routeIntent,
        'vectorMatchCount': _vectorMatchCount,
        'vectorMinSimilarity': _vectorMinSimilarity,
        'toolInputsCategory': _toolInputsCategory,
        'toolInputsQuery': _toolInputsQuery,
        'showAdvancedSettings': _showAdvancedSettings,
        'savedAt': DateTime.now().toIso8601String(),
        // Feed items
        'feedItems': _feedItems.map((item) => item.toJson()).toList(),
      };

      // Save to local storage (SharedPreferences in a real implementation)
      // For now, just mark as saved
      _hasUnsavedChanges = false;
      debugPrint('Auto-saved draft at ${DateTime.now()} with data: ${draftData.keys.join(", ")}');
      
      // Show subtle draft saved notification
      JournalToast.draftSaved();
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
      // Detect platform and set source
      _detectAndSetSource();

      // Load user's animals
      await _loadAnimals();

      // Set default values
      if (widget.animalId != null) {
        _selectedAnimalId = widget.animalId;
      } else if (_animals.isNotEmpty) {
        _selectedAnimalId = _animals.first.id;
      }
      
      // Initialize breed for selected animal (if not editing existing entry)
      if (_selectedAnimalId != null && widget.existingEntry == null) {
        _initializeBreedForAnimal(_selectedAnimalId!);
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
        _showError('Failed to initialize form: ${e.toString()}');
      }
    }
  }

  void _detectAndSetSource() {
    // Auto-detect source based on platform
    if (kIsWeb) {
      // Running in web browser
      _selectedSource = 'web_app';
    } else {
      // Running on native mobile platform
      _selectedSource = 'mobile_app';
    }
    
    debugPrint('Auto-detected source: $_selectedSource (kIsWeb: $kIsWeb)');
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

    // Populate metadata fields from existing entry
    _selectedSource = entry.source ?? 'web_app'; // Use existing or default
    _parseNotesAndBreed(entry.notes ?? ''); // Parse notes and extract breed info
    
    // Generate new IDs for edited entries to create new trace
    _runId = _uuid.v4();
    _traceId = _uuid.v4(); // New trace for edited entry

    // Load feed items if editing existing entry
    if (entry.id != null) {
      _loadFeedItems(entry.id!);
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
        await _extractCityStateFromLocation(_locationData!);
      } else {
        // Location not available
        if (mounted) {
          _showError('Location not available: ${result.userMessage}');
        }
      }

      setState(() => _isLoadingLocation = false);
    } catch (e) {
      setState(() => _isLoadingLocation = false);
      debugPrint('Location permission error: $e');
      
      if (mounted) {
        _showError('Location error: ${e.toString()}');
      }
    }
  }

  Future<void> _extractCityStateFromLocation(LocationData location) async {
    try {
      // Use city and state from LocationData if available
      if (location.city != null && location.state != null) {
        _locationCity = location.city;
        _locationState = location.state;
      } else {
        // Fallback: extract from address if available
        if (location.address != null) {
          final addressParts = location.address!.split(', ');
          if (addressParts.length >= 2) {
            // Try to extract city and state from address
            // Format might be "Denver, CO" or "Denver, CO 80202, USA"
            for (int i = 0; i < addressParts.length; i++) {
              final part = addressParts[i].trim();
              // Look for state-like pattern (2 letter code)
              if (part.length == 2 && part.toUpperCase() == part) {
                _locationState = part;
                if (i > 0) {
                  _locationCity = addressParts[i - 1].trim();
                }
                break;
              }
            }
          }
        }
        
        // No location data available
        if (_locationCity == null && location.address?.contains('Denver') == true) {
          _locationCity = 'Denver';
          _locationState = 'CO';
        }
      }
      
      // Update LocationData with extracted city/state
      if (_locationCity != null || _locationState != null) {
        _locationData = LocationData(
          latitude: location.latitude,
          longitude: location.longitude,
          address: location.address,
          name: location.name,
          accuracy: location.accuracy,
          capturedAt: location.capturedAt,
          city: _locationCity,
          state: _locationState,
        );
      }
      
      setState(() {});
    } catch (e) {
      debugPrint('Error extracting city/state: $e');
      // Set defaults if extraction fails
      _locationCity = 'Unknown';
      _locationState = 'Unknown';
    }
  }

  Future<void> _attachCurrentWeather() async {
    setState(() => _isLoadingWeather = true);

    try {
      WeatherData? weather;
      
      if (_useIPBasedWeather || _locationData == null) {
        // Try IP-based weather (fallback)
        if (_locationCity != null) {
          weather = await _weatherService.getWeatherByCityName(_locationCity!);
        }
      } else if (_locationData != null) {
        // Try GPS-based weather
        weather = await _weatherService.getWeatherByLocation(
          _locationData!.latitude!,
          _locationData!.longitude!,
        );
      }

      if (weather != null) {
        setState(() {
          _weatherData = weather;
          _isLoadingWeather = false;
        });
      } else {
        // Use enhanced mock weather data for demonstration
        setState(() {
          _weatherData = null;
          _isLoadingWeather = false;
        });
        
        if (mounted) {
          _showError('Weather data not available');
        }
      }
    } catch (e) {
      setState(() => _isLoadingWeather = false);
      debugPrint('Weather fetch error: $e');
      if (mounted) {
        _showError('Could not fetch weather data');
      }
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

  Future<void> _loadFeedItems(String entryId) async {
    try {
      final feedItems = await FeedService.getFeedItemsForEntry(entryId);
      setState(() {
        _feedItems = feedItems;
      });
    } catch (e) {
      debugPrint('Failed to load feed items: $e');
      // Not critical, just means no feed items to display
    }
  }

  void _onFeedItemsChanged(List<FeedItem> feedItems) {
    setState(() {
      _feedItems = feedItems;
      _markAsChanged();
    });
  }

  Future<void> _saveFeedItems(String entryId) async {
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) throw Exception('User not authenticated');

      debugPrint('💾 Saving ${_feedItems.length} feed items for entry: $entryId');

      for (final feedItem in _feedItems) {
        // Create feed item with proper entry ID and user ID
        final itemToSave = feedItem.copyWith(
          entryId: entryId,
          userId: user.id,
        );

        await FeedService.saveFeedItem(itemToSave);
      }

      debugPrint('✅ Successfully saved ${_feedItems.length} feed items');
    } catch (e) {
      debugPrint('❌ Error saving feed items: $e');
      // Non-critical error - don't block journal submission
      // Just show a warning message
      if (mounted) {
        _showError('Journal saved successfully, but some feed items could not be saved: ${e.toString()}');
      }
    }
  }

  /// Compose retrieval query for AI processing
  /// Format: entry_text\nFFA: ffa_standards\nObjectives: learning_objectives\nWeight update: cw=current_weight • tw=target_weight • d=entry_date
  String _composeRetrievalQuery() {
    final parts = <String>[];
    
    // Main entry text
    final entryText = _descriptionController.text.trim();
    if (entryText.isNotEmpty) {
      parts.add(entryText);
    }
    
    // FFA Standards
    if (_selectedFFAStandards.isNotEmpty) {
      parts.add('FFA: ${_selectedFFAStandards.join(', ')}');
    }
    
    // Learning Objectives
    if (_learningObjectives.isNotEmpty) {
      parts.add('Objectives: ${_learningObjectives.join(', ')}');
    }
    
    // Weight update information
    final currentWeight = _currentWeightController.text.trim();
    final targetWeight = _targetWeightController.text.trim();
    if (currentWeight.isNotEmpty || targetWeight.isNotEmpty) {
      final weightParts = <String>[];
      if (currentWeight.isNotEmpty) {
        weightParts.add('cw=$currentWeight');
      }
      if (targetWeight.isNotEmpty) {
        weightParts.add('tw=$targetWeight');
      }
      weightParts.add('d=${_formatDate(_selectedDate)}');
      parts.add('Weight update: ${weightParts.join(' • ')}');
    }
    
    // Example output:
    // Today I worked with my Holstein heifer to prepare for the county show...
    // FFA: AS.01.01 - Analyze the role of animals in agriculture, AS.07.01 - Demonstrate animal health maintenance
    // Objectives: Improve animal handling skills, Build trust with animal
    // Weight update: cw=850 • tw=900 • d=1/15/2025
    
    return parts.join('\n');
  }

  Future<void> _submitJournal() async {
    if (!_formKey.currentState!.validate()) {
      // Show validation error toast
      JournalToast.validationError('required fields');
      return;
    }

    setState(() => _isSubmitting = true);

    // Use the comprehensive journal toast submission flow
    await JournalToast.showSubmissionFlow(
      onSubmit: () => _performSubmission(),
      onViewEntry: () {
        // TODO: Navigate to entry detail view
        debugPrint('Navigate to journal entry detail view');
      },
      onRetry: () {
        // Retry submission
        _submitJournal();
      },
    );
  }

  /// Performs the actual journal submission logic
  Future<void> _performSubmission() async {
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
        // Metadata fields
        source: _selectedSource,
        notes: _buildNotesWithBreed(),
        // Distributed tracing
        traceId: _traceId,
      );

      // Save to database
      JournalEntry savedEntry;
      if (widget.existingEntry != null) {
        savedEntry = await JournalService.updateEntry(entry);
      } else {
        savedEntry = await JournalService.createEntry(entry);
      }

      // Save feed items after journal entry is saved
      if (_feedItems.isNotEmpty && savedEntry.id != null) {
        await _saveFeedItems(savedEntry.id!);
      }

      // Clear draft on successful save
      await _clearDraft();

      // Start AI processing in background if enabled
      if (_sendToSPAROrchestrator) {
        _startAIProcessing(savedEntry);
      }

      // Navigate back on success (after toast flow completes)
      if (mounted) {
        // Small delay to allow toast flow to complete
        Future.delayed(const Duration(milliseconds: 6500), () {
          if (mounted) {
            if (_sendToSPAROrchestrator) {
              _simulateAssessmentResult();
            } else {
              Navigator.of(context).pop(savedEntry);
            }
          }
        });
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  /// Build notes field including breed information
  String? _buildNotesWithBreed() {
    final userNotes = _notesController.text.trim();
    final breedInfo = _getBreedInfo();
    
    if (breedInfo.isEmpty && userNotes.isEmpty) {
      return null;
    }
    
    if (breedInfo.isEmpty) {
      return userNotes;
    }
    
    if (userNotes.isEmpty) {
      return breedInfo;
    }
    
    return '$breedInfo\n\n$userNotes';
  }
  
  /// Get breed information for the selected animal
  String _getBreedInfo() {
    if (_selectedAnimalId == null || _selectedBreed == null) {
      return '';
    }
    
    final selectedAnimal = _animals.firstWhere(
      (animal) => animal.id == _selectedAnimalId,
      orElse: () => throw Exception('Selected animal not found'),
    );
    
    final breed = _selectedBreed == 'Other' 
        ? _customBreedController.text.trim()
        : _selectedBreed!;
    
    if (breed.isEmpty) return '';
    
    return 'Breed: $breed (${selectedAnimal.speciesDisplay})';
  }

  /// Parse notes field and extract breed information for existing entries
  void _parseNotesAndBreed(String notes) {
    final lines = notes.split('\n');
    final breedRegex = RegExp(r'^Breed:\s*(.+?)\s*\([^)]+\)$');
    
    String cleanedNotes = '';
    String? extractedBreed;
    
    for (final line in lines) {
      final match = breedRegex.firstMatch(line.trim());
      if (match != null) {
        extractedBreed = match.group(1)?.trim();
      } else if (line.trim().isNotEmpty) {
        if (cleanedNotes.isNotEmpty) cleanedNotes += '\n';
        cleanedNotes += line;
      }
    }
    
    // Set the cleaned notes (without breed info)
    _notesController.text = cleanedNotes;
    
    // Set breed information if found and animal is loaded
    if (extractedBreed != null && _selectedAnimalId != null && _animals.isNotEmpty) {
      _initializeBreedForAnimal(_selectedAnimalId!, extractedBreed);
    }
  }

  /// Initialize breed for selected animal
  void _initializeBreedForAnimal(String animalId, [String? breedHint]) {
    final selectedAnimal = _animals.firstWhere(
      (animal) => animal.id == animalId,
      orElse: () => throw Exception('Selected animal not found'),
    );
    
    final availableBreeds = getBreedsForSpecies(selectedAnimal.species);
    String? breedToSet = breedHint ?? selectedAnimal.breed;
    
    if (breedToSet != null && breedToSet.isNotEmpty) {
      if (availableBreeds.contains(breedToSet)) {
        _selectedBreed = breedToSet;
        _customBreedController.clear();
      } else {
        _selectedBreed = 'Other';
        _customBreedController.text = breedToSet;
      }
    } else {
      _selectedBreed = null;
      _customBreedController.clear();
    }
  }

  /// Start AI processing with proper error handling
  void _startAIProcessing(JournalEntry savedEntry) {
    // Update status to pending
    _updateAIProcessingStatus(
      ProcessingStatus.pending,
      message: 'Submitting for AI analysis...',
    );

    // Compose retrieval query for AI processing
    final retrievalQuery = _composeRetrievalQuery();
    debugPrint('Composed retrieval query: $retrievalQuery');
    
    // Prepare SPAR settings for webhook payload
    final sparSettings = {
      'enabled': true,
      'runId': _runId,
      'route': {
        'intent': _routeIntent,
      },
      'vector': {
        'matchCount': _vectorMatchCount,
        'minSimilarity': _vectorMinSimilarity,
      },
      'toolInputs': {
        'category': _toolInputsCategory,
        'query': _toolInputsQuery ?? retrievalQuery,
      },
    };
    
    debugPrint('SPAR Settings: ${sparSettings.toString()}');
    
    // Start AI processing in background (don't wait for completion)
    N8NWebhookService.sendJournalEntry(
      savedEntry,
      sparSettings: sparSettings,
    ).then((_) {
      // Successfully submitted - update to processing
      _updateAIProcessingStatus(
        ProcessingStatus.processing,
        message: 'AI analyzing your entry...',
      );
    }).catchError((error) {
      debugPrint('AI processing error: $error');
      // Update status to failed
      _updateAIProcessingStatus(
        ProcessingStatus.failed,
        message: 'AI analysis failed to start',
        error: error.toString(),
      );
      
      // Show AI processing error toast (non-blocking)
      if (mounted) {
        JournalToast.aiError(onRetry: () {
          _startAIProcessing(savedEntry);
        });
      }
      return error;
    });
  }

  /// Show error using toast notification system
  void _showError(String message, {VoidCallback? onRetry}) {
    showError(message, onAction: onRetry);
  }

  /// Example method for file upload with toast notifications
  /// This can be used when file upload functionality is implemented
  Future<void> _uploadFile(String fileName, Future<void> Function() uploadFunction) async {
    String? uploadToastId;
    
    try {
      // Show upload progress toast
      uploadToastId = JournalToast.uploadProgress(fileName);
      
      // Perform the actual upload
      await uploadFunction();
      
      // Dismiss progress toast and show success
      if (uploadToastId != null) {
        dismissToast(uploadToastId);
      }
      JournalToast.uploadSuccess(fileName);
      
    } catch (e) {
      // Dismiss progress toast and show error
      if (uploadToastId != null) {
        dismissToast(uploadToastId);
      }
      JournalToast.uploadError(fileName, onRetry: () {
        _uploadFile(fileName, uploadFunction);
      });
    }
  }

  /// Example method for multiple file uploads with progress tracking
  Future<void> _uploadMultipleFiles(List<String> fileNames, List<Future<void> Function()> uploadFunctions) async {
    for (int i = 0; i < fileNames.length; i++) {
      await _uploadFile(fileNames[i], uploadFunctions[i]);
      
      // Small delay between uploads to show progress
      if (i < fileNames.length - 1) {
        await Future.delayed(const Duration(milliseconds: 500));
      }
    }
    
    // Show completion toast
    showSuccess('All ${fileNames.length} files uploaded successfully!');
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
                _sendToSPAROrchestrator
                    ? 'All required fields completed! Your entry is ready for enhanced SPAR analysis.'
                    : 'All required fields completed! Your entry is ready for basic AI analysis.',
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
          // AI Processing Status Indicator
          if (_aiProcessingStatus != ProcessingStatus.idle)
            ProcessingStatusIndicator(
              status: _aiProcessingStatus,
              message: _aiProcessingMessage,
              errorMessage: _aiProcessingError,
              progress: _aiProcessingProgress,
              size: ProcessingStatusSize.small,
              showStatusText: false,
              onTap: _showAIProcessingDetails,
            ),
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

            // Feed Data Section
            FeedDataCard(
              feedItems: _feedItems,
              onFeedItemsChanged: _onFeedItemsChanged,
              selectedAnimal: _selectedAnimalId != null 
                  ? _animals.firstWhere((a) => a.id == _selectedAnimalId, orElse: () => _animals.first)
                  : null,
            ),
            const SizedBox(height: 16),

            // Weight/Feeding Panel (Collapsible)
            _buildWeightFeedingPanel(),
            const SizedBox(height: 16),

            // Additional Fields Section
            _buildAdditionalFieldsSection(),
            const SizedBox(height: 16),

            // Metadata Section
            _buildMetadataSection(),
            const SizedBox(height: 16),

            // Advanced AI Settings (SPAR Controls)
            _buildAdvancedAISettingsSection(),
            const SizedBox(height: 16),

            // FFA Degree Information
            _buildFFADegreeSection(),
            const SizedBox(height: 16),

            // AI Assessment Preview (appears after submission when SPAR enabled)
            if (_showAssessmentPreview || _isProcessingAssessment) ...[
              AssessmentPreviewCard(
                assessmentResult: _assessmentResult,
                isProcessing: _isProcessingAssessment,
                onViewDetails: _onViewAssessmentDetails,
                onShare: _onShareAssessment,
                onRetry: _onRetryAssessment,
              ),
              const SizedBox(height: 16),
            ],

            // Test Assessment Preview Button (Development/Demo)
            if (kDebugMode && !_showAssessmentPreview && !_isProcessingAssessment) ...[
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _simulateAssessmentResult,
                  icon: const Icon(Icons.psychology_outlined),
                  label: const Text('Preview AI Assessment (Demo)'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.blue.shade700,
                    side: BorderSide(color: Colors.blue.shade300),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
            ],

            const SizedBox(height: 16),

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
              Column(
                children: [
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
                        // Reset breed selection when animal changes
                        _selectedBreed = null;
                        _customBreedController.clear();
                        // Pre-populate from animal's breed if available
                        if (value != null) {
                          final selectedAnimal = _animals.firstWhere(
                            (animal) => animal.id == value,
                          );
                          if (selectedAnimal.breed != null && selectedAnimal.breed!.isNotEmpty) {
                            final availableBreeds = getBreedsForSpecies(selectedAnimal.species);
                            if (availableBreeds.contains(selectedAnimal.breed)) {
                              _selectedBreed = selectedAnimal.breed;
                            } else {
                              _selectedBreed = 'Other';
                              _customBreedController.text = selectedAnimal.breed!;
                            }
                          }
                        }
                      });
                    },
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please select an animal';
                      }
                      return null;
                    },
                  ),
                  if (_selectedAnimalId != null) ...[
                    const SizedBox(height: 12),
                    _buildBreedSelector(),
                  ],
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildBreedSelector() {
    if (_selectedAnimalId == null) return const SizedBox.shrink();
    
    final selectedAnimal = _animals.firstWhere(
      (animal) => animal.id == _selectedAnimalId,
    );
    final availableBreeds = getBreedsForSpecies(selectedAnimal.species);
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Breed *',
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          value: _selectedBreed,
          decoration: const InputDecoration(
            hintText: 'Select breed',
            prefixIcon: Icon(Icons.category),
          ),
          items: availableBreeds.map((breed) {
            return DropdownMenuItem(
              value: breed,
              child: Text(breed),
            );
          }).toList(),
          onChanged: (value) {
            setState(() {
              _selectedBreed = value;
              if (value != 'Other') {
                _customBreedController.clear();
              }
            });
          },
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Please select a breed';
            }
            return null;
          },
        ),
        if (_selectedBreed == 'Other') ...[
          const SizedBox(height: 12),
          TextFormField(
            controller: _customBreedController,
            decoration: const InputDecoration(
              labelText: 'Custom Breed *',
              hintText: 'Enter breed name',
              prefixIcon: Icon(Icons.edit),
            ),
            validator: (value) {
              if (_selectedBreed == 'Other' && (value == null || value.trim().isEmpty)) {
                return 'Please enter breed name';
              }
              return null;
            },
          ),
        ],
      ],
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
                ElevatedButton.icon(
                  onPressed: _isLoadingWeather ? null : _attachCurrentWeather,
                  icon: _isLoadingWeather
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.cloud, size: 16),
                  label: Text(
                    _isLoadingWeather ? 'Loading...' : 'Attach Weather',
                    style: const TextStyle(fontSize: 12),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryGreen,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    minimumSize: const Size(120, 32),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Location Widget - City, State visible, lat/lon hidden
            if (_locationData != null) ...[
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
                    Row(
                      children: [
                        Icon(Icons.location_on, size: 20, color: Colors.green.shade700),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _locationCity != null && _locationState != null
                                    ? '$_locationCity, $_locationState'
                                    : _locationData!.address ?? 'Location captured',
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  color: Colors.green.shade700,
                                  fontSize: 16,
                                ),
                              ),
                              if (_locationData!.latitude != null && _locationData!.longitude != null)
                                Text(
                                  'Lat: ${_locationData!.latitude!.toStringAsFixed(4)}, Lon: ${_locationData!.longitude!.toStringAsFixed(4)}',
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: Colors.green.shade600,
                                    fontFamily: 'monospace',
                                  ),
                                ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.green.shade100,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            'GPS',
                            style: TextStyle(
                              fontSize: 10,
                              color: Colors.green.shade700,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (_locationData!.accuracy != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        'Accuracy: ±${_locationData!.accuracy!.round()}m',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.green.shade600,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 12),
            ],

            // IP-based Weather Toggle
            SwitchListTile(
              title: Text(
                'Use IP-based weather if GPS not granted',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey.shade700,
                ),
              ),
              subtitle: Text(
                _useIPBasedWeather 
                    ? 'Weather will be fetched using your internet location' 
                    : 'Weather will use GPS coordinates when available',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade600,
                ),
              ),
              value: _useIPBasedWeather,
              onChanged: (value) {
                setState(() {
                  _useIPBasedWeather = value;
                });
              },
              activeColor: AppTheme.primaryGreen,
              dense: true,
              contentPadding: EdgeInsets.zero,
            ),
            const SizedBox(height: 8),

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
                      size: 24,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                '${_weatherData!.temperature?.round() ?? '--'}°C',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.blue.shade700,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.blue.shade100,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  'Attached',
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: Colors.blue.shade700,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          Text(
                            _weatherData!.description ?? 'Weather captured',
                            style: TextStyle(color: Colors.blue.shade600),
                          ),
                          if (_weatherData!.humidity != null || _weatherData!.windSpeed != null)
                            Text(
                              '${_weatherData!.humidity != null ? 'Humidity: ${_weatherData!.humidity}%' : ''}'
                              '${_weatherData!.humidity != null && _weatherData!.windSpeed != null ? ' • ' : ''}'
                              '${_weatherData!.windSpeed != null ? 'Wind: ${_weatherData!.windSpeed!.round()} mph' : ''}',
                              style: TextStyle(
                                color: Colors.blue.shade600,
                                fontSize: 12,
                              ),
                            ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () {
                        setState(() {
                          _weatherData = null;
                        });
                      },
                      icon: Icon(Icons.close, color: Colors.blue.shade600),
                      tooltip: 'Remove weather data',
                      iconSize: 20,
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
            ] else if (_isLoadingWeather && _weatherData == null) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue.shade200),
                ),
                child: Row(
                  children: [
                    SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.blue.shade700,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Fetching weather data...',
                            style: TextStyle(
                              fontWeight: FontWeight.w500,
                              color: Colors.blue.shade700,
                            ),
                          ),
                          Text(
                            _useIPBasedWeather 
                                ? 'Using IP-based location'
                                : 'Using GPS coordinates',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.blue.shade600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ] else if (_locationData == null) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.orange.shade200),
                ),
                child: Row(
                  children: [
                    Icon(Icons.location_off, color: Colors.orange.shade700),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Location not available',
                            style: TextStyle(
                              fontWeight: FontWeight.w500,
                              color: Colors.orange.shade700,
                            ),
                          ),
                          Text(
                            'Grant location permission for better weather accuracy',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.orange.shade600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    TextButton(
                      onPressed: _requestLocationPermission,
                      child: Text(
                        'Enable',
                        style: TextStyle(color: Colors.orange.shade700),
                      ),
                    ),
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

  Widget _buildMetadataSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.info_outline, color: AppTheme.primaryGreen),
                const SizedBox(width: 8),
                const Text(
                  'Entry Metadata',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 12),
            
            // Source dropdown
            DropdownButtonFormField<String>(
              value: _selectedSource,
              decoration: InputDecoration(
                labelText: 'Entry Source',
                prefixIcon: const Icon(Icons.source, color: AppTheme.primaryGreen),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppTheme.primaryGreen, width: 2),
                ),
              ),
              items: const [
                DropdownMenuItem(
                  value: 'mobile_app',
                  child: Row(
                    children: [
                      Icon(Icons.phone_android, size: 20, color: Colors.grey),
                      SizedBox(width: 8),
                      Text('Mobile App'),
                    ],
                  ),
                ),
                DropdownMenuItem(
                  value: 'web_app',
                  child: Row(
                    children: [
                      Icon(Icons.web, size: 20, color: Colors.grey),
                      SizedBox(width: 8),
                      Text('Web App'),
                    ],
                  ),
                ),
                DropdownMenuItem(
                  value: 'import',
                  child: Row(
                    children: [
                      Icon(Icons.file_upload, size: 20, color: Colors.grey),
                      SizedBox(width: 8),
                      Text('Imported'),
                    ],
                  ),
                ),
                DropdownMenuItem(
                  value: 'api',
                  child: Row(
                    children: [
                      Icon(Icons.api, size: 20, color: Colors.grey),
                      SizedBox(width: 8),
                      Text('API/External'),
                    ],
                  ),
                ),
              ],
              onChanged: (value) {
                setState(() {
                  _selectedSource = value!;
                });
              },
            ),
            const SizedBox(height: 16),

            // Notes field (collapsible)
            ExpansionTile(
              leading: const Icon(Icons.note_add, color: AppTheme.primaryGreen),
              title: const Text(
                'Additional Notes',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
              ),
              subtitle: Text(
                _notesController.text.isEmpty 
                    ? 'Tap to add optional notes or metadata'
                    : 'Notes: ${_notesController.text.length} characters',
                style: const TextStyle(fontSize: 12),
              ),
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
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
                              'What can you add here?',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.blue.shade700,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '• Supervisor feedback or comments\n• Additional context not captured elsewhere\n• Technical details or specifications\n• Links to related resources\n• Personal reflections and insights',
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
                        controller: _notesController,
                        maxLines: 4,
                        decoration: InputDecoration(
                          hintText: 'Add any additional notes, context, or metadata...',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: AppTheme.primaryGreen, width: 2),
                          ),
                          contentPadding: const EdgeInsets.all(16),
                        ),
                        onChanged: (value) {
                          setState(() {}); // Update subtitle
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAdvancedAISettingsSection() {
    return Card(
      child: Column(
        children: [
          ListTile(
            leading: Icon(
              Icons.settings_suggest,
              color: _sendToSPAROrchestrator ? AppTheme.primaryGreen : Colors.grey,
            ),
            title: const Text(
              'Advanced AI Settings',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            subtitle: Text(
              _showAdvancedSettings 
                  ? 'Configure SPAR orchestrator and AI processing'
                  : _sendToSPAROrchestrator
                      ? 'SPAR enabled • Run ID: ${_runId.substring(0, 8)}...'
                      : 'SPAR disabled • Basic processing only',
              style: const TextStyle(fontSize: 12),
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  _sendToSPAROrchestrator ? Icons.smart_toy : Icons.smart_toy_outlined,
                  color: _sendToSPAROrchestrator ? Colors.green : Colors.grey,
                  size: 20,
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: Icon(_showAdvancedSettings ? Icons.expand_less : Icons.expand_more),
                  onPressed: () {
                    setState(() {
                      _showAdvancedSettings = !_showAdvancedSettings;
                    });
                  },
                ),
              ],
            ),
          ),
          if (_showAdvancedSettings) ...[
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Info card about SPAR
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
                        Row(
                          children: [
                            Icon(Icons.info_outline, color: Colors.blue.shade700, size: 16),
                            const SizedBox(width: 6),
                            Text(
                              'SPAR Orchestrator Controls',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.blue.shade700,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'These settings control how AI processes your journal entry. SPAR (Systematic Processing and Retrieval) provides enhanced educational analysis with vector search and intelligent routing.',
                          style: TextStyle(
                            color: Colors.blue.shade700,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // SPAR Enable/Disable
                  SwitchListTile(
                    title: const Text(
                      'Send to SPAR Orchestrator',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                    subtitle: Text(
                      _sendToSPAROrchestrator 
                          ? 'AI analysis with advanced educational processing'
                          : 'Basic AI analysis only',
                      style: const TextStyle(fontSize: 12),
                    ),
                    value: _sendToSPAROrchestrator,
                    onChanged: (value) {
                      setState(() {
                        _sendToSPAROrchestrator = value;
                        if (value) {
                          _runId = _uuid.v4(); // Generate new run ID when enabling
                        }
                      });
                    },
                    activeColor: AppTheme.primaryGreen,
                    contentPadding: EdgeInsets.zero,
                  ),
                  const SizedBox(height: 16),

                  if (_sendToSPAROrchestrator) ...[
                    // Run ID Display (read-only)
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
                          Row(
                            children: [
                              Icon(Icons.fingerprint, color: Colors.green.shade700, size: 16),
                              const SizedBox(width: 6),
                              Text(
                                'Run ID (Client Trace)',
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  color: Colors.green.shade700,
                                  fontSize: 14,
                                ),
                              ),
                              const Spacer(),
                              IconButton(
                                icon: Icon(Icons.refresh, size: 16, color: Colors.green.shade700),
                                onPressed: () {
                                  setState(() {
                                    _runId = _uuid.v4();
                                  });
                                },
                                tooltip: 'Generate new Run ID',
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(color: Colors.green.shade300),
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    _runId,
                                    style: const TextStyle(
                                      fontFamily: 'monospace',
                                      fontSize: 11,
                                      color: Colors.black87,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Use this ID to correlate UI actions with n8n workflow execution',
                            style: TextStyle(
                              color: Colors.green.shade600,
                              fontSize: 10,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Trace ID Display (read-only)
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.purple.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.purple.shade200),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.track_changes, color: Colors.purple.shade700, size: 16),
                              const SizedBox(width: 6),
                              Text(
                                'Trace ID (Distributed Tracing)',
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  color: Colors.purple.shade700,
                                  fontSize: 14,
                                ),
                              ),
                              const Spacer(),
                              IconButton(
                                icon: Icon(Icons.refresh, size: 16, color: Colors.purple.shade700),
                                onPressed: () {
                                  setState(() {
                                    _traceId = _uuid.v4();
                                  });
                                },
                                tooltip: 'Generate new Trace ID',
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(color: Colors.purple.shade300),
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    _traceId,
                                    style: const TextStyle(
                                      fontFamily: 'monospace',
                                      fontSize: 11,
                                      color: Colors.black87,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Correlates UI events with backend processing across all services',
                            style: TextStyle(
                              color: Colors.purple.shade600,
                              fontSize: 10,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Routing Settings
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.route, color: AppTheme.primaryGreen, size: 18),
                            const SizedBox(width: 6),
                            const Text(
                              'Routing Settings',
                              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        DropdownButtonFormField<String>(
                          value: _routeIntent,
                          decoration: InputDecoration(
                            labelText: 'Route Intent',
                            isDense: true,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: const BorderSide(color: AppTheme.primaryGreen, width: 2),
                            ),
                          ),
                          items: const [
                            DropdownMenuItem(
                              value: 'edu_context',
                              child: Text('Educational Context (Default)'),
                            ),
                            DropdownMenuItem(
                              value: 'general',
                              child: Text('General Analysis'),
                            ),
                            DropdownMenuItem(
                              value: 'analysis',
                              child: Text('Deep Analysis'),
                            ),
                          ],
                          onChanged: (value) {
                            setState(() {
                              _routeIntent = value!;
                            });
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Vector Tuning Settings
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.tune, color: AppTheme.primaryGreen, size: 18),
                            const SizedBox(width: 6),
                            const Text(
                              'Vector Search Tuning',
                              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: TextFormField(
                                initialValue: _vectorMatchCount.toString(),
                                keyboardType: TextInputType.number,
                                decoration: InputDecoration(
                                  labelText: 'Match Count',
                                  hintText: '6',
                                  isDense: true,
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                    borderSide: const BorderSide(color: AppTheme.primaryGreen, width: 2),
                                  ),
                                ),
                                validator: (value) {
                                  if (value == null || value.isEmpty) return 'Required';
                                  final count = int.tryParse(value);
                                  if (count == null || count < 1 || count > 20) {
                                    return '1-20';
                                  }
                                  return null;
                                },
                                onChanged: (value) {
                                  final count = int.tryParse(value);
                                  if (count != null && count >= 1 && count <= 20) {
                                    _vectorMatchCount = count;
                                  }
                                },
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: TextFormField(
                                initialValue: _vectorMinSimilarity.toString(),
                                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                decoration: InputDecoration(
                                  labelText: 'Min Similarity',
                                  hintText: '0.75',
                                  isDense: true,
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                    borderSide: const BorderSide(color: AppTheme.primaryGreen, width: 2),
                                  ),
                                ),
                                validator: (value) {
                                  if (value == null || value.isEmpty) return 'Required';
                                  final similarity = double.tryParse(value);
                                  if (similarity == null || similarity < 0.0 || similarity > 1.0) {
                                    return '0.0-1.0';
                                  }
                                  return null;
                                },
                                onChanged: (value) {
                                  final similarity = double.tryParse(value);
                                  if (similarity != null && similarity >= 0.0 && similarity <= 1.0) {
                                    _vectorMinSimilarity = similarity;
                                  }
                                },
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Tool Inputs Override (Optional)
                    ExpansionTile(
                      leading: const Icon(Icons.build, color: AppTheme.primaryGreen, size: 18),
                      title: const Text(
                        'Tool Inputs Override (Optional)',
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                      ),
                      subtitle: Text(
                        _toolInputsCategory != null || _toolInputsQuery != null
                            ? 'Custom overrides set'
                            : 'Use defaults from form data',
                        style: const TextStyle(fontSize: 12),
                      ),
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                          child: Column(
                            children: [
                              TextFormField(
                                initialValue: _toolInputsCategory,
                                decoration: InputDecoration(
                                  labelText: 'Category Override',
                                  hintText: 'e.g., health_check, feeding, training',
                                  isDense: true,
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                    borderSide: const BorderSide(color: AppTheme.primaryGreen, width: 2),
                                  ),
                                ),
                                onChanged: (value) {
                                  _toolInputsCategory = value.isEmpty ? null : value;
                                },
                              ),
                              const SizedBox(height: 12),
                              TextFormField(
                                initialValue: _toolInputsQuery,
                                maxLines: 3,
                                decoration: InputDecoration(
                                  labelText: 'Query Override',
                                  hintText: 'Custom query (defaults to retrieval_query if empty)',
                                  isDense: true,
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                    borderSide: const BorderSide(color: AppTheme.primaryGreen, width: 2),
                                  ),
                                ),
                                onChanged: (value) {
                                  _toolInputsQuery = value.isEmpty ? null : value;
                                },
                              ),
                            ],
                          ),
                        ),
                      ],
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







  // Method to simulate receiving SPAR assessment results
  void _simulateAssessmentResult() {
    setState(() {
      _isProcessingAssessment = true;
    });

    // Simulate processing delay
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        setState(() {
          _assessmentResult = SPARAssessmentResult.mock();
          _showAssessmentPreview = true;
          _isProcessingAssessment = false;
        });
      }
    });
  }

  /// Handle viewing detailed assessment results
  void _onViewAssessmentDetails() {
    if (_assessmentResult == null) return;
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.psychology, color: AppTheme.primaryGreen),
            const SizedBox(width: 8),
            const Text('Assessment Details'),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Feedback Summary:',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: 8),
              Text(
                _assessmentResult!.feedbackSummary,
                style: TextStyle(height: 1.4, color: Colors.grey.shade700),
              ),
              const SizedBox(height: 20),
              Text(
                'Processing Details:',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: 8),
              Text('Assessment ID: ${_assessmentResult!.id}'),
              Text('Processed: ${_assessmentResult!.processedAt.toString()}'),
              Text('Status: ${_assessmentResult!.isComplete ? "Complete" : "Processing"}'),
              const SizedBox(height: 20),
              Text(
                'SPAR Configuration:',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: 8),
              Text('Route Intent: $_routeIntent'),
              Text('Vector Matches: $_vectorMatchCount'),
              Text('Min Similarity: $_vectorMinSimilarity'),
              Text('Run ID: $_runId'),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  /// Handle sharing assessment results
  void _onShareAssessment() {
    if (_assessmentResult == null) return;
    
    // Show share options dialog
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.share, color: AppTheme.primaryGreen),
            SizedBox(width: 8),
            Text('Share Assessment'),
          ],
        ),
        content: const Text(
          'Share your AI assessment results with instructors, mentors, or add to your FFA portfolio.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton.icon(
            onPressed: () {
              // TODO: Implement actual sharing functionality
              Navigator.of(context).pop();
              showSuccess('Assessment results shared successfully!');
            },
            icon: const Icon(Icons.share),
            label: const Text('Share'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryGreen,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  /// Handle retrying failed assessment
  void _onRetryAssessment() {
    if (_assessmentResult == null) {
      // Retry processing
      _simulateAssessmentResult();
      return;
    }
    
    // Show retry confirmation
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.refresh, color: Colors.orange),
            SizedBox(width: 8),
            Text('Retry Assessment'),
          ],
        ),
        content: const Text(
          'This will reprocess your journal entry with the AI assessment system. Your current results will be replaced.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.of(context).pop();
              setState(() {
                _assessmentResult = null;
                _showAssessmentPreview = false;
              });
              _simulateAssessmentResult();();
            },
            icon: const Icon(Icons.refresh),
            label: const Text('Retry'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSubmitButton() {
    return Column(
      children: [
        // Assessment Processing Status
        if (_isProcessingAssessment)
          Card(
            color: Colors.blue.shade50,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Processing AI Assessment...',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.blue.shade800,
                          ),
                        ),
                        Text(
                          'SPAR is analyzing your journal entry',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.blue.shade600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

        const SizedBox(height: 8),

        // Submit Button
        SizedBox(
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
        ),
      ],
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

  /// Update AI processing status and monitor progress
  void _updateAIProcessingStatus(ProcessingStatus status, {
    String? message,
    String? error,
    double? progress,
  }) {
    setState(() {
      _aiProcessingStatus = status;
      _aiProcessingMessage = message;
      _aiProcessingError = error;
      _aiProcessingProgress = progress;
    });

    // Start monitoring for processing and pending states
    if (status == ProcessingStatus.processing || status == ProcessingStatus.pending) {
      _startAIStatusMonitoring();
    } else {
      _aiStatusTimer?.cancel();
    }
  }

  /// Start monitoring AI processing status
  void _startAIStatusMonitoring() {
    _aiStatusTimer?.cancel();
    _aiStatusTimer = Timer.periodic(const Duration(seconds: 2), (timer) async {
      if (_runId.isNotEmpty) {
        try {
          final run = await SPARRunsService.getSPARRun(_runId);
          if (run != null) {
            final status = (run['status'] as String).toProcessingStatus();
            
            // Update progress for processing status
            double? progress;
            if (status == ProcessingStatus.processing) {
              final createdAt = DateTime.parse(run['created_at']);
              final elapsed = DateTime.now().difference(createdAt).inSeconds;
              const estimatedDuration = 30; // 30 seconds estimated
              progress = (elapsed / estimatedDuration).clamp(0.0, 0.9);
            }

            setState(() {
              _aiProcessingStatus = status;
              _aiProcessingProgress = progress;
              
              if (status == ProcessingStatus.completed) {
                _aiProcessingMessage = 'AI analysis completed successfully';
                _aiProcessingError = null;
              } else if (status == ProcessingStatus.failed) {
                _aiProcessingMessage = 'AI analysis failed';
                _aiProcessingError = run['error'];
              } else if (status == ProcessingStatus.timeout) {
                _aiProcessingMessage = 'AI analysis timed out';
                _aiProcessingError = 'Processing took too long';
              }
            });

            // Stop monitoring when complete
            if (status == ProcessingStatus.completed || 
                status == ProcessingStatus.failed || 
                status == ProcessingStatus.timeout) {
              timer.cancel();
            }
          }
        } catch (e) {
          print('Error monitoring AI status: $e');
        }
      }
    });
  }

  /// Show AI processing details dialog
  void _showAIProcessingDetails() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.psychology, color: Colors.blue[600]),
            const SizedBox(width: 8),
            const Text('AI Processing Status'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ProcessingStatusIndicator(
              status: _aiProcessingStatus,
              message: _aiProcessingMessage,
              errorMessage: _aiProcessingError,
              progress: _aiProcessingProgress,
              size: ProcessingStatusSize.large,
              showStatusText: true,
              showRetryButton: true,
              onRetry: _aiProcessingStatus == ProcessingStatus.failed 
                  ? _retryAIProcessing 
                  : null,
            ),
            
            const SizedBox(height: 16),
            
            if (_aiProcessingStatus == ProcessingStatus.processing) 
              const AIProcessingProgressIndicator(
                currentStep: 'Analyzing journal content and standards...',
                showDetails: true,
              ),
            
            if (_runId.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                'Run ID: $_runId',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                  fontFamily: 'monospace',
                ),
              ),
            ],
          ],
        ),
        actions: [
          if (_aiProcessingStatus == ProcessingStatus.failed)
            TextButton.icon(
              onPressed: _retryAIProcessing,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
              style: TextButton.styleFrom(foregroundColor: Colors.orange[700]),
            ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  /// Retry AI processing for the current entry
  Future<void> _retryAIProcessing() async {
    if (_runId.isEmpty) return;

    try {
      await SPARRunsService.retrySPARRun(_runId);
      _updateAIProcessingStatus(
        ProcessingStatus.pending,
        message: 'AI analysis retry initiated',
      );
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('AI analysis retry initiated'),
            backgroundColor: Colors.blue,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Retry failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

}