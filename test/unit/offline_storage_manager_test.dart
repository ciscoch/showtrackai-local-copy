import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path_provider/path_provider.dart';
import 'package:device_info_plus/device_info_plus.dart';

import '../../lib/services/offline_storage_manager.dart';
import 'offline_storage_manager_test.mocks.dart';

@GenerateMocks([
  SharedPreferences,
  Directory,
  File,
  DeviceInfoPlugin,
  AndroidDeviceInfo,
  FileStat,
])
void main() {
  group('OfflineStorageManager Unit Tests', () {
    late OfflineStorageManager storageManager;
    late MockSharedPreferences mockPrefs;
    late MockDirectory mockAppDir;
    late MockDirectory mockPhotosDir;
    late MockDirectory mockCacheDir;
    late MockFile mockFile;
    late MockDeviceInfoPlugin mockDeviceInfo;

    const int totalLimit = 100 * 1024 * 1024; // 100MB
    const int photoLimit = 50 * 1024 * 1024;  // 50MB
    const int dataLimit = 30 * 1024 * 1024;   // 30MB
    const int cacheLimit = 20 * 1024 * 1024;  // 20MB

    setUp(() {
      storageManager = OfflineStorageManager();
      mockPrefs = MockSharedPreferences();
      mockAppDir = MockDirectory();
      mockPhotosDir = MockDirectory();
      mockCacheDir = MockDirectory();
      mockFile = MockFile();
      mockDeviceInfo = MockDeviceInfoPlugin();

      // Setup default mock behavior
      when(mockAppDir.path).thenReturn('/test/app/dir');
      when(mockPhotosDir.path).thenReturn('/test/app/dir/photos');
      when(mockCacheDir.path).thenReturn('/test/app/dir/cache');
      
      SharedPreferences.setMockInitialValues({});
    });

    group('initialize', () {
      test('should initialize with default quotas', () async {
        // Arrange
        when(mockPrefs.containsKey('quota_total')).thenReturn(false);
        when(mockPrefs.setInt(any, any)).thenAnswer((_) async => true);
        when(mockPrefs.getKeys()).thenReturn(<String>{});
        when(mockPrefs.getString(any)).thenReturn(null);
        when(mockPrefs.getInt(any)).thenReturn(null);

        // Mock path provider
        await storageManager.initialize();

        // Act & Assert
        expect(storageManager.getCurrentQuota('total'), equals(totalLimit));
        expect(storageManager.getCurrentQuota('photos'), equals(photoLimit));
        expect(storageManager.getCurrentQuota('data'), equals(dataLimit));
        expect(storageManager.getCurrentQuota('cache'), equals(cacheLimit));
      });

      test('should perform initial assessment and cleanup if needed', () async {
        // Arrange
        when(mockPrefs.containsKey('quota_total')).thenReturn(true);
        when(mockPrefs.getInt('quota_total')).thenReturn(totalLimit);
        when(mockPrefs.getInt('quota_photos')).thenReturn(photoLimit);
        when(mockPrefs.getInt('quota_data')).thenReturn(dataLimit);
        when(mockPrefs.getInt('quota_cache')).thenReturn(cacheLimit);
        when(mockPrefs.getKeys()).thenReturn(<String>{});
        when(mockPrefs.getString(any)).thenReturn(null);
        when(mockPrefs.setInt(any, any)).thenAnswer((_) async => true);

        // Mock high storage usage requiring cleanup
        when(mockPrefs.getKeys()).thenReturn({
          'journal_entry_1', 'journal_entry_2', 'cache_item_1'
        });
        when(mockPrefs.getString('journal_entry_1')).thenReturn(
          'x' * (totalLimit ~/ 2) // Half the total limit
        );
        when(mockPrefs.getString('journal_entry_2')).thenReturn(
          'x' * (totalLimit ~/ 2) // Another half, causing 100% usage
        );
        
        // Act
        await storageManager.initialize();

        // Assert - Should not throw and should handle cleanup
        expect(() => storageManager.getCurrentQuota('total'), returnsNormally);
      });
    });

    group('setStorageQuotas', () {
      test('should update quotas correctly', () async {
        // Arrange
        when(mockPrefs.setInt(any, any)).thenAnswer((_) async => true);
        when(mockPrefs.getInt(any)).thenReturn(null);

        // Act
        await storageManager.setStorageQuotas(
          totalLimit: 200 * 1024 * 1024,
          photoLimit: 100 * 1024 * 1024,
        );

        // Assert
        verify(mockPrefs.setInt('quota_total', 200 * 1024 * 1024)).called(1);
        verify(mockPrefs.setInt('quota_photos', 100 * 1024 * 1024)).called(1);
      });

      test('should only update specified quotas', () async {
        // Arrange
        when(mockPrefs.setInt(any, any)).thenAnswer((_) async => true);
        when(mockPrefs.getInt('quota_total')).thenReturn(totalLimit);
        when(mockPrefs.getInt('quota_photos')).thenReturn(photoLimit);
        when(mockPrefs.getInt('quota_data')).thenReturn(dataLimit);
        when(mockPrefs.getInt('quota_cache')).thenReturn(cacheLimit);

        // Act
        await storageManager.setStorageQuotas(photoLimit: 75 * 1024 * 1024);

        // Assert
        verify(mockPrefs.setInt('quota_photos', 75 * 1024 * 1024)).called(1);
        verifyNever(mockPrefs.setInt('quota_total', any));
      });
    });

    group('getStorageStats', () {
      test('should calculate storage statistics correctly', () async {
        // Arrange
        _setupStorageStatsMocks();

        // Act
        final stats = await storageManager.getStorageStats();

        // Assert
        expect(stats.totalUsed, greaterThan(0));
        expect(stats.totalQuota, equals(totalLimit));
        expect(stats.photoQuota, equals(photoLimit));
        expect(stats.usagePercentage, isA<int>());
        expect(stats.usagePercentage, inInclusiveRange(0, 100));
      });

      test('should detect when cleanup is needed', () async {
        // Arrange
        _setupHighUsageStorageMocks();

        // Act
        final stats = await storageManager.getStorageStats();

        // Assert
        expect(stats.needsCleanup, isTrue);
        expect(stats.usagePercentage, greaterThanOrEqualTo(90));
      });

      test('should show warning when approaching limit', () async {
        // Arrange
        _setupWarningLevelStorageMocks();

        // Act
        final stats = await storageManager.getStorageStats();

        // Assert
        expect(stats.showWarning, isTrue);
        expect(stats.usagePercentage, greaterThanOrEqualTo(80));
        expect(stats.needsCleanup, isFalse);
      });
    });

    group('canStoreData', () {
      test('should allow storage when under limits', () async {
        // Arrange
        _setupLowUsageStorageMocks();

        // Act
        final permission = await storageManager.canStoreData(
          OfflineStorageManager.DataType.journalEntries,
          1024 * 1024, // 1MB
        );

        // Assert
        expect(permission.canStore, isTrue);
        expect(permission.warnings, isEmpty);
        expect(permission.suggestCleanup, isFalse);
      });

      test('should deny storage when exceeding total quota', () async {
        // Arrange
        _setupHighUsageStorageMocks();

        // Act
        final permission = await storageManager.canStoreData(
          OfflineStorageManager.DataType.journalEntries,
          10 * 1024 * 1024, // 10MB (would exceed limit)
        );

        // Assert
        expect(permission.canStore, isFalse);
        expect(permission.warnings, contains('Total storage quota exceeded'));
      });

      test('should deny storage when exceeding photo quota', () async {
        // Arrange
        _setupLowUsageStorageMocks();
        
        // Mock high photo usage
        when(mockPhotosDir.exists()).thenAnswer((_) async => true);
        when(mockPhotosDir.list()).thenAnswer((_) => Stream.fromIterable([
          mockFile,
        ]));
        when(mockFile.length()).thenAnswer((_) async => photoLimit - 1024); // Almost full

        // Act
        final permission = await storageManager.canStoreData(
          OfflineStorageManager.DataType.photos,
          2048, // Would exceed photo quota
        );

        // Assert
        expect(permission.canStore, isFalse);
        expect(permission.warnings, contains('Photo storage quota exceeded'));
      });

      test('should suggest cleanup when approaching limits', () async {
        // Arrange
        _setupWarningLevelStorageMocks();

        // Act
        final permission = await storageManager.canStoreData(
          OfflineStorageManager.DataType.journalEntries,
          1024,
        );

        // Assert
        expect(permission.canStore, isTrue);
        expect(permission.suggestCleanup, isTrue);
        expect(permission.warnings, contains('Approaching storage limit - consider cleanup'));
      });

      test('should check device storage availability', () async {
        // Arrange
        _setupLowUsageStorageMocks();

        // Mock low device storage
        when(mockDeviceInfo.androidInfo).thenAnswer((_) async => MockAndroidDeviceInfo());

        // Act
        final permission = await storageManager.canStoreData(
          OfflineStorageManager.DataType.photos,
          2 * 1024 * 1024 * 1024, // 2GB - exceeds estimated device storage
        );

        // Assert
        expect(permission.canStore, isFalse);
        expect(permission.warnings, contains('Insufficient device storage'));
      });
    });

    group('performSmartCleanup', () {
      test('should not cleanup when under threshold', () async {
        // Arrange
        _setupLowUsageStorageMocks();

        // Act
        final result = await storageManager.performSmartCleanup();

        // Assert
        expect(result.success, isFalse);
        expect(result.message, equals('No cleanup needed'));
        expect(result.bytesFreed, equals(0));
      });

      test('should perform cleanup when over threshold', () async {
        // Arrange
        _setupHighUsageStorageMocks();
        _setupCleanupMocks();

        // Act
        final result = await storageManager.performSmartCleanup(forceCleanup: true);

        // Assert
        expect(result.success, isTrue);
        expect(result.bytesFreed, greaterThan(0));
        expect(result.message, contains('Cleaned'));
        verify(mockPrefs.setInt('last_cleanup', any)).called(1);
      });

      test('should clear temporary caches first', () async {
        // Arrange
        _setupHighUsageStorageMocks();
        _setupCacheCleanupMocks();

        // Act
        final result = await storageManager.performSmartCleanup(forceCleanup: true);

        // Assert
        expect(result.bytesFreed, greaterThan(0));
      });

      test('should compress photos when photo storage is high', () async {
        // Arrange
        _setupHighUsageStorageMocks();
        _setupPhotoCompressionMocks();

        // Act
        final result = await storageManager.performSmartCleanup(forceCleanup: true);

        // Assert
        expect(result.bytesFreed, greaterThan(0));
        verify(mockPrefs.setBool(argThat(startsWith('compressed_')), true)).called(atLeastOnce);
      });

      test('should archive old journal entries', () async {
        // Arrange
        _setupHighUsageStorageMocks();
        _setupJournalArchiveMocks();

        // Act
        final result = await storageManager.performSmartCleanup(forceCleanup: true);

        // Assert
        expect(result.bytesFreed, greaterThan(0));
      });
    });

    group('getProtectedDataIds', () {
      test('should protect unsynced data', () async {
        // Arrange
        when(mockPrefs.getStringList('unsynced_journals'))
            .thenReturn(['journal_1', 'journal_2']);
        when(mockPrefs.getStringList('unsynced_animals'))
            .thenReturn(['animal_1']);
        when(mockPrefs.getStringList('unsynced_weights'))
            .thenReturn(['weight_1']);

        // Act
        final protectedIds = await storageManager.getProtectedDataIds();

        // Assert
        expect(protectedIds, contains('journal_1'));
        expect(protectedIds, contains('journal_2'));
        expect(protectedIds, contains('animal_1'));
        expect(protectedIds, contains('weight_1'));
      });

      test('should protect recent data', () async {
        // Arrange
        when(mockPrefs.getStringList(any)).thenReturn([]);
        
        final recentTimestamp = DateTime.now().subtract(Duration(days: 15)).millisecondsSinceEpoch;
        when(mockPrefs.getKeys()).thenReturn({
          'journal_entry_recent',
          'journal_entry_old'
        });
        when(mockPrefs.getInt('journal_entry_recent_timestamp')).thenReturn(recentTimestamp);
        when(mockPrefs.getInt('journal_entry_old_timestamp')).thenReturn(
          DateTime.now().subtract(Duration(days: 60)).millisecondsSinceEpoch
        );

        // Act
        final protectedIds = await storageManager.getProtectedDataIds();

        // Assert
        expect(protectedIds, contains('recent'));
        expect(protectedIds, isNot(contains('old')));
      });
    });

    group('trackDataAccess', () {
      test('should track data access timestamp', () async {
        // Arrange
        when(mockPrefs.setInt(any, any)).thenAnswer((_) async => true);

        // Act
        await storageManager.trackDataAccess(
          'test_data_123',
          OfflineStorageManager.DataType.journalEntries,
        );

        // Assert
        verify(mockPrefs.setInt('access_journalEntries_test_data_123', any)).called(1);
      });

      test('should update timestamp on repeated access', () async {
        // Arrange
        when(mockPrefs.setInt(any, any)).thenAnswer((_) async => true);

        // Act
        await storageManager.trackDataAccess('data_123', OfflineStorageManager.DataType.animals);
        await Future.delayed(Duration(milliseconds: 10));
        await storageManager.trackDataAccess('data_123', OfflineStorageManager.DataType.animals);

        // Assert
        verify(mockPrefs.setInt('access_animals_data_123', any)).called(2);
      });
    });

    group('getUserStorageInfo', () {
      test('should calculate user-specific storage', () async {
        // Arrange
        const userId = 'user_123';
        _setupUserStorageMocks(userId);

        // Act
        final userInfo = await storageManager.getUserStorageInfo(userId);

        // Assert
        expect(userInfo.userId, equals(userId));
        expect(userInfo.totalSize, greaterThan(0));
        expect(userInfo.isMinor, isFalse);
        expect(userInfo.dataRetentionDays, equals(365));
      });

      test('should apply COPPA restrictions for minors', () async {
        // Arrange
        const userId = 'minor_user_123';
        final minorBirthDate = DateTime.now().subtract(Duration(days: 365 * 10)); // 10 years old
        
        when(mockPrefs.getString('user_birth_date_$userId'))
            .thenReturn(minorBirthDate.toIso8601String());
        when(mockPrefs.getKeys()).thenReturn({});
        when(mockPrefs.getInt('quota_total')).thenReturn(totalLimit);

        // Act
        final userInfo = await storageManager.getUserStorageInfo(userId);

        // Assert
        expect(userInfo.isMinor, isTrue);
        expect(userInfo.dataRetentionDays, equals(30));
        expect(userInfo.totalQuota, lessThan(totalLimit)); // Should apply stricter limit
        expect(userInfo.totalQuota, equals(25 * 1024 * 1024)); // 25MB for minors
      });

      test('should handle users without birth date', () async {
        // Arrange
        const userId = 'unknown_age_user';
        when(mockPrefs.getString('user_birth_date_$userId')).thenReturn(null);
        when(mockPrefs.getKeys()).thenReturn({});

        // Act
        final userInfo = await storageManager.getUserStorageInfo(userId);

        // Assert
        expect(userInfo.isMinor, isFalse);
        expect(userInfo.dataRetentionDays, equals(365));
      });
    });

    group('clearUserData', () {
      test('should remove all user-specific data', () async {
        // Arrange
        const userId = 'user_to_clear';
        when(mockPrefs.getKeys()).thenReturn({
          'journal_entry_${userId}_1',
          'animal_${userId}_1',
          'other_data_123',
          'user_birth_date_$userId',
        });
        when(mockPrefs.remove(any)).thenAnswer((_) async => true);

        final userPhotosDir = MockDirectory();
        final userCacheDir = MockDirectory();
        when(userPhotosDir.exists()).thenAnswer((_) async => true);
        when(userCacheDir.exists()).thenAnswer((_) async => true);
        when(userPhotosDir.delete(recursive: true)).thenAnswer((_) async {});
        when(userCacheDir.delete(recursive: true)).thenAnswer((_) async {});

        // Act
        await storageManager.clearUserData(userId);

        // Assert
        verify(mockPrefs.remove('journal_entry_${userId}_1')).called(1);
        verify(mockPrefs.remove('animal_${userId}_1')).called(1);
        verify(mockPrefs.remove('user_birth_date_$userId')).called(1);
        verifyNever(mockPrefs.remove('other_data_123')); // Should not remove other user's data
      });

      test('should handle missing user directories gracefully', () async {
        // Arrange
        const userId = 'user_with_no_files';
        when(mockPrefs.getKeys()).thenReturn({});

        // Act & Assert - Should not throw
        await expectLater(
          storageManager.clearUserData(userId),
          completes,
        );
      });
    });

    group('getCleanupRecommendations', () {
      test('should recommend cache cleanup for large caches', () async {
        // Arrange
        _setupLowUsageStorageMocks();
        _setupLargeCacheMocks();

        // Act
        final recommendations = await storageManager.getCleanupRecommendations();

        // Assert
        expect(recommendations, isNotEmpty);
        expect(
          recommendations.any((r) => r.type == 'cache'),
          isTrue,
        );
      });

      test('should recommend photo compression when photos exceed 70% quota', () async {
        // Arrange
        _setupLowUsageStorageMocks();
        _setupHighPhotoUsageMocks();

        // Act
        final recommendations = await storageManager.getCleanupRecommendations();

        // Assert
        expect(
          recommendations.any((r) => r.type == 'photos'),
          isTrue,
        );
        final photoRec = recommendations.firstWhere((r) => r.type == 'photos');
        expect(photoRec.impact, equals(CleanupImpact.medium));
      });

      test('should recommend archival for old data', () async {
        // Arrange
        _setupLowUsageStorageMocks();
        _setupOldDataMocks();

        // Act
        final recommendations = await storageManager.getCleanupRecommendations();

        // Assert
        expect(
          recommendations.any((r) => r.type == 'archive'),
          isTrue,
        );
        final archiveRec = recommendations.firstWhere((r) => r.type == 'archive');
        expect(archiveRec.impact, equals(CleanupImpact.low));
      });

      test('should return empty recommendations when all is optimal', () async {
        // Arrange
        _setupOptimalStorageMocks();

        // Act
        final recommendations = await storageManager.getCleanupRecommendations();

        // Assert
        expect(recommendations, isEmpty);
      });
    });

    group('Edge Cases and Error Handling', () {
      test('should handle file system errors gracefully', () async {
        // Arrange
        when(mockPhotosDir.exists()).thenThrow(const FileSystemException('Access denied'));
        when(mockCacheDir.exists()).thenThrow(const FileSystemException('Access denied'));
        _setupBasicMocks();

        // Act & Assert - Should not throw
        final stats = await storageManager.getStorageStats();
        expect(stats.photosSize, equals(0));
        expect(stats.tempCacheSize, equals(0));
      });

      test('should handle SharedPreferences errors', () async {
        // Arrange
        when(mockPrefs.getString(any)).thenThrow(Exception('Preferences error'));
        when(mockPrefs.getKeys()).thenReturn(<String>{});

        // Act & Assert - Should handle gracefully
        final stats = await storageManager.getStorageStats();
        expect(stats, isNotNull);
      });

      test('should handle corrupted data in preferences', () async {
        // Arrange
        when(mockPrefs.getString('journal_entry_corrupted')).thenReturn('invalid_json');
        when(mockPrefs.getKeys()).thenReturn({'journal_entry_corrupted'});
        when(mockPrefs.getInt(any)).thenReturn(totalLimit);

        // Act & Assert - Should skip corrupted data
        final stats = await storageManager.getStorageStats();
        expect(stats, isNotNull);
      });
    });
  });
}

