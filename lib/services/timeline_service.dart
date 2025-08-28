import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/timeline_item.dart';
import '../models/journal_entry.dart';
import '../models/expense.dart';

/// High-performance timeline service optimized for APP-125
/// Implements unified timeline queries with caching and pagination
class TimelineService {
  static final _supabase = Supabase.instance.client;
  static const String _baseUrl = 'https://mellifluous-speculoos-46225c.netlify.app';
  
  // Cache for timeline data (5 minutes TTL)
  static final Map<String, _CacheEntry> _cache = {};
  static const Duration _cacheTimeout = Duration(minutes: 5);

  /// Get paginated timeline items with optimal database query
  static Future<TimelineResponse> getTimelineItems({
    int limit = 20,
    int offset = 0,
    DateTime? startDate,
    DateTime? endDate,
    String? category,
    String? animalId,
    List<String>? itemTypes,
    bool useCache = true,
  }) async {
    final currentUser = _supabase.auth.currentUser;
    if (currentUser == null) {
      throw Exception('User not authenticated');
    }

    // Generate cache key
    final cacheKey = _generateCacheKey(
      userId: currentUser.id,
      limit: limit,
      offset: offset,
      startDate: startDate,
      endDate: endDate,
      category: category,
      animalId: animalId,
      itemTypes: itemTypes,
    );

    // Check cache first
    if (useCache) {
      final cachedData = _getFromCache(cacheKey);
      if (cachedData != null) {
        return cachedData;
      }
    }

    try {
      // Use optimized database function instead of multiple queries
      final response = await _supabase
          .rpc('get_timeline_items', params: {
            'p_user_id': currentUser.id,
            'p_limit': limit,
            'p_offset': offset,
            'p_start_date': startDate?.toIso8601String()?.split('T')[0],
            'p_end_date': endDate?.toIso8601String()?.split('T')[0],
            'p_category': category,
            'p_animal_id': animalId,
            'p_item_types': itemTypes ?? ['journal', 'expense'],
          });

      final timelineItems = (response as List).map((item) {
        return TimelineItem(
          id: item['item_id'],
          date: DateTime.parse(item['date']),
          type: item['item_type'] == 'journal' 
              ? TimelineItemType.journal 
              : TimelineItemType.expense,
          title: item['title'] ?? '',
          description: item['content'] ?? '',
          animalId: item['animal_id'],
          animalName: item['animal_name'],
          amount: item['amount']?.toDouble(),
          category: item['category'],
          tags: item['tags'] != null ? List<String>.from(item['tags']) : null,
          imageUrl: item['attachments']?.isNotEmpty == true ? item['attachments'][0] : null,
          metadata: item['metadata'] != null ? Map<String, dynamic>.from(item['metadata']) : null,
        );
      }).toList();

      // Get total count for pagination (efficient count query)
      final countResponse = await _supabase
          .from('unified_timeline')
          .select('*', const FetchOptions(count: CountOption.exact))
          .eq('user_id', currentUser.id);

      final totalCount = countResponse.count ?? 0;
      final hasMore = offset + limit < totalCount;

      final result = TimelineResponse(
        items: timelineItems,
        totalCount: totalCount,
        hasMore: hasMore,
        nextOffset: hasMore ? offset + limit : null,
      );

      // Cache the result
      if (useCache) {
        _cache[cacheKey] = _CacheEntry(result, DateTime.now());
      }

      return result;

    } catch (e) {
      print('Error fetching timeline items: $e');
      throw Exception('Failed to fetch timeline items: $e');
    }
  }

  /// Get timeline statistics with advanced analytics
  static Future<TimelineStatistics> getTimelineStatistics({
    DateTime? startDate,
    DateTime? endDate,
    bool useCache = true,
  }) async {
    final currentUser = _supabase.auth.currentUser;
    if (currentUser == null) {
      throw Exception('User not authenticated');
    }

    final cacheKey = 'stats_${currentUser.id}_${startDate?.millisecondsSinceEpoch}_${endDate?.millisecondsSinceEpoch}';

    if (useCache) {
      final cachedStats = _getFromCache(cacheKey);
      if (cachedStats != null) {
        return cachedStats as TimelineStatistics;
      }
    }

    try {
      final response = await _supabase
          .rpc('get_timeline_statistics', params: {
            'p_user_id': currentUser.id,
            'p_start_date': startDate?.toIso8601String()?.split('T')[0],
            'p_end_date': endDate?.toIso8601String()?.split('T')[0],
          });

      final stats = TimelineStatistics.fromJson(response);
      
      if (useCache) {
        _cache[cacheKey] = _CacheEntry(stats, DateTime.now());
      }

      return stats;

    } catch (e) {
      print('Error fetching timeline statistics: $e');
      throw Exception('Failed to fetch timeline statistics: $e');
    }
  }

  /// Search timeline items with full-text search
  static Future<List<TimelineItem>> searchTimelineItems({
    required String query,
    int limit = 50,
    String? category,
    String? animalId,
    List<String>? itemTypes,
  }) async {
    final currentUser = _supabase.auth.currentUser;
    if (currentUser == null) {
      throw Exception('User not authenticated');
    }

    try {
      final response = await _supabase
          .from('unified_timeline')
          .select('*')
          .eq('user_id', currentUser.id)
          .textSearch('title,content', query)
          .order('date', ascending: false)
          .limit(limit);

      return (response as List).map((item) {
        return TimelineItem(
          id: item['item_id'],
          date: DateTime.parse(item['date']),
          type: item['item_type'] == 'journal' 
              ? TimelineItemType.journal 
              : TimelineItemType.expense,
          title: item['title'] ?? '',
          description: item['content'] ?? '',
          animalId: item['animal_id'],
          animalName: item['animal_name'],
          amount: item['amount']?.toDouble(),
          category: item['category'],
          tags: item['tags'] != null ? List<String>.from(item['tags']) : null,
        );
      }).toList();

    } catch (e) {
      print('Error searching timeline items: $e');
      throw Exception('Failed to search timeline items: $e');
    }
  }

