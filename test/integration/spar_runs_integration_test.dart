import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import '../../lib/services/spar_runs_service.dart';
import '../../lib/services/spar_callback_service.dart';
import '../../lib/models/journal_entry.dart';

void main() {
  late SupabaseClient supabase;
  final uuid = const Uuid();
  
  setUpAll(() async {
    // Initialize Supabase for testing
    await Supabase.initialize(
      url: const String.fromEnvironment('SUPABASE_URL'),
      anonKey: const String.fromEnvironment('SUPABASE_ANON_KEY'),
    );
    supabase = Supabase.instance.client;
    
    // Sign in with test user
    await supabase.auth.signInWithPassword(
      email: 'test@example.com',
      password: 'testpassword123',
    );
  });
  
  tearDownAll(() async {
    // Clean up test data
    await supabase.auth.signOut();
  });
  
  group('SPAR Runs Service Tests', () {
    test('Create SPAR run for journal entry', () async {
      // Arrange
      final runId = 'test_run_${uuid.v4()}';
      final userId = supabase.auth.currentUser!.id;
      final journalId = uuid.v4();
      
      // Act
      final createdRunId = await SPARRunsService.createSPARRun(
        runId: runId,
        userId: userId,
        journalEntryId: journalId,
        intent: 'edu_context',
        inputs: {
          'title': 'Test Journal Entry',
          'description': 'This is a test journal entry for SPAR integration',
          'category': 'daily_care',
        },
        sparSettings: {
          'vector': {
            'matchCount': 6,
            'minSimilarity': 0.75,
          },
        },
      );
      
      // Assert
      expect(createdRunId, equals(runId));
      
      // Verify the run was created
      final run = await SPARRunsService.getSPARRun(runId);
      expect(run, isNotNull);
      expect(run!['run_id'], equals(runId));
      expect(run['user_id'], equals(userId));
      expect(run['status'], equals('pending'));
      expect(run['goal'], equals('edu_context'));
    });
    
    test('Update SPAR run to processing status', () async {
      // Arrange
      final runId = 'test_run_${uuid.v4()}';
      final userId = supabase.auth.currentUser!.id;
      
      await SPARRunsService.createSPARRun(
        runId: runId,
        userId: userId,
        journalEntryId: uuid.v4(),
        intent: 'analysis',
        inputs: {'test': 'data'},
      );
      
      // Act
      await SPARRunsService.updateSPARRunProcessing(
        runId: runId,
        plan: {
          'steps': ['analyze', 'summarize', 'recommend'],
          'estimated_time': 10,
        },
      );
      
      // Assert
      final run = await SPARRunsService.getSPARRun(runId);
      expect(run!['status'], equals('processing'));
      expect(run['plan'], isNotNull);
      expect(run['plan']['steps'], hasLength(3));
    });
    
    test('Complete SPAR run with results', () async {
      // Arrange
      final runId = 'test_run_${uuid.v4()}';
      final userId = supabase.auth.currentUser!.id;
      
      await SPARRunsService.createSPARRun(
        runId: runId,
        userId: userId,
        journalEntryId: uuid.v4(),
        intent: 'feedback',
        inputs: {'test': 'data'},
      );
      
      await SPARRunsService.updateSPARRunProcessing(runId: runId);
      
      // Act
      await SPARRunsService.updateSPARRunCompleted(
        runId: runId,
        results: {
          'quality_score': 85,
          'competencies': ['AS.01.01', 'AS.02.03'],
          'recommendations': ['Add more detail', 'Include evidence'],
        },
        reflections: {
          'summary': 'Good journal entry with room for improvement',
          'insights': ['Strong understanding of concepts'],
        },
      );
      
      // Assert
      final run = await SPARRunsService.getSPARRun(runId);
      expect(run!['status'], equals('completed'));
      expect(run['step_results'], isNotNull);
      expect(run['reflections'], isNotNull);
      expect(run['processing_completed_at'], isNotNull);
    });
    
    test('Handle SPAR run failure', () async {
      // Arrange
      final runId = 'test_run_${uuid.v4()}';
      final userId = supabase.auth.currentUser!.id;
      
      await SPARRunsService.createSPARRun(
        runId: runId,
        userId: userId,
        journalEntryId: uuid.v4(),
        intent: 'analysis',
        inputs: {'test': 'data'},
      );
      
      // Act
      await SPARRunsService.updateSPARRunFailed(
        runId: runId,
        error: 'AI processing failed',
        errorDetails: {
          'code': 'AI_ERROR',
          'message': 'Model unavailable',
        },
      );
      
      // Assert
      final run = await SPARRunsService.getSPARRun(runId);
      expect(run!['status'], equals('failed'));
      expect(run['error'], equals('AI processing failed'));
      expect(run['error_details']['code'], equals('AI_ERROR'));
    });
    
    test('Handle SPAR run timeout', () async {
      // Arrange
      final runId = 'test_run_${uuid.v4()}';
      final userId = supabase.auth.currentUser!.id;
      
      await SPARRunsService.createSPARRun(
        runId: runId,
        userId: userId,
        journalEntryId: uuid.v4(),
        intent: 'analysis',
        inputs: {'test': 'data'},
      );
      
      // Act
      await SPARRunsService.updateSPARRunTimeout(
        runId: runId,
        timeoutSeconds: 30,
      );
      
      // Assert
      final run = await SPARRunsService.getSPARRun(runId);
      expect(run!['status'], equals('timeout'));
      expect(run['error'], contains('timeout'));
      expect(run['error_details']['timeout_seconds'], equals(30));
    });
    
    test('Get user SPAR run statistics', () async {
      // Arrange
      final userId = supabase.auth.currentUser!.id;
      
      // Create multiple runs with different statuses
      for (int i = 0; i < 5; i++) {
        final runId = 'test_run_${uuid.v4()}';
        await SPARRunsService.createSPARRun(
          runId: runId,
          userId: userId,
          journalEntryId: uuid.v4(),
          intent: 'test',
          inputs: {'index': i},
        );
        
        // Set different statuses
        if (i < 3) {
          await SPARRunsService.updateSPARRunCompleted(
            runId: runId,
            results: {'test': true},
          );
        } else if (i == 3) {
          await SPARRunsService.updateSPARRunFailed(
            runId: runId,
            error: 'Test failure',
          );
        }
        // Leave last one as pending
      }
      
      // Act
      final stats = await SPARRunsService.getUserSPARStats(userId);
      
      // Assert
      expect(stats['total_runs'], greaterThanOrEqualTo(5));
      expect(stats['completed'], greaterThanOrEqualTo(3));
      expect(stats['failed'], greaterThanOrEqualTo(1));
      expect(stats['pending'], greaterThanOrEqualTo(1));
      expect(stats['success_rate'], greaterThan(0));
    });
  });
  
  group('SPAR Callback Service Tests', () {
    test('Process successful callback', () async {
      // Arrange
      final runId = 'test_run_${uuid.v4()}';
      final userId = supabase.auth.currentUser!.id;
      
      await SPARRunsService.createSPARRun(
        runId: runId,
        userId: userId,
        journalEntryId: uuid.v4(),
        intent: 'analysis',
        inputs: {'test': 'data'},
      );
      
      // Act
      final result = await SPARCallbackService.processSPARCallback(
        runId: runId,
        status: 'completed',
        results: {
          'quality_score': 90,
          'insights': ['Great work!'],
        },
      );
      
      // Assert
      expect(result['success'], isTrue);
      expect(result['message'], contains('successfully'));
      
      final run = await SPARRunsService.getSPARRun(runId);
      expect(run!['status'], equals('completed'));
    });
    
    test('Process batch callbacks', () async {
      // Arrange
      final runs = <String>[];
      final userId = supabase.auth.currentUser!.id;
      
      for (int i = 0; i < 3; i++) {
        final runId = 'test_run_${uuid.v4()}';
        runs.add(runId);
        await SPARRunsService.createSPARRun(
          runId: runId,
          userId: userId,
          journalEntryId: uuid.v4(),
          intent: 'batch_test',
          inputs: {'index': i},
        );
      }
      
      // Act
      final result = await SPARCallbackService.processBatchCallbacks(
        updates: [
          {
            'runId': runs[0],
            'status': 'completed',
            'results': {'test': true},
          },
          {
            'runId': runs[1],
            'status': 'failed',
            'error': 'Test error',
          },
          {
            'runId': runs[2],
            'status': 'completed',
            'results': {'test': true},
          },
        ],
      );
      
      // Assert
      expect(result['total'], equals(3));
      expect(result['successCount'], equals(3)); // All callbacks processed
      expect(result['failedCount'], equals(0)); // No callback failures
      
      // Verify individual run statuses
      final run1 = await SPARRunsService.getSPARRun(runs[0]);
      expect(run1!['status'], equals('completed'));
      
      final run2 = await SPARRunsService.getSPARRun(runs[1]);
      expect(run2!['status'], equals('failed'));
      
      final run3 = await SPARRunsService.getSPARRun(runs[2]);
      expect(run3!['status'], equals('completed'));
    });
    
    test('Validate callback authentication', () async {
      // Act & Assert
      final validAuth = await SPARCallbackService.validateCallbackAuth(
        authToken: 'valid-token',
        expectedSecret: 'valid-token',
      );
      expect(validAuth, isTrue);
      
      final invalidAuth = await SPARCallbackService.validateCallbackAuth(
        authToken: 'wrong-token',
        expectedSecret: 'valid-token',
      );
      expect(invalidAuth, isFalse);
      
      final emptyAuth = await SPARCallbackService.validateCallbackAuth(
        authToken: '',
      );
      expect(emptyAuth, isFalse);
    });
    
    test('Get callback statistics', () async {
      // Act
      final stats = await SPARCallbackService.getCallbackStats(
        timeWindow: const Duration(hours: 24),
      );
      
      // Assert
      expect(stats, isNotNull);
      expect(stats['time_window_hours'], equals(24));
      expect(stats['calculated_at'], isNotNull);
      expect(stats.containsKey('total_callbacks'), isTrue);
      expect(stats.containsKey('successful'), isTrue);
      expect(stats.containsKey('failed'), isTrue);
    });
  });
  
  group('SPAR Runs Maintenance', () {
    test('Monitor and timeout stuck runs', () async {
      // This test would need to create runs and wait for timeout
      // For now, just test the function doesn't throw
      await SPARRunsService.monitorActiveRuns(timeoutSeconds: 1);
      
      // No assertions needed - just verify it doesn't throw
    });
    
    test('Clean up old runs', () async {
      // Act
      final deletedCount = await SPARRunsService.cleanupOldRuns(
        daysToKeep: 30,
      );
      
      // Assert
      expect(deletedCount, greaterThanOrEqualTo(0));
    });
    
    test('Retry failed SPAR run', () async {
      // Arrange
      final runId = 'test_run_${uuid.v4()}';
      final userId = supabase.auth.currentUser!.id;
      
      await SPARRunsService.createSPARRun(
        runId: runId,
        userId: userId,
        journalEntryId: uuid.v4(),
        intent: 'retry_test',
        inputs: {'test': 'data'},
      );
      
      await SPARRunsService.updateSPARRunFailed(
        runId: runId,
        error: 'Initial failure',
      );
      
      // Act
      await SPARRunsService.retrySPARRun(runId);
      
      // Assert
      final run = await SPARRunsService.getSPARRun(runId);
      expect(run!['status'], equals('pending')); // Reset to pending
      expect(run['retry_count'], equals(1));
      expect(run['retried_at'], isNotNull);
    });
  });
}