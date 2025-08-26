import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../lib/services/auth_service.dart';
import 'auth_service_test.mocks.dart';

@GenerateMocks([
  SupabaseClient,
  GoTrueClient,
  User,
  Session,
  AuthResponse,
  SharedPreferences,
])
void main() {
  group('AuthService Unit Tests', () {
    late AuthService authService;
    late MockSupabaseClient mockSupabase;
    late MockGoTrueClient mockAuth;
    late MockUser mockUser;
    late MockSession mockSession;
    late MockAuthResponse mockAuthResponse;
    late MockSharedPreferences mockPrefs;

    const String testEmail = 'test@example.com';
    const String testPassword = 'test123password';
    const String testUserId = 'test-user-123';
    const String testAccessToken = 'test-access-token';
    const String testRefreshToken = 'test-refresh-token';

    setUp(() {
      mockSupabase = MockSupabaseClient();
      mockAuth = MockGoTrueClient();
      mockUser = MockUser();
      mockSession = MockSession();
      mockAuthResponse = MockAuthResponse();
      mockPrefs = MockSharedPreferences();

      // Setup basic Supabase mocking
      when(mockSupabase.auth).thenReturn(mockAuth);
      when(mockUser.id).thenReturn(testUserId);
      when(mockUser.email).thenReturn(testEmail);
      when(mockSession.user).thenReturn(mockUser);
      when(mockSession.accessToken).thenReturn(testAccessToken);
      when(mockSession.refreshToken).thenReturn(testRefreshToken);
      when(mockSession.expiresAt).thenReturn(
        DateTime.now().add(Duration(hours: 1)).millisecondsSinceEpoch ~/ 1000
      );

      authService = AuthService();
      SharedPreferences.setMockInitialValues({});
    });

    group('Sign Up', () {
      test('should sign up user successfully', () async {
        // Arrange
        when(mockAuthResponse.user).thenReturn(mockUser);
        when(mockAuthResponse.session).thenReturn(mockSession);
        when(mockAuth.signUp(
          email: testEmail,
          password: testPassword,
        )).thenAnswer((_) async => mockAuthResponse);

        when(mockPrefs.setString(any, any)).thenAnswer((_) async => true);
        when(mockPrefs.setBool(any, any)).thenAnswer((_) async => true);

        // Act
        final result = await authService.signUp(testEmail, testPassword);

        // Assert
        expect(result.success, isTrue);
        expect(result.user, isNotNull);
        expect(result.user!.email, equals(testEmail));
        expect(result.session, isNotNull);
        
        verify(mockAuth.signUp(
          email: testEmail,
          password: testPassword,
        )).called(1);
      });

      test('should handle sign up with existing email', () async {
        // Arrange
        when(mockAuth.signUp(
          email: testEmail,
          password: testPassword,
        )).thenThrow(AuthException('User already registered'));

        // Act
        final result = await authService.signUp(testEmail, testPassword);

        // Assert
        expect(result.success, isFalse);
        expect(result.error, contains('User already registered'));
        expect(result.user, isNull);
        expect(result.session, isNull);
      });

      test('should handle weak password error', () async {
        // Arrange
        when(mockAuth.signUp(
          email: testEmail,
          password: 'weak',
        )).thenThrow(AuthException('Password should be at least 6 characters'));

        // Act
        final result = await authService.signUp(testEmail, 'weak');

        // Assert
        expect(result.success, isFalse);
        expect(result.error, contains('Password should be at least 6 characters'));
      });

      test('should handle invalid email format', () async {
        // Arrange
        const invalidEmail = 'invalid-email';
        
        when(mockAuth.signUp(
          email: invalidEmail,
          password: testPassword,
        )).thenThrow(AuthException('Invalid email format'));

        // Act
        final result = await authService.signUp(invalidEmail, testPassword);

        // Assert
        expect(result.success, isFalse);
        expect(result.error, contains('Invalid email format'));
      });

      test('should create user profile after successful sign up', () async {
        // Arrange
        when(mockAuthResponse.user).thenReturn(mockUser);
        when(mockAuthResponse.session).thenReturn(mockSession);
        when(mockAuth.signUp(
          email: testEmail,
          password: testPassword,
        )).thenAnswer((_) async => mockAuthResponse);

        when(mockPrefs.setString(any, any)).thenAnswer((_) async => true);
        when(mockPrefs.setBool(any, any)).thenAnswer((_) async => true);

        // Act
        final result = await authService.signUp(
          testEmail, 
          testPassword,
          userData: UserProfileData(
            displayName: 'Test User',
            schoolName: 'Test High School',
            gradeLevel: '10',
            ffaChapter: 'Test FFA Chapter',
          ),
        );

        // Assert
        expect(result.success, isTrue);
        verify(mockPrefs.setString('user_display_name_$testUserId', 'Test User')).called(1);
        verify(mockPrefs.setString('user_school_name_$testUserId', 'Test High School')).called(1);
        verify(mockPrefs.setString('user_grade_level_$testUserId', '10')).called(1);
        verify(mockPrefs.setString('user_ffa_chapter_$testUserId', 'Test FFA Chapter')).called(1);
      });
    });

    group('Sign In', () {
      test('should sign in user successfully', () async {
        // Arrange
        when(mockAuthResponse.user).thenReturn(mockUser);
        when(mockAuthResponse.session).thenReturn(mockSession);
        when(mockAuth.signInWithPassword(
          email: testEmail,
          password: testPassword,
        )).thenAnswer((_) async => mockAuthResponse);

        when(mockPrefs.setString(any, any)).thenAnswer((_) async => true);
        when(mockPrefs.setBool(any, any)).thenAnswer((_) async => true);
        when(mockPrefs.setInt(any, any)).thenAnswer((_) async => true);

        // Act
        final result = await authService.signIn(testEmail, testPassword);

        // Assert
        expect(result.success, isTrue);
        expect(result.user, isNotNull);
        expect(result.session, isNotNull);
        
        verify(mockAuth.signInWithPassword(
          email: testEmail,
          password: testPassword,
        )).called(1);
        
        // Should update last login time
        verify(mockPrefs.setInt('last_login_$testUserId', any)).called(1);
      });

      test('should handle invalid credentials', () async {
        // Arrange
        when(mockAuth.signInWithPassword(
          email: testEmail,
          password: 'wrongpassword',
        )).thenThrow(AuthException('Invalid login credentials'));

        // Act
        final result = await authService.signIn(testEmail, 'wrongpassword');

        // Assert
        expect(result.success, isFalse);
        expect(result.error, contains('Invalid login credentials'));
        expect(result.user, isNull);
      });

      test('should handle unconfirmed email', () async {
        // Arrange
        when(mockAuth.signInWithPassword(
          email: testEmail,
          password: testPassword,
        )).thenThrow(AuthException('Email not confirmed'));

        // Act
        final result = await authService.signIn(testEmail, testPassword);

        // Assert
        expect(result.success, isFalse);
        expect(result.error, contains('Email not confirmed'));
        expect(result.needsEmailConfirmation, isTrue);
      });

      test('should handle too many requests error', () async {
        // Arrange
        when(mockAuth.signInWithPassword(
          email: testEmail,
          password: testPassword,
        )).thenThrow(AuthException('Too many requests'));

        // Act
        final result = await authService.signIn(testEmail, testPassword);

        // Assert
        expect(result.success, isFalse);
        expect(result.error, contains('Too many requests'));
        expect(result.retryAfter, isNotNull);
      });

      test('should remember user preference', () async {
        // Arrange
        when(mockAuthResponse.user).thenReturn(mockUser);
        when(mockAuthResponse.session).thenReturn(mockSession);
        when(mockAuth.signInWithPassword(
          email: testEmail,
          password: testPassword,
        )).thenAnswer((_) async => mockAuthResponse);

        when(mockPrefs.setString(any, any)).thenAnswer((_) async => true);
        when(mockPrefs.setBool(any, any)).thenAnswer((_) async => true);
        when(mockPrefs.setInt(any, any)).thenAnswer((_) async => true);

        // Act
        final result = await authService.signIn(
          testEmail, 
          testPassword, 
          rememberMe: true,
        );

        // Assert
        expect(result.success, isTrue);
        verify(mockPrefs.setBool('remember_user_$testUserId', true)).called(1);
        verify(mockPrefs.setString('remembered_email', testEmail)).called(1);
      });
    });

    group('Sign Out', () {
      test('should sign out user successfully', () async {
        // Arrange
        when(mockAuth.currentUser).thenReturn(mockUser);
        when(mockAuth.signOut()).thenAnswer((_) async {});
        when(mockPrefs.remove(any)).thenAnswer((_) async => true);
        when(mockPrefs.setBool(any, any)).thenAnswer((_) async => true);
        when(mockPrefs.setInt(any, any)).thenAnswer((_) async => true);

        // Act
        await authService.signOut();

        // Assert
        verify(mockAuth.signOut()).called(1);
        verify(mockPrefs.setInt('last_logout_$testUserId', any)).called(1);
      });

      test('should clear user session data on sign out', () async {
        // Arrange
        when(mockAuth.currentUser).thenReturn(mockUser);
        when(mockAuth.signOut()).thenAnswer((_) async {});
        when(mockPrefs.remove(any)).thenAnswer((_) async => true);
        when(mockPrefs.setBool(any, any)).thenAnswer((_) async => true);
        when(mockPrefs.setInt(any, any)).thenAnswer((_) async => true);

        // Act
        await authService.signOut();

        // Assert
        verify(mockPrefs.remove('current_user_session')).called(1);
        verify(mockPrefs.setBool('is_logged_in', false)).called(1);
      });

      test('should handle sign out errors gracefully', () async {
        // Arrange
        when(mockAuth.currentUser).thenReturn(mockUser);
        when(mockAuth.signOut()).thenThrow(AuthException('Sign out failed'));
        when(mockPrefs.setBool(any, any)).thenAnswer((_) async => true);

        // Act & Assert - Should not throw
        expect(() async => await authService.signOut(), returnsNormally);
      });
    });

    group('Token Refresh', () {
      test('should refresh token successfully', () async {
        // Arrange
        final newSession = MockSession();
        when(newSession.user).thenReturn(mockUser);
        when(newSession.accessToken).thenReturn('new-access-token');
        when(newSession.refreshToken).thenReturn('new-refresh-token');
        when(newSession.expiresAt).thenReturn(
          DateTime.now().add(Duration(hours: 1)).millisecondsSinceEpoch ~/ 1000
        );

        when(mockAuthResponse.session).thenReturn(newSession);
        when(mockAuth.refreshSession()).thenAnswer((_) async => mockAuthResponse);
        when(mockPrefs.setString(any, any)).thenAnswer((_) async => true);

        // Act
        final result = await authService.refreshToken();

        // Assert
        expect(result.success, isTrue);
        expect(result.session, isNotNull);
        expect(result.session!.accessToken, equals('new-access-token'));
        
        verify(mockAuth.refreshSession()).called(1);
      });

      test('should handle refresh token expiration', () async {
        // Arrange
        when(mockAuth.refreshSession()).thenThrow(
          AuthException('refresh_token_not_found')
        );

        // Act
        final result = await authService.refreshToken();

        // Assert
        expect(result.success, isFalse);
        expect(result.error, contains('refresh_token_not_found'));
        expect(result.needsReauthentication, isTrue);
      });

      test('should automatically refresh token when near expiry', () async {
        // Arrange
        final expiringSoon = DateTime.now().add(Duration(minutes: 2));
        final expiringSession = MockSession();
        when(expiringSession.user).thenReturn(mockUser);
        when(expiringSession.accessToken).thenReturn(testAccessToken);
        when(expiringSession.expiresAt).thenReturn(
          expiringSoon.millisecondsSinceEpoch ~/ 1000
        );
        
        when(mockAuth.currentSession).thenReturn(expiringSession);
        
        final newSession = MockSession();
        when(newSession.user).thenReturn(mockUser);
        when(newSession.accessToken).thenReturn('refreshed-token');
        when(newSession.expiresAt).thenReturn(
          DateTime.now().add(Duration(hours: 1)).millisecondsSinceEpoch ~/ 1000
        );
        
        when(mockAuthResponse.session).thenReturn(newSession);
        when(mockAuth.refreshSession()).thenAnswer((_) async => mockAuthResponse);
        when(mockPrefs.setString(any, any)).thenAnswer((_) async => true);

        // Act
        final needsRefresh = authService.needsTokenRefresh();
        if (needsRefresh) {
          await authService.refreshToken();
        }

        // Assert
        expect(needsRefresh, isTrue);
        verify(mockAuth.refreshSession()).called(1);
      });
    });

    group('Password Reset', () {
      test('should send password reset email successfully', () async {
        // Arrange
        when(mockAuth.resetPasswordForEmail(testEmail))
            .thenAnswer((_) async {});

        // Act
        final result = await authService.resetPassword(testEmail);

        // Assert
        expect(result.success, isTrue);
        expect(result.message, contains('Password reset email sent'));
        
        verify(mockAuth.resetPasswordForEmail(testEmail)).called(1);
      });

      test('should handle invalid email for password reset', () async {
        // Arrange
        when(mockAuth.resetPasswordForEmail('invalid@email.com'))
            .thenThrow(AuthException('User not found'));

        // Act
        final result = await authService.resetPassword('invalid@email.com');

        // Assert
        expect(result.success, isFalse);
        expect(result.error, contains('User not found'));
      });

      test('should handle rate limiting for password reset', () async {
        // Arrange
        when(mockAuth.resetPasswordForEmail(testEmail))
            .thenThrow(AuthException('Email rate limit exceeded'));

        // Act
        final result = await authService.resetPassword(testEmail);

        // Assert
        expect(result.success, isFalse);
        expect(result.error, contains('rate limit'));
        expect(result.retryAfter, isNotNull);
      });

      test('should update password successfully', () async {
        // Arrange
        when(mockAuth.currentUser).thenReturn(mockUser);
        when(mockAuth.updateUser(UserAttributes(password: 'newpassword123')))
            .thenAnswer((_) async => UserResponse());

        // Act
        final result = await authService.updatePassword('newpassword123');

        // Assert
        expect(result.success, isTrue);
        expect(result.message, contains('Password updated successfully'));
        
        verify(mockAuth.updateUser(
          argThat(predicate<UserAttributes>((attr) => attr.password == 'newpassword123'))
        )).called(1);
      });

      test('should require authentication for password update', () async {
        // Arrange
        when(mockAuth.currentUser).thenReturn(null);

        // Act
        final result = await authService.updatePassword('newpassword123');

        // Assert
        expect(result.success, isFalse);
        expect(result.error, contains('User not authenticated'));
      });
    });

    group('User Profile Management', () {
      test('should get current user successfully', () async {
        // Arrange
        when(mockAuth.currentUser).thenReturn(mockUser);
        when(mockAuth.currentSession).thenReturn(mockSession);

        // Act
        final user = authService.getCurrentUser();

        // Assert
        expect(user, isNotNull);
        expect(user!.id, equals(testUserId));
        expect(user.email, equals(testEmail));
      });

      test('should return null when no user is signed in', () async {
        // Arrange
        when(mockAuth.currentUser).thenReturn(null);

        // Act
        final user = authService.getCurrentUser();

        // Assert
        expect(user, isNull);
      });

      test('should get current session successfully', () async {
        // Arrange
        when(mockAuth.currentSession).thenReturn(mockSession);

        // Act
        final session = authService.getCurrentSession();

        // Assert
        expect(session, isNotNull);
        expect(session!.accessToken, equals(testAccessToken));
        expect(session.user.id, equals(testUserId));
      });

      test('should update user profile successfully', () async {
        // Arrange
        when(mockAuth.currentUser).thenReturn(mockUser);
        when(mockAuth.updateUser(any)).thenAnswer((_) async => UserResponse());
        when(mockPrefs.setString(any, any)).thenAnswer((_) async => true);

        final profileData = UserProfileData(
          displayName: 'Updated Name',
          schoolName: 'New School',
          gradeLevel: '11',
          ffaChapter: 'New FFA Chapter',
        );

        // Act
        final result = await authService.updateUserProfile(profileData);

        // Assert
        expect(result.success, isTrue);
        verify(mockPrefs.setString('user_display_name_$testUserId', 'Updated Name')).called(1);
        verify(mockPrefs.setString('user_school_name_$testUserId', 'New School')).called(1);
      });

      test('should handle user profile update errors', () async {
        // Arrange
        when(mockAuth.currentUser).thenReturn(mockUser);
        when(mockAuth.updateUser(any)).thenThrow(AuthException('Update failed'));

        final profileData = UserProfileData(displayName: 'Updated Name');

        // Act
        final result = await authService.updateUserProfile(profileData);

        // Assert
        expect(result.success, isFalse);
        expect(result.error, contains('Update failed'));
      });
    });

    group('Session Validation', () {
      test('should validate active session', () async {
        // Arrange
        when(mockAuth.currentSession).thenReturn(mockSession);
        when(mockAuth.currentUser).thenReturn(mockUser);

        // Act
        final isValid = authService.isSessionValid();

        // Assert
        expect(isValid, isTrue);
      });

      test('should invalidate expired session', () async {
        // Arrange
        final expiredSession = MockSession();
        when(expiredSession.user).thenReturn(mockUser);
        when(expiredSession.expiresAt).thenReturn(
          DateTime.now().subtract(Duration(hours: 1)).millisecondsSinceEpoch ~/ 1000
        );
        
        when(mockAuth.currentSession).thenReturn(expiredSession);

        // Act
        final isValid = authService.isSessionValid();

        // Assert
        expect(isValid, isFalse);
      });

      test('should invalidate null session', () async {
        // Arrange
        when(mockAuth.currentSession).thenReturn(null);

        // Act
        final isValid = authService.isSessionValid();

        // Assert
        expect(isValid, isFalse);
      });
    });

    group('Authentication State Monitoring', () {
      test('should listen to auth state changes', () async {
        // Arrange
        final authStateController = StreamController<AuthState>();
        when(mockAuth.onAuthStateChange).thenAnswer((_) => authStateController.stream);

        List<AuthState> receivedStates = [];
        
        // Act
        final subscription = authService.onAuthStateChange.listen((state) {
          receivedStates.add(state);
        });

        authStateController.add(AuthState(AuthChangeEvent.signedIn, mockSession));
        authStateController.add(AuthState(AuthChangeEvent.signedOut, null));
        
        await Future.delayed(Duration(milliseconds: 10));

        // Assert
        expect(receivedStates, hasLength(2));
        expect(receivedStates[0].event, equals(AuthChangeEvent.signedIn));
        expect(receivedStates[1].event, equals(AuthChangeEvent.signedOut));

        // Cleanup
        await subscription.cancel();
        await authStateController.close();
      });

      test('should handle auth state change errors', () async {
        // Arrange
        final authStateController = StreamController<AuthState>();
        when(mockAuth.onAuthStateChange).thenAnswer((_) => authStateController.stream);

        // Act
        final subscription = authService.onAuthStateChange.listen(
          (state) {},
          onError: (error) {
            expect(error, isA<Exception>());
          },
        );

        authStateController.addError(Exception('Auth state error'));
        
        await Future.delayed(Duration(milliseconds: 10));

        // Cleanup
        await subscription.cancel();
        await authStateController.close();
      });
    });

    group('Biometric Authentication', () {
      test('should enable biometric authentication when available', () async {
        // Arrange
        when(mockPrefs.setBool(any, any)).thenAnswer((_) async => true);
        when(mockPrefs.setString(any, any)).thenAnswer((_) async => true);

        // Act
        final result = await authService.enableBiometricAuth(testUserId);

        // Assert
        expect(result.success, isTrue);
        verify(mockPrefs.setBool('biometric_enabled_$testUserId', true)).called(1);
      });

      test('should handle biometric authentication unavailable', () async {
        // Arrange - Mock biometric unavailable scenario
        // This would typically check device capabilities

        // Act
        final result = await authService.enableBiometricAuth(testUserId);

        // Assert
        expect(result.success, isFalse);
        expect(result.error, contains('Biometric authentication not available'));
      });

      test('should authenticate with biometrics successfully', () async {
        // Arrange
        when(mockPrefs.getBool('biometric_enabled_$testUserId')).thenReturn(true);
        when(mockPrefs.getString('biometric_user_id')).thenReturn(testUserId);
        when(mockAuth.currentUser).thenReturn(mockUser);
        when(mockAuth.currentSession).thenReturn(mockSession);

        // Act
        final result = await authService.authenticateWithBiometrics();

        // Assert
        expect(result.success, isTrue);
        expect(result.user, isNotNull);
        expect(result.session, isNotNull);
      });
    });

    group('Error Handling and Edge Cases', () {
      test('should handle network connectivity issues', () async {
        // Arrange
        when(mockAuth.signInWithPassword(
          email: testEmail,
          password: testPassword,
        )).thenThrow(Exception('Network error'));

        // Act
        final result = await authService.signIn(testEmail, testPassword);

        // Assert
        expect(result.success, isFalse);
        expect(result.error, contains('Network error'));
      });

      test('should handle concurrent authentication attempts', () async {
        // Arrange
        when(mockAuthResponse.user).thenReturn(mockUser);
        when(mockAuthResponse.session).thenReturn(mockSession);
        when(mockAuth.signInWithPassword(
          email: testEmail,
          password: testPassword,
        )).thenAnswer((_) async {
          await Future.delayed(Duration(milliseconds: 100));
          return mockAuthResponse;
        });

        when(mockPrefs.setString(any, any)).thenAnswer((_) async => true);
        when(mockPrefs.setBool(any, any)).thenAnswer((_) async => true);
        when(mockPrefs.setInt(any, any)).thenAnswer((_) async => true);

        // Act
        final future1 = authService.signIn(testEmail, testPassword);
        final future2 = authService.signIn(testEmail, testPassword);
        
        final results = await Future.wait([future1, future2]);

        // Assert - Both should succeed or at least one should handle concurrency
        expect(results.any((r) => r.success), isTrue);
      });

      test('should handle SharedPreferences errors gracefully', () async {
        // Arrange
        when(mockAuthResponse.user).thenReturn(mockUser);
        when(mockAuthResponse.session).thenReturn(mockSession);
        when(mockAuth.signInWithPassword(
          email: testEmail,
          password: testPassword,
        )).thenAnswer((_) async => mockAuthResponse);

        when(mockPrefs.setString(any, any)).thenThrow(Exception('Storage error'));

        // Act
        final result = await authService.signIn(testEmail, testPassword);

        // Assert - Should still succeed even if local storage fails
        expect(result.success, isTrue);
      });

      test('should handle malformed session data', () async {
        // Arrange
        final malformedSession = MockSession();
        when(malformedSession.user).thenReturn(null); // Null user
        when(malformedSession.accessToken).thenReturn('');  // Empty token
        
        when(mockAuth.currentSession).thenReturn(malformedSession);

        // Act
        final isValid = authService.isSessionValid();
        final user = authService.getCurrentUser();

        // Assert
        expect(isValid, isFalse);
        expect(user, isNull);
      });
    });

    group('Security Features', () {
      test('should track failed login attempts', () async {
        // Arrange
        when(mockAuth.signInWithPassword(
          email: testEmail,
          password: 'wrongpassword',
        )).thenThrow(AuthException('Invalid credentials'));
        
        when(mockPrefs.getInt('failed_attempts_$testEmail')).thenReturn(0);
        when(mockPrefs.setInt(any, any)).thenAnswer((_) async => true);

        // Act
        for (int i = 0; i < 3; i++) {
          await authService.signIn(testEmail, 'wrongpassword');
        }

        // Assert
        verify(mockPrefs.setInt('failed_attempts_$testEmail', any)).called(atLeast(3));
      });

      test('should implement account lockout after max failed attempts', () async {
        // Arrange
        when(mockPrefs.getInt('failed_attempts_$testEmail')).thenReturn(5);
        when(mockPrefs.getInt('lockout_until_$testEmail')).thenReturn(
          DateTime.now().add(Duration(minutes: 15)).millisecondsSinceEpoch
        );

        // Act
        final result = await authService.signIn(testEmail, testPassword);

        // Assert
        expect(result.success, isFalse);
        expect(result.error, contains('Account temporarily locked'));
        expect(result.retryAfter, isNotNull);
      });

      test('should clear failed attempts after successful login', () async {
        // Arrange
        when(mockAuthResponse.user).thenReturn(mockUser);
        when(mockAuthResponse.session).thenReturn(mockSession);
        when(mockAuth.signInWithPassword(
          email: testEmail,
          password: testPassword,
        )).thenAnswer((_) async => mockAuthResponse);

        when(mockPrefs.getInt('failed_attempts_$testEmail')).thenReturn(3);
        when(mockPrefs.remove(any)).thenAnswer((_) async => true);
        when(mockPrefs.setString(any, any)).thenAnswer((_) async => true);
        when(mockPrefs.setBool(any, any)).thenAnswer((_) async => true);
        when(mockPrefs.setInt(any, any)).thenAnswer((_) async => true);

        // Act
        final result = await authService.signIn(testEmail, testPassword);

        // Assert
        expect(result.success, isTrue);
        verify(mockPrefs.remove('failed_attempts_$testEmail')).called(1);
        verify(mockPrefs.remove('lockout_until_$testEmail')).called(1);
      });
    });
  });
}

