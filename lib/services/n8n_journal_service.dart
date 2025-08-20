import 'dart:convert';
import 'dart:math';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

/// Service to connect Flutter frontend to n8n Journaling_Agent_AI_Enhanced workflow
/// Connects to https://showtrackai.app.n8n.cloud/workflow/e06pF0MwCa0v1lCF
class N8NJournalService {
  // N8N Workflow endpoints
  static const String _baseUrl = 'https://showtrackai.app.n8n.cloud';
  static const String _directWebhook = '$_baseUrl/webhook/journaling-agent-ai-enhanced';
  static const String _orchestratorWebhook = '$_baseUrl/webhook/a9b86a3a-2baa-4485-8c86-8538202d7966';
  
  static final _supabase = Supabase.instance.client;
  static final _random = Random();

  /// Submit journal entry to n8n workflow for AI processing
  static Future<JournalProcessingResult> submitJournalEntry({
    required String animalId,
    required String entryText,
    required DateTime entryDate,
    String? animalType,
    List<String>? photos,
  }) async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) throw Exception('User not authenticated');

      // Generate unique request ID
      final requestId = 'journal_${DateTime.now().millisecondsSinceEpoch}_${user.id.substring(0, 8)}';

      // Prepare payload matching n8n workflow expectations
      final payload = {
        'userId': user.id,
        'animalId': animalId,
        'entryText': entryText,
        'entryDate': entryDate.toIso8601String(),
        'animalType': animalType ?? 'general',
        'photos': photos ?? [],
        'requestId': requestId,
      };

      // Call n8n workflow
      final response = await http.post(
        Uri.parse(_directWebhook),
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode(payload),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return JournalProcessingResult.fromJson(data);
      } else {
        throw Exception('N8N workflow failed: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      throw Exception('Error submitting to n8n workflow: $e');
    }
  }

  /// Get journal entries from Supabase (n8n stores them there)
  static Future<List<JournalEntry>> getJournalEntries({
    int limit = 20,
    int offset = 0,
    String? category,
  }) async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) throw Exception('User not authenticated');

      var query = _supabase
          .from('journal_entries')
          .select()
          .eq('user_id', user.id)
          .order('created_at', ascending: false)
          .range(offset, offset + limit - 1);

      if (category != null) {
        query = query.eq('category', category);
      }

      final response = await query;
      return (response as List)
          .map((e) => JournalEntry.fromSupabaseJson(e))
          .toList();
    } catch (e) {
      throw Exception('Error fetching journal entries: $e');
    }
  }

  /// Get analytics data from Supabase
  static Future<JournalAnalytics> getAnalytics() async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) throw Exception('User not authenticated');

      // Get user stats using the database function
      final statsResponse = await _supabase
          .rpc('get_user_journal_stats', params: {'user_uuid': user.id});

      final stats = statsResponse[0];

      // Get recent entries for additional analytics
      final recentEntries = await _supabase
          .from('journal_entries')
          .select('quality_score, ffa_standards, aet_skills, competency_level')
          .eq('user_id', user.id)
          .order('created_at', ascending: false)
          .limit(50);

      return JournalAnalytics(
        totalEntries: stats['total_entries'] ?? 0,
        totalHours: (stats['total_hours'] ?? 0).toDouble(),
        currentStreak: stats['current_streak'] ?? 0,
        averageQualityScore: (stats['average_quality_score'] ?? 0).toDouble(),
        uniqueSkillsCount: stats['unique_skills_count'] ?? 0,
        ffaStandards: _extractFFAStandards(recentEntries),
        competencyDistribution: _calculateCompetencyDistribution(recentEntries),
      );
    } catch (e) {
      // Return empty analytics on error
      return JournalAnalytics(
        totalEntries: 0,
        totalHours: 0,
        currentStreak: 0,
        averageQualityScore: 0,
        uniqueSkillsCount: 0,
        ffaStandards: [],
        competencyDistribution: {},
      );
    }
  }

  /// Get animals for journal entry selection
  static Future<List<Animal>> getUserAnimals() async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) throw Exception('User not authenticated');

      final response = await _supabase
          .from('animals')
          .select()
          .eq('user_id', user.id)
          .eq('status', 'active')
          .order('name');

      return (response as List)
          .map((e) => Animal.fromJson(e))
          .toList();
    } catch (e) {
      return []; // Return empty list on error
    }
  }

  // Helper methods
  static List<String> _extractFFAStandards(List<dynamic> entries) {
    final standards = <String>{};
    for (final entry in entries) {
      if (entry['ffa_standards'] != null) {
        standards.addAll(List<String>.from(entry['ffa_standards']));
      }
    }
    return standards.toList();
  }

  static Map<String, int> _calculateCompetencyDistribution(List<dynamic> entries) {
    final distribution = <String, int>{};
    for (final entry in entries) {
      final level = entry['competency_level'] as String?;
      if (level != null) {
        distribution[level] = (distribution[level] ?? 0) + 1;
      }
    }
    return distribution;
  }
}

