import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../lib/services/ai_assessment_service.dart';
import '../../lib/services/journal_service.dart';
import '../../lib/models/journal_entry.dart';

/// Integration tests for AI Assessment functionality
/// 
/// These tests verify the complete flow from journal entry creation
/// through AI assessment processing and retrieval.
/// 
/// Note: These tests require a working Supabase connection and
/// the AI assessment database schema to be deployed.

void main() {
  group('AI Assessment Integration Tests', () {
    late AiAssessmentService aiAssessmentService;
    
    setUpAll(() async {
      // Initialize Supabase (you'll need to configure this for your test environment)
      await Supabase.initialize(
        url: 'YOUR_SUPABASE_URL',
        anonKey: 'YOUR_SUPABASE_ANON_KEY',
      );
      
      aiAssessmentService = AiAssessmentService();
    });

    group('AiAssessment Model Tests', () {
      test('should create AiAssessment from JSON correctly', () {
        final json = {
          'id': 'test-assessment-id',
          'journal_entry_id': 'test-journal-id',
          'assessment_type': 'journal_analysis',
          'quality_score': 8.5,
          'engagement_score': 7.8,
          'learning_depth_score': 8.2,
          'competencies_identified': ['AS.07.01', 'AS.07.02'],
          'ffa_standards_matched': ['Animal Health Management'],
          'learning_objectives_achieved': ['Demonstrated health assessment'],
          'strengths_identified': ['Excellent documentation'],
          'growth_areas': ['Include cost analysis'],
          'recommendations': ['Continue monitoring'],
          'key_concepts': ['Preventive care'],
          'vocabulary_used': ['Auscultation'],
          'technical_accuracy_notes': 'Good use of terminology',
          'confidence_score': 0.89,
          'created_at': '2025-02-02T10:30:45Z',
          'model_used': 'gpt-4',
          'n8n_run_id': 'run_123',
          'trace_id': 'trace_456'
        };

        final assessment = AiAssessment.fromJson(json);

        expect(assessment.id, equals('test-assessment-id'));
        expect(assessment.journalEntryId, equals('test-journal-id'));
        expect(assessment.qualityScore, equals(8.5));
        expect(assessment.competenciesIdentified.length, equals(2));
        expect(assessment.competenciesIdentified, contains('AS.07.01'));
        expect(assessment.strengthsIdentified, contains('Excellent documentation'));
        expect(assessment.overallScore, closeTo(8.17, 0.1));
        expect(assessment.assessmentGrade, equals('Very Good'));
        expect(assessment.showsProficiency, isTrue);
      });

      test('should handle null values gracefully', () {
        final json = {
          'id': 'test-assessment-id',
          'journal_entry_id': 'test-journal-id',
          'assessment_type': 'journal_analysis',
          'competencies_identified': null,
          'ffa_standards_matched': [],
          'learning_objectives_achieved': null,
          'strengths_identified': null,
          'growth_areas': null,
          'recommendations': null,
          'key_concepts': null,
          'vocabulary_used': null,
          'created_at': '2025-02-02T10:30:45Z',
        };

        final assessment = AiAssessment.fromJson(json);

        expect(assessment.competenciesIdentified, isEmpty);
        expect(assessment.ffaStandardsMatched, isEmpty);
        expect(assessment.strengthsIdentified, isEmpty);
        expect(assessment.overallScore, isNull);
        expect(assessment.assessmentGrade, equals('Not Assessed'));
        expect(assessment.showsProficiency, isFalse);
      });

      test('should parse JSONB arrays correctly', () {
        // Test string JSON format
        final assessment1 = AiAssessment.fromJson({
          'id': 'test-1',
          'journal_entry_id': 'journal-1',
          'assessment_type': 'journal_analysis',
          'competencies_identified': '["AS.07.01", "AS.07.02"]',
          'created_at': '2025-02-02T10:30:45Z',
        });

        expect(assessment1.competenciesIdentified.length, equals(2));
        expect(assessment1.competenciesIdentified, contains('AS.07.01'));

        // Test array format
        final assessment2 = AiAssessment.fromJson({
          'id': 'test-2',
          'journal_entry_id': 'journal-2',
          'assessment_type': 'journal_analysis',
          'competencies_identified': ['AS.08.01', 'AS.08.02'],
          'created_at': '2025-02-02T10:30:45Z',
        });

        expect(assessment2.competenciesIdentified.length, equals(2));
        expect(assessment2.competenciesIdentified, contains('AS.08.01'));
      });
    });

    group('CompetencyProgress Model Tests', () {
      test('should create CompetencyProgress from JSON correctly', () {
        final json = {
          'competency_code': 'AS.07.01',
          'assessment_count': 5,
          'avg_quality_score': 8.2,
          'latest_assessment_date': '2025-02-02T10:30:45Z',
          'progress_trend': 'Consistent'
        };

        final progress = CompetencyProgress.fromJson(json);

        expect(progress.competencyCode, equals('AS.07.01'));
        expect(progress.assessmentCount, equals(5));
        expect(progress.avgQualityScore, equals(8.2));
        expect(progress.latestAssessmentDate, isNotNull);
        expect(progress.progressTrend, equals('Consistent'));
      });
    });

    group('AiAssessmentService Tests', () {
      test('should handle getAssessmentForJournalEntry with no assessment', () async {
        final assessment = await aiAssessmentService.getAssessmentForJournalEntry(
          'non-existent-journal-id'
        );

        expect(assessment, isNull);
      });

      test('should handle getCompetencyProgress with no data', () async {
        final progress = await aiAssessmentService.getCompetencyProgress(
          'non-existent-user-id'
        );

        expect(progress, isEmpty);
      });

      test('should handle getAssessmentStatistics with no data', () async {
        final stats = await aiAssessmentService.getAssessmentStatistics(
          'non-existent-user-id'
        );

        expect(stats['totalAssessments'], equals(0));
        expect(stats['averageQualityScore'], equals(0.0));
        expect(stats['assessmentTrend'], equals('No data'));
      });

      test('should handle hasAssessment gracefully', () async {
        final hasAssessment = await aiAssessmentService.hasAssessment(
          'non-existent-journal-id'
        );

        expect(hasAssessment, isFalse);
      });

      test('should handle getAssessmentStatus with invalid trace ID', () async {
        final status = await aiAssessmentService.getAssessmentStatus(
          'invalid-trace-id'
        );

        expect(status, isNull);
      });
    });

    group('JournalService AI Integration Tests', () {
      test('should handle getAiAssessment gracefully', () async {
        final assessment = await JournalService.getAiAssessment(
          'non-existent-journal-id'
        );

        expect(assessment, isNull);
      });

      test('should handle hasAiAssessment gracefully', () async {
        final hasAssessment = await JournalService.hasAiAssessment(
          'non-existent-journal-id'
        );

        expect(hasAssessment, isFalse);
      });

      test('should handle getAssessmentStatistics gracefully', () async {
        final stats = await JournalService.getAssessmentStatistics();

        expect(stats, isNotNull);
        expect(stats.containsKey('totalAssessments'), isTrue);
        expect(stats.containsKey('averageQualityScore'), isTrue);
        expect(stats.containsKey('assessmentTrend'), isTrue);
      });

      test('should handle getCompetencyProgress gracefully', () async {
        final progress = await JournalService.getCompetencyProgress();

        expect(progress, isNotNull);
        expect(progress, isEmpty);
      });

      test('should handle getHighQualityAssessments gracefully', () async {
        final assessments = await JournalService.getHighQualityAssessments();

        expect(assessments, isNotNull);
        expect(assessments, isEmpty);
      });

      test('should handle searchAssessmentsByCompetency gracefully', () async {
        final assessments = await JournalService.searchAssessmentsByCompetency(
          'AS.07.01'
        );

        expect(assessments, isNotNull);
        expect(assessments, isEmpty);
      });

      test('should handle getUserAiAssessments gracefully', () async {
        final assessments = await JournalService.getUserAiAssessments();

        expect(assessments, isNotNull);
        expect(assessments, isEmpty);
      });

      test('should handle getEnhancedFfaDegreeProgress gracefully', () async {
        final progress = await JournalService.getEnhancedFfaDegreeProgress();

        expect(progress, isNotNull);
        expect(progress.containsKey('saProjects'), isTrue);
        expect(progress.containsKey('totalAiAssessments'), isTrue);
        expect(progress.containsKey('averageQualityScore'), isTrue);
        expect(progress.containsKey('hasAiInsights'), isTrue);
      });
    });

    group('Error Handling Tests', () {
      test('should handle invalid JSON in _parseJsonArray', () {
        final result = AiAssessment._parseJsonArray('invalid json');
        expect(result, isEmpty);
      });

      test('should handle null input in _parseJsonArray', () {
        final result = AiAssessment._parseJsonArray(null);
        expect(result, isEmpty);
      });

      test('should handle non-array input in _parseJsonArray', () {
        final result = AiAssessment._parseJsonArray('not an array');
        expect(result, isEmpty);
      });

      test('should handle array with mixed types in _parseJsonArray', () {
        final result = AiAssessment._parseJsonArray([1, 'string', true, null]);
        expect(result, equals(['1', 'string', 'true', 'null']));
      });
    });

    group('Business Logic Tests', () {
      test('should calculate overall score correctly', () {
        final assessment = AiAssessment(
          id: 'test',
          journalEntryId: 'journal',
          assessmentType: 'test',
          qualityScore: 8.0,
          engagementScore: 9.0,
          learningDepthScore: 7.0,
          competenciesIdentified: [],
          ffaStandardsMatched: [],
          learningObjectivesAchieved: [],
          strengthsIdentified: [],
          growthAreas: [],
          recommendations: [],
          keyConcepts: [],
          vocabularyUsed: [],
          processedAt: DateTime.now(),
        );

        expect(assessment.overallScore, equals(8.0));
      });

      test('should determine assessment grade correctly', () {
        final testCases = [
          (9.5, 'Excellent'),
          (8.5, 'Very Good'),
          (7.5, 'Good'),
          (6.5, 'Satisfactory'),
          (5.5, 'Needs Improvement'),
          (4.0, 'Poor'),
        ];

        for (final testCase in testCases) {
          final assessment = AiAssessment(
            id: 'test',
            journalEntryId: 'journal',
            assessmentType: 'test',
            qualityScore: testCase.$1,
            competenciesIdentified: [],
            ffaStandardsMatched: [],
            learningObjectivesAchieved: [],
            strengthsIdentified: [],
            growthAreas: [],
            recommendations: [],
            keyConcepts: [],
            vocabularyUsed: [],
            processedAt: DateTime.now(),
          );

          expect(assessment.assessmentGrade, equals(testCase.$2));
        }
      });

      test('should determine proficiency correctly', () {
        final proficientAssessment = AiAssessment(
          id: 'test',
          journalEntryId: 'journal',
          assessmentType: 'test',
          qualityScore: 8.0,
          competenciesIdentified: ['AS.07.01', 'AS.07.02'],
          ffaStandardsMatched: [],
          learningObjectivesAchieved: [],
          strengthsIdentified: ['Good work', 'Excellent detail'],
          growthAreas: ['Minor improvement'],
          recommendations: [],
          keyConcepts: [],
          vocabularyUsed: [],
          processedAt: DateTime.now(),
        );

        expect(proficientAssessment.showsProficiency, isTrue);

        final nonProficientAssessment = AiAssessment(
          id: 'test',
          journalEntryId: 'journal',
          assessmentType: 'test',
          qualityScore: 5.0,
          competenciesIdentified: [],
          ffaStandardsMatched: [],
          learningObjectivesAchieved: [],
          strengthsIdentified: [],
          growthAreas: ['Major improvements needed'],
          recommendations: [],
          keyConcepts: [],
          vocabularyUsed: [],
          processedAt: DateTime.now(),
        );

        expect(nonProficientAssessment.showsProficiency, isFalse);
      });
    });

    group('Data Serialization Tests', () {
      test('should convert to JSON correctly', () {
        final assessment = AiAssessment(
          id: 'test-id',
          journalEntryId: 'journal-id',
          assessmentType: 'journal_analysis',
          qualityScore: 8.5,
          competenciesIdentified: ['AS.07.01'],
          ffaStandardsMatched: ['Animal Health'],
          learningObjectivesAchieved: ['Health assessment'],
          strengthsIdentified: ['Good documentation'],
          growthAreas: ['Cost analysis'],
          recommendations: ['Continue monitoring'],
          keyConcepts: ['Preventive care'],
          vocabularyUsed: ['Auscultation'],
          processedAt: DateTime.parse('2025-02-02T10:30:45Z'),
        );

        final json = assessment.toJson();

        expect(json['id'], equals('test-id'));
        expect(json['journal_entry_id'], equals('journal-id'));
        expect(json['quality_score'], equals(8.5));
        expect(json['competencies_identified'], contains('AS.07.01'));
        expect(json['processed_at'], equals('2025-02-02T10:30:45.000Z'));
      });
    });
  });
}

