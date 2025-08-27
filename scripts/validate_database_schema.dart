#!/usr/bin/env dart

/// Database Schema Validator for ShowTrackAI
/// 
/// This script validates that the production database schema matches
/// what the Flutter application expects, preventing runtime errors.
/// 
/// Usage: dart scripts/validate_database_schema.dart

import 'dart:io';
import 'package:supabase/supabase.dart';

// Expected schema definition based on Animal model
const Map<String, Map<String, dynamic>> expectedSchema = {
  'animals': {
    'columns': {
      'id': {'type': 'uuid', 'nullable': false},
      'user_id': {'type': 'uuid', 'nullable': false},
      'name': {'type': 'text', 'nullable': false},
      'tag': {'type': 'text', 'nullable': true},
      'species': {'type': 'text', 'nullable': false},
      'breed': {'type': 'text', 'nullable': true},
      'gender': {'type': 'text', 'nullable': true},
      'birth_date': {'type': 'date', 'nullable': true},
      'purchase_weight': {'type': 'numeric', 'nullable': true},
      'current_weight': {'type': 'numeric', 'nullable': true},
      'purchase_date': {'type': 'date', 'nullable': true},
      'purchase_price': {'type': 'numeric', 'nullable': true},
      'description': {'type': 'text', 'nullable': true},
      'photo_url': {'type': 'text', 'nullable': true},
      'metadata': {'type': 'jsonb', 'nullable': true},
      'created_at': {'type': 'timestamp', 'nullable': false},
      'updated_at': {'type': 'timestamp', 'nullable': false},
    }
  },
  'weights': {
    'columns': {
      'id': {'type': 'uuid', 'nullable': false},
      'animal_id': {'type': 'uuid', 'nullable': false},
      'weight': {'type': 'numeric', 'nullable': false},
      'weight_date': {'type': 'date', 'nullable': false},
      'notes': {'type': 'text', 'nullable': true},
      'created_at': {'type': 'timestamp', 'nullable': false},
    }
  },
  'health_records': {
    'columns': {
      'id': {'type': 'uuid', 'nullable': false},
      'animal_id': {'type': 'uuid', 'nullable': false},
      'record_date': {'type': 'date', 'nullable': false},
      'type': {'type': 'text', 'nullable': false},
      'description': {'type': 'text', 'nullable': true},
      'treatment': {'type': 'text', 'nullable': true},
      'veterinarian': {'type': 'text', 'nullable': true},
      'cost': {'type': 'numeric', 'nullable': true},
      'follow_up_required': {'type': 'boolean', 'nullable': true},
      'created_at': {'type': 'timestamp', 'nullable': false},
    }
  },
  'journal_entries': {
    'columns': {
      'id': {'type': 'uuid', 'nullable': false},
      'user_id': {'type': 'uuid', 'nullable': false},
      'title': {'type': 'text', 'nullable': false},
      'content': {'type': 'text', 'nullable': true},
      'entry_date': {'type': 'date', 'nullable': false},
      'category': {'type': 'text', 'nullable': true},
      'tags': {'type': 'text[]', 'nullable': true},
      'animal_ids': {'type': 'uuid[]', 'nullable': true},
      'created_at': {'type': 'timestamp', 'nullable': false},
      'updated_at': {'type': 'timestamp', 'nullable': false},
    }
  }
};

class SchemaValidator {
  final SupabaseClient supabase;
  final List<String> errors = [];
  final List<String> warnings = [];
  
  SchemaValidator(this.supabase);
  
  Future<bool> validate() async {
    print('🔍 Starting database schema validation...\n');
    
    for (final tableName in expectedSchema.keys) {
      await validateTable(tableName, expectedSchema[tableName]!);
    }
    
    return reportResults();
  }
  
