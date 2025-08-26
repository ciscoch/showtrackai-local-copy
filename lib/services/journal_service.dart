import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import '../models/journal_entry.dart';
import 'n8n_webhook_service.dart';

/// Journal service for real-time database operations
/// Handles CRUD operations, AI processing, and search with Supabase
class JournalService {
  static const String _baseUrl = 'https://mellifluous-speculoos-46225c.netlify.app';
  static const String _n8nWebhookUrl = 'https://showtrackai.app.n8n.cloud/webhook/4b52c2de-4d37-4752-aa5c-5741bd9e493d';
  
  static final _supabase = Supabase.instance.client;
  static final _uuid = const Uuid();

  /// Create a new journal entry
  static Future<JournalEntry> createEntry(JournalEntry entry) async {
    final currentUser = _supabase.auth.currentUser;
    if (currentUser == null) {
      throw Exception('User not authenticated');
    }

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
      );

      final token = _supabase.auth.currentSession?.accessToken;
      if (token == null) throw Exception('Not authenticated');

      final response = await http.post(
        Uri.parse('$_baseUrl/.netlify/functions/journal-create'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode(entryWithId.toJson()),
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode == 201) {
        final data = jsonDecode(response.body);
        final createdEntry = JournalEntry.fromJson(data['data']);
        
        // Trigger enhanced AI processing asynchronously
        _processWithEnhancedAIAsync(createdEntry);
        
        return createdEntry;
      } else {
        throw Exception('Failed to create entry: ${response.statusCode} ${response.body}');
      }
    } catch (e) {
      print('Error creating entry: $e');
      throw Exception('Failed to create journal entry: ${e.toString()}');
    }
  }

  /// Update an existing journal entry
  static Future<JournalEntry> updateEntry(JournalEntry entry) async {
    final currentUser = _supabase.auth.currentUser;
    if (currentUser == null) {
      throw Exception('User not authenticated');
    }

    try {
      final updatedEntry = entry.copyWith(
        updatedAt: DateTime.now(),
        isSynced: true,
      );

      final token = _supabase.auth.currentSession?.accessToken;
      if (token == null) throw Exception('Not authenticated');

      final response = await http.put(
        Uri.parse('$_baseUrl/.netlify/functions/journal-update'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode(updatedEntry.toJson()),
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return JournalEntry.fromJson(data['data']);
      } else {
        throw Exception('Failed to update entry: ${response.statusCode} ${response.body}');
      }
    } catch (e) {
      print('Error updating entry: $e');
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
        Uri.parse('$_baseUrl/.netlify/functions/journal-delete?id=$id'),
        headers: {'Authorization': 'Bearer $token'},
      ).timeout(const Duration(seconds: 30));

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

      final uri = Uri.parse('$_baseUrl/.netlify/functions/journal-list')
          .replace(queryParameters: queryParams);

      final response = await http.get(
        uri,
        headers: {'Authorization': 'Bearer $token'},
      ).timeout(const Duration(seconds: 30));

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
        Uri.parse('$_baseUrl/.netlify/functions/journal-get?id=$id'),
        headers: {'Authorization': 'Bearer $token'},
      ).timeout(const Duration(seconds: 30));

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
}