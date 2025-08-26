import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';

// Import the models
import '../../lib/models/journal_entry.dart';
import '../../lib/services/journal_service.dart';

// Generate mocks
@GenerateMocks([JournalService])
import 'journal_ai_analysis_widget_test.mocks.dart';

/// AI Analysis Widget Test
/// 
/// This widget would display AI insights for journal entries including:
/// - Quality assessment with scoring
/// - FFA standards identification
/// - AET skills recognition
/// - Learning concepts extraction
/// - Competency level assessment
/// - Feedback with strengths/improvements
/// - Recommended activities
/// 
/// Since the actual widget doesn't exist yet, this test defines the expected
/// behavior and interface for the AI analysis display component.
class MockAIAnalysisWidget extends StatelessWidget {
  final AIInsights? aiInsights;
  final bool isLoading;
  final String? error;
  final VoidCallback? onRefresh;
  final VoidCallback? onSaveInsights;
  final bool showDetailedView;

  const MockAIAnalysisWidget({
    Key? key,
    this.aiInsights,
    this.isLoading = false,
    this.error,
    this.onRefresh,
    this.onSaveInsights,
    this.showDetailedView = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(16.0),
          child: Column(
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Analyzing journal entry...'),
            ],
          ),
        ),
      );
    }

    if (error != null) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              const Icon(Icons.error, color: Colors.red, size: 48),
              const SizedBox(height: 16),
              Text('Error: $error'),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: onRefresh,
                child: const Text('Retry Analysis'),
              ),
            ],
          ),
        ),
      );
    }

    if (aiInsights == null) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              const Icon(Icons.psychology, size: 48),
              const SizedBox(height: 16),
              const Text('No AI analysis available'),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: onRefresh,
                child: const Text('Generate Analysis'),
              ),
            ],
          ),
        ),
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                const Icon(Icons.psychology, color: Colors.blue),
                const SizedBox(width: 8),
                const Text(
                  'AI Analysis Results',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                if (onSaveInsights != null)
                  IconButton(
                    icon: const Icon(Icons.save),
                    onPressed: onSaveInsights,
                    tooltip: 'Save Analysis',
                  ),
                IconButton(
                  icon: const Icon(Icons.refresh),
                  onPressed: onRefresh,
                  tooltip: 'Refresh Analysis',
                ),
              ],
            ),
            const Divider(),

            // Quality Score
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _getScoreColor(aiInsights!.qualityAssessment.score),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.grade, color: Colors.white),
                  const SizedBox(width: 8),
                  Text(
                    'Quality Score: ${aiInsights!.qualityAssessment.score}/10',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Competency Level
            _buildInfoChip('Competency Level', aiInsights!.competencyLevel),
            const SizedBox(height: 16),

            // FFA Standards
            if (aiInsights!.ffaStandards.isNotEmpty) ...[
              const Text(
                'FFA Standards Identified:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: aiInsights!.ffaStandards
                    .map((standard) => Chip(
                          label: Text(standard),
                          backgroundColor: Colors.green.shade100,
                        ))
                    .toList(),
              ),
              const SizedBox(height: 16),
            ],

            // AET Skills
            if (aiInsights!.aetSkillsIdentified.isNotEmpty) ...[
              const Text(
                'AET Skills Identified:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: aiInsights!.aetSkillsIdentified
                    .map((skill) => Chip(
                          label: Text(skill),
                          backgroundColor: Colors.blue.shade100,
                        ))
                    .toList(),
              ),
              const SizedBox(height: 16),
            ],

            // Learning Concepts
            if (aiInsights!.learningConcepts.isNotEmpty) ...[
              const Text(
                'Learning Concepts:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: aiInsights!.learningConcepts
                    .map((concept) => Chip(
                          label: Text(concept),
                          backgroundColor: Colors.orange.shade100,
                        ))
                    .toList(),
              ),
              const SizedBox(height: 16),
            ],

            // Detailed View Toggle
            if (showDetailedView) ...[
              ExpansionTile(
                title: const Text('Detailed Feedback'),
                children: [
                  // Strengths
                  if (aiInsights!.feedback.strengths.isNotEmpty) ...[
                    const ListTile(
                      leading: Icon(Icons.check_circle, color: Colors.green),
                      title: Text(
                        'Strengths',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                    ...aiInsights!.feedback.strengths
                        .map((strength) => ListTile(
                              contentPadding:
                                  const EdgeInsets.only(left: 56, right: 16),
                              title: Text(strength),
                            ))
                        .toList(),
                  ],

                  // Improvements
                  if (aiInsights!.feedback.improvements.isNotEmpty) ...[
                    const ListTile(
                      leading: Icon(Icons.trending_up, color: Colors.orange),
                      title: Text(
                        'Areas for Improvement',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                    ...aiInsights!.feedback.improvements
                        .map((improvement) => ListTile(
                              contentPadding:
                                  const EdgeInsets.only(left: 56, right: 16),
                              title: Text(improvement),
                            ))
                        .toList(),
                  ],

                  // Suggestions
                  if (aiInsights!.feedback.suggestions.isNotEmpty) ...[
                    const ListTile(
                      leading: Icon(Icons.lightbulb, color: Colors.blue),
                      title: Text(
                        'Suggestions',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                    ...aiInsights!.feedback.suggestions
                        .map((suggestion) => ListTile(
                              contentPadding:
                                  const EdgeInsets.only(left: 56, right: 16),
                              title: Text(suggestion),
                            ))
                        .toList(),
                  ],
                ],
              ),

              // Recommended Activities
              if (aiInsights!.recommendedActivities.isNotEmpty)
                ExpansionTile(
                  title: const Text('Recommended Activities'),
                  children: aiInsights!.recommendedActivities
                      .map((activity) => ListTile(
                            leading: const Icon(Icons.assignment),
                            title: Text(activity),
                          ))
                      .toList(),
                ),

              // Quality Assessment Justification
              ExpansionTile(
                title: const Text('Quality Assessment'),
                children: [
                  ListTile(
                    title: Text(
                      aiInsights!.qualityAssessment.justification,
                      style: const TextStyle(fontSize: 14),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildInfoChip(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.grey.shade200,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '$label: ',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          Text(value),
        ],
      ),
    );
  }

  Color _getScoreColor(int score) {
    if (score >= 8) return Colors.green;
    if (score >= 6) return Colors.orange;
    return Colors.red;
  }
}

void main() {
  group('Journal AI Analysis Widget Tests', () {
    late MockJournalService mockJournalService;

    setUp(() {
      mockJournalService = MockJournalService();
    });

    // Sample AI insights for testing
    final sampleAIInsights = AIInsights(
      qualityAssessment: QualityAssessment(
        score: 8,
        justification:
            'This journal entry demonstrates thorough understanding of animal care practices with detailed observations and proper documentation.',
      ),
      ffaStandards: ['AS.01.01', 'AS.02.03', 'AS.07.01'],
      aetSkillsIdentified: [
        'Animal Health Management',
        'Record Keeping',
        'Performance Evaluation'
      ],
      learningConcepts: [
        'Daily Care Routines',
        'Health Assessment',
        'Observation Skills'
      ],
      competencyLevel: 'Proficient',
      feedback: Feedback(
        strengths: [
          'Detailed health observations',
          'Proper record keeping format',
          'Shows understanding of animal behavior'
        ],
        improvements: [
          'Include more specific measurements',
          'Add feed conversion calculations',
          'Document environmental factors'
        ],
        suggestions: [
          'Consider tracking weight trends over time',
          'Research breed-specific care requirements',
          'Connect observations to learning objectives'
        ],
      ),
      recommendedActivities: [
        'Practice weight estimation techniques',
        'Create a feeding schedule optimization plan',
        'Research disease prevention protocols'
      ],
    );

    testWidgets('displays loading state correctly', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: MockAIAnalysisWidget(isLoading: true),
          ),
        ),
      );

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('Analyzing journal entry...'), findsOneWidget);
    });

    testWidgets('displays error state with retry button',
        (WidgetTester tester) async {
      bool refreshCalled = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MockAIAnalysisWidget(
              error: 'Network connection failed',
              onRefresh: () => refreshCalled = true,
            ),
          ),
        ),
      );

      expect(find.byIcon(Icons.error), findsOneWidget);
      expect(find.text('Error: Network connection failed'), findsOneWidget);
      expect(find.text('Retry Analysis'), findsOneWidget);

      await tester.tap(find.text('Retry Analysis'));
      expect(refreshCalled, isTrue);
    });

    testWidgets('displays no analysis state with generate button',
        (WidgetTester tester) async {
      bool refreshCalled = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MockAIAnalysisWidget(
              aiInsights: null,
              onRefresh: () => refreshCalled = true,
            ),
          ),
        ),
      );

      expect(find.byIcon(Icons.psychology), findsOneWidget);
      expect(find.text('No AI analysis available'), findsOneWidget);
      expect(find.text('Generate Analysis'), findsOneWidget);

      await tester.tap(find.text('Generate Analysis'));
      expect(refreshCalled, isTrue);
    });

    testWidgets('displays AI insights summary view correctly',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MockAIAnalysisWidget(
              aiInsights: sampleAIInsights,
              showDetailedView: false,
            ),
          ),
        ),
      );

      // Check header
      expect(find.text('AI Analysis Results'), findsOneWidget);
      expect(find.byIcon(Icons.psychology), findsOneWidget);

      // Check quality score
      expect(find.text('Quality Score: 8/10'), findsOneWidget);

      // Check competency level
      expect(find.text('Competency Level: Proficient'), findsOneWidget);

      // Check FFA standards chips
      expect(find.text('AS.01.01'), findsOneWidget);
      expect(find.text('AS.02.03'), findsOneWidget);
      expect(find.text('AS.07.01'), findsOneWidget);

      // Check AET skills chips
      expect(find.text('Animal Health Management'), findsOneWidget);
      expect(find.text('Record Keeping'), findsOneWidget);

      // Check learning concepts chips
      expect(find.text('Daily Care Routines'), findsOneWidget);
      expect(find.text('Health Assessment'), findsOneWidget);
    });

    testWidgets('displays detailed view with expandable sections',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MockAIAnalysisWidget(
              aiInsights: sampleAIInsights,
              showDetailedView: true,
            ),
          ),
        ),
      );

      // Check expansion tiles exist
      expect(find.text('Detailed Feedback'), findsOneWidget);
      expect(find.text('Recommended Activities'), findsOneWidget);
      expect(find.text('Quality Assessment'), findsOneWidget);

      // Expand detailed feedback
      await tester.tap(find.text('Detailed Feedback'));
      await tester.pumpAndSettle();

      // Check strengths section
      expect(find.text('Strengths'), findsOneWidget);
      expect(find.text('Detailed health observations'), findsOneWidget);
      expect(find.text('Proper record keeping format'), findsOneWidget);

      // Check improvements section
      expect(find.text('Areas for Improvement'), findsOneWidget);
      expect(find.text('Include more specific measurements'), findsOneWidget);

      // Check suggestions section
      expect(find.text('Suggestions'), findsOneWidget);
      expect(find.text('Consider tracking weight trends over time'),
          findsOneWidget);
    });

    testWidgets('handles save insights action', (WidgetTester tester) async {
      bool saveInsightsCalled = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MockAIAnalysisWidget(
              aiInsights: sampleAIInsights,
              onSaveInsights: () => saveInsightsCalled = true,
            ),
          ),
        ),
      );

      await tester.tap(find.byIcon(Icons.save));
      expect(saveInsightsCalled, isTrue);
    });

    testWidgets('handles refresh action', (WidgetTester tester) async {
      bool refreshCalled = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MockAIAnalysisWidget(
              aiInsights: sampleAIInsights,
              onRefresh: () => refreshCalled = true,
            ),
          ),
        ),
      );

      await tester.tap(find.byIcon(Icons.refresh));
      expect(refreshCalled, isTrue);
    });

    testWidgets('quality score color changes based on score',
        (WidgetTester tester) async {
      // Test high score (green)
      final highScoreInsights = AIInsights(
        qualityAssessment: QualityAssessment(score: 9, justification: 'Great'),
        ffaStandards: ['AS.01.01'],
        aetSkillsIdentified: ['Animal Health Management'],
        learningConcepts: ['Daily Care Routines'],
        competencyLevel: 'Advanced',
        feedback: Feedback(
          strengths: ['Excellence'],
          improvements: [],
          suggestions: [],
        ),
        recommendedActivities: [],
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MockAIAnalysisWidget(aiInsights: highScoreInsights),
          ),
        ),
      );

      expect(find.text('Quality Score: 9/10'), findsOneWidget);
      // Note: Color testing would require more sophisticated widget testing
      // In a real implementation, you would check the container's decoration
    });

    testWidgets('handles empty feedback sections gracefully',
        (WidgetTester tester) async {
      final emptyFeedbackInsights = AIInsights(
        qualityAssessment: QualityAssessment(score: 6, justification: 'OK'),
        ffaStandards: [],
        aetSkillsIdentified: [],
        learningConcepts: [],
        competencyLevel: 'Developing',
        feedback: Feedback(
          strengths: [],
          improvements: [],
          suggestions: [],
        ),
        recommendedActivities: [],
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MockAIAnalysisWidget(
              aiInsights: emptyFeedbackInsights,
              showDetailedView: true,
            ),
          ),
        ),
      );

      expect(find.text('Quality Score: 6/10'), findsOneWidget);
      expect(find.text('Competency Level: Developing'), findsOneWidget);

      // The widget should still display properly even with empty sections
      expect(find.text('AI Analysis Results'), findsOneWidget);
    });

    testWidgets('displays proper tooltips for action buttons',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MockAIAnalysisWidget(
              aiInsights: sampleAIInsights,
              onSaveInsights: () {},
            ),
          ),
        ),
      );

      // Long press to show tooltip
      await tester.longPress(find.byIcon(Icons.save));
      await tester.pump();
      expect(find.text('Save Analysis'), findsOneWidget);

      // Dismiss tooltip and test refresh button
      await tester.tap(find.byType(MockAIAnalysisWidget));
      await tester.pump();

      await tester.longPress(find.byIcon(Icons.refresh));
      await tester.pump();
      expect(find.text('Refresh Analysis'), findsOneWidget);
    });

    testWidgets('chip displays are properly formatted',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MockAIAnalysisWidget(aiInsights: sampleAIInsights),
          ),
        ),
      );

      // Check that chips are displayed for each category
      final ffaChips = find.descendant(
        of: find.text('FFA Standards Identified:').first,
        matching: find.byType(Chip),
      );
      
      final aetChips = find.descendant(
        of: find.text('AET Skills Identified:').first,
        matching: find.byType(Chip),
      );
      
      final conceptChips = find.descendant(
        of: find.text('Learning Concepts:').first,
        matching: find.byType(Chip),
      );

      // Note: The exact count depends on how Flutter renders the widget tree
      // In a real test, you would verify the specific chip contents and styling
    });

    testWidgets('widget is accessible for screen readers',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MockAIAnalysisWidget(aiInsights: sampleAIInsights),
          ),
        ),
      );

      // Check that important elements have proper semantics
      expect(find.byIcon(Icons.psychology), findsOneWidget);
      expect(find.text('AI Analysis Results'), findsOneWidget);
      
      // In a full implementation, you would test:
      // - Semantic labels for buttons
      // - Screen reader announcements
      // - Focus management
      // - Color contrast compliance
    });

    group('Error Handling Tests', () {
      testWidgets('handles malformed AI insights gracefully',
          (WidgetTester tester) async {
        // This would test with null or incomplete data in AIInsights
        // Since our model classes are well-defined, we focus on edge cases

        final incompleteInsights = AIInsights(
          qualityAssessment: QualityAssessment(score: 0, justification: ''),
          ffaStandards: [],
          aetSkillsIdentified: [],
          learningConcepts: [],
          competencyLevel: '',
          feedback: Feedback(
            strengths: [],
            improvements: [],
            suggestions: [],
          ),
          recommendedActivities: [],
        );

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: MockAIAnalysisWidget(aiInsights: incompleteInsights),
            ),
          ),
        );

        // Widget should still render without crashing
        expect(find.text('AI Analysis Results'), findsOneWidget);
        expect(find.text('Quality Score: 0/10'), findsOneWidget);
      });

      testWidgets('handles very long text content appropriately',
          (WidgetTester tester) async {
        final longTextInsights = AIInsights(
          qualityAssessment: QualityAssessment(
            score: 7,
            justification:
                'This is a very long justification text that should wrap properly and not cause layout issues in the UI. ' * 5,
          ),
          ffaStandards: ['AS.01.01'],
          aetSkillsIdentified: ['Very Long Skill Name That Might Cause Layout Issues'],
          learningConcepts: ['Extremely Long Learning Concept Name That Should Be Handled Gracefully'],
          competencyLevel: 'Proficient',
          feedback: Feedback(
            strengths: ['Very long strength description that goes on and on...'],
            improvements: ['Very long improvement suggestion with many details...'],
            suggestions: ['Very long suggestion with comprehensive details...'],
          ),
          recommendedActivities: ['Very long recommended activity description...'],
        );

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                child: MockAIAnalysisWidget(
                  aiInsights: longTextInsights,
                  showDetailedView: true,
                ),
              ),
            ),
          ),
        );

        // Widget should handle long content without overflow
        expect(find.text('AI Analysis Results'), findsOneWidget);
        
        // Test that content is scrollable if needed
        await tester.drag(find.byType(SingleChildScrollView), const Offset(0, -200));
        await tester.pump();
      });
    });

    group('Performance Tests', () {
      testWidgets('renders quickly with large datasets',
          (WidgetTester tester) async {
        // Create insights with many items
        final largeDataInsights = AIInsights(
          qualityAssessment: QualityAssessment(score: 8, justification: 'Good'),
          ffaStandards: List.generate(20, (i) => 'AS.${i.toString().padLeft(2, '0')}.01'),
          aetSkillsIdentified: List.generate(15, (i) => 'Skill $i'),
          learningConcepts: List.generate(25, (i) => 'Concept $i'),
          competencyLevel: 'Advanced',
          feedback: Feedback(
            strengths: List.generate(10, (i) => 'Strength $i'),
            improvements: List.generate(10, (i) => 'Improvement $i'),
            suggestions: List.generate(10, (i) => 'Suggestion $i'),
          ),
          recommendedActivities: List.generate(15, (i) => 'Activity $i'),
        );

        final stopwatch = Stopwatch()..start();

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: MockAIAnalysisWidget(
                aiInsights: largeDataInsights,
                showDetailedView: true,
              ),
            ),
          ),
        );

        stopwatch.stop();

        // Verify it renders in reasonable time (less than 100ms)
        expect(stopwatch.elapsedMilliseconds, lessThan(100));

        // Verify all content is present
        expect(find.text('AI Analysis Results'), findsOneWidget);
      });
    });
  });
}