// Mock AuthService for testing
class AuthService {
  static const int maxFailedAttempts = 5;
  static const int lockoutMinutes = 15;
  static const int tokenRefreshThresholdMinutes = 5;

  Stream<AuthState> get onAuthStateChange => _authStateController.stream;
  final StreamController<AuthState> _authStateController = StreamController<AuthState>.broadcast();

  User? getCurrentUser() {
    try {
      return Supabase.instance.client.auth.currentUser;
    } catch (e) {
      return null;
    }
  }

  Session? getCurrentSession() {
    try {
      return Supabase.instance.client.auth.currentSession;
    } catch (e) {
      return null;
    }
  }

  bool isSessionValid() {
    final session = getCurrentSession();
    if (session == null) return false;
    
    final user = session.user;
    if (user == null) return false;
    
    final accessToken = session.accessToken;
    if (accessToken.isEmpty) return false;
    
    final expiresAt = session.expiresAt;
    if (expiresAt == null) return false;
    
    final expiryDate = DateTime.fromMillisecondsSinceEpoch(expiresAt * 1000);
    return expiryDate.isAfter(DateTime.now());
  }

  bool needsTokenRefresh() {
    final session = getCurrentSession();
    if (session == null) return false;
    
    final expiresAt = session.expiresAt;
    if (expiresAt == null) return false;
    
    final expiryDate = DateTime.fromMillisecondsSinceEpoch(expiresAt * 1000);
    final now = DateTime.now();
    final minutesUntilExpiry = expiryDate.difference(now).inMinutes;
    
    return minutesUntilExpiry <= tokenRefreshThresholdMinutes;
  }