/// Mock data for testing
class MockAiAssessmentData {
  static final sampleAssessmentJson = {
    'id': 'sample-assessment-123',
    'journal_entry_id': 'sample-journal-456',
    'assessment_type': 'journal_analysis',
    'quality_score': 8.5,
    'engagement_score': 7.8,
    'learning_depth_score': 8.2,
    'competencies_identified': ['AS.07.01', 'AS.07.02', 'AS.01.03'],
    'ffa_standards_matched': [
      'Animal Science - Health Management',
      'Animal Science - Nutrition Planning'
    ],
    'learning_objectives_achieved': [
      'Demonstrated proper health assessment techniques',
      'Recorded detailed observations with measurements'
    ],
    'strengths_identified': [
      'Excellent attention to detail in observations',
      'Proper use of technical terminology',
      'Clear documentation of procedures followed'
    ],
    'growth_areas': [
      'Could provide more specific measurements',
      'Consider adding cost analysis'
    ],
    'recommendations': [
      'Continue daily health monitoring',
      'Document feed conversion ratios'
    ],
    'key_concepts': [
      'Preventive healthcare',
      'Animal behavior observation'
    ],
    'vocabulary_used': [
      'Auscultation',
      'Body condition scoring'
    ],
    'technical_accuracy_notes': 'Entry demonstrates advanced understanding of animal health protocols',
    'confidence_score': 0.89,
    'created_at': '2025-02-02T10:30:45Z',
    'model_used': 'gpt-4',
    'n8n_run_id': 'run_sample_789',
    'trace_id': 'trace_sample_101112'
  };

