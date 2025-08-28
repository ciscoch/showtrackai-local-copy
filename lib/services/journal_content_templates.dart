import 'dart:async';
import 'dart:convert';
import '../models/journal_entry.dart';

/// Service for managing journal content templates and context-aware suggestions
/// Provides quick-fill, smart suggestions, and AI-powered content generation
class JournalContentTemplateService {
  static final JournalContentTemplateService _instance = 
      JournalContentTemplateService._internal();
  factory JournalContentTemplateService() => _instance;
  JournalContentTemplateService._internal();

  // Template library for common agricultural activities
  static const Map<String, List<JournalTemplate>> _templates = {
    'feeding': [
      JournalTemplate(
        id: 'daily_feeding',
        title: 'Daily Feeding Session',
        category: 'feeding',
        descriptionTemplate: 'Fed {animal_type} with {feed_amount} lbs of {feed_type}. Animal showed {appetite_level} appetite. Observed {animal_condition} body condition. Water intake appears {water_intake_level}. No behavioral abnormalities noted during feeding.',
        suggestedAETSkills: ['Animal Health Management', 'Feeding and Nutrition', 'Record Keeping'],
        duration: 30,
        tags: ['daily_care', 'nutrition', 'observation'],
        objectives: [
          'Provide proper nutrition for optimal growth',
          'Monitor animal health during feeding',
          'Maintain accurate feeding records'
        ],
      ),
      JournalTemplate(
        id: 'feed_analysis',
        title: 'Feed Quality Assessment',
        category: 'feeding',
        descriptionTemplate: 'Analyzed {feed_brand} {feed_type} for quality indicators. Feed appearance: {feed_appearance}. Texture: {feed_texture}. No signs of mold or contamination detected. Feed conversion ratio calculated at {fcr}. Cost per pound: {cost_per_pound}.',
        suggestedAETSkills: ['Feeding and Nutrition', 'Cost Analysis', 'Quality Assurance'],
        duration: 45,
        tags: ['feed_analysis', 'quality_control', 'economics'],
        objectives: [
          'Evaluate feed quality and nutritional value',
          'Calculate feed conversion efficiency',
          'Optimize feed costs while maintaining nutrition'
        ],
      ),
    ],
    'health': [
      JournalTemplate(
        id: 'daily_health_check',
        title: 'Daily Health Assessment',
        category: 'health',
        descriptionTemplate: 'Conducted comprehensive health check on {animal_name}. Temperature: {temperature}°F (normal range). Eyes are {eye_condition}, nose is {nose_condition}. Gait appears {gait_condition}. Appetite is {appetite_level}. No signs of illness or distress observed. Animal responsive to handling.',
        suggestedAETSkills: ['Animal Health Management', 'Performance Evaluation', 'Record Keeping'],
        duration: 20,
        tags: ['health_check', 'daily_care', 'monitoring'],
        objectives: [
          'Monitor animal health status daily',
          'Identify potential health issues early',
          'Maintain detailed health records'
        ],
      ),
      JournalTemplate(
        id: 'vaccination_record',
        title: 'Vaccination Administration',
        category: 'health',
        descriptionTemplate: 'Administered {vaccine_name} to {animal_name} under veterinary supervision. Vaccination site: {injection_site}. No immediate adverse reactions observed. Updated vaccination records. Next vaccination due: {next_due_date}. Animal handled calmly throughout procedure.',
        suggestedAETSkills: ['Animal Health Management', 'Record Keeping', 'Safety Protocols'],
        duration: 15,
        tags: ['vaccination', 'veterinary_care', 'prevention'],
        objectives: [
          'Maintain proper vaccination schedule',
          'Prevent disease outbreaks',
          'Follow veterinary protocols'
        ],
      ),
    ],
    'training': [
      JournalTemplate(
        id: 'show_training',
        title: 'Show Training Session',
        category: 'training',
        descriptionTemplate: 'Conducted {duration}-minute show training with {animal_name}. Focused on {training_focus} today. Animal\'s stance improved {improvement_level}. Response to halter cues was {response_level}. Practiced walking pattern {pattern_type}. Need to work more on {improvement_areas}.',
        suggestedAETSkills: ['Performance Evaluation', 'Animal Health Management', 'Public Speaking'],
        duration: 45,
        tags: ['show_prep', 'training', 'competition'],
        objectives: [
          'Improve animal show performance',
          'Develop handling skills',
          'Prepare for competition'
        ],
      ),
      JournalTemplate(
        id: 'handling_practice',
        title: 'Animal Handling Practice',
        category: 'training',
        descriptionTemplate: 'Practiced basic handling techniques with {animal_name}. Animal remained {calmness_level} throughout session. Successfully practiced {handling_techniques}. Animal responded well to {positive_reinforcement}. Noted improvement in {specific_improvements}.',
        suggestedAETSkills: ['Animal Health Management', 'Safety Protocols', 'Problem Solving'],
        duration: 30,
        tags: ['handling', 'training', 'safety'],
        objectives: [
          'Develop safe handling techniques',
          'Build trust with animal',
          'Improve handling confidence'
        ],
      ),
    ],
    'breeding': [
      JournalTemplate(
        id: 'breeding_observation',
        title: 'Breeding Behavior Observation',
        category: 'breeding',
        descriptionTemplate: 'Observed breeding behavior in {animal_name}. Signs of estrus: {estrus_signs}. Breeding occurred at {breeding_time}. Animal behavior: {behavior_notes}. Environmental conditions: {weather_temp}°F, {weather_conditions}. Recorded for genetic tracking.',
        suggestedAETSkills: ['Breeding and Genetics', 'Record Keeping', 'Performance Evaluation'],
        duration: 60,
        tags: ['breeding', 'genetics', 'reproduction'],
        objectives: [
          'Monitor breeding cycles accurately',
          'Maintain genetic records',
          'Optimize breeding outcomes'
        ],
      ),
    ],
    'showing': [
      JournalTemplate(
        id: 'show_preparation',
        title: 'Competition Show Preparation',
        category: 'showing',
        descriptionTemplate: 'Prepared {animal_name} for {show_name} competition. Grooming completed: {grooming_tasks}. Animal weight: {current_weight} lbs (target: {target_weight} lbs). Training focus: {training_areas}. Equipment checked and ready. Confidence level: {confidence_level}.',
        suggestedAETSkills: ['Performance Evaluation', 'Public Speaking', 'Critical Thinking'],
        duration: 120,
        tags: ['show_prep', 'competition', 'grooming'],
        objectives: [
          'Prepare animal for competition',
          'Perfect showing techniques',
          'Build competition confidence'
        ],
      ),
    ],
    'general': [
      JournalTemplate(
        id: 'project_reflection',
        title: 'SAE Project Reflection',
        category: 'general',
        descriptionTemplate: 'Reflected on my SAE project progress this week. Key accomplishments: {accomplishments}. Challenges faced: {challenges}. Skills developed: {skills_learned}. Areas for improvement: {improvement_areas}. Goals for next week: {next_goals}.',
        suggestedAETSkills: ['Critical Thinking', 'Problem Solving', 'Project Management'],
        duration: 30,
        tags: ['reflection', 'goal_setting', 'personal_development'],
        objectives: [
          'Evaluate project progress regularly',
          'Identify learning opportunities',
          'Set goals for continued improvement'
        ],
      ),
    ],
  };

