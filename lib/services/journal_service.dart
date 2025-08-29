import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import '../models/journal_entry.dart';
import '../config/api_config.dart';
import 'n8n_webhook_service.dart';
import 'ai_assessment_service.dart';

/// Journal service for real-time database operations
/// Handles CRUD operations, AI processing, and search with Supabase
class JournalService {
  
  static final _supabase = Supabase.instance.client;
  static final _uuid = const Uuid();
  static final _aiAssessmentService = AiAssessmentService();

  /// Create a new journal entry
  static Future<JournalEntry> createEntry(JournalEntry entry) async {
    final currentUser = _supabase.auth.currentUser;
    if (currentUser == null) {
      throw Exception('User not authenticated');
    }

    final traceId = entry.traceId ?? 'unknown';
    print('[TRACE_ID: $traceId] 💾 Creating journal entry for user: ${currentUser.id}');

    try {
      // Generate ID if not provided
      final entryWithId = JournalEntry(
        id: entry.id ?? _uuid.v4(),
        userId: currentUser.id,
        title: entry.title,
        description: entry.description,
        date: entry.date,
        duration: entry.duration,
        category: entry.category,
        aetSkills: entry.aetSkills,
        animalId: entry.animalId,
        feedData: entry.feedData,
        objectives: entry.objectives,
        learningOutcomes: entry.learningOutcomes,
        challenges: entry.challenges,
        improvements: entry.improvements,
        photos: entry.photos,
        qualityScore: entry.qualityScore,
        ffaStandards: entry.ffaStandards,
        educationalConcepts: entry.educationalConcepts,
        competencyLevel: entry.competencyLevel,
        aiInsights: entry.aiInsights,
        locationData: entry.locationData,
        weatherData: entry.weatherData,
        attachmentUrls: entry.attachmentUrls,
        tags: entry.tags,
        supervisorId: entry.supervisorId,
        isPublic: entry.isPublic,
        competencyTracking: entry.competencyTracking,
        ffaDegreeType: entry.ffaDegreeType,
        countsForDegree: entry.countsForDegree,
        saType: entry.saType,
        hoursLogged: entry.hoursLogged,
        financialValue: entry.financialValue,
        evidenceType: entry.evidenceType,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        isSynced: true,
        // Preserve distributed tracing
        source: entry.source,
        notes: entry.notes,
        traceId: entry.traceId,
      );

      final token = _supabase.auth.currentSession?.accessToken;
      if (token == null) throw Exception('Not authenticated');

      print('[TRACE_ID: $traceId] 🌐 HTTP POST to Netlify function: journal-create');
      
      final response = await http.post(
        Uri.parse(ApiConfig.journalCreate),
        headers: ApiConfig.getHeadersWithTrace(
          authToken: token,
          traceId: traceId,
        ),
        body: jsonEncode(entryWithId.toJson()),
      ).timeout(ApiConfig.requestTimeout);

      print('[TRACE_ID: $traceId] 📡 Netlify response: ${response.statusCode} (${response.body.length} bytes)');

      if (response.statusCode == 201) {
        final data = jsonDecode(response.body);
        final createdEntry = JournalEntry.fromJson(data['data']);
        
        print('[TRACE_ID: $traceId] ✅ Journal entry created successfully: ${createdEntry.id}');
        
        // Trigger enhanced AI processing asynchronously
        print('[TRACE_ID: $traceId] 🤖 Starting background AI processing');
        _processWithEnhancedAIAsync(createdEntry);
        
        return createdEntry;
      } else {
        print('[TRACE_ID: $traceId] ❌ Failed to create entry: ${response.statusCode}');
        throw Exception('Failed to create entry: ${response.statusCode} ${response.body}');
      }
    } catch (e) {
      print('[TRACE_ID: $traceId] 💥 Error creating entry: $e');
      throw Exception('Failed to create journal entry: ${e.toString()}');
    }
  }

