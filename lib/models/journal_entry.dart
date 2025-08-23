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
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'user_id': userId,
        'title': title,
        'description': description,
        'date': date.toIso8601String(),
        'duration': duration,
        'category': category,
        'aetSkills': aetSkills,
        'animalId': animalId,
        'feedData': feedData?.toJson(),
        'objectives': objectives,
        'learningOutcomes': learningOutcomes,
        'challenges': challenges,
        'improvements': improvements,
        'photos': photos,
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

  factory Feedback.fromJson(Map<String, dynamic> json) => Feedback(
        strengths: List<String>.from(json['strengths']),
        improvements: List<String>.from(json['improvements']),
        suggestions: List<String>.from(json['suggestions']),
      );
}

// AET Skills categories
class AETSkills {
  static const Map<String, List<String>> categories = {
    'Animal Care': [
      'Feeding Management',
      'Health Monitoring',
      'Grooming & Hygiene',
      'Housing Management',
      'Record Keeping',
    ],
    'Business Management': [
      'Financial Planning',
      'Cost Analysis',
      'Marketing',
      'Sales',
      'Inventory Management',
    ],
    'Leadership': [
      'Public Speaking',
      'Team Collaboration',
      'Project Management',
      'Decision Making',
      'Problem Solving',
    ],
    'Technical Skills': [
      'Equipment Operation',
      'Facility Maintenance',
      'Technology Use',
      'Safety Practices',
      'Quality Control',
    ],
  };

  static List<String> getAllSkills() {
    return categories.values.expand((skills) => skills).toList();
  }
}