  /// Get templates for a specific category
  List<JournalTemplate> getTemplatesForCategory(String category) {
    return _templates[category] ?? [];
  }

  /// Get all available templates
  List<JournalTemplate> getAllTemplates() {
    return _templates.values.expand((templates) => templates).toList();
  }

  /// Generate context-aware suggestions based on user input
  Future<List<ContentSuggestion>> generateSuggestions({
    required String category,
    required String currentText,
    String? animalType,
    String? previousEntries,
    Map<String, dynamic>? context,
  }) async {
    final suggestions = <ContentSuggestion>[];
    
    // Quick Fill suggestions - simple template matching
    if (currentText.length < 20) {
      final quickFills = _generateQuickFillSuggestions(category, currentText);
      suggestions.addAll(quickFills);
    }
    
    // Smart suggestions based on context
    final smartSuggestions = _generateSmartSuggestions(
      category: category,
      currentText: currentText,
      animalType: animalType,
      context: context,
    );
    suggestions.addAll(smartSuggestions);
    
    // Sort by confidence score
    suggestions.sort((a, b) => b.confidence.compareTo(a.confidence));
    
    return suggestions.take(5).toList();
  }

  /// Generate quick fill suggestions for immediate completion
  List<ContentSuggestion> _generateQuickFillSuggestions(
    String category, 
    String currentText,
  ) {
    final suggestions = <ContentSuggestion>[];
    final templates = getTemplatesForCategory(category);
    
    for (final template in templates) {
      final words = currentText.toLowerCase().split(' ');
      final templateWords = template.descriptionTemplate.toLowerCase().split(' ');
      
      // Check for partial matches
      double matchScore = 0;
      for (final word in words) {
        if (word.length > 2 && templateWords.any((tw) => tw.contains(word))) {
          matchScore += 0.2;
        }
      }
      
      if (matchScore > 0 || currentText.length < 10) {
        suggestions.add(ContentSuggestion(
          id: 'quick_${template.id}',
          type: SuggestionType.quickFill,
          title: template.title,
          content: template.descriptionTemplate,
          confidence: 0.8 + matchScore,
          suggestedAETSkills: template.suggestedAETSkills,
          estimatedDuration: template.duration,
          tags: template.tags,
        ));
      }
    }
    
    return suggestions;
  }

