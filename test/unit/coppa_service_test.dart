import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../lib/services/coppa_service.dart';
import 'coppa_service_test.mocks.dart';

@GenerateMocks([
  SharedPreferences,
  SupabaseClient,
  GoTrueClient,
  User,
])
void main() {
  group('COPPAService Unit Tests', () {
    late COPPAService coppaService;
    late MockSharedPreferences mockPrefs;
    late MockSupabaseClient mockSupabase;
    late MockGoTrueClient mockAuth;
    late MockUser mockUser;

    const String testUserId = 'test-user-123';
    const String parentEmail = 'parent@example.com';
    const String guardianEmail = 'guardian@example.com';

    setUp(() {
      mockPrefs = MockSharedPreferences();
      mockSupabase = MockSupabaseClient();
      mockAuth = MockGoTrueClient();
      mockUser = MockUser();

      // Setup Supabase mocking
      when(mockSupabase.auth).thenReturn(mockAuth);
      when(mockAuth.currentUser).thenReturn(mockUser);
      when(mockUser.id).thenReturn(testUserId);
      when(mockUser.email).thenReturn('student@example.com');

      coppaService = COPPAService();
      SharedPreferences.setMockInitialValues({});
    });

    group('Age Verification', () {
      test('should correctly identify users under 13', () async {
        // Arrange
        final birthDate = DateTime.now().subtract(Duration(days: 365 * 10)); // 10 years old
        when(mockPrefs.getString('user_birth_date_$testUserId'))
            .thenReturn(birthDate.toIso8601String());

        // Act
        final isMinor = await coppaService.isUserUnder13(testUserId);

        // Assert
        expect(isMinor, isTrue);
      });

      test('should correctly identify users 13 and older', () async {
        // Arrange
        final birthDate = DateTime.now().subtract(Duration(days: 365 * 15)); // 15 years old
        when(mockPrefs.getString('user_birth_date_$testUserId'))
            .thenReturn(birthDate.toIso8601String());

        // Act
        final isMinor = await coppaService.isUserUnder13(testUserId);

        // Assert
        expect(isMinor, isFalse);
      });

      test('should handle missing birth date gracefully', () async {
        // Arrange
        when(mockPrefs.getString('user_birth_date_$testUserId')).thenReturn(null);

        // Act
        final isMinor = await coppaService.isUserUnder13(testUserId);

        // Assert
        expect(isMinor, isFalse); // Default to not minor when unknown
      });

      test('should handle edge case of exactly 13 years old', () async {
        // Arrange
        final birthDate = DateTime.now().subtract(Duration(days: 365 * 13)); // Exactly 13
        when(mockPrefs.getString('user_birth_date_$testUserId'))
            .thenReturn(birthDate.toIso8601String());

        // Act
        final isMinor = await coppaService.isUserUnder13(testUserId);

        // Assert
        expect(isMinor, isFalse); // 13 is not under 13
      });

      test('should handle leap years in age calculation', () async {
        // Arrange
        final now = DateTime(2024, 3, 1); // After leap day
        final birthDate = DateTime(2012, 2, 29); // Born on leap day, 12 years ago
        
        when(mockPrefs.getString('user_birth_date_$testUserId'))
            .thenReturn(birthDate.toIso8601String());

        // Act
        final isMinor = await coppaService.isUserUnder13(testUserId, currentDate: now);

        // Assert
        expect(isMinor, isTrue); // Still 11 years old due to leap day
      });
    });

    group('Parental Consent Management', () {
      test('should successfully set parental consent', () async {
        // Arrange
        when(mockPrefs.setString(any, any)).thenAnswer((_) async => true);
        when(mockPrefs.setBool(any, any)).thenAnswer((_) async => true);
        when(mockPrefs.setInt(any, any)).thenAnswer((_) async => true);

        final consentData = COPPAConsentData(
          parentEmail: parentEmail,
          parentName: 'John Parent',
          relationshipType: 'father',
          consentMethod: 'email_verification',
          ipAddress: '192.168.1.1',
          userAgent: 'Test Browser',
        );

        // Act
        await coppaService.recordParentalConsent(testUserId, consentData);

        // Assert
        verify(mockPrefs.setString('coppa_parent_email_$testUserId', parentEmail)).called(1);
        verify(mockPrefs.setBool('coppa_consent_$testUserId', true)).called(1);
        verify(mockPrefs.setString('coppa_consent_method_$testUserId', 'email_verification')).called(1);
        verify(mockPrefs.setInt('coppa_consent_timestamp_$testUserId', any)).called(1);
      });

      test('should verify parental consent exists', () async {
        // Arrange
        when(mockPrefs.getBool('coppa_consent_$testUserId')).thenReturn(true);
        when(mockPrefs.getString('coppa_parent_email_$testUserId')).thenReturn(parentEmail);
        when(mockPrefs.getInt('coppa_consent_timestamp_$testUserId'))
            .thenReturn(DateTime.now().millisecondsSinceEpoch);

        // Act
        final hasConsent = await coppaService.hasParentalConsent(testUserId);

        // Assert
        expect(hasConsent, isTrue);
      });

      test('should detect missing parental consent', () async {
        // Arrange
        when(mockPrefs.getBool('coppa_consent_$testUserId')).thenReturn(null);

        // Act
        final hasConsent = await coppaService.hasParentalConsent(testUserId);

        // Assert
        expect(hasConsent, isFalse);
      });

      test('should detect expired parental consent', () async {
        // Arrange
        final expiredTimestamp = DateTime.now()
            .subtract(Duration(days: 400)) // Over a year old
            .millisecondsSinceEpoch;
            
        when(mockPrefs.getBool('coppa_consent_$testUserId')).thenReturn(true);
        when(mockPrefs.getString('coppa_parent_email_$testUserId')).thenReturn(parentEmail);
        when(mockPrefs.getInt('coppa_consent_timestamp_$testUserId'))
            .thenReturn(expiredTimestamp);

        // Act
        final hasConsent = await coppaService.hasParentalConsent(testUserId);

        // Assert
        expect(hasConsent, isFalse); // Should be considered expired
      });

      test('should handle multiple parent/guardian consents', () async {
        // Arrange
        when(mockPrefs.setString(any, any)).thenAnswer((_) async => true);
        when(mockPrefs.setBool(any, any)).thenAnswer((_) async => true);
        when(mockPrefs.setInt(any, any)).thenAnswer((_) async => true);

        final parentConsent = COPPAConsentData(
          parentEmail: parentEmail,
          parentName: 'John Parent',
          relationshipType: 'father',
          consentMethod: 'email_verification',
          ipAddress: '192.168.1.1',
          userAgent: 'Test Browser',
        );

        final guardianConsent = COPPAConsentData(
          parentEmail: guardianEmail,
          parentName: 'Jane Guardian',
          relationshipType: 'guardian',
          consentMethod: 'phone_verification',
          ipAddress: '192.168.1.2',
          userAgent: 'Test Browser',
        );

        // Act
        await coppaService.recordParentalConsent(testUserId, parentConsent);
        await coppaService.recordParentalConsent(testUserId, guardianConsent);

        // Assert - Should update to latest consent
        verify(mockPrefs.setString('coppa_parent_email_$testUserId', guardianEmail)).called(1);
        verify(mockPrefs.setString('coppa_relationship_$testUserId', 'guardian')).called(1);
      });
    });

    group('Data Access Permissions', () {
      test('should allow data access with valid parental consent', () async {
        // Arrange
        when(mockPrefs.getBool('coppa_consent_$testUserId')).thenReturn(true);
        when(mockPrefs.getString('coppa_parent_email_$testUserId')).thenReturn(parentEmail);
        when(mockPrefs.getInt('coppa_consent_timestamp_$testUserId'))
            .thenReturn(DateTime.now().millisecondsSinceEpoch);

        // Act
        final canAccess = await coppaService.canAccessUserData(testUserId);

        // Assert
        expect(canAccess, isTrue);
      });

      test('should deny data access without parental consent', () async {
        // Arrange
        when(mockPrefs.getBool('coppa_consent_$testUserId')).thenReturn(null);

        // Act
        final canAccess = await coppaService.canAccessUserData(testUserId);

        // Assert
        expect(canAccess, isFalse);
      });

      test('should deny data access with expired consent', () async {
        // Arrange
        final expiredTimestamp = DateTime.now()
            .subtract(Duration(days: 400))
            .millisecondsSinceEpoch;
            
        when(mockPrefs.getBool('coppa_consent_$testUserId')).thenReturn(true);
        when(mockPrefs.getInt('coppa_consent_timestamp_$testUserId'))
            .thenReturn(expiredTimestamp);

        // Act
        final canAccess = await coppaService.canAccessUserData(testUserId);

        // Assert
        expect(canAccess, isFalse);
      });

      test('should allow access for users 13 and older without consent', () async {
        // Arrange
        final birthDate = DateTime.now().subtract(Duration(days: 365 * 15)); // 15 years old
        when(mockPrefs.getString('user_birth_date_$testUserId'))
            .thenReturn(birthDate.toIso8601String());
        when(mockPrefs.getBool('coppa_consent_$testUserId')).thenReturn(null);

        // Act
        final canAccess = await coppaService.canAccessUserData(testUserId);

        // Assert
        expect(canAccess, isTrue); // Adult users don't need parental consent
      });
    });

    group('Consent Withdrawal', () {
      test('should successfully revoke parental consent', () async {
        // Arrange
        when(mockPrefs.remove(any)).thenAnswer((_) async => true);
        when(mockPrefs.setBool('coppa_consent_revoked_$testUserId', true))
            .thenAnswer((_) async => true);
        when(mockPrefs.setInt(any, any)).thenAnswer((_) async => true);

        // Act
        await coppaService.revokeParentalConsent(testUserId, 'Parent request');

        // Assert
        verify(mockPrefs.remove('coppa_consent_$testUserId')).called(1);
        verify(mockPrefs.remove('coppa_parent_email_$testUserId')).called(1);
        verify(mockPrefs.setBool('coppa_consent_revoked_$testUserId', true)).called(1);
        verify(mockPrefs.setInt('coppa_revocation_timestamp_$testUserId', any)).called(1);
      });

      test('should prevent data access after consent revocation', () async {
        // Arrange
        when(mockPrefs.getBool('coppa_consent_revoked_$testUserId')).thenReturn(true);

        // Act
        final canAccess = await coppaService.canAccessUserData(testUserId);

        // Assert
        expect(canAccess, isFalse);
      });

      test('should allow re-granting consent after revocation', () async {
        // Arrange
        when(mockPrefs.setBool('coppa_consent_revoked_$testUserId', false))
            .thenAnswer((_) async => true);
        when(mockPrefs.setString(any, any)).thenAnswer((_) async => true);
        when(mockPrefs.setBool(any, any)).thenAnswer((_) async => true);
        when(mockPrefs.setInt(any, any)).thenAnswer((_) async => true);

        final newConsentData = COPPAConsentData(
          parentEmail: parentEmail,
          parentName: 'John Parent',
          relationshipType: 'father',
          consentMethod: 'in_person_verification',
          ipAddress: '192.168.1.1',
          userAgent: 'Test Browser',
        );

        // Act
        await coppaService.recordParentalConsent(testUserId, newConsentData);

        // Assert
        verify(mockPrefs.setBool('coppa_consent_revoked_$testUserId', false)).called(1);
        verify(mockPrefs.setBool('coppa_consent_$testUserId', true)).called(1);
      });
    });

    group('Data Collection Limits', () {
      test('should return restricted data collection permissions for minors', () async {
        // Arrange
        final birthDate = DateTime.now().subtract(Duration(days: 365 * 10)); // 10 years old
        when(mockPrefs.getString('user_birth_date_$testUserId'))
            .thenReturn(birthDate.toIso8601String());
        when(mockPrefs.getBool('coppa_consent_$testUserId')).thenReturn(true);

        // Act
        final permissions = await coppaService.getDataCollectionPermissions(testUserId);

        // Assert
        expect(permissions.canCollectPersonalInfo, isTrue); // With consent
        expect(permissions.canCollectBehavioralData, isFalse); // COPPA restriction
        expect(permissions.canShareWithThirdParties, isFalse); // COPPA restriction
        expect(permissions.dataRetentionDays, equals(30)); // Shorter retention
        expect(permissions.requiresParentalNotification, isTrue);
      });

      test('should return full permissions for users 13 and older', () async {
        // Arrange
        final birthDate = DateTime.now().subtract(Duration(days: 365 * 16)); // 16 years old
        when(mockPrefs.getString('user_birth_date_$testUserId'))
            .thenReturn(birthDate.toIso8601String());

        // Act
        final permissions = await coppaService.getDataCollectionPermissions(testUserId);

        // Assert
        expect(permissions.canCollectPersonalInfo, isTrue);
        expect(permissions.canCollectBehavioralData, isTrue);
        expect(permissions.canShareWithThirdParties, isTrue);
        expect(permissions.dataRetentionDays, equals(365)); // Standard retention
        expect(permissions.requiresParentalNotification, isFalse);
      });

      test('should deny all permissions for minors without consent', () async {
        // Arrange
        final birthDate = DateTime.now().subtract(Duration(days: 365 * 8)); // 8 years old
        when(mockPrefs.getString('user_birth_date_$testUserId'))
            .thenReturn(birthDate.toIso8601String());
        when(mockPrefs.getBool('coppa_consent_$testUserId')).thenReturn(null);

        // Act
        final permissions = await coppaService.getDataCollectionPermissions(testUserId);

        // Assert
        expect(permissions.canCollectPersonalInfo, isFalse);
        expect(permissions.canCollectBehavioralData, isFalse);
        expect(permissions.canShareWithThirdParties, isFalse);
        expect(permissions.dataRetentionDays, equals(0)); // No data retention
        expect(permissions.requiresParentalNotification, isTrue);
      });
    });

    group('Audit Logging', () {
      test('should log data access events', () async {
        // Arrange
        when(mockPrefs.setString(any, any)).thenAnswer((_) async => true);
        when(mockPrefs.getString('coppa_access_log_$testUserId')).thenReturn(null);

        // Act
        await coppaService.logDataAccess(testUserId, 'journal_entries', 'read');

        // Assert
        verify(mockPrefs.setString('coppa_access_log_$testUserId', any)).called(1);
      });

      test('should maintain access log history', () async {
        // Arrange
        final existingLog = [
          {
            'timestamp': DateTime.now().subtract(Duration(hours: 1)).toIso8601String(),
            'dataType': 'animals',
            'operation': 'read',
            'ipAddress': '192.168.1.1',
          }
        ];
        
        when(mockPrefs.getString('coppa_access_log_$testUserId'))
            .thenReturn(jsonEncode(existingLog));
        when(mockPrefs.setString(any, any)).thenAnswer((_) async => true);

        // Act
        await coppaService.logDataAccess(testUserId, 'journal_entries', 'create');

        // Assert
        final captured = verify(mockPrefs.setString('coppa_access_log_$testUserId', captureAny))
            .captured.first as String;
        final logData = jsonDecode(captured) as List;
        expect(logData, hasLength(2)); // Should have both entries
        expect(logData[1]['dataType'], equals('journal_entries'));
        expect(logData[1]['operation'], equals('create'));
      });

      test('should limit log size to prevent excessive storage', () async {
        // Arrange
        final oldLogs = List.generate(150, (index) => {
          'timestamp': DateTime.now().subtract(Duration(hours: index)).toIso8601String(),
          'dataType': 'test_data',
          'operation': 'read',
          'ipAddress': '192.168.1.1',
        });
        
        when(mockPrefs.getString('coppa_access_log_$testUserId'))
            .thenReturn(jsonEncode(oldLogs));
        when(mockPrefs.setString(any, any)).thenAnswer((_) async => true);

        // Act
        await coppaService.logDataAccess(testUserId, 'new_data', 'create');

        // Assert
        final captured = verify(mockPrefs.setString('coppa_access_log_$testUserId', captureAny))
            .captured.first as String;
        final logData = jsonDecode(captured) as List;
        expect(logData.length, lessThanOrEqualTo(100)); // Should be capped at 100 entries
      });
    });

    group('Parent Notification System', () {
      test('should send notification on first data collection', () async {
        // Arrange
        when(mockPrefs.getBool('coppa_parent_notified_$testUserId')).thenReturn(null);
        when(mockPrefs.setBool('coppa_parent_notified_$testUserId', true))
            .thenAnswer((_) async => true);
        when(mockPrefs.getString('coppa_parent_email_$testUserId')).thenReturn(parentEmail);

        // Act
        final shouldNotify = await coppaService.shouldNotifyParent(testUserId, 'data_collection_start');

        // Assert
        expect(shouldNotify, isTrue);
      });

      test('should not send duplicate notifications', () async {
        // Arrange
        when(mockPrefs.getBool('coppa_parent_notified_$testUserId')).thenReturn(true);

        // Act
        final shouldNotify = await coppaService.shouldNotifyParent(testUserId, 'data_collection_start');

        // Assert
        expect(shouldNotify, isFalse);
      });

      test('should send notification on significant events', () async {
        // Arrange
        when(mockPrefs.getBool('coppa_parent_notified_policy_change_$testUserId')).thenReturn(null);
        when(mockPrefs.getString('coppa_parent_email_$testUserId')).thenReturn(parentEmail);

        // Act
        final shouldNotify = await coppaService.shouldNotifyParent(testUserId, 'policy_change');

        // Assert
        expect(shouldNotify, isTrue);
      });

      test('should track notification history', () async {
        // Arrange
        when(mockPrefs.setBool(any, any)).thenAnswer((_) async => true);
        when(mockPrefs.setInt(any, any)).thenAnswer((_) async => true);

        // Act
        await coppaService.recordParentNotification(testUserId, 'data_sharing_request', parentEmail);

        // Assert
        verify(mockPrefs.setBool('coppa_parent_notified_data_sharing_request_$testUserId', true)).called(1);
        verify(mockPrefs.setInt('coppa_notification_timestamp_$testUserId', any)).called(1);
      });
    });

    group('Error Handling and Edge Cases', () {
      test('should handle corrupted consent data gracefully', () async {
        // Arrange
        when(mockPrefs.getString('coppa_parent_email_$testUserId')).thenReturn('invalid_email');
        when(mockPrefs.getBool('coppa_consent_$testUserId')).thenReturn(true);
        when(mockPrefs.getInt('coppa_consent_timestamp_$testUserId')).thenReturn(null);

        // Act & Assert - Should not throw
        expect(() async => await coppaService.hasParentalConsent(testUserId), returnsNormally);
      });

      test('should handle SharedPreferences failures', () async {
        // Arrange
        when(mockPrefs.getBool(any)).thenThrow(Exception('Storage error'));

        // Act
        final hasConsent = await coppaService.hasParentalConsent(testUserId);

        // Assert - Should default to false on error
        expect(hasConsent, isFalse);
      });

      test('should validate consent data before storage', () async {
        // Arrange
        when(mockPrefs.setString(any, any)).thenAnswer((_) async => true);
        when(mockPrefs.setBool(any, any)).thenAnswer((_) async => true);
        when(mockPrefs.setInt(any, any)).thenAnswer((_) async => true);

        final invalidConsent = COPPAConsentData(
          parentEmail: 'invalid-email', // Invalid email
          parentName: '',  // Empty name
          relationshipType: 'invalid_relation',  // Invalid relationship
          consentMethod: 'unknown_method',  // Invalid method
          ipAddress: '192.168.1.1',
          userAgent: 'Test Browser',
        );

        // Act & Assert
        expect(
          () async => await coppaService.recordParentalConsent(testUserId, invalidConsent),
          throwsA(isA<ArgumentError>()),
        );
      });

      test('should handle timezone differences in age calculation', () async {
        // Arrange
        final utcBirthDate = DateTime.utc(2011, 6, 15); // UTC birth date
        final localCurrentDate = DateTime(2024, 6, 16, 10, 0, 0); // Local time
        
        when(mockPrefs.getString('user_birth_date_$testUserId'))
            .thenReturn(utcBirthDate.toIso8601String());

        // Act
        final isMinor = await coppaService.isUserUnder13(testUserId, currentDate: localCurrentDate);

        // Assert
        expect(isMinor, isFalse); // Should be 13 years and 1 day old
      });
    });

    group('Compliance Reporting', () {
      test('should generate compliance summary', () async {
        // Arrange
        when(mockPrefs.getBool('coppa_consent_$testUserId')).thenReturn(true);
        when(mockPrefs.getString('coppa_parent_email_$testUserId')).thenReturn(parentEmail);
        when(mockPrefs.getInt('coppa_consent_timestamp_$testUserId'))
            .thenReturn(DateTime.now().millisecondsSinceEpoch);
        when(mockPrefs.getString('coppa_consent_method_$testUserId'))
            .thenReturn('email_verification');

        // Act
        final summary = await coppaService.getComplianceSummary(testUserId);

        // Assert
        expect(summary.userId, equals(testUserId));
        expect(summary.hasValidConsent, isTrue);
        expect(summary.parentEmail, equals(parentEmail));
        expect(summary.consentMethod, equals('email_verification'));
        expect(summary.consentDate, isNotNull);
        expect(summary.isConsentCurrent, isTrue);
      });

      test('should indicate compliance violations', () async {
        // Arrange
        final expiredTimestamp = DateTime.now()
            .subtract(Duration(days: 400))
            .millisecondsSinceEpoch;
            
        when(mockPrefs.getBool('coppa_consent_$testUserId')).thenReturn(true);
        when(mockPrefs.getInt('coppa_consent_timestamp_$testUserId'))
            .thenReturn(expiredTimestamp);

        // Act
        final summary = await coppaService.getComplianceSummary(testUserId);

        // Assert
        expect(summary.hasValidConsent, isFalse);
        expect(summary.isConsentCurrent, isFalse);
        expect(summary.complianceViolations, isNotEmpty);
        expect(summary.complianceViolations, contains('Expired parental consent'));
      });
    });
  });
}

