import 'dart:convert';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'spar_runs_service.dart';

/// Service for handling callbacks from N8N workflow to update SPAR runs
/// This can be called via Supabase Edge Functions or direct API
class SPARCallbackService {
  static final _supabase = Supabase.instance.client;
  
  /// Process a callback from N8N with SPAR orchestration results
  /// This method should be exposed via an API endpoint or Edge Function
  static Future<Map<String, dynamic>> processSPARCallback({
    required String runId,
    required String status,
    Map<String, dynamic>? results,
    Map<String, dynamic>? plan,
    Map<String, dynamic>? stepResults,
    Map<String, dynamic>? reflections,
    String? error,
    Map<String, dynamic>? errorDetails,
  }) async {
    try {
      print('[SPAR Callback] Processing callback for run: $runId with status: $status');
      
      // Validate the run exists
      final run = await SPARRunsService.getSPARRun(runId);
      if (run == null) {
        throw Exception('SPAR run not found: $runId');
      }
      
      // Update based on status
      switch (status.toLowerCase()) {
        case 'processing':
          await SPARRunsService.updateSPARRunProcessing(
            runId: runId,
            plan: plan,
          );
          break;
          
        case 'completed':
        case 'success':
          await SPARRunsService.updateSPARRunCompleted(
            runId: runId,
            results: results ?? {},
            plan: plan,
            stepResults: stepResults,
            reflections: reflections,
          );
          
          // Update journal entry with AI analysis if available
          if (results != null && run['journal_entry_id'] != null) {
            await _updateJournalWithAnalysis(
              journalId: run['journal_entry_id'],
              analysis: results,
            );
          }
          break;
          
        case 'failed':
        case 'error':
          await SPARRunsService.updateSPARRunFailed(
            runId: runId,
            error: error ?? 'Unknown error',
            errorDetails: errorDetails,
          );
          break;
          
        case 'timeout':
          await SPARRunsService.updateSPARRunTimeout(
            runId: runId,
            timeoutSeconds: errorDetails?['timeout_seconds'] ?? 60,
          );
          break;
          
        default:
          throw Exception('Invalid status: $status');
      }
      
      return {
        'success': true,
        'message': 'SPAR run updated successfully',
        'runId': runId,
        'status': status,
        'timestamp': DateTime.now().toIso8601String(),
      };
      
    } catch (e) {
      print('[SPAR Callback] Error processing callback: $e');
      return {
        'success': false,
        'error': e.toString(),
        'runId': runId,
        'timestamp': DateTime.now().toIso8601String(),
      };
    }
  }
  
  /// Batch update multiple SPAR runs (for bulk processing)
  static Future<Map<String, dynamic>> processBatchCallbacks({
    required List<Map<String, dynamic>> updates,
  }) async {
    final results = <String, dynamic>{
      'successful': [],
      'failed': [],
      'total': updates.length,
    };
    
    for (final update in updates) {
      try {
        final result = await processSPARCallback(
          runId: update['runId'] ?? update['run_id'],
          status: update['status'],
          results: update['results'],
          plan: update['plan'],
          stepResults: update['stepResults'] ?? update['step_results'],
          reflections: update['reflections'],
          error: update['error'],
          errorDetails: update['errorDetails'] ?? update['error_details'],
        );
        
        if (result['success'] == true) {
          results['successful'].add(update['runId'] ?? update['run_id']);
        } else {
          results['failed'].add({
            'runId': update['runId'] ?? update['run_id'],
            'error': result['error'],
          });
        }
      } catch (e) {
        results['failed'].add({
          'runId': update['runId'] ?? update['run_id'],
          'error': e.toString(),
        });
      }
    }
    
    results['successCount'] = results['successful'].length;
    results['failedCount'] = results['failed'].length;
    results['timestamp'] = DateTime.now().toIso8601String();
    
    return results;
  }
  
  /// Update journal entry with AI analysis results
  static Future<void> _updateJournalWithAnalysis(
    String journalId,
    Map<String, dynamic> analysis,
  ) async {
    try {
      // Extract key insights from the analysis
      final aiInsights = {
        'analyzed_at': DateTime.now().toIso8601String(),
        'quality_score': analysis['quality_score'],
        'competencies_identified': analysis['competencies'],
        'ffa_standards_matched': analysis['ffa_standards'],
        'learning_objectives_achieved': analysis['objectives_achieved'],
        'recommendations': analysis['recommendations'],
        'insights': analysis['insights'],
        'improvement_areas': analysis['improvements'],
        'strengths_identified': analysis['strengths'],
      };
      
      // Update the journal entry
      await _supabase
          .from('journal_entries')
          .update({
            'ai_analysis': aiInsights,
            'is_synced': true,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', journalId);
      
      print('[SPAR Callback] Journal entry updated with AI analysis');
      
    } catch (e) {
      print('[SPAR Callback] Error updating journal with analysis: $e');
      // Don't throw - this is a secondary operation
    }
  }
  
  /// Validate callback authentication (for security)
  static Future<bool> validateCallbackAuth({
    required String authToken,
    String? expectedSecret,
  }) async {
    try {
      // In production, validate against a shared secret or JWT
      // For now, basic validation
      if (authToken.isEmpty) {
        return false;
      }
      
      // If an expected secret is provided, validate against it
      if (expectedSecret != null && authToken != expectedSecret) {
        return false;
      }
      
      // Additional validation logic can be added here
      // - Check JWT signature
      // - Validate timestamp to prevent replay attacks
      // - Check IP whitelist
      
      return true;
      
    } catch (e) {
      print('[SPAR Callback] Auth validation error: $e');
      return false;
    }
  }
  
  /// Get callback statistics for monitoring
  static Future<Map<String, dynamic>> getCallbackStats({
    Duration? timeWindow = const Duration(hours: 24),
  }) async {
    try {
      final cutoffTime = DateTime.now()
          .subtract(timeWindow ?? const Duration(hours: 24))
          .toIso8601String();
      
      final runs = await _supabase
          .from('spar_runs')
          .select()
          .gte('updated_at', cutoffTime);
      
      final stats = {
        'total_callbacks': runs.length,
        'successful': runs.where((r) => r['status'] == 'completed').length,
        'failed': runs.where((r) => r['status'] == 'failed').length,
        'processing': runs.where((r) => r['status'] == 'processing').length,
        'timeout': runs.where((r) => r['status'] == 'timeout').length,
        'time_window_hours': (timeWindow ?? const Duration(hours: 24)).inHours,
        'calculated_at': DateTime.now().toIso8601String(),
      };
      
      return stats;
      
    } catch (e) {
      print('[SPAR Callback] Error getting callback stats: $e');
      return {
        'error': e.toString(),
        'calculated_at': DateTime.now().toIso8601String(),
      };
    }
  }
}