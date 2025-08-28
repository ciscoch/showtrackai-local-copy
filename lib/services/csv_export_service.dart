import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:flutter/foundation.dart';
// Web-safe import using conditional import
import 'csv_export_io.dart' if (dart.library.html) 'csv_export_web.dart';
import '../models/journal_entry.dart';
import '../models/animal.dart';
import 'animal_service.dart';

/// Service for exporting journal entries to CSV format
/// Handles all agricultural data fields and supports filtered exports
class CsvExportService {
  static final DateFormat _dateFormat = DateFormat('yyyy-MM-dd');
  static final DateFormat _dateTimeFormat = DateFormat('yyyy-MM-dd HH:mm:ss');
  
  /// Export journal entries to CSV
  static Future<void> exportJournalEntries({
    required List<JournalEntry> entries,
    String? fileName,
    DateTimeRange? dateRange,
    String? animalFilter,
    String? categoryFilter,
    bool includeAIInsights = true,
    bool includeWeatherData = true,
    bool includeLocationData = true,
    bool includeFinancialData = true,
    bool includeFeedData = true,
    bool includeCompetencyData = true,
    Function(String)? onProgress,
  }) async {
    try {
      // Memory usage check for large datasets
      if (entries.length > 1000) {
        onProgress?.call('Processing large dataset (${entries.length} entries)...');
      }
      // Filter entries based on provided criteria
      final filteredEntries = filterEntries(
        entries,
        dateRange: dateRange,
        animalId: animalFilter,
        category: categoryFilter,
      );

      if (filteredEntries.isEmpty) {
        throw Exception('No entries to export with the selected filters');
      }

      // Load animal data for names
      final animalService = AnimalService();
      final animals = await animalService.getAnimals();
      final animalMap = <String, Animal>{
        for (var animal in animals) 
          if (animal.id != null) animal.id!: animal
      };

      // Generate CSV content with streaming for large datasets
      final csvContent = await _generateCsvContent(
        filteredEntries,
        animalMap,
        includeAIInsights: includeAIInsights,
        includeWeatherData: includeWeatherData,
        includeLocationData: includeLocationData,
        includeFinancialData: includeFinancialData,
        includeFeedData: includeFeedData,
        includeCompetencyData: includeCompetencyData,
        onProgress: onProgress,
      );

      // Generate filename with timestamp
      final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
      final exportFileName = fileName ?? 'journal_export_$timestamp.csv';

      // Download the file
      _downloadCsv(csvContent, exportFileName);
      
    } catch (e) {
      print('Error exporting journal entries: $e');
      throw Exception('Failed to export journal entries: $e');
    }
  }

  /// Filter entries based on criteria
  static List<JournalEntry> filterEntries(
    List<JournalEntry> entries, {
    DateTimeRange? dateRange,
    String? animalId,
    String? category,
  }) {
    return entries.where((entry) {
      // Date range filter
      if (dateRange != null) {
        final entryDate = entry.date;
        if (entryDate.isBefore(dateRange.start) || 
            entryDate.isAfter(dateRange.end.add(const Duration(days: 1)))) {
          return false;
        }
      }

      // Animal filter
      if (animalId != null && animalId.isNotEmpty) {
        if (entry.animalId != animalId) {
          return false;
        }
      }

      // Category filter
      if (category != null && category.isNotEmpty) {
        if (entry.category != category) {
          return false;
        }
      }

      return true;
    }).toList();
  }

