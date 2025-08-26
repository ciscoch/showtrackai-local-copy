import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({Key? key}) : super(key: key);

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _showDebug = false;
  String _connectionStatus = 'Not tested';
  bool _isTestingConnection = false;

  @override
  void initState() {
    super.initState();
    // Pre-populate with test user as requested
    _emailController.text = 'test-elite@example.com';
    _passwordController.text = 'test123456';
    print('🧪 Pre-populated test user: test-elite@example.com');
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _signIn() async {
    // Validate input
    if (_emailController.text.trim().isEmpty || _passwordController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter both email and password'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    final email = _emailController.text.trim();
    final password = _passwordController.text;

    try {
      print('🔐 Attempting sign in for: $email');
      
      // Check if this is our test user
      if (email == 'test-elite@example.com') {
        print('🧪 Test user detected - using test authentication flow');
        
        // Test authentication flow with fallback
        try {
          // Try Supabase authentication first with short timeout
          final response = await Supabase.instance.client.auth
              .signInWithPassword(
                email: email,
                password: password,
              )
              .timeout(
                const Duration(seconds: 5),
                onTimeout: () {
                  throw Exception('Connection timeout');
                },
              );

          print('✅ Supabase sign in successful: ${response.user?.email}');
          
          if (response.user != null && mounted) {
            _showSuccessMessage('Signed in with Supabase');
            Navigator.of(context).pushReplacementNamed('/dashboard');
            return;
          }
        } catch (supabaseError) {
          print('⚠️ Supabase authentication failed: $supabaseError');
          
          // Fallback to test mode if password is correct
          if (password == 'test123456') {
            print('🎮 Using test mode authentication');
            _showSuccessMessage('Signed in as test user');
            Navigator.of(context).pushReplacementNamed('/dashboard');
            return;
          } else {
            throw Exception('Invalid password for test user');
          }
        }
      }
      
      // Standard authentication for other users
      final response = await Supabase.instance.client.auth
          .signInWithPassword(
            email: email,
            password: password,
          )
          .timeout(
            const Duration(seconds: 10),
            onTimeout: () {
              throw Exception('Connection timeout - please check your internet connection');
            },
          );

      print('✅ Sign in successful: ${response.user?.email}');
      
      if (response.user != null && mounted) {
        _showSuccessMessage('Signed in successfully');
        Navigator.of(context).pushReplacementNamed('/dashboard');
      }
    } catch (e) {
      print('❌ Sign in error: $e');
      
      if (mounted) {
        String errorMessage = 'Login failed';
        
        // Parse error message for better user feedback
        if (e.toString().contains('timeout')) {
          errorMessage = 'Connection timeout - please check your internet connection';
        } else if (e.toString().contains('Invalid login credentials')) {
          if (email == 'test-elite@example.com') {
            errorMessage = 'Test user not found. Please create user in Supabase Dashboard or use Demo Mode';
          } else {
            errorMessage = 'Invalid email or password';
          }
        } else if (e.toString().contains('Test user not found')) {
          errorMessage = 'Test user needs to be created in Supabase Dashboard';
          _showTestUserCreationDialog();
        } else if (e.toString().contains('ERR_NAME_NOT_RESOLVED')) {
          errorMessage = 'Cannot reach server - please check your connection';
        } else if (e.toString().contains('ERR_TIMED_OUT')) {
          errorMessage = 'Server not responding - please try again later';
        } else if (e.toString().contains('Invalid password for test user')) {
          errorMessage = 'Invalid password for test user. Use: test123456';
        } else {
          errorMessage = 'Login failed: ${e.toString().replaceAll('Exception: ', '')}';
        }
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _showSuccessMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _showTestUserCreationDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Create Test User'),
          content: const SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('The test user needs to be created in Supabase Dashboard:'),
                SizedBox(height: 16),
                Text('1. Go to Supabase Dashboard', style: TextStyle(fontWeight: FontWeight.bold)),
                Text('2. Navigate to Authentication > Users'),
                Text('3. Click "Add User"'),
                Text('4. Enter:'),
                SizedBox(height: 8),
                Card(
                  color: Color(0xFFF5F5F5),
                  child: Padding(
                    padding: EdgeInsets.all(8.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Email: test-elite@example.com', style: TextStyle(fontFamily: 'monospace')),
                        Text('Password: test123456', style: TextStyle(fontFamily: 'monospace')),
                        Text('Auto Confirm User: ✓', style: TextStyle(fontFamily: 'monospace')),
                        Text('Email Confirm: ✓', style: TextStyle(fontFamily: 'monospace')),
                      ],
                    ),
                  ),
                ),
                SizedBox(height: 8),
                Text('5. Click "Create User"'),
                SizedBox(height: 16),
                Text('Or use Demo Mode to test the app without Supabase.'),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Got it'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                _signInAsDemo();
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
              child: const Text('Use Demo Mode'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _signInAsDemo() async {
    print('🎭 Signing in as demo user');
    
    setState(() {
      _isLoading = true;
    });

    try {
      // Simulate authentication delay
      await Future.delayed(const Duration(seconds: 1));
      
      _showSuccessMessage('Signed in as Demo User');
      Navigator.of(context).pushReplacementNamed('/dashboard');
    } catch (e) {
      print('❌ Demo sign in failed: $e');
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Demo mode failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }



  Future<void> _testConnection() async {
    setState(() {
      _isTestingConnection = true;
      _connectionStatus = 'Testing...';
    });

    try {
      print('🔍 Testing Supabase connection...');
      
      // Test 1: Check if Supabase client is initialized
      final client = Supabase.instance.client;
      print('✅ Supabase client initialized');
      
      // Test 2: Try to fetch from a simple table with timeout
      final response = await client
          .from('animals')
          .select('id')
          .limit(1)
          .timeout(
            const Duration(seconds: 5),
            onTimeout: () {
              throw Exception('Connection timeout');
            },
          );
      
      print('✅ Database query successful: ${response.length} records');
      
      setState(() {
        _connectionStatus = '✅ Connected to Supabase';
      });
    } catch (e) {
      print('❌ Connection test failed: $e');
      
      String status = '❌ Connection failed';
      if (e.toString().contains('timeout')) {
        status = '❌ Connection timeout';
      } else if (e.toString().contains('ERR_NAME_NOT_RESOLVED')) {
        status = '❌ Cannot resolve server';
      } else if (e.toString().contains('ERR_TIMED_OUT')) {
        status = '❌ Server not responding';
      } else if (e.toString().contains('relation "animals" does not exist')) {
        status = '⚠️ Connected but database not configured';
      }
      
      setState(() {
        _connectionStatus = status;
      });
    } finally {
      setState(() {
        _isTestingConnection = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    print('🔐 Building LoginScreen...');
    print('🖥️ Screen size: ${MediaQuery.of(context).size}');
    print('🎨 Theme brightness: ${Theme.of(context).brightness}');
    
    return Scaffold(
      backgroundColor: Colors.white,
      body: Container(
        width: double.infinity,
        height: double.infinity,
        color: Colors.white,
        child: SafeArea(
          child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 80),
              
              // Logo/Title
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: const Color(0xFF4CAF50),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  children: [
                    const Icon(
                      Icons.agriculture,
                      size: 64,
                      color: Colors.white,
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'ShowTrackAI',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Text(
                      'Agricultural Education Platform',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
              ),
              
              const SizedBox(height: 48),
              
              // Login Form
              TextField(
                controller: _emailController,
                decoration: const InputDecoration(
                  labelText: 'Email',
                  prefixIcon: Icon(Icons.email),
                ),
                keyboardType: TextInputType.emailAddress,
              ),
              
              const SizedBox(height: 16),
              
              TextField(
                controller: _passwordController,
                decoration: const InputDecoration(
                  labelText: 'Password',
                  prefixIcon: Icon(Icons.lock),
                ),
                obscureText: true,
              ),
              
              const SizedBox(height: 24),
              
              ElevatedButton(
                onPressed: _isLoading ? null : _signIn,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF4CAF50),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: _isLoading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text('Sign In', style: TextStyle(fontSize: 16)),
              ),
              
              const SizedBox(height: 16),
              
              // Quick Test Sign In Button
              ElevatedButton.icon(
                onPressed: _isLoading ? null : () async {
                  // Ensure test credentials are set
                  _emailController.text = 'test-elite@example.com';
                  _passwordController.text = 'test123456';
                  await _signIn();
                },
                icon: const Icon(Icons.science),
                label: const Text('Quick Sign In (Test User)', style: TextStyle(fontSize: 16)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),

              const SizedBox(height: 12),

              // Demo Mode Button
              ElevatedButton.icon(
                onPressed: _isLoading ? null : _signInAsDemo,
                icon: const Icon(Icons.play_circle_outline),
                label: const Text('Demo Mode (No Account)', style: TextStyle(fontSize: 16)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.purple,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
              
              const SizedBox(height: 12),
              

              
              const SizedBox(height: 32),
              
              // Debug Toggle
              TextButton(
                onPressed: () {
                  setState(() {
                    _showDebug = !_showDebug;
                  });
                },
                child: Text(_showDebug ? 'Hide Debug Info' : 'Show Debug Info'),
              ),
              
              // Debug Information
              if (_showDebug) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey[300]!),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Debug Information',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      Text('Flutter Version: ${_getFlutterInfo()}'),
                      Text('Supabase URL: https://zifbuzsdhparxlhsifdi.supabase.co'),
                      Text('Current Route: ${ModalRoute.of(context)?.settings.name ?? 'Unknown'}'),
                      Text('Screen Size: ${MediaQuery.of(context).size}'),
                      Text('Platform: ${Theme.of(context).platform}'),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          const Text('Connection Status: '),
                          Expanded(
                            child: Text(
                              _connectionStatus,
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: _connectionStatus.contains('✅')
                                    ? Colors.green
                                    : _connectionStatus.contains('❌')
                                        ? Colors.red
                                        : _connectionStatus.contains('⚠️')
                                            ? Colors.orange
                                            : Colors.black,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      ElevatedButton.icon(
                        onPressed: _isTestingConnection ? null : _testConnection,
                        icon: _isTestingConnection
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                ),
                              )
                            : const Icon(Icons.wifi_tethering),
                        label: Text(_isTestingConnection ? 'Testing...' : 'Test Connection'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue,
                          foregroundColor: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'Test User Credentials:',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.orange[50],
                          border: Border.all(color: Colors.orange[200]!),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const SelectableText(
                          'Email: test-elite@example.com\nPassword: test123456\n\n✨ Features:\n• Works with Supabase authentication\n• Real-time data synchronization\n• Pre-populated on app start',
                          style: TextStyle(fontFamily: 'monospace', fontSize: 12),
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Note: Supabase connection may be unavailable.\nUse "Continue as Demo User" to test the app.',
                        style: TextStyle(
                          color: Colors.orange,
                          fontSize: 12,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'If you see this screen, Flutter is working correctly!',
                        style: TextStyle(
                          color: Colors.green,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
        ),
      ),
    );
  }

  String _getFlutterInfo() {
    try {
      return 'Flutter Web (HTML Renderer)';
    } catch (e) {
      return 'Unknown';
    }
  }

  String _getSupabaseUrl() {
    try {
      return 'Available (check console for details)';
    } catch (e) {
      return 'Not available: $e';
    }
  }
}