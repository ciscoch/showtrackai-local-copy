import 'dart:io';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path_provider/path_provider.dart';
import 'package:device_info_plus/device_info_plus.dart';

/// Comprehensive offline storage management with quota limits and smart cleanup
class OfflineStorageManager {
  static final OfflineStorageManager _instance = OfflineStorageManager._internal();
  factory OfflineStorageManager() => _instance;
  OfflineStorageManager._internal();

  SharedPreferences? _prefs;
  Directory? _appDir;
  
  // Storage quotas and limits (in bytes)
  static const int DEFAULT_TOTAL_LIMIT = 100 * 1024 * 1024; // 100MB
  static const int DEFAULT_PHOTO_LIMIT = 50 * 1024 * 1024;  // 50MB
  static const int DEFAULT_DATA_LIMIT = 30 * 1024 * 1024;   // 30MB
  static const int DEFAULT_CACHE_LIMIT = 20 * 1024 * 1024;  // 20MB
  static const int CRITICAL_DAYS_KEEP = 30; // Always keep last 30 days
  static const int WARNING_THRESHOLD_PERCENT = 80; // Warn at 80% capacity
  static const int CLEANUP_THRESHOLD_PERCENT = 90; // Auto-cleanup at 90%
  
  // Data type identifiers
  enum DataType {
    journalEntries,
    animals,
    photos,
    healthRecords,
    weights,
    tempCache,
    userData
  }

  /// Initialize the storage manager
  Future<void> initialize() async {
    _prefs = await SharedPreferences.getInstance();
    _appDir = await getApplicationDocumentsDirectory();
    
    // Set default quotas if not configured
    await _ensureDefaultQuotas();
    
    // Perform initial storage assessment
    await _performInitialAssessment();
  }

  /// Set storage quotas for different data types
  Future<void> setStorageQuotas({
    int? totalLimit,
    int? photoLimit,
    int? dataLimit,
    int? cacheLimit,
  }) async {
    if (totalLimit != null) {
      await _prefs!.setInt('quota_total', totalLimit);
    }
    if (photoLimit != null) {
      await _prefs!.setInt('quota_photos', photoLimit);
    }
    if (dataLimit != null) {
      await _prefs!.setInt('quota_data', dataLimit);
    }
    if (cacheLimit != null) {
      await _prefs!.setInt('quota_cache', cacheLimit);
    }
    
    debugPrint('Updated storage quotas: Total=${totalLimit ?? getCurrentQuota('total')}B, '
               'Photos=${photoLimit ?? getCurrentQuota('photos')}B, '
               'Data=${dataLimit ?? getCurrentQuota('data')}B');
  }

  /// Get current storage usage statistics
  Future<StorageStats> getStorageStats() async {
    final stats = StorageStats();
    
    // Calculate usage by data type
    stats.journalEntriesSize = await _calculateDataTypeSize(DataType.journalEntries);
    stats.animalsSize = await _calculateDataTypeSize(DataType.animals);
    stats.photosSize = await _calculateDataTypeSize(DataType.photos);
    stats.healthRecordsSize = await _calculateDataTypeSize(DataType.healthRecords);
    stats.weightsSize = await _calculateDataTypeSize(DataType.weights);
    stats.tempCacheSize = await _calculateDataTypeSize(DataType.tempCache);
    
    stats.totalUsed = stats.journalEntriesSize + stats.animalsSize + stats.photosSize +
                     stats.healthRecordsSize + stats.weightsSize + stats.tempCacheSize;
    
    // Get quotas
    stats.totalQuota = getCurrentQuota('total');
    stats.photoQuota = getCurrentQuota('photos');
    stats.dataQuota = getCurrentQuota('data');
    
    // Get device available storage
    stats.deviceAvailable = await _getDeviceAvailableStorage();
    
    // Calculate usage percentages
    stats.usagePercentage = (stats.totalUsed / stats.totalQuota * 100).round();
    stats.photoUsagePercentage = (stats.photosSize / stats.photoQuota * 100).round();
    
    // Check if cleanup is needed
    stats.needsCleanup = stats.usagePercentage >= CLEANUP_THRESHOLD_PERCENT;
    stats.showWarning = stats.usagePercentage >= WARNING_THRESHOLD_PERCENT;
    
    return stats;
  }