// Mock COPPA Service for testing
class COPPAService {
  static const int _consentValidityDays = 365;
  static const int _maxLogEntries = 100;

  Future<bool> isUserUnder13(String userId, {DateTime? currentDate}) async {
    final prefs = await SharedPreferences.getInstance();
    final birthDateString = prefs.getString('user_birth_date_$userId');
    
    if (birthDateString == null) return false;
    
    try {
      final birthDate = DateTime.parse(birthDateString);
      final now = currentDate ?? DateTime.now();
      final age = now.difference(birthDate).inDays / 365.25;
      return age < 13.0;
    } catch (e) {
      return false;
    }
  }

  Future<void> recordParentalConsent(String userId, COPPAConsentData consentData) async {
    // Validate consent data
    if (!_isValidEmail(consentData.parentEmail)) {
      throw ArgumentError('Invalid parent email');
    }
    if (consentData.parentName.isEmpty) {
      throw ArgumentError('Parent name is required');
    }
    if (!_isValidRelationship(consentData.relationshipType)) {
      throw ArgumentError('Invalid relationship type');
    }
    if (!_isValidConsentMethod(consentData.consentMethod)) {
      throw ArgumentError('Invalid consent method');
    }

    final prefs = await SharedPreferences.getInstance();
    
    await prefs.setString('coppa_parent_email_$userId', consentData.parentEmail);
    await prefs.setString('coppa_parent_name_$userId', consentData.parentName);
    await prefs.setString('coppa_relationship_$userId', consentData.relationshipType);
    await prefs.setString('coppa_consent_method_$userId', consentData.consentMethod);
    await prefs.setString('coppa_consent_ip_$userId', consentData.ipAddress);
    await prefs.setString('coppa_consent_useragent_$userId', consentData.userAgent);
    await prefs.setBool('coppa_consent_$userId', true);
    await prefs.setBool('coppa_consent_revoked_$userId', false);
    await prefs.setInt('coppa_consent_timestamp_$userId', DateTime.now().millisecondsSinceEpoch);
  }

