import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/journal_entry.dart';
import '../models/animal.dart';
import '../services/csv_export_service.dart';

/// Dialog for configuring and executing journal export
class ExportDialog extends StatefulWidget {
  final List<JournalEntry> entries;
  final List<Animal> animals;
  final String? preselectedAnimalId;
  final String? preselectedCategory;
  final DateTimeRange? preselectedDateRange;

  const ExportDialog({
    super.key,
    required this.entries,
    required this.animals,
    this.preselectedAnimalId,
    this.preselectedCategory,
    this.preselectedDateRange,
  });

  @override
  State<ExportDialog> createState() => _ExportDialogState();
}

class _ExportDialogState extends State<ExportDialog> {
  final _fileNameController = TextEditingController();
  
  DateTimeRange? _selectedDateRange;
  String? _selectedAnimalId;
  String? _selectedCategory;
  
  bool _includeAIInsights = true;
  bool _includeWeatherData = true;
  bool _includeLocationData = true;
  bool _includeFinancialData = true;
  bool _includeFeedData = true;
  bool _includeCompetencyData = true;
  
  bool _exportSummaryReport = false;
  bool _isExporting = false;
  String _exportProgress = '';
  
  int _filteredEntriesCount = 0;

  @override
  void initState() {
    super.initState();
    _selectedAnimalId = widget.preselectedAnimalId;
    _selectedCategory = widget.preselectedCategory;
    _selectedDateRange = widget.preselectedDateRange;
    _updateFilteredCount();
    
    // Generate default filename
    final timestamp = DateFormat('yyyyMMdd').format(DateTime.now());
    _fileNameController.text = 'journal_export_$timestamp';
  }

  @override
  void dispose() {
    _fileNameController.dispose();
    super.dispose();
  }

  void _updateFilteredCount() {
    final filtered = CsvExportService.filterEntries(
      widget.entries,
      dateRange: _selectedDateRange,
      animalId: _selectedAnimalId,
      category: _selectedCategory,
    );
    
    setState(() {
      _filteredEntriesCount = filtered.length;
    });
  }

