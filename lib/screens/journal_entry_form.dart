import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/journal_entry.dart';
import '../services/journal_service.dart';
import '../theme/app_theme.dart';
import '../widgets/feed_data_input.dart';
import '../widgets/aet_skills_selector.dart';
import '../widgets/location_input_field.dart';

class JournalEntryForm extends StatefulWidget {
  const JournalEntryForm({Key? key}) : super(key: key);

  @override
  State<JournalEntryForm> createState() => _JournalEntryFormState();
}

class _JournalEntryFormState extends State<JournalEntryForm> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _durationController = TextEditingController();
  final _objectivesController = TextEditingController();
  final _outcomesController = TextEditingController();
  final _challengesController = TextEditingController();
  final _improvementsController = TextEditingController();
  
  DateTime _selectedDate = DateTime.now();
  String _selectedCategory = 'general';
  List<String> _selectedAETSkills = [];
  FeedData? _feedData;
  LocationData? _locationData;
  WeatherData? _weatherData;
  bool _isSubmitting = false;

  final List<String> _categories = [
    'feeding',
    'health',
    'training',
    'breeding',
    'showing',
    'general'
  ];

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _durationController.dispose();
    _objectivesController.dispose();
    _outcomesController.dispose();
    _challengesController.dispose();
    _improvementsController.dispose();
    super.dispose();
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  Future<void> _submitJournal() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSubmitting = true);

    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) {
        throw Exception('User not authenticated');
      }

      final entry = JournalEntry(
        userId: user.id,
        title: _titleController.text,
        description: _descriptionController.text,
        date: _selectedDate,
        duration: int.parse(_durationController.text),
        category: _selectedCategory,
        aetSkills: _selectedAETSkills,
        feedData: _feedData,
        location: _locationData,
        weather: _weatherData,
        objectives: _objectivesController.text.isNotEmpty
            ? _objectivesController.text.split('\n')
            : null,
        learningOutcomes: _outcomesController.text.isNotEmpty
            ? _outcomesController.text.split('\n')
            : null,
        challenges: _challengesController.text.isNotEmpty
            ? _challengesController.text
            : null,
        improvements: _improvementsController.text.isNotEmpty
            ? _improvementsController.text
            : null,
      );

      await JournalService.createEntry(entry);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Journal entry created successfully!'),
            backgroundColor: AppTheme.secondaryGreen,
          ),
        );
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('New Journal Entry'),
        actions: [
          IconButton(
            icon: const Icon(Icons.help_outline),
            onPressed: () => _showHelpDialog(context),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Title Field
            TextFormField(
              controller: _titleController,
              decoration: const InputDecoration(
                labelText: 'Title *',
                hintText: 'Enter a descriptive title',
                prefixIcon: Icon(Icons.title),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter a title';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),

            // Date and Duration Row
            Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: () => _selectDate(context),
                    child: InputDecorator(
                      decoration: const InputDecoration(
                        labelText: 'Date *',
                        prefixIcon: Icon(Icons.calendar_today),
                      ),
                      child: Text(
                        '${_selectedDate.month}/${_selectedDate.day}/${_selectedDate.year}',
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: TextFormField(
                    controller: _durationController,
                    decoration: const InputDecoration(
                      labelText: 'Duration (minutes) *',
                      prefixIcon: Icon(Icons.timer),
                    ),
                    keyboardType: TextInputType.number,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Required';
                      }
                      if (int.tryParse(value) == null || int.parse(value) < 1) {
                        return 'Invalid';
                      }
                      return null;
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Category Dropdown
            DropdownButtonFormField<String>(
              value: _selectedCategory,
              decoration: const InputDecoration(
                labelText: 'Category *',
                prefixIcon: Icon(Icons.category),
              ),
              items: _categories.map((category) {
                return DropdownMenuItem(
                  value: category,
                  child: Text(category[0].toUpperCase() + category.substring(1)),
                );
              }).toList(),
              onChanged: (value) {
                setState(() {
                  _selectedCategory = value!;
                });
              },
            ),
            const SizedBox(height: 16),

            // Description Field
            TextFormField(
              controller: _descriptionController,
              decoration: const InputDecoration(
                labelText: 'Description *',
                hintText: 'Describe your activities in detail (minimum 50 words)',
                prefixIcon: Icon(Icons.description),
                alignLabelWithHint: true,
              ),
              maxLines: 5,
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter a description';
                }
                if (value.split(' ').length < 50) {
                  return 'Description must be at least 50 words';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),

            // AET Skills Selector
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'AET Skills *',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    AETSkillsSelector(
                      selectedSkills: _selectedAETSkills,
                      onChanged: (skills) {
                        setState(() {
                          _selectedAETSkills = skills;
                        });
                      },
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Location and Weather Input
            LocationInputField(
              onLocationChanged: (location, weather) {
                setState(() {
                  _locationData = location;
                  _weatherData = weather;
                });
              },
              initialLocation: _locationData,
              initialWeather: _weatherData,
            ),
            const SizedBox(height: 16),

            // Feed Data Input (optional)
            if (_selectedCategory == 'feeding')
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Feed Information',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      FeedDataInput(
                        onChanged: (feedData) {
                          setState(() {
                            _feedData = feedData;
                          });
                        },
                      ),
                    ],
                  ),
                ),
              ),
            const SizedBox(height: 16),

            // Learning Objectives (optional)
            TextFormField(
              controller: _objectivesController,
              decoration: const InputDecoration(
                labelText: 'Learning Objectives',
                hintText: 'Enter each objective on a new line',
                prefixIcon: Icon(Icons.flag),
                alignLabelWithHint: true,
              ),
              maxLines: 3,
            ),
            const SizedBox(height: 16),

            // Learning Outcomes (optional)
            TextFormField(
              controller: _outcomesController,
              decoration: const InputDecoration(
                labelText: 'Learning Outcomes',
                hintText: 'What did you learn? (one per line)',
                prefixIcon: Icon(Icons.school),
                alignLabelWithHint: true,
              ),
              maxLines: 3,
            ),
            const SizedBox(height: 16),

            // Challenges Faced (optional)
            TextFormField(
              controller: _challengesController,
              decoration: const InputDecoration(
                labelText: 'Challenges Faced',
                hintText: 'Describe any challenges you encountered',
                prefixIcon: Icon(Icons.warning),
                alignLabelWithHint: true,
              ),
              maxLines: 2,
            ),
            const SizedBox(height: 16),

            // Improvements Planned (optional)
            TextFormField(
              controller: _improvementsController,
              decoration: const InputDecoration(
                labelText: 'Improvements Planned',
                hintText: 'What will you do differently next time?',
                prefixIcon: Icon(Icons.trending_up),
                alignLabelWithHint: true,
              ),
              maxLines: 2,
            ),
            const SizedBox(height: 24),

            // Submit Button
            ElevatedButton(
              onPressed: _isSubmitting ? null : _submitJournal,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: _isSubmitting
                  ? const CircularProgressIndicator(color: Colors.white)
                  : const Text(
                      'Submit Journal Entry',
                      style: TextStyle(fontSize: 16),
                    ),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  void _showHelpDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Journal Entry Tips'),
        content: const SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('• Be detailed in your descriptions'),
              SizedBox(height: 8),
              Text('• Include specific measurements and observations'),
              SizedBox(height: 8),
              Text('• Select all relevant AET skills demonstrated'),
              SizedBox(height: 8),
              Text('• Document challenges to show problem-solving'),
              SizedBox(height: 8),
              Text('• Set clear learning objectives'),
              SizedBox(height: 8),
              Text('• AI will analyze your entry for quality and provide feedback'),
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
}