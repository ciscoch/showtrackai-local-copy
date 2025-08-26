import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/journal_entry.dart';
import '../models/animal.dart';
import '../services/journal_service.dart';
import '../services/animal_service.dart';
import '../services/spar_runs_service.dart';
import '../theme/app_theme.dart';
import '../widgets/weather_pill.dart';
import '../widgets/processing_status_indicator.dart';
import '../widgets/ai_status_panel.dart';
import 'journal_entry_form_page.dart';

class JournalListPage extends StatefulWidget {
  const JournalListPage({super.key});

  @override
  State<JournalListPage> createState() => _JournalListPageState();
}

class _JournalListPageState extends State<JournalListPage> {
  final _searchController = TextEditingController();
  final _scrollController = ScrollController();

  List<JournalEntry> _entries = [];
  List<JournalEntry> _filteredEntries = [];
  List<Animal> _animals = [];
  Map<String, Map<String, dynamic>> _entryProcessingStatus = {}; // journalId -> SPAR run data
  
  bool _isLoading = true;
  bool _isLoadingMore = false;
  String _searchQuery = '';
  String? _selectedAnimalFilter;
  String? _selectedCategoryFilter;
  DateTimeRange? _selectedDateRange;
  JournalSortOption _sortOption = JournalSortOption.dateDescending;
  bool _showAIAnalysisOnly = false;
  bool _showAIStatusPanel = false;
  
  static const int _pageSize = 20;
  int _currentPage = 0;
  bool _hasMoreData = true;

