import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/rendering.dart';
import 'package:intl/intl.dart';
import '../models/timeline_item.dart';
import '../models/journal_entry.dart';
import '../models/expense.dart';
import '../models/animal.dart';
import '../services/journal_service.dart';
import '../services/expense_service.dart';
import '../services/animal_service.dart';
import '../widgets/timeline_item_card.dart';
import '../widgets/timeline_filters.dart';
import '../widgets/timeline_stats_card.dart';
import '../theme/app_theme.dart';
import '../theme/mobile_responsive_theme.dart';

/// APP-125: Timeline view combining journal entries and expenses
class TimelineViewScreen extends StatefulWidget {
  const TimelineViewScreen({super.key});

  @override
  State<TimelineViewScreen> createState() => _TimelineViewScreenState();
}

class _TimelineViewScreenState extends State<TimelineViewScreen>
    with TickerProviderStateMixin, AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;
  // Controllers
  final ScrollController _scrollController = ScrollController();
  late TabController _tabController;
  late AnimationController _refreshAnimationController;
  late AnimationController _fabAnimationController;
  late Animation<double> _fabScaleAnimation;
  
  // Data
  List<TimelineItem> _allItems = [];
  List<TimelineItem> _filteredItems = [];
  Map<DateTime, List<TimelineItem>> _groupedItems = {};
  List<Animal> _animals = [];
  Map<String, String> _animalNames = {};
  
  // Loading states
  bool _isLoading = true;
  bool _isLoadingMore = false;
  bool _hasMoreData = true;
  bool _isRefreshing = false;
  bool _showFab = true;
  
  // Filters
  Set<TimelineItemType> _selectedTypes = {
    TimelineItemType.journal,
    TimelineItemType.expense,
  };
  String? _selectedAnimalId;
  DateTimeRange? _selectedDateRange;
  String? _selectedCategory;
  String _searchQuery = '';
  
  // Pagination
  static const int _pageSize = 20;
  int _currentPage = 0;
  
  // Statistics
  Map<String, dynamic> _statistics = {};

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _refreshAnimationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _fabAnimationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _fabScaleAnimation = Tween<double>(
      begin: 1.0,
      end: 0.0,
    ).animate(CurvedAnimation(
      parent: _fabAnimationController,
      curve: Curves.easeInOut,
    ));
    
    _scrollController.addListener(_onScroll);
    _initializeData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _scrollController.dispose();
    _refreshAnimationController.dispose();
    _fabAnimationController.dispose();
    super.dispose();
  }

  void _onScroll() {
    // Infinite scroll loading
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      _loadMoreData();
    }
    
    // FAB visibility based on scroll direction
    if (_scrollController.position.userScrollDirection == ScrollDirection.reverse) {
      if (_showFab) {
        setState(() => _showFab = false);
        _fabAnimationController.forward();
      }
    } else if (_scrollController.position.userScrollDirection == ScrollDirection.forward) {
      if (!_showFab) {
        setState(() => _showFab = true);
        _fabAnimationController.reverse();
      }
    }
  }

  Future<void> _initializeData() async {
    if (!_isRefreshing) {
      setState(() => _isLoading = true);
    }
    
    try {
      // Add haptic feedback for refresh
      if (_isRefreshing) {
        HapticFeedback.lightImpact();
        _refreshAnimationController.forward();
      }
      
      // Load animals first for name mapping
      await _loadAnimals();
      
      // Load initial data
      await _loadTimelineData(reset: true);
      
      // Load statistics
      await _loadStatistics();
      
      // Success haptic feedback
      if (_isRefreshing) {
        HapticFeedback.selectionClick();
        await Future.delayed(const Duration(milliseconds: 300));
        _refreshAnimationController.reverse();
      }
      
    } catch (e) {
      // Error haptic feedback
      HapticFeedback.heavyImpact();
      _showErrorSnackbar('Failed to load timeline: ${e.toString()}');
    } finally {
      setState(() {
        _isLoading = false;
        _isRefreshing = false;
      });
    }
  }

  Future<void> _loadAnimals() async {
    try {
      final animals = await AnimalService().getAnimals();
      setState(() {
        _animals = animals;
        _animalNames = {};
        for (var animal in animals) {
          if (animal.id != null) {
            _animalNames[animal.id!] = animal.name;
          }
        }
      });
    } catch (e) {
      print('Error loading animals: $e');
    }
  }

  Future<void> _loadTimelineData({bool reset = false}) async {
    if (reset) {
      _currentPage = 0;
      _hasMoreData = true;
      _allItems.clear();
    }

    if (!_hasMoreData || _isLoadingMore) return;

    setState(() => _isLoadingMore = true);

    try {
      // Calculate date range for query
      final endDate = _selectedDateRange?.end ?? DateTime.now();
      final startDate = _selectedDateRange?.start ?? 
          DateTime.now().subtract(const Duration(days: 30));

      // Load both journals and expenses in parallel
      final futures = <Future>[];
      
      if (_selectedTypes.contains(TimelineItemType.journal)) {
        futures.add(JournalService.getEntries(
          offset: _currentPage * _pageSize,
          limit: _pageSize,
          animalId: _selectedAnimalId,
          category: _selectedCategory,
          startDate: startDate,
          endDate: endDate,
        ));
      } else {
        futures.add(Future.value([]));
      }

      if (_selectedTypes.contains(TimelineItemType.expense)) {
        futures.add(ExpenseService.getExpenses(
          offset: _currentPage * _pageSize,
          limit: _pageSize,
          animalId: _selectedAnimalId,
          category: _selectedCategory,
          startDate: startDate,
          endDate: endDate,
        ));
      } else {
        futures.add(Future.value([]));
      }

      final results = await Future.wait(futures);
      
      final journals = results[0] as List<JournalEntry>;
      final expenses = results[1] as List<Expense>;

      // Convert to timeline items
      final newItems = <TimelineItem>[
        ...journals.map((j) => TimelineItem.fromJournal(
          j,
          animalName: _animalNames[j.animalId],
        )),
        ...expenses.map((e) => TimelineItem.fromExpense(
          e,
          animalName: _animalNames[e.animalId],
        )),
      ];

      // Sort by date (newest first)
      newItems.sort((a, b) => b.date.compareTo(a.date));

      setState(() {
        if (reset) {
          _allItems = newItems;
        } else {
          _allItems.addAll(newItems);
        }
        _currentPage++;
        _hasMoreData = newItems.length == _pageSize;
        _applyFilters();
      });
    } catch (e) {
      _showErrorSnackbar('Error loading data: ${e.toString()}');
    } finally {
      setState(() => _isLoadingMore = false);
    }
  }

  Future<void> _loadMoreData() async {
    if (!_hasMoreData || _isLoadingMore) return;
    await _loadTimelineData(reset: false);
  }

  Future<void> _loadStatistics() async {
    try {
      final endDate = _selectedDateRange?.end ?? DateTime.now();
      final startDate = _selectedDateRange?.start ?? 
          DateTime.now().subtract(const Duration(days: 30));

      final expenseStats = await ExpenseService.getExpenseStats(
        startDate: startDate,
        endDate: endDate,
        animalId: _selectedAnimalId,
      );

      setState(() {
        _statistics = {
          'totalExpenses': expenseStats['totalAmount'] ?? 0,
          'transactionCount': expenseStats['transactionCount'] ?? 0,
          'journalCount': _allItems
              .where((i) => i.type == TimelineItemType.journal)
              .length,
          'averageExpense': expenseStats['averageAmount'] ?? 0,
          'topCategory': expenseStats['topCategory'],
          'categoryBreakdown': expenseStats['categoryBreakdown'] ?? {},
        };
      });
    } catch (e) {
      print('Error loading statistics: $e');
    }
  }

  void _applyFilters() {
    var filtered = List<TimelineItem>.from(_allItems);

    // Apply search filter
    if (_searchQuery.isNotEmpty) {
      final query = _searchQuery.toLowerCase();
      filtered = filtered.where((item) {
        return item.title.toLowerCase().contains(query) ||
               item.description.toLowerCase().contains(query) ||
               (item.tags?.any((tag) => tag.toLowerCase().contains(query)) ?? false);
      }).toList();
    }

    // Group by date
    _groupedItems.clear();
    for (final item in filtered) {
      final dateKey = DateTime(
        item.date.year,
        item.date.month,
        item.date.day,
      );
      
      if (!_groupedItems.containsKey(dateKey)) {
        _groupedItems[dateKey] = [];
      }
      
      _groupedItems[dateKey]!.add(item);
    }

    // Sort dates
    final sortedDates = _groupedItems.keys.toList()
      ..sort((a, b) => b.compareTo(a));

    setState(() {
      _filteredItems = filtered;
      _groupedItems = Map.fromEntries(
        sortedDates.map((date) => MapEntry(date, _groupedItems[date]!))
      );
    });
  }

  void _showErrorSnackbar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }

  Future<void> _handleRefresh() async {
    setState(() => _isRefreshing = true);
    await _initializeData();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // Required for AutomaticKeepAliveClientMixin
    
    return Scaffold(
      backgroundColor: ShowTrackColors.background,
      appBar: _buildAppBar(context),
      body: TabBarView(
        controller: _tabController,
        physics: const ClampingScrollPhysics(),
        children: [
          _buildTimelineView(),
          _buildCalendarView(),
          _buildAnalyticsView(),
        ],
      ),
      floatingActionButton: _buildFloatingActionButton(context),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
    );
  }
  
  PreferredSizeWidget _buildAppBar(BuildContext context) {
    final isSmallScreen = ResponsiveUtils.isSmallScreen(context);
    
    return AppBar(
      title: AnimatedSwitcher(
        duration: const Duration(milliseconds: 300),
        child: _isRefreshing
            ? Row(
                key: const ValueKey('refreshing'),
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Text('Refreshing...'),
                ],
              )
            : const Text(
                'Timeline',
                key: ValueKey('timeline'),
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
      ),
      backgroundColor: ShowTrackColors.primary,
      elevation: 0,
      systemOverlayStyle: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
      ),
      bottom: TabBar(
        controller: _tabController,
        indicatorColor: Colors.white,
        indicatorWeight: 3,
        indicatorPadding: EdgeInsets.symmetric(
          horizontal: isSmallScreen ? 8 : 16,
        ),
        labelColor: Colors.white,
        unselectedLabelColor: Colors.white70,
        labelStyle: TextStyle(
          fontSize: isSmallScreen ? 11 : 12,
          fontWeight: FontWeight.w600,
        ),
        unselectedLabelStyle: TextStyle(
          fontSize: isSmallScreen ? 10 : 11,
        ),
        tabs: [
          Tab(
            text: isSmallScreen ? 'Feed' : 'Timeline',
            icon: Icon(Icons.timeline, size: isSmallScreen ? 18 : 20),
          ),
          Tab(
            text: 'Calendar',
            icon: Icon(Icons.calendar_month, size: isSmallScreen ? 18 : 20),
          ),
          Tab(
            text: isSmallScreen ? 'Stats' : 'Analytics',
            icon: Icon(Icons.analytics, size: isSmallScreen ? 18 : 20),
          ),
        ],
      ),
      actions: [
        AnimatedRotation(
          turns: _isRefreshing ? 1 : 0,
          duration: const Duration(milliseconds: 800),
          child: IconButton(
            icon: const Icon(Icons.filter_list, color: Colors.white),
            onPressed: _isRefreshing ? null : _showFilterDialog,
            tooltip: 'Filter timeline',
            splashRadius: 24,
          ),
        ),
        if (!ResponsiveUtils.isVerySmallScreen(context))
          IconButton(
            icon: const Icon(Icons.add, color: Colors.white),
            onPressed: _isRefreshing ? null : _showAddOptions,
            tooltip: 'Add new item',
            splashRadius: 24,
          ),
      ],
    );
  }
  
  Widget _buildFloatingActionButton(BuildContext context) {
    if (ResponsiveUtils.isVerySmallScreen(context)) {
      return ScaleTransition(
        scale: _fabScaleAnimation,
        child: FloatingActionButton(
          onPressed: _showAddOptions,
          backgroundColor: ShowTrackColors.primary,
          child: const Icon(Icons.add, color: Colors.white),
          tooltip: 'Add new item',
        ),
      );
    }
    return const SizedBox.shrink();
  }

  Widget _buildTimelineView() {
    if (_isLoading) {
      return _buildLoadingState();
    }

    if (_filteredItems.isEmpty) {
      return _buildEmptyState();
    }

    return RefreshIndicator(
      onRefresh: _handleRefresh,
      displacement: 40,
      strokeWidth: 3,
      backgroundColor: ShowTrackColors.surface,
      color: ShowTrackColors.primary,
      child: Column(
        children: [
          // Search bar with animation
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            padding: ResponsiveUtils.getResponsivePadding(context),
            color: ShowTrackColors.surface,
            child: _buildSearchBar(context),
          ),
          
          // Statistics summary with fade animation
          if (_statistics.isNotEmpty)
            AnimatedOpacity(
              opacity: _isRefreshing ? 0.6 : 1.0,
              duration: const Duration(milliseconds: 300),
              child: TimelineStatsCard(statistics: _statistics),
            ),
          
          // Timeline list with enhanced animations
          Expanded(
            child: AnimatedList(
              key: GlobalKey<AnimatedListState>(),
              controller: _scrollController,
              padding: EdgeInsets.only(
                bottom: ResponsiveUtils.getSafeAreaBottomPadding(context),
              ),
              initialItemCount: _groupedItems.length + (_isLoadingMore ? 1 : 0),
              itemBuilder: (context, index, animation) {
                if (index >= _groupedItems.length) {
                  return SlideTransition(
                    position: animation.drive(
                      Tween(begin: const Offset(0, 0.5), end: Offset.zero),
                    ),
                    child: FadeTransition(
                      opacity: animation,
                      child: const Center(
                        child: Padding(
                          padding: EdgeInsets.all(16.0),
                          child: CircularProgressIndicator(),
                        ),
                      ),
                    ),
                  );
                }

                final date = _groupedItems.keys.elementAt(index);
                final items = _groupedItems[date]!;
                
                return SlideTransition(
                  position: animation.drive(
                    Tween(begin: const Offset(0, 0.3), end: Offset.zero).chain(
                      CurveTween(curve: Curves.easeOutCubic),
                    ),
                  ),
                  child: FadeTransition(
                    opacity: animation.drive(CurveTween(curve: Curves.easeIn)),
                    child: _buildDateGroup(context, date, items),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(
            strokeWidth: 3,
          ),
          const SizedBox(height: 16),
          Text(
            'Loading your timeline...',
            style: TextStyle(
              fontSize: 16,
              color: ShowTrackColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildSearchBar(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: ShowTrackColors.background,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: TextField(
        decoration: InputDecoration(
          hintText: 'Search timeline...',
          hintStyle: TextStyle(
            color: ShowTrackColors.textHint,
            fontSize: ResponsiveUtils.getResponsiveFontSize(context, baseSize: 14),
          ),
          prefixIcon: Icon(
            Icons.search,
            color: ShowTrackColors.textSecondary,
          ),
          suffixIcon: _searchQuery.isNotEmpty
              ? IconButton(
                  icon: Icon(
                    Icons.clear,
                    color: ShowTrackColors.textSecondary,
                  ),
                  onPressed: () {
                    HapticFeedback.lightImpact();
                    setState(() => _searchQuery = '');
                    _applyFilters();
                  },
                  splashRadius: 20,
                )
              : null,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          filled: true,
          fillColor: ShowTrackColors.surface,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 12,
          ),
        ),
        style: TextStyle(
          fontSize: ResponsiveUtils.getResponsiveFontSize(context, baseSize: 14),
        ),
        onChanged: (value) {
          setState(() => _searchQuery = value);
          _applyFilters();
        },
      ),
    );
  }
  
  Widget _buildDateGroup(BuildContext context, DateTime date, List<TimelineItem> items) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Enhanced date header
        Container(
          padding: EdgeInsets.symmetric(
            horizontal: ResponsiveUtils.isSmallScreen(context) ? 16 : 20,
            vertical: 12,
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: ShowTrackColors.primary,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: ShowTrackColors.primary.withOpacity(0.3),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Text(
                  _formatDateHeader(date),
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: ResponsiveUtils.getResponsiveFontSize(
                      context,
                      baseSize: 12,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Container(
                  height: 1,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        ShowTrackColors.primary.withOpacity(0.3),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 2,
                ),
                decoration: BoxDecoration(
                  color: ShowTrackColors.textSecondary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${items.length} item${items.length != 1 ? 's' : ''}',
                  style: TextStyle(
                    color: ShowTrackColors.textSecondary,
                    fontSize: ResponsiveUtils.getResponsiveFontSize(
                      context,
                      baseSize: 11,
                    ),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
        
        // Timeline items with staggered animation
        ...items.asMap().entries.map((entry) {
          final index = entry.key;
          final item = entry.value;
          
          return TweenAnimationBuilder<double>(
            duration: Duration(milliseconds: 300 + (index * 100)),
            tween: Tween(begin: 0.0, end: 1.0),
            curve: Curves.easeOutCubic,
            builder: (context, value, child) {
              return Transform.translate(
                offset: Offset(0, 20 * (1 - value)),
                child: Opacity(
                  opacity: value,
                  child: TimelineItemCard(
                    item: item,
                    onTap: () => _navigateToDetail(item),
                  ),
                ),
              );
            },
          );
        }).toList(),
      ],
    );
  }

  Widget _buildCalendarView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.calendar_month, size: 64, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            'Calendar View',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Coming soon! View your timeline in calendar format.',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[500],
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildAnalyticsView() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Summary cards
          Row(
            children: [
              Expanded(
                child: _buildStatCard(
                  'Total Expenses',
                  '\$${_statistics['totalExpenses']?.toStringAsFixed(2) ?? '0.00'}',
                  Icons.attach_money,
                  Colors.green,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildStatCard(
                  'Journal Entries',
                  '${_statistics['journalCount'] ?? 0}',
                  Icons.book,
                  Colors.blue,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildStatCard(
                  'Transactions',
                  '${_statistics['transactionCount'] ?? 0}',
                  Icons.receipt,
                  Colors.orange,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildStatCard(
                  'Avg Expense',
                  '\$${_statistics['averageExpense']?.toStringAsFixed(2) ?? '0.00'}',
                  Icons.trending_up,
                  Colors.purple,
                ),
              ),
            ],
          ),
          
          // Category breakdown
          const SizedBox(height: 24),
          Text(
            'Expense Categories',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 16),
          if (_statistics['categoryBreakdown'] != null)
            ...(_statistics['categoryBreakdown'] as Map<String, dynamic>)
                .entries
                .map((entry) => _buildCategoryBar(
                      entry.key,
                      entry.value.toDouble(),
                      _statistics['totalExpenses'] ?? 1,
                    ))
                .toList(),
        ],
      ),
    );
  }

  Widget _buildStatCard(
    String title,
    String value,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              const Spacer(),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryBar(String category, double amount, double total) {
    final percentage = (amount / total * 100).toStringAsFixed(1);
    final displayName = ExpenseCategories.getDisplayName(category);
    final color = ExpenseCategories.getColor(category);
    
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                displayName,
                style: const TextStyle(fontSize: 14),
              ),
              Text(
                '\$${amount.toStringAsFixed(2)} ($percentage%)',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          LinearProgressIndicator(
            value: amount / total,
            backgroundColor: Colors.grey[200],
            valueColor: AlwaysStoppedAnimation<Color>(color),
            minHeight: 6,
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return RefreshIndicator(
      onRefresh: _handleRefresh,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: Container(
          height: MediaQuery.of(context).size.height * 0.6,
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                TweenAnimationBuilder<double>(
                  duration: const Duration(milliseconds: 800),
                  tween: Tween(begin: 0.0, end: 1.0),
                  curve: Curves.elasticOut,
                  builder: (context, value, child) {
                    return Transform.scale(
                      scale: value,
                      child: Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: ShowTrackColors.primary.withOpacity(0.1),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.timeline,
                          size: 64,
                          color: ShowTrackColors.primary,
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 24),
                Text(
                  'Your timeline is empty',
                  style: TextStyle(
                    fontSize: ResponsiveUtils.getResponsiveFontSize(
                      context,
                      baseSize: 20,
                    ),
                    fontWeight: FontWeight.bold,
                    color: ShowTrackColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32),
                  child: Text(
                    'Start documenting your agricultural journey by adding journal entries and tracking expenses.',
                    style: TextStyle(
                      fontSize: ResponsiveUtils.getResponsiveFontSize(
                        context,
                        baseSize: 14,
                      ),
                      color: ShowTrackColors.textSecondary,
                      height: 1.5,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(height: 32),
                
                // Responsive button layout
                if (ResponsiveUtils.isSmallScreen(context))
                  Column(
                    children: [
                      SizedBox(
                        width: 200,
                        child: ElevatedButton.icon(
                          icon: const Icon(Icons.book),
                          label: const Text('Add Journal Entry'),
                          onPressed: _navigateToAddJournal,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: ShowTrackColors.primary,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                              vertical: 12,
                              horizontal: 16,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: 200,
                        child: ElevatedButton.icon(
                          icon: const Icon(Icons.attach_money),
                          label: const Text('Track Expense'),
                          onPressed: _navigateToAddExpense,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: ShowTrackColors.info,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                              vertical: 12,
                              horizontal: 16,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                    ],
                  )
                else
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      ElevatedButton.icon(
                        icon: const Icon(Icons.book),
                        label: const Text('Add Journal Entry'),
                        onPressed: _navigateToAddJournal,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: ShowTrackColors.primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                            vertical: 12,
                            horizontal: 16,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      ElevatedButton.icon(
                        icon: const Icon(Icons.attach_money),
                        label: const Text('Track Expense'),
                        onPressed: _navigateToAddExpense,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: ShowTrackColors.info,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                            vertical: 12,
                            horizontal: 16,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ],
                  ),
                  
                const SizedBox(height: 24),
                
                // Quick tips
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 24),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: ShowTrackColors.info.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: ShowTrackColors.info.withOpacity(0.2),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.lightbulb_outline,
                        color: ShowTrackColors.info,
                        size: 20,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Pull down to refresh • Tap + to add items • Use filters to organize',
                          style: TextStyle(
                            fontSize: 12,
                            color: ShowTrackColors.info,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _formatDateHeader(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    
    if (date == today) {
      return 'Today';
    } else if (date == yesterday) {
      return 'Yesterday';
    } else if (date.year == now.year) {
      return DateFormat('MMMM d').format(date);
    } else {
      return DateFormat('MMMM d, yyyy').format(date);
    }
  }

  void _showFilterDialog() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => TimelineFilters(
        selectedTypes: _selectedTypes,
        selectedAnimalId: _selectedAnimalId,
        selectedDateRange: _selectedDateRange,
        selectedCategory: _selectedCategory,
        animals: _animals,
        onApplyFilters: (types, animalId, dateRange, category) {
          setState(() {
            _selectedTypes = types;
            _selectedAnimalId = animalId;
            _selectedDateRange = dateRange;
            _selectedCategory = category;
          });
          _initializeData();
        },
      ),
    );
  }

  void _showAddOptions() {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.book, color: Colors.blue),
              title: const Text('Add Journal Entry'),
              onTap: () {
                Navigator.pop(context);
                _navigateToAddJournal();
              },
            ),
            ListTile(
              leading: const Icon(Icons.attach_money, color: Colors.green),
              title: const Text('Add Expense'),
              onTap: () {
                Navigator.pop(context);
                _navigateToAddExpense();
              },
            ),
          ],
        ),
      ),
    );
  }

  void _navigateToDetail(TimelineItem item) {
    // Add haptic feedback for navigation
    HapticFeedback.selectionClick();
    
    if (item.type == TimelineItemType.journal) {
      Navigator.pushNamed(
        context,
        '/journal/detail',
        arguments: item.journalEntry,
      ).then((_) {
        // Only refresh if we're still on this screen
        if (mounted) {
          _initializeData();
        }
      });
    } else {
      Navigator.pushNamed(
        context,
        '/expense/detail',
        arguments: item.expense,
      ).then((_) {
        // Only refresh if we're still on this screen
        if (mounted) {
          _initializeData();
        }
      });
    }
  }

  void _navigateToAddJournal() {
    HapticFeedback.lightImpact();
    Navigator.pushNamed(context, '/journal/new')
        .then((_) {
          if (mounted) {
            _initializeData();
          }
        });
  }

  void _navigateToAddExpense() {
    HapticFeedback.lightImpact();
    Navigator.pushNamed(context, '/expense/new')
        .then((_) {
          if (mounted) {
            _initializeData();
          }
        });
  }
}