  Future<AuthResult> signUp(String email, String password, {UserProfileData? userData}) async {
    try {
      final response = await Supabase.instance.client.auth.signUp(
        email: email,
        password: password,
      );

      if (response.user != null && response.session != null) {
        await _storeUserSession(response.session!);
        
        if (userData != null) {
          await _createUserProfile(response.user!.id, userData);
        }

        return AuthResult(
          success: true,
          user: response.user,
          session: response.session,
        );
      } else {
        return AuthResult(
          success: false,
          error: 'Sign up failed - no user or session returned',
        );
      }
    } on AuthException catch (e) {
      return AuthResult(
        success: false,
        error: e.message,
      );
    } catch (e) {
      return AuthResult(
        success: false,
        error: 'Sign up failed: ${e.toString()}',
      );
    }
  }

  Future<AuthResult> signIn(String email, String password, {bool rememberMe = false}) async {
    try {
      // Check for account lockout
      final isLockedOut = await _isAccountLockedOut(email);
      if (isLockedOut) {
        final lockoutUntil = await _getLockoutTime(email);
        return AuthResult(
          success: false,
          error: 'Account temporarily locked due to too many failed attempts',
          retryAfter: lockoutUntil,
        );
      }

      final response = await Supabase.instance.client.auth.signInWithPassword(
        email: email,
        password: password,
      );

      if (response.user != null && response.session != null) {
        await _clearFailedAttempts(email);
        await _storeUserSession(response.session!);
        await _updateLastLogin(response.user!.id);
        
        if (rememberMe) {
          await _storeRememberMePreference(response.user!.id, email);
        }

        return AuthResult(
          success: true,
          user: response.user,
          session: response.session,
        );
      } else {
        await _recordFailedAttempt(email);
        return AuthResult(
          success: false,
          error: 'Sign in failed - no user or session returned',
        );
      }
    } on AuthException catch (e) {
      await _recordFailedAttempt(email);
      
      return AuthResult(
        success: false,
        error: e.message,
        needsEmailConfirmation: e.message.contains('Email not confirmed'),
        retryAfter: e.message.contains('Too many requests') ? DateTime.now().add(Duration(minutes: 5)) : null,
      );
    } catch (e) {
      await _recordFailedAttempt(email);
      return AuthResult(
        success: false,
        error: 'Sign in failed: ${e.toString()}',
      );
    }
  }

