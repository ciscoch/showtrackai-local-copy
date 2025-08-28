import 'package:flutter/foundation.dart';
import 'weight.dart';

enum GoalStatus {
  active,
  achieved,
  missed,
  cancelled,
  paused,
}

@immutable
class WeightGoal {
  final String? id;
  final String animalId;
  final String userId;
  final String goalName;
  final double targetWeight;
  final WeightUnit weightUnit;
  final DateTime targetDate;
  
  // Starting point
  final double startingWeight;
  final DateTime startingDate;
  
  // Target metrics
  final double? targetAdg; // Target Average Daily Gain
  final double? minAdg;
  final double? maxAdg;
  
  // Progress tracking
  final double? currentWeight;
  final DateTime? lastWeightDate;
  final double? progressPercentage;
  final double? projectedWeight;
  final DateTime? projectedDate;
  final int? daysRemaining;
  
  // Show/competition goals
  final String? showName;
  final DateTime? showDate;
  final double? weightClassMin;
  final double? weightClassMax;
  
  // Status and metadata
  final GoalStatus status;
  final DateTime? achievedDate;
  final String? achievementNotes;
  
  // Alerts and notifications
  final bool alertEnabled;
  final int alertThresholdDays;
  final DateTime? lastAlertSent;
  
  final DateTime? createdAt;
  final DateTime? updatedAt;
  
  const WeightGoal({
    this.id,
    required this.animalId,
    required this.userId,
    required this.goalName,
    required this.targetWeight,
    this.weightUnit = WeightUnit.lb,
    required this.targetDate,
    required this.startingWeight,
    required this.startingDate,
    this.targetAdg,
    this.minAdg,
    this.maxAdg,
    this.currentWeight,
    this.lastWeightDate,
    this.progressPercentage,
    this.projectedWeight,
    this.projectedDate,
    this.daysRemaining,
    this.showName,
    this.showDate,
    this.weightClassMin,
    this.weightClassMax,
    this.status = GoalStatus.active,
    this.achievedDate,
    this.achievementNotes,
    this.alertEnabled = true,
    this.alertThresholdDays = 7,
    this.lastAlertSent,
    this.createdAt,
    this.updatedAt,
  });
  
  // Calculated properties
  double? get totalWeightNeeded {
    if (currentWeight == null) return targetWeight - startingWeight;
    return targetWeight - currentWeight!;
  }
  
  double? get weightGainedSoFar {
    if (currentWeight == null) return null;
    return currentWeight! - startingWeight;
  }
  
  int? get totalDaysForGoal {
    return targetDate.difference(startingDate).inDays;
  }
  
  int? get daysElapsed {
    return DateTime.now().difference(startingDate).inDays;
  }
  
  double? get requiredAdgToMeetGoal {
    final remaining = daysRemaining;
    final weightNeeded = totalWeightNeeded;
    if (remaining == null || remaining <= 0 || weightNeeded == null) return null;
    return weightNeeded / remaining;
  }
  
  bool get isOnTrack {
    final currentProgress = progressPercentage ?? 0;
    final timeProgress = daysElapsed != null && totalDaysForGoal != null
        ? (daysElapsed! / totalDaysForGoal!) * 100
        : 0;
    return currentProgress >= timeProgress * 0.9; // Allow 10% tolerance
  }
  
  bool get isOverdue => daysRemaining != null && daysRemaining! < 0;
  
  bool get isUrgent => daysRemaining != null && daysRemaining! <= alertThresholdDays;
  
  String get urgencyStatus {
    if (isOverdue) return 'overdue';
    if (isUrgent) return 'urgent';
    if (daysRemaining != null && daysRemaining! <= 30) return 'approaching';
    return 'on_track';
  }
  
  // Display helpers
  String get statusDisplay {
    switch (status) {
      case GoalStatus.active:
        return 'Active';
      case GoalStatus.achieved:
        return 'Achieved';
      case GoalStatus.missed:
        return 'Missed';
      case GoalStatus.cancelled:
        return 'Cancelled';
      case GoalStatus.paused:
        return 'Paused';
    }
  }
  
  String get weightUnitDisplay {
    switch (weightUnit) {
      case WeightUnit.lb:
        return 'lbs';
      case WeightUnit.kg:
        return 'kg';
    }
  }
  
  // Convert weight to different unit
  double get targetWeightInLbs {
    switch (weightUnit) {
      case WeightUnit.lb:
        return targetWeight;
      case WeightUnit.kg:
        return targetWeight * 2.20462;
    }
  }
  
  double get targetWeightInKg {
    switch (weightUnit) {
      case WeightUnit.lb:
        return targetWeight / 2.20462;
      case WeightUnit.kg:
        return targetWeight;
    }
  }
  
