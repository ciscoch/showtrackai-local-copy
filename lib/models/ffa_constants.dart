/// FFA (Future Farmers of America) constants and categories
/// Used throughout the application for consistent FFA program compliance

class FFAConstants {
  // FFA Degree Types
  static const List<String> degreeTypes = [
    'Discovery FFA Degree',
    'Greenhand FFA Degree',
    'Chapter FFA Degree',
    'State FFA Degree',
    'American FFA Degree',
  ];

  // SAE (Supervised Agricultural Experience) Types
  static const List<String> saeTypes = [
    'Entrepreneurship SAE',
    'Placement/Internship SAE',
    'Research SAE',
    'Exploratory SAE',
    'School-Based Enterprise SAE',
    'Service Learning SAE',
  ];

  // Evidence Types for FFA Records
  static const List<String> evidenceTypes = [
    'Journal Entry',
    'Photo Documentation',
    'Video Recording',
    'Financial Records',
    'Project Report',
    'Research Paper',
    'Presentation',
    'Certificate/Award',
    'Supervisor Verification',
    'Competition Results',
  ];

  // FFA Standards (Animal Systems focus)
  static const List<String> animalSystemsStandards = [
    'AS.01.01 - Analyze the role of animals in agriculture',
    'AS.01.02 - Evaluate the development and implications of animal agriculture',
    'AS.02.01 - Analyze the relationship between nutrition and health',
    'AS.02.02 - Evaluate nutrient requirements of animals',
    'AS.02.03 - Design feeding programs',
    'AS.03.01 - Evaluate the significance of animal genetics',
    'AS.03.02 - Examine the reproductive process of animals',
    'AS.03.03 - Apply scientific principles in the breeding of animals',
    'AS.04.01 - Analyze the importance of animal behavior and animal handling',
    'AS.04.02 - Select and handle animals to achieve desired outcomes',
    'AS.05.01 - Evaluate the importance of correct animal nutrition',
    'AS.05.02 - Examine anatomical structures and their functions',
    'AS.05.03 - Evaluate the growth and development of animals',
    'AS.06.01 - Analyze facilities, equipment, and feed safety',
    'AS.06.02 - Design animal facilities',
    'AS.06.03 - Manage animal facilities',
    'AS.07.01 - Demonstrate animal health maintenance',
    'AS.07.02 - Evaluate animal diseases and veterinary practices',
    'AS.07.03 - Examine animal welfare concerns and solutions',
    'AS.08.01 - Analyze market preparation and marketing strategies',
    'AS.08.02 - Demonstrate livestock selection and evaluation skills',
    'AS.08.03 - Evaluate the marketing of animal products',
  ];

  // Common AET (Agricultural Education Tracking) Skills
  static const List<String> aetSkills = [
    'Animal Selection and Management',
    'Feed Management and Nutrition',
    'Health Care Management',
    'Breeding and Genetics',
    'Record Keeping',
    'Financial Management',
    'Equipment Operation and Maintenance',
    'Facility Management',
    'Marketing and Sales',
    'Leadership Development',
    'Communication Skills',
    'Problem Solving',
    'Critical Thinking',
    'Data Analysis',
    'Research Methods',
    'Safety Practices',
    'Environmental Stewardship',
    'Technology Integration',
    'Project Management',
    'Teamwork and Collaboration',
  ];

  // Competency Levels
  static const List<String> competencyLevels = [
    'Novice',
    'Developing', 
    'Proficient',
    'Advanced',
    'Expert',
  ];
}

/// Journal entry categories for agricultural education
class JournalCategories {
  static const List<String> categories = [
    'daily_care',
    'health_check',
    'feeding',
    'training',
    'show_prep',
    'veterinary',
    'breeding',
    'record_keeping',
    'financial',
    'learning_reflection',
    'project_planning',
    'competition',
    'community_service',
    'leadership_activity',
    'safety_training',
    'research',
  ];

  static const Map<String, String> categoryDisplayNames = {
    'daily_care': 'Daily Care',
    'health_check': 'Health Check',
    'feeding': 'Feeding',
    'training': 'Training',
    'show_prep': 'Show Preparation',
    'veterinary': 'Veterinary Care',
    'breeding': 'Breeding',
    'record_keeping': 'Record Keeping',
    'financial': 'Financial Management',
    'learning_reflection': 'Learning Reflection',
    'project_planning': 'Project Planning',
    'competition': 'Competition',
    'community_service': 'Community Service',
    'leadership_activity': 'Leadership Activity',
    'safety_training': 'Safety Training',
    'research': 'Research',
  };

  static String getDisplayName(String category) {
    return categoryDisplayNames[category] ?? category;
  }
}

/// Quick learning objectives suggestions
class LearningObjectives {
  static const List<String> common = [
    'Improve animal handling skills',
    'Build trust with animal',
    'Learn proper feeding techniques',
    'Develop observation skills',
    'Practice record keeping',
    'Understand animal behavior',
    'Master show techniques',
    'Learn safety procedures',
    'Develop leadership skills',
    'Improve communication abilities',
    'Practice problem-solving',
    'Build financial management skills',
    'Develop time management',
    'Learn equipment operation',
    'Practice data collection',
    'Understand animal nutrition',
    'Master health assessment',
    'Develop breeding knowledge',
    'Learn marketing strategies',
    'Practice teamwork',
  ];

  static List<String> getRandomSuggestions({int count = 5}) {
    final shuffled = List<String>.from(common)..shuffle();
    return shuffled.take(count).toList();
  }
}

/// AET skill categories for organization
class AETSkillCategories {
  static const Map<String, List<String>> categories = {
    'Animal Management': [
      'Animal Selection and Management',
      'Animal Health Care',
      'Animal Nutrition',
      'Animal Breeding',
      'Animal Behavior and Handling',
    ],
    'Technical Skills': [
      'Equipment Operation and Maintenance',
      'Facility Management',
      'Feed Management and Nutrition',
      'Data Analysis',
      'Technology Integration',
    ],
    'Business and Financial': [
      'Record Keeping',
      'Financial Management',
      'Marketing and Sales',
      'Project Management',
      'Business Planning',
    ],
    'Leadership and Communication': [
      'Leadership Development',
      'Communication Skills',
      'Teamwork and Collaboration',
      'Public Speaking',
      'Mentoring',
    ],
    'Academic and Research': [
      'Research Methods',
      'Critical Thinking',
      'Problem Solving',
      'Scientific Method',
      'Data Collection',
    ],
    'Safety and Environment': [
      'Safety Practices',
      'Environmental Stewardship',
      'Risk Management',
      'Emergency Procedures',
      'Regulatory Compliance',
    ],
  };

  static List<String> getAllSkills() {
    return categories.values.expand((skills) => skills).toList();
  }

  static List<String> getSkillsByCategory(String category) {
    return categories[category] ?? [];
  }

  static String? getCategoryForSkill(String skill) {
    for (final entry in categories.entries) {
      if (entry.value.contains(skill)) {
        return entry.key;
      }
    }
    return null;
  }
}