  /// Get aggregated timeline data by date for calendar view
  static Future<Map<DateTime, TimelineDayAggregate>> getTimelineAggregateByDate({
    DateTime? startDate,
    DateTime? endDate,
    String? animalId,
  }) async {
    final currentUser = _supabase.auth.currentUser;
    if (currentUser == null) {
      throw Exception('User not authenticated');
    }

    try {
      final response = await _supabase
          .from('timeline_aggregated')
          .select('*')
          .eq('user_id', currentUser.id)
          .gte('date', startDate?.toIso8601String()?.split('T')[0] ?? '1970-01-01')
          .lte('date', endDate?.toIso8601String()?.split('T')[0] ?? '2099-12-31')
          .order('date', ascending: false);

      final Map<DateTime, TimelineDayAggregate> aggregates = {};

      for (final item in response) {
        final date = DateTime.parse(item['date']);
        aggregates[date] = TimelineDayAggregate(
          date: date,
          totalItems: item['total_items'],
          journalCount: item['journal_count'],
          expenseCount: item['expense_count'],
          totalExpenses: item['total_expenses']?.toDouble() ?? 0.0,
          averageQuality: item['avg_quality']?.toDouble(),
          categories: List<String>.from(item['categories'] ?? []),
          animalsInvolved: List<String>.from(item['animals_involved'] ?? []),
        );
      }

      return aggregates;

    } catch (e) {
      print('Error fetching timeline aggregates: $e');
      throw Exception('Failed to fetch timeline aggregates: $e');
    }
  }

  /// Invalidate cache (call after creating/updating items)
  static void invalidateCache([String? specificKey]) {
    if (specificKey != null) {
      _cache.remove(specificKey);
    } else {
      _cache.clear();
    }
  }

  /// Get item from cache if valid
  static T? _getFromCache<T>(String key) {
    final entry = _cache[key];
    if (entry == null) return null;
    
    if (DateTime.now().difference(entry.timestamp) > _cacheTimeout) {
      _cache.remove(key);
      return null;
    }

    return entry.data as T?;
  }

  /// Generate cache key for request parameters
  static String _generateCacheKey({
    required String userId,
    required int limit,
    required int offset,
    DateTime? startDate,
    DateTime? endDate,
    String? category,
    String? animalId,
    List<String>? itemTypes,
  }) {
    return [
      'timeline',
      userId,
      limit.toString(),
      offset.toString(),
      startDate?.millisecondsSinceEpoch.toString() ?? '',
      endDate?.millisecondsSinceEpoch.toString() ?? '',
      category ?? '',
      animalId ?? '',
      itemTypes?.join(',') ?? '',
    ].join('_');
  }
}

/// Response wrapper for paginated timeline data
class TimelineResponse {
  final List<TimelineItem> items;
  final int totalCount;
  final bool hasMore;
  final int? nextOffset;

  TimelineResponse({
    required this.items,
    required this.totalCount,
    required this.hasMore,
    this.nextOffset,
  });
}

/// Timeline statistics with advanced metrics
class TimelineStatistics {
  final int totalItems;
  final int journalCount;
  final int expenseCount;
  final double totalExpenses;
  final double? averageQuality;
  final List<String> categories;
  final DateTime? startDate;
  final DateTime? endDate;
  final Map<String, int> weeklyActivity;

  TimelineStatistics({
    required this.totalItems,
    required this.journalCount,
    required this.expenseCount,
    required this.totalExpenses,
    this.averageQuality,
    required this.categories,
    this.startDate,
    this.endDate,
    required this.weeklyActivity,
  });

  factory TimelineStatistics.fromJson(Map<String, dynamic> json) {
    return TimelineStatistics(
      totalItems: json['total_items'] ?? 0,
      journalCount: json['journal_count'] ?? 0,
      expenseCount: json['expense_count'] ?? 0,
      totalExpenses: json['total_expenses']?.toDouble() ?? 0.0,
      averageQuality: json['average_quality']?.toDouble(),
      categories: List<String>.from(json['categories'] ?? []),
      startDate: json['date_range']?['start'] != null 
          ? DateTime.parse(json['date_range']['start']) 
          : null,
      endDate: json['date_range']?['end'] != null 
          ? DateTime.parse(json['date_range']['end']) 
          : null,
      weeklyActivity: json['weekly_activity'] != null
          ? Map<String, int>.from(json['weekly_activity'])
          : {},
    );
  }
}

/// Daily aggregate data for timeline
class TimelineDayAggregate {
  final DateTime date;
  final int totalItems;
  final int journalCount;
  final int expenseCount;
  final double totalExpenses;
  final double? averageQuality;
  final List<String> categories;
  final List<String> animalsInvolved;

  TimelineDayAggregate({
    required this.date,
    required this.totalItems,
    required this.journalCount,
    required this.expenseCount,
    required this.totalExpenses,
    this.averageQuality,
    required this.categories,
    required this.animalsInvolved,
  });
}

/// Cache entry wrapper
class _CacheEntry {
  final dynamic data;
  final DateTime timestamp;

  _CacheEntry(this.data, this.timestamp);
}

/// Exception classes for timeline operations
class TimelineException implements Exception {
  final String message;
  final String? code;
  final dynamic originalException;

  TimelineException(this.message, {this.code, this.originalException});

  @override
  String toString() => 'TimelineException: $message';
}