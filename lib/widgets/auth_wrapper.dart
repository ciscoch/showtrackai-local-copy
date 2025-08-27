import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../screens/login_screen.dart';
import '../screens/dashboard_screen.dart';

/// AuthWrapper manages the authentication state and handles routing
/// between login and dashboard screens based on auth status
class AuthWrapper extends StatelessWidget {
  const AuthWrapper({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: AuthService(),
      builder: (context, child) {
        final authService = AuthService();
        
        print('🔐 AuthWrapper: isAuthenticated=${authService.isAuthenticated}, isDemoMode=${authService.isDemoMode}');
        
        // Show dashboard if authenticated OR in demo mode
        if (authService.isAuthenticatedOrDemo) {
          return const DashboardScreen();
        }
        
        // Show login screen if not authenticated
        return const LoginScreen();
      },
    );
  }
}

/// Route guard that protects routes requiring authentication
class AuthGuard extends StatelessWidget {
  final Widget child;
  
  const AuthGuard({Key? key, required this.child}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: AuthService(),
      builder: (context, _) {
        final authService = AuthService();
        
        if (authService.isAuthenticatedOrDemo) {
          return child;
        }
        
        // Redirect to login if not authenticated
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (Navigator.canPop(context)) {
            Navigator.of(context).pushReplacementNamed('/login');
          }
        });
        
        // Show loading while redirecting
        return const Scaffold(
          body: Center(
            child: CircularProgressIndicator(),
          ),
        );
      },
    );
  }
}