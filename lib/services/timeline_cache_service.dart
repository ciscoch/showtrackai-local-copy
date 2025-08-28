import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/timeline_item.dart';
import 'timeline_service.dart';

/// Advanced multi-layer caching system for timeline data
/// Implements memory, disk, and network caching with intelligent invalidation
class TimelineCacheService {
  static TimelineCacheService? _instance;
  static TimelineCacheService get instance => _instance ??= TimelineCacheService._();
  TimelineCacheService._();

  // Memory cache (L1) - Fastest access
  final Map<String, _MemoryCacheEntry> _memoryCache = {};
  static const int _maxMemoryEntries = 100;
  static const Duration _memoryTtl = Duration(minutes: 5);

  // Disk cache (L2) - Persistent across app restarts
  SharedPreferences? _prefs;
  static const Duration _diskTtl = Duration(hours: 24);
  static const String _diskKeyPrefix = 'timeline_cache_';

  // Network cache headers (L3)
  final Map<String, String> _etags = {};

  /// Initialize cache service
  Future<void> initialize() async {
    _prefs = await SharedPreferences.getInstance();
    await _cleanupExpiredDiskCache();
  }

  /// Get timeline data with multi-layer caching
  Future<TimelineResponse?> getTimelineData(String cacheKey, Map<String, dynamic> queryParams) async {
    // L1: Check memory cache first
    final memoryData = _getFromMemoryCache(cacheKey);
    if (memoryData != null) {
      debugPrint('🟢 Cache HIT (Memory): $cacheKey');
      return memoryData;
    }

    // L2: Check disk cache
    final diskData = await _getFromDiskCache(cacheKey);
    if (diskData != null) {
      debugPrint('🟡 Cache HIT (Disk): $cacheKey');
      // Populate memory cache for faster future access
      _storeInMemoryCache(cacheKey, diskData);
      return diskData;
    }

    debugPrint('🔴 Cache MISS: $cacheKey');
    return null;
  }

  /// Store timeline data in all cache layers
  Future<void> storeTimelineData(String cacheKey, TimelineResponse data) async {
    // Store in memory cache (L1)
    _storeInMemoryCache(cacheKey, data);

    // Store in disk cache (L2)
    await _storeToDiskCache(cacheKey, data);
  }

  /// Get from memory cache (L1)
  TimelineResponse? _getFromMemoryCache(String key) {
    final entry = _memoryCache[key];
    if (entry == null) return null;

    // Check expiration
    if (DateTime.now().difference(entry.timestamp) > _memoryTtl) {
      _memoryCache.remove(key);
      return null;
    }

    // Update access time for LRU
    entry.lastAccessed = DateTime.now();
    return entry.data;
  }

  /// Store in memory cache (L1) with LRU eviction
  void _storeInMemoryCache(String key, TimelineResponse data) {
    // Evict oldest entries if cache is full
    if (_memoryCache.length >= _maxMemoryEntries) {
      final sortedEntries = _memoryCache.entries.toList()
        ..sort((a, b) => a.value.lastAccessed.compareTo(b.value.lastAccessed));
      
      // Remove oldest 20% of entries
      final toRemove = (_maxMemoryEntries * 0.2).round();
      for (int i = 0; i < toRemove; i++) {
        _memoryCache.remove(sortedEntries[i].key);
      }
    }

    _memoryCache[key] = _MemoryCacheEntry(
      data: data,
      timestamp: DateTime.now(),
      lastAccessed: DateTime.now(),
    );
  }

  /// Get from disk cache (L2)
  Future<TimelineResponse?> _getFromDiskCache(String key) async {
    if (_prefs == null) return null;

    try {
      final cacheData = _prefs!.getString('$_diskKeyPrefix$key');
      if (cacheData == null) return null;

      final Map<String, dynamic> cacheEntry = jsonDecode(cacheData);
      
      // Check expiration
      final timestamp = DateTime.parse(cacheEntry['timestamp']);
      if (DateTime.now().difference(timestamp) > _diskTtl) {
        await _prefs!.remove('$_diskKeyPrefix$key');
        return null;
      }

      // Deserialize timeline data
      final items = (cacheEntry['data']['items'] as List)
          .map((item) => TimelineItem.fromJson(item))
          .toList();

      return TimelineResponse(
        items: items,
        totalCount: cacheEntry['data']['totalCount'],
        hasMore: cacheEntry['data']['hasMore'],
        nextOffset: cacheEntry['data']['nextOffset'],
      );

    } catch (e) {
      debugPrint('Error reading from disk cache: $e');
      return null;
    }
  }

  /// Store to disk cache (L2)
  Future<void> _storeToDiskCache(String key, TimelineResponse data) async {
    if (_prefs == null) return;

    try {
      final cacheEntry = {
        'timestamp': DateTime.now().toIso8601String(),
        'data': {
          'items': data.items.map((item) => item.toJson()).toList(),
          'totalCount': data.totalCount,
          'hasMore': data.hasMore,
          'nextOffset': data.nextOffset,
        },
      };

      await _prefs!.setString('$_diskKeyPrefix$key', jsonEncode(cacheEntry));
    } catch (e) {
      debugPrint('Error storing to disk cache: $e');
    }
  }