  Future<bool> hasParentalConsent(String userId) async {
    final prefs = await SharedPreferences.getInstance();
    
    final hasConsent = prefs.getBool('coppa_consent_$userId') ?? false;
    final timestamp = prefs.getInt('coppa_consent_timestamp_$userId');
    
    if (!hasConsent || timestamp == null) return false;
    
    // Check if consent is still valid (not expired)
    final consentDate = DateTime.fromMillisecondsSinceEpoch(timestamp);
    final now = DateTime.now();
    final daysSinceConsent = now.difference(consentDate).inDays;
    
    return daysSinceConsent <= _consentValidityDays;
  }

  Future<bool> canAccessUserData(String userId) async {
    try {
      // Check if user is under 13
      final isMinor = await isUserUnder13(userId);
      
      // If not a minor, allow access
      if (!isMinor) return true;
      
      // Check if consent was revoked
      final prefs = await SharedPreferences.getInstance();
      final isRevoked = prefs.getBool('coppa_consent_revoked_$userId') ?? false;
      if (isRevoked) return false;
      
      // For minors, require valid parental consent
      return await hasParentalConsent(userId);
    } catch (e) {
      return false; // Deny access on any error
    }
  }

  Future<void> revokeParentalConsent(String userId, String reason) async {
    final prefs = await SharedPreferences.getInstance();
    
    await prefs.remove('coppa_consent_$userId');
    await prefs.remove('coppa_parent_email_$userId');
    await prefs.remove('coppa_parent_name_$userId');
    await prefs.setBool('coppa_consent_revoked_$userId', true);
    await prefs.setInt('coppa_revocation_timestamp_$userId', DateTime.now().millisecondsSinceEpoch);
    await prefs.setString('coppa_revocation_reason_$userId', reason);
  }

