import 'package:flutter/material.dart';

/// FFA Degree Progress Card with mobile-optimized layout
/// Fixes: Text truncation, spacing issues, touch targets, responsive design
class FFADegreeProgressCard extends StatelessWidget {
  final String degreeType;
  final int progressPercentage;
  final String progressText;
  final String detailText;
  final Color progressColor;
  final IconData icon;
  final VoidCallback? onTap;

  const FFADegreeProgressCard({
    Key? key,
    required this.degreeType,
    required this.progressPercentage,
    required this.progressText,
    required this.detailText,
    required this.progressColor,
    required this.icon,
    this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Get screen dimensions for responsive design
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 360;
    
    return Card(
      elevation: 3,
      margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          // Responsive padding that scales with screen size
          padding: EdgeInsets.all(isSmallScreen ? 12 : 16),
          constraints: const BoxConstraints(
            minHeight: 140, // Ensure minimum height for content
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header Row - Icon + Title
              Row(
                children: [
                  // Icon container with proper sizing
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: progressColor.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      icon,
                      color: progressColor,
                      size: isSmallScreen ? 18 : 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  
                  // Title with flexible text sizing
                  Expanded(
                    child: Text(
                      degreeType,
                      style: TextStyle(
                        fontSize: isSmallScreen ? 13 : 15,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                        height: 1.2, // Line height for better readability
                      ),
                      maxLines: 2, // Allow wrapping if needed
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              
              const SizedBox(height: 16),
              
              // Progress Section
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Progress Percentage - Prominent Display
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '$progressPercentage%',
                        style: TextStyle(
                          fontSize: isSmallScreen ? 28 : 32,
                          fontWeight: FontWeight.bold,
                          color: progressColor,
                          height: 1.0,
                        ),
                      ),
                      const SizedBox(width: 8),
                      
                      // Progress text with proper sizing
                      Expanded(
                        child: Text(
                          progressText,
                          style: TextStyle(
                            fontSize: isSmallScreen ? 12 : 13,
                            color: Colors.grey[600],
                            fontWeight: FontWeight.w500,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 12),
                  
                  // Progress Bar
                  Container(
                    height: 6,
                    decoration: BoxDecoration(
                      color: Colors.grey[200],
                      borderRadius: BorderRadius.circular(3),
                    ),
                    child: FractionallySizedBox(
                      alignment: Alignment.centerLeft,
                      widthFactor: progressPercentage / 100,
                      child: Container(
                        decoration: BoxDecoration(
                          color: progressColor,
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 12),
                  
                  // Detail text with proper wrapping
                  Text(
                    detailText,
                    style: TextStyle(
                      fontSize: isSmallScreen ? 11 : 12,
                      color: Colors.grey[600],
                      height: 1.3,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
              
              const Spacer(),
              
              // Action indicator (optional)
              if (onTap != null)
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Icon(
                      Icons.arrow_forward_ios,
                      size: 12,
                      color: Colors.grey[400],
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Collection of FFA Degree Cards with responsive grid layout
class FFADegreesSection extends StatelessWidget {
  const FFADegreesSection({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    
    // Responsive grid configuration
    int crossAxisCount;
    double childAspectRatio;
    
    if (screenWidth < 320) {
      // Very small phones
      crossAxisCount = 1;
      childAspectRatio = 1.8;
    } else if (screenWidth < 480) {
      // Normal phones (iPhone, most Android)
      crossAxisCount = 2;
      childAspectRatio = 0.85;
    } else if (screenWidth < 768) {
      // Large phones / small tablets
      crossAxisCount = 2;
      childAspectRatio = 1.0;
    } else {
      // Tablets and larger
      crossAxisCount = 3;
      childAspectRatio = 1.1;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section Header
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
          child: Row(
            children: [
              const Icon(
                Icons.school,
                color: Color(0xFF4CAF50),
                size: 24,
              ),
              const SizedBox(width: 12),
              const Text(
                'FFA Degree Progress',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              const Spacer(),
              TextButton(
                onPressed: () {
                  Navigator.pushNamed(context, '/ffa-progress');
                },
                child: const Text(
                  'View All',
                  style: TextStyle(
                    color: Color(0xFF4CAF50),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
        
        // Responsive Grid of Degree Cards
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: GridView.count(
            crossAxisCount: crossAxisCount,
            childAspectRatio: childAspectRatio,
            crossAxisSpacing: 8,
            mainAxisSpacing: 8,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            children: [
              // Greenhand Degree
              FFADegreeProgressCard(
                degreeType: 'Greenhand Degree',
                progressPercentage: 11,
                progressText: 'In Progress',
                detailText: '2/18 requirements completed',
                progressColor: const Color(0xFF4CAF50),
                icon: Icons.eco,
                onTap: () => _navigateToDegreDetail(context, 'greenhand'),
              ),
              
              // Chapter Degree
              FFADegreeProgressCard(
                degreeType: 'Chapter Degree',
                progressPercentage: 2,
                progressText: 'Getting Started',
                detailText: '1/15 requirements completed',
                progressColor: const Color(0xFF2196F3),
                icon: Icons.group,
                onTap: () => _navigateToDegreDetail(context, 'chapter'),
              ),
              
              // State Degree
              FFADegreeProgressCard(
                degreeType: 'State Degree',
                progressPercentage: 20,
                progressText: 'Active',
                detailText: '3/15 skills demonstrated',
                progressColor: const Color(0xFFFF9800),
                icon: Icons.star,
                onTap: () => _navigateToDegreDetail(context, 'state'),
              ),
              
              // American Degree
              FFADegreeProgressCard(
                degreeType: 'American Degree',
                progressPercentage: 0,
                progressText: 'Future Goal',
                detailText: '\$2,500 SAE earnings required',
                progressColor: const Color(0xFFE91E63),
                icon: Icons.flag,
                onTap: () => _navigateToDegreDetail(context, 'american'),
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _navigateToDegreDetail(BuildContext context, String degreeType) {
    Navigator.pushNamed(
      context,
      '/ffa-degree-detail',
      arguments: degreeType,
    );
  }
}