// Helper methods to setup various mock scenarios

void _setupStorageStatsMocks() {
  final mockPrefs = MockSharedPreferences();
  when(mockPrefs.getInt('quota_total')).thenReturn(100 * 1024 * 1024);
  when(mockPrefs.getInt('quota_photos')).thenReturn(50 * 1024 * 1024);
  when(mockPrefs.getInt('quota_data')).thenReturn(30 * 1024 * 1024);
  when(mockPrefs.getInt('quota_cache')).thenReturn(20 * 1024 * 1024);
  when(mockPrefs.getKeys()).thenReturn({'journal_entry_1', 'animal_1'});
  when(mockPrefs.getString('journal_entry_1')).thenReturn('x' * 1024);
  when(mockPrefs.getString('animal_1')).thenReturn('x' * 512);
}

void _setupHighUsageStorageMocks() {
  final mockPrefs = MockSharedPreferences();
  when(mockPrefs.getInt('quota_total')).thenReturn(100 * 1024 * 1024);
  when(mockPrefs.getInt('quota_photos')).thenReturn(50 * 1024 * 1024);
  when(mockPrefs.getInt('quota_data')).thenReturn(30 * 1024 * 1024);
  when(mockPrefs.getInt('quota_cache')).thenReturn(20 * 1024 * 1024);
  
  // Mock high usage (95% of total quota)
  final highUsageData = 'x' * (95 * 1024 * 1024); // 95MB
  when(mockPrefs.getKeys()).thenReturn({'large_entry'});
  when(mockPrefs.getString('large_entry')).thenReturn(highUsageData);
}