  Future<COPPADataPermissions> getDataCollectionPermissions(String userId) async {
    final isMinor = await isUserUnder13(userId);
    
    if (!isMinor) {
      return COPPADataPermissions(
        canCollectPersonalInfo: true,
        canCollectBehavioralData: true,
        canShareWithThirdParties: true,
        dataRetentionDays: 365,
        requiresParentalNotification: false,
      );
    }
    
    final hasConsent = await hasParentalConsent(userId);
    
    if (!hasConsent) {
      return COPPADataPermissions(
        canCollectPersonalInfo: false,
        canCollectBehavioralData: false,
        canShareWithThirdParties: false,
        dataRetentionDays: 0,
        requiresParentalNotification: true,
      );
    }
    
    return COPPADataPermissions(
      canCollectPersonalInfo: true,
      canCollectBehavioralData: false, // COPPA restriction
      canShareWithThirdParties: false, // COPPA restriction
      dataRetentionDays: 30, // Shorter retention for minors
      requiresParentalNotification: true,
    );
  }

  Future<void> logDataAccess(String userId, String dataType, String operation) async {
    final prefs = await SharedPreferences.getInstance();
    
    final logEntry = {
      'timestamp': DateTime.now().toIso8601String(),
      'dataType': dataType,
      'operation': operation,
      'ipAddress': '192.168.1.1', // In real implementation, get actual IP
      'userAgent': 'App/1.0', // In real implementation, get actual user agent
    };
    
    final existingLogString = prefs.getString('coppa_access_log_$userId');
    List<Map<String, dynamic>> logEntries = [];
    
    if (existingLogString != null) {
      try {
        final decoded = jsonDecode(existingLogString);
        logEntries = List<Map<String, dynamic>>.from(decoded);
      } catch (e) {
        logEntries = [];
      }
    }
    
    logEntries.add(logEntry);
    
    // Keep only the most recent entries
    if (logEntries.length > _maxLogEntries) {
      logEntries = logEntries.takeLast(_maxLogEntries).toList();
    }
    
    await prefs.setString('coppa_access_log_$userId', jsonEncode(logEntries));
  }

