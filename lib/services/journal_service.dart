import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/journal_entry.dart';

/// Service to connect to the Netlify-deployed API endpoints
/// This works with your existing mellifluous-speculoos-46225c.netlify.app deployment
class JournalService {
  static const String _baseUrl = 'https://mellifluous-speculoos-46225c.netlify.app';
  static final _supabase = Supabase.instance.client;

  /// Create a new journal entry
  static Future<JournalEntry> createEntry(JournalEntry entry) async {
    try {
      final token = _supabase.auth.currentSession?.accessToken;
      if (token == null) throw Exception('Not authenticated');

      final response = await http.post(
        Uri.parse('$_baseUrl/.netlify/functions/journal-create'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode(entry.toJson()),
      );

      if (response.statusCode == 201) {
        final data = jsonDecode(response.body);
        return JournalEntry.fromJson(data['data']);
      } else {
        throw Exception('Failed to create journal entry: ${response.body}');
      }
    } catch (e) {
      throw Exception('Error creating journal entry: $e');
    }
  }

  /// Get all journal entries for the current user
  static Future<List<JournalEntry>> getEntries({
    int limit = 20,
    int offset = 0,
    String? category,
  }) async {
    try {
      final token = _supabase.auth.currentSession?.accessToken;
      if (token == null) throw Exception('Not authenticated');

      final queryParams = {
        'limit': limit.toString(),
        'offset': offset.toString(),
        if (category != null) 'category': category,
      };

      final uri = Uri.parse('$_baseUrl/.netlify/functions/journal-list')
          .replace(queryParameters: queryParams);

      final response = await http.get(
        uri,
        headers: {
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final List entries = data['data'] ?? [];
        return entries.map((e) => JournalEntry.fromJson(e)).toList();
      } else {
        throw Exception('Failed to fetch entries: ${response.body}');
      }
    } catch (e) {
      throw Exception('Error fetching entries: $e');
    }
  }

  /// Get a single journal entry
  static Future<JournalEntry> getEntry(String id) async {
    try {
      final token = _supabase.auth.currentSession?.accessToken;
      if (token == null) throw Exception('Not authenticated');

      final response = await http.get(
        Uri.parse('$_baseUrl/.netlify/functions/journal-get?id=$id'),
        headers: {
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return JournalEntry.fromJson(data['data']);
      } else {
        throw Exception('Failed to fetch entry: ${response.body}');
      }
    } catch (e) {
      throw Exception('Error fetching entry: $e');
    }
  }

  /// Update a journal entry
  static Future<JournalEntry> updateEntry(JournalEntry entry) async {
    try {
      final token = _supabase.auth.currentSession?.accessToken;
      if (token == null) throw Exception('Not authenticated');

      final response = await http.put(
        Uri.parse('$_baseUrl/.netlify/functions/journal-update'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode(entry.toJson()),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return JournalEntry.fromJson(data['data']);
      } else {
        throw Exception('Failed to update entry: ${response.body}');
      }
    } catch (e) {
      throw Exception('Error updating entry: $e');
    }
  }

  /// Delete a journal entry
  static Future<void> deleteEntry(String id) async {
    try {
      final token = _supabase.auth.currentSession?.accessToken;
      if (token == null) throw Exception('Not authenticated');

      final response = await http.delete(
        Uri.parse('$_baseUrl/.netlify/functions/journal-delete?id=$id'),
        headers: {
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode != 200) {
        throw Exception('Failed to delete entry: ${response.body}');
      }
    } catch (e) {
      throw Exception('Error deleting entry: $e');
    }
  }

  /// Get analytics for the current user
  static Future<Map<String, dynamic>> getAnalytics() async {
    try {
      final token = _supabase.auth.currentSession?.accessToken;
      if (token == null) throw Exception('Not authenticated');

      final response = await http.get(
        Uri.parse('$_baseUrl/.netlify/functions/journal-analytics'),
        headers: {
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        throw Exception('Failed to fetch analytics: ${response.body}');
      }
    } catch (e) {
      throw Exception('Error fetching analytics: $e');
    }
  }

  /// Trigger AI processing for an entry
  static Future<void> processWithAI(String entryId) async {
    try {
      final token = _supabase.auth.currentSession?.accessToken;
      if (token == null) throw Exception('Not authenticated');

      final response = await http.post(
        Uri.parse('$_baseUrl/.netlify/functions/journal-ai-process'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({'entryId': entryId}),
      );

      if (response.statusCode != 200) {
        throw Exception('Failed to process with AI: ${response.body}');
      }
    } catch (e) {
      throw Exception('Error processing with AI: $e');
    }
  }

  /// Get user statistics
  static Future<JournalStats> getUserStats() async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) throw Exception('Not authenticated');

      // Fetch from Supabase directly for real-time stats
      final response = await _supabase
          .from('journal_entries')
          .select('id, quality_score, duration_minutes, created_at')
          .eq('user_id', userId);

      final entries = response as List;
      
      // Calculate stats
      int totalEntries = entries.length;
      double totalHours = entries.fold<int>(0, (sum, e) => sum + ((e['duration_minutes'] ?? 0) as int)) / 60;
      double averageScore = entries.isEmpty ? 0 : 
          entries.fold(0.0, (sum, e) => sum + (e['quality_score'] ?? 0)) / entries.length;
      
      // Calculate streak (simplified)
      int streak = _calculateStreak(entries);

      return JournalStats(
        totalEntries: totalEntries,
        totalHours: totalHours,
        currentStreak: streak,
        averageQualityScore: averageScore,
      );
    } catch (e) {
      // Return empty stats on error
      return JournalStats(
        totalEntries: 0,
        totalHours: 0,
        currentStreak: 0,
        averageQualityScore: 0,
      );
    }
  }

  static int _calculateStreak(List<dynamic> entries) {
    if (entries.isEmpty) return 0;

    // Sort by date
    entries.sort((a, b) => 
      DateTime.parse(b['created_at']).compareTo(DateTime.parse(a['created_at']))
    );

    int streak = 0;
    DateTime? lastDate;

    for (var entry in entries) {
      final date = DateTime.parse(entry['created_at']);
      final dateOnly = DateTime(date.year, date.month, date.day);

      if (lastDate == null) {
        // First entry
        streak = 1;
        lastDate = dateOnly;
      } else {
        final dayDiff = lastDate.difference(dateOnly).inDays;
        if (dayDiff == 1) {
          // Consecutive day
          streak++;
          lastDate = dateOnly;
        } else {
          // Streak broken
          break;
        }
      }
    }

    return streak;
  }
}

/// Journal statistics model
class JournalStats {
  final int totalEntries;
  final double totalHours;
  final int currentStreak;
  final double averageQualityScore;

  JournalStats({
    required this.totalEntries,
    required this.totalHours,
    required this.currentStreak,
    required this.averageQualityScore,
  });
}