  /// Generate CSV content from journal entries
  static Future<String> _generateCsvContent(
    List<JournalEntry> entries,
    Map<String, Animal> animalMap, {
    required bool includeAIInsights,
    required bool includeWeatherData,
    required bool includeLocationData,
    required bool includeFinancialData,
    required bool includeFeedData,
    required bool includeCompetencyData,
    Function(String)? onProgress,
  }) async {
    final buffer = StringBuffer();
    
    // Build header row
    final headers = <String>[
      'Entry ID',
      'Date',
      'Title',
      'Category',
      'Duration (minutes)',
      'Description',
      'Animal Name',
      'Animal ID',
      'AET Skills',
      'Learning Objectives',
      'Learning Outcomes',
      'Challenges Faced',
      'Improvements Planned',
    ];

    // Add FFA/Educational headers
    headers.addAll([
      'FFA Standards',
      'Educational Concepts',
      'Competency Level',
      'FFA Degree Type',
      'Counts for Degree',
      'SAE Type',
      'Hours Logged',
      'Evidence Type',
    ]);

    // Add financial headers if included
    if (includeFinancialData) {
      headers.addAll([
        'Financial Value',
      ]);
    }

    // Add feed data headers if included
    if (includeFeedData) {
      headers.addAll([
        'Feed Brand',
        'Feed Type',
        'Feed Amount',
        'Feed Cost',
        'Feed Conversion Ratio',
        'Current Weight',
        'Target Weight',
        'Weigh-In Date',
      ]);
    }

    // Add weather data headers if included
    if (includeWeatherData) {
      headers.addAll([
        'Temperature (°F)',
        'Weather Condition',
        'Humidity (%)',
        'Wind Speed (mph)',
        'Weather Description',
      ]);
    }

    // Add location data headers if included
    if (includeLocationData) {
      headers.addAll([
        'Location Name',
        'Address',
        'City',
        'State',
        'Latitude',
        'Longitude',
      ]);
    }

    // Add competency tracking headers if included
    if (includeCompetencyData) {
      headers.addAll([
        'Demonstrated Skills',
        'Completed Standards',
        'Progress Percentage',
        'Last Assessment',
      ]);
    }

    // Add AI insights headers if included
    if (includeAIInsights) {
      headers.addAll([
        'Quality Score',
        'AI Assessment Score',
        'AI Assessment Justification',
        'AI Strengths',
        'AI Improvements',
        'AI Suggestions',
        'Recommended Activities',
      ]);
    }

    // Add metadata headers
    headers.addAll([
      'Tags',
      'Notes',
      'Source',
      'Supervisor ID',
      'Is Public',
      'Is Synced',
      'Created At',
      'Updated At',
    ]);

    // Write headers
    buffer.writeln(_csvRow(headers));

    // Write data rows with progress tracking
    for (int i = 0; i < entries.length; i++) {
      final entry = entries[i];
      final animal = entry.animalId != null ? animalMap[entry.animalId] : null;
      
      // Report progress for large datasets
      if (entries.length > 100 && i % 50 == 0) {
        final progress = ((i + 1) / entries.length * 100).round();
        onProgress?.call('Processing entry ${i + 1} of ${entries.length} ($progress%)');
      }
      
      final row = <String>[
        entry.id ?? '',
        _dateFormat.format(entry.date),
        entry.title,
        JournalCategories.getDisplayName(entry.category),
        entry.duration.toString(),
        _escapeField(entry.description),
        animal?.name ?? '',
        entry.animalId ?? '',
        entry.aetSkills.join('; '),
        entry.objectives?.join('; ') ?? '',
        entry.learningOutcomes?.join('; ') ?? '',
        entry.challenges ?? '',
        entry.improvements ?? '',
      ];

      // Add FFA/Educational data
      row.addAll([
        entry.ffaStandards?.join('; ') ?? '',
        entry.educationalConcepts?.join('; ') ?? '',
        entry.competencyLevel ?? '',
        entry.ffaDegreeType ?? '',
        entry.countsForDegree ? 'Yes' : 'No',
        entry.saType ?? '',
        entry.hoursLogged?.toString() ?? '',
        entry.evidenceType ?? '',
      ]);

      // Add financial data if included
      if (includeFinancialData) {
        row.add(entry.financialValue?.toStringAsFixed(2) ?? '');
      }

      // Add feed data if included
      if (includeFeedData) {
        row.addAll([
          entry.feedData?.brand ?? '',
          entry.feedData?.type ?? '',
          entry.feedData?.amount.toString() ?? '',
          entry.feedData?.cost.toStringAsFixed(2) ?? '',
          entry.feedData?.feedConversionRatio?.toStringAsFixed(2) ?? '',
          entry.feedStrategy?.currentWeight?.toString() ?? '',
          entry.feedStrategy?.targetWeight?.toString() ?? '',
          entry.feedStrategy?.weighInDate != null 
            ? _dateFormat.format(entry.feedStrategy!.weighInDate!) 
            : '',
        ]);
      }

      // Add weather data if included
      if (includeWeatherData) {
        row.addAll([
          entry.weatherData?.temperature?.toStringAsFixed(1) ?? '',
          entry.weatherData?.condition ?? '',
          entry.weatherData?.humidity?.toString() ?? '',
          entry.weatherData?.windSpeed?.toStringAsFixed(1) ?? '',
          entry.weatherData?.description ?? '',
        ]);
      }

      // Add location data if included
      if (includeLocationData) {
        row.addAll([
          entry.locationData?.name ?? '',
          entry.locationData?.address ?? '',
          entry.locationData?.city ?? '',
          entry.locationData?.state ?? '',
          entry.locationData?.latitude?.toStringAsFixed(6) ?? '',
          entry.locationData?.longitude?.toStringAsFixed(6) ?? '',
        ]);
      }

      // Add competency tracking if included
      if (includeCompetencyData) {
        row.addAll([
          entry.competencyTracking?.demonstratedSkills.join('; ') ?? '',
          entry.competencyTracking?.completedStandards.join('; ') ?? '',
          entry.competencyTracking?.progressPercentage.toStringAsFixed(1) ?? '',
          entry.competencyTracking?.lastAssessment != null
            ? _dateTimeFormat.format(entry.competencyTracking!.lastAssessment!)
            : '',
        ]);
      }

      // Add AI insights if included
      if (includeAIInsights && entry.aiInsights != null) {
        row.addAll([
          entry.qualityScore?.toString() ?? '',
          entry.aiInsights!.qualityAssessment.score.toString(),
          _escapeField(entry.aiInsights!.qualityAssessment.justification),
          entry.aiInsights!.feedback.strengths.join('; '),
          entry.aiInsights!.feedback.improvements.join('; '),
          entry.aiInsights!.feedback.suggestions.join('; '),
          entry.aiInsights!.recommendedActivities.join('; '),
        ]);
      } else if (includeAIInsights) {
        row.addAll(List.filled(7, ''));
      }

      // Add metadata
      row.addAll([
        entry.tags?.join('; ') ?? '',
        entry.notes ?? '',
        entry.source ?? '',
        entry.supervisorId ?? '',
        entry.isPublic ? 'Yes' : 'No',
        entry.isSynced ? 'Yes' : 'No',
        entry.createdAt != null ? _dateTimeFormat.format(entry.createdAt!) : '',
        entry.updatedAt != null ? _dateTimeFormat.format(entry.updatedAt!) : '',
      ]);

      buffer.writeln(_csvRow(row));
    }

    return buffer.toString();
  }

