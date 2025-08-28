import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/timeline_item.dart';
import 'timeline_service.dart';
import 'timeline_cache_service.dart';

/// High-performance pagination service for timeline infinite scroll
/// Implements intelligent prefetching, deduplication, and batch loading
class TimelinePaginationService {
  static TimelinePaginationService? _instance;
  static TimelinePaginationService get instance => _instance ??= TimelinePaginationService._();
  TimelinePaginationService._();

  // Configuration
  static const int defaultPageSize = 20;
  static const int prefetchThreshold = 5; // Load more when 5 items from bottom
  static const int maxPrefetchPages = 2; // Maximum pages to prefetch
  static const Duration batchDelay = Duration(milliseconds: 300); // Batch multiple requests

  // State management
  final Map<String, _PaginationState> _states = {};
  final Map<String, Timer> _batchTimers = {};

  /// Initialize pagination for a timeline query
  String initializePagination({
    String? category,
    String? animalId,
    DateTime? startDate,
    DateTime? endDate,
    List<String>? itemTypes,
  }) {
    final queryId = _generateQueryId(
      category: category,
      animalId: animalId,
      startDate: startDate,
      endDate: endDate,
      itemTypes: itemTypes,
    );

    _states[queryId] = _PaginationState(
      queryId: queryId,
      category: category,
      animalId: animalId,
      startDate: startDate,
      endDate: endDate,
      itemTypes: itemTypes,
    );

    return queryId;
  }

  /// Get current timeline items for query
  List<TimelineItem> getItems(String queryId) {
    return _states[queryId]?.items ?? [];
  }

  /// Check if more data is available
  bool hasMoreData(String queryId) {
    return _states[queryId]?.hasMore ?? false;
  }

  /// Check if currently loading
  bool isLoading(String queryId) {
    return _states[queryId]?.isLoading ?? false;
  }

  /// Get current page info
  Map<String, dynamic> getPageInfo(String queryId) {
    final state = _states[queryId];
    if (state == null) return {};

    return {
      'currentPage': state.currentPage,
      'totalItems': state.items.length,
      'hasMore': state.hasMore,
      'isLoading': state.isLoading,
      'lastUpdated': state.lastUpdated,
      'cacheHitRate': state.cacheHitRate,
    };
  }

  /// Load initial page
  Future<List<TimelineItem>> loadInitialPage(String queryId) async {
    final state = _states[queryId];
    if (state == null) throw Exception('Query not initialized: $queryId');

    state.isLoading = true;
    state.items.clear();
    state.currentPage = 0;

    try {
      final response = await TimelineService.getTimelineItems(
        limit: defaultPageSize,
        offset: 0,
        startDate: state.startDate,
        endDate: state.endDate,
        category: state.category,
        animalId: state.animalId,
        itemTypes: state.itemTypes,
      );

      state.items = response.items;
      state.hasMore = response.hasMore;
      state.totalCount = response.totalCount;
      state.lastUpdated = DateTime.now();

      // Start prefetching next page if available
      if (state.hasMore && state.items.length > prefetchThreshold) {
        _schedulePrefetch(queryId);
      }

      return state.items;

    } catch (e) {
      state.error = e.toString();
      rethrow;
    } finally {
      state.isLoading = false;
    }
  }

  /// Load next page (infinite scroll)
  Future<List<TimelineItem>> loadNextPage(String queryId) async {
    final state = _states[queryId];
    if (state == null) throw Exception('Query not initialized: $queryId');

    if (state.isLoading || !state.hasMore) {
      return state.items;
    }

    state.isLoading = true;

    try {
      final offset = state.items.length;
      
      final response = await TimelineService.getTimelineItems(
        limit: defaultPageSize,
        offset: offset,
        startDate: state.startDate,
        endDate: state.endDate,
        category: state.category,
        animalId: state.animalId,
        itemTypes: state.itemTypes,
      );

      // Deduplicate items (prevent duplicates on fast scrolling)
      final existingIds = state.items.map((item) => item.id).toSet();
      final newItems = response.items
          .where((item) => !existingIds.contains(item.id))
          .toList();

      state.items.addAll(newItems);
      state.hasMore = response.hasMore;
      state.currentPage++;
      state.lastUpdated = DateTime.now();

      // Update cache hit rate tracking
      state.cacheRequests++;
      if (response.totalCount == state.totalCount) {
        state.cacheHits++;
      }

      // Schedule next prefetch
      if (state.hasMore && newItems.isNotEmpty) {
        _schedulePrefetch(queryId);
      }

      return state.items;

    } catch (e) {
      state.error = e.toString();
      rethrow;
    } finally {
      state.isLoading = false;
    }
  }

  /// Refresh timeline data
  Future<List<TimelineItem>> refreshTimeline(String queryId) async {
    final state = _states[queryId];
    if (state == null) throw Exception('Query not initialized: $queryId');

    // Invalidate cache for this query
    await TimelineCacheService.instance.invalidateCache(queryId);

    // Reset state
    state.currentPage = 0;
    state.hasMore = true;
    state.error = null;

    return await loadInitialPage(queryId);
  }

  /// Smart prefetching based on scroll position
  void _schedulePrefetch(String queryId) {
    // Cancel existing timer
    _batchTimers[queryId]?.cancel();

    // Schedule batched prefetch
    _batchTimers[queryId] = Timer(batchDelay, () => _executePrefetch(queryId));
  }