  @override
  void initState() {
    super.initState();
    _initializeData();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _initializeData() async {
    setState(() => _isLoading = true);
    
    try {
      await Future.wait([
        _loadAnimals(),
        _loadJournalEntries(reset: true),
        _loadProcessingStatus(),
      ]);
    } catch (e) {
      _showErrorSnackbar('Failed to load data: ${e.toString()}');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _loadAnimals() async {
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user != null) {
        final animals = await AnimalService().getAnimals();
        setState(() {
          _animals = animals;
        });
      }
    } catch (e) {
      print('Error loading animals: $e');
    }
  }

  Future<void> _loadJournalEntries({bool reset = false}) async {
    if (reset) {
      _currentPage = 0;
      _hasMoreData = true;
      _entries.clear();
    }

    if (!_hasMoreData || _isLoadingMore) return;

    setState(() => _isLoadingMore = true);

    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) throw Exception('User not authenticated');

      final newEntries = await JournalService.getEntries(
        offset: _currentPage * _pageSize,
        limit: _pageSize,
        animalId: _selectedAnimalFilter,
        category: _selectedCategoryFilter,
        startDate: _selectedDateRange?.start,
        endDate: _selectedDateRange?.end,
      );

      setState(() {
        if (reset) {
          _entries = newEntries;
        } else {
          _entries.addAll(newEntries);
        }
        _currentPage++;
        _hasMoreData = newEntries.length == _pageSize;
        _applyFilters();
      });
    } catch (e) {
      _showErrorSnackbar('Failed to load entries: ${e.toString()}');
    } finally {
      setState(() => _isLoadingMore = false);
    }
  }

  void _applyFilters() {
    var filtered = List<JournalEntry>.from(_entries);

    // Apply search filter
    if (_searchQuery.isNotEmpty) {
      filtered = filtered.where((entry) {
        final query = _searchQuery.toLowerCase();
        return entry.title.toLowerCase().contains(query) ||
               entry.description.toLowerCase().contains(query) ||
               (entry.tags?.any((tag) => tag.toLowerCase().contains(query)) ?? false) ||
               (entry.challenges?.toLowerCase().contains(query) ?? false) ||
               (entry.improvements?.toLowerCase().contains(query) ?? false);
      }).toList();
    }

    // Apply AI analysis filter
    if (_showAIAnalysisOnly) {
      filtered = filtered.where((entry) => entry.aiInsights != null).toList();
    }

    // Apply animal filter
    if (_selectedAnimalFilter != null) {
      filtered = filtered.where((entry) => entry.animalId == _selectedAnimalFilter).toList();
    }

    // Apply category filter
    if (_selectedCategoryFilter != null) {
      filtered = filtered.where((entry) => entry.category == _selectedCategoryFilter).toList();
    }

    // Apply date range filter
    if (_selectedDateRange != null) {
      filtered = filtered.where((entry) {
        return entry.date.isAfter(_selectedDateRange!.start.subtract(const Duration(days: 1))) &&
               entry.date.isBefore(_selectedDateRange!.end.add(const Duration(days: 1)));
      }).toList();
    }

    setState(() {
      _filteredEntries = filtered;
    });
  }

  void _onScroll() {
    if (_scrollController.position.pixels >= 
        _scrollController.position.maxScrollExtent - 200) {
      _loadJournalEntries();
    }
  }

  Future<void> _refreshData() async {
    await Future.wait([
      _loadJournalEntries(reset: true),
      _loadProcessingStatus(),
    ]);
  }

  /// Load SPAR processing status for journal entries
  Future<void> _loadProcessingStatus() async {
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) return;

      // Get recent SPAR runs for this user
      final runs = await SPARRunsService.getUserSPARRuns(
        userId: user.id,
        limit: 50, // Get more runs to match with entries
      );

      // Map SPAR runs to journal entries
      final statusMap = <String, Map<String, dynamic>>{};
      for (final run in runs) {
        final journalId = run['journal_entry_id'] as String?;
        if (journalId != null) {
          // Keep only the most recent run per journal entry
          if (!statusMap.containsKey(journalId) || 
              DateTime.parse(run['created_at']).isAfter(
                DateTime.parse(statusMap[journalId]!['created_at']))) {
            statusMap[journalId] = run;
          }
        }
      }

      setState(() {
        _entryProcessingStatus = statusMap;
      });

      // Check if we should show the AI status panel
      final hasActiveRuns = runs.any((run) {
        final status = run['status'] as String;
        return status == SPARRunsService.STATUS_PENDING || 
               status == SPARRunsService.STATUS_PROCESSING;
      });

      if (hasActiveRuns && !_showAIStatusPanel) {
        setState(() {
          _showAIStatusPanel = true;
        });
      }
    } catch (e) {
      print('Error loading processing status: $e');
    }
  }

  /// Retry AI processing for a specific journal entry
  Future<void> _retryProcessing(String journalId) async {
    final status = _entryProcessingStatus[journalId];
    if (status == null) return;

    try {
      await SPARRunsService.retrySPARRun(status['run_id']);
      await _loadProcessingStatus(); // Refresh status
      
      _showSuccessSnackbar('AI analysis retry initiated');
    } catch (e) {
      _showErrorSnackbar('Retry failed: ${e.toString()}');
    }
  }

  void _navigateToCreateEntry() async {
    final result = await Navigator.of(context).push<JournalEntry>(
      MaterialPageRoute(
        builder: (context) => const JournalEntryFormPage(),
      ),
    );

    if (result != null) {
      _refreshData();
    }
  }

  void _navigateToEditEntry(JournalEntry entry) async {
    final result = await Navigator.of(context).push<JournalEntry>(
      MaterialPageRoute(
        builder: (context) => JournalEntryFormPage(existingEntry: entry),
      ),
    );

    if (result != null) {
      _refreshData();
    }
  }

  void _navigateToEntryDetail(JournalEntry entry) {
    // TODO: Navigate to entry detail view
    showDialog(
      context: context,
      builder: (context) => _buildEntryDetailDialog(entry),
    );
  }

  Future<void> _deleteEntry(JournalEntry entry) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Entry'),
        content: Text('Are you sure you want to delete "${entry.title}"?\n\nThis action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await JournalService.deleteEntry(entry.id!);
        _refreshData();
        _showSuccessSnackbar('Entry deleted successfully');
      } catch (e) {
        _showErrorSnackbar('Failed to delete entry: ${e.toString()}');
      }
    }
  }

  void _showErrorSnackbar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }

  void _showSuccessSnackbar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppTheme.secondaryGreen,
      ),
    );
  }

  String _getSortField() {
    switch (_sortOption) {
      case JournalSortOption.dateAscending:
      case JournalSortOption.dateDescending:
        return 'entry_date';
      case JournalSortOption.titleAscending:
      case JournalSortOption.titleDescending:
        return 'title';
      case JournalSortOption.qualityScoreDescending:
        return 'quality_score';
      case JournalSortOption.durationDescending:
        return 'duration_minutes';
    }
  }

  bool _getSortAscending() {
    switch (_sortOption) {
      case JournalSortOption.dateAscending:
      case JournalSortOption.titleAscending:
        return true;
      case JournalSortOption.dateDescending:
      case JournalSortOption.titleDescending:
      case JournalSortOption.qualityScoreDescending:
      case JournalSortOption.durationDescending:
        return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Journal Entries'),
        elevation: 0,
        actions: [
          // Global AI Status Indicator
          GlobalAIStatusIndicator(
            onTap: () {
              setState(() {
                _showAIStatusPanel = !_showAIStatusPanel;
              });
            },
            showBadge: true,
          ),
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: _showSearchDialog,
          ),
          IconButton(
            icon: const Icon(Icons.filter_list),
            onPressed: _showFilterDialog,
          ),
          PopupMenuButton<JournalSortOption>(
            icon: const Icon(Icons.sort),
            onSelected: (option) {
              setState(() {
                _sortOption = option;
              });
              _refreshData();
            },
            itemBuilder: (context) => JournalSortOption.values.map((option) {
              return PopupMenuItem(
                value: option,
                child: Row(
                  children: [
                    if (_sortOption == option)
                      Icon(Icons.check, color: AppTheme.primaryGreen),
                    if (_sortOption == option) const SizedBox(width: 8),
                    Text(_getSortOptionLabel(option)),
                  ],
                ),
              );
            }).toList(),
          ),
        ],
      ),
      body: Stack(
        children: [
          _buildBody(),
          // AI Status Panel
          AIStatusPanel(
            isVisible: _showAIStatusPanel,
            onDismiss: () {
              setState(() {
                _showAIStatusPanel = false;
              });
            },
            position: AIStatusPanelPosition.bottomRight,
            maxEntries: 3,
            autoHideCompleted: true,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _navigateToCreateEntry,
        backgroundColor: AppTheme.primaryGreen,
        icon: const Icon(Icons.add),
        label: const Text('New Entry'),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Loading journal entries...'),
          ],
        ),
      );
    }

    return Column(
      children: [
        _buildFilterChips(),
        Expanded(
          child: _filteredEntries.isEmpty 
              ? _buildEmptyState()
              : _buildEntriesList(),
        ),
      ],
    );
  }

  Widget _buildFilterChips() {
    final hasFilters = _selectedAnimalFilter != null ||
        _selectedCategoryFilter != null ||
        _selectedDateRange != null ||
        _showAIAnalysisOnly ||
        _searchQuery.isNotEmpty;

    if (!hasFilters) return const SizedBox.shrink();

    return Container(
      height: 60,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            if (_searchQuery.isNotEmpty) ...[
              _buildFilterChip(
                label: 'Search: "$_searchQuery"',
                onDeleted: () {
                  setState(() {
                    _searchQuery = '';
                    _searchController.clear();
                  });
                  _applyFilters();
                },
              ),
              const SizedBox(width: 8),
            ],
            if (_selectedAnimalFilter != null) ...[
              _buildFilterChip(
                label: 'Animal: ${_getAnimalName(_selectedAnimalFilter!)}',
                onDeleted: () {
                  setState(() {
                    _selectedAnimalFilter = null;
                  });
                  _applyFilters();
                },
              ),
              const SizedBox(width: 8),
            ],
            if (_selectedCategoryFilter != null) ...[
              _buildFilterChip(
                label: 'Category: ${JournalCategories.getDisplayName(_selectedCategoryFilter!)}',
                onDeleted: () {
                  setState(() {
                    _selectedCategoryFilter = null;
                  });
                  _applyFilters();
                },
              ),
              const SizedBox(width: 8),
            ],
            if (_selectedDateRange != null) ...[
              _buildFilterChip(
                label: 'Date: ${_formatDateRange(_selectedDateRange!)}',
                onDeleted: () {
                  setState(() {
                    _selectedDateRange = null;
                  });
                  _applyFilters();
                },
              ),
              const SizedBox(width: 8),
            ],
            if (_showAIAnalysisOnly) ...[
              _buildFilterChip(
                label: 'AI Analyzed Only',
                onDeleted: () {
                  setState(() {
                    _showAIAnalysisOnly = false;
                  });
                  _applyFilters();
                },
              ),
              const SizedBox(width: 8),
            ],
            TextButton.icon(
              onPressed: _clearAllFilters,
              icon: const Icon(Icons.clear_all),
              label: const Text('Clear All'),
              style: TextButton.styleFrom(
                foregroundColor: Colors.grey[600],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChip({
    required String label,
    required VoidCallback onDeleted,
  }) {
    return Chip(
      label: Text(
        label,
        style: const TextStyle(fontSize: 12),
      ),
      deleteIcon: const Icon(Icons.close, size: 18),
      onDeleted: onDeleted,
      backgroundColor: AppTheme.primaryGreen.withOpacity(0.1),
      side: BorderSide(color: AppTheme.primaryGreen.withOpacity(0.3)),
    );
  }

  Widget _buildEmptyState() {
    final hasFilters = _selectedAnimalFilter != null ||
        _selectedCategoryFilter != null ||
        _selectedDateRange != null ||
        _showAIAnalysisOnly ||
        _searchQuery.isNotEmpty;

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            hasFilters ? Icons.search_off : Icons.book_outlined,
            size: 80,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            hasFilters 
                ? 'No entries match your filters'
                : 'No journal entries yet',
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            hasFilters
                ? 'Try adjusting your filters to see more entries'
                : 'Start documenting your agricultural activities',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 24),
          if (hasFilters)
            TextButton.icon(
              onPressed: _clearAllFilters,
              icon: const Icon(Icons.clear_all),
              label: const Text('Clear Filters'),
            )
          else
            ElevatedButton.icon(
              onPressed: _navigateToCreateEntry,
              icon: const Icon(Icons.add),
              label: const Text('Create First Entry'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryGreen,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildEntriesList() {
    return RefreshIndicator(
      onRefresh: _refreshData,
      child: ListView.separated(
        controller: _scrollController,
        padding: const EdgeInsets.all(16),
        itemCount: _filteredEntries.length + (_isLoadingMore ? 1 : 0),
        separatorBuilder: (context, index) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          if (index >= _filteredEntries.length) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: CircularProgressIndicator(),
              ),
            );
          }
          
          final entry = _filteredEntries[index];
          return _buildEntryCard(entry);
        },
      ),
    );
  }

  Widget _buildEntryCard(JournalEntry entry) {
    final animal = _animals.firstWhere(
      (a) => a.id == entry.animalId,
      orElse: () => Animal(userId: '', name: 'Unknown', species: AnimalSpecies.other),
    );

    return Card(
      elevation: 2,
      child: InkWell(
        onTap: () => _navigateToEntryDetail(entry),
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header Row
              Row(
                children: [
                  Expanded(
                    child: Text(
                      entry.title,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  PopupMenuButton<String>(
                    onSelected: (action) {
                      switch (action) {
                        case 'edit':
                          _navigateToEditEntry(entry);
                          break;
                        case 'delete':
                          _deleteEntry(entry);
                          break;
                      }
                    },
                    itemBuilder: (context) => [
                      const PopupMenuItem(
                        value: 'edit',
                        child: ListTile(
                          leading: Icon(Icons.edit),
                          title: Text('Edit'),
                          contentPadding: EdgeInsets.zero,
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'delete',
                        child: ListTile(
                          leading: Icon(Icons.delete, color: Colors.red),
                          title: Text('Delete', style: TextStyle(color: Colors.red)),
                          contentPadding: EdgeInsets.zero,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 8),

              // Meta Information Row
              Row(
                children: [
                  Icon(
                    Icons.pets,
                    size: 16,
                    color: Colors.grey[600],
                  ),
                  const SizedBox(width: 4),
                  Text(
                    animal.name,
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Icon(
                    Icons.calendar_today,
                    size: 16,
                    color: Colors.grey[600],
                  ),
                  const SizedBox(width: 4),
                  Text(
                    _formatDate(entry.date),
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                  const SizedBox(width: 16),
                  Icon(
                    Icons.timer,
                    size: 16,
                    color: Colors.grey[600],
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '${entry.duration} min',
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Description Preview
              Text(
                entry.description,
                style: const TextStyle(fontSize: 14),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 12),

              // Category and AI Indicators
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: _getCategoryColor(entry.category).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: _getCategoryColor(entry.category).withOpacity(0.3),
                      ),
                    ),
                    child: Text(
                      JournalCategories.getDisplayName(entry.category),
                      style: TextStyle(
                        color: _getCategoryColor(entry.category),
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  const Spacer(),
                  
                  // AI Processing Status Badge
                  _buildAIStatusBadge(entry),
                  
                  if (entry.aiInsights != null) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.blue.shade200),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.smart_toy,
                            size: 14,
                            color: Colors.blue.shade700,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'AI Score: ${entry.qualityScore ?? 0}/10',
                            style: TextStyle(
                              color: Colors.blue.shade700,
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  if (entry.locationData != null) ...[
                    const SizedBox(width: 8),
                    Icon(
                      Icons.location_on,
                      size: 16,
                      color: Colors.green[600],
                    ),
                  ],
                ],
              ),
              
              // Weather Pill Display
              if (entry.weatherData != null) ...[
                const SizedBox(height: 8),
                WeatherPill(
                  weatherData: entry.weatherData!,
                  compact: true,
                ),
              ],

              // Tags
              if (entry.tags != null && entry.tags!.isNotEmpty) ...[
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: entry.tags!.take(3).map((tag) {
                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.grey[100],
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        tag,
                        style: const TextStyle(
                          fontSize: 11,
                          color: Colors.grey,
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEntryDetailDialog(JournalEntry entry) {
    return Dialog(
      insetPadding: const EdgeInsets.all(16),
      child: Container(
        constraints: const BoxConstraints(maxHeight: 600),
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.primaryGreen.withOpacity(0.1),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(8),
                  topRight: Radius.circular(8),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      entry.title,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
            ),

            // Content
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Meta information
                    Row(
                      children: [
                        Icon(Icons.calendar_today, size: 16, color: Colors.grey[600]),
                        const SizedBox(width: 4),
                        Text(
                          _formatDate(entry.date),
                          style: TextStyle(color: Colors.grey[600]),
                        ),
                        const SizedBox(width: 16),
                        Icon(Icons.timer, size: 16, color: Colors.grey[600]),
                        const SizedBox(width: 4),
                        Text(
                          '${entry.duration} minutes',
                          style: TextStyle(color: Colors.grey[600]),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Description
                    const Text(
                      'Description',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Text(entry.description),
                    const SizedBox(height: 16),

                    // AI Insights
                    if (entry.aiInsights != null) ...[
                      const Text(
                        'AI Analysis',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.blue.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.blue.shade200),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Quality Score: ${entry.qualityScore}/10',
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 8),
                            Text('Competency Level: ${entry.competencyLevel ?? 'Not assessed'}'),
                            if (entry.aiInsights!.feedback.strengths.isNotEmpty) ...[
                              const SizedBox(height: 8),
                              const Text('Strengths:', style: TextStyle(fontWeight: FontWeight.w500)),
                              ...entry.aiInsights!.feedback.strengths.map(
                                (strength) => Text('• $strength', style: const TextStyle(fontSize: 14)),
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],

                    // Weather info
                    if (entry.weatherData != null) ...[
                      const Text(
                        'Weather Conditions',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      WeatherPillExpanded(weatherData: entry.weatherData!),
                      const SizedBox(height: 16),
                    ],

                    // FFA Standards
                    if (entry.ffaStandards != null && entry.ffaStandards!.isNotEmpty) ...[
                      const Text(
                        'FFA Standards',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        children: entry.ffaStandards!.map((standard) {
                          return Chip(
                            label: Text(standard),
                            backgroundColor: AppTheme.primaryGreen.withOpacity(0.1),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 16),
                    ],

                    // AET Skills
                    if (entry.aetSkills.isNotEmpty) ...[
                      const Text(
                        'AET Skills',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        children: entry.aetSkills.map((skill) {
                          return Chip(
                            label: Text(skill),
                            backgroundColor: AppTheme.secondaryGreen.withOpacity(0.1),
                          );
                        }).toList(),
                      ),
                    ],
                  ],
                ),
              ),
            ),

            // Action buttons
            Container(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  TextButton.icon(
                    onPressed: () {
                      Navigator.of(context).pop();
                      _navigateToEditEntry(entry);
                    },
                    icon: const Icon(Icons.edit),
                    label: const Text('Edit'),
                  ),
                  TextButton.icon(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close),
                    label: const Text('Close'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showSearchDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Search Entries'),
        content: TextField(
          controller: _searchController,
          decoration: const InputDecoration(
            hintText: 'Search titles, descriptions, tags...',
            prefixIcon: Icon(Icons.search),
          ),
          autofocus: true,
          onChanged: (value) {
            setState(() {
              _searchQuery = value;
            });
            _applyFilters();
          },
        ),
        actions: [
          TextButton(
            onPressed: () {
              setState(() {
                _searchQuery = '';
                _searchController.clear();
              });
              _applyFilters();
              Navigator.of(context).pop();
            },
            child: const Text('Clear'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Done'),
          ),
        ],
      ),
    );
  }

  void _showFilterDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Filter Entries'),
        content: SizedBox(
          width: double.maxFinite,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Animal filter
              const Text('Animal:', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              DropdownButton<String?>(
                value: _selectedAnimalFilter,
                isExpanded: true,
                items: [
                  const DropdownMenuItem<String?>(
                    value: null,
                    child: Text('All Animals'),
                  ),
                  ..._animals.map((animal) => DropdownMenuItem<String?>(
                    value: animal.id,
                    child: Text(animal.name),
                  )),
                ],
                onChanged: (value) {
                  setState(() {
                    _selectedAnimalFilter = value;
                  });
                },
              ),
              const SizedBox(height: 16),

              // Category filter
              const Text('Category:', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              DropdownButton<String?>(
                value: _selectedCategoryFilter,
                isExpanded: true,
                items: [
                  const DropdownMenuItem<String?>(
                    value: null,
                    child: Text('All Categories'),
                  ),
                  ...JournalCategories.categories.map((category) => DropdownMenuItem<String?>(
                    value: category,
                    child: Text(JournalCategories.getDisplayName(category)),
                  )),
                ],
                onChanged: (value) {
                  setState(() {
                    _selectedCategoryFilter = value;
                  });
                },
              ),
              const SizedBox(height: 16),

              // AI Analysis filter
              SwitchListTile(
                title: const Text('AI Analyzed Only'),
                value: _showAIAnalysisOnly,
                onChanged: (value) {
                  setState(() {
                    _showAIAnalysisOnly = value;
                  });
                },
                contentPadding: EdgeInsets.zero,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: _clearAllFilters,
            child: const Text('Clear All'),
          ),
          TextButton(
            onPressed: () {
              _applyFilters();
              Navigator.of(context).pop();
            },
            child: const Text('Apply'),
          ),
        ],
      ),
    );
  }

  void _clearAllFilters() {
    setState(() {
      _selectedAnimalFilter = null;
      _selectedCategoryFilter = null;
      _selectedDateRange = null;
      _showAIAnalysisOnly = false;
      _searchQuery = '';
      _searchController.clear();
    });
    _applyFilters();
  }

  String _getAnimalName(String animalId) {
    return _animals.firstWhere(
      (animal) => animal.id == animalId,
      orElse: () => Animal(userId: '', name: 'Unknown', species: AnimalSpecies.other),
    ).name;
  }

  Color _getCategoryColor(String category) {
    const colors = {
      'daily_care': Colors.green,
      'health_check': Colors.red,
      'feeding': Colors.orange,
      'training': Colors.blue,
      'show_prep': Colors.purple,
      'veterinary': Colors.pink,
      'breeding': Colors.teal,
      'record_keeping': Colors.brown,
      'financial': Colors.indigo,
    };
    return colors[category] ?? Colors.grey;
  }

  String _formatDate(DateTime date) {
    return '${date.month}/${date.day}/${date.year}';
  }

  String _formatDateRange(DateTimeRange range) {
    return '${_formatDate(range.start)} - ${_formatDate(range.end)}';
  }

  String _getSortOptionLabel(JournalSortOption option) {
    switch (option) {
      case JournalSortOption.dateDescending:
        return 'Date (Newest First)';
      case JournalSortOption.dateAscending:
        return 'Date (Oldest First)';
      case JournalSortOption.titleAscending:
        return 'Title (A-Z)';
      case JournalSortOption.titleDescending:
        return 'Title (Z-A)';
      case JournalSortOption.qualityScoreDescending:
        return 'Quality Score (High-Low)';
      case JournalSortOption.durationDescending:
        return 'Duration (Long-Short)';
    }
  }

  /// Build AI processing status badge for a journal entry
  Widget _buildAIStatusBadge(JournalEntry entry) {
    if (entry.id == null) return const SizedBox.shrink();
    
    final status = _entryProcessingStatus[entry.id!];
    if (status == null) {
      // No processing status found - show idle if no AI insights
      if (entry.aiInsights == null) {
        return ProcessingStatusBadge(
          status: ProcessingStatus.idle,
          onTap: () => _showProcessingDetails(entry),
        );
      }
      return const SizedBox.shrink();
    }

    final processingStatus = (status['status'] as String).toProcessingStatus();
    
    return ProcessingStatusBadge(
      status: processingStatus,
      onTap: () => _showProcessingDetails(entry),
      onRetry: processingStatus == ProcessingStatus.failed 
          ? () => _retryProcessing(entry.id!) 
          : null,
    );
  }

  /// Show detailed processing information for a journal entry
  void _showProcessingDetails(JournalEntry entry) {
    final status = entry.id != null ? _entryProcessingStatus[entry.id!] : null;
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.psychology, color: Colors.blue[600]),
            const SizedBox(width: 8),
            const Text('AI Processing Status'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Entry: "${entry.title}"',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            
            if (status != null) ...[
              ProcessingStatusIndicator(
                status: (status['status'] as String).toProcessingStatus(),
                size: ProcessingStatusSize.large,
                showStatusText: true,
                showRetryButton: true,
                onRetry: (status['status'] as String) == SPARRunsService.STATUS_FAILED
                    ? () {
                        Navigator.of(context).pop();
                        _retryProcessing(entry.id!);
                      }
                    : null,
              ),
              const SizedBox(height: 16),
              
              Text(
                'Processing Details:',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[700],
                ),
              ),
              const SizedBox(height: 8),
              
              _buildStatusDetail('Run ID', status['run_id']),
              _buildStatusDetail('Created', _formatDateTime(status['created_at'])),
              if (status['processing_started_at'] != null)
                _buildStatusDetail('Started', _formatDateTime(status['processing_started_at'])),
              if (status['processing_completed_at'] != null)
                _buildStatusDetail('Completed', _formatDateTime(status['processing_completed_at'])),
              if (status['processing_duration_ms'] != null)
                _buildStatusDetail('Duration', '${status['processing_duration_ms']}ms'),
              if (status['error'] != null)
                _buildStatusDetail('Error', status['error'], isError: true),
            ] else ...[
              Row(
                children: [
                  Icon(
                    entry.aiInsights != null ? Icons.check_circle : Icons.pending,
                    color: entry.aiInsights != null ? Colors.green[600] : Colors.grey[600],
                  ),
                  const SizedBox(width: 8),
                  Text(
                    entry.aiInsights != null 
                        ? 'AI analysis completed'
                        : 'No AI analysis found',
                  ),
                ],
              ),
              const SizedBox(height: 12),
              
              if (entry.aiInsights != null) ...[
                Text(
                  'AI Insights Available:',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.grey[700],
                  ),
                ),
                const SizedBox(height: 8),
                _buildStatusDetail('Quality Score', '${entry.qualityScore}/10'),
                _buildStatusDetail('Competency Level', entry.competencyLevel ?? 'Not assessed'),
                if (entry.ffaStandards?.isNotEmpty == true)
                  _buildStatusDetail('FFA Standards', '${entry.ffaStandards!.length} matched'),
              ],
            ],
          ],
        ),
        actions: [
          if (status != null && (status['status'] as String) == SPARRunsService.STATUS_FAILED)
            TextButton.icon(
              onPressed: () {
                Navigator.of(context).pop();
                _retryProcessing(entry.id!);
              },
              icon: const Icon(Icons.refresh),
              label: const Text('Retry Processing'),
              style: TextButton.styleFrom(foregroundColor: Colors.orange[700]),
            ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusDetail(String label, String value, {bool isError = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              '$label:',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 12,
                color: isError ? Colors.red[600] : Colors.grey[800],
                fontFamily: isError ? 'monospace' : null,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatDateTime(String isoString) {
    try {
      final dateTime = DateTime.parse(isoString);
      final now = DateTime.now();
      final difference = now.difference(dateTime);
      
      if (difference.inMinutes < 1) {
        return '${difference.inSeconds}s ago';
      } else if (difference.inHours < 1) {
        return '${difference.inMinutes}m ago';
      } else if (difference.inDays < 1) {
        return '${difference.inHours}h ago';
      } else {
        return '${dateTime.month}/${dateTime.day} ${dateTime.hour}:${dateTime.minute.toString().padLeft(2, '0')}';
      }
    } catch (e) {
      return isoString;
    }
  }
}

enum JournalSortOption {
  dateDescending,
  dateAscending,
  titleAscending,
  titleDescending,
  qualityScoreDescending,
  durationDescending,
}