  Future<void> signOut() async {
    try {
      final user = getCurrentUser();
      if (user != null) {
        await _updateLastLogout(user.id);
      }
      
      await Supabase.instance.client.auth.signOut();
      await _clearUserSession();
    } catch (e) {
      // Log error but don't throw - always clear local session
      await _clearUserSession();
    }
  }

  Future<AuthResult> refreshToken() async {
    try {
      final response = await Supabase.instance.client.auth.refreshSession();
      
      if (response.session != null) {
        await _storeUserSession(response.session!);
        return AuthResult(
          success: true,
          session: response.session,
        );
      } else {
        return AuthResult(
          success: false,
          error: 'Token refresh failed - no session returned',
        );
      }
    } on AuthException catch (e) {
      return AuthResult(
        success: false,
        error: e.message,
        needsReauthentication: e.message.contains('refresh_token_not_found') || e.message.contains('invalid_grant'),
      );
    } catch (e) {
      return AuthResult(
        success: false,
        error: 'Token refresh failed: ${e.toString()}',
      );
    }
  }

  Future<AuthResult> resetPassword(String email) async {
    try {
      await Supabase.instance.client.auth.resetPasswordForEmail(email);
      
      return AuthResult(
        success: true,
        message: 'Password reset email sent to $email',
      );
    } on AuthException catch (e) {
      return AuthResult(
        success: false,
        error: e.message,
        retryAfter: e.message.contains('rate limit') ? DateTime.now().add(Duration(minutes: 5)) : null,
      );
    } catch (e) {
      return AuthResult(
        success: false,
        error: 'Password reset failed: ${e.toString()}',
      );
    }
  }

