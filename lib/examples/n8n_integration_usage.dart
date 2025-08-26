/// Example usage of the N8N Webhook Service integration
/// This file demonstrates how to use the enhanced AI processing capabilities
/// in your Flutter application with robust error handling and offline support.

import '../services/journal_service.dart';
import '../services/n8n_webhook_service.dart';
import '../models/journal_entry.dart';

class N8NIntegrationExamples {
  
  /// Example 1: Create a journal entry with automatic AI processing
  static Future<void> createEntryWithAIAnalysis() async {
    try {
      // Create a new journal entry
      final entry = JournalEntry(
        userId: 'user123',
        title: 'Daily Health Check - Holstein Heifer',
        description: '''
        Performed comprehensive health assessment of Holstein heifer #247 today.
        
        Observations:
        - Temperature: 101.2°F (normal range)
        - Eyes: Clear, bright, no discharge
        - Nose: Moist, cool to touch
        - Appetite: Excellent - consumed full grain ration
        - Movement: Normal gait, no signs of lameness
        - Coat condition: Shiny, well-groomed
        
        Actions taken:
        - Provided fresh water
        - Applied fly spray for pest control
        - Checked hooves - all appear healthy
        - Updated weight record: 650 lbs
        
        Learning outcomes:
        - Improved ability to identify normal vs abnormal signs
        - Better understanding of daily care requirements
        - Gained confidence in animal handling techniques
        
        Next steps:
        - Continue daily monitoring
        - Schedule vaccination with veterinarian next week
        - Begin show training preparation
        ''',
        date: DateTime.now(),
        duration: 45, // minutes
        category: 'health_check',
        aetSkills: [
          'Animal Health Management',
          'Performance Evaluation',
          'Record Keeping',
        ],
        animalId: 'animal_holstein_247',
        objectives: [
          'Assess overall animal health',
          'Practice observation skills',
          'Maintain accurate records',
        ],
        challenges: 'Animal was slightly nervous during examination',
        improvements: 'Need to work on calming techniques',
        countsForDegree: true,
        ffaDegreeType: 'Chapter FFA Degree',
        saType: 'Entrepreneurship',
        hoursLogged: 0.75,
        financialValue: 25.0, // Value of time and care
        evidenceType: 'Performance Assessment',
        locationData: LocationData(
          latitude: 40.7128,
          longitude: -74.0060,
          address: '123 Farm Road, Agricultural Valley, IN',
          name: 'Valley View Farm',
        ),
        weatherData: WeatherData(
          temperature: 72.0,
          condition: 'Partly Cloudy',
          humidity: 65,
          windSpeed: 8.5,
          description: 'Pleasant conditions for outdoor work',
        ),
        tags: ['health', 'holstein', 'daily_care', 'ffa_project'],
      );

      // Create the entry (this will trigger AI processing automatically)
      final createdEntry = await JournalService.createEntry(entry);
      print('✅ Entry created: ${createdEntry.id}');
      
      // The AI processing happens asynchronously, but you can also wait for results
      if (createdEntry.id != null) {
        print('⏳ Waiting for AI analysis...');
        final analysisResult = await JournalService.processWithAI(createdEntry.id!);
        
        print('🤖 AI Analysis Results:');
        print('   Quality Score: ${analysisResult.qualityScore}/10');
        print('   Competency Level: ${analysisResult.competencyLevel}');
        print('   FFA Standards: ${analysisResult.ffaStandards.join(", ")}');
        print('   Recommendations: ${analysisResult.recommendations.length}');
      }
      
    } catch (e) {
      print('❌ Error: $e');
    }
  }

  /// Example 2: Process existing entry with enhanced AI analysis
  static Future<void> processExistingEntry(String entryId) async {
    try {
      print('🔍 Fetching entry $entryId...');
      final entry = await JournalService.getEntry(entryId);
      
      if (entry == null) {
        print('❌ Entry not found');
        return;
      }

      print('🤖 Processing with AI...');
      final result = await N8NWebhookService.processJournalEntry(entry);
      
      print('✅ Analysis complete!');
      print('📊 Results Summary:');
      print('   Request ID: ${result.requestId}');
      print('   Status: ${result.status}');
      print('   Quality Score: ${result.qualityScore}/10');
      print('   Educational Concepts: ${result.educationalConcepts.join(", ")}');
      
      // Display detailed feedback
      final feedback = result.aiInsights.feedback;
      print('💪 Strengths:');
      feedback.strengths.forEach((strength) => print('   • $strength'));
      
      print('📈 Areas for Improvement:');
      feedback.improvements.forEach((improvement) => print('   • $improvement'));
      
      print('💡 Suggestions:');
      feedback.suggestions.forEach((suggestion) => print('   • $suggestion'));
      
    } catch (e) {
      print('❌ Processing failed: $e');
    }
  }

