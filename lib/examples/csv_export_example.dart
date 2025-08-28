import 'package:flutter/material.dart';
import '../models/journal_entry.dart';
import '../models/animal.dart';
import '../services/csv_export_service.dart';

/// Example demonstrating CSV export functionality
/// 
/// This example shows how to:
/// 1. Export all journal entries to CSV
/// 2. Export filtered entries (by date, animal, category)
/// 3. Export summary reports
/// 4. Customize which data fields to include
class CsvExportExample extends StatelessWidget {
  const CsvExportExample({super.key});

  // Sample data for testing
  static final List<JournalEntry> _sampleEntries = [
    JournalEntry(
      id: '1',
      userId: 'user123',
      title: 'Morning Feed and Health Check',
      description: 'Fed 3 lbs of starter feed to heifer #247. Animal appears healthy with good appetite. Temperature normal at 101.5°F.',
      date: DateTime.now().subtract(const Duration(days: 2)),
      duration: 45,
      category: 'health_check',
      aetSkills: ['Animal Health Management', 'Feeding and Nutrition'],
      animalId: 'animal_1',
      feedData: FeedData(
        brand: 'Purina',
        type: 'Starter Feed',
        amount: 3.0,
        cost: 18.50,
        feedConversionRatio: 2.3,
      ),
      objectives: ['Monitor health', 'Track feed intake'],
      learningOutcomes: ['Identified normal vital signs', 'Calculated feed efficiency'],
      challenges: 'Animal was initially hesitant to eat',
      improvements: 'Try feeding at different time tomorrow',
      qualityScore: 8,
      ffaStandards: ['AS.07.01', 'AS.07.02'],
      competencyLevel: 'Proficient',
      weatherData: WeatherData(
        temperature: 72.5,
        condition: 'Partly Cloudy',
        humidity: 65,
        windSpeed: 5.2,
        description: 'Comfortable conditions for livestock',
      ),
      locationData: LocationData(
        latitude: 40.7128,
        longitude: -74.0060,
        address: 'School Farm',
        city: 'Springfield',
        state: 'IL',
      ),
      tags: ['daily-care', 'feeding', 'health'],
      hoursLogged: 0.75,
      financialValue: 18.50,
      countsForDegree: true,
      saType: 'Entrepreneurship',
      ffaDegreeType: 'Chapter FFA Degree',
      isSynced: true,
    ),
    JournalEntry(
      id: '2',
      userId: 'user123',
      title: 'Grooming and Training Session',
      description: 'Worked on halter breaking with steer #182. Made good progress with leading. Also performed full grooming routine.',
      date: DateTime.now().subtract(const Duration(days: 1)),
      duration: 60,
      category: 'training',
      aetSkills: ['Animal Training', 'Show Preparation'],
      animalId: 'animal_2',
      objectives: ['Improve halter training', 'Practice show stance'],
      learningOutcomes: ['Successfully led animal 50 feet', 'Animal held stance for 30 seconds'],
      challenges: 'Animal still pulls on halter occasionally',
      improvements: 'Need to work on stopping command',
      qualityScore: 7,
      ffaStandards: ['AS.06.01', 'AS.06.02'],
      competencyLevel: 'Developing',
      tags: ['training', 'show-prep'],
      hoursLogged: 1.0,
      countsForDegree: true,
      saType: 'Placement',
      ffaDegreeType: 'Chapter FFA Degree',
      isSynced: true,
    ),
    JournalEntry(
      id: '3',
      userId: 'user123',
      title: 'Veterinary Visit and Vaccination',
      description: 'Annual vaccination administered by Dr. Smith. Animal received respiratory vaccine and dewormer. Weight recorded at 850 lbs.',
      date: DateTime.now(),
      duration: 30,
      category: 'veterinary',
      aetSkills: ['Animal Health Management', 'Record Keeping'],
      animalId: 'animal_1',
      objectives: ['Complete annual vaccinations', 'Update health records'],
      learningOutcomes: ['Learned proper restraint technique', 'Understood vaccine schedule'],
      challenges: 'Animal was stressed during injection',
      improvements: 'Practice restraint techniques more',
      qualityScore: 9,
      ffaStandards: ['AS.07.01', 'AS.07.03'],
      competencyLevel: 'Advanced',
      weatherData: WeatherData(
        temperature: 68.0,
        condition: 'Clear',
        humidity: 45,
        windSpeed: 3.5,
        description: 'Perfect weather for veterinary work',
      ),
      tags: ['veterinary', 'vaccination', 'health'],
      hoursLogged: 0.5,
      financialValue: 125.00,
      countsForDegree: true,
      saType: 'Entrepreneurship',
      ffaDegreeType: 'State FFA Degree',
      isSynced: true,
      aiInsights: AIInsights(
        qualityAssessment: QualityAssessment(
          score: 9,
          justification: 'Excellent documentation of veterinary procedures with proper health management practices.',
        ),
        ffaStandards: ['AS.07.01', 'AS.07.03'],
        aetSkillsIdentified: ['Animal Health Management', 'Record Keeping', 'Safety Protocols'],
        learningConcepts: ['Vaccination protocols', 'Animal restraint', 'Health record management'],
        competencyLevel: 'Advanced',
        feedback: Feedback(
          strengths: [
            'Thorough documentation of veterinary procedures',
            'Good understanding of vaccination importance',
            'Proper safety protocols followed',
          ],
          improvements: [
            'Include specific vaccine names and dosages',
            'Document animal behavior more thoroughly',
          ],
          suggestions: [
            'Create a vaccination schedule calendar',
            'Practice restraint techniques during non-stress times',
          ],
        ),
        recommendedActivities: [
          'Review vaccination schedules for other animals',
          'Practice subcutaneous injection technique',
          'Study common livestock diseases',
        ],
      ),
    ),
  ];

