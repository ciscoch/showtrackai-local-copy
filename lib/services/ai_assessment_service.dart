/// AI Assessment Service
/// 
/// Service for retrieving and managing AI assessments from the
/// normalized journal_entry_ai_assessments table.
/// 
/// This service provides methods to fetch AI assessment data
/// that has been processed by N8N workflows and stored in a 
/// structured format optimized for analytics and reporting.

import 'dart:convert';
import 'package:supabase_flutter/supabase_flutter.dart';

/// AI Assessment data model
class AiAssessment {
  final String id;
  final String journalEntryId;
  final String assessmentType;
  final double? qualityScore;
  final double? engagementScore;
  final double? learningDepthScore;
  final List<String> competenciesIdentified;
  final List<String> ffaStandardsMatched;
  final List<String> learningObjectivesAchieved;
  final List<String> strengthsIdentified;
  final List<String> growthAreas;
  final List<String> recommendations;
  final List<String> keyConcepts;
  final List<String> vocabularyUsed;
  final String? technicalAccuracyNotes;
  final double? confidenceScore;
  final DateTime processedAt;
  final String? modelUsed;
  final String? n8nRunId;
  final String? traceId;

  AiAssessment({
    required this.id,
    required this.journalEntryId,
    required this.assessmentType,
    this.qualityScore,
    this.engagementScore,
    this.learningDepthScore,
    required this.competenciesIdentified,
    required this.ffaStandardsMatched,
    required this.learningObjectivesAchieved,
    required this.strengthsIdentified,
    required this.growthAreas,
    required this.recommendations,
    required this.keyConcepts,
    required this.vocabularyUsed,
    this.technicalAccuracyNotes,
    this.confidenceScore,
    required this.processedAt,
    this.modelUsed,
    this.n8nRunId,
    this.traceId,
  });

  /// Factory constructor to create AiAssessment from Supabase JSON
  factory AiAssessment.fromJson(Map<String, dynamic> json) {
    return AiAssessment(
      id: json['id'] as String,
      journalEntryId: json['journal_entry_id'] as String,
      assessmentType: json['assessment_type'] as String,
      qualityScore: json['quality_score']?.toDouble(),
      engagementScore: json['engagement_score']?.toDouble(),
      learningDepthScore: json['learning_depth_score']?.toDouble(),
      competenciesIdentified: _parseJsonArray(json['competencies_identified']),
      ffaStandardsMatched: _parseJsonArray(json['ffa_standards_matched']),
      learningObjectivesAchieved: _parseJsonArray(json['learning_objectives_achieved']),
      strengthsIdentified: _parseJsonArray(json['strengths_identified']),
      growthAreas: _parseJsonArray(json['growth_areas']),
      recommendations: _parseJsonArray(json['recommendations']),
      keyConcepts: _parseJsonArray(json['key_concepts']),
      vocabularyUsed: _parseJsonArray(json['vocabulary_used']),
      technicalAccuracyNotes: json['technical_accuracy_notes'] as String?,
      confidenceScore: json['confidence_score']?.toDouble(),
      processedAt: DateTime.parse(json['created_at'] as String),
      modelUsed: json['model_used'] as String?,
      n8nRunId: json['n8n_run_id'] as String?,
      traceId: json['trace_id'] as String?,
    );
  }

  /// Helper method to parse JSONB arrays from Supabase
  static List<String> _parseJsonArray(dynamic jsonData) {
    if (jsonData == null) return [];
    
    if (jsonData is List) {
      return jsonData.map((item) => item.toString()).toList();
    }
    
    if (jsonData is String) {
      try {
        final List<dynamic> parsed = jsonDecode(jsonData);
        return parsed.map((item) => item.toString()).toList();
      } catch (e) {
        return [];
      }
    }
    
    return [];
  }

