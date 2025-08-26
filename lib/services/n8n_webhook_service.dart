import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/journal_entry.dart';

/// Service for sending journal entries to N8N webhook for AI processing
class N8NWebhookService {
  static const String _webhookUrl = 'https://showtrackai.app.n8n.cloud/webhook/4b52c2de-4d37-4752-aa5c-5741bd9e493d';
  static const Duration _defaultTimeout = Duration(seconds: 30);
  static const int _maxRetries = 3;
  static const Duration _retryDelay = Duration(seconds: 2);
  
  static final _supabase = Supabase.instance.client;

  /// Send a journal entry to N8N for AI processing
  static Future<void> sendJournalEntry(JournalEntry entry) async {
    if (_supabase.auth.currentUser == null) {
      throw Exception('User not authenticated');
    }

    try {
      final payload = _buildWebhookPayload(entry);
      await _sendWebhookWithRetry(payload);
      print('✅ Journal entry sent to N8N successfully');
    } catch (e) {
      print('❌ Failed to send journal entry to N8N: $e');
      throw Exception('Failed to process journal entry with AI: $e');
    }
  }

  /// Build the payload for the N8N webhook
  static Map<String, dynamic> _buildWebhookPayload(JournalEntry entry) {
    try {
      // Create a comprehensive query for AI processing
      final retrievalQuery = _buildRetrievalQuery(entry);
      
      // Build competency context
      final competencyContext = {
        'currentLevel': entry.competencyLevel ?? 'Developing',
        'ffaStandards': entry.ffaStandards ?? [],
        'aetSkills': entry.aetSkills,
        'degreeType': entry.ffaDegreeType ?? 'Greenhand',
        'countsForDegree': entry.countsForDegree ?? false,
      };

      // Build weather context if available
      final weatherContext = entry.weatherData != null ? {
        'temperature': entry.weatherData!.temperature,
        'condition': entry.weatherData!.condition,
        'humidity': entry.weatherData!.humidity,
        'windSpeed': entry.weatherData!.windSpeed,
        'description': entry.weatherData!.description,
      } : null;

      return {
        'requestId': 'journal_${entry.id}_${DateTime.now().millisecondsSinceEpoch}',
        'timestamp': DateTime.now().toIso8601String(),
        'journalEntry': {
          'id': entry.id,
          'userId': entry.userId,
          'title': entry.title,
          'description': entry.description,
          'content': entry.description,
          'retrievalQuery': retrievalQuery,
          'date': entry.date.toIso8601String(),
          'duration': entry.duration,
          'category': entry.category,
          'objectives': entry.objectives,
          'learningOutcomes': entry.learningOutcomes,
          'challenges': entry.challenges,
          'improvements': entry.improvements,
          'tags': entry.tags,
          'hoursLogged': entry.hoursLogged,
          'financialValue': entry.financialValue,
          'evidenceType': entry.evidenceType,
          'saType': entry.saType,
        },
        'userContext': {
          'userId': _supabase.auth.currentUser?.id,
          'ageGroup': 'teen',
          'educationalLevel': 'high_school',
        },
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
      print('Error building webhook payload: $e');
      rethrow;
    }
  }

  /// Build a comprehensive retrieval query for AI processing
  static String _buildRetrievalQuery(JournalEntry entry) {
    final queryParts = <String>[];
    
    // Core content
    queryParts.add(entry.title);
    queryParts.add(entry.description);
    
    // Context information
    queryParts.add('Agricultural education activity');
    queryParts.add('Category: ${entry.category}');
    
    if (entry.objectives?.isNotEmpty == true) {
      queryParts.add('Objectives: ${entry.objectives}');
    }
    
    if (entry.learningOutcomes?.isNotEmpty == true) {
      queryParts.add('Learning outcomes: ${entry.learningOutcomes}');
    }
    
    if (entry.challenges?.isNotEmpty == true) {
      queryParts.add('Challenges: ${entry.challenges}');
    }
    
    if (entry.improvements?.isNotEmpty == true) {
      queryParts.add('Improvements: ${entry.improvements}');
    }
    
    // FFA context
    if (entry.ffaDegreeType != null) {
      queryParts.add('FFA degree type: ${entry.ffaDegreeType}');
    }
    
    if (entry.saType != null) {
      queryParts.add('SAE type: ${entry.saType}');
    }
    
    return queryParts.join(' | ');
  }

  /// Send webhook with retry logic
  static Future<void> _sendWebhookWithRetry(Map<String, dynamic> payload) async {
    Exception? lastException;
    
    for (int attempt = 1; attempt <= _maxRetries; attempt++) {
      try {
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
          print('✅ N8N webhook successful on attempt $attempt');
          return;
        } else {
          throw HttpException('Webhook failed: ${response.statusCode} - ${response.body}');
        }
      } catch (e) {
        lastException = e is Exception ? e : Exception(e.toString());
        print('⚠️ N8N webhook attempt $attempt failed: $e');
        
        if (attempt < _maxRetries) {
          final delay = Duration(seconds: _retryDelay.inSeconds * attempt);
          print('⏱️ Retrying in ${delay.inSeconds} seconds...');
          await Future.delayed(delay);
        }
      }
    }

    throw lastException ?? Exception('Unknown error during webhook processing');
  }

  /// Check if the N8N webhook is available
  static Future<bool> isWebhookAvailable() async {
    try {
      final response = await http.head(
        Uri.parse(_webhookUrl),
      ).timeout(const Duration(seconds: 10));
      
      return response.statusCode < 500;
    } catch (e) {
      print('N8N webhook availability check failed: $e');
      return false;
    }
  }

  /// Get webhook service status
  static Future<Map<String, dynamic>> getServiceStatus() async {
    try {
      final isAvailable = await isWebhookAvailable();
      
      return {
        'available': isAvailable,
        'webhookUrl': _webhookUrl,
        'lastChecked': DateTime.now().toIso8601String(),
        'timeout': _defaultTimeout.inSeconds,
        'maxRetries': _maxRetries,
      };
    } catch (e) {
      return {
        'available': false,
        'error': e.toString(),
        'webhookUrl': _webhookUrl,
        'lastChecked': DateTime.now().toIso8601String(),
      };
    }
  }
}