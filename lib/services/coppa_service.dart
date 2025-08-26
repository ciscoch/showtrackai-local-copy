import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Service for COPPA (Children's Online Privacy Protection Act) compliance
/// Handles age verification and parental consent for users under 13
class CoppaService {
  static final CoppaService _instance = CoppaService._internal();
  factory CoppaService() => _instance;
  CoppaService._internal();
  
  final SupabaseClient _client = Supabase.instance.client;
  
  // COPPA age threshold
  static const int coppaAgeThreshold = 13;
  
  /// Check if user needs parental consent based on age
  Future<bool> requiresParentalConsent(DateTime birthDate) async {
    final age = _calculateAge(birthDate);
    return age < coppaAgeThreshold;
  }
  
  /// Calculate age from birth date
  int _calculateAge(DateTime birthDate) {
    final now = DateTime.now();
    int age = now.year - birthDate.year;
    
    // Adjust if birthday hasn't occurred this year
    if (now.month < birthDate.month ||
        (now.month == birthDate.month && now.day < birthDate.day)) {
      age--;
    }
    
    return age;
  }
  
  /// Update user profile with birth date and check COPPA requirements
  Future<CoppaStatus> updateUserBirthDate({
    required String userId,
    required DateTime birthDate,
    String? parentEmail,
  }) async {
    try {
      final age = _calculateAge(birthDate);
      final isMinor = age < coppaAgeThreshold;
      
      // Update user profile
      await _client.from('user_profiles').upsert({
        'id': userId,
        'birth_date': birthDate.toIso8601String().split('T')[0],
        'parent_email': isMinor ? parentEmail : null,
        'updated_at': DateTime.now().toIso8601String(),
      });
      
      return CoppaStatus(
        isMinor: isMinor,
        age: age,
        requiresConsent: isMinor,
        hasConsent: false, // Will be updated when parent confirms
        parentEmail: parentEmail,
      );
    } catch (e) {
      print('Error updating birth date: $e');
      throw Exception('Failed to update age information');
    }
  }
  
  /// Get COPPA status for current user
  Future<CoppaStatus?> getUserCoppaStatus(String userId) async {
    try {
      final response = await _client
          .from('user_profiles')
          .select('birth_date, parent_email, parent_consent, parent_consent_date')
          .eq('id', userId)
          .maybeSingle();
      
      if (response == null || response['birth_date'] == null) {
        return null;
      }
      
      final birthDate = DateTime.parse(response['birth_date']);
      final age = _calculateAge(birthDate);
      final isMinor = age < coppaAgeThreshold;
      
      return CoppaStatus(
        isMinor: isMinor,
        age: age,
        requiresConsent: isMinor,
        hasConsent: response['parent_consent'] ?? false,
        parentEmail: response['parent_email'],
        consentDate: response['parent_consent_date'] != null
            ? DateTime.parse(response['parent_consent_date'])
            : null,
      );
    } catch (e) {
      print('Error getting COPPA status: $e');
      return null;
    }
  }
  
  /// Send parental consent request email
  Future<void> sendParentalConsentRequest({
    required String userId,
    required String parentEmail,
    required String childName,
  }) async {
    try {
      // In production, this would send an actual email
      // For now, we'll just log the consent request
      print('📧 Sending parental consent request to: $parentEmail');
      print('For child: $childName (User ID: $userId)');
      
      // Store the consent request in database
      await _client.from('parental_consent_requests').insert({
        'user_id': userId,
        'parent_email': parentEmail,
        'child_name': childName,
        'request_date': DateTime.now().toIso8601String(),
        'status': 'pending',
      });
      
      // TODO: Integrate with email service (SendGrid, Mailgun, etc.)
    } catch (e) {
      print('Error sending consent request: $e');
      throw Exception('Failed to send parental consent request');
    }
  }
  
  /// Verify parental consent token (from email link)
  Future<bool> verifyParentalConsent({
    required String userId,
    required String consentToken,
  }) async {
    try {
      // Verify the consent token
      final response = await _client
          .from('parental_consent_requests')
          .select()
          .eq('user_id', userId)
          .eq('consent_token', consentToken)
          .eq('status', 'pending')
          .maybeSingle();
      
      if (response == null) {
        return false;
      }
      
      // Update consent status
      await _client.from('parental_consent_requests').update({
        'status': 'approved',
        'consent_date': DateTime.now().toIso8601String(),
      }).eq('id', response['id']);
      
      // Update user profile with consent
      await _client.from('user_profiles').update({
        'parent_consent': true,
        'parent_consent_date': DateTime.now().toIso8601String(),
      }).eq('id', userId);
      
      return true;
    } catch (e) {
      print('Error verifying consent: $e');
      return false;
    }
  }
  
  /// Check if user can access feature based on COPPA status
  bool canAccessFeature({
    required CoppaStatus coppaStatus,
    required CoppaFeature feature,
  }) {
    // If not a minor, all features are accessible
    if (!coppaStatus.isMinor) {
      return true;
    }
    
    // If minor without consent, only allow basic features
    if (!coppaStatus.hasConsent) {
      return feature.allowedWithoutConsent;
    }
    
    // Minor with consent can access age-appropriate features
    return feature.allowedWithConsent;
  }
  
  /// Get restricted features message for minors
  String getRestrictedFeatureMessage(CoppaFeature feature) {
    if (feature.allowedWithoutConsent) {
      return 'This feature is available to all users';
    } else if (feature.allowedWithConsent) {
      return 'This feature requires parental consent for users under 13';
    } else {
      return 'This feature is not available for users under 13';
    }
  }
}

/// COPPA compliance status for a user
class CoppaStatus {
  final bool isMinor;
  final int age;
  final bool requiresConsent;
  final bool hasConsent;
  final String? parentEmail;
  final DateTime? consentDate;
  
  const CoppaStatus({
    required this.isMinor,
    required this.age,
    required this.requiresConsent,
    required this.hasConsent,
    this.parentEmail,
    this.consentDate,
  });
  
  bool get isCompliant => !requiresConsent || hasConsent;
  
  String get statusMessage {
    if (!isMinor) {
      return 'Full access granted';
    } else if (hasConsent) {
      return 'Parental consent verified';
    } else {
      return 'Parental consent required';
    }
  }
}

/// Features that may have COPPA restrictions
class CoppaFeature {
  final String name;
  final String description;
  final bool allowedWithoutConsent;
  final bool allowedWithConsent;
  
  const CoppaFeature({
    required this.name,
    required this.description,
    required this.allowedWithoutConsent,
    required this.allowedWithConsent,
  });
  
  // Common feature definitions
  static const CoppaFeature journalEntry = CoppaFeature(
    name: 'Journal Entry',
    description: 'Create and view journal entries',
    allowedWithoutConsent: false,
    allowedWithConsent: true,
  );
  
  static const CoppaFeature animalManagement = CoppaFeature(
    name: 'Animal Management',
    description: 'Add and manage animals',
    allowedWithoutConsent: false,
    allowedWithConsent: true,
  );
  
  static const CoppaFeature photoUpload = CoppaFeature(
    name: 'Photo Upload',
    description: 'Upload photos of animals',
    allowedWithoutConsent: false,
    allowedWithConsent: true,
  );
  
  static const CoppaFeature locationSharing = CoppaFeature(
    name: 'Location Sharing',
    description: 'Share location for weather data',
    allowedWithoutConsent: false,
    allowedWithConsent: true,
  );
  
  static const CoppaFeature socialFeatures = CoppaFeature(
    name: 'Social Features',
    description: 'Interact with other users',
    allowedWithoutConsent: false,
    allowedWithConsent: false, // Not allowed even with consent for under 13
  );
  
  static const CoppaFeature viewOnlyMode = CoppaFeature(
    name: 'View Only Mode',
    description: 'View educational content only',
    allowedWithoutConsent: true,
    allowedWithConsent: true,
  );
}