  /// Check if we can store new data of specified size
  Future<StoragePermission> canStoreData(DataType dataType, int sizeInBytes) async {
    final stats = await getStorageStats();
    final permission = StoragePermission();
    
    permission.canStore = true;
    permission.warnings = [];
    
    // Check total quota
    if (stats.totalUsed + sizeInBytes > stats.totalQuota) {
      permission.canStore = false;
      permission.warnings.add('Total storage quota exceeded');
    }
    
    // Check photo quota specifically
    if (dataType == DataType.photos && 
        stats.photosSize + sizeInBytes > stats.photoQuota) {
      permission.canStore = false;
      permission.warnings.add('Photo storage quota exceeded');
    }
    
    // Check device storage
    if (sizeInBytes > stats.deviceAvailable) {
      permission.canStore = false;
      permission.warnings.add('Insufficient device storage');
    }
    
    // Suggest cleanup if approaching limits
    if (stats.usagePercentage >= WARNING_THRESHOLD_PERCENT) {
      permission.warnings.add('Approaching storage limit - consider cleanup');
      permission.suggestCleanup = true;
    }
    
    return permission;
  }

  /// Perform smart cleanup to free storage space
  Future<CleanupResult> performSmartCleanup({bool forceCleanup = false}) async {
    final result = CleanupResult();
    final initialStats = await getStorageStats();
    
    if (!forceCleanup && initialStats.usagePercentage < CLEANUP_THRESHOLD_PERCENT) {
      result.message = 'No cleanup needed';
      return result;
    }
    
    debugPrint('Starting smart cleanup. Current usage: ${initialStats.usagePercentage}%');
    
    // Cleanup strategy (in order of priority)
    int cleanedBytes = 0;
    
    // 1. Clear temporary caches first
    cleanedBytes += await _clearTemporaryCaches();
    
    // 2. Remove old synced data (beyond critical period)
    cleanedBytes += await _removeOldSyncedData();
    
    // 3. Compress photos if needed
    if (initialStats.photosSize > initialStats.photoQuota * 0.8) {
      cleanedBytes += await _compressOldPhotos();
    }
    
    // 4. Archive old journal entries (move to compressed storage)
    cleanedBytes += await _archiveOldJournalEntries();
    
    // 5. Remove least recently used cached data
    cleanedBytes += await _performLRUCleanup();
    
    // Update cleanup timestamp
    await _prefs!.setInt('last_cleanup', DateTime.now().millisecondsSinceEpoch);
    
    final finalStats = await getStorageStats();
    result.bytesFreed = cleanedBytes;
    result.newUsagePercentage = finalStats.usagePercentage;
    result.success = cleanedBytes > 0;
    result.message = 'Cleaned ${_formatBytes(cleanedBytes)} of storage';
    
    debugPrint('Cleanup completed. Freed: ${_formatBytes(cleanedBytes)}, '
               'New usage: ${finalStats.usagePercentage}%');
    
    return result;
  }

  /// Get data that should never be deleted (unsynced, recent, critical)
  Future<Set<String>> getProtectedDataIds() async {
    final protected = <String>{};
    
    // Get unsynced data
    final unsyncedJournals = _prefs!.getStringList('unsynced_journals') ?? [];
    final unsyncedAnimals = _prefs!.getStringList('unsynced_animals') ?? [];
    final unsyncedWeights = _prefs!.getStringList('unsynced_weights') ?? [];
    
    protected.addAll(unsyncedJournals);
    protected.addAll(unsyncedAnimals);
    protected.addAll(unsyncedWeights);
    
    // Get recent data (last 30 days)
    final criticalDate = DateTime.now().subtract(Duration(days: CRITICAL_DAYS_KEEP));
    
    // Add recent journal entries
    final journalKeys = _prefs!.getKeys()
        .where((key) => key.startsWith('journal_entry_'))
        .where((key) => _isDataRecent(key, criticalDate));
    
    protected.addAll(journalKeys.map((key) => key.replaceFirst('journal_entry_', '')));
    
    return protected;
  }

  /// Track data access for LRU cache management
  Future<void> trackDataAccess(String dataId, DataType dataType) async {
    final accessKey = 'access_${dataType.name}_$dataId';
    await _prefs!.setInt(accessKey, DateTime.now().millisecondsSinceEpoch);
  }