void _setupWarningLevelStorageMocks() {
  final mockPrefs = MockSharedPreferences();
  when(mockPrefs.getInt('quota_total')).thenReturn(100 * 1024 * 1024);
  when(mockPrefs.getInt('quota_photos')).thenReturn(50 * 1024 * 1024);
  when(mockPrefs.getInt('quota_data')).thenReturn(30 * 1024 * 1024);
  when(mockPrefs.getInt('quota_cache')).thenReturn(20 * 1024 * 1024);
  
  // Mock warning level usage (85% of total quota)
  final warningData = 'x' * (85 * 1024 * 1024); // 85MB
  when(mockPrefs.getKeys()).thenReturn({'warning_entry'});
  when(mockPrefs.getString('warning_entry')).thenReturn(warningData);
}

void _setupLowUsageStorageMocks() {
  final mockPrefs = MockSharedPreferences();
  when(mockPrefs.getInt('quota_total')).thenReturn(100 * 1024 * 1024);
  when(mockPrefs.getInt('quota_photos')).thenReturn(50 * 1024 * 1024);
  when(mockPrefs.getInt('quota_data')).thenReturn(30 * 1024 * 1024);
  when(mockPrefs.getInt('quota_cache')).thenReturn(20 * 1024 * 1024);
  when(mockPrefs.getKeys()).thenReturn({'small_entry'});
  when(mockPrefs.getString('small_entry')).thenReturn('x' * 1024); // 1KB
}