  Future<void> _selectDateRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDateRange: _selectedDateRange ?? DateTimeRange(
        start: DateTime.now().subtract(const Duration(days: 30)),
        end: DateTime.now(),
      ),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: Colors.green,
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: Colors.black87,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _selectedDateRange = picked;
      });
      _updateFilteredCount();
    }
  }

  Future<void> _export() async {
    if (_filteredEntriesCount == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No entries match the selected filters'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => _isExporting = true);

    try {
      final fileName = _fileNameController.text.trim();
      final exportFileName = fileName.isEmpty 
          ? null 
          : (fileName.endsWith('.csv') ? fileName : '$fileName.csv');

      if (_exportSummaryReport) {
        await CsvExportService.exportSummaryReport(
          entries: widget.entries,
          fileName: exportFileName,
          dateRange: _selectedDateRange,
        );
      } else {
        await CsvExportService.exportJournalEntries(
          entries: widget.entries,
          fileName: exportFileName,
          dateRange: _selectedDateRange,
          animalFilter: _selectedAnimalId,
          categoryFilter: _selectedCategory,
          includeAIInsights: _includeAIInsights,
          includeWeatherData: _includeWeatherData,
          includeLocationData: _includeLocationData,
          includeFinancialData: _includeFinancialData,
          includeFeedData: _includeFeedData,
          includeCompetencyData: _includeCompetencyData,
          onProgress: (progress) {
            if (mounted) {
              setState(() {
                _exportProgress = progress;
              });
            }
          },
        );
      }

      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_exportSummaryReport 
                ? 'Summary report exported successfully!' 
                : 'Journal entries exported successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Export failed: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isExporting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('MMM dd, yyyy');
    
    return Dialog(
      child: Container(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width > 600 ? 600 : MediaQuery.of(context).size.width * 0.95,
          maxHeight: MediaQuery.of(context).size.height * 0.9,
        ),
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.download, color: Colors.green[700], size: 28),
                    const SizedBox(width: 12),
                    const Text(
                      'Export Journal Entries',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                      semanticsLabel: 'Export journal entries dialog',
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Export $_filteredEntriesCount of ${widget.entries.length} entries',
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 14,
                  ),
                ),
                const Divider(height: 32),
                
                // Export Type
                Card(
                  elevation: 0,
                  color: Colors.grey[50],
                  child: Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Export Type',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 8),
                        RadioListTile<bool>(
                          title: const Text('Full Journal Entries'),
                          subtitle: const Text('Export complete journal data with all fields'),
                          value: false,
                          groupValue: _exportSummaryReport,
                          onChanged: (value) {
                            setState(() => _exportSummaryReport = value!);
                          },
                          activeColor: Colors.green,
                        ),
                        RadioListTile<bool>(
                          title: const Text('Summary Report'),
                          subtitle: const Text('Export statistical summary and analytics'),
                          value: true,
                          groupValue: _exportSummaryReport,
                          onChanged: (value) {
                            setState(() => _exportSummaryReport = value!);
                          },
                          activeColor: Colors.green,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                
                // Filters
                Card(
                  elevation: 0,
                  color: Colors.grey[50],
                  child: Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Filters',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 12),
                        
                        // Date Range
                        ListTile(
                          leading: const Icon(Icons.date_range),
                          title: const Text('Date Range'),
                          subtitle: _selectedDateRange != null
                              ? Text(
                                  '${dateFormat.format(_selectedDateRange!.start)} - '
                                  '${dateFormat.format(_selectedDateRange!.end)}',
                                )
                              : const Text('All dates'),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (_selectedDateRange != null)
                                IconButton(
                                  icon: const Icon(Icons.clear),
                                  onPressed: () {
                                    setState(() => _selectedDateRange = null);
                                    _updateFilteredCount();
                                  },
                                ),
                              TextButton(
                                onPressed: _selectDateRange,
                                child: const Text('Select'),
                              ),
                            ],
                          ),
                        ),
                        
                        // Animal Filter
                        if (widget.animals.isNotEmpty && !_exportSummaryReport) ...[
                          const Divider(),
                          ListTile(
                            leading: const Icon(Icons.pets),
                            title: const Text('Animal'),
                            subtitle: DropdownButton<String?>(
                              value: _selectedAnimalId,
                              isExpanded: true,
                              hint: const Text('All animals'),
                              items: [
                                const DropdownMenuItem(
                                  value: null,
                                  child: Text('All animals'),
                                ),
                                ...widget.animals.map((animal) => DropdownMenuItem(
                                  value: animal.id,
                                  child: Text('${animal.name} (${animal.species})'),
                                )),
                              ],
                              onChanged: (value) {
                                setState(() => _selectedAnimalId = value);
                                _updateFilteredCount();
                              },
                            ),
                          ),
                        ],
                        
                        // Category Filter
                        if (!_exportSummaryReport) ...[
                          const Divider(),
                          ListTile(
                            leading: const Icon(Icons.category),
                            title: const Text('Category'),
                            subtitle: DropdownButton<String?>(
                              value: _selectedCategory,
                              isExpanded: true,
                              hint: const Text('All categories'),
                              items: [
                                const DropdownMenuItem(
                                  value: null,
                                  child: Text('All categories'),
                                ),
                                ...JournalCategories.categories.map((category) => DropdownMenuItem(
                                  value: category,
                                  child: Text(JournalCategories.getDisplayName(category)),
                                )),
                              ],
                              onChanged: (value) {
                                setState(() => _selectedCategory = value);
                                _updateFilteredCount();
                              },
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                
                // Data Fields (only for full export)
                if (!_exportSummaryReport) ...[
                  Card(
                    elevation: 0,
                    color: Colors.grey[50],
                    child: Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Data Fields to Include',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 8),
                          CheckboxListTile(
                            title: const Text('AI Insights & Analysis'),
                            subtitle: const Text('Quality scores, feedback, recommendations'),
                            value: _includeAIInsights,
                            onChanged: (value) {
                              setState(() => _includeAIInsights = value!);
                            },
                            activeColor: Colors.green,
                          ),
                          CheckboxListTile(
                            title: const Text('Weather Data'),
                            subtitle: const Text('Temperature, conditions, humidity'),
                            value: _includeWeatherData,
                            onChanged: (value) {
                              setState(() => _includeWeatherData = value!);
                            },
                            activeColor: Colors.green,
                          ),
                          CheckboxListTile(
                            title: const Text('Location Data'),
                            subtitle: const Text('GPS coordinates, address, city/state'),
                            value: _includeLocationData,
                            onChanged: (value) {
                              setState(() => _includeLocationData = value!);
                            },
                            activeColor: Colors.green,
                          ),
                          CheckboxListTile(
                            title: const Text('Feed & Nutrition Data'),
                            subtitle: const Text('Feed details, weights, conversion ratios'),
                            value: _includeFeedData,
                            onChanged: (value) {
                              setState(() => _includeFeedData = value!);
                            },
                            activeColor: Colors.green,
                          ),
                          CheckboxListTile(
                            title: const Text('Financial Data'),
                            subtitle: const Text('Financial values and costs'),
                            value: _includeFinancialData,
                            onChanged: (value) {
                              setState(() => _includeFinancialData = value!);
                            },
                            activeColor: Colors.green,
                          ),
                          CheckboxListTile(
                            title: const Text('Competency Tracking'),
                            subtitle: const Text('Skills, standards, progress percentages'),
                            value: _includeCompetencyData,
                            onChanged: (value) {
                              setState(() => _includeCompetencyData = value!);
                            },
                            activeColor: Colors.green,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
                
                // File Name
                TextField(
                  controller: _fileNameController,
                  decoration: InputDecoration(
                    labelText: 'File Name (optional)',
                    hintText: 'journal_export_${DateFormat('yyyyMMdd').format(DateTime.now())}',
                    border: const OutlineInputBorder(),
                    suffixText: '.csv',
                    prefixIcon: const Icon(Icons.insert_drive_file),
                  ),
                ),
                const SizedBox(height: 24),
                
                // Action Buttons
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: _isExporting ? null : () => Navigator.of(context).pop(),
                      child: const Text('Cancel'),
                    ),
                    const SizedBox(width: 16),
                    ElevatedButton.icon(
                      onPressed: _isExporting || _filteredEntriesCount == 0 ? null : _export,
                      icon: _isExporting
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                            )
                          : const Icon(Icons.download),
                      label: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(_isExporting 
                              ? (_exportProgress.isNotEmpty ? _exportProgress : 'Exporting...')
                              : 'Export $_filteredEntriesCount entries'),
                          if (_isExporting && _exportProgress.isNotEmpty)
                            const SizedBox(height: 2),
                        ],
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}