  /// Clean up expired disk cache entries
  Future<void> _cleanupExpiredDiskCache() async {
    if (_prefs == null) return;

    final keys = _prefs!.getKeys()
        .where((key) => key.startsWith(_diskKeyPrefix))
        .toList();

    for (final key in keys) {
      try {
        final cacheData = _prefs!.getString(key);
        if (cacheData == null) continue;

        final Map<String, dynamic> cacheEntry = jsonDecode(cacheData);
        final timestamp = DateTime.parse(cacheEntry['timestamp']);
        
        if (DateTime.now().difference(timestamp) > _diskTtl) {
          await _prefs!.remove(key);
          debugPrint('Cleaned up expired cache entry: $key');
        }
      } catch (e) {
        // Remove corrupted entries
        await _prefs!.remove(key);
        debugPrint('Removed corrupted cache entry: $key');
      }
    }
  }

  /// Invalidate specific cache entries
  Future<void> invalidateCache(String pattern) async {
    // Clear memory cache
    _memoryCache.removeWhere((key, value) => key.contains(pattern));

    // Clear disk cache
    if (_prefs != null) {
      final keys = _prefs!.getKeys()
          .where((key) => key.startsWith(_diskKeyPrefix) && key.contains(pattern))
          .toList();

      for (final key in keys) {
        await _prefs!.remove(key);
      }
    }

    debugPrint('Invalidated cache entries matching: $pattern');
  }

  /// Clear all cache layers
  Future<void> clearAllCache() async {
    // Clear memory cache
    _memoryCache.clear();

    // Clear disk cache
    if (_prefs != null) {
      final keys = _prefs!.getKeys()
          .where((key) => key.startsWith(_diskKeyPrefix))
          .toList();

      for (final key in keys) {
        await _prefs!.remove(key);
      }
    }

    // Clear ETags
    _etags.clear();

    debugPrint('Cleared all timeline cache');
  }

  /// Get cache statistics for debugging
  Map<String, dynamic> getCacheStats() {
    final diskCacheCount = _prefs?.getKeys()
        .where((key) => key.startsWith(_diskKeyPrefix))
        .length ?? 0;

    return {
      'memoryCache': {
        'entries': _memoryCache.length,
        'maxEntries': _maxMemoryEntries,
        'ttl': _memoryTtl.inMinutes,
      },
      'diskCache': {
        'entries': diskCacheCount,
        'ttl': _diskTtl.inHours,
      },
      'networkCache': {
        'etags': _etags.length,
      }
    };
  }

  /// Preload cache for common queries
  Future<void> preloadCommonQueries(String userId) async {
    final commonQueries = [
      // Recent timeline (most common)
      {'limit': 20, 'offset': 0},
      // Last week data
      {
        'limit': 50,
        'offset': 0,
        'startDate': DateTime.now().subtract(const Duration(days: 7)),
      },
      // Last month data
      {
        'limit': 100,
        'offset': 0,
        'startDate': DateTime.now().subtract(const Duration(days: 30)),
      },
    ];

    for (final query in commonQueries) {
      try {
        final cacheKey = _generateCacheKey(userId, query);
        final cachedData = await getTimelineData(cacheKey, query);
        
        if (cachedData == null) {
          // Load and cache the data
          final data = await TimelineService.getTimelineItems(
            limit: query['limit'] as int,
            offset: query['offset'] as int,
            startDate: query['startDate'] as DateTime?,
          );
          await storeTimelineData(cacheKey, data);
          debugPrint('Preloaded cache for: $cacheKey');
        }
      } catch (e) {
        debugPrint('Failed to preload query: $e');
      }
    }
  }

  /// Generate consistent cache keys
  String _generateCacheKey(String userId, Map<String, dynamic> params) {
    final keyParts = [
      'timeline',
      userId,
      params['limit']?.toString() ?? '',
      params['offset']?.toString() ?? '',
      params['startDate']?.millisecondsSinceEpoch?.toString() ?? '',
      params['endDate']?.millisecondsSinceEpoch?.toString() ?? '',
      params['category']?.toString() ?? '',
      params['animalId']?.toString() ?? '',
    ];
    return keyParts.join('_');
  }
}

/// Memory cache entry with access tracking
class _MemoryCacheEntry {
  final TimelineResponse data;
  final DateTime timestamp;
  DateTime lastAccessed;

  _MemoryCacheEntry({
    required this.data,
    required this.timestamp,
    required this.lastAccessed,
  });
}

/// Cache performance metrics
class CacheMetrics {
  static int _memoryHits = 0;
  static int _diskHits = 0;
  static int _misses = 0;

  static void recordMemoryHit() => _memoryHits++;
  static void recordDiskHit() => _diskHits++;
  static void recordMiss() => _misses++;

  static Map<String, dynamic> getMetrics() {
    final total = _memoryHits + _diskHits + _misses;
    return {
      'memoryHits': _memoryHits,
      'diskHits': _diskHits,
      'misses': _misses,
      'totalRequests': total,
      'memoryHitRate': total > 0 ? _memoryHits / total : 0.0,
      'diskHitRate': total > 0 ? _diskHits / total : 0.0,
      'missRate': total > 0 ? _misses / total : 0.0,
    };
  }

  static void reset() {
    _memoryHits = 0;
    _diskHits = 0;
    _misses = 0;
  }
}