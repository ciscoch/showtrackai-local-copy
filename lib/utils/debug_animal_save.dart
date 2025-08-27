// Debug utility for tracking animal save issues
// Import this in AnimalEditScreen and call before _updateAnimal

import 'package:flutter/foundation.dart';
import '../models/animal.dart';
import '../services/auth_service.dart';
import '../services/animal_service.dart';
import '../utils/input_sanitizer.dart';

class AnimalSaveDebugger {
  static const bool _isDebugMode = kDebugMode;
  
  /// Comprehensive debug check before attempting to save an animal
  static Future<Map<String, dynamic>> debugSaveAttempt({
    required Animal originalAnimal,
    required Animal updatedAnimal,
    required AuthService authService,
    required AnimalService animalService,
    required Map<String, String> formValues,
  }) async {
    final debugInfo = <String, dynamic>{};
    
    if (!_isDebugMode) {
      return debugInfo;
    }
    
    print('🐄 === ANIMAL SAVE DEBUG START ===');
    
    // 1. Authentication Check
    debugInfo['auth'] = await _debugAuthentication(authService);
    
    // 2. Animal Data Validation
    debugInfo['animal_data'] = _debugAnimalData(originalAnimal, updatedAnimal);
    
    // 3. Input Sanitization Check
    debugInfo['sanitization'] = _debugInputSanitization(formValues);
    
    // 4. Database Permissions Check
    debugInfo['permissions'] = await _debugDatabasePermissions(
      animalService, originalAnimal.id!
    );
    
    // 5. Network & Supabase Check
    debugInfo['network'] = await _debugNetworkConnection(animalService);
    
    // 6. Overall Assessment
    debugInfo['assessment'] = _assessIssues(debugInfo);
    
    print('🐄 === ANIMAL SAVE DEBUG END ===');
    
    return debugInfo;
  }
  
  static Future<Map<String, dynamic>> _debugAuthentication(
    AuthService authService
  ) async {
    print('🔐 Checking authentication...');
    
    final authDebug = <String, dynamic>{};
    
    try {
      authDebug['is_authenticated'] = authService.isAuthenticated;
      authDebug['current_user_id'] = authService.currentUser?.id;
      authDebug['current_session_exists'] = authService.currentSession != null;
      
      if (authService.currentSession != null) {
        final session = authService.currentSession!;
        authDebug['session_expires_at'] = session.expiresAt;
        authDebug['session_expires_in'] = session.expiresIn;
        
        // Check if session is close to expiry (within 5 minutes)
        if (session.expiresAt != null) {
          final expiryTime = DateTime.fromMillisecondsSinceEpoch(
            session.expiresAt! * 1000
          );
          final minutesUntilExpiry = expiryTime.difference(DateTime.now()).inMinutes;
          authDebug['minutes_until_expiry'] = minutesUntilExpiry;
          authDebug['session_near_expiry'] = minutesUntilExpiry < 5;
        }
      }
      
      // Test session validation
      authDebug['session_valid'] = await authService.validateSession();
      
      // Check auth headers
      final headers = authService.getAuthHeaders();
      authDebug['has_auth_header'] = headers.containsKey('Authorization');
      authDebug['auth_token_length'] = headers['Authorization']?.length ?? 0;
      
      print('✅ Auth check: ${authDebug['is_authenticated']}');
      print('👤 User ID: ${authDebug['current_user_id']}');
      print('🎫 Session valid: ${authDebug['session_valid']}');
      
    } catch (e) {
      authDebug['error'] = e.toString();
      print('❌ Auth check failed: $e');
    }
    
    return authDebug;
  }
  
  static Map<String, dynamic> _debugAnimalData(
    Animal originalAnimal, 
    Animal updatedAnimal
  ) {
    print('🐄 Checking animal data...');
    
    final dataDebug = <String, dynamic>{};
    
    try {
      dataDebug['original_animal_id'] = originalAnimal.id;
      dataDebug['updated_animal_id'] = updatedAnimal.id;
      dataDebug['user_id_match'] = originalAnimal.userId == updatedAnimal.userId;
      dataDebug['has_animal_id'] = updatedAnimal.id != null && updatedAnimal.id!.isNotEmpty;
      
      // Check for data changes
      final changes = <String, dynamic>{};
      if (originalAnimal.name != updatedAnimal.name) {
        changes['name'] = {
          'old': originalAnimal.name,
          'new': updatedAnimal.name,
        };
      }
      if (originalAnimal.tag != updatedAnimal.tag) {
        changes['tag'] = {
          'old': originalAnimal.tag,
          'new': updatedAnimal.tag,
        };
      }
      if (originalAnimal.species != updatedAnimal.species) {
        changes['species'] = {
          'old': originalAnimal.species.name,
          'new': updatedAnimal.species.name,
        };
      }
      
      dataDebug['changes'] = changes;
      dataDebug['has_changes'] = changes.isNotEmpty;
      
      // Test JSON serialization
      try {
        final jsonData = updatedAnimal.toJson();
        dataDebug['json_serializable'] = true;
        dataDebug['json_size'] = jsonData.toString().length;
      } catch (e) {
        dataDebug['json_serializable'] = false;
        dataDebug['json_error'] = e.toString();
      }
      
      print('🆔 Animal ID: ${dataDebug['has_animal_id']}');
      print('🔄 Has changes: ${dataDebug['has_changes']}');
      print('📄 JSON serializable: ${dataDebug['json_serializable']}');
      
    } catch (e) {
      dataDebug['error'] = e.toString();
      print('❌ Animal data check failed: $e');
    }
    
    return dataDebug;
  }
  
