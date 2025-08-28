import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/foundation.dart' show kDebugMode;
import '../models/weight.dart';
import '../models/weight_goal.dart';
import 'auth_service.dart';

class WeightService {
  final SupabaseClient _client = Supabase.instance.client;
  final AuthService _authService = AuthService();
  
  // Get current user ID
  String? get _currentUserId => _client.auth.currentUser?.id;
  
  // =====================================================================
  // WEIGHT MANAGEMENT CRUD OPERATIONS
  // =====================================================================
  
  /// Create a new weight entry
  Future<Weight> createWeight(Weight weight) async {
    try {
      if (_currentUserId == null) {
        throw Exception('User not authenticated');
      }
      
      // Ensure the weight belongs to current user
      final weightData = weight.copyWith(
        userId: _currentUserId!,
        recordedBy: _currentUserId!,
      ).toJson();
      weightData.remove('id'); // Let database generate ID
      
      final response = await _client
          .from('weights')
          .insert(weightData)
          .select()
          .single();
      
      return Weight.fromJson(response);
    } catch (e) {
      if (kDebugMode) {
        print('Error creating weight: $e');
      }
      throw Exception('Failed to create weight: ${e.toString()}');
    }
  }
  
  /// Get all weight entries for current user
  Future<List<Weight>> getWeights() async {
    try {
      if (_currentUserId == null) {
        throw Exception('User not authenticated');
      }
      
      final response = await _client
          .from('weights')
          .select()
          .eq('user_id', _currentUserId!)
          .eq('status', 'active')
          .order('measurement_date', ascending: false)
          .order('measurement_time', ascending: false);
      
      return (response as List)
          .map((json) => Weight.fromJson(json))
          .toList();
    } catch (e) {
      if (kDebugMode) {
        print('Error fetching weights: $e');
      }
      throw Exception('Failed to fetch weights: ${e.toString()}');
    }
  }
  
  /// Get weights for specific animal
  Future<List<Weight>> getWeightsByAnimal(String animalId) async {
    try {
      if (_currentUserId == null) {
        throw Exception('User not authenticated');
      }
      
      final response = await _client
          .from('weights')
          .select()
          .eq('user_id', _currentUserId!)
          .eq('animal_id', animalId)
          .eq('status', 'active')
          .order('measurement_date', ascending: false)
          .order('measurement_time', ascending: false);
      
      return (response as List)
          .map((json) => Weight.fromJson(json))
          .toList();
    } catch (e) {
      print('Error fetching weights for animal: $e');
      throw Exception('Failed to fetch animal weights: ${e.toString()}');
    }
  }
  
  /// Get latest weight for an animal
  Future<Weight?> getLatestWeightForAnimal(String animalId) async {
    try {
      if (_currentUserId == null) {
        throw Exception('User not authenticated');
      }
      
      final response = await _client
          .from('v_latest_weights')
          .select()
          .eq('user_id', _currentUserId!)
          .eq('animal_id', animalId)
          .maybeSingle();
      
      if (response == null) return null;
      return Weight.fromJson(response);
    } catch (e) {
      print('Error fetching latest weight: $e');
      throw Exception('Failed to fetch latest weight: ${e.toString()}');
    }
  }
  
  /// Update a weight entry
  Future<Weight> updateWeight(Weight weight) async {
    try {
      // Validate authentication
      if (!_authService.isAuthenticated) {
        throw Exception('User not authenticated - please sign in again');
      }
      
      final sessionValid = await _authService.validateSession();
      if (!sessionValid) {
        throw Exception('Session expired - please sign in again');
      }
      
      final currentUserId = _currentUserId;
      if (currentUserId == null) {
        throw Exception('Authentication validation failed - user ID is null');
      }
      
      if (weight.id == null) {
        throw Exception('Weight ID is required for update');
      }
      
      // Prepare update data
      final updateData = weight.toJson();
      updateData.remove('id');
      updateData.remove('user_id');
      updateData.remove('created_at');
      updateData['updated_at'] = DateTime.now().toIso8601String();
      
      final response = await _client
          .from('weights')
          .update(updateData)
          .eq('id', weight.id!)
          .eq('user_id', currentUserId)
          .select()
          .single()
          .timeout(
            const Duration(seconds: 30),
            onTimeout: () {
              throw Exception('Update timed out - please check your connection and try again');
            },
          );
      
      return Weight.fromJson(response);
    } catch (e) {
      print('Weight update failed: $e');
      
      if (e.toString().contains('JWT expired')) {
        throw Exception('Your session has expired. Please sign in again.');
      } else if (e.toString().contains('Row Level Security')) {
        throw Exception('Permission denied. Please sign out and sign in again.');
      } else if (e.toString().contains('timeout')) {
        throw Exception('Update timed out. Please check your internet connection.');
      }
      
      throw Exception('Failed to update weight: ${e.toString()}');
    }
  }
  