  /// Update an existing journal entry
  static Future<JournalEntry> updateEntry(JournalEntry entry) async {
    final currentUser = _supabase.auth.currentUser;
    if (currentUser == null) {
      throw Exception('User not authenticated');
    }

    final traceId = entry.traceId ?? 'unknown';
    print('[TRACE_ID: $traceId] 📝 Updating journal entry: ${entry.id}');

    try {
      final updatedEntry = entry.copyWith(
        updatedAt: DateTime.now(),
        isSynced: true,
      );

      final token = _supabase.auth.currentSession?.accessToken;
      if (token == null) throw Exception('Not authenticated');

      print('[TRACE_ID: $traceId] 🌐 HTTP PUT to Netlify function: journal-update');
      
      final response = await http.put(
        Uri.parse(ApiConfig.journalUpdate),
        headers: ApiConfig.getHeadersWithTrace(
          authToken: token,
          traceId: traceId,
        ),
        body: jsonEncode(updatedEntry.toJson()),
      ).timeout(ApiConfig.requestTimeout);

      print('[TRACE_ID: $traceId] 📡 Netlify response: ${response.statusCode} (${response.body.length} bytes)');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final updatedResult = JournalEntry.fromJson(data['data']);
        print('[TRACE_ID: $traceId] ✅ Journal entry updated successfully');
        return updatedResult;
      } else {
        print('[TRACE_ID: $traceId] ❌ Failed to update entry: ${response.statusCode}');
        throw Exception('Failed to update entry: ${response.statusCode} ${response.body}');
      }
    } catch (e) {
      print('[TRACE_ID: $traceId] 💥 Error updating entry: $e');
      throw Exception('Failed to update journal entry: ${e.toString()}');
    }
  }

  /// Delete a journal entry
  static Future<void> deleteEntry(String id) async {
    final currentUser = _supabase.auth.currentUser;
    if (currentUser == null) {
      throw Exception('User not authenticated');
    }

    try {
      final token = _supabase.auth.currentSession?.accessToken;
      if (token == null) throw Exception('Not authenticated');

      final response = await http.delete(
        Uri.parse('${ApiConfig.journalDelete}?id=$id'),
        headers: ApiConfig.getDefaultHeaders(authToken: token),
      ).timeout(ApiConfig.requestTimeout);

      if (response.statusCode != 200) {
        throw Exception('Failed to delete entry: ${response.statusCode} ${response.body}');
      }
    } catch (e) {
      print('Error deleting entry: $e');
      throw Exception('Failed to delete journal entry: ${e.toString()}');
    }
  }

  /// Get all journal entries with filtering
  static Future<List<JournalEntry>> getEntries({
    int limit = 20,
    int offset = 0,
    String? category,
    String? animalId,
    DateTime? startDate,
    DateTime? endDate,
    List<String>? tags,
  }) async {
    final currentUser = _supabase.auth.currentUser;
    if (currentUser == null) {
      throw Exception('User not authenticated');
    }

    try {
      final token = _supabase.auth.currentSession?.accessToken;
      if (token == null) throw Exception('Not authenticated');

      // Build query parameters
      final queryParams = <String, String>{
        'limit': limit.toString(),
        'offset': offset.toString(),
      };
      
      if (category != null) queryParams['category'] = category;
      if (animalId != null) queryParams['animal_id'] = animalId;
      if (startDate != null) queryParams['start_date'] = startDate.toIso8601String();
      if (endDate != null) queryParams['end_date'] = endDate.toIso8601String();
      if (tags != null && tags.isNotEmpty) queryParams['tags'] = tags.join(',');

      final uri = Uri.parse(ApiConfig.journalList)
          .replace(queryParameters: queryParams);

      final response = await http.get(
        uri,
        headers: ApiConfig.getDefaultHeaders(authToken: token),
      ).timeout(ApiConfig.requestTimeout);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final entries = (data['data'] as List)
            .map((json) => JournalEntry.fromJson(json))
            .toList();
        return entries;
      } else {
        throw Exception('Failed to fetch entries: ${response.statusCode} ${response.body}');
      }
    } catch (e) {
      print('Error fetching entries: $e');
      throw Exception('Failed to fetch journal entries: ${e.toString()}');
    }
  }

  /// Get a single journal entry by ID
  static Future<JournalEntry?> getEntry(String id) async {
    final currentUser = _supabase.auth.currentUser;
    if (currentUser == null) {
      throw Exception('User not authenticated');
    }

    try {
      final token = _supabase.auth.currentSession?.accessToken;
      if (token == null) throw Exception('Not authenticated');

      final response = await http.get(
        Uri.parse('${ApiConfig.journalGet}?id=$id'),
        headers: ApiConfig.getDefaultHeaders(authToken: token),
      ).timeout(ApiConfig.requestTimeout);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return JournalEntry.fromJson(data['data']);
      } else if (response.statusCode == 404) {
        return null;
      } else {
        throw Exception('Failed to fetch entry: ${response.statusCode} ${response.body}');
      }
    } catch (e) {
      print('Error fetching entry: $e');
      throw Exception('Failed to fetch journal entry: ${e.toString()}');
    }
  }

  /// Search journal entries
  static Future<List<JournalEntry>> searchEntries({
    required String query,
    String? category,
    String? animalId,
    List<String>? tags,
    int limit = 50,
  }) async {
    final currentUser = _supabase.auth.currentUser;
    if (currentUser == null) {
      throw Exception('User not authenticated');
    }

    try {
      // Get all entries and filter locally
      // In a production app, you'd want server-side search
      final allEntries = await getEntries(limit: 1000);
      
      return allEntries.where((entry) {
        // Text search in title and description
        final matchesQuery = query.isEmpty ||
            entry.title.toLowerCase().contains(query.toLowerCase()) ||
            entry.description.toLowerCase().contains(query.toLowerCase());
        
        // Category filter
        final matchesCategory = category == null || entry.category == category;
        
        // Animal filter  
        final matchesAnimal = animalId == null || entry.animalId == animalId;
        
        // Tags filter
        final matchesTags = tags == null || tags.isEmpty ||
            tags.every((tag) => entry.tags?.contains(tag) == true);
        
        return matchesQuery && matchesCategory && matchesAnimal && matchesTags;
      }).take(limit).toList();
    } catch (e) {
      print('Error searching entries: $e');
      throw Exception('Failed to search journal entries: ${e.toString()}');
    }
  }

  /// Get journal statistics
  static Future<Map<String, dynamic>> getJournalStatistics() async {
    final currentUser = _supabase.auth.currentUser;
    if (currentUser == null) {
      throw Exception('User not authenticated');
    }

    try {
      final entries = await getEntries(limit: 1000);
      
      return {
        'totalEntries': entries.length,
        'totalHours': entries.fold<double>(0, (sum, entry) => sum + entry.duration),
        'averageQuality': entries.isNotEmpty 
            ? entries.fold<double>(0, (sum, entry) => sum + (entry.qualityScore ?? 0)) / entries.length
            : 0.0,
        'categoriesCount': entries.map((e) => e.category).toSet().length,
        'recentEntries': entries.take(5).length,
      };
    } catch (e) {
      print('Error getting statistics: $e');
      return {
        'totalEntries': 0,
        'totalHours': 0.0,
        'averageQuality': 0.0,
        'categoriesCount': 0,
        'recentEntries': 0,
      };
    }
  }

  /// Process journal entry with enhanced AI asynchronously
  static void _processWithEnhancedAIAsync(JournalEntry entry) {
    // Don't await this - let it run in background
    _processWithEnhancedAI(entry).catchError((e) {
      print('Background AI processing failed: $e');
    });
  }

  /// Process journal entry with enhanced AI
  static Future<void> _processWithEnhancedAI(JournalEntry entry) async {
    try {
      await N8NWebhookService.sendJournalEntry(entry);
      print('✅ Journal entry sent to N8N for AI processing');
    } catch (e) {
      print('❌ Failed to send journal entry to N8N: $e');
      // Don't throw error - AI processing is optional
    }
  }

  /// Get FFA degree progress for user
  static Future<Map<String, dynamic>> getFfaDegreeProgress() async {
    final currentUser = _supabase.auth.currentUser;
    if (currentUser == null) {
      throw Exception('User not authenticated');
    }

    try {
      final entries = await getEntries(limit: 1000);
      
      // Calculate FFA degree requirements progress
      final saEntries = entries.where((e) => e.saType != null).toList();
      final totalSAHours = saEntries.fold<double>(0, (sum, entry) => sum + (entry.hoursLogged ?? 0));
      final totalSAValue = saEntries.fold<double>(0, (sum, entry) => sum + (entry.financialValue ?? 0));
      
      return {
        'saProjects': saEntries.length,
        'saHours': totalSAHours,
        'saValue': totalSAValue,
        'greenhandReady': saEntries.length >= 1 && totalSAHours >= 150,
        'chapterReady': saEntries.length >= 2 && totalSAHours >= 300 && totalSAValue >= 1000,
        'stateReady': saEntries.length >= 3 && totalSAHours >= 540 && totalSAValue >= 10000,
      };
    } catch (e) {
      print('Error calculating FFA progress: $e');
      return {
        'saProjects': 0,
        'saHours': 0.0,
        'saValue': 0.0,
        'greenhandReady': false,
        'chapterReady': false,
        'stateReady': false,
      };
    }
  }

  // ============================================================================
  // AI ASSESSMENT INTEGRATION METHODS
  // ============================================================================

  /// Get AI assessment for a journal entry
  static Future<AiAssessment?> getAiAssessment(String journalEntryId) async {
    try {
      return await _aiAssessmentService.getAssessmentForJournalEntry(journalEntryId);
    } catch (e) {
      print('Error fetching AI assessment for journal entry $journalEntryId: $e');
      return null;
    }
  }

  /// Check if a journal entry has an AI assessment
  static Future<bool> hasAiAssessment(String journalEntryId) async {
    try {
      return await _aiAssessmentService.hasAssessment(journalEntryId);
    } catch (e) {
      print('Error checking AI assessment for journal entry $journalEntryId: $e');
      return false;
    }
  }

  /// Get AI assessment status by trace ID
  static Future<Map<String, dynamic>?> getAssessmentStatus(String traceId) async {
    try {
      return await _aiAssessmentService.getAssessmentStatus(traceId);
    } catch (e) {
      print('Error fetching assessment status for trace ID $traceId: $e');
      return null;
    }
  }

  /// Get competency progress for the current user
  static Future<List<CompetencyProgress>> getCompetencyProgress({int daysBack = 30}) async {
    final currentUser = _supabase.auth.currentUser;
    if (currentUser == null) {
      throw Exception('User not authenticated');
    }

    try {
      return await _aiAssessmentService.getCompetencyProgress(currentUser.id, daysBack: daysBack);
    } catch (e) {
      print('Error fetching competency progress: $e');
      return [];
    }
  }

  /// Get high quality assessed entries for the current user
  static Future<List<AiAssessment>> getHighQualityAssessments({
    double minQualityScore = 8.0,
    int limit = 10,
  }) async {
    final currentUser = _supabase.auth.currentUser;
    if (currentUser == null) {
      throw Exception('User not authenticated');
    }

    try {
      return await _aiAssessmentService.getHighQualityAssessments(
        currentUser.id,
        minQualityScore: minQualityScore,
        limit: limit,
      );
    } catch (e) {
      print('Error fetching high quality assessments: $e');
      return [];
    }
  }

  /// Search assessments by competency for the current user
  static Future<List<AiAssessment>> searchAssessmentsByCompetency(String competencyCode) async {
    final currentUser = _supabase.auth.currentUser;
    if (currentUser == null) {
      throw Exception('User not authenticated');
    }

    try {
      return await _aiAssessmentService.searchAssessmentsByCompetency(currentUser.id, competencyCode);
    } catch (e) {
      print('Error searching assessments by competency: $e');
      return [];
    }
  }

  /// Get comprehensive assessment statistics for the current user
  static Future<Map<String, dynamic>> getAssessmentStatistics() async {
    final currentUser = _supabase.auth.currentUser;
    if (currentUser == null) {
      throw Exception('User not authenticated');
    }

    try {
      return await _aiAssessmentService.getAssessmentStatistics(currentUser.id);
    } catch (e) {
      print('Error fetching assessment statistics: $e');
      return {
        'totalAssessments': 0,
        'averageQualityScore': 0.0,
        'averageEngagementScore': 0.0,
        'averageLearningDepthScore': 0.0,
        'totalCompetencies': 0,
        'totalFfaStandards': 0,
        'totalStrengths': 0,
        'totalRecommendations': 0,
        'assessmentTrend': 'Error',
      };
    }
  }

  /// Get all AI assessments for the current user
  static Future<List<AiAssessment>> getUserAiAssessments({
    int limit = 50,
    int offset = 0,
  }) async {
    final currentUser = _supabase.auth.currentUser;
    if (currentUser == null) {
      throw Exception('User not authenticated');
    }

    try {
      return await _aiAssessmentService.getAssessmentsForUser(
        currentUser.id,
        limit: limit,
        offset: offset,
      );
    } catch (e) {
      print('Error fetching user AI assessments: $e');
      return [];
    }
  }

  /// Get enhanced FFA degree progress with AI assessment data
  static Future<Map<String, dynamic>> getEnhancedFfaDegreeProgress() async {
    final currentUser = _supabase.auth.currentUser;
    if (currentUser == null) {
      throw Exception('User not authenticated');
    }

    try {
      // Get basic FFA progress
      final basicProgress = await getFfaDegreeProgress();
      
      // Get AI assessment statistics
      final assessmentStats = await getAssessmentStatistics();
      
      // Get competency progress
      final competencyProgress = await getCompetencyProgress(daysBack: 365);
      
      // Calculate enhanced metrics
      final proficientCompetencies = competencyProgress
          .where((cp) => cp.progressTrend == 'Consistent' || cp.progressTrend == 'Proficient')
          .length;
      
      final averageCompetencyScore = competencyProgress.isNotEmpty
          ? competencyProgress
              .where((cp) => cp.avgQualityScore != null)
              .map((cp) => cp.avgQualityScore!)
              .reduce((a, b) => a + b) / competencyProgress.length
          : 0.0;

      return {
        ...basicProgress,
        // AI-enhanced metrics
        'totalAiAssessments': assessmentStats['totalAssessments'],
        'averageQualityScore': assessmentStats['averageQualityScore'],
        'proficientCompetencies': proficientCompetencies,
        'totalCompetenciesTracked': competencyProgress.length,
        'averageCompetencyScore': averageCompetencyScore,
        'assessmentTrend': assessmentStats['assessmentTrend'],
        'hasAiInsights': assessmentStats['totalAssessments'] > 0,
        // Quality gates with AI criteria
        'greenhandReadyAi': (basicProgress['greenhandReady'] as bool) && 
                           averageCompetencyScore >= 6.0,
        'chapterReadyAi': (basicProgress['chapterReady'] as bool) && 
                         averageCompetencyScore >= 7.0 && 
                         proficientCompetencies >= 3,
        'stateReadyAi': (basicProgress['stateReady'] as bool) && 
                       averageCompetencyScore >= 8.0 && 
                       proficientCompetencies >= 5,
      };
    } catch (e) {
      print('Error calculating enhanced FFA progress: $e');
      // Fallback to basic progress
      return await getFfaDegreeProgress();
    }
  }
}