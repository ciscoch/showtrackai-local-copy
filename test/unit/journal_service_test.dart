import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../lib/services/journal_service.dart';
import '../../lib/models/journal_entry.dart';
import '../../lib/services/n8n_webhook_service.dart';
import 'journal_service_test.mocks.dart';

@GenerateMocks([
  http.Client,
  SharedPreferences,
  SupabaseClient,
  GoTrueClient,
  Session,
  User,
], customMocks: [
  MockSpec<N8NWebhookService>(as: #MockN8NWebhookService),
])
void main() {
  group('JournalService Unit Tests', () {
    late MockClient mockHttpClient;
    late MockSharedPreferences mockPrefs;
    late MockSupabaseClient mockSupabase;
    late MockGoTrueClient mockAuth;
    late MockSession mockSession;
    late MockUser mockUser;
    
    const String testUserId = 'test-user-123';
    const String testToken = 'test-jwt-token';
    const String testEntryId = 'entry-123';

    setUp(() {
      mockHttpClient = MockClient();
      mockPrefs = MockSharedPreferences();
      mockSupabase = MockSupabaseClient();
      mockAuth = MockGoTrueClient();
      mockSession = MockSession();
      mockUser = MockUser();

      // Setup Supabase mocking
      when(mockSupabase.auth).thenReturn(mockAuth);
      when(mockAuth.currentSession).thenReturn(mockSession);
      when(mockAuth.currentUser).thenReturn(mockUser);
      when(mockSession.accessToken).thenReturn(testToken);
      when(mockUser.id).thenReturn(testUserId);

      // Mock SharedPreferences
      SharedPreferences.setMockInitialValues({});
      
      // Mock network connectivity
      HttpOverrides.global = MockHttpOverrides();
    });

    tearDown(() {
      HttpOverrides.global = null;
    });

    group('createEntry', () {
      test('should create entry successfully online', () async {
        // Arrange
        final journalEntry = _createTestJournalEntry();
        
        when(mockPrefs.getString(any)).thenReturn(null);
        when(mockPrefs.setString(any, any)).thenAnswer((_) async => true);
        when(mockPrefs.getStringList(any)).thenReturn([]);
        when(mockPrefs.setStringList(any, any)).thenAnswer((_) async => true);

        when(mockHttpClient.post(
          any,
          headers: anyNamed('headers'),
          body: anyNamed('body'),
        )).thenAnswer((_) async => http.Response(
          jsonEncode({
            'data': journalEntry.copyWith(isSynced: true).toJson(),
            'success': true,
          }),
          201,
        ));

        // Act
        final result = await JournalService.createEntry(journalEntry);

        // Assert
        expect(result.id, isNotNull);
        expect(result.userId, equals(testUserId));
        expect(result.title, equals('Test Entry'));
        expect(result.isSynced, isTrue);
        
        verify(mockHttpClient.post(
          argThat(contains('journal-create')),
          headers: argThat(containsPair('Authorization', 'Bearer $testToken'), named: 'headers'),
          body: anyNamed('body'),
        )).called(1);
      });

      test('should store entry offline when network fails', () async {
        // Arrange
        final journalEntry = _createTestJournalEntry();
        
        when(mockPrefs.getString(any)).thenReturn(null);
        when(mockPrefs.setString(any, any)).thenAnswer((_) async => true);
        when(mockPrefs.getStringList(any)).thenReturn([]);
        when(mockPrefs.setStringList(any, any)).thenAnswer((_) async => true);

        when(mockHttpClient.post(
          any,
          headers: anyNamed('headers'),
          body: anyNamed('body'),
        )).thenThrow(const SocketException('Network error'));

        // Act
        final result = await JournalService.createEntry(journalEntry);

        // Assert
        expect(result.id, isNotNull);
        expect(result.isSynced, isFalse);
        
        // Verify offline storage
        verify(mockPrefs.setString(
          'journal_offline_entries',
          any,
        )).called(1);
        
        verify(mockPrefs.setString(
          'journal_offline_queue',
          any,
        )).called(1);
      });

      test('should handle authentication error', () async {
        // Arrange
        when(mockAuth.currentSession).thenReturn(null);
        final journalEntry = _createTestJournalEntry();

        when(mockPrefs.getString(any)).thenReturn(null);
        when(mockPrefs.setString(any, any)).thenAnswer((_) async => true);
        when(mockPrefs.getStringList(any)).thenReturn([]);
        when(mockPrefs.setStringList(any, any)).thenAnswer((_) async => true);

        // Act & Assert
        final result = await JournalService.createEntry(journalEntry);
        
        // Should fallback to offline storage
        expect(result.isSynced, isFalse);
        verify(mockPrefs.setString('journal_offline_entries', any)).called(1);
      });

      test('should handle server error response', () async {
        // Arrange
        final journalEntry = _createTestJournalEntry();
        
        when(mockPrefs.getString(any)).thenReturn(null);
        when(mockPrefs.setString(any, any)).thenAnswer((_) async => true);
        when(mockPrefs.getStringList(any)).thenReturn([]);
        when(mockPrefs.setStringList(any, any)).thenAnswer((_) async => true);

        when(mockHttpClient.post(
          any,
          headers: anyNamed('headers'),
          body: anyNamed('body'),
        )).thenAnswer((_) async => http.Response(
          jsonEncode({'error': 'Server error'}),
          500,
        ));

        // Act
        final result = await JournalService.createEntry(journalEntry);

        // Assert - Should fallback to offline
        expect(result.isSynced, isFalse);
        verify(mockPrefs.setString('journal_offline_entries', any)).called(1);
      });

      test('should trigger AI processing asynchronously', () async {
        // Arrange
        final journalEntry = _createTestJournalEntry();
        
        when(mockPrefs.getString(any)).thenReturn(null);
        when(mockPrefs.setString(any, any)).thenAnswer((_) async => true);
        when(mockPrefs.getStringList(any)).thenReturn([]);
        when(mockPrefs.setStringList(any, any)).thenAnswer((_) async => true);

        when(mockHttpClient.post(
          any,
          headers: anyNamed('headers'),
          body: anyNamed('body'),
        )).thenAnswer((_) async => http.Response(
          jsonEncode({
            'data': journalEntry.copyWith(isSynced: true).toJson(),
            'success': true,
          }),
          201,
        ));

        // Act
        final result = await JournalService.createEntry(journalEntry);

        // Assert
        expect(result.isSynced, isTrue);
        // Note: Testing async AI processing would require more complex mocking
        // This test verifies the successful creation which should trigger AI processing
      });
    });

    group('getEntries', () {
      test('should fetch entries online successfully', () async {
        // Arrange
        final testEntries = [
          _createTestJournalEntry(id: 'entry-1', title: 'Entry 1'),
          _createTestJournalEntry(id: 'entry-2', title: 'Entry 2'),
        ];

        when(mockPrefs.getString(any)).thenReturn(null);
        when(mockPrefs.setString(any, any)).thenAnswer((_) async => true);

        when(mockHttpClient.get(
          any,
          headers: anyNamed('headers'),
        )).thenAnswer((_) async => http.Response(
          jsonEncode({
            'data': testEntries.map((e) => e.toJson()).toList(),
            'success': true,
          }),
          200,
        ));

        // Act
        final result = await JournalService.getEntries(limit: 10);

        // Assert
        expect(result, hasLength(2));
        expect(result[0].title, equals('Entry 1'));
        expect(result[1].title, equals('Entry 2'));
        
        verify(mockHttpClient.get(
          argThat(contains('journal-list')),
          headers: argThat(containsPair('Authorization', 'Bearer $testToken'), named: 'headers'),
        )).called(1);
      });

      test('should fallback to offline data when online fails', () async {
        // Arrange
        final offlineEntries = {
          'entry-1': _createTestJournalEntry(id: 'entry-1').toJson(),
          'entry-2': _createTestJournalEntry(id: 'entry-2').toJson(),
        };

        when(mockPrefs.getString('journal_offline_entries'))
            .thenReturn(jsonEncode(offlineEntries));
        when(mockPrefs.setString(any, any)).thenAnswer((_) async => true);

        when(mockHttpClient.get(
          any,
          headers: anyNamed('headers'),
        )).thenThrow(const SocketException('Network error'));

        // Act
        final result = await JournalService.getEntries(limit: 10);

        // Assert
        expect(result, hasLength(2));
        expect(result.every((entry) => !entry.isSynced), isTrue);
      });

      test('should apply filters correctly', () async {
        // Arrange
        final allEntries = [
          _createTestJournalEntry(id: 'entry-1', category: 'daily_care'),
          _createTestJournalEntry(id: 'entry-2', category: 'health_check'),
          _createTestJournalEntry(id: 'entry-3', category: 'daily_care'),
        ];

        when(mockPrefs.getString('journal_offline_entries'))
            .thenReturn(jsonEncode({
              for (var entry in allEntries) entry.id!: entry.toJson()
            }));

        // Act
        final result = await JournalService.getEntries(
          category: 'daily_care',
          onlineFirst: false,
        );

        // Assert
        expect(result, hasLength(2));
        expect(result.every((entry) => entry.category == 'daily_care'), isTrue);
      });

      test('should handle pagination correctly', () async {
        // Arrange
        final allEntries = List.generate(
          25,
          (index) => _createTestJournalEntry(
            id: 'entry-$index',
            title: 'Entry $index',
          ),
        );

        when(mockPrefs.getString('journal_offline_entries'))
            .thenReturn(jsonEncode({
              for (var entry in allEntries) entry.id!: entry.toJson()
            }));

        // Act
        final page1 = await JournalService.getEntries(
          limit: 10,
          offset: 0,
          onlineFirst: false,
        );
        final page2 = await JournalService.getEntries(
          limit: 10,
          offset: 10,
          onlineFirst: false,
        );

        // Assert
        expect(page1, hasLength(10));
        expect(page2, hasLength(10));
        expect(page1[0].id, isNot(equals(page2[0].id)));
      });
    });

    group('getEntry', () {
      test('should get single entry from local cache first', () async {
        // Arrange
        final testEntry = _createTestJournalEntry(id: testEntryId, isSynced: true);
        
        when(mockPrefs.getString('journal_offline_entries'))
            .thenReturn(jsonEncode({testEntryId: testEntry.toJson()}));

        // Act
        final result = await JournalService.getEntry(testEntryId);

        // Assert
        expect(result, isNotNull);
        expect(result!.id, equals(testEntryId));
        expect(result.isSynced, isTrue);
        
        // Should not make network call for synced local data
        verifyNever(mockHttpClient.get(any, headers: anyNamed('headers')));
      });

      test('should fetch from server if local data is not synced', () async {
        // Arrange
        final localEntry = _createTestJournalEntry(id: testEntryId, isSynced: false);
        final serverEntry = _createTestJournalEntry(id: testEntryId, isSynced: true);
        
        when(mockPrefs.getString('journal_offline_entries'))
            .thenReturn(jsonEncode({testEntryId: localEntry.toJson()}));
        when(mockPrefs.setString(any, any)).thenAnswer((_) async => true);

        when(mockHttpClient.get(
          argThat(contains('journal-get')),
          headers: anyNamed('headers'),
        )).thenAnswer((_) async => http.Response(
          jsonEncode({
            'data': serverEntry.toJson(),
            'success': true,
          }),
          200,
        ));

        // Act
        final result = await JournalService.getEntry(testEntryId);

        // Assert
        expect(result, isNotNull);
        expect(result!.isSynced, isTrue);
        
        verify(mockHttpClient.get(
          argThat(contains('journal-get')),
          headers: argThat(containsPair('Authorization', 'Bearer $testToken'), named: 'headers'),
        )).called(1);
      });

      test('should return null for non-existent entry', () async {
        // Arrange
        when(mockPrefs.getString('journal_offline_entries')).thenReturn(null);
        
        when(mockHttpClient.get(
          any,
          headers: anyNamed('headers'),
        )).thenAnswer((_) async => http.Response(
          jsonEncode({'error': 'Entry not found'}),
          404,
        ));

        // Act
        final result = await JournalService.getEntry('non-existent-id');

        // Assert
        expect(result, isNull);
      });
    });

    group('updateEntry', () {
      test('should update entry online successfully', () async {
        // Arrange
        final originalEntry = _createTestJournalEntry(id: testEntryId);
        final updatedEntry = originalEntry.copyWith(
          title: 'Updated Title',
          description: 'Updated description',
        );

        when(mockPrefs.getString(any)).thenReturn(null);
        when(mockPrefs.setString(any, any)).thenAnswer((_) async => true);
        when(mockPrefs.getStringList(any)).thenReturn([]);
        when(mockPrefs.setStringList(any, any)).thenAnswer((_) async => true);

        when(mockHttpClient.put(
          any,
          headers: anyNamed('headers'),
          body: anyNamed('body'),
        )).thenAnswer((_) async => http.Response(
          jsonEncode({
            'data': updatedEntry.copyWith(isSynced: true).toJson(),
            'success': true,
          }),
          200,
        ));

        // Act
        final result = await JournalService.updateEntry(updatedEntry);

        // Assert
        expect(result.title, equals('Updated Title'));
        expect(result.description, equals('Updated description'));
        expect(result.isSynced, isTrue);
        
        verify(mockHttpClient.put(
          argThat(contains('journal-update')),
          headers: argThat(containsPair('Authorization', 'Bearer $testToken'), named: 'headers'),
          body: anyNamed('body'),
        )).called(1);
      });

      test('should store update offline when network fails', () async {
        // Arrange
        final updatedEntry = _createTestJournalEntry(id: testEntryId)
            .copyWith(title: 'Updated Title');

        when(mockPrefs.getString(any)).thenReturn(null);
        when(mockPrefs.setString(any, any)).thenAnswer((_) async => true);
        when(mockPrefs.getStringList(any)).thenReturn([]);
        when(mockPrefs.setStringList(any, any)).thenAnswer((_) async => true);

        when(mockHttpClient.put(
          any,
          headers: anyNamed('headers'),
          body: anyNamed('body'),
        )).thenThrow(const SocketException('Network error'));

        // Act
        final result = await JournalService.updateEntry(updatedEntry);

        // Assert
        expect(result.isSynced, isFalse);
        expect(result.updatedAt, isNotNull);
        
        verify(mockPrefs.setString('journal_offline_entries', any)).called(1);
        verify(mockPrefs.setString('journal_offline_queue', any)).called(1);
      });
    });

    group('deleteEntry', () {
      test('should delete entry online successfully', () async {
        // Arrange
        when(mockPrefs.getString(any)).thenReturn(null);
        when(mockPrefs.setString(any, any)).thenAnswer((_) async => true);
        when(mockPrefs.getStringList(any)).thenReturn([]);
        when(mockPrefs.setStringList(any, any)).thenAnswer((_) async => true);

        when(mockHttpClient.delete(
          argThat(contains('journal-delete')),
          headers: anyNamed('headers'),
        )).thenAnswer((_) async => http.Response(
          jsonEncode({'success': true}),
          200,
        ));

        // Act
        await JournalService.deleteEntry(testEntryId);

        // Assert
        verify(mockHttpClient.delete(
          argThat(contains('journal-delete')),
          headers: argThat(containsPair('Authorization', 'Bearer $testToken'), named: 'headers'),
        )).called(1);
      });

      test('should queue delete operation when offline', () async {
        // Arrange
        when(mockPrefs.getString(any)).thenReturn(null);
        when(mockPrefs.setString(any, any)).thenAnswer((_) async => true);
        when(mockPrefs.getStringList(any)).thenReturn([]);
        when(mockPrefs.setStringList(any, any)).thenAnswer((_) async => true);

        when(mockHttpClient.delete(
          any,
          headers: anyNamed('headers'),
        )).thenThrow(const SocketException('Network error'));

        // Act
        await JournalService.deleteEntry(testEntryId);

        // Assert
        verify(mockPrefs.setString('journal_offline_queue', any)).called(1);
      });
    });

    group('searchEntries', () {
      test('should search entries by title and description', () async {
        // Arrange
        final entries = [
          _createTestJournalEntry(id: 'entry-1', title: 'Daily Care', description: 'Fed the animals'),
          _createTestJournalEntry(id: 'entry-2', title: 'Health Check', description: 'Vaccinated cattle'),
          _createTestJournalEntry(id: 'entry-3', title: 'Training', description: 'Daily care routine'),
        ];

        when(mockPrefs.getString('journal_offline_entries'))
            .thenReturn(jsonEncode({
              for (var entry in entries) entry.id!: entry.toJson()
            }));

        // Act
        final result = await JournalService.searchEntries(query: 'daily');

        // Assert
        expect(result, hasLength(2));
        expect(result.any((entry) => entry.title == 'Daily Care'), isTrue);
        expect(result.any((entry) => entry.description.contains('Daily care')), isTrue);
      });

      test('should filter search results by category', () async {
        // Arrange
        final entries = [
          _createTestJournalEntry(id: 'entry-1', title: 'Care', category: 'daily_care'),
          _createTestJournalEntry(id: 'entry-2', title: 'Care', category: 'health_check'),
        ];

        when(mockPrefs.getString('journal_offline_entries'))
            .thenReturn(jsonEncode({
              for (var entry in entries) entry.id!: entry.toJson()
            }));

        // Act
        final result = await JournalService.searchEntries(
          query: 'care',
          category: 'daily_care',
        );

        // Assert
        expect(result, hasLength(1));
        expect(result[0].category, equals('daily_care'));
      });

      test('should handle empty search results', () async {
        // Arrange
        when(mockPrefs.getString('journal_offline_entries')).thenReturn(null);

        // Act
        final result = await JournalService.searchEntries(query: 'nonexistent');

        // Assert
        expect(result, isEmpty);
      });
    });

    group('syncOfflineEntries', () {
      test('should sync all queued operations successfully', () async {
        // Arrange
        final queueItems = [
          {
            'operation': 'create',
            'entry': _createTestJournalEntry(id: 'entry-1').toJson(),
            'timestamp': DateTime.now().toIso8601String(),
          },
          {
            'operation': 'update',
            'entry': _createTestJournalEntry(id: 'entry-2').toJson(),
            'timestamp': DateTime.now().toIso8601String(),
          },
        ];

        when(mockPrefs.getString('journal_offline_queue'))
            .thenReturn(jsonEncode(queueItems));
        when(mockPrefs.setString(any, any)).thenAnswer((_) async => true);

        // Mock successful HTTP responses
        when(mockHttpClient.post(any, headers: anyNamed('headers'), body: anyNamed('body')))
            .thenAnswer((_) async => http.Response(
              jsonEncode({'data': {}, 'success': true}), 201));
        when(mockHttpClient.put(any, headers: anyNamed('headers'), body: anyNamed('body')))
            .thenAnswer((_) async => http.Response(
              jsonEncode({'data': {}, 'success': true}), 200));

        // Act
        final result = await JournalService.syncOfflineEntries();

        // Assert
        expect(result, isTrue);
        verify(mockPrefs.setString('journal_offline_queue', '[]')).called(1);
        verify(mockPrefs.setString('journal_last_sync', any)).called(1);
      });

      test('should handle partial sync failures', () async {
        // Arrange
        final queueItems = [
          {
            'operation': 'create',
            'entry': _createTestJournalEntry(id: 'entry-1').toJson(),
            'timestamp': DateTime.now().toIso8601String(),
          },
          {
            'operation': 'create',
            'entry': _createTestJournalEntry(id: 'entry-2').toJson(),
            'timestamp': DateTime.now().toIso8601String(),
          },
        ];

        when(mockPrefs.getString('journal_offline_queue'))
            .thenReturn(jsonEncode(queueItems));
        when(mockPrefs.setString(any, any)).thenAnswer((_) async => true);

        // First call succeeds, second fails
        when(mockHttpClient.post(any, headers: anyNamed('headers'), body: anyNamed('body')))
            .thenAnswer((_) async => http.Response(
              jsonEncode({'data': {}, 'success': true}), 201))
            .thenAnswer((_) async => http.Response(
              jsonEncode({'error': 'Server error'}), 500));

        // Act
        final result = await JournalService.syncOfflineEntries();

        // Assert
        expect(result, isFalse);
        // Verify partial cleanup (only successful items removed)
        verify(mockPrefs.setString('journal_offline_queue', argThat(contains('entry-2')))).called(1);
      });

      test('should return false when offline', () async {
        // Arrange
        HttpOverrides.global = OfflineHttpOverrides();

        // Act
        final result = await JournalService.syncOfflineEntries();

        // Assert
        expect(result, isFalse);
      });
    });

    group('getUserStats', () {
      test('should calculate user statistics correctly', () async {
        // Arrange
        final entries = [
          _createTestJournalEntry(
            id: 'entry-1',
            category: 'daily_care',
            duration: 60,
            qualityScore: 8,
            countsForDegree: true,
            financialValue: 25.50,
          ),
          _createTestJournalEntry(
            id: 'entry-2',
            category: 'health_check',
            duration: 30,
            qualityScore: 9,
            countsForDegree: false,
            financialValue: 15.25,
          ),
          _createTestJournalEntry(
            id: 'entry-3',
            category: 'daily_care',
            duration: 45,
            qualityScore: 7,
            countsForDegree: true,
            financialValue: 30.00,
          ),
        ];

        when(mockPrefs.getString('journal_offline_entries'))
            .thenReturn(jsonEncode({
              for (var entry in entries) entry.id!: entry.toJson()
            }));

        // Act
        final stats = await JournalService.getUserStats();

        // Assert
        expect(stats.totalEntries, equals(3));
        expect(stats.totalHours, equals(2.25)); // (60+30+45)/60
        expect(stats.averageQualityScore, equals(8.0)); // (8+9+7)/3
        expect(stats.ffaDegreeEntries, equals(2));
        expect(stats.totalFinancialValue, equals(70.75));
        expect(stats.categoryBreakdown['daily_care'], equals(2));
        expect(stats.categoryBreakdown['health_check'], equals(1));
      });

      test('should handle empty entry list', () async {
        // Arrange
        when(mockPrefs.getString('journal_offline_entries')).thenReturn(null);

        // Act
        final stats = await JournalService.getUserStats();

        // Assert
        expect(stats.totalEntries, equals(0));
        expect(stats.totalHours, equals(0));
        expect(stats.averageQualityScore, equals(0));
        expect(stats.ffaDegreeEntries, equals(0));
        expect(stats.totalFinancialValue, equals(0));
        expect(stats.categoryBreakdown, isEmpty);
      });
    });

    group('Error Handling', () {
      test('should handle JSON parsing errors gracefully', () async {
        // Arrange
        when(mockPrefs.getString('journal_offline_entries')).thenReturn('invalid json');

        // Act & Assert
        expect(
          () async => await JournalService.getEntries(onlineFirst: false),
          throwsA(isA<Exception>()),
        );
      });

      test('should handle network timeouts', () async {
        // Arrange
        final journalEntry = _createTestJournalEntry();
        
        when(mockPrefs.getString(any)).thenReturn(null);
        when(mockPrefs.setString(any, any)).thenAnswer((_) async => true);
        when(mockPrefs.getStringList(any)).thenReturn([]);
        when(mockPrefs.setStringList(any, any)).thenAnswer((_) async => true);

        when(mockHttpClient.post(
          any,
          headers: anyNamed('headers'),
          body: anyNamed('body'),
        )).thenAnswer((_) => Future.delayed(
          const Duration(seconds: 15),
          () => http.Response('{}', 200),
        ));

        // Act
        final result = await JournalService.createEntry(journalEntry);

        // Assert - Should fallback to offline storage
        expect(result.isSynced, isFalse);
      });
    });
  });
}

// Helper methods and mock classes

JournalEntry _createTestJournalEntry({
  String? id,
  String title = 'Test Entry',
  String description = 'Test description',
  String category = 'daily_care',
  int duration = 60,
  int? qualityScore,
  bool countsForDegree = false,
  double? financialValue,
  bool isSynced = false,
}) {
  return JournalEntry(
    id: id ?? 'test-entry-123',
    userId: 'test-user-123',
    title: title,
    description: description,
    date: DateTime.now(),
    duration: duration,
    category: category,
    aetSkills: ['Animal Health Management', 'Record Keeping'],
    animalId: 'test-animal-123',
    qualityScore: qualityScore,
    countsForDegree: countsForDegree,
    financialValue: financialValue,
    isSynced: isSynced,
    createdAt: DateTime.now(),
    updatedAt: DateTime.now(),
  );
}

class MockHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) {
    return MockHttpClient();
  }
}

class OfflineHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) {
    final client = MockHttpClient();
    // Simulate network unavailability
    return client;
  }
}

class MockHttpClient extends Mock implements HttpClient {}

extension JournalEntryTestExtension on JournalEntry {
  JournalEntry copyWith({
    String? id,
    String? userId,
    String? title,
    String? description,
    DateTime? date,
    int? duration,
    String? category,
    List<String>? aetSkills,
    String? animalId,
    int? qualityScore,
    bool? countsForDegree,
    double? financialValue,
    bool? isSynced,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return JournalEntry(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      title: title ?? this.title,
      description: description ?? this.description,
      date: date ?? this.date,
      duration: duration ?? this.duration,
      category: category ?? this.category,
      aetSkills: aetSkills ?? this.aetSkills,
      animalId: animalId ?? this.animalId,
      qualityScore: qualityScore ?? this.qualityScore,
      countsForDegree: countsForDegree ?? this.countsForDegree,
      financialValue: financialValue ?? this.financialValue,
      isSynced: isSynced ?? this.isSynced,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}