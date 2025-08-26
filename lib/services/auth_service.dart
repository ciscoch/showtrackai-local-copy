import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:async';

class AuthService extends ChangeNotifier {
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;
  AuthService._internal();

  final SupabaseClient _client = Supabase.instance.client;
  StreamSubscription<AuthState>? _authStateSubscription;
  Timer? _refreshTimer;
  
  User? get currentUser => _client.auth.currentUser;
  Session? get currentSession => _client.auth.currentSession;
  bool get isAuthenticated => currentUser != null;
  
  // Token refresh configuration
  static const Duration _tokenRefreshInterval = Duration(minutes: 50); // Refresh before 60min expiry
  static const Duration _tokenRefreshBuffer = Duration(minutes: 5);
  
  void initialize() {
    print('🔐 Initializing AuthService...');
    
    // Listen to auth state changes
    _authStateSubscription = _client.auth.onAuthStateChange.listen(
      _handleAuthStateChange,
      onError: _handleAuthError,
    );
    
    // Set up token refresh if user is already signed in
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
    // Attempt to refresh token on error
    refreshSession();
  }
  
  void _scheduleTokenRefresh() {
    _cancelTokenRefresh();
    
    final session = currentSession;
    if (session == null) return;
    
    // Calculate when to refresh (5 minutes before expiry)
    final expiresAt = session.expiresAt;
    if (expiresAt == null) return;
    
    final expiryTime = DateTime.fromMillisecondsSinceEpoch(expiresAt * 1000);
    final refreshTime = expiryTime.subtract(_tokenRefreshBuffer);
    final timeUntilRefresh = refreshTime.difference(DateTime.now());
    
    if (timeUntilRefresh.isNegative) {
      // Token already expired or about to expire
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
      // Don't throw - let the app handle missing auth gracefully
    }
  }
  
  Future<AuthResponse> signIn({
    required String email,
    required String password,
  }) async {
    try {
      print('🔐 Signing in user: $email');
      
      final response = await _client.auth.signInWithPassword(
        email: email,
        password: password,
      );
      
      if (response.user != null) {
        print('✅ Sign in successful');
        _scheduleTokenRefresh();
      }
      
      return response;
    } catch (e) {
      print('❌ Sign in failed: $e');
      rethrow;
    }
  }
  
  Future<AuthResponse> signUp({
    required String email,
    required String password,
    Map<String, dynamic>? metadata,
  }) async {
    try {
      print('📝 Signing up new user: $email');
      
      final response = await _client.auth.signUp(
        email: email,
        password: password,
        data: metadata,
      );
      
      if (response.user != null) {
        print('✅ Sign up successful');
        _scheduleTokenRefresh();
      }
      
      return response;
    } catch (e) {
      print('❌ Sign up failed: $e');
      rethrow;
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
  
  // Check if session is valid and refresh if needed
  Future<bool> validateSession() async {
    final session = currentSession;
    if (session == null) return false;
    
    final expiresAt = session.expiresAt;
    if (expiresAt == null) return false;
    
    final expiryTime = DateTime.fromMillisecondsSinceEpoch(expiresAt * 1000);
    final timeUntilExpiry = expiryTime.difference(DateTime.now());
    
    // If less than 5 minutes until expiry, refresh now
    if (timeUntilExpiry.inMinutes < 5) {
      await refreshSession();
    }
    
    return currentUser != null;
  }
  
  // Get current auth headers for API calls
  Map<String, String> getAuthHeaders() {
    final session = currentSession;
    if (session?.accessToken == null) return {};
    
    return {
      'Authorization': 'Bearer ${session!.accessToken}',
    };
  }
  
  void dispose() {
    print('🧹 Disposing AuthService...');
    _authStateSubscription?.cancel();
    _cancelTokenRefresh();
  }
}