  /// Execute prefetch operation
  Future<void> _executePrefetch(String queryId) async {
    final state = _states[queryId];
    if (state == null || !state.hasMore || state.isLoading) return;

    try {
      // Prefetch next 1-2 pages in background
      final prefetchPages = state.hasMore ? 
          (state.totalCount > 100 ? maxPrefetchPages : 1) : 0;

      for (int i = 1; i <= prefetchPages; i++) {
        final offset = state.items.length + ((i - 1) * defaultPageSize);
        
        // Don't prefetch if we already have this data
        if (offset >= state.totalCount) break;

        final cacheKey = _generateCacheKey(queryId, offset);
        final cachedData = await TimelineCacheService.instance
            .getTimelineData(cacheKey, _getQueryParams(state, offset));

        if (cachedData == null) {
          // Load and cache in background
          TimelineService.getTimelineItems(
            limit: defaultPageSize,
            offset: offset,
            startDate: state.startDate,
            endDate: state.endDate,
            category: state.category,
            animalId: state.animalId,
            itemTypes: state.itemTypes,
          ).then((response) {
            TimelineCacheService.instance.storeTimelineData(cacheKey, response);
            debugPrint('🎯 Prefetched page at offset $offset for $queryId');
          }).catchError((e) {
            debugPrint('❌ Prefetch failed for $queryId: $e');
          });
        }
      }

    } catch (e) {
      debugPrint('Prefetch error for $queryId: $e');
    }
  }

  /// Get scroll position for triggering next load
  bool shouldLoadMore(String queryId, int visibleItemIndex) {
    final state = _states[queryId];
    if (state == null || state.isLoading || !state.hasMore) {
      return false;
    }

    // Load more when user is within prefetchThreshold items from the end
    return visibleItemIndex >= (state.items.length - prefetchThreshold);
  }

  /// Bulk operations for better performance
  Future<List<String>> initializeMultipleQueries(List<Map<String, dynamic>> queries) async {
    final queryIds = <String>[];
    
    for (final query in queries) {
      final queryId = initializePagination(
        category: query['category'],
        animalId: query['animalId'],
        startDate: query['startDate'],
        endDate: query['endDate'],
        itemTypes: query['itemTypes'],
      );
      queryIds.add(queryId);
    }

    // Load initial pages in parallel
    await Future.wait(queryIds.map((id) => loadInitialPage(id)));

    return queryIds;
  }

  /// Clean up pagination state
  void disposePagination(String queryId) {
    _batchTimers[queryId]?.cancel();
    _batchTimers.remove(queryId);
    _states.remove(queryId);
  }

  /// Clean up all pagination states
  void disposeAll() {
    _batchTimers.values.forEach((timer) => timer.cancel());
    _batchTimers.clear();
    _states.clear();
  }

  /// Get performance metrics
  Map<String, dynamic> getMetrics() {
    final totalItems = _states.values.fold<int>(
      0, (sum, state) => sum + state.items.length,
    );
    
    final totalCacheRequests = _states.values.fold<int>(
      0, (sum, state) => sum + state.cacheRequests,
    );
    
    final totalCacheHits = _states.values.fold<int>(
      0, (sum, state) => sum + state.cacheHits,
    );

    return {
      'activeQueries': _states.length,
      'totalItems': totalItems,
      'averageItemsPerQuery': _states.isNotEmpty ? totalItems / _states.length : 0,
      'cacheHitRate': totalCacheRequests > 0 ? totalCacheHits / totalCacheRequests : 0,
      'prefetchTimers': _batchTimers.length,
    };
  }

  /// Helper methods
  String _generateQueryId({
    String? category,
    String? animalId,
    DateTime? startDate,
    DateTime? endDate,
    List<String>? itemTypes,
  }) {
    return [
      'query',
      category ?? 'all',
      animalId ?? 'all',
      startDate?.millisecondsSinceEpoch.toString() ?? '',
      endDate?.millisecondsSinceEpoch.toString() ?? '',
      itemTypes?.join(',') ?? 'all',
    ].join('_');
  }

  String _generateCacheKey(String queryId, int offset) {
    return '${queryId}_offset_$offset';
  }

  Map<String, dynamic> _getQueryParams(_PaginationState state, int offset) {
    return {
      'limit': defaultPageSize,
      'offset': offset,
      'category': state.category,
      'animalId': state.animalId,
      'startDate': state.startDate,
      'endDate': state.endDate,
      'itemTypes': state.itemTypes,
    };
  }
}

/// Internal pagination state
class _PaginationState {
  final String queryId;
  final String? category;
  final String? animalId;
  final DateTime? startDate;
  final DateTime? endDate;
  final List<String>? itemTypes;

  List<TimelineItem> items = [];
  int currentPage = 0;
  bool hasMore = true;
  bool isLoading = false;
  int totalCount = 0;
  String? error;
  DateTime? lastUpdated;

  // Performance tracking
  int cacheRequests = 0;
  int cacheHits = 0;

  double get cacheHitRate => cacheRequests > 0 ? cacheHits / cacheRequests : 0.0;

  _PaginationState({
    required this.queryId,
    this.category,
    this.animalId,
    this.startDate,
    this.endDate,
    this.itemTypes,
  });
}