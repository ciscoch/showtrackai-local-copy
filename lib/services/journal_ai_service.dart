import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'journal_content_templates.dart';

class JournalAIService {
  static final _supabase = Supabase.instance.client;
  static const String _baseUrl = 'https://showtrackai.netlify.app/.netlify/functions';
  static const String _n8nWebhookUrl = 'https://showtrackai.app.n8n.cloud/webhook/journal-content-gen';
  
  // Cache for storing recent suggestions
  static final Map<String, ContentSuggestion> _suggestionCache = {};
  static const Duration _cacheDuration = Duration(hours: 6);
  static final Map<String, DateTime> _cacheTimestamps = {};
  
  /// Generate AI-powered content suggestion
  static Future<ContentSuggestion> generateAIContent({
    required Map<String, dynamic> context,
  }) async {
    try {
      // Generate cache key
      final cacheKey = _generateCacheKey(context);
      
      // Check cache first
      if (_suggestionCache.containsKey(cacheKey)) {
        final timestamp = _cacheTimestamps[cacheKey];
        if (timestamp != null && 
            DateTime.now().difference(timestamp) < _cacheDuration) {
          return _suggestionCache[cacheKey]!;
        }
      }
      
      // Get user profile for age verification
      final user = _supabase.auth.currentUser;
      if (user == null) {
        throw Exception('User not authenticated');
      }
      
      final profileResponse = await _supabase
          .from('user_profiles')
          .select('birth_date, parent_consent')
          .eq('id', user.id)
          .single();
      
      // Check COPPA compliance
      final birthDate = profileResponse['birth_date'] != null
          ? DateTime.parse(profileResponse['birth_date'])
          : null;
      final userAge = birthDate != null
          ? DateTime.now().difference(birthDate).inDays ~/ 365
          : 18;
      
      if (userAge < 13 && profileResponse['parent_consent'] != true) {
        // Return safe, generic suggestion for users under 13 without consent
        return _generateSafeSuggestion(context);
      }
      
      // Try N8N webhook first for AI generation
      try {
        final suggestion = await _callN8NWebhook(context, userAge);
        
        // Cache the result
        _suggestionCache[cacheKey] = suggestion;
        _cacheTimestamps[cacheKey] = DateTime.now();
        
        // Track usage for analytics
        await _trackSuggestionUsage(suggestion.type, true);
        
        return suggestion;
      } catch (e) {
        // Fallback to Netlify function
        return await _callNetlifyFunction(context, userAge);
      }
    } catch (e) {
      // Final fallback to local generation
      return await _generateLocalSuggestion(context);
    }
  }
  
