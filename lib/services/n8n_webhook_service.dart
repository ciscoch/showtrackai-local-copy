import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/journal_entry.dart';

/// Enhanced N8N Webhook Service for robust journal AI processing
/// Connects to: https://showtrackai.app.n8n.cloud/webhook/4b52c2de-4d37-4752-aa5c-5741bd9e493d
class N8NWebhookService {
  static const String _webhookUrl = 'https://showtrackai.app.n8n.cloud/webhook/4b52c2de-4d37-4752-aa5c-5741bd9e493d';
  static const String _retryQueueKey = 'n8n_retry_queue';
  static const String _responsesCacheKey = 'n8n_responses_cache';
  static const Duration _defaultTimeout = Duration(seconds: 30);
  static const int _maxRetries = 3;
  static const Duration _retryDelay = Duration(seconds: 5);
  
  static final _supabase = Supabase.instance.client;
  static final _random = Random();

  /// Main method to process journal entry with AI
  static Future<N8NAnalysisResult> processJournalEntry(JournalEntry entry) async {
    try {
      // Check if we already have a cached result for this entry
      final cachedResult = await _getCachedResult(entry.id!);
      if (cachedResult != null) {
        return cachedResult;
      }

      // Prepare comprehensive webhook payload
      final payload = await _buildWebhookPayload(entry);
      
      // Attempt to send webhook with retry logic
      final result = await _sendWebhookWithRetry(payload);
      
      // Cache the successful result
      await _cacheResult(entry.id!, result);
      
      // Update the journal entry with AI insights
      await _updateJournalEntryWithInsights(entry.id!, result);
      
      return result;
    } catch (e) {
      // Store failed request for retry
      await _addToRetryQueue(entry);
      
      // Return fallback analysis
      return _generateFallbackAnalysis(entry);
    }
  }

  /// Build comprehensive webhook payload
  static Future<Map<String, dynamic>> _buildWebhookPayload(JournalEntry entry) async {
    try {
      // Get user information for age-appropriate responses
      final user = _supabase.auth.currentUser;
      if (user == null) throw Exception('User not authenticated');

      // Get user profile for context
      final userProfile = await _getUserProfile(user.id);
      
      // Get animal information if linked
      Map<String, dynamic>? animalData;
      if (entry.animalId != null) {
        animalData = await _getAnimalData(entry.animalId!);
      }

      // Get recent weather data if location available
      Map<String, dynamic>? weatherContext;
      if (entry.locationData != null) {
        weatherContext = _buildWeatherContext(entry.weatherData);
      }

      // Calculate user competency context
      final competencyContext = await _buildCompetencyContext(user.id);

      return {
        'requestId': 'webhook_${DateTime.now().millisecondsSinceEpoch}_${_random.nextInt(10000)}',
        'timestamp': DateTime.now().toIso8601String(),
        'journalEntry': {
          'id': entry.id,
          'userId': entry.userId,
          'title': entry.title,
          'description': entry.description,
          'content': entry.description, // Main content for analysis
          'date': entry.date.toIso8601String(),
          'duration': entry.duration,
          'category': entry.category,
          'tags': entry.tags ?? [],
          'aetSkills': entry.aetSkills,
          'objectives': entry.objectives ?? [],
          'challenges': entry.challenges,
          'improvements': entry.improvements,
          'ffaDegreeType': entry.ffaDegreeType,
          'saType': entry.saType,
          'hoursLogged': entry.hoursLogged,
          'financialValue': entry.financialValue,
          'evidenceType': entry.evidenceType,
          'countsForDegree': entry.countsForDegree,
          'feedStrategy': entry.feedStrategy?.toJson(),
          // Metadata fields
          'source': entry.source,
          'notes': entry.notes,
        },
        'userContext': {
          'userId': user.id,
          'email': user.email,
          'ageGroup': userProfile['age_group'] ?? 'teen', // child, teen, adult
          'experience': userProfile['experience_level'] ?? 'beginner',
          'ffaChapter': userProfile['ffa_chapter'],
          'educationLevel': userProfile['education_level'] ?? 'high_school',
          'interests': userProfile['interests'] ?? [],
        },
        'animalData': animalData,
        'locationContext': entry.locationData != null ? {
          'latitude': entry.locationData!.latitude,
          'longitude': entry.locationData!.longitude,
          'address': entry.locationData!.address,
          'name': entry.locationData!.name,
        } : null,
        'weatherContext': weatherContext,
        'competencyContext': competencyContext,
        'mediaData': {
          'photos': entry.photos ?? [],
          'attachments': entry.attachmentUrls ?? [],
        },
        'processingOptions': {
          'includeFFAStandards': true,
          'includeCompetencyMapping': true,
          'includeRecommendations': true,
          'includeQualityScore': true,
          'ageAppropriate': true,
          'detailLevel': 'comprehensive',
        },
      };
    } catch (e) {
      // Return minimal payload if context building fails
      return {
        'requestId': 'fallback_${DateTime.now().millisecondsSinceEpoch}',
        'timestamp': DateTime.now().toIso8601String(),
        'journalEntry': {
          'id': entry.id,
          'userId': entry.userId,
          'title': entry.title,
          'description': entry.description,
          'content': entry.description,
          'date': entry.date.toIso8601String(),
          'category': entry.category,
          // Metadata fields
          'source': entry.source,
          'notes': entry.notes,
        },
        'userContext': {
          'userId': _supabase.auth.currentUser?.id,
          'ageGroup': 'teen',
        },
        'processingOptions': {
          'includeFFAStandards': true,
          'includeCompetencyMapping': true,
          'detailLevel': 'basic',
        },
      };
    }
  }

