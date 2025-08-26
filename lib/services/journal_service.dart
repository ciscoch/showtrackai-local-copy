import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import '../models/journal_entry.dart';
import 'n8n_webhook_service.dart';

/// Comprehensive journal service with offline-first capability
/// Handles CRUD operations, AI processing, search, and sync with Supabase
class JournalService {
  static const String _baseUrl = 'https://mellifluous-speculoos-46225c.netlify.app';
  static const String _n8nWebhookUrl = 'https://showtrackai.app.n8n.cloud/webhook/4b52c2de-4d37-4752-aa5c-5741bd9e493d';
  static const String _offlineQueueKey = 'journal_offline_queue';
  static const String _offlineEntriesKey = 'journal_offline_entries';
  static const String _lastSyncKey = 'journal_last_sync';
  
  static final _supabase = Supabase.instance.client;
  static final _uuid = const Uuid();

  /// Create a new journal entry with offline support
  static Future<JournalEntry> createEntry(JournalEntry entry) async {
    try {
      // Generate ID if not provided
      final entryWithId = JournalEntry(
        id: entry.id ?? _uuid.v4(),
        userId: entry.userId,
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
        isSynced: false,
      );

      // Try online creation first
      if (await _isOnline()) {
        try {
          final token = _supabase.auth.currentSession?.accessToken;
          if (token == null) throw Exception('Not authenticated');

          final response = await http.post(
            Uri.parse('$_baseUrl/.netlify/functions/journal-create'),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $token',
            },
            body: jsonEncode(entryWithId.toJson()),
          ).timeout(const Duration(seconds: 10));

          if (response.statusCode == 201) {
            final data = jsonDecode(response.body);
            final syncedEntry = JournalEntry.fromJson(data['data']).copyWith(isSynced: true);
            
            // Store locally for offline access
            await _storeEntryLocally(syncedEntry);
            
            // Trigger enhanced AI processing asynchronously
            _processWithEnhancedAIAsync(syncedEntry);
            
            return syncedEntry;
          }
        } catch (e) {
          // Fall through to offline storage
          print('Online creation failed: $e');
        }
      }

      // Store offline and add to sync queue
      await _storeEntryLocally(entryWithId);
      await _addToOfflineQueue('create', entryWithId);
      
      return entryWithId;
    } catch (e) {
      throw Exception('Error creating journal entry: $e');
    }
  }

  /// Get all journal entries with offline support and filtering
  static Future<List<JournalEntry>> getEntries({
    int limit = 20,
    int offset = 0,
    String? category,
    String? animalId,
    DateTime? startDate,
    DateTime? endDate,
    List<String>? tags,
    bool onlineFirst = true,
  }) async {
    try {
      List<JournalEntry> entries = [];

      // Try online first if requested and available
      if (onlineFirst && await _isOnline()) {
        try {
          entries = await _fetchEntriesOnline(
            limit: limit,
            offset: offset,
            category: category,
            animalId: animalId,
            startDate: startDate,
            endDate: endDate,
            tags: tags,
          );
          
          // Update local storage with online data
          for (final entry in entries) {
            await _storeEntryLocally(entry);
          }
          
          return entries;
        } catch (e) {
          print('Online fetch failed: $e');
        }
      }

      // Fallback to offline data
      entries = await _getEntriesFromLocal(
        limit: limit,
        offset: offset,
        category: category,
        animalId: animalId,
        startDate: startDate,
        endDate: endDate,
        tags: tags,
      );

      return entries;
    } catch (e) {
      throw Exception('Error fetching entries: $e');
    }
  }

  /// Get a single journal entry by ID
  static Future<JournalEntry?> getEntry(String id) async {
    try {
      // Try local first for better performance
      final localEntry = await _getEntryFromLocal(id);
      if (localEntry != null && localEntry.isSynced) {
        return localEntry;
      }

      // Try online if local is not synced or doesn't exist
      if (await _isOnline()) {
        try {
          final token = _supabase.auth.currentSession?.accessToken;
          if (token != null) {
            final response = await http.get(
              Uri.parse('$_baseUrl/.netlify/functions/journal-get?id=$id'),
              headers: {'Authorization': 'Bearer $token'},
            ).timeout(const Duration(seconds: 5));

            if (response.statusCode == 200) {
              final data = jsonDecode(response.body);
              final entry = JournalEntry.fromJson(data['data']).copyWith(isSynced: true);
              await _storeEntryLocally(entry);
              return entry;
            }
          }
        } catch (e) {
          print('Online fetch failed: $e');
        }
      }

      return localEntry;
    } catch (e) {
      throw Exception('Error fetching entry: $e');
    }
  }

  /// Update a journal entry
  static Future<JournalEntry> updateEntry(JournalEntry entry) async {
    try {
      final updatedEntry = entry.copyWith(
        updatedAt: DateTime.now(),
        isSynced: false,
      );

      // Try online update first
      if (await _isOnline()) {
        try {
          final token = _supabase.auth.currentSession?.accessToken;
          if (token != null) {
            final response = await http.put(
              Uri.parse('$_baseUrl/.netlify/functions/journal-update'),
              headers: {
                'Content-Type': 'application/json',
                'Authorization': 'Bearer $token',
              },
              body: jsonEncode(updatedEntry.toJson()),
            ).timeout(const Duration(seconds: 10));

            if (response.statusCode == 200) {
              final data = jsonDecode(response.body);
              final syncedEntry = JournalEntry.fromJson(data['data']).copyWith(isSynced: true);
              await _storeEntryLocally(syncedEntry);
              return syncedEntry;
            }
          }
        } catch (e) {
          print('Online update failed: $e');
        }
      }

      // Store offline and add to sync queue
      await _storeEntryLocally(updatedEntry);
      await _addToOfflineQueue('update', updatedEntry);
      
      return updatedEntry;
    } catch (e) {
      throw Exception('Error updating entry: $e');
    }
  }

  /// Delete a journal entry
  static Future<void> deleteEntry(String id) async {
    try {
      // Try online delete first
      if (await _isOnline()) {
        try {
          final token = _supabase.auth.currentSession?.accessToken;
          if (token != null) {
            final response = await http.delete(
              Uri.parse('$_baseUrl/.netlify/functions/journal-delete?id=$id'),
              headers: {'Authorization': 'Bearer $token'},
            ).timeout(const Duration(seconds: 10));

            if (response.statusCode == 200) {
              await _removeEntryFromLocal(id);
              return;
            }
          }
        } catch (e) {
          print('Online delete failed: $e');
        }
      }

      // Add to offline queue for later sync
      await _addToOfflineQueue('delete', JournalEntry(
        id: id,
        userId: _supabase.auth.currentUser?.id ?? '',
        title: '',
        description: '',
        date: DateTime.now(),
        duration: 0,
        category: '',
        aetSkills: [],
      ));
      
      // Mark as deleted locally
      await _markEntryAsDeleted(id);
    } catch (e) {
      throw Exception('Error deleting entry: $e');
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
    try {
      final allEntries = await getEntries(limit: 1000, onlineFirst: false);
      
      return allEntries.where((entry) {
        // Text search in title and description
        final matchesQuery = query.isEmpty ||
            entry.title.toLowerCase().contains(query.toLowerCase()) ||
            entry.description.toLowerCase().contains(query.toLowerCase()) ||
            (entry.challenges?.toLowerCase().contains(query.toLowerCase()) ?? false) ||
            (entry.improvements?.toLowerCase().contains(query.toLowerCase()) ?? false);

        // Category filter
        final matchesCategory = category == null || entry.category == category;

        // Animal filter
        final matchesAnimal = animalId == null || entry.animalId == animalId;

        // Tags filter
        final matchesTags = tags == null || tags.isEmpty ||
            (entry.tags?.any((tag) => tags.contains(tag)) ?? false);

        return matchesQuery && matchesCategory && matchesAnimal && matchesTags;
      }).take(limit).toList();
    } catch (e) {
      throw Exception('Error searching entries: $e');
    }
  }

  /// Sync offline entries with server
  static Future<bool> syncOfflineEntries() async {
    try {
      if (!await _isOnline()) {
        return false;
      }

      final prefs = await SharedPreferences.getInstance();
      final queueJson = prefs.getString(_offlineQueueKey);
      if (queueJson == null) return true;

      final queue = List<Map<String, dynamic>>.from(jsonDecode(queueJson));
      final successfulSyncs = <Map<String, dynamic>>[];

      for (final item in queue) {
        try {
          final operation = item['operation'] as String;
          final entryData = item['entry'] as Map<String, dynamic>;
          final entry = JournalEntry.fromJson(entryData);

          bool success = false;
          switch (operation) {
            case 'create':
              await _syncCreateEntry(entry);
              success = true;
              break;
            case 'update':
              await _syncUpdateEntry(entry);
              success = true;
              break;
            case 'delete':
              await _syncDeleteEntry(entry.id!);
              success = true;
              break;
          }

          if (success) {
            successfulSyncs.add(item);
          }
        } catch (e) {
          print('Failed to sync item: $e');
          // Continue with other items
        }
      }

      // Remove successfully synced items from queue
      if (successfulSyncs.isNotEmpty) {
        final remainingQueue = queue.where((item) => !successfulSyncs.contains(item)).toList();
        await prefs.setString(_offlineQueueKey, jsonEncode(remainingQueue));
        await prefs.setString(_lastSyncKey, DateTime.now().toIso8601String());
      }

      return successfulSyncs.length == queue.length;
    } catch (e) {
      print('Sync error: $e');
      return false;
    }
  }

  /// Enhanced AI processing for journal entries
  static Future<N8NAnalysisResult> processWithAI(String entryId) async {
    final entry = await getEntry(entryId);
    if (entry == null) {
      throw Exception('Entry not found');
    }

    return await N8NWebhookService.processJournalEntry(entry);
  }

  /// Trigger AI processing and return result
  static Future<N8NAnalysisResult?> processWithAIAndReturn(JournalEntry entry) async {
    try {
      final result = await N8NWebhookService.processJournalEntry(entry);
      return result;
    } catch (e) {
      print('AI processing failed: $e');
      return null;
    }
  }

  /// Process retry queue for failed AI requests
  static Future<void> processAIRetryQueue() async {
    await N8NWebhookService.processRetryQueue();
  }

  /// Get user statistics
  static Future<JournalStats> getUserStats() async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) throw Exception('Not authenticated');

      // Get all entries for stats calculation
      final entries = await getEntries(limit: 10000, onlineFirst: false);
      
      int totalEntries = entries.length;
      double totalHours = entries.fold<int>(0, (sum, e) => sum + e.duration) / 60.0;
      double averageScore = entries.isEmpty ? 0 : 
          entries.where((e) => e.qualityScore != null)
                 .fold(0.0, (sum, e) => sum + (e.qualityScore ?? 0)) / 
          entries.where((e) => e.qualityScore != null).length;
      
      // Calculate streak
      int streak = _calculateStreak(entries);

      // Additional agricultural stats
      Map<String, int> categoryCount = {};
      Map<String, double> categoryHours = {};
      int ffaDegreeEntries = entries.where((e) => e.countsForDegree).length;
      double totalFinancialValue = entries
          .where((e) => e.financialValue != null)
          .fold(0.0, (sum, e) => sum + (e.financialValue ?? 0));

      for (final entry in entries) {
        categoryCount[entry.category] = (categoryCount[entry.category] ?? 0) + 1;
        categoryHours[entry.category] = (categoryHours[entry.category] ?? 0) + (entry.duration / 60.0);
      }

      return JournalStats(
        totalEntries: totalEntries,
        totalHours: totalHours,
        currentStreak: streak,
        averageQualityScore: averageScore,
        categoryBreakdown: categoryCount,
        categoryHours: categoryHours,
        ffaDegreeEntries: ffaDegreeEntries,
        totalFinancialValue: totalFinancialValue,
        lastSyncTime: await _getLastSyncTime(),
        pendingSyncCount: await _getPendingSyncCount(),
      );
    } catch (e) {
      // Return empty stats on error
      return JournalStats(
        totalEntries: 0,
        totalHours: 0,
        currentStreak: 0,
        averageQualityScore: 0,
        categoryBreakdown: {},
        categoryHours: {},
        ffaDegreeEntries: 0,
        totalFinancialValue: 0,
        lastSyncTime: null,
        pendingSyncCount: 0,
      );
    }
  }

  /// Get analytics data
  static Future<Map<String, dynamic>> getAnalytics() async {
    try {
      final stats = await getUserStats();
      final entries = await getEntries(limit: 1000, onlineFirst: false);
      
      // Weekly activity analysis
      final now = DateTime.now();
      final weeklyActivity = <String, int>{};
      
      for (int i = 6; i >= 0; i--) {
        final date = now.subtract(Duration(days: i));
        final dateKey = '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
        final dayEntries = entries.where((e) => 
            e.date.year == date.year &&
            e.date.month == date.month &&
            e.date.day == date.day
        ).length;
        weeklyActivity[dateKey] = dayEntries;
      }

      // Skill progression
      final skillCount = <String, int>{};
      for (final entry in entries) {
        for (final skill in entry.aetSkills) {
          skillCount[skill] = (skillCount[skill] ?? 0) + 1;
        }
      }

      return {
        'stats': stats.toJson(),
        'weeklyActivity': weeklyActivity,
        'skillProgression': skillCount,
        'recentEntries': entries.take(5).map((e) => e.toJson()).toList(),
        'topCategories': stats.categoryBreakdown.entries
            .toList()
            ..sort((a, b) => b.value.compareTo(a.value))
            ..take(5),
      };
    } catch (e) {
      throw Exception('Error fetching analytics: $e');
    }
  }

  // Private helper methods

  static Future<bool> _isOnline() async {
    try {
      final result = await InternetAddress.lookup('google.com');
      return result.isNotEmpty && result[0].rawAddress.isNotEmpty;
    } on SocketException catch (_) {
      return false;
    }
  }

  static Future<void> _processWithEnhancedAIAsync(JournalEntry entry) async {
    try {
      await N8NWebhookService.processJournalEntry(entry);
    } catch (e) {
      print('Async AI processing failed for ${entry.id}: $e');
    }
  }

  static Future<List<JournalEntry>> _fetchEntriesOnline({
    int limit = 20,
    int offset = 0,
    String? category,
    String? animalId,
    DateTime? startDate,
    DateTime? endDate,
    List<String>? tags,
  }) async {
    final token = _supabase.auth.currentSession?.accessToken;
    if (token == null) throw Exception('Not authenticated');

    final queryParams = <String, String>{
      'limit': limit.toString(),
      'offset': offset.toString(),
      if (category != null) 'category': category,
      if (animalId != null) 'animalId': animalId,
      if (startDate != null) 'startDate': startDate.toIso8601String(),
      if (endDate != null) 'endDate': endDate.toIso8601String(),
      if (tags != null && tags.isNotEmpty) 'tags': tags.join(','),
    };

    final uri = Uri.parse('$_baseUrl/.netlify/functions/journal-list')
        .replace(queryParameters: queryParams);

    final response = await http.get(
      uri,
      headers: {'Authorization': 'Bearer $token'},
    ).timeout(const Duration(seconds: 10));

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final List entries = data['data'] ?? [];
      return entries.map((e) => JournalEntry.fromJson(e).copyWith(isSynced: true)).toList();
    } else {
      throw Exception('Failed to fetch entries: ${response.body}');
    }
  }

  static Future<void> _storeEntryLocally(JournalEntry entry) async {
    final prefs = await SharedPreferences.getInstance();
    final entriesJson = prefs.getString(_offlineEntriesKey);
    
    Map<String, dynamic> entries = {};
    if (entriesJson != null) {
      entries = Map<String, dynamic>.from(jsonDecode(entriesJson));
    }
    
    entries[entry.id!] = entry.toJson();
    await prefs.setString(_offlineEntriesKey, jsonEncode(entries));
  }

  static Future<JournalEntry?> _getEntryFromLocal(String id) async {
    final prefs = await SharedPreferences.getInstance();
    final entriesJson = prefs.getString(_offlineEntriesKey);
    
    if (entriesJson != null) {
      final entries = Map<String, dynamic>.from(jsonDecode(entriesJson));
      final entryData = entries[id];
      if (entryData != null) {
        return JournalEntry.fromJson(entryData);
      }
    }
    
    return null;
  }

  static Future<List<JournalEntry>> _getEntriesFromLocal({
    int limit = 20,
    int offset = 0,
    String? category,
    String? animalId,
    DateTime? startDate,
    DateTime? endDate,
    List<String>? tags,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final entriesJson = prefs.getString(_offlineEntriesKey);
    
    if (entriesJson == null) return [];
    
    final entriesMap = Map<String, dynamic>.from(jsonDecode(entriesJson));
    List<JournalEntry> entries = entriesMap.values
        .map((data) => JournalEntry.fromJson(data))
        .where((entry) => entry.syncError != 'deleted') // Filter out deleted entries
        .toList();

    // Apply filters
    entries = entries.where((entry) {
      if (category != null && entry.category != category) return false;
      if (animalId != null && entry.animalId != animalId) return false;
      if (startDate != null && entry.date.isBefore(startDate)) return false;
      if (endDate != null && entry.date.isAfter(endDate)) return false;
      if (tags != null && tags.isNotEmpty && (entry.tags == null || 
          !tags.any((tag) => entry.tags!.contains(tag)))) return false;
      return true;
    }).toList();

    // Sort by date (newest first)
    entries.sort((a, b) => b.date.compareTo(a.date));

    // Apply pagination
    if (offset >= entries.length) return [];
    final end = (offset + limit).clamp(0, entries.length);
    return entries.sublist(offset, end);
  }

  static Future<void> _removeEntryFromLocal(String id) async {
    final prefs = await SharedPreferences.getInstance();
    final entriesJson = prefs.getString(_offlineEntriesKey);
    
    if (entriesJson != null) {
      final entries = Map<String, dynamic>.from(jsonDecode(entriesJson));
      entries.remove(id);
      await prefs.setString(_offlineEntriesKey, jsonEncode(entries));
    }
  }

  static Future<void> _markEntryAsDeleted(String id) async {
    final entry = await _getEntryFromLocal(id);
    if (entry != null) {
      final deletedEntry = entry.copyWith(syncError: 'deleted');
      await _storeEntryLocally(deletedEntry);
    }
  }

  static Future<void> _addToOfflineQueue(String operation, JournalEntry entry) async {
    final prefs = await SharedPreferences.getInstance();
    final queueJson = prefs.getString(_offlineQueueKey);
    
    List<Map<String, dynamic>> queue = [];
    if (queueJson != null) {
      queue = List<Map<String, dynamic>>.from(jsonDecode(queueJson));
    }
    
    queue.add({
      'operation': operation,
      'entry': entry.toJson(),
      'timestamp': DateTime.now().toIso8601String(),
    });
    
    await prefs.setString(_offlineQueueKey, jsonEncode(queue));
  }

  static Future<void> _syncCreateEntry(JournalEntry entry) async {
    final token = _supabase.auth.currentSession?.accessToken;
    if (token == null) throw Exception('Not authenticated');

    final response = await http.post(
      Uri.parse('$_baseUrl/.netlify/functions/journal-create'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode(entry.toJson()),
    ).timeout(const Duration(seconds: 30));

    if (response.statusCode == 201) {
      final data = jsonDecode(response.body);
      final syncedEntry = JournalEntry.fromJson(data['data']).copyWith(isSynced: true);
      await _storeEntryLocally(syncedEntry);
    } else {
      throw Exception('Failed to sync create: ${response.body}');
    }
  }

  static Future<void> _syncUpdateEntry(JournalEntry entry) async {
    final token = _supabase.auth.currentSession?.accessToken;
    if (token == null) throw Exception('Not authenticated');

    final response = await http.put(
      Uri.parse('$_baseUrl/.netlify/functions/journal-update'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode(entry.toJson()),
    ).timeout(const Duration(seconds: 30));

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final syncedEntry = JournalEntry.fromJson(data['data']).copyWith(isSynced: true);
      await _storeEntryLocally(syncedEntry);
    } else {
      throw Exception('Failed to sync update: ${response.body}');
    }
  }

  static Future<void> _syncDeleteEntry(String id) async {
    final token = _supabase.auth.currentSession?.accessToken;
    if (token == null) throw Exception('Not authenticated');

    final response = await http.delete(
      Uri.parse('$_baseUrl/.netlify/functions/journal-delete?id=$id'),
      headers: {'Authorization': 'Bearer $token'},
    ).timeout(const Duration(seconds: 30));

    if (response.statusCode == 200) {
      await _removeEntryFromLocal(id);
    } else {
      throw Exception('Failed to sync delete: ${response.body}');
    }
  }

  static int _calculateStreak(List<JournalEntry> entries) {
    if (entries.isEmpty) return 0;

    // Sort by date (newest first)
    entries.sort((a, b) => b.date.compareTo(a.date));

    int streak = 0;
    DateTime? lastDate;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    for (var entry in entries) {
      final entryDate = DateTime(entry.date.year, entry.date.month, entry.date.day);

      if (lastDate == null) {
        // Check if the most recent entry is from today or yesterday
        final dayDiff = today.difference(entryDate).inDays;
        if (dayDiff <= 1) {
          streak = 1;
          lastDate = entryDate;
        } else {
          break; // Streak broken
        }
      } else {
        final dayDiff = lastDate.difference(entryDate).inDays;
        if (dayDiff == 1) {
          // Consecutive day
          streak++;
          lastDate = entryDate;
        } else if (dayDiff == 0) {
          // Same day, continue
          continue;
        } else {
          // Streak broken
          break;
        }
      }
    }

    return streak;
  }

  static Future<DateTime?> _getLastSyncTime() async {
    final prefs = await SharedPreferences.getInstance();
    final syncTimeString = prefs.getString(_lastSyncKey);
    return syncTimeString != null ? DateTime.parse(syncTimeString) : null;
  }

  static Future<int> _getPendingSyncCount() async {
    final prefs = await SharedPreferences.getInstance();
    final queueJson = prefs.getString(_offlineQueueKey);
    if (queueJson == null) return 0;
    
    final queue = List<Map<String, dynamic>>.from(jsonDecode(queueJson));
    return queue.length;
  }
}

/// Enhanced journal statistics with agricultural focus
class JournalStats {
  final int totalEntries;
  final double totalHours;
  final int currentStreak;
  final double averageQualityScore;
  final Map<String, int> categoryBreakdown;
  final Map<String, double> categoryHours;
  final int ffaDegreeEntries;
  final double totalFinancialValue;
  final DateTime? lastSyncTime;
  final int pendingSyncCount;

  JournalStats({
    required this.totalEntries,
    required this.totalHours,
    required this.currentStreak,
    required this.averageQualityScore,
    required this.categoryBreakdown,
    required this.categoryHours,
    required this.ffaDegreeEntries,
    required this.totalFinancialValue,
    this.lastSyncTime,
    required this.pendingSyncCount,
  });

  Map<String, dynamic> toJson() => {
        'totalEntries': totalEntries,
        'totalHours': totalHours,
        'currentStreak': currentStreak,
        'averageQualityScore': averageQualityScore,
        'categoryBreakdown': categoryBreakdown,
        'categoryHours': categoryHours,
        'ffaDegreeEntries': ffaDegreeEntries,
        'totalFinancialValue': totalFinancialValue,
        'lastSyncTime': lastSyncTime?.toIso8601String(),
        'pendingSyncCount': pendingSyncCount,
      };
}

/// Extension methods for JournalEntry
extension JournalEntryExtensions on JournalEntry {
  JournalEntry copyWith({
    String? id,
    String? userId,
    String? title,
    String? description,
    DateTime? date,
    int? duration,
    String? category,
    List<String>? aetSkills,
    String? animalId,
    FeedData? feedData,
    List<String>? objectives,
    List<String>? learningOutcomes,
    String? challenges,
    String? improvements,
    List<String>? photos,
    int? qualityScore,
    List<String>? ffaStandards,
    List<String>? educationalConcepts,
    String? competencyLevel,
    AIInsights? aiInsights,
    DateTime? createdAt,
    DateTime? updatedAt,
    LocationData? locationData,
    WeatherData? weatherData,
    List<String>? attachmentUrls,
    List<String>? tags,
    String? supervisorId,
    bool? isPublic,
    CompetencyTracking? competencyTracking,
    String? ffaDegreeType,
    bool? countsForDegree,
    String? saType,
    double? hoursLogged,
    double? financialValue,
    String? evidenceType,
    bool? isSynced,
    DateTime? lastSyncAttempt,
    String? syncError,
  }) {
    return JournalEntry(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      title: title ?? this.title,
      description: description ?? this.description,
      date: date ?? this.date,
      duration: duration ?? this.duration,
      category: category ?? this.category,
      aetSkills: aetSkills ?? this.aetSkills,
      animalId: animalId ?? this.animalId,
      feedData: feedData ?? this.feedData,
      objectives: objectives ?? this.objectives,
      learningOutcomes: learningOutcomes ?? this.learningOutcomes,
      challenges: challenges ?? this.challenges,
      improvements: improvements ?? this.improvements,
      photos: photos ?? this.photos,
      qualityScore: qualityScore ?? this.qualityScore,
      ffaStandards: ffaStandards ?? this.ffaStandards,
      educationalConcepts: educationalConcepts ?? this.educationalConcepts,
      competencyLevel: competencyLevel ?? this.competencyLevel,
      aiInsights: aiInsights ?? this.aiInsights,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      locationData: locationData ?? this.locationData,
      weatherData: weatherData ?? this.weatherData,
      attachmentUrls: attachmentUrls ?? this.attachmentUrls,
      tags: tags ?? this.tags,
      supervisorId: supervisorId ?? this.supervisorId,
      isPublic: isPublic ?? this.isPublic,
      competencyTracking: competencyTracking ?? this.competencyTracking,
      ffaDegreeType: ffaDegreeType ?? this.ffaDegreeType,
      countsForDegree: countsForDegree ?? this.countsForDegree,
      saType: saType ?? this.saType,
      hoursLogged: hoursLogged ?? this.hoursLogged,
      financialValue: financialValue ?? this.financialValue,
      evidenceType: evidenceType ?? this.evidenceType,
      isSynced: isSynced ?? this.isSynced,
      lastSyncAttempt: lastSyncAttempt ?? this.lastSyncAttempt,
      syncError: syncError ?? this.syncError,
    );
  }
}