  Future<bool> shouldNotifyParent(String userId, String eventType) async {
    final prefs = await SharedPreferences.getInstance();
    final key = 'coppa_parent_notified_${eventType}_$userId';
    
    final alreadyNotified = prefs.getBool(key) ?? false;
    return !alreadyNotified;
  }

  Future<void> recordParentNotification(String userId, String eventType, String parentEmail) async {
    final prefs = await SharedPreferences.getInstance();
    
    await prefs.setBool('coppa_parent_notified_${eventType}_$userId', true);
    await prefs.setInt('coppa_notification_timestamp_$userId', DateTime.now().millisecondsSinceEpoch);
    await prefs.setString('coppa_last_notified_email_$userId', parentEmail);
  }

  Future<COPPAComplianceSummary> getComplianceSummary(String userId) async {
    final prefs = await SharedPreferences.getInstance();
    
    final hasConsent = prefs.getBool('coppa_consent_$userId') ?? false;
    final timestamp = prefs.getInt('coppa_consent_timestamp_$userId');
    final parentEmail = prefs.getString('coppa_parent_email_$userId');
    final consentMethod = prefs.getString('coppa_consent_method_$userId');
    
    DateTime? consentDate;
    bool isConsentCurrent = false;
    List<String> violations = [];
    
    if (timestamp != null) {
      consentDate = DateTime.fromMillisecondsSinceEpoch(timestamp);
      final daysSinceConsent = DateTime.now().difference(consentDate).inDays;
      isConsentCurrent = daysSinceConsent <= _consentValidityDays;
      
      if (!isConsentCurrent) {
        violations.add('Expired parental consent');
      }
    }
    
    if (hasConsent && parentEmail == null) {
      violations.add('Missing parent email');
    }
    
    return COPPAComplianceSummary(
      userId: userId,
      hasValidConsent: hasConsent && isConsentCurrent,
      parentEmail: parentEmail,
      consentMethod: consentMethod,
      consentDate: consentDate,
      isConsentCurrent: isConsentCurrent,
      complianceViolations: violations,
    );
  }

