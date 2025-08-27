import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AuthService extends ChangeNotifier {
  // Singleton
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;
  AuthService._internal();

  final SupabaseClient _client = Supabase.instance.client;

  StreamSubscription<AuthState>? _authStateSubscription;
  Timer? _refreshTimer;

  User? get currentUser => _client.auth.currentUser;
  Session? get currentSession => _client.auth.currentSession;
  bool get isAuthenticated => currentUser != null;

  // Refresh a few minutes before expiry
  static const Duration _tokenRefreshBuffer = Duration(minutes: 5);

  // Call this once on app start
  void initialize() {
    print('🔐 Initializing AuthService...');

    _authStateSubscription = _client.auth.onAuthStateChange.listen(
      _handleAuthStateChange,
      onError: _handleAuthError,
    );

    if (currentSession != null) {
      _scheduleTokenRefresh();
    }
  }

  void _handleAuthStateChange(AuthState state) {
    print('🔄 Auth state changed: ${state.event}');

    switch (state.event) {
      case AuthChangeEvent.signedIn:
        print('✅ User signed in: ${state.session?.user.email}');
        _scheduleTokenRefresh();
        notifyListeners();
        break;

      case AuthChangeEvent.signedOut:
        print('👋 User signed out');
        _cancelTokenRefresh();
        notifyListeners();
        break;

      case AuthChangeEvent.tokenRefreshed:
        print('🔄 Token refreshed successfully');
        _scheduleTokenRefresh();
        break;

      case AuthChangeEvent.userUpdated:
        print('👤 User profile updated');
        notifyListeners();
        break;

      case AuthChangeEvent.passwordRecovery:
        print('🔑 Password recovery initiated');
        break;

      default:
        print('ℹ️ Auth event: ${state.event}');
    }
  }

  void _handleAuthError(dynamic error) {
    print('❌ Auth error: $error');
    // Try to recover by refreshing
    refreshSession();
  }

  void _scheduleTokenRefresh() {
    _cancelTokenRefresh();

    final session = currentSession;
    if (session == null) return;

    // Compute an absolute expiry time
    DateTime? expiryTime;
    if (session.expiresAt != null) {
      // expiresAt is seconds since epoch
      expiryTime =
          DateTime.fromMillisecondsSinceEpoch(session.expiresAt! * 1000);
    } else if (session.expiresIn != null) {
      // expiresIn is seconds from now
      expiryTime = DateTime.now().add(Duration(seconds: session.expiresIn!));
    }

    // If we can't determine expiry, do nothing
    if (expiryTime == null) {
      print('ℹ️ No expiry available; skipping scheduled refresh.');
      return;
    }

    final now = DateTime.now();
    final refreshTime = expiryTime.subtract(_tokenRefreshBuffer);
    final timeUntilRefresh = refreshTime.difference(now);

    if (timeUntilRefresh.isNegative) {
      // Already past the buffer window—refresh immediately
      print('⏱️ Expiry buffer passed; refreshing now.');
      refreshSession();
    } else {
      print('⏰ Scheduling token refresh in ${timeUntilRefresh.inMinutes} minutes');
      _refreshTimer = Timer(timeUntilRefresh, refreshSession);
    }
  }

  void _cancelTokenRefresh() {
    _refreshTimer?.cancel();
    _refreshTimer = null;
  }

  Future<void> refreshSession() async {
    try {
      print('🔄 Refreshing auth session...');
      final response = await _client.auth.refreshSession();

      if (response.session != null) {
        print('✅ Session refreshed successfully');
        _scheduleTokenRefresh();
      } else {
        print('⚠️ Session refresh returned null');
      }
    } catch (e) {
      print('❌ Failed to refresh session: $e');
      // Swallow to allow app to handle gracefully
    }
  }

  Future<AuthResponse> signIn({
    required String email,
    required String password,
  }) async {
    try {
      print('🔐 Signing in user: $email');

      final response = await _client.auth
          .signInWithPassword(email: email, password: password)
          .timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          throw AuthException(
              'Connection timeout - please check your internet connection');
        },
      );

      if (response.user != null) {
        print('✅ Sign in successful: ${response.user!.id}');
        await _ensureUserProfile(response.user!);
        _scheduleTokenRefresh();
      } else {
        throw AuthException('Authentication succeeded but no user returned');
      }

      return response;
    } catch (e) {
      print('❌ Sign in failed: $e');

      if (e is AuthException) {
        rethrow;
      } else if (e.toString().contains('Invalid login credentials')) {
        throw AuthException('Invalid email or password');
      } else if (e.toString().contains('timeout')) {
        throw AuthException(
            'Connection timeout - please check your internet connection');
      } else if (e.toString().contains('network')) {
        throw AuthException('Network error - please check your connection');
      } else {
        throw AuthException('Sign in failed: ${e.toString()}');
      }
    }
  }

  // Ensure a user profile row exists for this user
  Future<void> _ensureUserProfile(User user) async {
    try {
      final profileResponse = await _client
          .from('user_profiles')
          .select('id')
          .eq('id', user.id)
          .maybeSingle();

      if (profileResponse == null) {
        print('📝 Creating user profile for: ${user.email}');
        await _client.from('user_profiles').insert({
          'id': user.id,
          'email': user.email ?? '',
          'created_at': DateTime.now().toIso8601String(),
        });
        print('✅ User profile created');
      } else {
        print('✅ User profile exists');
      }
    } catch (e) {
      print('⚠️ Could not verify/create user profile: $e');
      // Non-fatal
    }
  }

  Future<AuthResponse> signUp({
    required String email,
    required String password,
    Map<String, dynamic>? metadata,
  }) async {
    try {
      print('📝 Signing up new user: $email');

      final response = await _client.auth
          .signUp(
            email: email,
            password: password,
            data: metadata,
          )
          .timeout(
        const Duration(seconds: 15),
        onTimeout: () {
          throw AuthException('Connection timeout during sign up');
        },
      );

      if (response.user != null) {
        print('✅ Sign up successful: ${response.user!.id}');
        await _ensureUserProfile(response.user!);

        if (response.session != null) {
          _scheduleTokenRefresh();
        } else {
          print('⚠️ Sign up successful but no session - email confirmation likely required');
        }
      }

      return response;
    } catch (e) {
      print('❌ Sign up failed: $e');

      if (e is AuthException) {
        rethrow;
      } else if (e.toString().contains('User already registered')) {
        throw AuthException('An account with this email already exists');
      } else if (e.toString().contains('signup_disabled')) {
        throw AuthException('New user registration is currently disabled');
      } else if (e.toString().contains('weak_password')) {
        throw AuthException('Password is too weak. Please use a stronger password');
      } else {
        throw AuthException('Sign up failed: ${e.toString()}');
      }
    }
  }

  Future<void> signOut() async {
    try {
      print('👋 Signing out user...');
      _cancelTokenRefresh();
      await _client.auth.signOut();
      print('✅ Sign out successful');
    } catch (e) {
      print('❌ Sign out failed: $e');
      rethrow;
    }
  }

  Future<void> resetPassword(String email) async {
    try {
      print('🔑 Sending password reset to: $email');
      await _client.auth.resetPasswordForEmail(email);
      print('✅ Password reset email sent');
    } catch (e) {
      print('❌ Password reset failed: $e');
      rethrow;
    }
  }

  // Validate current session and refresh if close to expiry
  Future<bool> validateSession() async {
    final session = currentSession;
    if (session == null) return false;

    DateTime? expiryTime;
    if (session.expiresAt != null) {
      expiryTime =
          DateTime.fromMillisecondsSinceEpoch(session.expiresAt! * 1000);
    } else if (session.expiresIn != null) {
      expiryTime = DateTime.now().add(Duration(seconds: session.expiresIn!));
    }

    if (expiryTime == null) {
      // If we can't determine expiry, assume still valid
      return currentUser != null;
    }

    final timeUntilExpiry = expiryTime.difference(DateTime.now());
    if (timeUntilExpiry <= _tokenRefreshBuffer) {
      await refreshSession();
    }

    return currentUser != null;
    }

  // Get current auth headers for API calls
  Map<String, String> getAuthHeaders() {
    final session = currentSession;
    final token = session?.accessToken;
    if (token == null || token.isEmpty) return {};
    return {'Authorization': 'Bearer $token'};
  }

  @override
  void dispose() {
    print('🧹 Disposing AuthService...');
    _authStateSubscription?.cancel();
    _cancelTokenRefresh();
    super.dispose();
  }
}