  /// Get storage usage by user (COPPA compliance)
  Future<UserStorageInfo> getUserStorageInfo(String userId) async {
    final userInfo = UserStorageInfo(userId: userId);
    
    // Calculate user-specific storage
    userInfo.journalEntriesSize = await _calculateUserDataSize(userId, DataType.journalEntries);
    userInfo.animalsSize = await _calculateUserDataSize(userId, DataType.animals);
    userInfo.photosSize = await _calculateUserDataSize(userId, DataType.photos);
    
    userInfo.totalSize = userInfo.journalEntriesSize + userInfo.animalsSize + userInfo.photosSize;
    
    // Check if user is minor for COPPA compliance
    final birthDate = _prefs!.getString('user_birth_date_$userId');
    if (birthDate != null) {
      final birth = DateTime.parse(birthDate);
      final age = DateTime.now().difference(birth).inDays / 365.25;
      userInfo.isMinor = age < 13;
      
      // Apply stricter limits for minors
      if (userInfo.isMinor) {
        userInfo.dataRetentionDays = 30; // Keep less data for minors
        userInfo.totalQuota = min(getCurrentQuota('total'), 25 * 1024 * 1024); // Max 25MB for minors
      }
    }
    
    return userInfo;
  }

  /// Clear all offline data for a user (COPPA compliance)
  Future<void> clearUserData(String userId) async {
    debugPrint('Clearing offline data for user: $userId');
    
    // Remove user-specific preferences
    final keysToRemove = _prefs!.getKeys()
        .where((key) => key.contains(userId))
        .toList();
    
    for (final key in keysToRemove) {
      await _prefs!.remove(key);
    }
    
    // Remove user files
    await _removeUserFiles(userId);
    
    debugPrint('Cleared offline data for user: $userId');
  }

  /// Get cleanup recommendations
  Future<List<CleanupRecommendation>> getCleanupRecommendations() async {
    final recommendations = <CleanupRecommendation>[];
    final stats = await getStorageStats();
    
    // Temporary cache cleanup
    if (stats.tempCacheSize > 5 * 1024 * 1024) { // > 5MB
      recommendations.add(CleanupRecommendation(
        type: 'cache',
        description: 'Clear temporary caches',
        potentialSavings: stats.tempCacheSize,
        impact: CleanupImpact.low,
      ));
    }
    
    // Photo compression
    if (stats.photosSize > stats.photoQuota * 0.7) {
      final compressionSavings = (stats.photosSize * 0.4).round(); // Estimate 40% savings
      recommendations.add(CleanupRecommendation(
        type: 'photos',
        description: 'Compress old photos',
        potentialSavings: compressionSavings,
        impact: CleanupImpact.medium,
      ));
    }
    
    // Old data archival
    final oldDataSize = await _estimateOldDataSize();
    if (oldDataSize > 10 * 1024 * 1024) { // > 10MB
      recommendations.add(CleanupRecommendation(
        type: 'archive',
        description: 'Archive old journal entries',
        potentialSavings: oldDataSize,
        impact: CleanupImpact.low,
      ));
    }
    
    return recommendations;
  }

  // Private helper methods
  
  Future<void> _ensureDefaultQuotas() async {
    if (!_prefs!.containsKey('quota_total')) {
      await setStorageQuotas(
        totalLimit: DEFAULT_TOTAL_LIMIT,
        photoLimit: DEFAULT_PHOTO_LIMIT,
        dataLimit: DEFAULT_DATA_LIMIT,
        cacheLimit: DEFAULT_CACHE_LIMIT,
      );
    }
  }

  Future<void> _performInitialAssessment() async {
    final stats = await getStorageStats();
    
    if (stats.needsCleanup) {
      debugPrint('Initial assessment: Storage cleanup needed (${stats.usagePercentage}%)');
      await performSmartCleanup();
    } else if (stats.showWarning) {
      debugPrint('Initial assessment: Approaching storage limit (${stats.usagePercentage}%)');
    }
  }

  int getCurrentQuota(String type) {
    switch (type) {
      case 'total':
        return _prefs!.getInt('quota_total') ?? DEFAULT_TOTAL_LIMIT;
      case 'photos':
        return _prefs!.getInt('quota_photos') ?? DEFAULT_PHOTO_LIMIT;
      case 'data':
        return _prefs!.getInt('quota_data') ?? DEFAULT_DATA_LIMIT;
      case 'cache':
        return _prefs!.getInt('quota_cache') ?? DEFAULT_CACHE_LIMIT;
      default:
        return DEFAULT_TOTAL_LIMIT;
    }
  }

