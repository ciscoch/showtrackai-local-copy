import 'package:flutter/material.dart';
import '../services/journal_content_templates.dart';
import '../widgets/ai_assisted_text_field.dart';
import '../widgets/journal_suggestion_panel.dart';
import '../theme/app_theme.dart';

/// Example implementation showing how to integrate all SHO-9 AI assistance features
/// This demonstrates the complete user experience for journal entry auto-population
class JournalAIAssistanceExample extends StatefulWidget {
  const JournalAIAssistanceExample({Key? key}) : super(key: key);

  @override
  State<JournalAIAssistanceExample> createState() => _JournalAIAssistanceExampleState();
}

class _JournalAIAssistanceExampleState extends State<JournalAIAssistanceExample> {
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _durationController = TextEditingController();
  
  String _selectedCategory = 'feeding';
  List<String> _selectedAETSkills = [];
  List<String> _suggestedTags = [];
  bool _showSuggestionPanel = false;
  
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
    super.dispose();
  }

  void _updateAETSkills(List<String> skills) {
    setState(() {
      // Merge suggested skills with existing ones, avoiding duplicates
      final newSkills = [..._selectedAETSkills];
      for (final skill in skills) {
        if (!newSkills.contains(skill)) {
          newSkills.add(skill);
        }
      }
      _selectedAETSkills = newSkills;
    });
    
    _showSnackbar('Added ${skills.length} AET skills', AppTheme.primaryGreen);
  }

  void _updateDuration(int minutes) {
    setState(() {
      _durationController.text = minutes.toString();
    });
    
    _showSnackbar('Duration set to $minutes minutes', AppTheme.accentBlue);
  }

  void _updateTags(List<String> tags) {
    setState(() {
      _suggestedTags = tags;
    });
    
    _showSnackbar('Added ${tags.length} tags', AppTheme.accentOrange);
  }

  void _applySuggestion(ContentSuggestion suggestion) {
    final currentText = _descriptionController.text;
    final newText = currentText.isNotEmpty
        ? '$currentText\n\n${suggestion.content}'
        : suggestion.content;
    
    setState(() {
      _descriptionController.text = newText;
    });
    
    _showSnackbar('Applied: ${suggestion.title}', AppTheme.primaryGreen);
  }

  void _showSnackbar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _onCategoryChanged(String category) {
    setState(() {
      _selectedCategory = category;
    });
    
    // Demonstrate auto-population on category change
    final templateService = JournalContentTemplateService();
    
    // Auto-suggest duration
    final suggestedDuration = templateService.getSuggestedDurationForCategory(category);
    if (_durationController.text.isEmpty) {
      _updateDuration(suggestedDuration);
    }
    
    // Auto-suggest AET skills
    final suggestedSkills = templateService.getSuggestedAETSkillsForCategory(category);
    if (_selectedAETSkills.isEmpty && suggestedSkills.isNotEmpty) {
      _updateAETSkills(suggestedSkills.take(3).toList());
    }
    
    // Show category-specific tips
    _showCategoryTips(category);
  }

  void _showCategoryTips(String category) {
    final tips = _getCategoryTips(category);
    if (tips.isNotEmpty) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Text('${category.toUpperCase()} Tips'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: tips.map((tip) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.lightbulb_outline, size: 16, color: AppTheme.primaryGreen),
                  const SizedBox(width: 8),
                  Expanded(child: Text(tip, style: const TextStyle(fontSize: 14))),
                ],
              ),
            )).toList(),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Got it'),
            ),
          ],
        ),
      );
    }
  }

  List<String> _getCategoryTips(String category) {
    switch (category) {
      case 'feeding':
        return [
          'Include feed amounts and types',
          'Note animal appetite and behavior',
          'Record feed costs for economic analysis',
          'Mention feed conversion ratios',
        ];
      case 'health':
        return [
          'Record vital signs (temperature, pulse)',
          'Document any symptoms observed',
          'Note treatments or medications given',
          'Include veterinary consultation details',
        ];
      case 'training':
        return [
          'Describe training techniques used',
          'Note animal responses and progress',
          'Record time spent on each activity',
          'Document behavioral improvements',
        ];
      default:
        return [];
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('AI-Assisted Journal Entry'),
        backgroundColor: AppTheme.primaryGreen,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.help_outline),
            onPressed: _showFeatureHelp,
          ),
        ],
      ),
      body: Form(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Feature Overview Card
            Card(
              color: AppTheme.lightGreen,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.auto_awesome, color: AppTheme.primaryGreen),
                        const SizedBox(width: 8),
                        Text(
                          'AI Writing Assistant',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.darkGreen,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'This example demonstrates three levels of AI assistance:\n'
                      '• Quick Fill: Instant templates\n'
                      '• Smart Suggest: Context-aware help\n'
                      '• AI Generate: Full content creation',
                      style: TextStyle(color: AppTheme.textSecondary),
                    ),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 24),
            
            // Title Field
            TextFormField(
              controller: _titleController,
              decoration: const InputDecoration(
                labelText: 'Entry Title',
                hintText: 'e.g., Daily Cattle Feeding Session',
                prefixIcon: Icon(Icons.title),
              ),
            ),
            
            const SizedBox(height: 16),
            
            // Category Selection with Auto-Population Demo
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Category Selection Demo',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Watch how duration and skills auto-populate when you change categories',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      value: _selectedCategory,
                      decoration: const InputDecoration(
                        labelText: 'Activity Category',
                        prefixIcon: Icon(Icons.category),
                      ),
                      items: _categories.map((category) {
                        return DropdownMenuItem(
                          value: category,
                          child: Text(category[0].toUpperCase() + category.substring(1)),
                        );
                      }).toList(),
                      onChanged: (value) => _onCategoryChanged(value!),
                    ),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 16),
            
            // Duration Field (Auto-populated)
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _durationController,
                    decoration: InputDecoration(
                      labelText: 'Duration (minutes)',
                      prefixIcon: const Icon(Icons.timer),
                      helperText: 'Auto-suggested based on category',
                      helperStyle: TextStyle(color: AppTheme.primaryGreen, fontSize: 11),
                    ),
                    keyboardType: TextInputType.number,
                  ),
                ),
                const SizedBox(width: 16),
                ElevatedButton.icon(
                  onPressed: () => _showAETSkillsDemo(),
                  icon: const Icon(Icons.school),
                  label: Text('Skills (${_selectedAETSkills.length})'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.accentBlue,
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 24),
            
            // AI-Assisted Description Field
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'AI-Assisted Writing',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Start typing to see real-time suggestions, or click "AI Generate" for full content.',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 16),
                    AIAssistedTextField(
                      controller: _descriptionController,
                      labelText: 'Activity Description',
                      hintText: 'Describe your agricultural activity in detail...',
                      maxLines: 6,
                      category: _selectedCategory,
                      animalType: 'cattle', // Could be dynamic
                      context: {
                        'selectedCategory': _selectedCategory,
                        'duration': _durationController.text,
                        'existingSkills': _selectedAETSkills,
                        'weather': 'sunny',
                        'temperature': 75,
                      },
                      onAETSkillsGenerated: _updateAETSkills,
                      onDurationSuggested: _updateDuration,
                      onTagsGenerated: _updateTags,
                    ),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 16),
            
            // Writing Assistant Toggle
            Row(
              children: [
                ElevatedButton.icon(
                  onPressed: () {
                    setState(() {
                      _showSuggestionPanel = !_showSuggestionPanel;
                    });
                  },
                  icon: Icon(
                    _showSuggestionPanel ? Icons.close : Icons.auto_fix_high,
                  ),
                  label: Text(
                    _showSuggestionPanel ? 'Hide Assistant' : 'Writing Assistant',
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _showSuggestionPanel
                        ? Colors.grey[600]
                        : AppTheme.primaryGreen,
                    foregroundColor: Colors.white,
                  ),
                ),
                const SizedBox(width: 12),
                OutlinedButton.icon(
                  onPressed: _demonstrateFeatures,
                  icon: const Icon(Icons.play_circle_outline),
                  label: const Text('Demo Mode'),
                ),
              ],
            ),
            
            const SizedBox(height: 16),
            
            // Suggested Tags Display
            if (_suggestedTags.isNotEmpty) ...[
              Card(
                color: AppTheme.lightGreen.withOpacity(0.5),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Suggested Tags',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: AppTheme.darkGreen,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: _suggestedTags.map((tag) {
                          return Chip(
                            label: Text(tag),
                            backgroundColor: AppTheme.primaryGreen.withOpacity(0.1),
                            labelStyle: TextStyle(
                              color: AppTheme.darkGreen,
                              fontSize: 12,
                            ),
                            deleteIcon: const Icon(Icons.add, size: 16),
                            onDeleted: () => _addTag(tag),
                          );
                        }).toList(),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],
            
            // Performance Stats
            _buildPerformanceStats(),
            
            const SizedBox(height: 100), // Space for bottom sheet
          ],
        ),
      ),
      
      // AI Suggestion Panel as Bottom Sheet
      bottomSheet: _showSuggestionPanel
          ? JournalSuggestionPanel(
              category: _selectedCategory,
              currentText: _descriptionController.text,
              animalType: 'cattle',
              context: {
                'selectedCategory': _selectedCategory,
                'duration': _durationController.text,
                'existingSkills': _selectedAETSkills,
                'suggestedTags': _suggestedTags,
              },
              onSuggestionSelected: _applySuggestion,
              onAETSkillsUpdated: _updateAETSkills,
              onDurationUpdated: _updateDuration,
              onTagsUpdated: _updateTags,
              onClose: () => setState(() => _showSuggestionPanel = false),
            )
          : null,
    );
  }

  Widget _buildPerformanceStats() {
    return Card(
      color: Colors.blue[50],
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.analytics, color: Colors.blue[700]),
                const SizedBox(width: 8),
                Text(
                  'Performance Metrics',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue[700],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildMetric('Words', '${_descriptionController.text.split(' ').length}'),
                ),
                Expanded(
                  child: _buildMetric('Skills', '${_selectedAETSkills.length}'),
                ),
                Expanded(
                  child: _buildMetric('Tags', '${_suggestedTags.length}'),
                ),
                Expanded(
                  child: _buildMetric('Duration', '${_durationController.text}m'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetric(String label, String value) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.blue[700],
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.blue[600],
          ),
        ),
      ],
    );
  }

  void _showAETSkillsDemo() {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Auto-Selected AET Skills',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: AppTheme.primaryGreen,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            if (_selectedAETSkills.isEmpty)
              Text(
                'Select a category to see auto-suggested skills',
                style: TextStyle(color: AppTheme.textSecondary),
              )
            else
              ...(_selectedAETSkills.map((skill) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    Icon(Icons.check_circle, color: AppTheme.primaryGreen, size: 20),
                    const SizedBox(width: 12),
                    Expanded(child: Text(skill)),
                  ],
                ),
              ))),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Close'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _addTag(String tag) {
    _showSnackbar('Tag "$tag" would be added to entry', AppTheme.primaryGreen);
  }

  void _demonstrateFeatures() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Demo Mode'),
        content: const Text(
          'This would start an interactive demo showing:\n\n'
          '1. Category auto-population\n'
          '2. Real-time suggestions\n'
          '3. AI content generation\n'
          '4. Progressive enhancement\n\n'
          'Try selecting different categories and typing in the description field!',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Start Demo'),
          ),
        ],
      ),
    );
  }

  void _showFeatureHelp() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('AI Assistance Features'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildFeatureItem(
                Icons.flash_on,
                'Quick Fill',
                'Instant templates based on activity category',
                AppTheme.accentOrange,
              ),
              const SizedBox(height: 16),
              _buildFeatureItem(
                Icons.psychology,
                'Smart Suggest',
                'Context-aware suggestions as you type',
                AppTheme.accentBlue,
              ),
              const SizedBox(height: 16),
              _buildFeatureItem(
                Icons.auto_awesome,
                'AI Generate',
                'Full AI-powered content creation',
                AppTheme.primaryGreen,
              ),
              const SizedBox(height: 16),
              _buildFeatureItem(
                Icons.offline_bolt,
                'Offline Ready',
                'Templates work without internet connection',
                Colors.grey[600]!,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Got it'),
          ),
        ],
      ),
    );
  }

  Widget _buildFeatureItem(IconData icon, String title, String description, Color color) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: color, size: 24),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: color,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                description,
                style: TextStyle(
                  fontSize: 12,
                  color: AppTheme.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}