// Input Sanitization Test Suite
// Add this to your test files or run in debug console

import '../lib/utils/input_sanitizer.dart';

void testInputSanitization() {
  print('Testing Input Sanitization...');
  
  final testCases = {
    // Animal names
    'name_valid': 'Bessie Mae',
    'name_with_apostrophe': "O'Malley",
    'name_with_hyphen': 'Mary-Jane',
    'name_with_numbers': 'Cow123',
    'name_with_special_chars': 'Bessie<script>alert("xss")</script>',
    'name_too_short': 'A',
    'name_too_long': 'A' * 60,
    
    // Tag numbers
    'tag_valid': 'A123',
    'tag_with_hyphen': 'A-123-B',
    'tag_with_spaces': 'A 123',
    'tag_with_special': 'A123!@#',
    
    // Descriptions
    'desc_normal': 'Good quality heifer with excellent bloodlines.',
    'desc_with_sql': 'Nice cow; DROP TABLE animals;',
    'desc_with_html': 'Description with <b>bold</b> text',
    
    // Numeric values
    'weight_valid': '250.5',
    'weight_invalid': '250.5.5',
    'weight_negative': '-50',
    'weight_too_high': '10000',
  };
  
  for (final entry in testCases.entries) {
    final field = entry.key;
    final value = entry.value;
    
    dynamic result;
    if (field.startsWith('name_')) {
      result = InputSanitizer.sanitizeAnimalName(value);
    } else if (field.startsWith('tag_')) {
      result = InputSanitizer.sanitizeTagNumber(value);
    } else if (field.startsWith('desc_')) {
      result = InputSanitizer.sanitizeDescription(value);
    } else if (field.startsWith('weight_')) {
      result = InputSanitizer.sanitizeNumeric(value, min: 0.1, max: 5000);
    }
    
    print('$field: "$value" -> $result');
    
    if (result == null && value.isNotEmpty) {
      print('  ⚠️ Valid input was rejected!');
    }
  }
}
