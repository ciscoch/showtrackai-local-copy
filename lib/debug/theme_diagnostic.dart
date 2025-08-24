import 'package:flutter/material.dart';

class ThemeDiagnosticScreen extends StatelessWidget {
  const ThemeDiagnosticScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Theme Diagnostic'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
      ),
      body: Container(
        color: Colors.white,
        padding: const EdgeInsets.all(16),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Success indicator
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.green,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  '✅ FLUTTER IS WORKING! If you see this, the issue is not with Flutter itself.',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              
              const SizedBox(height: 20),
              
              // Theme Information
              _buildSection('Theme Information', [
                _buildInfoRow('Brightness', theme.brightness.toString()),
                _buildInfoRow('Scaffold Background', colorScheme.surface.toString()),
                _buildInfoRow('Primary Color', colorScheme.primary.toString()),
                _buildInfoRow('Background Color', colorScheme.surface.toString()),
                _buildInfoRow('Surface Color', colorScheme.surface.toString()),
              ]),
              
              const SizedBox(height: 20),
              
              // Color Scheme Display
              _buildSection('Color Scheme', [
                _buildColorBox('Primary', colorScheme.primary),
                _buildColorBox('Secondary', colorScheme.secondary),
                _buildColorBox('Surface', colorScheme.surface),
                _buildColorBox('Error', colorScheme.error),
                _buildColorBox('Background', colorScheme.surface),
                _buildColorBox('On Primary', colorScheme.onPrimary),
                _buildColorBox('On Secondary', colorScheme.onSecondary),
                _buildColorBox('On Surface', colorScheme.onSurface),
              ]),
              
              const SizedBox(height: 20),
              
              // Widget Tests
              _buildSection('Widget Visibility Tests', [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.red,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    'RED CONTAINER - Should be clearly visible',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.blue,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    'BLUE CONTAINER - Should be clearly visible',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'THEME PRIMARY CONTAINER - Using theme.colorScheme.primary',
                    style: TextStyle(
                      color: theme.colorScheme.onPrimary, 
                      fontWeight: FontWeight.bold
                    ),
                  ),
                ),
              ]),
              
              const SizedBox(height: 20),
              
              // Potential Issues
              _buildSection('Potential Issues Check', [
                _buildIssueCheck(
                  'Same background and text color?',
                  colorScheme.surface == colorScheme.onSurface,
                ),
                _buildIssueCheck(
                  'Transparent backgrounds?',
                  colorScheme.surface.opacity < 1.0,
                ),
                _buildIssueCheck(
                  'Dark theme in light mode?',
                  theme.brightness == Brightness.dark && 
                  colorScheme.surface.computeLuminance() < 0.5,
                ),
              ]),
              
              const SizedBox(height: 20),
              
              // Action Buttons
              _buildSection('Test Actions', [
                ElevatedButton(
                  onPressed: () {
                    print('🎨 Theme diagnostic button pressed');
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Flutter interaction working!'),
                        backgroundColor: Colors.green,
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Test Flutter Interaction'),
                ),
                const SizedBox(height: 10),
                OutlinedButton(
                  onPressed: () {
                    print('🔄 Requesting full screen refresh');
                    // Force a rebuild
                    (context as Element).markNeedsBuild();
                  },
                  child: const Text('Force Screen Refresh'),
                ),
              ]),
            ],
          ),
        ),
      ),
    );
  }
  
  Widget _buildSection(String title, List<Widget> children) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.black,
            ),
          ),
          const SizedBox(height: 10),
          ...children,
        ],
      ),
    );
  }
  
  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 150,
            child: Text(
              '$label:',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.black,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(color: Colors.black87),
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildColorBox(String label, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 20,
            decoration: BoxDecoration(
              color: color,
              border: Border.all(color: Colors.black),
            ),
          ),
          const SizedBox(width: 10),
          Text(
            '$label: $color',
            style: const TextStyle(color: Colors.black),
          ),
        ],
      ),
    );
  }
  
  Widget _buildIssueCheck(String description, bool hasIssue) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(
            hasIssue ? Icons.warning : Icons.check,
            color: hasIssue ? Colors.red : Colors.green,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              description,
              style: TextStyle(
                color: hasIssue ? Colors.red : Colors.green,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }
}