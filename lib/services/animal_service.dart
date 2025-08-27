import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/animal.dart';

class AnimalService {
  final SupabaseClient _client = Supabase.instance.client;
  
  // Create animal table if it doesn't exist (for development)
  static const String createTableSQL = '''
    CREATE TABLE IF NOT EXISTS animals (
      id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
      user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
      name VARCHAR(255) NOT NULL,
      tag VARCHAR(100),
      species VARCHAR(50) NOT NULL,
      breed VARCHAR(100),
      gender VARCHAR(50),
      birth_date DATE,
      purchase_weight DECIMAL(10,2),
      current_weight DECIMAL(10,2),
      purchase_date DATE,
      purchase_price DECIMAL(10,2),
      description TEXT,
      photo_url TEXT,
      metadata JSONB,
      created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
      updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
      UNIQUE(user_id, tag)
    );
    
    -- Create indexes for better performance
    CREATE INDEX IF NOT EXISTS idx_animals_user_id ON animals(user_id);
    CREATE INDEX IF NOT EXISTS idx_animals_species ON animals(species);
    CREATE INDEX IF NOT EXISTS idx_animals_tag ON animals(tag);
  ''';
  
  // Get current user ID
  String? get _currentUserId => _client.auth.currentUser?.id;
  
  // Create a new animal
  Future<Animal> createAnimal(Animal animal) async {
    try {
      if (_currentUserId == null) {
        throw Exception('User not authenticated');
      }
      
      // Ensure the animal belongs to current user
      final animalData = animal.copyWith(userId: _currentUserId!).toJson();
      animalData.remove('id'); // Let database generate ID
      
      final response = await _client
          .from('animals')
          .insert(animalData)
          .select()
          .single();
      
      return Animal.fromJson(response);
    } catch (e) {
      print('Error creating animal: $e');
      throw Exception('Failed to create animal: ${e.toString()}');
    }
  }
  
  // Get all animals for current user
  Future<List<Animal>> getAnimals() async {
    try {
      if (_currentUserId == null) {
        throw Exception('User not authenticated');
      }
      
      final response = await _client
          .from('animals')
          .select()
          .eq('user_id', _currentUserId!)
          .order('created_at', ascending: false);
      
      return (response as List)
          .map((json) => Animal.fromJson(json))
          .toList();
    } catch (e) {
      print('Error fetching animals: $e');
      throw Exception('Failed to fetch animals: ${e.toString()}');
    }
  }
  
  // Get a single animal by ID
  Future<Animal?> getAnimalById(String id) async {
    try {
      if (_currentUserId == null) {
        throw Exception('User not authenticated');
      }
      
      final response = await _client
          .from('animals')
          .select()
          .eq('id', id)
          .eq('user_id', _currentUserId!)
          .maybeSingle();
      
      if (response == null) return null;
      return Animal.fromJson(response);
    } catch (e) {
      print('Error fetching animal: $e');
      throw Exception('Failed to fetch animal: ${e.toString()}');
    }
  }
  
  // Get animals by species
  Future<List<Animal>> getAnimalsBySpecies(AnimalSpecies species) async {
    try {
      if (_currentUserId == null) {
        throw Exception('User not authenticated');
      }
      
      final response = await _client
          .from('animals')
          .select()
          .eq('user_id', _currentUserId!)
          .eq('species', species.name)
          .order('name');
      
      return (response as List)
          .map((json) => Animal.fromJson(json))
          .toList();
    } catch (e) {
      print('Error fetching animals by species: $e');
      throw Exception('Failed to fetch animals: ${e.toString()}');
    }
  }
  
  // Update an animal
  Future<Animal> updateAnimal(Animal animal) async {
    try {
      if (_currentUserId == null) {
        throw Exception('User not authenticated');
      }
      
      if (animal.id == null) {
        throw Exception('Animal ID is required for update');
      }
      
      final updateData = animal.toJson();
      updateData['updated_at'] = DateTime.now().toIso8601String();
      
      final response = await _client
          .from('animals')
          .update(updateData)
          .eq('id', animal.id!)
          .eq('user_id', _currentUserId!)
          .select()
          .single();
      
      return Animal.fromJson(response);
    } catch (e) {
      print('Error updating animal: $e');
      throw Exception('Failed to update animal: ${e.toString()}');
    }
  }
  
  // Update animal weight
  Future<Animal> updateWeight(String animalId, double newWeight) async {
    try {
      if (_currentUserId == null) {
        throw Exception('User not authenticated');
      }
      
      final response = await _client
          .from('animals')
          .update({
            'current_weight': newWeight,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', animalId)
          .eq('user_id', _currentUserId!)
          .select()
          .single();
      
      return Animal.fromJson(response);
    } catch (e) {
      print('Error updating animal weight: $e');
      throw Exception('Failed to update weight: ${e.toString()}');
    }
  }
  
  // Delete an animal
  Future<void> deleteAnimal(String animalId) async {
    try {
      if (_currentUserId == null) {
        throw Exception('User not authenticated');
      }
      
      await _client
          .from('animals')
          .delete()
          .eq('id', animalId)
          .eq('user_id', _currentUserId!);
    } catch (e) {
      print('Error deleting animal: $e');
      throw Exception('Failed to delete animal: ${e.toString()}');
    }
  }
  
  // Check if tag is already used
  Future<bool> isTagAvailable(String tag, {String? excludeAnimalId}) async {
    try {
      if (_currentUserId == null) {
        throw Exception('User not authenticated');
      }
      
      var query = _client
          .from('animals')
          .select('id')
          .eq('user_id', _currentUserId!)
          .eq('tag', tag);
      
      // Exclude the current animal if editing
      if (excludeAnimalId != null) {
        query = query.neq('id', excludeAnimalId);
      }
      
      final response = await query.maybeSingle();
      
      return response == null;
    } catch (e) {
      print('Error checking tag availability: $e');
      return false;
    }
  }
  
  // Search animals by name or tag
  Future<List<Animal>> searchAnimals(String query) async {
    try {
      if (_currentUserId == null) {
        throw Exception('User not authenticated');
      }
      
      final response = await _client
          .from('animals')
          .select()
          .eq('user_id', _currentUserId!)
          .or('name.ilike.%$query%,tag.ilike.%$query%')
          .order('name');
      
      return (response as List)
          .map((json) => Animal.fromJson(json))
          .toList();
    } catch (e) {
      print('Error searching animals: $e');
      throw Exception('Failed to search animals: ${e.toString()}');
    }
  }
}