  /// Generate smart context-aware suggestions
  List<ContentSuggestion> _generateSmartSuggestions({
    required String category,
    required String currentText,
    String? animalType,
    Map<String, dynamic>? context,
  }) {
    final suggestions = <ContentSuggestion>[];
    
    // Analyze current text for context clues
    final textLower = currentText.toLowerCase();
    final contextualHints = _extractContextualHints(textLower, context);
    
    // Generate suggestions based on detected context
    if (contextualHints.isNotEmpty) {
      suggestions.addAll(_generateContextualSuggestions(
        category: category,
        hints: contextualHints,
        animalType: animalType,
      ));
    }
    
    // Add completion suggestions
    if (currentText.length > 20) {
      suggestions.addAll(_generateCompletionSuggestions(
        category: category,
        currentText: currentText,
      ));
    }
    
    return suggestions;
  }

  /// Extract contextual hints from text
  Map<String, dynamic> _extractContextualHints(
    String text, 
    Map<String, dynamic>? additionalContext,
  ) {
    final hints = <String, dynamic>{};
    
    // Animal condition keywords
    if (text.contains('healthy') || text.contains('good')) {
      hints['animal_condition'] = 'healthy';
    } else if (text.contains('sick') || text.contains('lethargic')) {
      hints['animal_condition'] = 'concerning';
    }
    
    // Activity keywords
    if (text.contains('fed') || text.contains('feeding')) {
      hints['activity'] = 'feeding';
    } else if (text.contains('trained') || text.contains('training')) {
      hints['activity'] = 'training';
    } else if (text.contains('check') || text.contains('examined')) {
      hints['activity'] = 'health_check';
    }
    
    // Merge with additional context
    if (additionalContext != null) {
      hints.addAll(additionalContext);
    }
    
    return hints;
  }