void _setupCleanupMocks() {
  final mockPrefs = MockSharedPreferences();
  when(mockPrefs.getKeys()).thenReturn({
    'cache_item_1', 'journal_entry_old', 'access_journalEntries_old_entry'
  });
  when(mockPrefs.getString('cache_item_1')).thenReturn('cache_data');
  when(mockPrefs.getString('journal_entry_old')).thenReturn('old_journal_data');
  when(mockPrefs.getInt('access_journalEntries_old_entry')).thenReturn(
    DateTime.now().subtract(Duration(days: 90)).millisecondsSinceEpoch
  );
  when(mockPrefs.remove(any)).thenAnswer((_) async => true);
  when(mockPrefs.setString(any, any)).thenAnswer((_) async => true);
  when(mockPrefs.setInt(any, any)).thenAnswer((_) async => true);
  when(mockPrefs.getStringList(any)).thenReturn([]);
}

void _setupCacheCleanupMocks() {
  final mockCacheDir = MockDirectory();
  final mockCacheFile = MockFile();
  
  when(mockCacheDir.exists()).thenAnswer((_) async => true);
  when(mockCacheDir.list()).thenAnswer((_) => Stream.fromIterable([mockCacheFile]));
  when(mockCacheFile.length()).thenAnswer((_) async => 1024);
  when(mockCacheFile.delete()).thenAnswer((_) async {});
  
  final mockPrefs = MockSharedPreferences();
  when(mockPrefs.getKeys()).thenReturn({'cache_key_1'});
  when(mockPrefs.getString('cache_key_1')).thenReturn('cached_data');
  when(mockPrefs.remove('cache_key_1')).thenAnswer((_) async => true);
}