  // Create from JSON (Supabase)
  factory WeightGoal.fromJson(Map<String, dynamic> json) {
    return WeightGoal(
      id: json['id']?.toString(),
      animalId: json['animal_id'] ?? '',
      userId: json['user_id'] ?? '',
      goalName: json['goal_name'] ?? '',
      targetWeight: (json['target_weight'] ?? 0).toDouble(),
      weightUnit: WeightUnit.values.firstWhere(
        (u) => u.name == json['weight_unit'],
        orElse: () => WeightUnit.lb,
      ),
      targetDate: json['target_date'] != null
          ? DateTime.parse(json['target_date'])
          : DateTime.now(),
      startingWeight: (json['starting_weight'] ?? 0).toDouble(),
      startingDate: json['starting_date'] != null
          ? DateTime.parse(json['starting_date'])
          : DateTime.now(),
      targetAdg: json['target_adg']?.toDouble(),
      minAdg: json['min_adg']?.toDouble(),
      maxAdg: json['max_adg']?.toDouble(),
      currentWeight: json['current_weight']?.toDouble(),
      lastWeightDate: json['last_weight_date'] != null
          ? DateTime.parse(json['last_weight_date'])
          : null,
      progressPercentage: json['progress_percentage']?.toDouble(),
      projectedWeight: json['projected_weight']?.toDouble(),
      projectedDate: json['projected_date'] != null
          ? DateTime.parse(json['projected_date'])
          : null,
      daysRemaining: json['days_remaining'],
      showName: json['show_name'],
      showDate: json['show_date'] != null
          ? DateTime.parse(json['show_date'])
          : null,
      weightClassMin: json['weight_class_min']?.toDouble(),
      weightClassMax: json['weight_class_max']?.toDouble(),
      status: GoalStatus.values.firstWhere(
        (s) => s.name == json['status'],
        orElse: () => GoalStatus.active,
      ),
      achievedDate: json['achieved_date'] != null
          ? DateTime.parse(json['achieved_date'])
          : null,
      achievementNotes: json['achievement_notes'],
      alertEnabled: json['alert_enabled'] ?? true,
      alertThresholdDays: json['alert_threshold_days'] ?? 7,
      lastAlertSent: json['last_alert_sent'] != null
          ? DateTime.parse(json['last_alert_sent'])
          : null,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'])
          : null,
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'])
          : null,
    );
  }
  
  // Convert to JSON for Supabase
  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      'animal_id': animalId,
      'user_id': userId,
      'goal_name': goalName,
      'target_weight': targetWeight,
      'weight_unit': weightUnit.name,
      'target_date': targetDate.toIso8601String().split('T')[0], // Date only
      'starting_weight': startingWeight,
      'starting_date': startingDate.toIso8601String().split('T')[0], // Date only
      'target_adg': targetAdg,
      'min_adg': minAdg,
      'max_adg': maxAdg,
      'current_weight': currentWeight,
      'last_weight_date': lastWeightDate?.toIso8601String().split('T')[0],
      'progress_percentage': progressPercentage,
      'projected_weight': projectedWeight,
      'projected_date': projectedDate?.toIso8601String().split('T')[0],
      'days_remaining': daysRemaining,
      'show_name': showName,
      'show_date': showDate?.toIso8601String().split('T')[0],
      'weight_class_min': weightClassMin,
      'weight_class_max': weightClassMax,
      'status': status.name,
      'achieved_date': achievedDate?.toIso8601String().split('T')[0],
      'achievement_notes': achievementNotes,
      'alert_enabled': alertEnabled,
      'alert_threshold_days': alertThresholdDays,
      'last_alert_sent': lastAlertSent?.toIso8601String(),
      'created_at': createdAt?.toIso8601String() ?? DateTime.now().toIso8601String(),
      'updated_at': DateTime.now().toIso8601String(),
    };
  }
  
  // Create a copy with updated fields
  WeightGoal copyWith({
    String? id,
    String? animalId,
    String? userId,
    String? goalName,
    double? targetWeight,
    WeightUnit? weightUnit,
    DateTime? targetDate,
    double? startingWeight,
    DateTime? startingDate,
    double? targetAdg,
    double? minAdg,
    double? maxAdg,
    double? currentWeight,
    DateTime? lastWeightDate,
    double? progressPercentage,
    double? projectedWeight,
    DateTime? projectedDate,
    int? daysRemaining,
    String? showName,
    DateTime? showDate,
    double? weightClassMin,
    double? weightClassMax,
    GoalStatus? status,
    DateTime? achievedDate,
    String? achievementNotes,
    bool? alertEnabled,
    int? alertThresholdDays,
    DateTime? lastAlertSent,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return WeightGoal(
      id: id ?? this.id,
      animalId: animalId ?? this.animalId,
      userId: userId ?? this.userId,
      goalName: goalName ?? this.goalName,
      targetWeight: targetWeight ?? this.targetWeight,
      weightUnit: weightUnit ?? this.weightUnit,
      targetDate: targetDate ?? this.targetDate,
      startingWeight: startingWeight ?? this.startingWeight,
      startingDate: startingDate ?? this.startingDate,
      targetAdg: targetAdg ?? this.targetAdg,
      minAdg: minAdg ?? this.minAdg,
      maxAdg: maxAdg ?? this.maxAdg,
      currentWeight: currentWeight ?? this.currentWeight,
      lastWeightDate: lastWeightDate ?? this.lastWeightDate,
      progressPercentage: progressPercentage ?? this.progressPercentage,
      projectedWeight: projectedWeight ?? this.projectedWeight,
      projectedDate: projectedDate ?? this.projectedDate,
      daysRemaining: daysRemaining ?? this.daysRemaining,
      showName: showName ?? this.showName,
      showDate: showDate ?? this.showDate,
      weightClassMin: weightClassMin ?? this.weightClassMin,
      weightClassMax: weightClassMax ?? this.weightClassMax,
      status: status ?? this.status,
      achievedDate: achievedDate ?? this.achievedDate,
      achievementNotes: achievementNotes ?? this.achievementNotes,
      alertEnabled: alertEnabled ?? this.alertEnabled,
      alertThresholdDays: alertThresholdDays ?? this.alertThresholdDays,
      lastAlertSent: lastAlertSent ?? this.lastAlertSent,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
  
  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is WeightGoal &&
        other.id == id &&
        other.animalId == animalId &&
        other.goalName == goalName &&
        other.targetDate == targetDate;
  }
  
  @override
  int get hashCode {
    return id.hashCode ^
        animalId.hashCode ^
        goalName.hashCode ^
        targetDate.hashCode;
  }
}