  /// Send webhook with retry logic and error handling
  static Future<N8NAnalysisResult> _sendWebhookWithRetry(Map<String, dynamic> payload) async {
    Exception? lastException;
    
    for (int attempt = 1; attempt <= _maxRetries; attempt++) {
      try {
        // Check if we're online
        if (!await _isOnline()) {
          throw Exception('No internet connection available');
        }

        final response = await http.post(
          Uri.parse(_webhookUrl),
          headers: {
            'Content-Type': 'application/json',
            'User-Agent': 'ShowTrackAI-Flutter/2.0',
            'X-Request-ID': payload['requestId'],
            'X-Retry-Attempt': attempt.toString(),
          },
          body: jsonEncode(payload),
        ).timeout(_defaultTimeout);

        if (response.statusCode == 200) {
          final responseData = jsonDecode(response.body);
          return N8NAnalysisResult.fromWebhookResponse(responseData);
        } else {
          throw HttpException('Webhook failed: ${response.statusCode} - ${response.body}');
        }
      } catch (e) {
        lastException = e is Exception ? e : Exception(e.toString());
        
        if (attempt < _maxRetries) {
          // Wait before retry with exponential backoff
          final delay = Duration(seconds: _retryDelay.inSeconds * attempt);
          await Future.delayed(delay);
        }
      }
    }

    throw lastException ?? Exception('Unknown error during webhook processing');
  }

  /// Generate fallback analysis when webhook fails
  static N8NAnalysisResult _generateFallbackAnalysis(JournalEntry entry) {
    // Basic analysis based on entry content
    final contentLength = entry.description.length;
    final wordCount = entry.description.split(' ').length;
    
    // Calculate basic quality score
    int qualityScore = 5; // Base score
    if (wordCount > 50) qualityScore += 2;
    if (wordCount > 100) qualityScore += 2;
    if (entry.challenges != null && entry.challenges!.isNotEmpty) qualityScore += 1;
    if (entry.improvements != null && entry.improvements!.isNotEmpty) qualityScore += 1;
    if (entry.objectives != null && entry.objectives!.isNotEmpty) qualityScore += 1;
    
    qualityScore = qualityScore.clamp(1, 10);

    // Basic FFA standards mapping based on category
    List<String> ffaStandards = _mapCategoryToFFAStandards(entry.category);
    
    // Basic competency level assessment
    String competencyLevel = 'Developing';
    if (qualityScore >= 8) competencyLevel = 'Proficient';
    if (qualityScore >= 9) competencyLevel = 'Advanced';
    if (qualityScore <= 3) competencyLevel = 'Novice';

    return N8NAnalysisResult(
      requestId: 'fallback_${DateTime.now().millisecondsSinceEpoch}',
      status: 'completed_offline',
      qualityScore: qualityScore,
      ffaStandards: ffaStandards,
      aetSkills: entry.aetSkills,
      competencyLevel: competencyLevel,
      educationalConcepts: _extractEducationalConcepts(entry),
      aiInsights: AIInsights(
        qualityAssessment: QualityAssessment(
          score: qualityScore,
          justification: 'Offline analysis based on entry length and completeness',
        ),
        ffaStandards: ffaStandards,
        aetSkillsIdentified: entry.aetSkills,
        learningConcepts: _extractEducationalConcepts(entry),
        competencyLevel: competencyLevel,
        feedback: Feedback(
          strengths: ['Entry created and documented'],
          improvements: ['Consider adding more detail when online AI is available'],
          suggestions: ['Connect to internet for enhanced AI analysis'],
        ),
        recommendedActivities: ['Continue documenting activities', 'Review entry when online'],
      ),
      recommendations: [
        'Great job documenting your agricultural activities!',
        'Try to connect to the internet for enhanced AI analysis.',
        'Consider adding more details about your learning outcomes.',
      ],
      processingMetadata: {
        'processed_at': DateTime.now().toIso8601String(),
        'processing_method': 'offline_fallback',
        'ai_available': false,
        'confidence_level': 'low',
      },
    );
  }