  /// Call N8N webhook for AI generation
  static Future<ContentSuggestion> _callN8NWebhook(
    Map<String, dynamic> context,
    int userAge,
  ) async {
    final response = await http.post(
      Uri.parse(_n8nWebhookUrl),
      headers: {
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'title': context['title'] ?? '',
        'category': context['category'] ?? 'other',
        'duration': context['duration'] ?? 60,
        'date': (context['date'] ?? DateTime.now()).toIso8601String(),
        'userAge': userAge,
        'animalType': context['animalType'],
        'weather': context['weather'],
        'additionalContext': context,
      }),
    ).timeout(Duration(seconds: 10));
    
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      
      return ContentSuggestion(
        type: SuggestionType.aiGenerated,
        content: data['content'] ?? '',
        description: data['description'] ?? '',
        objectives: List<String>.from(data['objectives'] ?? []),
        outcomes: List<String>.from(data['outcomes'] ?? []),
        aetSkills: List<String>.from(data['aetSkills'] ?? []),
        ffaStandards: List<String>.from(data['ffaStandards'] ?? []),
        confidence: (data['confidence'] ?? 0.85).toDouble(),
        suggestedDuration: data['suggestedDuration'] ?? 60,
        suggestedTags: List<String>.from(data['suggestedTags'] ?? []),
      );
    } else {
      throw Exception('N8N webhook failed: ${response.statusCode}');
    }
  }
  
  /// Call Netlify function for AI generation
  static Future<ContentSuggestion> _callNetlifyFunction(
    Map<String, dynamic> context,
    int userAge,
  ) async {
    final token = _supabase.auth.currentSession?.accessToken;
    if (token == null) {
      throw Exception('No authentication token');
    }
    
    final response = await http.post(
      Uri.parse('$_baseUrl/journal-generate-content'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({
        'title': context['title'] ?? '',
        'category': context['category'] ?? 'other',
        'duration': context['duration'] ?? 60,
        'date': (context['date'] ?? DateTime.now()).toIso8601String(),
        'userAge': userAge,
        'context': context,
      }),
    ).timeout(Duration(seconds: 15));
    
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final suggestion = data['suggestion'];
      
      return ContentSuggestion(
        type: SuggestionType.aiGenerated,
        content: suggestion['content'] ?? '',
        description: suggestion['description'] ?? '',
        objectives: List<String>.from(suggestion['objectives'] ?? []),
        outcomes: List<String>.from(suggestion['outcomes'] ?? []),
        aetSkills: List<String>.from(suggestion['aet_skills'] ?? []),
        ffaStandards: List<String>.from(suggestion['ffa_standards'] ?? []),
        confidence: (suggestion['confidence'] ?? 0.85).toDouble(),
        suggestedDuration: suggestion['suggested_duration'] ?? 60,
        suggestedTags: List<String>.from(suggestion['suggested_tags'] ?? []),
      );
    } else {
      throw Exception('Netlify function failed: ${response.statusCode}');
    }
  }
  
  /// Generate safe suggestion for users under 13
  static ContentSuggestion _generateSafeSuggestion(Map<String, dynamic> context) {
    final category = context['category'] ?? 'other';
    final duration = context['duration'] ?? 60;
    
    return ContentSuggestion(
      type: SuggestionType.quickFill,
      content: 'Today I worked with my animal for $duration minutes.',
      description: '''Today's activity focused on ${category}.
I spent time caring for my animal and learning new skills.
The animal responded well to the activity.
I followed all safety guidelines during the session.''',
      objectives: [
        'Practice animal care skills',
        'Learn through hands-on experience',
        'Build responsibility',
      ],
      outcomes: [
        'Completed the planned activity',
        'Gained practical experience',
        'Ready for the next session',
      ],
      aetSkills: [
        'Animal Care',
        'Responsibility',
        'Record Keeping',
      ],
      ffaStandards: ['AS.01.01', 'CS.01.01'],
      confidence: 0.7,
      suggestedDuration: duration,
      suggestedTags: [category, 'daily-care'],
    );
  }
  
  /// Generate local suggestion as fallback
  static Future<ContentSuggestion> _generateLocalSuggestion(
    Map<String, dynamic> context,
  ) async {
    // Use the template service for local generation
    return await JournalContentTemplateService.generateSuggestion(
      title: context['title'] ?? '',
      category: context['category'] ?? 'other',
      date: context['date'] ?? DateTime.now(),
      duration: context['duration'] ?? 60,
      additionalContext: context,
    );
  }
  
  /// Get cached suggestions for a category
  static Future<List<ContentSuggestion>> getCachedSuggestions({
    required String category,
    int limit = 5,
  }) async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return [];
      
      // Query Supabase for cached suggestions
      final response = await _supabase
          .from('journal_suggestion_cache')
          .select()
          .eq('user_id', user.id)
          .eq('category', category)
          .order('created_at', ascending: false)
          .limit(limit);
      
      return (response as List).map((item) {
        final content = item['content'] as Map<String, dynamic>;
        
        return ContentSuggestion(
          type: SuggestionType.values[item['suggestion_type'] ?? 0],
          content: content['content'] ?? '',
          description: content['description'] ?? '',
          objectives: List<String>.from(content['objectives'] ?? []),
          outcomes: List<String>.from(content['outcomes'] ?? []),
          aetSkills: List<String>.from(content['aet_skills'] ?? []),
          ffaStandards: List<String>.from(content['ffa_standards'] ?? []),
          confidence: (content['confidence'] ?? 0.7).toDouble(),
          suggestedDuration: content['suggested_duration'] ?? 60,
          suggestedTags: List<String>.from(content['suggested_tags'] ?? []),
        );
      }).toList();
    } catch (e) {
      return [];
    }
  }
  
  /// Track suggestion usage for analytics
  static Future<void> trackSuggestionUsage(
    SuggestionType type,
    bool accepted,
  ) async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return;
      
      await _supabase.from('suggestion_analytics').insert({
        'user_id': user.id,
        'suggestion_type': type.index,
        'accepted': accepted,
        'timestamp': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      // Silently fail - analytics should not break the app
    }
  }
  
  /// Update user preferences based on accepted suggestions
  static Future<void> updateUserPreferences({
    required String category,
    required List<String> acceptedTags,
    required int preferredDuration,
  }) async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return;
      
      // Get existing preferences
      final response = await _supabase
          .from('user_journal_preferences')
          .select()
          .eq('user_id', user.id)
          .single();
      
      if (response == null) {
        // Create new preferences
        await _supabase.from('user_journal_preferences').insert({
          'user_id': user.id,
          'preferred_categories': [category],
          'preferred_tags': acceptedTags,
          'default_duration': preferredDuration,
        });
      } else {
        // Update existing preferences
        final existingCategories = List<String>.from(
          response['preferred_categories'] ?? [],
        );
        final existingTags = List<String>.from(
          response['preferred_tags'] ?? [],
        );
        
        if (!existingCategories.contains(category)) {
          existingCategories.add(category);
        }
        
        for (String tag in acceptedTags) {
          if (!existingTags.contains(tag)) {
            existingTags.add(tag);
          }
        }
        
        await _supabase
            .from('user_journal_preferences')
            .update({
              'preferred_categories': existingCategories,
              'preferred_tags': existingTags,
              'default_duration': preferredDuration,
            })
            .eq('user_id', user.id);
      }
    } catch (e) {
      // Silently fail - preferences should not break the app
    }
  }
  
  /// Generate cache key for suggestions
  static String _generateCacheKey(Map<String, dynamic> context) {
    final title = context['title'] ?? '';
    final category = context['category'] ?? '';
    final duration = context['duration'] ?? 0;
    
    return '${title.toLowerCase()}_${category}_$duration';
  }
  
  /// Clear suggestion cache
  static void clearCache() {
    _suggestionCache.clear();
    _cacheTimestamps.clear();
  }
  
  /// Get available suggestion statistics
  static Future<Map<String, dynamic>> getSuggestionStats() async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return {};
      
      final response = await _supabase
          .from('suggestion_analytics')
          .select()
          .eq('user_id', user.id);
      
      final suggestions = response as List;
      
      int totalSuggestions = suggestions.length;
      int acceptedCount = suggestions.where((s) => s['accepted'] == true).length;
      
      Map<int, int> typeCount = {};
      for (var suggestion in suggestions) {
        final type = suggestion['suggestion_type'] as int;
        typeCount[type] = (typeCount[type] ?? 0) + 1;
      }
      
      return {
        'total': totalSuggestions,
        'accepted': acceptedCount,
        'acceptance_rate': totalSuggestions > 0 
            ? (acceptedCount / totalSuggestions * 100).toStringAsFixed(1)
            : '0',
        'by_type': typeCount,
        'cache_size': _suggestionCache.length,
      };
    } catch (e) {
      return {};
    }
  }
}