  /// Convert to JSON for serialization
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'journal_entry_id': journalEntryId,
      'assessment_type': assessmentType,
      'quality_score': qualityScore,
      'engagement_score': engagementScore,
      'learning_depth_score': learningDepthScore,
      'competencies_identified': competenciesIdentified,
      'ffa_standards_matched': ffaStandardsMatched,
      'learning_objectives_achieved': learningObjectivesAchieved,
      'strengths_identified': strengthsIdentified,
      'growth_areas': growthAreas,
      'recommendations': recommendations,
      'key_concepts': keyConcepts,
      'vocabulary_used': vocabularyUsed,
      'technical_accuracy_notes': technicalAccuracyNotes,
      'confidence_score': confidenceScore,
      'processed_at': processedAt.toIso8601String(),
      'model_used': modelUsed,
      'n8n_run_id': n8nRunId,
      'trace_id': traceId,
    };
  }

  /// Get overall assessment score (average of available scores)
  double? get overallScore {
    final scores = [qualityScore, engagementScore, learningDepthScore]
        .where((score) => score != null)
        .cast<double>()
        .toList();
    
    if (scores.isEmpty) return null;
    return scores.reduce((a, b) => a + b) / scores.length;
  }

  /// Get assessment grade based on quality score
  String get assessmentGrade {
    if (qualityScore == null) return 'Not Assessed';
    if (qualityScore! >= 9.0) return 'Excellent';
    if (qualityScore! >= 8.0) return 'Very Good';
    if (qualityScore! >= 7.0) return 'Good';
    if (qualityScore! >= 6.0) return 'Satisfactory';
    if (qualityScore! >= 5.0) return 'Needs Improvement';
    return 'Poor';
  }

  /// Check if assessment indicates proficiency in competencies
  bool get showsProficiency {
    return competenciesIdentified.isNotEmpty && 
           (qualityScore ?? 0) >= 7.0 &&
           strengthsIdentified.length >= growthAreas.length;
  }
}

/// Competency progress tracking model
class CompetencyProgress {
  final String competencyCode;
  final int assessmentCount;
  final double? avgQualityScore;
  final DateTime? latestAssessmentDate;
  final String progressTrend;

  CompetencyProgress({
    required this.competencyCode,
    required this.assessmentCount,
    this.avgQualityScore,
    this.latestAssessmentDate,
    required this.progressTrend,
  });

  factory CompetencyProgress.fromJson(Map<String, dynamic> json) {
    return CompetencyProgress(
      competencyCode: json['competency_code'] as String,
      assessmentCount: json['assessment_count'] as int,
      avgQualityScore: json['avg_quality_score']?.toDouble(),
      latestAssessmentDate: json['latest_assessment_date'] != null
          ? DateTime.parse(json['latest_assessment_date'] as String)
          : null,
      progressTrend: json['progress_trend'] as String,
    );
  }
}

/// Service class for AI Assessment operations
class AiAssessmentService {
  final SupabaseClient _supabase = Supabase.instance.client;

  /// Get AI assessment for a specific journal entry
  Future<AiAssessment?> getAssessmentForJournalEntry(
    String journalEntryId, {
    String assessmentType = 'journal_analysis',
  }) async {
    try {
      final response = await _supabase
          .rpc('get_ai_assessment_for_journal_entry', params: {
        'p_journal_entry_id': journalEntryId,
        'p_assessment_type': assessmentType,
      });

      if (response == null || response.isEmpty) {
        return null;
      }

      return AiAssessment.fromJson(response.first as Map<String, dynamic>);
    } catch (e) {
      print('Error fetching AI assessment: $e');
      return null;
    }
  }

