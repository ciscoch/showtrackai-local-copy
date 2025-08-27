import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../models/ffa_constants.dart';

/// FFA Degrees Section widget for the dashboard
/// Displays progress toward different FFA degree levels
class FFADegreesSection extends StatelessWidget {
  const FFADegreesSection({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'FFA Degree Progress',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 16),
          
          // Degree Progress Cards
          Column(
            children: [
              _buildDegreeCard(
                context,
                'Greenhand FFA Degree',
                'Complete foundational requirements',
                0.75,
                AppTheme.primaryGreen,
                Icons.eco,
              ),
              const SizedBox(height: 12),
              _buildDegreeCard(
                context,
                'Chapter FFA Degree',
                'Advance your skills and involvement',
                0.35,
                AppTheme.accentBlue,
                Icons.school,
              ),
              const SizedBox(height: 12),
              _buildDegreeCard(
                context,
                'State FFA Degree',
                'Demonstrate state-level excellence',
                0.15,
                AppTheme.accentOrange,
                Icons.star_outline,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDegreeCard(
    BuildContext context,
    String title,
    String subtitle,
    double progress,
    Color color,
    IconData icon,
  ) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        onTap: () {
          // Navigate to degree details/requirements
          Navigator.pushNamed(context, '/ffa/degrees');
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(icon, color: color, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        Text(
                          subtitle,
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    '${(progress * 100).toInt()}%',
                    style: TextStyle(
                      color: color,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: progress,
                  backgroundColor: color.withOpacity(0.1),
                  valueColor: AlwaysStoppedAnimation<Color>(color),
                  minHeight: 6,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}