  /// Update journal entry with AI insights
  static Future<void> _updateJournalEntryWithInsights(String entryId, N8NAnalysisResult result) async {
    try {
      // Update the entry in Supabase with AI insights
      await _supabase.from('journal_entries').update({
        'quality_score': result.qualityScore,
        'ffa_standards': result.ffaStandards,
        'aet_skills': result.aetSkills,
        'learning_concepts': result.educationalConcepts,
        'competency_level': result.competencyLevel,
        'ai_insights': result.aiInsights.toJson(),
        'ai_processed': true,
        'ai_processed_at': DateTime.now().toIso8601String(),
        'processing_metadata': result.processingMetadata,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', entryId);

    } catch (e) {
      print('Failed to update journal entry with AI insights: $e');
      // Don't throw - this is not critical for the user experience
    }
  }

  /// Cache analysis result for offline access
  static Future<void> _cacheResult(String entryId, N8NAnalysisResult result) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cacheJson = prefs.getString(_responsesCacheKey);
      
      Map<String, dynamic> cache = {};
      if (cacheJson != null) {
        cache = Map<String, dynamic>.from(jsonDecode(cacheJson));
      }
      
      cache[entryId] = {
        'result': result.toJson(),
        'cached_at': DateTime.now().toIso8601String(),
      };
      
      // Keep only last 100 cached results
      if (cache.length > 100) {
        final sortedEntries = cache.entries.toList()
          ..sort((a, b) => (b.value['cached_at'] as String)
              .compareTo(a.value['cached_at'] as String));
        
        cache = Map.fromEntries(sortedEntries.take(100));
      }
      
      await prefs.setString(_responsesCacheKey, jsonEncode(cache));
    } catch (e) {
      print('Failed to cache N8N result: $e');
    }
  }