  /// Create a CSV row from a list of values
  static String _csvRow(List<String> fields) {
    return fields.map((field) => _escapeField(field)).join(',');
  }

  /// Escape a field for CSV format
  static String _escapeField(String field) {
    // If field contains comma, newline, or quote, wrap in quotes
    if (field.contains(',') || field.contains('\n') || field.contains('"')) {
      // Escape quotes by doubling them
      final escaped = field.replaceAll('"', '""');
      return '"$escaped"';
    }
    return field;
  }

  /// Download CSV file (platform specific implementation)
  static void _downloadCsv(String csvContent, String fileName) {
    // The conditional import will handle platform-specific implementation
    // Both methods have the same signature
    downloadCsvIO(csvContent, fileName);
  }

  /// Export a summary report of journal entries
  static Future<void> exportSummaryReport({
    required List<JournalEntry> entries,
    String? fileName,
    DateTimeRange? dateRange,
  }) async {
    try {
      final filteredEntries = filterEntries(entries, dateRange: dateRange);
      
      if (filteredEntries.isEmpty) {
        throw Exception('No entries to export for summary report');
      }

      // Generate summary statistics
      final summary = _generateSummaryStatistics(filteredEntries);
      
      // Create CSV content for summary
      final buffer = StringBuffer();
      buffer.writeln('ShowTrackAI Journal Summary Report');
      buffer.writeln('Generated on: ${_dateTimeFormat.format(DateTime.now())}');
      buffer.writeln('');
      
      if (dateRange != null) {
        buffer.writeln('Date Range: ${_dateFormat.format(dateRange.start)} to ${_dateFormat.format(dateRange.end)}');
      }
      buffer.writeln('');
      
      // Summary statistics
      buffer.writeln('Summary Statistics');
      buffer.writeln('Metric,Value');
      summary.forEach((key, value) {
        buffer.writeln('$key,$value');
      });
      buffer.writeln('');
      
      // Category breakdown
      buffer.writeln('Category Breakdown');
      buffer.writeln('Category,Count,Total Hours');
      
      final categoryStats = _getCategoryStatistics(filteredEntries);
      categoryStats.forEach((category, stats) {
        buffer.writeln('${JournalCategories.getDisplayName(category)},${stats['count']},${stats['hours']}');
      });
      
      // Generate filename
      final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
      final exportFileName = fileName ?? 'journal_summary_$timestamp.csv';
      
      // Download the file
      _downloadCsv(buffer.toString(), exportFileName);
      
    } catch (e) {
      print('Error exporting summary report: $e');
      throw Exception('Failed to export summary report: $e');
    }
  }

