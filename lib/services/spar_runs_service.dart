import 'dart:convert';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/journal_entry.dart';

/// Service for managing SPAR (Strategic Planning AI Reasoning) orchestration runs
/// Tracks AI processing lifecycle from submission through completion
class SPARRunsService {
  static final _supabase = Supabase.instance.client;
  
  /// Status constants for SPAR runs
  static const String STATUS_PENDING = 'pending';
  static const String STATUS_PROCESSING = 'processing';
  static const String STATUS_COMPLETED = 'completed';
  static const String STATUS_FAILED = 'failed';
  static const String STATUS_TIMEOUT = 'timeout';
  
  /// Create a new SPAR run record when journal submission starts
  /// Returns the created run ID for tracking
  static Future<String> createSPARRun({
    required String runId,
    required String userId,
    required String journalEntryId,
    required String intent,
    required Map<String, dynamic> inputs,
    Map<String, dynamic>? sparSettings,
  }) async {
    try {
      print('[SPAR] Creating SPAR run: $runId for journal entry: $journalEntryId');
      
      // Build the inputs data structure
      final inputsData = {
        'journal_entry_id': journalEntryId,
        'user_id': userId,
        'submission_timestamp': DateTime.now().toIso8601String(),
        'spar_settings': sparSettings ?? {},
        'raw_inputs': inputs,
        'metadata': {
          'source': 'flutter_app',
          'version': '2.0.0',
          'platform': _getPlatform(),
        }
      };
      
      // Insert the SPAR run record
      final response = await _supabase
          .from('spar_runs')
          .insert({
            'run_id': runId,
            'user_id': userId,
            'journal_entry_id': journalEntryId,
            'goal': intent,
            'inputs': inputsData,
            'status': STATUS_PENDING,
            'created_at': DateTime.now().toIso8601String(),
          })
          .select()
          .single();
      
      print('[SPAR] SPAR run created successfully: ${response['run_id']}');
      return response['run_id'];
      
    } catch (e) {
      print('[SPAR] Error creating SPAR run: $e');
      // Don't fail the journal submission if SPAR tracking fails
      // This is supplementary tracking, not critical path
      return runId;
    }
  }
  
