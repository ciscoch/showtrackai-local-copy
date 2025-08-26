import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/app_theme.dart';

/// Comprehensive AI Assessment Preview Card
/// Displays SPAR assessment results with visual quality scores, competencies, 
/// strengths, growth areas, and personalized recommendations
class AssessmentPreviewCard extends StatefulWidget {
  final SPARAssessmentResult? assessmentResult;
  final bool isProcessing;
  final VoidCallback? onRetry;
  final VoidCallback? onViewDetails;
  final VoidCallback? onShare;

  const AssessmentPreviewCard({
    super.key,
    this.assessmentResult,
    this.isProcessing = false,
    this.onRetry,
    this.onViewDetails,
    this.onShare,
  });

  @override
  State<AssessmentPreviewCard> createState() => _AssessmentPreviewCardState();
}

class _AssessmentPreviewCardState extends State<AssessmentPreviewCard>
    with TickerProviderStateMixin {
  late AnimationController _animationController;
  late AnimationController _scoreAnimationController;
  late Animation<double> _fadeInAnimation;
  late Animation<double> _scoreAnimation;
  bool _showDetails = false;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _scoreAnimationController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );

    _fadeInAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutQuart,
    ));

    _scoreAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _scoreAnimationController,
      curve: Curves.elasticOut,
    ));

    _animationController.forward();
    if (widget.assessmentResult != null && !widget.isProcessing) {
      _scoreAnimationController.forward();
    }
  }

  @override
  void didUpdateWidget(AssessmentPreviewCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.assessmentResult != null && 
        oldWidget.assessmentResult == null && 
        !widget.isProcessing) {
      _scoreAnimationController.forward();
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    _scoreAnimationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.isProcessing && widget.assessmentResult == null) {
      return const SizedBox.shrink();
    }

    return FadeTransition(
      opacity: _fadeInAnimation,
      child: Card(
        elevation: 6,
        shadowColor: Colors.black.withValues(alpha: 0.15),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.white,
                Colors.grey.shade50,
              ],
            ),
          ),
          child: widget.isProcessing 
              ? _buildProcessingView()
              : _buildAssessmentView(),
        ),
      ),
    );
  }

  Widget _buildProcessingView() {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    color: Colors.blue,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'AI Assessment in Progress',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Analyzing your journal entry for quality and learning outcomes...',
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          _buildProcessingSteps(),
        ],
      ),
    );
  }

  Widget _buildProcessingSteps() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Processing Steps:',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: Colors.grey.shade700,
            fontSize: 14,
          ),
        ),
        const SizedBox(height: 12),
        _buildProcessingStep('Content Analysis', true),
        _buildProcessingStep('FFA Standard Mapping', true),
        _buildProcessingStep('Competency Assessment', true),
        _buildProcessingStep('Generating Recommendations', false),
      ],
    );
  }

  Widget _buildProcessingStep(String title, bool isCompleted) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Container(
            width: 20,
            height: 20,
            decoration: BoxDecoration(
              color: isCompleted 
                  ? Colors.green.shade100 
                  : Colors.grey.shade100,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: isCompleted 
                    ? Colors.green.shade400 
                    : Colors.grey.shade300,
                width: 2,
              ),
            ),
            child: isCompleted
                ? Icon(
                    Icons.check,
                    size: 12,
                    color: Colors.green.shade700,
                  )
                : Container(
                    width: 8,
                    height: 8,
                    margin: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: Colors.orange,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
          ),
          const SizedBox(width: 12),
          Text(
            title,
            style: TextStyle(
              color: isCompleted 
                  ? Colors.grey.shade700 
                  : Colors.grey.shade600,
              fontSize: 13,
              fontWeight: isCompleted 
                  ? FontWeight.w500 
                  : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAssessmentView() {
    final result = widget.assessmentResult!;
    
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(result),
          const SizedBox(height: 24),
          _buildOverallScore(result),
          const SizedBox(height: 24),
          _buildCompetenciesBadges(result),
          const SizedBox(height: 20),
          _buildStrengthsAndGrowthAreas(result),
          const SizedBox(height: 20),
          _buildRecommendations(result),
          const SizedBox(height: 20),
          _buildDetailedScores(result),
          const SizedBox(height: 20),
          _buildActionButtons(),
        ],
      ),
    );
  }

  Widget _buildHeader(SPARAssessmentResult result) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppTheme.primaryGreen.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(
            Icons.psychology,
            color: AppTheme.primaryGreen,
            size: 28,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'AI Assessment Results',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.primaryGreen,
                ),
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  Text(
                    'Processed ${_formatTimestamp(result.processedAt)}',
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey.shade600,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: result.isComplete 
                          ? Colors.green.shade100 
                          : Colors.orange.shade100,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      result.isComplete ? 'Complete' : 'Processing',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: result.isComplete 
                            ? Colors.green.shade700 
                            : Colors.orange.shade700,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        IconButton(
          onPressed: () {
            setState(() {
              _showDetails = !_showDetails;
            });
            HapticFeedback.lightImpact();
          },
          icon: AnimatedRotation(
            turns: _showDetails ? 0.5 : 0,
            duration: const Duration(milliseconds: 200),
            child: const Icon(Icons.expand_more),
          ),
          tooltip: _showDetails ? 'Show less' : 'Show more',
        ),
      ],
    );
  }

  Widget _buildOverallScore(SPARAssessmentResult result) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            _getScoreColor(result.overallScore).withValues(alpha: 0.05),
            _getScoreColor(result.overallScore).withValues(alpha: 0.15),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: _getScoreColor(result.overallScore).withValues(alpha: 0.3),
          width: 1.5,
        ),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Overall Quality Score',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey.shade700,
                  ),
                ),
                const SizedBox(height: 8),
                AnimatedBuilder(
                  animation: _scoreAnimation,
                  builder: (context, child) {
                    final animatedScore = result.overallScore * _scoreAnimation.value;
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Text(
                          animatedScore.toStringAsFixed(1),
                          style: TextStyle(
                            fontSize: 36,
                            fontWeight: FontWeight.bold,
                            color: _getScoreColor(result.overallScore),
                          ),
                        ),
                        Text(
                          ' / 10',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w500,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: _getScoreColor(result.overallScore),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    result.competencyLevel,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: AnimatedBuilder(
              animation: _scoreAnimation,
              builder: (context, child) {
                return _buildScoreCircle(
                  result.overallScore * _scoreAnimation.value,
                  result.overallScore,
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildScoreCircle(double animatedScore, double fullScore) {
    final animatedNormalizedScore = animatedScore / 10.0;
    
    return SizedBox(
      width: 100,
      height: 100,
      child: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox(
            width: 100,
            height: 100,
            child: CircularProgressIndicator(
              value: animatedNormalizedScore,
              strokeWidth: 8,
              backgroundColor: Colors.grey.shade200,
              valueColor: AlwaysStoppedAnimation<Color>(
                _getScoreColor(fullScore),
              ),
            ),
          ),
          Text(
            '${(animatedNormalizedScore * 100).round()}%',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: _getScoreColor(fullScore),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCompetenciesBadges(SPARAssessmentResult result) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(
              Icons.verified,
              color: AppTheme.primaryGreen,
              size: 20,
            ),
            const SizedBox(width: 8),
            Text(
              'Identified Competencies (${result.identifiedCompetencies.length})',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: result.identifiedCompetencies.map((competency) {
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: AppTheme.primaryGreen.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: AppTheme.primaryGreen.withValues(alpha: 0.3),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.check_circle_outline,
                    size: 16,
                    color: AppTheme.primaryGreen,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    competency,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: AppTheme.primaryGreen,
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildStrengthsAndGrowthAreas(SPARAssessmentResult result) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: _buildStrengthsList(result.strengths),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _buildGrowthAreasList(result.growthAreas),
        ),
      ],
    );
  }

  Widget _buildStrengthsList(List<String> strengths) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.green.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.green.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.star_rounded,
                color: Colors.green.shade600,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                'Strengths',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.green.shade700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...strengths.asMap().entries.map((entry) {
            return Padding(
              padding: EdgeInsets.only(bottom: entry.key < strengths.length - 1 ? 8 : 0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 6,
                    height: 6,
                    margin: const EdgeInsets.only(top: 6, right: 8),
                    decoration: BoxDecoration(
                      color: Colors.green.shade600,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      entry.value,
                      style: TextStyle(
                        color: Colors.green.shade700,
                        fontSize: 13,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        ],
      ),
    );
  }

  Widget _buildGrowthAreasList(List<String> growthAreas) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.orange.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.orange.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.trending_up,
                color: Colors.orange.shade600,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                'Growth Areas',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.orange.shade700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...growthAreas.asMap().entries.map((entry) {
            return Padding(
              padding: EdgeInsets.only(bottom: entry.key < growthAreas.length - 1 ? 8 : 0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 6,
                    height: 6,
                    margin: const EdgeInsets.only(top: 6, right: 8),
                    decoration: BoxDecoration(
                      color: Colors.orange.shade600,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      entry.value,
                      style: TextStyle(
                        color: Colors.orange.shade700,
                        fontSize: 13,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        ],
      ),
    );
  }

  Widget _buildRecommendations(SPARAssessmentResult result) {
    if (result.recommendations.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(
              Icons.lightbulb_outline,
              color: Colors.blue,
              size: 20,
            ),
            const SizedBox(width: 8),
            Text(
              'Personalized Recommendations (${result.recommendations.length})',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ...result.recommendations.map((recommendation) {
          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.blue.shade200),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: _getPriorityColor(recommendation.priority),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        recommendation.priority.toUpperCase(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        recommendation.title,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: Colors.blue.shade700,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  recommendation.description,
                  style: TextStyle(
                    color: Colors.blue.shade600,
                    fontSize: 13,
                    height: 1.4,
                  ),
                ),
                if (recommendation.actionSteps.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Text(
                    'Action Steps:',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.blue.shade700,
                    ),
                  ),
                  const SizedBox(height: 6),
                  ...recommendation.actionSteps.asMap().entries.map((entry) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${entry.key + 1}. ',
                            style: TextStyle(
                              color: Colors.blue.shade600,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Expanded(
                            child: Text(
                              entry.value,
                              style: TextStyle(
                                color: Colors.blue.shade600,
                                fontSize: 13,
                                height: 1.3,
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ],
              ],
            ),
          );
        }).toList(),
      ],
    );
  }

  Widget _buildDetailedScores(SPARAssessmentResult result) {
    if (!_showDetails || result.detailedScores.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(
              Icons.analytics,
              color: Colors.purple,
              size: 20,
            ),
            const SizedBox(width: 8),
            const Text(
              'Detailed Score Breakdown',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.purple.shade50,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.purple.shade200),
          ),
          child: Column(
            children: result.detailedScores.entries.map((entry) {
              final score = (entry.value as num).toDouble();
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          _formatScoreCategory(entry.key),
                          style: TextStyle(
                            fontWeight: FontWeight.w500,
                            color: Colors.purple.shade700,
                            fontSize: 14,
                          ),
                        ),
                        Text(
                          score.toStringAsFixed(1),
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: _getScoreColor(score),
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    LinearProgressIndicator(
                      value: score / 10.0,
                      backgroundColor: Colors.grey.shade200,
                      valueColor: AlwaysStoppedAnimation<Color>(_getScoreColor(score)),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildActionButtons() {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: widget.onViewDetails,
            icon: const Icon(Icons.visibility),
            label: const Text('View Details'),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: ElevatedButton.icon(
            onPressed: widget.onShare,
            icon: const Icon(Icons.share),
            label: const Text('Share Results'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryGreen,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
          ),
        ),
      ],
    );
  }

  Color _getScoreColor(double score) {
    if (score >= 8.5) return Colors.green.shade600;
    if (score >= 7.0) return Colors.blue.shade600;
    if (score >= 5.5) return Colors.orange.shade600;
    return Colors.red.shade600;
  }

  Color _getPriorityColor(String priority) {
    switch (priority.toLowerCase()) {
      case 'high':
        return Colors.red.shade600;
      case 'medium':
        return Colors.orange.shade600;
      case 'low':
        return Colors.blue.shade600;
      default:
        return Colors.grey.shade600;
    }
  }

  String _formatScoreCategory(String category) {
    return category
        .replaceAll('_', ' ')
        .split(' ')
        .map((word) => word.isEmpty ? '' : word[0].toUpperCase() + word.substring(1))
        .join(' ');
  }

  String _formatTimestamp(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);

    if (difference.inMinutes < 1) {
      return 'just now';
    } else if (difference.inHours < 1) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inDays < 1) {
      return '${difference.inHours}h ago';
    } else {
      return '${difference.inDays}d ago';
    }
  }
}

/// SPAR Assessment Result model for AI-generated feedback
class SPARAssessmentResult {
  final String id;
  final double overallScore;
  final String competencyLevel;
  final List<String> identifiedCompetencies;
  final List<String> strengths;
  final List<String> growthAreas;
  final List<AssessmentRecommendation> recommendations;
  final Map<String, dynamic> detailedScores;
  final String feedbackSummary;
  final DateTime processedAt;
  final bool isComplete;

  SPARAssessmentResult({
    required this.id,
    required this.overallScore,
    required this.competencyLevel,
    required this.identifiedCompetencies,
    required this.strengths,
    required this.growthAreas,
    required this.recommendations,
    required this.detailedScores,
    required this.feedbackSummary,
    required this.processedAt,
    this.isComplete = true,
  });

  factory SPARAssessmentResult.fromJson(Map<String, dynamic> json) {
    return SPARAssessmentResult(
      id: json['id'] ?? '',
      overallScore: (json['overallScore'] ?? 0).toDouble(),
      competencyLevel: json['competencyLevel'] ?? 'Developing',
      identifiedCompetencies: List<String>.from(json['identifiedCompetencies'] ?? []),
      strengths: List<String>.from(json['strengths'] ?? []),
      growthAreas: List<String>.from(json['growthAreas'] ?? []),
      recommendations: (json['recommendations'] as List? ?? [])
          .map((r) => AssessmentRecommendation.fromJson(r))
          .toList(),
      detailedScores: Map<String, dynamic>.from(json['detailedScores'] ?? {}),
      feedbackSummary: json['feedbackSummary'] ?? '',
      processedAt: json['processedAt'] != null 
          ? DateTime.parse(json['processedAt'])
          : DateTime.now(),
      isComplete: json['isComplete'] ?? true,
    );
  }

  // Mock assessment result for demonstration
  factory SPARAssessmentResult.mock() {
    return SPARAssessmentResult(
      id: 'mock_${DateTime.now().millisecondsSinceEpoch}',
      overallScore: 8.4,
      competencyLevel: 'Proficient',
      identifiedCompetencies: [
        'AS.07.01 - Animal Health Maintenance',
        'AS.01.02 - Animal Husbandry Practices',
        'AS.02.01 - Animal Nutrition Knowledge'
      ],
      strengths: [
        'Detailed observation of animal behavior and physical condition',
        'Systematic approach to health monitoring procedures',
        'Clear documentation of treatment protocols'
      ],
      growthAreas: [
        'Include specific measurements (weight, temperature)',
        'Document frequency of observations',
        'Connect observations to FFA degree requirements'
      ],
      recommendations: [
        AssessmentRecommendation(
          type: 'immediate',
          priority: 'high',
          title: 'Add Quantitative Data',
          description: 'Include specific measurements and metrics to strengthen your documentation.',
          actionSteps: [
            'Record animal weight if available',
            'Note temperature readings',
            'Document feed consumption amounts'
          ]
        ),
        AssessmentRecommendation(
          type: 'skill_development',
          priority: 'medium',
          title: 'Expand Health Monitoring',
          description: 'Develop more comprehensive health assessment skills.',
          actionSteps: [
            'Learn to use body condition scoring',
            'Practice taking vital signs',
            'Study common health indicators'
          ]
        )
      ],
      detailedScores: {
        'content_quality': 8.2,
        'technical_accuracy': 8.8,
        'ffa_alignment': 8.0,
        'learning_demonstration': 8.6,
        'reflection_depth': 8.1
      },
      feedbackSummary: 'This entry demonstrates strong animal care knowledge and systematic observation skills. Your documentation shows understanding of proper health monitoring procedures. To improve, focus on adding quantitative measurements and connecting your work to specific FFA degree requirements.',
      processedAt: DateTime.now(),
    );
  }
}

class AssessmentRecommendation {
  final String type; // 'immediate', 'skill_development', 'ffa_requirement'
  final String priority; // 'high', 'medium', 'low'
  final String title;
  final String description;
  final List<String> actionSteps;

  AssessmentRecommendation({
    required this.type,
    required this.priority,
    required this.title,
    required this.description,
    required this.actionSteps,
  });

  factory AssessmentRecommendation.fromJson(Map<String, dynamic> json) {
    return AssessmentRecommendation(
      type: json['type'] ?? '',
      priority: json['priority'] ?? 'medium',
      title: json['title'] ?? '',
      description: json['description'] ?? '',
      actionSteps: List<String>.from(json['actionSteps'] ?? []),
    );
  }
}