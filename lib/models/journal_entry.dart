class JournalEntry {
  final String? id;
  final String userId;
  final String title;
  final String description;
  final DateTime date;
  final int duration;
  final String category;
  final List<String> aetSkills;
  final String? animalId;
  final FeedData? feedData;
  final List<String>? objectives;
  final List<String>? learningOutcomes;
  final String? challenges;
  final String? improvements;
  final List<String>? photos;
  final int? qualityScore;
  final List<String>? ffaStandards;
  final List<String>? educationalConcepts;
  final String? competencyLevel;
  final AIInsights? aiInsights;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  
  // Agricultural specific fields
  final LocationData? locationData;
  final WeatherData? weatherData;
  final List<String>? attachmentUrls;
  final List<String>? tags;
  final String? supervisorId;
  final bool isPublic;
  final CompetencyTracking? competencyTracking;
  
  // FFA specific fields
  final String? ffaDegreeType;
  final bool countsForDegree;
  final String? saType; // SAE Type
  final double? hoursLogged;
  final double? financialValue;
  final String? evidenceType;
  
  // Offline sync fields
  final bool isSynced;
  final DateTime? lastSyncAttempt;
  final String? syncError;

  JournalEntry({
    this.id,
    required this.userId,
    required this.title,
    required this.description,
    required this.date,
    required this.duration,
    required this.category,
    required this.aetSkills,
    this.animalId,
    this.feedData,
    this.objectives,
    this.learningOutcomes,
    this.challenges,
    this.improvements,
    this.photos,
    this.qualityScore,
    this.ffaStandards,
    this.educationalConcepts,
    this.competencyLevel,
    this.aiInsights,
    this.createdAt,
    this.updatedAt,
    // New fields
    this.locationData,
    this.weatherData,
    this.attachmentUrls,
    this.tags,
    this.supervisorId,
    this.isPublic = false,
    this.competencyTracking,
    this.ffaDegreeType,
    this.countsForDegree = false,
    this.saType,
    this.hoursLogged,
    this.financialValue,
    this.evidenceType,
    this.isSynced = false,
    this.lastSyncAttempt,
    this.syncError,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'user_id': userId,
        'title': title,
        'description': description,
        'entry_text': description,
        'entry_date': date.toIso8601String(),
        'duration_minutes': duration,
        'category': category,
        'aet_skills': aetSkills,
        'animal_id': animalId,
        'metadata': {
          if (feedData != null) 'feedData': feedData!.toJson(),
          if (competencyTracking != null) 'competencyTracking': competencyTracking!.toJson(),
        },
        'learning_objectives': objectives,
        'learning_outcomes': learningOutcomes,
        'challenges_faced': challenges,
        'improvements_planned': improvements,
        'photos': photos,
        'quality_score': qualityScore,
        'ffa_standards': ffaStandards,
        'learning_concepts': educationalConcepts,
        'competency_level': competencyLevel,
        'ai_insights': aiInsights?.toJson(),
        'created_at': createdAt?.toIso8601String(),
        'updated_at': updatedAt?.toIso8601String(),
        // Location data
        'location_latitude': locationData?.latitude,
        'location_longitude': locationData?.longitude,
        'location_address': locationData?.address,
        'location_name': locationData?.name,
        'location_accuracy': locationData?.accuracy,
        'location_captured_at': locationData?.capturedAt?.toIso8601String(),
        // Weather data
        'weather_temperature': weatherData?.temperature,
        'weather_condition': weatherData?.condition,
        'weather_humidity': weatherData?.humidity,
        'weather_wind_speed': weatherData?.windSpeed,
        'weather_description': weatherData?.description,
        // New fields
        'attachment_urls': attachmentUrls,
        'tags': tags,
        'supervisor_id': supervisorId,
        'is_public': isPublic,
        'ffa_degree_type': ffaDegreeType,
        'counts_for_degree': countsForDegree,
        'sae_type': saType,
        'hours_logged': hoursLogged,
        'financial_value': financialValue,
        'evidence_type': evidenceType,
        'is_synced': isSynced,
        'last_sync_attempt': lastSyncAttempt?.toIso8601String(),
        'sync_error': syncError,
      };

  factory JournalEntry.fromJson(Map<String, dynamic> json) => JournalEntry(
        id: json['id'],
        userId: json['user_id'],
        title: json['title'],
        description: json['entry_text'] ?? json['description'],
        date: DateTime.parse(json['entry_date'] ?? json['date']),
        duration: json['duration_minutes'] ?? json['duration'],
        category: json['category'],
        aetSkills: List<String>.from(json['aet_skills'] ?? []),
        animalId: json['animal_id'],
        feedData: json['metadata']?['feedData'] != null
            ? FeedData.fromJson(json['metadata']['feedData'])
            : null,
        objectives: json['learning_objectives'] != null
            ? List<String>.from(json['learning_objectives'])
            : null,
        learningOutcomes: json['learning_outcomes'] != null
            ? List<String>.from(json['learning_outcomes'])
            : null,
        challenges: json['challenges_faced'],
        improvements: json['improvements_planned'],
        photos:
            json['photos'] != null ? List<String>.from(json['photos']) : null,
        qualityScore: json['quality_score'],
        ffaStandards: json['ffa_standards'] != null
            ? List<String>.from(json['ffa_standards'])
            : null,
        educationalConcepts: json['learning_concepts'] != null
            ? List<String>.from(json['learning_concepts'])
            : null,
        competencyLevel: json['competency_level'],
        aiInsights: json['ai_insights'] != null
            ? AIInsights.fromJson(json['ai_insights'])
            : null,
        createdAt: json['created_at'] != null
            ? DateTime.parse(json['created_at'])
            : null,
        updatedAt: json['updated_at'] != null
            ? DateTime.parse(json['updated_at'])
            : null,
        // Location data
        locationData: (json['location_latitude'] != null && json['location_longitude'] != null)
            ? LocationData(
                latitude: json['location_latitude']?.toDouble(),
                longitude: json['location_longitude']?.toDouble(),
                address: json['location_address'],
                name: json['location_name'],
                accuracy: json['location_accuracy']?.toDouble(),
                capturedAt: json['location_captured_at'] != null
                    ? DateTime.parse(json['location_captured_at'])
                    : null,
              )
            : null,
        // Weather data
        weatherData: json['weather_condition'] != null
            ? WeatherData(
                temperature: json['weather_temperature']?.toDouble(),
                condition: json['weather_condition'],
                humidity: json['weather_humidity'],
                windSpeed: json['weather_wind_speed']?.toDouble(),
                description: json['weather_description'],
              )
            : null,
        // New fields
        attachmentUrls: json['attachment_urls'] != null
            ? List<String>.from(json['attachment_urls'])
            : null,
        tags: json['tags'] != null ? List<String>.from(json['tags']) : null,
        supervisorId: json['supervisor_id'],
        isPublic: json['is_public'] ?? false,
        competencyTracking: json['metadata']?['competencyTracking'] != null
            ? CompetencyTracking.fromJson(json['metadata']['competencyTracking'])
            : null,
        ffaDegreeType: json['ffa_degree_type'],
        countsForDegree: json['counts_for_degree'] ?? false,
        saType: json['sae_type'],
        hoursLogged: json['hours_logged']?.toDouble(),
        financialValue: json['financial_value']?.toDouble(),
        evidenceType: json['evidence_type'],
        isSynced: json['is_synced'] ?? false,
        lastSyncAttempt: json['last_sync_attempt'] != null
            ? DateTime.parse(json['last_sync_attempt'])
            : null,
        syncError: json['sync_error'],
      );
}

class FeedData {
  final String brand;
  final String type;
  final double amount;
  final double cost;
  final double? feedConversionRatio;

  FeedData({
    required this.brand,
    required this.type,
    required this.amount,
    required this.cost,
    this.feedConversionRatio,
  });

  Map<String, dynamic> toJson() => {
        'brand': brand,
        'type': type,
        'amount': amount,
        'cost': cost,
        'feedConversionRatio': feedConversionRatio,
      };

  factory FeedData.fromJson(Map<String, dynamic> json) => FeedData(
        brand: json['brand'],
        type: json['type'],
        amount: json['amount'].toDouble(),
        cost: json['cost'].toDouble(),
        feedConversionRatio: json['feedConversionRatio']?.toDouble(),
      );
}

class AIInsights {
  final QualityAssessment qualityAssessment;
  final List<String> ffaStandards;
  final List<String> aetSkillsIdentified;
  final List<String> learningConcepts;
  final String competencyLevel;
  final Feedback feedback;
  final List<String> recommendedActivities;

  AIInsights({
    required this.qualityAssessment,
    required this.ffaStandards,
    required this.aetSkillsIdentified,
    required this.learningConcepts,
    required this.competencyLevel,
    required this.feedback,
    required this.recommendedActivities,
  });

  Map<String, dynamic> toJson() => {
        'qualityAssessment': qualityAssessment.toJson(),
        'ffaStandards': ffaStandards,
        'aetSkillsIdentified': aetSkillsIdentified,
        'learningConcepts': learningConcepts,
        'competencyLevel': competencyLevel,
        'feedback': feedback.toJson(),
        'recommendedActivities': recommendedActivities,
      };

  factory AIInsights.fromJson(Map<String, dynamic> json) => AIInsights(
        qualityAssessment:
            QualityAssessment.fromJson(json['qualityAssessment']),
        ffaStandards: List<String>.from(json['ffaStandards']),
        aetSkillsIdentified: List<String>.from(json['aetSkillsIdentified']),
        learningConcepts: List<String>.from(json['learningConcepts']),
        competencyLevel: json['competencyLevel'],
        feedback: Feedback.fromJson(json['feedback']),
        recommendedActivities: List<String>.from(json['recommendedActivities']),
      );
}

class QualityAssessment {
  final int score;
  final String justification;

  QualityAssessment({
    required this.score,
    required this.justification,
  });

  Map<String, dynamic> toJson() => {
        'score': score,
        'justification': justification,
      };

  factory QualityAssessment.fromJson(Map<String, dynamic> json) =>
      QualityAssessment(
        score: json['score'],
        justification: json['justification'],
      );
}

class Feedback {
  final List<String> strengths;
  final List<String> improvements;
  final List<String> suggestions;

  Feedback({
    required this.strengths,
    required this.improvements,
    required this.suggestions,
  });

  Map<String, dynamic> toJson() => {
        'strengths': strengths,
        'improvements': improvements,
        'suggestions': suggestions,
      };

  factory Feedback.fromJson(Map<String, dynamic> json) => Feedback(
        strengths: List<String>.from(json['strengths']),
        improvements: List<String>.from(json['improvements']),
        suggestions: List<String>.from(json['suggestions']),
      );
}

/// Location data for journal entries
class LocationData {
  final double? latitude;
  final double? longitude;
  final String? address;
  final String? name;
  final double? accuracy;
  final DateTime? capturedAt;

  LocationData({
    this.latitude,
    this.longitude,
    this.address,
    this.name,
    this.accuracy,
    this.capturedAt,
  });

  Map<String, dynamic> toJson() => {
        'latitude': latitude,
        'longitude': longitude,
        'address': address,
        'name': name,
        'accuracy': accuracy,
        'capturedAt': capturedAt?.toIso8601String(),
      };

  factory LocationData.fromJson(Map<String, dynamic> json) => LocationData(
        latitude: json['latitude']?.toDouble(),
        longitude: json['longitude']?.toDouble(),
        address: json['address'],
        name: json['name'],
        accuracy: json['accuracy']?.toDouble(),
        capturedAt: json['capturedAt'] != null
            ? DateTime.parse(json['capturedAt'])
            : null,
      );
}

/// Weather data for journal entries
class WeatherData {
  final double? temperature;
  final String? condition;
  final int? humidity;
  final double? windSpeed;
  final String? description;

  WeatherData({
    this.temperature,
    this.condition,
    this.humidity,
    this.windSpeed,
    this.description,
  });

  Map<String, dynamic> toJson() => {
        'temperature': temperature,
        'condition': condition,
        'humidity': humidity,
        'windSpeed': windSpeed,
        'description': description,
      };

  factory WeatherData.fromJson(Map<String, dynamic> json) => WeatherData(
        temperature: json['temperature']?.toDouble(),
        condition: json['condition'],
        humidity: json['humidity'],
        windSpeed: json['windSpeed']?.toDouble(),
        description: json['description'],
      );
}

/// Competency tracking for FFA standards
class CompetencyTracking {
  final List<String> demonstratedSkills;
  final Map<String, int> skillLevels;
  final List<String> completedStandards;
  final double progressPercentage;
  final DateTime? lastAssessment;

  CompetencyTracking({
    required this.demonstratedSkills,
    required this.skillLevels,
    required this.completedStandards,
    required this.progressPercentage,
    this.lastAssessment,
  });

  Map<String, dynamic> toJson() => {
        'demonstratedSkills': demonstratedSkills,
        'skillLevels': skillLevels,
        'completedStandards': completedStandards,
        'progressPercentage': progressPercentage,
        'lastAssessment': lastAssessment?.toIso8601String(),
      };

  factory CompetencyTracking.fromJson(Map<String, dynamic> json) =>
      CompetencyTracking(
        demonstratedSkills: List<String>.from(json['demonstratedSkills'] ?? []),
        skillLevels: Map<String, int>.from(json['skillLevels'] ?? {}),
        completedStandards: List<String>.from(json['completedStandards'] ?? []),
        progressPercentage: json['progressPercentage']?.toDouble() ?? 0.0,
        lastAssessment: json['lastAssessment'] != null
            ? DateTime.parse(json['lastAssessment'])
            : null,
      );
}

// AET Skills categories for agricultural education
class AETSkills {
  static const Map<String, List<String>> categories = {
    'Animal Systems': [
      'Animal Health Management',
      'Feeding and Nutrition',
      'Breeding and Genetics',
      'Housing and Environment',
      'Record Keeping',
      'Performance Evaluation',
    ],
    'Plant Systems': [
      'Crop Production',
      'Soil Management',
      'Pest Management',
      'Irrigation Systems',
      'Harvest and Storage',
      'Plant Health Assessment',
    ],
    'Agricultural Business': [
      'Financial Planning',
      'Marketing Strategies',
      'Supply Chain Management',
      'Risk Management',
      'Cost Analysis',
      'Sales and Communication',
    ],
    'Leadership Development': [
      'Public Speaking',
      'Team Leadership',
      'Project Management',
      'Critical Thinking',
      'Problem Solving',
      'Communication Skills',
    ],
    'Technology Applications': [
      'Precision Agriculture',
      'Equipment Operation',
      'Data Management',
      'Safety Protocols',
      'Quality Assurance',
      'Innovation Implementation',
    ],
    'Environmental Stewardship': [
      'Sustainable Practices',
      'Natural Resource Management',
      'Conservation Techniques',
      'Environmental Monitoring',
      'Waste Management',
      'Ecosystem Understanding',
    ],
  };

  static List<String> getAllSkills() {
    return categories.values.expand((skills) => skills).toList();
  }

  static List<String> getSkillsByCategory(String category) {
    return categories[category] ?? [];
  }
}

// Journal categories for agricultural education
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
    'other',
  ];

  static const Map<String, String> categoryDisplayNames = {
    'daily_care': 'Daily Care',
    'health_check': 'Health Check',
    'feeding': 'Feeding & Nutrition',
    'training': 'Training & Handling',
    'show_prep': 'Show Preparation',
    'veterinary': 'Veterinary Care',
    'breeding': 'Breeding Management',
    'record_keeping': 'Record Keeping',
    'financial': 'Financial Management',
    'learning_reflection': 'Learning Reflection',
    'project_planning': 'Project Planning',
    'competition': 'Competition',
    'community_service': 'Community Service',
    'leadership_activity': 'Leadership Activity',
    'safety_training': 'Safety Training',
    'research': 'Research & Learning',
    'other': 'Other',
  };

  static String getDisplayName(String category) {
    return categoryDisplayNames[category] ?? category;
  }
}

// FFA Degree types and SAE categories
class FFAConstants {
  static const List<String> degreeTypes = [
    'Discovery FFA Degree',
    'Greenhand FFA Degree',
    'Chapter FFA Degree',
    'State FFA Degree',
    'American FFA Degree',
  ];

  static const List<String> saeTypes = [
    'Entrepreneurship',
    'Placement',
    'Research',
    'Exploratory',
    'Service Learning',
    'School-Based Enterprise',
  ];

  static const List<String> competencyLevels = [
    'Novice',
    'Developing',
    'Proficient',
    'Advanced',
    'Expert',
  ];

  static const List<String> evidenceTypes = [
    'Written Documentation',
    'Photo Evidence',
    'Video Demonstration',
    'Digital Portfolio',
    'Performance Assessment',
    'Peer Evaluation',
    'Supervisor Verification',
    'Competition Results',
  ];
}