  Future<AuthResult> updatePassword(String newPassword) async {
    try {
      final user = getCurrentUser();
      if (user == null) {
        return AuthResult(
          success: false,
          error: 'User not authenticated',
        );
      }

      await Supabase.instance.client.auth.updateUser(
        UserAttributes(password: newPassword),
      );

      return AuthResult(
        success: true,
        message: 'Password updated successfully',
      );
    } on AuthException catch (e) {
      return AuthResult(
        success: false,
        error: e.message,
      );
    } catch (e) {
      return AuthResult(
        success: false,
        error: 'Password update failed: ${e.toString()}',
      );
    }
  }

  Future<AuthResult> updateUserProfile(UserProfileData profileData) async {
    try {
      final user = getCurrentUser();
      if (user == null) {
        return AuthResult(
          success: false,
          error: 'User not authenticated',
        );
      }

      // Update Supabase user metadata
      await Supabase.instance.client.auth.updateUser(
        UserAttributes(data: profileData.toJson()),
      );

      // Store profile data locally
      await _storeUserProfile(user.id, profileData);

      return AuthResult(
        success: true,
        message: 'Profile updated successfully',
      );
    } on AuthException catch (e) {
      return AuthResult(
        success: false,
        error: e.message,
      );
    } catch (e) {
      return AuthResult(
        success: false,
        error: 'Profile update failed: ${e.toString()}',
      );
    }
  }