  /// Delete a weight entry (soft delete)
  Future<void> deleteWeight(String weightId) async {
    try {
      if (_currentUserId == null) {
        throw Exception('User not authenticated');
      }
      
      await _client
          .from('weights')
          .update({
            'status': 'deleted',
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', weightId)
          .eq('user_id', _currentUserId!);
    } catch (e) {
      print('Error deleting weight: $e');
      throw Exception('Failed to delete weight: ${e.toString()}');
    }
  }
  
  // =====================================================================
  // WEIGHT GOAL MANAGEMENT
  // =====================================================================
  
  /// Create a new weight goal
  Future<WeightGoal> createWeightGoal(WeightGoal goal) async {
    try {
      if (_currentUserId == null) {
        throw Exception('User not authenticated');
      }
      
      final goalData = goal.copyWith(userId: _currentUserId!).toJson();
      goalData.remove('id');
      
      final response = await _client
          .from('weight_goals')
          .insert(goalData)
          .select()
          .single();
      
      return WeightGoal.fromJson(response);
    } catch (e) {
      print('Error creating weight goal: $e');
      throw Exception('Failed to create weight goal: ${e.toString()}');
    }
  }
  
  /// Get all weight goals for current user
  Future<List<WeightGoal>> getWeightGoals() async {
    try {
      if (_currentUserId == null) {
        throw Exception('User not authenticated');
      }
      
      final response = await _client
          .from('weight_goals')
          .select()
          .eq('user_id', _currentUserId!)
          .order('target_date', ascending: true);
      
      return (response as List)
          .map((json) => WeightGoal.fromJson(json))
          .toList();
    } catch (e) {
      print('Error fetching weight goals: $e');
      throw Exception('Failed to fetch weight goals: ${e.toString()}');
    }
  }
  
  /// Get weight goals for specific animal
  Future<List<WeightGoal>> getWeightGoalsByAnimal(String animalId) async {
    try {
      if (_currentUserId == null) {
        throw Exception('User not authenticated');
      }
      
      final response = await _client
          .from('weight_goals')
          .select()
          .eq('user_id', _currentUserId!)
          .eq('animal_id', animalId)
          .order('target_date', ascending: true);
      
      return (response as List)
          .map((json) => WeightGoal.fromJson(json))
          .toList();
    } catch (e) {
      print('Error fetching weight goals for animal: $e');
      throw Exception('Failed to fetch animal weight goals: ${e.toString()}');
    }
  }
  
  /// Get active weight goals with progress
  Future<List<WeightGoal>> getActiveWeightGoals() async {
    try {
      if (_currentUserId == null) {
        throw Exception('User not authenticated');
      }
      
      final response = await _client
          .from('v_active_weight_goals')
          .select()
          .eq('user_id', _currentUserId!)
          .order('urgency_status')
          .order('target_date');
      
      return (response as List)
          .map((json) => WeightGoal.fromJson(json))
          .toList();
    } catch (e) {
      print('Error fetching active weight goals: $e');
      throw Exception('Failed to fetch active weight goals: ${e.toString()}');
    }
  }
  
  /// Update a weight goal
  Future<WeightGoal> updateWeightGoal(WeightGoal goal) async {
    try {
      if (_currentUserId == null) {
        throw Exception('User not authenticated');
      }
      
      if (goal.id == null) {
        throw Exception('Goal ID is required for update');
      }
      
      final updateData = goal.toJson();
      updateData.remove('id');
      updateData.remove('user_id');
      updateData.remove('created_at');
      updateData['updated_at'] = DateTime.now().toIso8601String();
      
      final response = await _client
          .from('weight_goals')
          .update(updateData)
          .eq('id', goal.id!)
          .eq('user_id', _currentUserId!)
          .select()
          .single();
      
      return WeightGoal.fromJson(response);
    } catch (e) {
      print('Error updating weight goal: $e');
      throw Exception('Failed to update weight goal: ${e.toString()}');
    }
  }
  
  /// Delete a weight goal
  Future<void> deleteWeightGoal(String goalId) async {
    try {
      if (_currentUserId == null) {
        throw Exception('User not authenticated');
      }
      
      await _client
          .from('weight_goals')
          .delete()
          .eq('id', goalId)
          .eq('user_id', _currentUserId!);
    } catch (e) {
      print('Error deleting weight goal: $e');
      throw Exception('Failed to delete weight goal: ${e.toString()}');
    }
  }
  
  // =====================================================================
  // STATISTICS AND ANALYTICS
  // =====================================================================
  
  /// Get weight statistics for an animal
  Future<WeightStatistics?> getWeightStatistics(String animalId) async {
    try {
      if (_currentUserId == null) {
        throw Exception('User not authenticated');
      }
      
      final response = await _client
          .from('weight_statistics_cache')
          .select()
          .eq('animal_id', animalId)
          .maybeSingle();
      
      if (response == null) return null;
      return WeightStatistics.fromJson(response);
    } catch (e) {
      print('Error fetching weight statistics: $e');
      throw Exception('Failed to fetch weight statistics: ${e.toString()}');
    }
  }
  
  /// Get ADG calculations for an animal
  Future<List<Map<String, dynamic>>> getAdgCalculations(String animalId) async {
    try {
      if (_currentUserId == null) {
        throw Exception('User not authenticated');
      }
      
      final response = await _client
          .from('v_adg_calculations')
          .select()
          .eq('animal_id', animalId)
          .order('current_date', ascending: false);
      
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      print('Error fetching ADG calculations: $e');
      throw Exception('Failed to fetch ADG calculations: ${e.toString()}');
    }
  }
  
  /// Get weight trend for an animal
  Future<Map<String, dynamic>?> getWeightTrend(String animalId, {int days = 30}) async {
    try {
      if (_currentUserId == null) {
        throw Exception('User not authenticated');
      }
      
      final response = await _client
          .rpc('get_weight_trend', params: {
            'p_animal_id': animalId,
            'p_days': days,
          });
      
      if (response == null || response.isEmpty) return null;
      return Map<String, dynamic>.from(response[0]);
    } catch (e) {
      print('Error fetching weight trend: $e');
      throw Exception('Failed to fetch weight trend: ${e.toString()}');
    }
  }
  
  /// Detect weight outliers for an animal
  Future<List<Map<String, dynamic>>> detectWeightOutliers(String animalId) async {
    try {
      if (_currentUserId == null) {
        throw Exception('User not authenticated');
      }
      
      final response = await _client
          .rpc('detect_weight_outliers', params: {
            'p_animal_id': animalId,
          });
      
      return List<Map<String, dynamic>>.from(response ?? []);
    } catch (e) {
      print('Error detecting weight outliers: $e');
      throw Exception('Failed to detect weight outliers: ${e.toString()}');
    }
  }
  
  /// Get weight history with detailed analytics
  Future<List<Map<String, dynamic>>> getWeightHistory(String animalId) async {
    try {
      if (_currentUserId == null) {
        throw Exception('User not authenticated');
      }
      
      final response = await _client
          .from('v_weight_history')
          .select()
          .eq('animal_id', animalId)
          .eq('user_id', _currentUserId!)
          .order('measurement_date', ascending: false)
          .order('measurement_time', ascending: false);
      
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      print('Error fetching weight history: $e');
      throw Exception('Failed to fetch weight history: ${e.toString()}');
    }
  }
  
  // =====================================================================
  // ANALYTICS HELPER METHODS
  // =====================================================================
  
  /// Calculate projected weight gain
  Future<double?> calculateProjectedWeight(String animalId, DateTime targetDate) async {
    try {
      final stats = await getWeightStatistics(animalId);
      if (stats?.currentWeight == null || stats?.averageAdg == null) return null;
      
      final daysToTarget = targetDate.difference(DateTime.now()).inDays;
      if (daysToTarget <= 0) return stats!.currentWeight;
      
      return stats!.currentWeight! + (stats.averageAdg! * daysToTarget);
    } catch (e) {
      print('Error calculating projected weight: $e');
      return null;
    }
  }
  
  /// Get feeding efficiency metrics
  Future<Map<String, double>?> getFeedingEfficiency(String animalId, {int days = 30}) async {
    try {
      // This would integrate with feed records if available
      final weights = await getWeightsByAnimal(animalId);
      if (weights.isEmpty) return null;
      
      final recentWeights = weights
          .where((w) => w.measurementDate.isAfter(DateTime.now().subtract(Duration(days: days))))
          .toList();
      
      if (recentWeights.length < 2) return null;
      
      final totalGain = recentWeights.first.weightValue - recentWeights.last.weightValue;
      final periodDays = recentWeights.first.measurementDate
          .difference(recentWeights.last.measurementDate).inDays;
      
      return {
        'total_gain': totalGain,
        'period_days': periodDays.toDouble(),
        'average_daily_gain': periodDays > 0 ? totalGain / periodDays : 0.0,
        'feed_conversion_efficiency': 0.0, // Would be calculated with feed data
      };
    } catch (e) {
      print('Error calculating feeding efficiency: $e');
      return null;
    }
  }
  
  /// Check if weight goals are being met
  Future<List<Map<String, dynamic>>> checkGoalProgress() async {
    try {
      final activeGoals = await getActiveWeightGoals();
      List<Map<String, dynamic>> progressReports = [];
      
      for (final goal in activeGoals) {
        final isOnTrack = goal.isOnTrack;
        final daysRemaining = goal.daysRemaining ?? 0;
        final progressPercentage = goal.progressPercentage ?? 0;
        
        progressReports.add({
          'goal_id': goal.id,
          'goal_name': goal.goalName,
          'animal_id': goal.animalId,
          'on_track': isOnTrack,
          'days_remaining': daysRemaining,
          'progress_percentage': progressPercentage,
          'urgency': goal.urgencyStatus,
          'required_adg': goal.requiredAdgToMeetGoal,
        });
      }
      
      return progressReports;
    } catch (e) {
      print('Error checking goal progress: $e');
      throw Exception('Failed to check goal progress: ${e.toString()}');
    }
  }
  
  /// Get dashboard summary for all animals
  Future<Map<String, dynamic>> getDashboardSummary() async {
    try {
      if (_currentUserId == null) {
        throw Exception('User not authenticated');
      }
      
      // Get all animals' latest weights
      final latestWeights = await _client
          .from('v_latest_weights')
          .select()
          .eq('user_id', _currentUserId!);
      
      // Get active goals summary
      final activeGoals = await getActiveWeightGoals();
      
      // Calculate summary metrics
      int totalAnimalsTracked = latestWeights.length;
      int animalsWithGoals = activeGoals.map((g) => g.animalId).toSet().length;
      int urgentGoals = activeGoals.where((g) => g.isUrgent).length;
      int overdueGoals = activeGoals.where((g) => g.isOverdue).length;
      
      double averageAdg = 0;
      if (latestWeights.isNotEmpty) {
        final validAdgs = latestWeights
            .where((w) => w['adg'] != null)
            .map((w) => (w['adg'] as num).toDouble())
            .toList();
        
        if (validAdgs.isNotEmpty) {
          averageAdg = validAdgs.reduce((a, b) => a + b) / validAdgs.length;
        }
      }
      
      return {
        'total_animals_tracked': totalAnimalsTracked,
        'animals_with_goals': animalsWithGoals,
        'active_goals': activeGoals.length,
        'urgent_goals': urgentGoals,
        'overdue_goals': overdueGoals,
        'average_adg': averageAdg,
        'last_updated': DateTime.now().toIso8601String(),
      };
    } catch (e) {
      print('Error getting dashboard summary: $e');
      throw Exception('Failed to get dashboard summary: ${e.toString()}');
    }
  }
  
  // =====================================================================
  // DATA VALIDATION HELPERS
  // =====================================================================
  
  /// Validate weight entry data
  bool validateWeightEntry(Weight weight) {
    if (weight.weightValue <= 0) return false;
    if (weight.weightValue > (weight.weightUnit == WeightUnit.lb ? 5000 : 2500)) return false;
    if (weight.measurementDate.isAfter(DateTime.now())) return false;
    if (weight.confidenceLevel != null && 
        (weight.confidenceLevel! < 1 || weight.confidenceLevel! > 10)) return false;
    
    return true;
  }
  
  /// Validate weight goal data
  bool validateWeightGoal(WeightGoal goal) {
    if (goal.targetWeight <= 0) return false;
    if (goal.startingWeight <= 0) return false;
    if (goal.targetWeight == goal.startingWeight) return false;
    if (goal.targetDate.isBefore(goal.startingDate)) return false;
    if (goal.targetDate.isBefore(DateTime.now().subtract(const Duration(days: 1)))) return false;
    
    return true;
  }
}