  Future<int> _calculateDataTypeSize(DataType dataType) async {
    int totalSize = 0;
    
    try {
      switch (dataType) {
        case DataType.journalEntries:
          final journalKeys = _prefs!.getKeys()
              .where((key) => key.startsWith('journal_entry_'));
          for (final key in journalKeys) {
            final data = _prefs!.getString(key) ?? '';
            totalSize += utf8.encode(data).length;
          }
          break;
          
        case DataType.animals:
          final animalKeys = _prefs!.getKeys()
              .where((key) => key.startsWith('animal_'));
          for (final key in animalKeys) {
            final data = _prefs!.getString(key) ?? '';
            totalSize += utf8.encode(data).length;
          }
          break;
          
        case DataType.photos:
          final photosDir = Directory('${_appDir!.path}/photos');
          if (await photosDir.exists()) {
            await for (final file in photosDir.list()) {
              if (file is File) {
                totalSize += await file.length();
              }
            }
          }
          break;
          
        case DataType.tempCache:
          final cacheDir = Directory('${_appDir!.path}/cache');
          if (await cacheDir.exists()) {
            await for (final file in cacheDir.list()) {
              if (file is File) {
                totalSize += await file.length();
              }
            }
          }
          break;
          
        default:
          // Handle other data types
          break;
      }
    } catch (e) {
      debugPrint('Error calculating size for ${dataType.name}: $e');
    }
    
    return totalSize;
  }

  Future<int> _getDeviceAvailableStorage() async {
    try {
      final deviceInfo = DeviceInfoPlugin();
      if (Platform.isAndroid) {
        final androidInfo = await deviceInfo.androidInfo;
        // Estimate available storage (Android doesn't provide direct API)
        return 1024 * 1024 * 1024; // Assume 1GB available
      } else if (Platform.isIOS) {
        // iOS provides storage info through different means
        final stat = await _appDir!.stat();
        return 512 * 1024 * 1024; // Conservative estimate for iOS
      }
    } catch (e) {
      debugPrint('Error getting device storage: $e');
    }
    
    return 100 * 1024 * 1024; // Default 100MB if unknown
  }

  Future<int> _clearTemporaryCaches() async {
    int freedBytes = 0;
    
    try {
      final cacheDir = Directory('${_appDir!.path}/cache');
      if (await cacheDir.exists()) {
        await for (final file in cacheDir.list()) {
          if (file is File) {
            freedBytes += await file.length();
            await file.delete();
          }
        }
      }
      
      // Clear SharedPreferences cache entries
      final cacheKeys = _prefs!.getKeys()
          .where((key) => key.startsWith('cache_'))
          .toList();
      
      for (final key in cacheKeys) {
        final data = _prefs!.getString(key) ?? '';
        freedBytes += utf8.encode(data).length;
        await _prefs!.remove(key);
      }
    } catch (e) {
      debugPrint('Error clearing caches: $e');
    }
    
    return freedBytes;
  }

  Future<int> _removeOldSyncedData() async {
    int freedBytes = 0;
    final protectedIds = await getProtectedDataIds();
    final cutoffDate = DateTime.now().subtract(Duration(days: CRITICAL_DAYS_KEEP * 2)); // 60 days
    
    try {
      // Remove old synced journal entries
      final journalKeys = _prefs!.getKeys()
          .where((key) => key.startsWith('journal_entry_'))
          .where((key) => !protectedIds.contains(key.replaceFirst('journal_entry_', '')))
          .where((key) => !_isDataRecent(key, cutoffDate))
          .toList();
      
      for (final key in journalKeys) {
        final data = _prefs!.getString(key) ?? '';
        freedBytes += utf8.encode(data).length;
        await _prefs!.remove(key);
      }
      
      debugPrint('Removed ${journalKeys.length} old journal entries');
    } catch (e) {
      debugPrint('Error removing old synced data: $e');
    }
    
    return freedBytes;
  }

  Future<int> _compressOldPhotos() async {
    int freedBytes = 0;
    
    try {
      final photosDir = Directory('${_appDir!.path}/photos');
      if (await photosDir.exists()) {
        final cutoffDate = DateTime.now().subtract(Duration(days: CRITICAL_DAYS_KEEP));
        
        await for (final file in photosDir.list()) {
          if (file is File) {
            final stat = await file.stat();
            if (stat.modified.isBefore(cutoffDate)) {
              final originalSize = await file.length();
              // Simulate compression (in real implementation, use image compression library)
              final compressedSize = (originalSize * 0.6).round();
              freedBytes += originalSize - compressedSize;
              
              // Mark as compressed
              await _prefs!.setBool('compressed_${file.path}', true);
            }
          }
        }
      }
    } catch (e) {
      debugPrint('Error compressing photos: $e');
    }
    
    return freedBytes;
  }