  /// Example 3: Batch process multiple entries with retry handling
  static Future<void> batchProcessEntries(List<String> entryIds) async {
    print('📦 Starting batch processing of ${entryIds.length} entries...');
    
    final results = <String, N8NAnalysisResult>{};
    final failed = <String>[];
    
    for (final entryId in entryIds) {
      try {
        print('⏳ Processing entry $entryId...');
        
        final entry = await JournalService.getEntry(entryId);
        if (entry == null) {
          print('⚠️ Entry $entryId not found, skipping...');
          continue;
        }

        final result = await N8NWebhookService.processJournalEntry(entry);
        results[entryId] = result;
        
        print('✅ Entry $entryId processed (Score: ${result.qualityScore}/10)');
        
        // Small delay to avoid overwhelming the webhook
        await Future.delayed(Duration(seconds: 2));
        
      } catch (e) {
        print('❌ Failed to process $entryId: $e');
        failed.add(entryId);
      }
    }
    
    print('📊 Batch Processing Complete:');
    print('   Successful: ${results.length}');
    print('   Failed: ${failed.length}');
    
    if (results.isNotEmpty) {
      final avgScore = results.values
          .map((r) => r.qualityScore)
          .reduce((a, b) => a + b) / results.length;
      print('   Average Quality Score: ${avgScore.toStringAsFixed(1)}/10');
    }
    
    // Process retry queue for failed entries
    if (failed.isNotEmpty) {
      print('🔄 Processing retry queue...');
      await JournalService.processAIRetryQueue();
    }
  }

  /// Example 4: Handle offline scenarios with fallback analysis
  static Future<void> demonstrateOfflineFallback() async {
    try {
      // Create an entry that might need offline handling
      final entry = JournalEntry(
        userId: 'user123',
        title: 'Quick Feed Check',
        description: 'Fed the animals their evening grain ration. All animals ate well.',
        date: DateTime.now(),
        duration: 15,
        category: 'feeding',
        aetSkills: ['Feeding and Nutrition'],
      );

      print('📱 Creating entry (may go offline)...');
      final createdEntry = await JournalService.createEntry(entry);
      
      print('🤖 Attempting AI processing...');
      final analysisResult = await JournalService.processWithAIAndReturn(createdEntry);
      
      if (analysisResult != null) {
        if (analysisResult.status == 'completed_offline') {
          print('📴 Processed offline with fallback analysis');
          print('   Quality Score: ${analysisResult.qualityScore}/10 (estimated)');
          print('   This entry will be reprocessed when online');
        } else {
          print('🌐 Processed online with full AI analysis');
          print('   Quality Score: ${analysisResult.qualityScore}/10');
        }
      }
      
    } catch (e) {
      print('❌ Error in offline demonstration: $e');
    }
  }

  /// Example 5: Monitor and display processing status
  static Future<void> monitorProcessingStatus() async {
    try {
      print('📊 Checking processing status...');
      
      // Get user statistics
      final stats = await JournalService.getUserStats();
      print('📈 Journal Statistics:');
      print('   Total Entries: ${stats.totalEntries}');
      print('   Average Quality Score: ${stats.averageQualityScore.toStringAsFixed(1)}/10');
      print('   Pending Sync: ${stats.pendingSyncCount}');
      
      // Get recent entries
      final recentEntries = await JournalService.getEntries(limit: 5);
      print('📝 Recent Entries:');
      
      for (final entry in recentEntries) {
        final hasAI = entry.aiInsights != null;
        final qualityScore = entry.qualityScore ?? 0;
        final syncStatus = entry.isSynced ? '✅' : '⏳';
        final aiStatus = hasAI ? '🤖' : '❓';
        
        print('   $syncStatus $aiStatus ${entry.title} (Score: $qualityScore/10)');
      }
      
      // Process any pending retries
      print('🔄 Processing retry queue...');
      await JournalService.processAIRetryQueue();
      
    } catch (e) {
      print('❌ Error monitoring status: $e');
    }
  }

  /// Example 6: Search and analyze entries by criteria
  static Future<void> searchAndAnalyzeEntries() async {
    try {
      print('🔍 Searching for health check entries...');
      
      final healthEntries = await JournalService.searchEntries(
        query: 'health',
        category: 'health_check',
        limit: 10,
      );
      
      print('Found ${healthEntries.length} health check entries');
      
      // Analyze quality trends
      final qualityScores = healthEntries
          .where((e) => e.qualityScore != null)
          .map((e) => e.qualityScore!)
          .toList();
      
      if (qualityScores.isNotEmpty) {
        final avgQuality = qualityScores.reduce((a, b) => a + b) / qualityScores.length;
        final maxQuality = qualityScores.reduce((a, b) => a > b ? a : b);
        final minQuality = qualityScores.reduce((a, b) => a < b ? a : b);
        
        print('📊 Health Check Quality Analysis:');
        print('   Average: ${avgQuality.toStringAsFixed(1)}/10');
        print('   Best: $maxQuality/10');
        print('   Lowest: $minQuality/10');
      }
      
      // Find entries without AI analysis and process them
      final unanalyzed = healthEntries.where((e) => e.aiInsights == null).toList();
      if (unanalyzed.isNotEmpty) {
        print('🤖 Found ${unanalyzed.length} entries without AI analysis');
        print('Processing them now...');
        
        for (final entry in unanalyzed.take(3)) { // Process only first 3
          try {
            final result = await N8NWebhookService.processJournalEntry(entry);
            print('   ✅ Analyzed "${entry.title}" - Score: ${result.qualityScore}/10');
          } catch (e) {
            print('   ❌ Failed to analyze "${entry.title}": $e');
          }
        }
      }
      
    } catch (e) {
      print('❌ Error in search and analysis: $e');
    }
  }

