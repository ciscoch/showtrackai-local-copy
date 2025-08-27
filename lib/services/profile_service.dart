import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:io';
import 'auth_service.dart';

/// Service for managing user profile data and statistics
class ProfileService {
  static final ProfileService _instance = ProfileService._internal();
  factory ProfileService() => _instance;
  ProfileService._internal();

  final _supabase = Supabase.instance.client;
  final _authService = AuthService();

  /// Get comprehensive user profile data
  Future<Map<String, dynamic>> getProfileData() async {
    if (_authService.isDemoMode) {
      return _getDemoProfileData();
    }

    final user = _authService.currentUser;
    if (user == null) throw Exception('User not authenticated');

    try {
      // Load user profile
      final profileResponse = await _supabase
          .from('user_profiles')
          .select('*')
          .eq('id', user.id)
          .maybeSingle();

      return {
        'id': user.id,
        'email': user.email ?? 'No email',
        'name': profileResponse?['name'] ?? 'FFA Student',
        'chapter': profileResponse?['chapter'] ?? 'My FFA Chapter',
        'degree': profileResponse?['degree'] ?? 'Greenhand FFA Degree',
        'years_active': profileResponse?['years_active'] ?? 1,
        'profile_picture': profileResponse?['profile_picture'],
        'bio': profileResponse?['bio'] ?? 'Passionate about agricultural education',
        'phone': profileResponse?['phone'],
        'state': profileResponse?['state'] ?? 'State',
        'joined_date': profileResponse?['created_at'] ?? DateTime.now().toIso8601String(),
      };
    } catch (e) {
      print('Error loading profile data: $e');
      rethrow;
    }
  }

  /// Get user statistics for dashboard
  Future<Map<String, dynamic>> getUserStatistics() async {
    if (_authService.isDemoMode) {
      return _getDemoStatistics();
    }

    final user = _authService.currentUser;
    if (user == null) throw Exception('User not authenticated');

    try {
      // Run all statistics queries in parallel for better performance
      final results = await Future.wait([
        _getAnimalCount(),
        _getActiveProjects(),
        _getTotalJournalEntries(),
        _getAchievementsCount(),
        _getCurrentShowCount(),
        _getHealthRecordCount(),
        _getMonthlyJournalEntries(),
        _getRecentActivityCount(),
      ]);

      return {
        'total_animals': results[0],
        'active_projects': results[1],
        'journal_entries': results[2],
        'achievements': results[3],
        'current_shows': results[4],
        'health_records': results[5],
        'monthly_journal_entries': results[6],
        'recent_activity': results[7],
      };
    } catch (e) {
      print('Error loading user statistics: $e');
      rethrow;
    }
  }