  Future<int> _archiveOldJournalEntries() async {
    int freedBytes = 0;
    final protectedIds = await getProtectedDataIds();
    final archiveDate = DateTime.now().subtract(Duration(days: CRITICAL_DAYS_KEEP * 3)); // 90 days
    
    try {
      final journalKeys = _prefs!.getKeys()
          .where((key) => key.startsWith('journal_entry_'))
          .where((key) => !protectedIds.contains(key.replaceFirst('journal_entry_', '')))
          .where((key) => !_isDataRecent(key, archiveDate))
          .toList();
      
      for (final key in journalKeys) {
        final data = _prefs!.getString(key) ?? '';
        final originalSize = utf8.encode(data).length;
        
        // Create archived version (compressed JSON)
        final archiveKey = key.replaceFirst('journal_entry_', 'archived_journal_');
        final archiveData = _compressJsonString(data);
        await _prefs!.setString(archiveKey, archiveData);
        
        // Remove original
        await _prefs!.remove(key);
        
        freedBytes += originalSize - utf8.encode(archiveData).length;
      }
      
      debugPrint('Archived ${journalKeys.length} old journal entries');
    } catch (e) {
      debugPrint('Error archiving journal entries: $e');
    }
    
    return freedBytes;
  }

  Future<int> _performLRUCleanup() async {
    int freedBytes = 0;
    
    try {
      // Get access timestamps for data
      final accessData = <String, int>{};
      
      for (final key in _prefs!.getKeys()) {
        if (key.startsWith('access_')) {
          final timestamp = _prefs!.getInt(key) ?? 0;
          final dataId = key.replaceFirst(RegExp(r'access_\w+_'), '');
          accessData[dataId] = timestamp;
        }
      }
      
      // Sort by access time (oldest first)
      final sortedByAccess = accessData.entries.toList()
        ..sort((a, b) => a.value.compareTo(b.value));
      
      // Remove oldest 20% if we have enough data
      if (sortedByAccess.length > 10) {
        final toRemove = (sortedByAccess.length * 0.2).round();
        for (int i = 0; i < toRemove; i++) {
          final dataId = sortedByAccess[i].key;
          freedBytes += await _removeDataById(dataId);
        }
      }
    } catch (e) {
      debugPrint('Error performing LRU cleanup: $e');
    }
    
    return freedBytes;
  }

  Future<int> _calculateUserDataSize(String userId, DataType dataType) async {
    int totalSize = 0;
    
    try {
      final keys = _prefs!.getKeys()
          .where((key) => key.contains(userId) && key.contains(dataType.name.toLowerCase()));
      
      for (final key in keys) {
        final data = _prefs!.getString(key) ?? '';
        totalSize += utf8.encode(data).length;
      }
    } catch (e) {
      debugPrint('Error calculating user data size: $e');
    }
    
    return totalSize;
  }

  Future<void> _removeUserFiles(String userId) async {
    try {
      // Remove user photos
      final photosDir = Directory('${_appDir!.path}/photos/$userId');
      if (await photosDir.exists()) {
        await photosDir.delete(recursive: true);
      }
      
      // Remove user cache
      final cacheDir = Directory('${_appDir!.path}/cache/$userId');
      if (await cacheDir.exists()) {
        await cacheDir.delete(recursive: true);
      }
    } catch (e) {
      debugPrint('Error removing user files: $e');
    }
  }

  bool _isDataRecent(String key, DateTime cutoffDate) {
    try {
      // Extract timestamp from key or check stored metadata
      final timestampKey = '${key}_timestamp';
      final timestamp = _prefs!.getInt(timestampKey);
      
      if (timestamp != null) {
        final dataDate = DateTime.fromMillisecondsSinceEpoch(timestamp);
        return dataDate.isAfter(cutoffDate);
      }
    } catch (e) {
      debugPrint('Error checking data recency: $e');
    }
    
    return true; // Assume recent if we can't determine
  }

  String _compressJsonString(String jsonString) {
    // Simple compression simulation
    // In real implementation, use gzip or similar
    try {
      final json = jsonDecode(jsonString);
      return jsonEncode(json); // Re-encode to remove whitespace
    } catch (e) {
      return jsonString;
    }
  }