  /// Example 7: Export analysis results for reporting
  static Future<Map<String, dynamic>> generateAnalyticsReport() async {
    try {
      print('📊 Generating analytics report...');
      
      // Get comprehensive analytics
      final analytics = await JournalService.getAnalytics();
      
      // Get all entries for detailed analysis
      final allEntries = await JournalService.getEntries(limit: 1000);
      
      // Calculate AI processing statistics
      final aiProcessedCount = allEntries.where((e) => e.aiInsights != null).length;
      final aiProcessingRate = allEntries.isNotEmpty 
          ? (aiProcessedCount / allEntries.length * 100).toStringAsFixed(1)
          : '0.0';
      
      // FFA standards analysis
      final allFFAStandards = <String>{};
      final competencyLevels = <String, int>{};
      
      for (final entry in allEntries.where((e) => e.ffaStandards != null)) {
        allFFAStandards.addAll(entry.ffaStandards!);
        
        if (entry.competencyLevel != null) {
          competencyLevels[entry.competencyLevel!] = 
              (competencyLevels[entry.competencyLevel!] ?? 0) + 1;
        }
      }
      
      final report = {
        'generated_at': DateTime.now().toIso8601String(),
        'summary': {
          'total_entries': allEntries.length,
          'ai_processed': aiProcessedCount,
          'ai_processing_rate': '${aiProcessingRate}%',
          'unique_ffa_standards': allFFAStandards.length,
        },
        'quality_metrics': {
          'average_quality_score': analytics['stats']['averageQualityScore'],
          'total_hours_logged': analytics['stats']['totalHours'],
          'ffa_degree_entries': analytics['stats']['ffaDegreeEntries'],
        },
        'competency_distribution': competencyLevels,
        'ffa_standards_covered': allFFAStandards.toList()..sort(),
        'category_breakdown': analytics['stats']['categoryBreakdown'],
        'weekly_activity': analytics['weeklyActivity'],
        'top_skills': analytics['skillProgression'],
      };
      
      print('✅ Analytics report generated');
      print('   📝 Total Entries: ${report['summary']['total_entries']}');
      print('   🤖 AI Processed: ${report['summary']['ai_processing_rate']}');
      print('   📊 FFA Standards: ${report['summary']['unique_ffa_standards']}');
      
      return report;
      
    } catch (e) {
      print('❌ Error generating report: $e');
      return {};
    }
  }

  /// Example 8: Demonstrate error handling and recovery
  static Future<void> demonstrateErrorHandling() async {
    print('🛠️ Testing error handling scenarios...');
    
    // Test 1: Invalid entry ID
    try {
      await JournalService.processWithAI('invalid_id');
    } catch (e) {
      print('✅ Correctly handled invalid entry ID: $e');
    }
    
    // Test 2: Network timeout simulation
    try {
      final entry = JournalEntry(
        userId: 'test_user',
        title: 'Test Entry',
        description: 'This is a test entry for error handling',
        date: DateTime.now(),
        duration: 10,
        category: 'other',
        aetSkills: [],
      );
      
      // This should handle network issues gracefully
      final result = await JournalService.processWithAIAndReturn(entry);
      
      if (result?.status == 'completed_offline') {
        print('✅ Network issue handled with offline fallback');
      } else if (result?.status == 'completed') {
        print('✅ Network request succeeded');
      } else {
        print('⚠️ Unexpected result status: ${result?.status}');
      }
      
    } catch (e) {
      print('✅ Network error handled gracefully: $e');
    }
    
    // Test 3: Retry queue processing
    print('🔄 Processing retry queue to handle failed requests...');
    await JournalService.processAIRetryQueue();
    print('✅ Retry queue processed');
  }
}

/// Usage instructions:
/// 
/// 1. Basic usage - Create entry with AI analysis:
///    await N8NIntegrationExamples.createEntryWithAIAnalysis();
/// 
/// 2. Process existing entry:
///    await N8NIntegrationExamples.processExistingEntry('entry_id_here');
/// 
/// 3. Batch processing:
///    await N8NIntegrationExamples.batchProcessEntries(['id1', 'id2', 'id3']);
/// 
/// 4. Monitor status:
///    await N8NIntegrationExamples.monitorProcessingStatus();
/// 
/// 5. Generate report:
///    final report = await N8NIntegrationExamples.generateAnalyticsReport();
/// 
/// Remember to handle errors appropriately in your production code and
/// ensure proper user feedback during AI processing operations.