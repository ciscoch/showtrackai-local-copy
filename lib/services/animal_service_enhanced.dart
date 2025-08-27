import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/animal.dart';
import 'auth_service.dart';

class AnimalServiceEnhanced {
  final SupabaseClient _client = Supabase.instance.client;
  final AuthService _authService = AuthService();
  
  // Get current user ID
  String? get _currentUserId => _client.auth.currentUser?.id;
  
  // Enhanced update method with authentication validation
  Future<Animal> updateAnimal(Animal animal) async {
    try {
      // Step 1: Validate authentication BEFORE attempting update
      print('🔐 Validating authentication before animal update...');
      
      if (!_authService.isAuthenticated) {
        throw Exception('User not authenticated - please sign in again');
      }
      
      // Step 2: Proactively validate and refresh session
      final sessionValid = await _authService.validateSession();
      if (!sessionValid) {
        throw Exception('Session expired - please sign in again');
      }
      
      // Step 3: Double-check user ID after potential refresh
      final currentUserId = _currentUserId;
      if (currentUserId == null) {
        throw Exception('Authentication validation failed - user ID is null');
      }
      
      // Step 4: Validate animal ID
      if (animal.id == null) {
        throw Exception('Animal ID is required for update');
      }
      
      print('✅ Authentication validated. User: $currentUserId, Animal: ${animal.id}');
      
      // Step 5: Prepare update data
      final updateData = animal.toJson();
      updateData['updated_at'] = DateTime.now().toIso8601String();
      
      // Step 6: Execute update with comprehensive error handling
      print('💾 Executing animal update...');
      final response = await _client
          .from('animals')
          .update(updateData)
          .eq('id', animal.id!)
          .eq('user_id', currentUserId)  // Use validated user ID
          .select()
          .single()
          .timeout(
            const Duration(seconds: 30),
            onTimeout: () {
              throw Exception('Update timed out - please check your connection and try again');
            },
          );
      
      print('✅ Animal update successful');
      return Animal.fromJson(response);
      
    } catch (e) {
      print('❌ Animal update failed: $e');
      
      // Enhanced error handling with specific messages
      if (e.toString().contains('JWT expired')) {
        throw Exception('Your session has expired. Please sign in again.');
      } else if (e.toString().contains('Row Level Security')) {
        throw Exception('Permission denied. Please sign out and sign in again.');
      } else if (e.toString().contains('timeout')) {
        throw Exception('Update timed out. Please check your internet connection.');
      } else if (e.toString().contains('unique constraint')) {
        throw Exception('An animal with this tag already exists.');
      } else if (e.toString().contains('not found') || e.toString().contains('0 rows')) {
        throw Exception('Animal not found or you do not have permission to update it.');
      }
      
      // Re-throw with original message if no specific handling
      throw Exception('Failed to update animal: ${e.toString()}');
    }
  }
}