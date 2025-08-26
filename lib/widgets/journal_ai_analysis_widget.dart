import 'package:flutter/material.dart';
import '../services/journal_service.dart';
import '../services/n8n_webhook_service.dart';
import '../models/journal_entry.dart';

/// Widget for displaying AI analysis results from N8N webhook
class JournalAIAnalysisWidget extends StatefulWidget {
  final JournalEntry entry;
  final bool showFullAnalysis;

  const JournalAIAnalysisWidget({
    Key? key,
    required this.entry,
    this.showFullAnalysis = false,
  }) : super(key: key);

  @override
  State<JournalAIAnalysisWidget> createState() => _JournalAIAnalysisWidgetState();
}

class _JournalAIAnalysisWidgetState extends State<JournalAIAnalysisWidget> {
  N8NAnalysisResult? _analysisResult;
  bool _isAnalyzing = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    // Check if entry already has AI insights
    if (widget.entry.aiInsights != null) {
      // Convert existing insights to analysis result format if needed
      _loadExistingInsights();
    }
  }

  void _loadExistingInsights() {
    if (widget.entry.aiInsights != null) {
      setState(() {
        _analysisResult = N8NAnalysisResult(
          requestId: 'existing_${widget.entry.id}',
          status: 'completed',
          qualityScore: widget.entry.qualityScore ?? 5,
          ffaStandards: widget.entry.ffaStandards ?? [],
          aetSkills: widget.entry.aetSkills,
          competencyLevel: widget.entry.competencyLevel ?? 'Developing',
          educationalConcepts: widget.entry.educationalConcepts ?? [],
          aiInsights: widget.entry.aiInsights!,
          recommendations: widget.entry.aiInsights!.recommendedActivities,
          processingMetadata: {
            'loaded_from_existing': true,
            'processed_at': DateTime.now().toIso8601String(),
          },
        );
      });
    }
  }

  Future<void> _triggerAIAnalysis() async {
    setState(() {
      _isAnalyzing = true;
      _errorMessage = null;
    });

    try {
      final result = await JournalService.processWithAIAndReturn(widget.entry);
      setState(() {
        _analysisResult = result;
        _isAnalyzing = false;
      });

      if (result != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('AI Analysis Complete! Quality Score: ${result.qualityScore}/10'),
            backgroundColor: Colors.green,
            action: SnackBarAction(
              label: 'View',
              onPressed: () => _showFullAnalysisDialog(),
            ),
          ),
        );
      }
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
        _isAnalyzing = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('AI Analysis Failed: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _showFullAnalysisDialog() {
    if (_analysisResult == null) return;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.psychology, color: Colors.blue),
            SizedBox(width: 8),
            Text('AI Analysis Results'),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildQualityScoreCard(),
              SizedBox(height: 16),
              _buildFFAStandardsSection(),
              SizedBox(height: 16),
              _buildCompetencySection(),
              SizedBox(height: 16),
              _buildRecommendationsSection(),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text('Close'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.psychology,
                  color: _analysisResult != null ? Colors.green : Colors.grey,
                ),
                SizedBox(width: 8),
                Text(
                  'AI Analysis',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                Spacer(),
                if (_analysisResult == null && !_isAnalyzing)
                  ElevatedButton.icon(
                    onPressed: _triggerAIAnalysis,
                    icon: Icon(Icons.auto_fix_high),
                    label: Text('Analyze'),
                  ),
                if (_isAnalyzing)
                  SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
              ],
            ),
            SizedBox(height: 12),
            
            if (_errorMessage != null)
              Container(
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red.shade200),
                ),
                child: Row(
                  children: [
                    Icon(Icons.error_outline, color: Colors.red, size: 16),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _errorMessage!,
                        style: TextStyle(color: Colors.red.shade700),
                      ),
                    ),
                  ],
                ),
              ),
            
            if (_analysisResult != null) ...[
              _buildQuickSummary(),
              if (widget.showFullAnalysis) ...[
                SizedBox(height: 16),
                _buildFullAnalysis(),
              ] else ...[
                SizedBox(height: 8),
                TextButton(
                  onPressed: _showFullAnalysisDialog,
                  child: Text('View Full Analysis'),
                ),
              ],
            ],
            
            if (_analysisResult == null && !_isAnalyzing && _errorMessage == null)
              Container(
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, color: Colors.blue, size: 16),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Click "Analyze" to get AI-powered insights about this journal entry, including quality assessment and FFA standards alignment.',
                        style: TextStyle(color: Colors.blue.shade700),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickSummary() {
    if (_analysisResult == null) return SizedBox();

    return Container(
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.green.shade50,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.star, color: Colors.amber, size: 20),
              SizedBox(width: 8),
              Text(
                'Quality Score: ${_analysisResult!.qualityScore}/10',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.green.shade800,
                ),
              ),
            ],
          ),
          SizedBox(height: 8),
          Row(
            children: [
              Icon(Icons.school, color: Colors.blue, size: 16),
              SizedBox(width: 8),
              Text(
                'Competency: ${_analysisResult!.competencyLevel}',
                style: TextStyle(color: Colors.blue.shade700),
              ),
            ],
          ),
          if (_analysisResult!.ffaStandards.isNotEmpty) ...[
            SizedBox(height: 4),
            Row(
              children: [
                Icon(Icons.verified, color: Colors.orange, size: 16),
                SizedBox(width: 8),
                Text(
                  'FFA Standards: ${_analysisResult!.ffaStandards.length}',
                  style: TextStyle(color: Colors.orange.shade700),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildQualityScoreCard() {
    return Card(
      color: Colors.blue.shade50,
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.star, color: Colors.amber),
                SizedBox(width: 8),
                Text(
                  'Quality Assessment',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ],
            ),
            SizedBox(height: 8),
            Row(
              children: [
                Text(
                  '${_analysisResult!.qualityScore}/10',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue.shade700,
                  ),
                ),
                SizedBox(width: 16),
                Expanded(
                  child: LinearProgressIndicator(
                    value: _analysisResult!.qualityScore / 10.0,
                    backgroundColor: Colors.grey.shade300,
                    color: _getQualityColor(_analysisResult!.qualityScore),
                  ),
                ),
              ],
            ),
            SizedBox(height: 8),
            Text(
              _analysisResult!.aiInsights.qualityAssessment.justification,
              style: TextStyle(color: Colors.grey.shade600),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFFAStandardsSection() {
    if (_analysisResult!.ffaStandards.isEmpty) return SizedBox();

    return Card(
      color: Colors.orange.shade50,
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.verified, color: Colors.orange),
                SizedBox(width: 8),
                Text(
                  'FFA Standards Alignment',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ],
            ),
            SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: _analysisResult!.ffaStandards
                  .map((standard) => Chip(
                        label: Text(standard),
                        backgroundColor: Colors.orange.shade100,
                      ))
                  .toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCompetencySection() {
    return Card(
      color: Colors.purple.shade50,
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.school, color: Colors.purple),
                SizedBox(width: 8),
                Text(
                  'Competency Development',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ],
            ),
            SizedBox(height: 8),
            Text(
              'Current Level: ${_analysisResult!.competencyLevel}',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: Colors.purple.shade700,
              ),
            ),
            if (_analysisResult!.educationalConcepts.isNotEmpty) ...[
              SizedBox(height: 8),
              Text('Educational Concepts:', style: TextStyle(fontWeight: FontWeight.w500)),
              SizedBox(height: 4),
              Wrap(
                spacing: 6,
                runSpacing: 4,
                children: _analysisResult!.educationalConcepts
                    .map((concept) => Chip(
                          label: Text(
                            concept,
                            style: TextStyle(fontSize: 12),
                          ),
                          backgroundColor: Colors.purple.shade100,
                        ))
                    .toList(),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildRecommendationsSection() {
    if (_analysisResult!.recommendations.isEmpty) return SizedBox();

    return Card(
      color: Colors.green.shade50,
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.lightbulb, color: Colors.green),
                SizedBox(width: 8),
                Text(
                  'AI Recommendations',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ],
            ),
            SizedBox(height: 8),
            ...(_analysisResult!.recommendations.take(3).map((rec) => Padding(
                  padding: EdgeInsets.symmetric(vertical: 2),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.arrow_right, size: 16, color: Colors.green),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          rec,
                          style: TextStyle(color: Colors.green.shade700),
                        ),
                      ),
                    ],
                  ),
                ))),
          ],
        ),
      ),
    );
  }

  Widget _buildFullAnalysis() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildQualityScoreCard(),
        SizedBox(height: 16),
        _buildFFAStandardsSection(),
        SizedBox(height: 16),
        _buildCompetencySection(),
        SizedBox(height: 16),
        _buildRecommendationsSection(),
        
        // Processing metadata
        if (_analysisResult!.processingMetadata.isNotEmpty)
          Card(
            color: Colors.grey.shade50,
            child: Padding(
              padding: EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Processing Info',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Method: ${_analysisResult!.processingMetadata['processing_method'] ?? 'Unknown'}',
                    style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                  ),
                  Text(
                    'Status: ${_analysisResult!.status}',
                    style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Color _getQualityColor(int score) {
    if (score >= 8) return Colors.green;
    if (score >= 6) return Colors.orange;
    return Colors.red;
  }
}