void _setupPhotoCompressionMocks() {
  final mockPhotosDir = MockDirectory();
  final mockPhotoFile = MockFile();
  final mockFileStat = MockFileStat();
  
  when(mockPhotosDir.exists()).thenAnswer((_) async => true);
  when(mockPhotosDir.list()).thenAnswer((_) => Stream.fromIterable([mockPhotoFile]));
  when(mockPhotoFile.stat()).thenAnswer((_) async => mockFileStat);
  when(mockFileStat.modified).thenReturn(
    DateTime.now().subtract(Duration(days: 60))
  );
  when(mockPhotoFile.length()).thenAnswer((_) async => 1024 * 1024); // 1MB
  when(mockPhotoFile.path).thenReturn('/test/photo.jpg');
  
  final mockPrefs = MockSharedPreferences();
  when(mockPrefs.setBool(any, any)).thenAnswer((_) async => true);
}

void _setupJournalArchiveMocks() {
  final mockPrefs = MockSharedPreferences();
  when(mockPrefs.getKeys()).thenReturn({
    'journal_entry_old_1', 'journal_entry_old_2'
  });
  when(mockPrefs.getString('journal_entry_old_1')).thenReturn('old_journal_1');
  when(mockPrefs.getString('journal_entry_old_2')).thenReturn('old_journal_2');
  when(mockPrefs.getInt(any)).thenReturn(
    DateTime.now().subtract(Duration(days: 120)).millisecondsSinceEpoch
  );
  when(mockPrefs.setString(any, any)).thenAnswer((_) async => true);
  when(mockPrefs.remove(any)).thenAnswer((_) async => true);
  when(mockPrefs.getStringList(any)).thenReturn([]);
}