  /// Generate contextual suggestions based on hints
  List<ContentSuggestion> _generateContextualSuggestions({
    required String category,
    required Map<String, dynamic> hints,
    String? animalType,
  }) {
    final suggestions = <ContentSuggestion>[];
    
    if (hints['activity'] == 'feeding' && category == 'feeding') {
      suggestions.add(ContentSuggestion(
        id: 'context_feeding_followup',
        type: SuggestionType.smartSuggest,
        title: 'Add feeding observations',
        content: 'Animal showed normal appetite and consumed feed readily. No signs of digestive issues. Water intake appeared normal.',
        confidence: 0.85,
        suggestedAETSkills: ['Feeding and Nutrition', 'Animal Health Management'],
        estimatedDuration: null,
        tags: ['feeding', 'observation'],
      ));
    }
    
    if (hints['animal_condition'] == 'healthy') {
      suggestions.add(ContentSuggestion(
        id: 'context_healthy_details',
        type: SuggestionType.smartSuggest,
        title: 'Add health details',
        content: 'Eyes are clear and bright, nose is cool and moist. Gait is steady and normal. No signs of distress or abnormal behavior observed.',
        confidence: 0.80,
        suggestedAETSkills: ['Animal Health Management'],
        estimatedDuration: null,
        tags: ['health', 'observation'],
      ));
    }
    
    return suggestions;
  }

  /// Generate text completion suggestions
  List<ContentSuggestion> _generateCompletionSuggestions({
    required String category,
    required String currentText,
  }) {
    final suggestions = <ContentSuggestion>[];
    
    // Common completion patterns
    if (currentText.endsWith('observed') || currentText.endsWith('noticed')) {
      suggestions.add(ContentSuggestion(
        id: 'completion_observation',
        type: SuggestionType.textCompletion,
        title: 'Complete observation',
        content: ' normal behavior and good overall condition. No abnormalities detected.',
        confidence: 0.70,
        suggestedAETSkills: [],
        estimatedDuration: null,
        tags: ['observation'],
      ));
    }
    
    if (currentText.contains('temperature') && !currentText.contains('°F')) {
      suggestions.add(ContentSuggestion(
        id: 'completion_temperature',
        type: SuggestionType.textCompletion,
        title: 'Add temperature reading',
        content: ' of 101.2°F, which is within normal range for the species.',
        confidence: 0.75,
        suggestedAETSkills: ['Animal Health Management'],
        estimatedDuration: null,
        tags: ['health', 'measurement'],
      ));
    }
    
    return suggestions;
  }

  /// Get suggested AET skills for category
  List<String> getSuggestedAETSkillsForCategory(String category) {
    final templates = getTemplatesForCategory(category);
    final skills = <String>{};
    
    for (final template in templates) {
      skills.addAll(template.suggestedAETSkills);
    }
    
    return skills.toList();
  }

  /// Get suggested duration for category
  int getSuggestedDurationForCategory(String category) {
    final templates = getTemplatesForCategory(category);
    if (templates.isEmpty) return 30;
    
    final avgDuration = templates.map((t) => t.duration).reduce((a, b) => a + b) / templates.length;
    return avgDuration.round();
  }

  /// Generate AI-powered content (mock implementation)
  Future<ContentSuggestion> generateAIContent({
    required String category,
    required String prompt,
    Map<String, dynamic>? context,
  }) async {
    // Simulate AI processing delay
    await Future.delayed(const Duration(milliseconds: 1500));
    
    // Mock AI-generated content based on category and prompt
    final aiContent = _generateMockAIContent(category, prompt, context);
    
    return ContentSuggestion(
      id: 'ai_generated_${DateTime.now().millisecondsSinceEpoch}',
      type: SuggestionType.aiGenerated,
      title: 'AI Generated Content',
      content: aiContent.content,
      confidence: 0.90,
      suggestedAETSkills: aiContent.suggestedSkills,
      estimatedDuration: aiContent.duration,
      tags: aiContent.tags,
    );
  }