  /// Get all AI assessments for a user's journal entries
  Future<List<AiAssessment>> getAssessmentsForUser(
    String userId, {
    int limit = 50,
    int offset = 0,
  }) async {
    try {
      final response = await _supabase
          .from('journal_ai_assessment_summary')
          .select('*')
          .eq('user_id', userId)
          .order('assessment_date', ascending: false)
          .limit(limit)
          .range(offset, offset + limit - 1);

      return (response as List<dynamic>)
          .map((json) => AiAssessment.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      print('Error fetching user AI assessments: $e');
      return [];
    }
  }

  /// Get competency progress for a student
  Future<List<CompetencyProgress>> getCompetencyProgress(
    String userId, {
    int daysBack = 30,
  }) async {
    try {
      final response = await _supabase
          .rpc('get_student_ai_competency_progress', params: {
        'p_user_id': userId,
        'p_days_back': daysBack,
      });

      return (response as List<dynamic>)
          .map((json) => CompetencyProgress.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      print('Error fetching competency progress: $e');
      return [];
    }
  }

  /// Get recent assessments with high quality scores
  Future<List<AiAssessment>> getHighQualityAssessments(
    String userId, {
    double minQualityScore = 8.0,
    int limit = 10,
  }) async {
    try {
      final response = await _supabase
          .from('journal_ai_assessment_summary')
          .select('*')
          .eq('user_id', userId)
          .gte('quality_score', minQualityScore)
          .order('quality_score', ascending: false)
          .limit(limit);

      return (response as List<dynamic>)
          .map((json) => AiAssessment.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      print('Error fetching high quality assessments: $e');
      return [];
    }
  }

  /// Search assessments by competency or FFA standard
  Future<List<AiAssessment>> searchAssessmentsByCompetency(
    String userId,
    String competencyCode,
  ) async {
    try {
      final response = await _supabase
          .from('journal_entry_ai_assessments')
          .select('''
            *,
            journal_entries!inner(user_id)
          ''')
          .eq('journal_entries.user_id', userId)
          .contains('competencies_identified', [competencyCode])
          .order('created_at', ascending: false);

      return (response as List<dynamic>)
          .map((json) => AiAssessment.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      print('Error searching assessments by competency: $e');
      return [];
    }
  }

  /// Get assessment statistics for a user
  Future<Map<String, dynamic>> getAssessmentStatistics(String userId) async {
    try {
      final response = await _supabase
          .from('journal_ai_assessment_summary')
          .select('''
            quality_score,
            engagement_score,
            learning_depth_score,
            competencies_count,
            ffa_standards_count,
            strengths_count,
            recommendations_count,
            assessment_date
          ''')
          .eq('user_id', userId);

      if (response.isEmpty) {
        return {
          'totalAssessments': 0,
          'averageQualityScore': 0.0,
          'averageEngagementScore': 0.0,
          'averageLearningDepthScore': 0.0,
          'totalCompetencies': 0,
          'totalFfaStandards': 0,
          'totalStrengths': 0,
          'totalRecommendations': 0,
          'assessmentTrend': 'No data',
        };
      }

      final assessments = response as List<dynamic>;
      final qualityScores = assessments
          .where((a) => a['quality_score'] != null)
          .map((a) => a['quality_score'] as double)
          .toList();

      final engagementScores = assessments
          .where((a) => a['engagement_score'] != null)
          .map((a) => a['engagement_score'] as double)
          .toList();

      final learningDepthScores = assessments
          .where((a) => a['learning_depth_score'] != null)
          .map((a) => a['learning_depth_score'] as double)
          .toList();

      return {
        'totalAssessments': assessments.length,
        'averageQualityScore': qualityScores.isNotEmpty
            ? qualityScores.reduce((a, b) => a + b) / qualityScores.length
            : 0.0,
        'averageEngagementScore': engagementScores.isNotEmpty
            ? engagementScores.reduce((a, b) => a + b) / engagementScores.length
            : 0.0,
        'averageLearningDepthScore': learningDepthScores.isNotEmpty
            ? learningDepthScores.reduce((a, b) => a + b) / learningDepthScores.length
            : 0.0,
        'totalCompetencies': assessments
            .map((a) => a['competencies_count'] as int? ?? 0)
            .reduce((a, b) => a + b),
        'totalFfaStandards': assessments
            .map((a) => a['ffa_standards_count'] as int? ?? 0)
            .reduce((a, b) => a + b),
        'totalStrengths': assessments
            .map((a) => a['strengths_count'] as int? ?? 0)
            .reduce((a, b) => a + b),
        'totalRecommendations': assessments
            .map((a) => a['recommendations_count'] as int? ?? 0)
            .reduce((a, b) => a + b),
        'assessmentTrend': _calculateTrend(qualityScores),
      };
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

  /// Helper method to calculate trend from scores
  String _calculateTrend(List<double> scores) {
    if (scores.length < 2) return 'Insufficient data';
    
    final recentHalf = scores.take(scores.length ~/ 2).toList();
    final olderHalf = scores.skip(scores.length ~/ 2).toList();
    
    final recentAvg = recentHalf.reduce((a, b) => a + b) / recentHalf.length;
    final olderAvg = olderHalf.reduce((a, b) => a + b) / olderHalf.length;
    
    if (recentAvg > olderAvg + 0.5) return 'Improving';
    if (recentAvg < olderAvg - 0.5) return 'Declining';
    return 'Stable';
  }

  /// Check if journal entry has AI assessment
  Future<bool> hasAssessment(String journalEntryId) async {
    try {
      final response = await _supabase
          .from('journal_entry_ai_assessments')
          .select('id')
          .eq('journal_entry_id', journalEntryId)
          .limit(1);

      return response.isNotEmpty;
    } catch (e) {
      print('Error checking assessment existence: $e');
      return false;
    }
  }

  /// Get assessment processing status by trace ID
  Future<Map<String, dynamic>?> getAssessmentStatus(String traceId) async {
    try {
      final response = await _supabase
          .from('journal_entry_ai_assessments')
          .select('id, created_at, quality_score, n8n_run_id')
          .eq('trace_id', traceId)
          .order('created_at', ascending: false)
          .limit(1);

      if (response.isEmpty) return null;

      final assessment = response.first as Map<String, dynamic>;
      return {
        'hasAssessment': true,
        'assessmentId': assessment['id'],
        'processedAt': assessment['created_at'],
        'qualityScore': assessment['quality_score'],
        'n8nRunId': assessment['n8n_run_id'],
      };
    } catch (e) {
      print('Error fetching assessment status: $e');
      return null;
    }
  }
}