void _setupUserStorageMocks(String userId) {
  final mockPrefs = MockSharedPreferences();
  when(mockPrefs.getKeys()).thenReturn({
    'journal_entry_${userId}_1',
    'animal_${userId}_1',
    'other_user_data',
  });
  when(mockPrefs.getString('journal_entry_${userId}_1')).thenReturn('user_journal');
  when(mockPrefs.getString('animal_${userId}_1')).thenReturn('user_animal');
  when(mockPrefs.getString('user_birth_date_$userId')).thenReturn(null);
}

void _setupLargeCacheMocks() {
  final mockPrefs = MockSharedPreferences();
  when(mockPrefs.getInt('quota_cache')).thenReturn(20 * 1024 * 1024);
  
  final mockCacheDir = MockDirectory();
  final mockLargeCache = MockFile();
  when(mockCacheDir.exists()).thenAnswer((_) async => true);
  when(mockCacheDir.list()).thenAnswer((_) => Stream.fromIterable([mockLargeCache]));
  when(mockLargeCache.length()).thenAnswer((_) async => 6 * 1024 * 1024); // 6MB cache
}

void _setupHighPhotoUsageMocks() {
  final mockPhotosDir = MockDirectory();
  final mockPhotoFile = MockFile();
  
  when(mockPhotosDir.exists()).thenAnswer((_) async => true);
  when(mockPhotosDir.list()).thenAnswer((_) => Stream.fromIterable([mockPhotoFile]));
  when(mockPhotoFile.length()).thenAnswer((_) async => 40 * 1024 * 1024); // 40MB photos
}