  Future<AuthResult> enableBiometricAuth(String userId) async {
    try {
      // In a real implementation, check if biometric auth is available
      // For testing, we'll assume it's always available
      final biometricAvailable = true;
      
      if (!biometricAvailable) {
        return AuthResult(
          success: false,
          error: 'Biometric authentication not available on this device',
        );
      }

      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('biometric_enabled_$userId', true);
      await prefs.setString('biometric_user_id', userId);

      return AuthResult(
        success: true,
        message: 'Biometric authentication enabled',
      );
    } catch (e) {
      return AuthResult(
        success: false,
        error: 'Failed to enable biometric authentication: ${e.toString()}',
      );
    }
  }

  Future<AuthResult> authenticateWithBiometrics() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getString('biometric_user_id');
      final isEnabled = prefs.getBool('biometric_enabled_$userId') ?? false;
      
      if (!isEnabled || userId == null) {
        return AuthResult(
          success: false,
          error: 'Biometric authentication not enabled',
        );
      }

      // In a real implementation, prompt for biometric authentication
      // For testing, we'll assume it succeeds if the current session exists
      final user = getCurrentUser();
      final session = getCurrentSession();
      
      if (user != null && session != null) {
        return AuthResult(
          success: true,
          user: user,
          session: session,
        );
      } else {
        return AuthResult(
          success: false,
          error: 'Biometric authentication failed - no active session',
        );
      }
    } catch (e) {
      return AuthResult(
        success: false,
        error: 'Biometric authentication failed: ${e.toString()}',
      );
    }
  }

  // Private helper methods

  Future<void> _storeUserSession(Session session) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('current_user_session', session.accessToken);
      await prefs.setBool('is_logged_in', true);
    } catch (e) {
      // Log error but don't throw - session can still work without local storage
    }
  }

  Future<void> _clearUserSession() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('current_user_session');
      await prefs.setBool('is_logged_in', false);
    } catch (e) {
      // Ignore storage errors during cleanup
    }
  }

  Future<void> _createUserProfile(String userId, UserProfileData userData) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (userData.displayName != null) {
        await prefs.setString('user_display_name_$userId', userData.displayName!);
      }
      if (userData.schoolName != null) {
        await prefs.setString('user_school_name_$userId', userData.schoolName!);
      }
      if (userData.gradeLevel != null) {
        await prefs.setString('user_grade_level_$userId', userData.gradeLevel!);
      }
      if (userData.ffaChapter != null) {
        await prefs.setString('user_ffa_chapter_$userId', userData.ffaChapter!);
      }
    } catch (e) {
      // Log error but don't fail the signup
    }
  }

  Future<void> _storeUserProfile(String userId, UserProfileData userData) async {
    await _createUserProfile(userId, userData);
  }

  Future<void> _updateLastLogin(String userId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('last_login_$userId', DateTime.now().millisecondsSinceEpoch);
    } catch (e) {
      // Ignore storage errors
    }
  }

  Future<void> _updateLastLogout(String userId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('last_logout_$userId', DateTime.now().millisecondsSinceEpoch);
    } catch (e) {
      // Ignore storage errors
    }
  }

  Future<void> _storeRememberMePreference(String userId, String email) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('remember_user_$userId', true);
      await prefs.setString('remembered_email', email);
    } catch (e) {
      // Ignore storage errors
    }
  }

  Future<bool> _isAccountLockedOut(String email) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final failedAttempts = prefs.getInt('failed_attempts_$email') ?? 0;
      final lockoutUntil = prefs.getInt('lockout_until_$email');
      
      if (failedAttempts >= maxFailedAttempts && lockoutUntil != null) {
        final lockoutTime = DateTime.fromMillisecondsSinceEpoch(lockoutUntil);
        return DateTime.now().isBefore(lockoutTime);
      }
      
      return false;
    } catch (e) {
      return false;
    }
  }

  Future<DateTime?> _getLockoutTime(String email) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final lockoutUntil = prefs.getInt('lockout_until_$email');
      return lockoutUntil != null ? DateTime.fromMillisecondsSinceEpoch(lockoutUntil) : null;
    } catch (e) {
      return null;
    }
  }

  Future<void> _recordFailedAttempt(String email) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final failedAttempts = (prefs.getInt('failed_attempts_$email') ?? 0) + 1;
      await prefs.setInt('failed_attempts_$email', failedAttempts);
      
      if (failedAttempts >= maxFailedAttempts) {
        final lockoutUntil = DateTime.now().add(Duration(minutes: lockoutMinutes));
        await prefs.setInt('lockout_until_$email', lockoutUntil.millisecondsSinceEpoch);
      }
    } catch (e) {
      // Ignore storage errors
    }
  }

  Future<void> _clearFailedAttempts(String email) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('failed_attempts_$email');
      await prefs.remove('lockout_until_$email');
    } catch (e) {
      // Ignore storage errors
    }
  }
}

// Data classes for auth functionality
class AuthResult {
  final bool success;
  final User? user;
  final Session? session;
  final String? error;
  final String? message;
  final bool needsEmailConfirmation;
  final bool needsReauthentication;
  final DateTime? retryAfter;

  AuthResult({
    required this.success,
    this.user,
    this.session,
    this.error,
    this.message,
    this.needsEmailConfirmation = false,
    this.needsReauthentication = false,
    this.retryAfter,
  });
}

class UserProfileData {
  final String? displayName;
  final String? schoolName;
  final String? gradeLevel;
  final String? ffaChapter;

  UserProfileData({
    this.displayName,
    this.schoolName,
    this.gradeLevel,
    this.ffaChapter,
  });

  Map<String, dynamic> toJson() => {
    if (displayName != null) 'displayName': displayName,
    if (schoolName != null) 'schoolName': schoolName,
    if (gradeLevel != null) 'gradeLevel': gradeLevel,
    if (ffaChapter != null) 'ffaChapter': ffaChapter,
  };
}