  static Map<String, dynamic> _debugInputSanitization(
    Map<String, String> formValues
  ) {
    print('🧹 Checking input sanitization...');
    
    final sanitizationDebug = <String, dynamic>{};
    
    try {
      for (final entry in formValues.entries) {
        final field = entry.key;
        final value = entry.value;
        
        dynamic sanitizedValue;
        switch (field) {
          case 'name':
            sanitizedValue = InputSanitizer.sanitizeAnimalName(value);
            break;
          case 'tag':
            sanitizedValue = InputSanitizer.sanitizeTagNumber(value);
            break;
          case 'breed':
            sanitizedValue = InputSanitizer.sanitizeBreed(value);
            break;
          case 'description':
            sanitizedValue = InputSanitizer.sanitizeDescription(value);
            break;
          case 'weight':
          case 'price':
            sanitizedValue = InputSanitizer.sanitizeNumeric(value);
            break;
          default:
            sanitizedValue = InputSanitizer.sanitizeText(value);
        }
        
        sanitizationDebug[field] = {
          'original': value,
          'sanitized': sanitizedValue,
          'rejected': sanitizedValue == null && value.isNotEmpty,
        };
        
        if (sanitizedValue == null && value.isNotEmpty) {
          print('⚠️ $field rejected: "$value" -> null');
        }
      }
      
    } catch (e) {
      sanitizationDebug['error'] = e.toString();
      print('❌ Sanitization check failed: $e');
    }
    
    return sanitizationDebug;
  }
  
  static Future<Map<String, dynamic>> _debugDatabasePermissions(
    AnimalService animalService,
    String animalId,
  ) async {
    print('🔒 Checking database permissions...');
    
    final permissionsDebug = <String, dynamic>{};
    
    try {
      // Test if we can read the animal (SELECT permission)
      final animal = await animalService.getAnimalById(animalId);
      permissionsDebug['can_read'] = animal != null;
      permissionsDebug['animal_exists'] = animal != null;
      
      if (animal != null) {
        permissionsDebug['animal_user_id'] = animal.userId;
        // We can't easily test UPDATE permission without actually updating,
        // but we can check if the user_id matches current user
      }
      
      print('📖 Can read: ${permissionsDebug['can_read']}');
      print('🔍 Animal exists: ${permissionsDebug['animal_exists']}');
      
    } catch (e) {
      permissionsDebug['error'] = e.toString();
      permissionsDebug['can_read'] = false;
      print('❌ Permission check failed: $e');
    }
    
    return permissionsDebug;
  }
  
  static Future<Map<String, dynamic>> _debugNetworkConnection(
    AnimalService animalService,
  ) async {
    print('🌐 Checking network connection...');
    
    final networkDebug = <String, dynamic>{};
    
    try {
      // Try a simple read operation to test connectivity
      final startTime = DateTime.now();
      await animalService.getAnimals();
      final endTime = DateTime.now();
      
      networkDebug['connection_working'] = true;
      networkDebug['response_time_ms'] = endTime.difference(startTime).inMilliseconds;
      
      print('✅ Network OK (${networkDebug['response_time_ms']}ms)');
      
    } catch (e) {
      networkDebug['connection_working'] = false;
      networkDebug['error'] = e.toString();
      print('❌ Network check failed: $e');
    }
    
    return networkDebug;
  }
  
  static Map<String, String> _assessIssues(Map<String, dynamic> debugInfo) {
    final issues = <String, String>{};
    
    // Check authentication issues
    final auth = debugInfo['auth'] as Map<String, dynamic>?;
    if (auth != null) {
      if (auth['is_authenticated'] != true) {
        issues['AUTH_001'] = 'User is not authenticated';
      }
      if (auth['session_valid'] != true) {
        issues['AUTH_002'] = 'Session is invalid or expired';
      }
      if (auth['session_near_expiry'] == true) {
        issues['AUTH_003'] = 'Session is close to expiry';
      }
      if (auth['has_auth_header'] != true) {
        issues['AUTH_004'] = 'Missing authentication header';
      }
    }
    
    // Check animal data issues
    final animalData = debugInfo['animal_data'] as Map<String, dynamic>?;
    if (animalData != null) {
      if (animalData['has_animal_id'] != true) {
        issues['DATA_001'] = 'Animal ID is missing or empty';
      }
      if (animalData['user_id_match'] != true) {
        issues['DATA_002'] = 'User ID mismatch between original and updated animal';
      }
      if (animalData['json_serializable'] != true) {
        issues['DATA_003'] = 'Animal data cannot be serialized to JSON';
      }
      if (animalData['has_changes'] != true) {
        issues['DATA_004'] = 'No changes detected to save';
      }
    }
    
    // Check sanitization issues  
    final sanitization = debugInfo['sanitization'] as Map<String, dynamic>?;
    if (sanitization != null) {
      for (final entry in sanitization.entries) {
        if (entry.value is Map && entry.value['rejected'] == true) {
          issues['SANITIZE_001'] = 'Input rejected by sanitizer: ${entry.key}';
        }
      }
    }
    
    // Check permission issues
    final permissions = debugInfo['permissions'] as Map<String, dynamic>?;
    if (permissions != null) {
      if (permissions['can_read'] != true) {
        issues['PERM_001'] = 'Cannot read animal - permission denied';
      }
      if (permissions['animal_exists'] != true) {
        issues['PERM_002'] = 'Animal does not exist or is not accessible';
      }
    }
    
    // Check network issues
    final network = debugInfo['network'] as Map<String, dynamic>?;
    if (network != null) {
      if (network['connection_working'] != true) {
        issues['NET_001'] = 'Network connection failed';
      }
    }
    
    if (issues.isEmpty) {
      print('✅ No obvious issues detected');
    } else {
      print('⚠️ Issues found:');
      for (final entry in issues.entries) {
        print('   ${entry.key}: ${entry.value}');
      }
    }
    
    return issues;
  }
}