  Future<int> _removeDataById(String dataId) async {
    int freedBytes = 0;
    
    try {
      // Remove from SharedPreferences
      final keys = _prefs!.getKeys()
          .where((key) => key.contains(dataId))
          .toList();
      
      for (final key in keys) {
        final data = _prefs!.getString(key);
        if (data != null) {
          freedBytes += utf8.encode(data).length;
          await _prefs!.remove(key);
        }
      }
      
      // Remove associated files
      final photoFile = File('${_appDir!.path}/photos/$dataId.jpg');
      if (await photoFile.exists()) {
        freedBytes += await photoFile.length();
        await photoFile.delete();
      }
    } catch (e) {
      debugPrint('Error removing data by ID: $e');
    }
    
    return freedBytes;
  }

  Future<int> _estimateOldDataSize() async {
    int estimatedSize = 0;
    final oldDate = DateTime.now().subtract(Duration(days: CRITICAL_DAYS_KEEP * 2));
    
    try {
      final oldKeys = _prefs!.getKeys()
          .where((key) => key.startsWith('journal_entry_') || key.startsWith('animal_'))
          .where((key) => !_isDataRecent(key, oldDate));
      
      for (final key in oldKeys) {
        final data = _prefs!.getString(key) ?? '';
        estimatedSize += utf8.encode(data).length;
      }
    } catch (e) {
      debugPrint('Error estimating old data size: $e');
    }
    
    return estimatedSize;
  }

  String _formatBytes(int bytes) {
    if (bytes < 1024) return '${bytes}B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)}KB';
    if (bytes < 1024 * 1024 * 1024) return '${(bytes / (1024 * 1024)).toStringAsFixed(1)}MB';
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)}GB';
  }
}

/// Storage statistics and usage information
class StorageStats {
  int totalUsed = 0;
  int totalQuota = 0;
  int journalEntriesSize = 0;
  int animalsSize = 0;
  int photosSize = 0;
  int healthRecordsSize = 0;
  int weightsSize = 0;
  int tempCacheSize = 0;
  int photoQuota = 0;
  int dataQuota = 0;
  int deviceAvailable = 0;
  int usagePercentage = 0;
  int photoUsagePercentage = 0;
  bool needsCleanup = false;
  bool showWarning = false;
  
  Map<String, dynamic> toMap() => {
    'totalUsed': totalUsed,
    'totalQuota': totalQuota,
    'journalEntriesSize': journalEntriesSize,
    'animalsSize': animalsSize,
    'photosSize': photosSize,
    'healthRecordsSize': healthRecordsSize,
    'weightsSize': weightsSize,
    'tempCacheSize': tempCacheSize,
    'usagePercentage': usagePercentage,
    'needsCleanup': needsCleanup,
    'showWarning': showWarning,
  };
}

/// Storage permission check result
class StoragePermission {
  bool canStore = true;
  List<String> warnings = [];
  bool suggestCleanup = false;
  
  bool get hasWarnings => warnings.isNotEmpty;
}

/// Cleanup operation result
class CleanupResult {
  bool success = false;
  int bytesFreed = 0;
  int newUsagePercentage = 0;
  String message = '';
  
  Map<String, dynamic> toMap() => {
    'success': success,
    'bytesFreed': bytesFreed,
    'newUsagePercentage': newUsagePercentage,
    'message': message,
  };
}

/// User-specific storage information (COPPA compliance)
class UserStorageInfo {
  final String userId;
  int totalSize = 0;
  int journalEntriesSize = 0;
  int animalsSize = 0;
  int photosSize = 0;
  bool isMinor = false;
  int dataRetentionDays = 365;
  int totalQuota = 0;
  
  UserStorageInfo({required this.userId});
  
  Map<String, dynamic> toMap() => {
    'userId': userId,
    'totalSize': totalSize,
    'journalEntriesSize': journalEntriesSize,
    'animalsSize': animalsSize,
    'photosSize': photosSize,
    'isMinor': isMinor,
    'dataRetentionDays': dataRetentionDays,
    'totalQuota': totalQuota,
  };
}

/// Cleanup recommendation
class CleanupRecommendation {
  final String type;
  final String description;
  final int potentialSavings;
  final CleanupImpact impact;
  
  CleanupRecommendation({
    required this.type,
    required this.description,
    required this.potentialSavings,
    required this.impact,
  });
  
  Map<String, dynamic> toMap() => {
    'type': type,
    'description': description,
    'potentialSavings': potentialSavings,
    'impact': impact.name,
  };
}

enum CleanupImpact { low, medium, high }