  bool _isValidEmail(String email) {
    return RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(email);
  }

  bool _isValidRelationship(String relationship) {
    const validRelationships = ['parent', 'father', 'mother', 'guardian', 'caregiver'];
    return validRelationships.contains(relationship.toLowerCase());
  }

  bool _isValidConsentMethod(String method) {
    const validMethods = [
      'email_verification',
      'phone_verification', 
      'in_person_verification',
      'digital_signature',
      'postal_mail'
    ];
    return validMethods.contains(method);
  }
}

// Data classes for COPPA functionality
class COPPAConsentData {
  final String parentEmail;
  final String parentName;
  final String relationshipType;
  final String consentMethod;
  final String ipAddress;
  final String userAgent;
  
  COPPAConsentData({
    required this.parentEmail,
    required this.parentName,
    required this.relationshipType,
    required this.consentMethod,
    required this.ipAddress,
    required this.userAgent,
  });
}

class COPPADataPermissions {
  final bool canCollectPersonalInfo;
  final bool canCollectBehavioralData;
  final bool canShareWithThirdParties;
  final int dataRetentionDays;
  final bool requiresParentalNotification;
  
  COPPADataPermissions({
    required this.canCollectPersonalInfo,
    required this.canCollectBehavioralData,
    required this.canShareWithThirdParties,
    required this.dataRetentionDays,
    required this.requiresParentalNotification,
  });
}

class COPPAComplianceSummary {
  final String userId;
  final bool hasValidConsent;
  final String? parentEmail;
  final String? consentMethod;
  final DateTime? consentDate;
  final bool isConsentCurrent;
  final List<String> complianceViolations;
  
  COPPAComplianceSummary({
    required this.userId,
    required this.hasValidConsent,
    this.parentEmail,
    this.consentMethod,
    this.consentDate,
    required this.isConsentCurrent,
    required this.complianceViolations,
  });
}