  /// Get cached analysis result
  static Future<N8NAnalysisResult?> _getCachedResult(String entryId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cacheJson = prefs.getString(_responsesCacheKey);
      
      if (cacheJson == null) return null;
      
      final cache = Map<String, dynamic>.from(jsonDecode(cacheJson));
      final cachedEntry = cache[entryId];
      
      if (cachedEntry != null) {
        // Check if cache is still valid (24 hours)
        final cachedAt = DateTime.parse(cachedEntry['cached_at']);
        if (DateTime.now().difference(cachedAt).inHours < 24) {
          return N8NAnalysisResult.fromJson(cachedEntry['result']);
        }
      }
      
      return null;
    } catch (e) {
      return null;
    }
  }

  /// Process retry queue when connection is restored
  static Future<void> processRetryQueue() async {
    try {
      if (!await _isOnline()) return;

      final prefs = await SharedPreferences.getInstance();
      final queueJson = prefs.getString(_retryQueueKey);
      if (queueJson == null) return;

      final queue = List<Map<String, dynamic>>.from(jsonDecode(queueJson));
      final successfulEntries = <Map<String, dynamic>>[];

      for (final queueItem in queue) {
        try {
          final entryData = queueItem['entry'];
          final entry = JournalEntry.fromJson(entryData);
          
          // Retry processing
          final result = await processJournalEntry(entry);
          
          if (result.status == 'completed') {
            successfulEntries.add(queueItem);
          }
        } catch (e) {
          print('Retry failed for entry: $e');
          // Keep in queue for next retry
        }
      }

      // Remove successful entries from queue
      if (successfulEntries.isNotEmpty) {
        final remainingQueue = queue
            .where((item) => !successfulEntries.contains(item))
            .toList();
        await prefs.setString(_retryQueueKey, jsonEncode(remainingQueue));
      }
    } catch (e) {
      print('Error processing retry queue: $e');
    }
  }

  /// Add failed entry to retry queue
  static Future<void> _addToRetryQueue(JournalEntry entry) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final queueJson = prefs.getString(_retryQueueKey);
      
      List<Map<String, dynamic>> queue = [];
      if (queueJson != null) {
        queue = List<Map<String, dynamic>>.from(jsonDecode(queueJson));
      }
      
      queue.add({
        'entry': entry.toJson(),
        'failed_at': DateTime.now().toIso8601String(),
        'retry_count': 0,
      });
      
      // Keep only last 50 failed entries
      if (queue.length > 50) {
        queue = queue.sublist(queue.length - 50);
      }
      
      await prefs.setString(_retryQueueKey, jsonEncode(queue));
    } catch (e) {
      print('Failed to add entry to retry queue: $e');
    }
  }

  /// Helper methods

  static Future<bool> _isOnline() async {
    try {
      final result = await InternetAddress.lookup('google.com');
      return result.isNotEmpty && result[0].rawAddress.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  static Future<Map<String, dynamic>> _getUserProfile(String userId) async {
    try {
      final response = await _supabase
          .from('user_profiles')
          .select()
          .eq('id', userId)
          .single();
      return response;
    } catch (e) {
      return {};
    }
  }

  static Future<Map<String, dynamic>?> _getAnimalData(String animalId) async {
    try {
      final response = await _supabase
          .from('animals')
          .select()
          .eq('id', animalId)
          .single();
      return response;
    } catch (e) {
      return null;
    }
  }

  static Map<String, dynamic>? _buildWeatherContext(WeatherData? weatherData) {
    if (weatherData == null) return null;
    
    return {
      'temperature': weatherData.temperature,
      'condition': weatherData.condition,
      'humidity': weatherData.humidity,
      'windSpeed': weatherData.windSpeed,
      'description': weatherData.description,
    };
  }

  static Future<Map<String, dynamic>> _buildCompetencyContext(String userId) async {
    try {
      // Get recent entries to understand user's competency progression
      final recentEntries = await _supabase
          .from('journal_entries')
          .select('competency_level, ffa_standards, aet_skills, quality_score')
          .eq('user_id', userId)
          .order('created_at', ascending: false)
          .limit(20);

      final competencyLevels = <String, int>{};
      final ffaStandards = <String>{};
      final aetSkills = <String>{};
      int totalScore = 0;
      int scoredEntries = 0;

      for (final entry in recentEntries) {
        if (entry['competency_level'] != null) {
          final level = entry['competency_level'] as String;
          competencyLevels[level] = (competencyLevels[level] ?? 0) + 1;
        }
        
        if (entry['ffa_standards'] != null) {
          ffaStandards.addAll(List<String>.from(entry['ffa_standards']));
        }
        
        if (entry['aet_skills'] != null) {
          aetSkills.addAll(List<String>.from(entry['aet_skills']));
        }
        
        if (entry['quality_score'] != null) {
          totalScore += entry['quality_score'] as int;
          scoredEntries++;
        }
      }

      return {
        'competencyDistribution': competencyLevels,
        'ffaStandardsAchieved': ffaStandards.toList(),
        'aetSkillsDemonstrated': aetSkills.toList(),
        'averageQualityScore': scoredEntries > 0 ? totalScore / scoredEntries : 0,
        'entriesAnalyzed': recentEntries.length,
      };
    } catch (e) {
      return {};
    }
  }

  static List<String> _mapCategoryToFFAStandards(String category) {
    const Map<String, List<String>> categoryToStandards = {
      'daily_care': ['AS.01.01', 'AS.01.02'],
      'health_check': ['AS.07.01', 'AS.07.02'],
      'feeding': ['AS.02.01', 'AS.02.02'],
      'training': ['AS.03.01', 'AS.03.02'],
      'show_prep': ['AS.04.01', 'AS.08.01'],
      'veterinary': ['AS.07.03', 'AS.07.04'],
      'breeding': ['AS.05.01', 'AS.05.02'],
      'record_keeping': ['AB.01.01', 'AB.01.02'],
      'financial': ['AB.02.01', 'AB.03.01'],
    };
    
    return categoryToStandards[category] ?? ['AS.01.01'];
  }

  static List<String> _extractEducationalConcepts(JournalEntry entry) {
    final concepts = <String>[];
    
    // Basic concepts based on category
    const categoryToConcepts = {
      'daily_care': ['Animal Welfare', 'Husbandry Practices'],
      'health_check': ['Animal Health', 'Veterinary Science'],
      'feeding': ['Animal Nutrition', 'Feed Management'],
      'training': ['Animal Behavior', 'Training Techniques'],
      'show_prep': ['Competition Preparation', 'Animal Presentation'],
    };
    
    concepts.addAll(categoryToConcepts[entry.category] ?? []);
    
    // Add concepts based on content keywords
    final content = entry.description.toLowerCase();
    if (content.contains('feed') || content.contains('nutrition')) {
      concepts.add('Animal Nutrition');
    }
    if (content.contains('health') || content.contains('sick')) {
      concepts.add('Animal Health');
    }
    if (content.contains('training') || content.contains('behavior')) {
      concepts.add('Animal Behavior');
    }
    
    return concepts.toSet().toList(); // Remove duplicates
  }
}

/// Result from N8N webhook processing
class N8NAnalysisResult {
  final String requestId;
  final String status;
  final int qualityScore;
  final List<String> ffaStandards;
  final List<String> aetSkills;
  final String competencyLevel;
  final List<String> educationalConcepts;
  final AIInsights aiInsights;
  final List<String> recommendations;
  final Map<String, dynamic> processingMetadata;

  N8NAnalysisResult({
    required this.requestId,
    required this.status,
    required this.qualityScore,
    required this.ffaStandards,
    required this.aetSkills,
    required this.competencyLevel,
    required this.educationalConcepts,
    required this.aiInsights,
    required this.recommendations,
    required this.processingMetadata,
  });

  factory N8NAnalysisResult.fromWebhookResponse(Map<String, dynamic> json) {
    final data = json['data'] ?? json;
    
    return N8NAnalysisResult(
      requestId: data['requestId'] ?? '',
      status: data['status'] ?? 'completed',
      qualityScore: data['qualityScore'] ?? 5,
      ffaStandards: List<String>.from(data['ffaStandards'] ?? []),
      aetSkills: List<String>.from(data['aetSkills'] ?? []),
      competencyLevel: data['competencyLevel'] ?? 'Developing',
      educationalConcepts: List<String>.from(data['educationalConcepts'] ?? []),
      aiInsights: data['aiInsights'] != null 
          ? AIInsights.fromJson(data['aiInsights'])
          : _createDefaultInsights(data),
      recommendations: List<String>.from(data['recommendations'] ?? []),
      processingMetadata: data['processingMetadata'] ?? {
        'processed_at': DateTime.now().toIso8601String(),
        'processing_method': 'webhook',
        'ai_available': true,
      },
    );
  }

  factory N8NAnalysisResult.fromJson(Map<String, dynamic> json) {
    return N8NAnalysisResult(
      requestId: json['requestId'] ?? '',
      status: json['status'] ?? 'completed',
      qualityScore: json['qualityScore'] ?? 5,
      ffaStandards: List<String>.from(json['ffaStandards'] ?? []),
      aetSkills: List<String>.from(json['aetSkills'] ?? []),
      competencyLevel: json['competencyLevel'] ?? 'Developing',
      educationalConcepts: List<String>.from(json['educationalConcepts'] ?? []),
      aiInsights: AIInsights.fromJson(json['aiInsights']),
      recommendations: List<String>.from(json['recommendations'] ?? []),
      processingMetadata: json['processingMetadata'] ?? {},
    );
  }

  Map<String, dynamic> toJson() => {
    'requestId': requestId,
    'status': status,
    'qualityScore': qualityScore,
    'ffaStandards': ffaStandards,
    'aetSkills': aetSkills,
    'competencyLevel': competencyLevel,
    'educationalConcepts': educationalConcepts,
    'aiInsights': aiInsights.toJson(),
    'recommendations': recommendations,
    'processingMetadata': processingMetadata,
  };

  static AIInsights _createDefaultInsights(Map<String, dynamic> data) {
    return AIInsights(
      qualityAssessment: QualityAssessment(
        score: data['qualityScore'] ?? 5,
        justification: data['qualityJustification'] ?? 'Analysis completed',
      ),
      ffaStandards: List<String>.from(data['ffaStandards'] ?? []),
      aetSkillsIdentified: List<String>.from(data['aetSkills'] ?? []),
      learningConcepts: List<String>.from(data['educationalConcepts'] ?? []),
      competencyLevel: data['competencyLevel'] ?? 'Developing',
      feedback: Feedback(
        strengths: List<String>.from(data['strengths'] ?? ['Good documentation']),
        improvements: List<String>.from(data['improvements'] ?? ['Keep practicing']),
        suggestions: List<String>.from(data['suggestions'] ?? ['Continue learning']),
      ),
      recommendedActivities: List<String>.from(data['recommendations'] ?? []),
    );
  }
}