  /// Update user profile information
  Future<void> updateProfile(Map<String, dynamic> profileData) async {
    if (_authService.isDemoMode) {
      throw Exception('Cannot save changes in demo mode');
    }

    final user = _authService.currentUser;
    if (user == null) throw Exception('User not authenticated');

    try {
      await _supabase.from('user_profiles').upsert({
        'id': user.id,
        'name': profileData['name']?.toString().trim(),
        'chapter': profileData['chapter']?.toString().trim(),
        'bio': profileData['bio']?.toString().trim(),
        'phone': profileData['phone']?.toString().trim(),
        'degree': profileData['degree']?.toString(),
        'years_active': profileData['years_active'],
        'state': profileData['state']?.toString(),
        'updated_at': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      print('Error updating profile: $e');
      rethrow;
    }
  }

  /// Update profile picture
  Future<String> updateProfilePicture(String filePath) async {
    if (_authService.isDemoMode) {
      throw Exception('Cannot upload images in demo mode');
    }

    final user = _authService.currentUser;
    if (user == null) throw Exception('User not authenticated');

    try {
      final fileName = 'profile_${user.id}_${DateTime.now().millisecondsSinceEpoch}.jpg';
      
      // Upload to Supabase Storage
      final file = File(filePath);
      await _supabase.storage
          .from('profiles')
          .upload(fileName, file);

      // Get public URL
      final publicUrl = _supabase.storage
          .from('profiles')
          .getPublicUrl(fileName);

      // Update profile with new image URL
      await _supabase.from('user_profiles').upsert({
        'id': user.id,
        'profile_picture': publicUrl,
        'updated_at': DateTime.now().toIso8601String(),
      });

      return publicUrl;
    } catch (e) {
      print('Error updating profile picture: $e');
      rethrow;
    }
  }

  // Private helper methods for statistics
  Future<int> _getAnimalCount() async {
    try {
      final response = await _supabase
          .from('animals')
          .select('id')
          .eq('user_id', _authService.currentUser!.id);
      return response.length;
    } catch (e) {
      return 0;
    }
  }

  Future<int> _getActiveProjects() async {
    try {
      final response = await _supabase
          .from('projects')
          .select('id')
          .eq('status', 'active')
          .eq('user_id', _authService.currentUser!.id);
      return response.length;
    } catch (e) {
      return 0;
    }
  }

  Future<int> _getTotalJournalEntries() async {
    try {
      final response = await _supabase
          .from('journal_entries')
          .select('id')
          .eq('user_id', _authService.currentUser!.id);
      return response.length;
    } catch (e) {
      return 0;
    }
  }

  Future<int> _getHealthRecordCount() async {
    try {
      final response = await _supabase
          .from('health_records')
          .select('id')
          .eq('user_id', _authService.currentUser!.id);
      return response.length;
    } catch (e) {
      return 0;
    }
  }

  Future<int> _getMonthlyJournalEntries() async {
    try {
      final thirtyDaysAgo = DateTime.now().subtract(const Duration(days: 30));
      final response = await _supabase
          .from('journal_entries')
          .select('id')
          .eq('user_id', _authService.currentUser!.id)
          .gte('created_at', thirtyDaysAgo.toIso8601String());
      return response.length;
    } catch (e) {
      return 0;
    }
  }

  Future<int> _getRecentActivityCount() async {
    try {
      final sevenDaysAgo = DateTime.now().subtract(const Duration(days: 7));
      
      // Count recent activities across multiple tables
      final results = await Future.wait([
        _supabase
            .from('journal_entries')
            .select('id')
            .eq('user_id', _authService.currentUser!.id)
            .gte('created_at', sevenDaysAgo.toIso8601String()),
        _supabase
            .from('health_records')
            .select('id')
            .eq('user_id', _authService.currentUser!.id)
            .gte('created_at', sevenDaysAgo.toIso8601String()),
        _supabase
            .from('animals')
            .select('id')
            .eq('user_id', _authService.currentUser!.id)
            .gte('updated_at', sevenDaysAgo.toIso8601String()),
      ]);
      
      return results.fold<int>(0, (sum, result) => sum + result.length);
    } catch (e) {
      return 0;
    }
  }

  Future<int> _getAchievementsCount() async {
    // This would connect to achievements table when available
    // For now, calculate based on activity levels
    try {
      final stats = await getUserStatistics();
      int achievementCount = 0;
      
      // Basic achievements based on usage
      if (stats['journal_entries'] >= 10) achievementCount++;
      if (stats['total_animals'] >= 5) achievementCount++;
      if (stats['health_records'] >= 20) achievementCount++;
      if (stats['active_projects'] >= 3) achievementCount++;
      
      return achievementCount + 8; // Base achievements
    } catch (e) {
      return 12; // Default achievement count
    }
  }

  Future<int> _getCurrentShowCount() async {
    try {
      // This would connect to shows table when available
      // For now, estimate based on animals and time of year
      final animalCount = await _getAnimalCount();
      final currentMonth = DateTime.now().month;
      
      // Show season is typically spring and fall
      if ((currentMonth >= 3 && currentMonth <= 5) || 
          (currentMonth >= 9 && currentMonth <= 11)) {
        return (animalCount * 0.3).round(); // 30% of animals in shows
      }
      
      return (animalCount * 0.1).round(); // 10% in off-season
    } catch (e) {
      return 2; // Default show count
    }
  }

  // Demo data methods
  Map<String, dynamic> _getDemoProfileData() {
    return {
      'id': 'demo_user',
      'email': 'demo@showtrackai.com',
      'name': 'Demo Student',
      'chapter': 'Demo FFA Chapter',
      'degree': 'Chapter FFA Degree',
      'years_active': 2,
      'profile_picture': null,
      'bio': 'Demo account for exploring ShowTrackAI features',
      'phone': '555-0100',
      'state': 'Demo State',
      'joined_date': DateTime.now().subtract(const Duration(days: 365)).toIso8601String(),
    };
  }

  Map<String, dynamic> _getDemoStatistics() {
    return {
      'total_animals': 8,
      'active_projects': 3,
      'journal_entries': 45,
      'achievements': 12,
      'current_shows': 2,
      'health_records': 28,
      'monthly_journal_entries': 12,
      'recent_activity': 8,
    };
  }

  /// Get user's recent activity summary
  Future<List<Map<String, dynamic>>> getRecentActivity({int limit = 10}) async {
    if (_authService.isDemoMode) {
      return _getDemoRecentActivity();
    }

    final user = _authService.currentUser;
    if (user == null) throw Exception('User not authenticated');

    try {
      // Get recent journal entries, health records, and animal updates
      final journalEntries = await _supabase
          .from('journal_entries')
          .select('id, title, created_at')
          .eq('user_id', user.id)
          .order('created_at', ascending: false)
          .limit(limit ~/ 2);

      final healthRecords = await _supabase
          .from('health_records')
          .select('id, notes, created_at')
          .eq('user_id', user.id)
          .order('created_at', ascending: false)
          .limit(limit ~/ 2);

      // Combine and sort activities
      final activities = <Map<String, dynamic>>[];

      for (final entry in journalEntries) {
        activities.add({
          'type': 'journal',
          'title': entry['title'] ?? 'Journal Entry',
          'created_at': entry['created_at'],
          'icon': 'book',
        });
      }

      for (final record in healthRecords) {
        activities.add({
          'type': 'health',
          'title': 'Health Record',
          'created_at': record['created_at'],
          'icon': 'health_and_safety',
        });
      }

      // Sort by date and limit
      activities.sort((a, b) => 
          DateTime.parse(b['created_at']).compareTo(DateTime.parse(a['created_at'])));
      
      return activities.take(limit).toList();
    } catch (e) {
      print('Error loading recent activity: $e');
      return [];
    }
  }

  List<Map<String, dynamic>> _getDemoRecentActivity() {
    return [
      {
        'type': 'journal',
        'title': 'Daily Health Check - Holstein #247',
        'created_at': DateTime.now().subtract(const Duration(hours: 2)).toIso8601String(),
        'icon': 'book',
      },
      {
        'type': 'health',
        'title': 'Vaccination Record',
        'created_at': DateTime.now().subtract(const Duration(days: 1)).toIso8601String(),
        'icon': 'health_and_safety',
      },
      {
        'type': 'journal',
        'title': 'Feed Management Strategy',
        'created_at': DateTime.now().subtract(const Duration(days: 2)).toIso8601String(),
        'icon': 'book',
      },
      {
        'type': 'journal',
        'title': 'Show Preparation Training',
        'created_at': DateTime.now().subtract(const Duration(days: 3)).toIso8601String(),
        'icon': 'book',
      },
    ];
  }

  /// Check if user profile is complete
  bool isProfileComplete(Map<String, dynamic> profileData) {
    final requiredFields = ['name', 'chapter', 'degree'];
    
    for (final field in requiredFields) {
      final value = profileData[field]?.toString().trim();
      if (value == null || value.isEmpty) {
        return false;
      }
    }
    
    return true;
  }

  /// Get profile completion percentage
  double getProfileCompletionPercentage(Map<String, dynamic> profileData) {
    final allFields = ['name', 'chapter', 'degree', 'bio', 'phone', 'state', 'profile_picture'];
    int completedFields = 0;
    
    for (final field in allFields) {
      final value = profileData[field]?.toString().trim();
      if (value != null && value.isNotEmpty) {
        completedFields++;
      }
    }
    
    return (completedFields / allFields.length * 100);
  }
}