  Future<void> validateTable(String tableName, Map<String, dynamic> tableSchema) async {
    print('Checking table: $tableName');
    
    try {
      // Query to get column information
      final result = await supabase.rpc('get_table_schema', params: {
        'table_name': tableName,
      }).execute();
      
      if (result.error != null) {
        // Fallback: Try a simple query to check if table exists
        try {
          await supabase.from(tableName).select('id').limit(1).execute();
          warnings.add('Table $tableName exists but cannot validate schema details');
        } catch (e) {
          errors.add('Table $tableName does not exist or is not accessible');
        }
        return;
      }
      
      final actualColumns = Map<String, dynamic>.from(result.data as Map);
      final expectedColumns = tableSchema['columns'] as Map<String, dynamic>;
      
      // Check for missing columns
      for (final columnName in expectedColumns.keys) {
        if (!actualColumns.containsKey(columnName)) {
          errors.add('❌ Missing column: $tableName.$columnName');
        }
      }
      
      // Check for unexpected columns (informational)
      for (final columnName in actualColumns.keys) {
        if (!expectedColumns.containsKey(columnName)) {
          warnings.add('⚠️  Unexpected column: $tableName.$columnName');
        }
      }
      
      print('  ✅ Table $tableName validated\n');
      
    } catch (e) {
      errors.add('Failed to validate table $tableName: $e');
    }
  }
  
  bool reportResults() {
    print('\n' + '=' * 60);
    print('VALIDATION RESULTS');
    print('=' * 60);
    
    if (errors.isEmpty && warnings.isEmpty) {
      print('\n✅ SUCCESS: Database schema matches application expectations!');
      return true;
    }
    
    if (errors.isNotEmpty) {
      print('\n❌ ERRORS FOUND (${errors.length}):');
      for (final error in errors) {
        print('  $error');
      }
    }
    
    if (warnings.isNotEmpty) {
      print('\n⚠️  WARNINGS (${warnings.length}):');
      for (final warning in warnings) {
        print('  $warning');
      }
    }
    
    if (errors.isNotEmpty) {
      print('\n🔧 FIX REQUIRED:');
      print('  Run the migration: supabase/migrations/20250227_fix_animals_schema_complete.sql');
      print('  This will add all missing columns and fix the schema.');
    }
    
    print('\n' + '=' * 60);
    
    return errors.isEmpty;
  }
}

// Alternative validation using raw SQL query
Future<bool> validateWithSQL(SupabaseClient supabase) async {
  const query = '''
    SELECT 
      t.table_name,
      t.column_name,
      t.data_type,
      t.is_nullable
    FROM information_schema.columns t
    WHERE t.table_schema = 'public'
    AND t.table_name IN ('animals', 'weights', 'health_records', 'journal_entries')
    ORDER BY t.table_name, t.ordinal_position;
  ''';
  
  try {
    final result = await supabase.rpc('exec_sql', params: {'query': query}).execute();
    
    if (result.data != null) {
      print('\nActual database schema:');
      print(result.data);
      return true;
    }
  } catch (e) {
    print('Could not execute direct SQL validation: $e');
  }
  
  return false;
}

void main() async {
  // Get Supabase credentials from environment or command line
  final supabaseUrl = Platform.environment['SUPABASE_URL'] ?? 
    'https://zifbuzsdhparxlhsifdi.supabase.co';
  final supabaseAnonKey = Platform.environment['SUPABASE_ANON_KEY'] ?? 
    'YOUR_ANON_KEY_HERE';
  
  if (supabaseAnonKey == 'YOUR_ANON_KEY_HERE') {
    print('❌ ERROR: Please set SUPABASE_ANON_KEY environment variable');
    print('Example: SUPABASE_ANON_KEY=your_key dart scripts/validate_database_schema.dart');
    exit(1);
  }
  
  print('🚀 ShowTrackAI Database Schema Validator\n');
  print('Connecting to: $supabaseUrl');
  print('=' * 60 + '\n');
  
  final supabase = SupabaseClient(supabaseUrl, supabaseAnonKey);
  final validator = SchemaValidator(supabase);
  
  try {
    final isValid = await validator.validate();
    
    if (!isValid) {
      // Try alternative validation
      print('\nAttempting alternative validation method...');
      await validateWithSQL(supabase);
    }
    
    exit(isValid ? 0 : 1);
  } catch (e) {
    print('❌ Fatal error: $e');
    exit(1);
  }
}

// Helper RPC function to add to Supabase if needed:
/*
CREATE OR REPLACE FUNCTION get_table_schema(table_name text)
RETURNS TABLE(
  column_name text,
  data_type text,
  is_nullable text
) AS $$
BEGIN
  RETURN QUERY
  SELECT 
    c.column_name::text,
    c.data_type::text,
    c.is_nullable::text
  FROM information_schema.columns c
  WHERE c.table_schema = 'public'
  AND c.table_name = get_table_schema.table_name
  ORDER BY c.ordinal_position;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
*/