void _setupOldDataMocks() {
  final mockPrefs = MockSharedPreferences();
  when(mockPrefs.getKeys()).thenReturn({
    'journal_entry_old_1', 'journal_entry_old_2'
  });
  when(mockPrefs.getString('journal_entry_old_1')).thenReturn('x' * (6 * 1024 * 1024));
  when(mockPrefs.getString('journal_entry_old_2')).thenReturn('x' * (5 * 1024 * 1024));
  when(mockPrefs.getInt(any)).thenReturn(
    DateTime.now().subtract(Duration(days: 120)).millisecondsSinceEpoch
  );
}

void _setupOptimalStorageMocks() {
  final mockPrefs = MockSharedPreferences();
  when(mockPrefs.getInt('quota_total')).thenReturn(100 * 1024 * 1024);
  when(mockPrefs.getInt('quota_photos')).thenReturn(50 * 1024 * 1024);
  when(mockPrefs.getKeys()).thenReturn({'small_entry'});
  when(mockPrefs.getString('small_entry')).thenReturn('x' * 1024); // 1KB only
  
  // Small cache and photos
  final mockCacheDir = MockDirectory();
  final mockPhotosDir = MockDirectory();
  when(mockCacheDir.exists()).thenAnswer((_) async => false);
  when(mockPhotosDir.exists()).thenAnswer((_) async => false);
}

void _setupBasicMocks() {
  final mockPrefs = MockSharedPreferences();
  when(mockPrefs.getInt(any)).thenReturn(100 * 1024 * 1024);
  when(mockPrefs.getKeys()).thenReturn({});
}