  /// Generate mock AI content (placeholder for actual AI integration)
  _MockAIContent _generateMockAIContent(
    String category, 
    String prompt, 
    Map<String, dynamic>? context,
  ) {
    switch (category) {
      case 'feeding':
        return _MockAIContent(
          content: 'Today\'s feeding session focused on monitoring nutritional intake and animal response. The animal consumed the prescribed amount of feed with normal appetite. Observed healthy eating behavior and proper hydration levels. Feed quality appeared excellent with no signs of spoilage. Body condition score remains optimal for this stage of development.',
          suggestedSkills: ['Feeding and Nutrition', 'Animal Health Management', 'Record Keeping'],
          duration: 35,
          tags: ['feeding', 'nutrition', 'health_monitoring'],
        );
      case 'health':
        return _MockAIContent(
          content: 'Conducted comprehensive health assessment including vital signs monitoring and behavioral observation. All parameters fall within normal ranges for the species. Animal demonstrates alert, responsive behavior with good body condition. No signs of illness or distress detected. Preventive care protocols are being maintained effectively.',
          suggestedSkills: ['Animal Health Management', 'Performance Evaluation', 'Critical Thinking'],
          duration: 25,
          tags: ['health', 'assessment', 'monitoring'],
        );
      case 'training':
        return _MockAIContent(
          content: 'Training session focused on reinforcing previously learned behaviors and introducing new skills. Animal showed excellent responsiveness to cues and demonstrated improved performance. Positive reinforcement techniques proved effective in maintaining engagement. Progress is notable in areas of focus, with clear improvement trajectory established.',
          suggestedSkills: ['Performance Evaluation', 'Problem Solving', 'Communication Skills'],
          duration: 40,
          tags: ['training', 'behavior', 'skill_development'],
        );
      default:
        return _MockAIContent(
          content: 'Today\'s agricultural education activities contributed significantly to project objectives and skill development. Demonstrated practical application of learned concepts while maintaining focus on safety protocols. The experience reinforced theoretical knowledge through hands-on practice and critical thinking applications.',
          suggestedSkills: ['Critical Thinking', 'Problem Solving', 'Project Management'],
          duration: 30,
          tags: ['education', 'skill_development', 'application'],
        );
    }
  }
}

/// Template for journal entries
class JournalTemplate {
  final String id;
  final String title;
  final String category;
  final String descriptionTemplate;
  final List<String> suggestedAETSkills;
  final int duration;
  final List<String> tags;
  final List<String> objectives;

  const JournalTemplate({
    required this.id,
    required this.title,
    required this.category,
    required this.descriptionTemplate,
    required this.suggestedAETSkills,
    required this.duration,
    required this.tags,
    required this.objectives,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'category': category,
    'descriptionTemplate': descriptionTemplate,
    'suggestedAETSkills': suggestedAETSkills,
    'duration': duration,
    'tags': tags,
    'objectives': objectives,
  };

  factory JournalTemplate.fromJson(Map<String, dynamic> json) => JournalTemplate(
    id: json['id'],
    title: json['title'],
    category: json['category'],
    descriptionTemplate: json['descriptionTemplate'],
    suggestedAETSkills: List<String>.from(json['suggestedAETSkills']),
    duration: json['duration'],
    tags: List<String>.from(json['tags']),
    objectives: List<String>.from(json['objectives']),
  );
}

/// Content suggestion for journal entries
class ContentSuggestion {
  final String id;
  final SuggestionType type;
  final String title;
  final String content;
  final double confidence;
  final List<String> suggestedAETSkills;
  final int? estimatedDuration;
  final List<String> tags;

  const ContentSuggestion({
    required this.id,
    required this.type,
    required this.title,
    required this.content,
    required this.confidence,
    required this.suggestedAETSkills,
    this.estimatedDuration,
    required this.tags,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'type': type.toString(),
    'title': title,
    'content': content,
    'confidence': confidence,
    'suggestedAETSkills': suggestedAETSkills,
    'estimatedDuration': estimatedDuration,
    'tags': tags,
  };
}

/// Types of content suggestions
enum SuggestionType {
  quickFill,
  smartSuggest,
  aiGenerated,
  textCompletion,
}

/// Mock AI content structure
class _MockAIContent {
  final String content;
  final List<String> suggestedSkills;
  final int duration;
  final List<String> tags;

  const _MockAIContent({
    required this.content,
    required this.suggestedSkills,
    required this.duration,
    required this.tags,
  });
}