  /// Generate summary statistics
  static Map<String, String> _generateSummaryStatistics(List<JournalEntry> entries) {
    final stats = <String, String>{};
    
    stats['Total Entries'] = entries.length.toString();
    
    // Calculate total hours
    final totalMinutes = entries.fold<int>(0, (sum, entry) => sum + entry.duration);
    final totalHours = (totalMinutes / 60).toStringAsFixed(1);
    stats['Total Hours'] = totalHours;
    
    // Count unique animals
    final uniqueAnimals = entries
        .where((e) => e.animalId != null)
        .map((e) => e.animalId)
        .toSet()
        .length;
    stats['Unique Animals'] = uniqueAnimals.toString();
    
    // Count entries with AI insights
    final withAI = entries.where((e) => e.aiInsights != null).length;
    stats['Entries with AI Analysis'] = withAI.toString();
    
    // Average quality score
    final scoredEntries = entries.where((e) => e.qualityScore != null);
    if (scoredEntries.isNotEmpty) {
      final avgScore = scoredEntries.fold<int>(0, (sum, entry) => sum + entry.qualityScore!) / scoredEntries.length;
      stats['Average Quality Score'] = avgScore.toStringAsFixed(1);
    }
    
    // Count FFA degree entries
    final degreeEntries = entries.where((e) => e.countsForDegree).length;
    stats['FFA Degree Qualifying Entries'] = degreeEntries.toString();
    
    // Total financial value
    final totalValue = entries
        .where((e) => e.financialValue != null)
        .fold<double>(0, (sum, entry) => sum + entry.financialValue!);
    if (totalValue > 0) {
      stats['Total Financial Value'] = '\$${totalValue.toStringAsFixed(2)}';
    }
    
    return stats;
  }

  /// Get category statistics
  static Map<String, Map<String, dynamic>> _getCategoryStatistics(List<JournalEntry> entries) {
    final categoryStats = <String, Map<String, dynamic>>{};
    
    for (final entry in entries) {
      if (!categoryStats.containsKey(entry.category)) {
        categoryStats[entry.category] = {
          'count': 0,
          'hours': 0.0,
        };
      }
      
      categoryStats[entry.category]!['count'] += 1;
      categoryStats[entry.category]!['hours'] += entry.duration / 60.0;
    }
    
    // Round hours to 1 decimal place
    categoryStats.forEach((key, value) {
      value['hours'] = (value['hours'] as double).toStringAsFixed(1);
    });
    
    return categoryStats;
  }
}