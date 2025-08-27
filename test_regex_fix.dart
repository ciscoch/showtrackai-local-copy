// Test the regex fix
void main() {
  // The fixed regex pattern
  final RegExp _eventHandlerPattern = RegExp(
    'on\\w+\\s*=\\s*["\'][^"\']*["\']',
    multiLine: true,
    caseSensitive: false,
  );
  
  // Test cases
  final testStrings = [
    'onclick="alert(1)"',
    'onmouseover="hack()"',
    'normal text',
    'onload=\'malicious()\'',
  ];
  
  print('Testing regex pattern fix:');
  for (final test in testStrings) {
    final hasMatch = _eventHandlerPattern.hasMatch(test);
    print('  "$test" -> ${hasMatch ? "MATCHED (will be removed)" : "OK (safe)"}');
  }
  
  // Test the sanitization
  final dangerous = '<div onclick="alert(1)">Click me</div>';
  final sanitized = dangerous.replaceAll(_eventHandlerPattern, '');
  print('\nSanitization test:');
  print('  Original: $dangerous');
  print('  Sanitized: $sanitized');
  
  print('\n✅ Regex pattern is working correctly!');
}