  static final List<Animal> _sampleAnimals = [
    Animal(
      id: 'animal_1',
      userId: 'user123',
      name: 'Bessie',
      species: AnimalSpecies.cow,
      breed: 'Holstein',
    ),
    Animal(
      id: 'animal_2',
      userId: 'user123',
      name: 'Thunder',
      species: AnimalSpecies.cow,
      breed: 'Angus',
    ),
  ];

  void _exportAllEntries(BuildContext context) async {
    try {
      await CsvExportService.exportJournalEntries(
        entries: _sampleEntries,
        fileName: 'all_journal_entries.csv',
      );
      
      _showSuccessMessage(context, 'All entries exported successfully!');
    } catch (e) {
      _showErrorMessage(context, 'Export failed: $e');
    }
  }

  void _exportFilteredByDate(BuildContext context) async {
    try {
      final dateRange = DateTimeRange(
        start: DateTime.now().subtract(const Duration(days: 7)),
        end: DateTime.now(),
      );
      
      await CsvExportService.exportJournalEntries(
        entries: _sampleEntries,
        fileName: 'weekly_journal_entries.csv',
        dateRange: dateRange,
      );
      
      _showSuccessMessage(context, 'Weekly entries exported successfully!');
    } catch (e) {
      _showErrorMessage(context, 'Export failed: $e');
    }
  }

  void _exportByCategory(BuildContext context, String category) async {
    try {
      await CsvExportService.exportJournalEntries(
        entries: _sampleEntries,
        fileName: '${category}_entries.csv',
        categoryFilter: category,
      );
      
      _showSuccessMessage(context, '$category entries exported successfully!');
    } catch (e) {
      _showErrorMessage(context, 'Export failed: $e');
    }
  }

  void _exportSummaryReport(BuildContext context) async {
    try {
      await CsvExportService.exportSummaryReport(
        entries: _sampleEntries,
        fileName: 'journal_summary_report.csv',
      );
      
      _showSuccessMessage(context, 'Summary report exported successfully!');
    } catch (e) {
      _showErrorMessage(context, 'Export failed: $e');
    }
  }

  void _exportMinimalData(BuildContext context) async {
    try {
      await CsvExportService.exportJournalEntries(
        entries: _sampleEntries,
        fileName: 'minimal_journal_data.csv',
        includeAIInsights: false,
        includeWeatherData: false,
        includeLocationData: false,
        includeFinancialData: false,
        includeFeedData: false,
        includeCompetencyData: false,
      );
      
      _showSuccessMessage(context, 'Minimal data exported successfully!');
    } catch (e) {
      _showErrorMessage(context, 'Export failed: $e');
    }
  }

  void _showSuccessMessage(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  void _showErrorMessage(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('CSV Export Examples'),
        backgroundColor: Colors.green,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Sample Data',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${_sampleEntries.length} journal entries loaded',
                      style: TextStyle(color: Colors.grey[600]),
                    ),
                    Text(
                      '${_sampleAnimals.length} animals in database',
                      style: TextStyle(color: Colors.grey[600]),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            
            const Text(
              'Export Options',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            
            // Export all entries
            ElevatedButton.icon(
              onPressed: () => _exportAllEntries(context),
              icon: const Icon(Icons.download),
              label: const Text('Export All Entries'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                padding: const EdgeInsets.all(16),
              ),
            ),
            const SizedBox(height: 8),
            
            // Export by date range
            ElevatedButton.icon(
              onPressed: () => _exportFilteredByDate(context),
              icon: const Icon(Icons.date_range),
              label: const Text('Export Last 7 Days'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                padding: const EdgeInsets.all(16),
              ),
            ),
            const SizedBox(height: 8),
            
            // Export by categories
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => _exportByCategory(context, 'health_check'),
                    child: const Text('Health Checks'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange,
                      padding: const EdgeInsets.all(12),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => _exportByCategory(context, 'training'),
                    child: const Text('Training'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.purple,
                      padding: const EdgeInsets.all(12),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            
            // Export summary report
            ElevatedButton.icon(
              onPressed: () => _exportSummaryReport(context),
              icon: const Icon(Icons.analytics),
              label: const Text('Export Summary Report'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.indigo,
                padding: const EdgeInsets.all(16),
              ),
            ),
            const SizedBox(height: 8),
            
            // Export minimal data
            ElevatedButton.icon(
              onPressed: () => _exportMinimalData(context),
              icon: const Icon(Icons.minimize),
              label: const Text('Export Minimal Data (Basic Fields Only)'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.grey,
                padding: const EdgeInsets.all(16),
              ),
            ),
            const SizedBox(height: 24),
            
            Card(
              color: Colors.blue[50],
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.info, color: Colors.blue),
                        SizedBox(width: 8),
                        Text(
                          'Export Features',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.blue,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _buildFeatureItem('✓ Filter by date range, animal, or category'),
                    _buildFeatureItem('✓ Include/exclude AI insights and analysis'),
                    _buildFeatureItem('✓ Export weather and location data'),
                    _buildFeatureItem('✓ Include feed and financial information'),
                    _buildFeatureItem('✓ Export FFA standards and competencies'),
                    _buildFeatureItem('✓ Generate summary reports with statistics'),
                    _buildFeatureItem('✓ Custom file naming'),
                    _buildFeatureItem('✓ Web browser download support'),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFeatureItem(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Text(
        text,
        style: const TextStyle(fontSize: 14),
      ),
    );
  }
}

/// Run this example in your main.dart:
/// 
/// ```dart
/// import 'package:flutter/material.dart';
/// import 'examples/csv_export_example.dart';
/// 
/// void main() {
///   runApp(MaterialApp(
///     home: CsvExportExample(),
///   ));
/// }
/// ```