  /// Update SPAR run status to processing when N8N starts
  static Future<void> updateSPARRunProcessing({
    required String runId,
    Map<String, dynamic>? plan,
  }) async {
    try {
      print('[SPAR] Updating SPAR run to processing: $runId');
      
      final updates = {
        'status': STATUS_PROCESSING,
        'processing_started_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      };
      
      if (plan != null) {
        updates['plan'] = jsonEncode(plan);
      }
      
      await _supabase
          .from('spar_runs')
          .update(updates)
          .eq('run_id', runId);
      
      print('[SPAR] SPAR run updated to processing status');
      
    } catch (e) {
      print('[SPAR] Error updating SPAR run to processing: $e');
    }
  }
  
  /// Update SPAR run with completion data from N8N
  static Future<void> updateSPARRunCompleted({
    required String runId,
    required Map<String, dynamic> results,
    Map<String, dynamic>? plan,
    Map<String, dynamic>? stepResults,
    Map<String, dynamic>? reflections,
  }) async {
    try {
      print('[SPAR] Completing SPAR run: $runId');
      
      // Calculate processing duration
      final run = await getSPARRun(runId);
      Duration? processingDuration;
      if (run != null && run['processing_started_at'] != null) {
        final startTime = DateTime.parse(run['processing_started_at']);
        processingDuration = DateTime.now().difference(startTime);
      }
      
      final updates = {
        'status': STATUS_COMPLETED,
        'plan': plan ?? results['plan'],
        'step_results': stepResults ?? results['step_results'] ?? results,
        'reflections': reflections ?? results['reflections'] ?? {
          'summary': results['summary'],
          'insights': results['insights'],
          'recommendations': results['recommendations'],
        },
        'processing_completed_at': DateTime.now().toIso8601String(),
        'processing_duration_ms': processingDuration?.inMilliseconds,
        'updated_at': DateTime.now().toIso8601String(),
      };
      
      await _supabase
          .from('spar_runs')
          .update(updates)
          .eq('run_id', runId);
      
      print('[SPAR] SPAR run completed successfully');
      
      // Update related journal entry with AI results
      await _updateJournalWithAIResults(runId, results);
      
    } catch (e) {
      print('[SPAR] Error completing SPAR run: $e');
      // Try to at least mark it as failed
      await updateSPARRunFailed(
        runId: runId,
        error: 'Failed to save completion data: $e',
      );
    }
  }
  
  /// Update SPAR run as failed with error details
  static Future<void> updateSPARRunFailed({
    required String runId,
    required String error,
    Map<String, dynamic>? errorDetails,
  }) async {
    try {
      print('[SPAR] Marking SPAR run as failed: $runId');
      
      final updates = {
        'status': STATUS_FAILED,
        'error': error,
        'error_details': errorDetails ?? {'message': error},
        'failed_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      };
      
      await _supabase
          .from('spar_runs')
          .update(updates)
          .eq('run_id', runId);
      
      print('[SPAR] SPAR run marked as failed');
      
    } catch (e) {
      print('[SPAR] Error marking SPAR run as failed: $e');
    }
  }
  
  /// Mark SPAR run as timed out
  static Future<void> updateSPARRunTimeout({
    required String runId,
    int timeoutSeconds = 30,
  }) async {
    try {
      print('[SPAR] Marking SPAR run as timed out: $runId');
      
      final updates = {
        'status': STATUS_TIMEOUT,
        'error': 'Processing timeout after $timeoutSeconds seconds',
        'error_details': {
          'timeout_seconds': timeoutSeconds,
          'timeout_at': DateTime.now().toIso8601String(),
        },
        'updated_at': DateTime.now().toIso8601String(),
      };
      
      await _supabase
          .from('spar_runs')
          .update(updates)
          .eq('run_id', runId);
      
      print('[SPAR] SPAR run marked as timeout');
      
    } catch (e) {
      print('[SPAR] Error marking SPAR run as timeout: $e');
    }
  }
  
  /// Get a specific SPAR run by ID
  static Future<Map<String, dynamic>?> getSPARRun(String runId) async {
    try {
      final response = await _supabase
          .from('spar_runs')
          .select()
          .eq('run_id', runId)
          .maybeSingle();
      
      return response;
    } catch (e) {
      print('[SPAR] Error fetching SPAR run: $e');
      return null;
    }
  }
  
  /// Get SPAR runs for a specific journal entry
  static Future<List<Map<String, dynamic>>> getSPARRunsForJournal(String journalEntryId) async {
    try {
      final response = await _supabase
          .from('spar_runs')
          .select()
          .eq('journal_entry_id', journalEntryId)
          .order('created_at', ascending: false);
      
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      print('[SPAR] Error fetching SPAR runs for journal: $e');
      return [];
    }
  }
  
  /// Get recent SPAR runs for a user
  static Future<List<Map<String, dynamic>>> getUserSPARRuns({
    required String userId,
    int limit = 10,
  }) async {
    try {
      final response = await _supabase
          .from('spar_runs')
          .select()
          .eq('user_id', userId)
          .order('created_at', ascending: false)
          .limit(limit);
      
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      print('[SPAR] Error fetching user SPAR runs: $e');
      return [];
    }
  }
  
  /// Get SPAR run statistics for a user
  static Future<Map<String, dynamic>> getUserSPARStats(String userId) async {
    try {
      final runs = await getUserSPARRuns(userId: userId, limit: 100);
      
      final stats = {
        'total_runs': runs.length,
        'completed': runs.where((r) => r['status'] == STATUS_COMPLETED).length,
        'failed': runs.where((r) => r['status'] == STATUS_FAILED).length,
        'timeout': runs.where((r) => r['status'] == STATUS_TIMEOUT).length,
        'pending': runs.where((r) => r['status'] == STATUS_PENDING).length,
        'processing': runs.where((r) => r['status'] == STATUS_PROCESSING).length,
        'average_duration_ms': 0,
        'success_rate': 0.0,
      };
      
      // Calculate average processing duration for completed runs
      final completedRuns = runs.where((r) => 
        r['status'] == STATUS_COMPLETED && 
        r['processing_duration_ms'] != null
      ).toList();
      
      if (completedRuns.isNotEmpty) {
        final totalDuration = completedRuns
            .map((r) => r['processing_duration_ms'] as int)
            .reduce((a, b) => a + b);
        stats['average_duration_ms'] = totalDuration ~/ completedRuns.length;
      }
      
      // Calculate success rate
      if (runs.isNotEmpty) {
        stats['success_rate'] = (stats['completed'] ?? 0) / runs.length;
      }
      
      return stats;
    } catch (e) {
      print('[SPAR] Error calculating SPAR stats: $e');
      return {
        'total_runs': 0,
        'completed': 0,
        'failed': 0,
        'timeout': 0,
        'pending': 0,
        'processing': 0,
        'average_duration_ms': 0,
        'success_rate': 0.0,
      };
    }
  }
  
  /// Retry a failed SPAR run
  static Future<void> retrySPARRun(String runId) async {
    try {
      print('[SPAR] Retrying SPAR run: $runId');
      
      // Get the original run data
      final run = await getSPARRun(runId);
      if (run == null) {
        throw Exception('SPAR run not found: $runId');
      }
      
      // Reset status to pending for retry
      await _supabase
          .from('spar_runs')
          .update({
            'status': STATUS_PENDING,
            'error': null,
            'error_details': null,
            'retry_count': (run['retry_count'] ?? 0) + 1,
            'retried_at': DateTime.now().toIso8601String(),
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('run_id', runId);
      
      print('[SPAR] SPAR run reset for retry');
      
    } catch (e) {
      print('[SPAR] Error retrying SPAR run: $e');
      rethrow;
    }
  }
  
  /// Clean up old SPAR runs (maintenance function)
  static Future<int> cleanupOldRuns({
    int daysToKeep = 30,
    List<String> statusesToClean = const [STATUS_COMPLETED, STATUS_FAILED, STATUS_TIMEOUT],
  }) async {
    try {
      final cutoffDate = DateTime.now()
          .subtract(Duration(days: daysToKeep))
          .toIso8601String();
      
      final response = await _supabase
          .from('spar_runs')
          .delete()
          .lt('created_at', cutoffDate)
          .inFilter('status', statusesToClean)
          .select();
      
      final deletedCount = (response as List).length;
      print('[SPAR] Cleaned up $deletedCount old SPAR runs');
      return deletedCount;
      
    } catch (e) {
      print('[SPAR] Error cleaning up old runs: $e');
      return 0;
    }
  }
  
  /// Update related journal entry with AI processing results
  static Future<void> _updateJournalWithAIResults(
    String runId,
    Map<String, dynamic> results,
  ) async {
    try {
      // Get the SPAR run to find the journal entry ID
      final run = await getSPARRun(runId);
      if (run == null || run['journal_entry_id'] == null) {
        print('[SPAR] Cannot update journal - run or journal ID not found');
        return;
      }
      
      final journalId = run['journal_entry_id'];
      
      // Extract key AI insights
      final aiAnalysis = {
        'spar_run_id': runId,
        'processed_at': DateTime.now().toIso8601String(),
        'competency_mapping': results['competency_mapping'],
        'quality_score': results['quality_score'],
        'recommendations': results['recommendations'],
        'insights': results['insights'],
        'ffa_standards_matched': results['ffa_standards'],
        'learning_objectives_achieved': results['objectives_achieved'],
      };
      
      // Update journal entry with AI analysis results
      await _supabase
          .from('journal_entries')
          .update({
            'ai_analysis': aiAnalysis,
            'is_synced': true,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', journalId);
      
      print('[SPAR] Journal entry updated with AI results');
      
    } catch (e) {
      print('[SPAR] Error updating journal with AI results: $e');
    }
  }
  
  /// Get platform identifier
  static String _getPlatform() {
    // This would ideally use Platform.isAndroid, Platform.isIOS, etc.
    // For now, return a generic identifier
    return 'flutter_mobile';
  }
  
  /// Monitor active SPAR runs and handle timeouts
  static Future<void> monitorActiveRuns({
    int timeoutSeconds = 60,
  }) async {
    try {
      // Find runs that are still processing but past timeout
      final cutoffTime = DateTime.now()
          .subtract(Duration(seconds: timeoutSeconds))
          .toIso8601String();
      
      final stuckRuns = await _supabase
          .from('spar_runs')
          .select()
          .inFilter('status', [STATUS_PENDING, STATUS_PROCESSING])
          .lt('created_at', cutoffTime);
      
      for (final run in stuckRuns) {
        print('[SPAR] Found stuck run: ${run['run_id']}');
        await updateSPARRunTimeout(
          runId: run['run_id'],
          timeoutSeconds: timeoutSeconds,
        );
      }
      
      if (stuckRuns.isNotEmpty) {
        print('[SPAR] Marked ${stuckRuns.length} stuck runs as timeout');
      }
      
    } catch (e) {
      print('[SPAR] Error monitoring active runs: $e');
    }
  }
}