import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:convert';

/// Script to verify journal entries persistence implementation
/// Run this to check if all fields are being saved correctly
class JournalPersistenceVerifier {
  static final _supabase = Supabase.instance.client;

  /// Create a test journal entry with ALL fields populated
  static Future<Map<String, dynamic>> createTestJournalEntry() async {
    final testData = {
      'user_id': _supabase.auth.currentUser?.id,
      'title': 'Test Journal Entry - Field Verification',
      'entry_text': 'This is a comprehensive test of all journal fields',
      'entry_date': DateTime.now().toIso8601String(),
      'duration_minutes': 45,
      'category': 'health_check',
      'aet_skills': ['Animal Health Management', 'Record Keeping'],
      'animal_id': null, // Would need a valid animal ID
      'metadata': {
        'source': 'flutter_app',
        'notes': 'Test entry for field verification',
        'feedData': {
          'brand': 'TestBrand',
          'type': 'TestType',
          'amount': 10.5,
          'cost': 25.99,
        },
      },
      'learning_objectives': ['Understand health monitoring', 'Practice record keeping'],
      'learning_outcomes': ['Identified early signs of illness', 'Improved documentation'],
      'challenges_faced': 'Animal was uncooperative during examination',
      'improvements_planned': 'Use better restraint techniques next time',
      'photos': ['photo1.jpg', 'photo2.jpg'],
      'quality_score': 8,
      'ffa_standards': ['AS.07.01', 'AS.07.02'],
      'learning_concepts': ['Animal behavior', 'Health assessment'],
      'competency_level': 'Proficient',
      'ai_insights': {
        'qualityAssessment': {
          'score': 8,
          'justification': 'Good detail and reflection',
        },
      },
      'location_latitude': 41.8781,
      'location_longitude': -87.6298,
      'location_address': 'Chicago, IL',
      'location_name': 'Test Farm',
      'location_city': 'Chicago',
      'location_state': 'IL',
      'weather_temperature': 72.5,
      'weather_condition': 'Partly Cloudy',
      'weather_humidity': 65,
      'weather_wind_speed': 10.2,
      'weather_description': 'Nice day for farm work',
      'attachment_urls': ['doc1.pdf', 'doc2.pdf'],
      'tags': ['health', 'routine', 'morning'],
      'supervisor_id': null,
      'is_public': false,
      'ffa_degree_type': 'Chapter FFA Degree',
      'counts_for_degree': true,
      'sae_type': 'Entrepreneurship',
      'hours_logged': 1.5,
      'financial_value': 150.00,
      'evidence_type': 'Written Documentation',
      'is_synced': true,
      'trace_id': 'test_trace_${DateTime.now().millisecondsSinceEpoch}',
    };

    return testData;
  }

  /// Verify which fields are actually saved to the database
  static Future<void> verifyFieldPersistence() async {
    print('🔍 Journal Persistence Verification Starting...\n');
    print('=' * 60);

    try {
      // 1. Create test entry
      print('📝 Creating test journal entry with all fields...');
      final testData = await createTestJournalEntry();
      
      // 2. Insert into database
      final response = await _supabase
          .from('journal_entries')
          .insert(testData)
          .select()
          .single();

      print('✅ Entry created successfully!\n');
      
      // 3. Verify each field
      print('🔍 Verifying field persistence:\n');
      
      final fieldsToCheck = [
        // Core fields
        'id', 'user_id', 'title', 'entry_text',
        'entry_date', 'duration_minutes', 'category',
        // Skills and standards
        'aet_skills', 'ffa_standards', 'learning_objectives',
        'learning_outcomes', 'learning_concepts',
        // Content fields
        'challenges_faced', 'improvements_planned',
        'quality_score', 'competency_level',
        // Location fields
        'location_latitude', 'location_longitude',
        'location_address', 'location_name',
        'location_city', 'location_state',
        // Weather fields
        'weather_temperature', 'weather_condition',
        'weather_humidity', 'weather_wind_speed',
        'weather_description',
        // FFA and SAE fields
        'ffa_degree_type', 'counts_for_degree',
        'sae_type', 'hours_logged', 'financial_value',
        'evidence_type',
        // Metadata
        'metadata', 'trace_id', 'is_synced',
        // Arrays
        'photos', 'attachment_urls', 'tags',
      ];

      int savedCount = 0;
      int missingCount = 0;
      List<String> missingFields = [];

      for (String field in fieldsToCheck) {
        if (response.containsKey(field) && response[field] != null) {
          print('✅ $field: SAVED');
          savedCount++;
        } else {
          print('❌ $field: NOT SAVED or NULL');
          missingCount++;
          missingFields.add(field);
        }
      }

      print('\n' + '=' * 60);
      print('📊 VERIFICATION SUMMARY:');
      print('=' * 60);
      print('✅ Fields saved: $savedCount/${fieldsToCheck.length}');
      print('❌ Fields missing: $missingCount/${fieldsToCheck.length}');
      
      if (missingFields.isNotEmpty) {
        print('\n⚠️  Missing fields that need database schema update:');
        for (String field in missingFields) {
          print('   - $field');
        }
        print('\n💡 Run the migration: 20250202_fix_journal_entries_field_mapping.sql');
      } else {
        print('\n🎉 All fields are properly persisted!');
      }

      // 4. Check metadata structure
      print('\n📦 Checking metadata structure:');
      if (response['metadata'] != null) {
        final metadata = response['metadata'];
        print('   Source: ${metadata['source'] ?? 'NOT SET'}');
        print('   Notes: ${metadata['notes'] ?? 'NOT SET'}');
        print('   Feed Data: ${metadata['feedData'] != null ? 'PRESENT' : 'NOT SET'}');
      }

      // 5. Clean up test entry
      await _supabase
          .from('journal_entries')
          .delete()
          .eq('id', response['id']);
      
      print('\n🧹 Test entry cleaned up');
      
    } catch (e) {
      print('❌ Error during verification: $e');
      print('\n💡 This might indicate missing columns in the database.');
      print('   Run the migration script to add missing fields.');
    }

    print('\n' + '=' * 60);
    print('✅ Verification complete!');
  }

  /// Check database schema
  static Future<void> checkDatabaseSchema() async {
    print('\n📋 Checking database schema for journal_entries table:\n');
    
    try {
      // Query to get column information
      final result = await _supabase.rpc('get_table_columns', params: {
        'table_name': 'journal_entries'
      }).catchError((e) {
        print('Note: get_table_columns function may not exist. Attempting direct query...');
        return null;
      });

      if (result != null) {
        print('Columns in journal_entries table:');
        for (var col in result) {
          print('   - ${col['column_name']} (${col['data_type']})');
        }
      }
    } catch (e) {
      print('Could not query schema directly. Use Supabase dashboard to verify columns.');
    }
  }
}

// Main execution
void main() async {
  print('🚀 ShowTrackAI Journal Persistence Verification\n');
  
  // Initialize Supabase if needed
  if (Supabase.instance.client.auth.currentUser == null) {
    print('⚠️  Please ensure you are logged in to run this verification.');
    print('   Run this from within the app or provide authentication.');
    return;
  }

  // Run verification
  await JournalPersistenceVerifier.verifyFieldPersistence();
  
  // Optional: Check schema
  await JournalPersistenceVerifier.checkDatabaseSchema();
}