/// Result from n8n workflow processing
class JournalProcessingResult {
  final String status;
  final String requestId;
  final bool processingComplete;
  final ProcessingResults results;
  final List<String> recommendations;

  JournalProcessingResult({
    required this.status,
    required this.requestId,
    required this.processingComplete,
    required this.results,
    required this.recommendations,
  });

  factory JournalProcessingResult.fromJson(Map<String, dynamic> json) {
    final data = json['data'] ?? {};
    final results = data['results'] ?? {};
    final recs = data['recommendations'] ?? {};

    return JournalProcessingResult(
      status: json['status'] ?? 'unknown',
      requestId: data['requestId'] ?? '',
      processingComplete: data['processingComplete'] ?? false,
      results: ProcessingResults.fromJson(results),
      recommendations: List<String>.from(recs['nextSteps'] ?? []),
    );
  }
}

class ProcessingResults {
  final int qualityScore;
  final String educationalValue;
  final bool ffaEligible;
  final bool aiProcessed;
  final int categoriesIdentified;
  final int ffaStandards;
  final int competencies;
  final int aetPoints;
  final String competencyLevel;

  ProcessingResults({
    required this.qualityScore,
    required this.educationalValue,
    required this.ffaEligible,
    required this.aiProcessed,
    required this.categoriesIdentified,
    required this.ffaStandards,
    required this.competencies,
    required this.aetPoints,
    required this.competencyLevel,
  });

  factory ProcessingResults.fromJson(Map<String, dynamic> json) {
    return ProcessingResults(
      qualityScore: json['qualityScore'] ?? 0,
      educationalValue: json['educationalValue'] ?? 'low',
      ffaEligible: json['ffaEligible'] ?? false,
      aiProcessed: json['aiProcessed'] ?? false,
      categoriesIdentified: json['categoriesIdentified'] ?? 0,
      ffaStandards: json['ffaStandards'] ?? 0,
      competencies: json['competencies'] ?? 0,
      aetPoints: json['aetPoints'] ?? 0,
      competencyLevel: json['competencyLevel'] ?? 'Beginner',
    );
  }
}

class JournalEntry {
  final String id;
  final String userId;
  final String animalId;
  final String entryText;
  final DateTime entryDate;
  final int? qualityScore;
  final List<String>? ffaStandards;
  final List<String>? aetSkills;
  final String? competencyLevel;
  final DateTime createdAt;

  JournalEntry({
    required this.id,
    required this.userId,
    required this.animalId,
    required this.entryText,
    required this.entryDate,
    this.qualityScore,
    this.ffaStandards,
    this.aetSkills,
    this.competencyLevel,
    required this.createdAt,
  });

  factory JournalEntry.fromSupabaseJson(Map<String, dynamic> json) {
    return JournalEntry(
      id: json['id'],
      userId: json['user_id'],
      animalId: json['animal_id'],
      entryText: json['entry_text'],
      entryDate: DateTime.parse(json['entry_date']),
      qualityScore: json['quality_score'],
      ffaStandards: json['ffa_standards'] != null
          ? List<String>.from(json['ffa_standards'])
          : null,
      aetSkills: json['aet_skills'] != null
          ? List<String>.from(json['aet_skills'])
          : null,
      competencyLevel: json['competency_level'],
      createdAt: DateTime.parse(json['created_at']),
    );
  }
}

class JournalAnalytics {
  final int totalEntries;
  final double totalHours;
  final int currentStreak;
  final double averageQualityScore;
  final int uniqueSkillsCount;
  final List<String> ffaStandards;
  final Map<String, int> competencyDistribution;

  JournalAnalytics({
    required this.totalEntries,
    required this.totalHours,
    required this.currentStreak,
    required this.averageQualityScore,
    required this.uniqueSkillsCount,
    required this.ffaStandards,
    required this.competencyDistribution,
  });
}

class Animal {
  final String id;
  final String name;
  final String species;
  final String? breed;
  final String? tagNumber;

  Animal({
    required this.id,
    required this.name,
    required this.species,
    this.breed,
    this.tagNumber,
  });

  factory Animal.fromJson(Map<String, dynamic> json) {
    return Animal(
      id: json['id'],
      name: json['name'],
      species: json['species'],
      breed: json['breed'],
      tagNumber: json['tag_number'],
    );
  }
}