  static final sampleCompetencyProgressJson = {
    'competency_code': 'AS.07.01',
    'assessment_count': 5,
    'avg_quality_score': 8.2,
    'latest_assessment_date': '2025-02-02T10:30:45Z',
    'progress_trend': 'Consistent'
  };

  static final sampleStatistics = {
    'totalAssessments': 15,
    'averageQualityScore': 7.8,
    'averageEngagementScore': 7.5,
    'averageLearningDepthScore': 8.0,
    'totalCompetencies': 45,
    'totalFfaStandards': 12,
    'totalStrengths': 60,
    'totalRecommendations': 48,
    'assessmentTrend': 'Improving',
  };
}

/// Test utilities
class AiAssessmentTestUtils {
  static AiAssessment createSampleAssessment({
    String? id,
    String? journalEntryId,
    double? qualityScore,
    List<String>? competencies,
  }) {
    return AiAssessment(
      id: id ?? 'test-assessment',
      journalEntryId: journalEntryId ?? 'test-journal',
      assessmentType: 'journal_analysis',
      qualityScore: qualityScore ?? 8.0,
      competenciesIdentified: competencies ?? ['AS.07.01'],
      ffaStandardsMatched: ['Animal Health Management'],
      learningObjectivesAchieved: ['Demonstrated assessment'],
      strengthsIdentified: ['Good work'],
      growthAreas: ['Could improve'],
      recommendations: ['Keep practicing'],
      keyConcepts: ['Health'],
      vocabularyUsed: ['Technical terms'],
      processedAt: DateTime.now(),
    );
  }

  static CompetencyProgress createSampleProgress({
    String? competencyCode,
    int? assessmentCount,
    double? avgScore,
  }) {
    return CompetencyProgress(
      competencyCode: competencyCode ?? 'AS.07.01',
      assessmentCount: assessmentCount ?? 3,
      avgQualityScore: avgScore ?? 7.5,
      latestAssessmentDate: DateTime.now(),
      progressTrend: 'Developing',
    );
  }
}