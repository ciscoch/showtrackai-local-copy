import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' show TimeOfDay;

enum WeightUnit {
  lb,
  kg,
}

enum WeightStatus {
  active,
  deleted,
  flagged,
  adjusted,
}

enum MeasurementMethod {
  digitalScale,
  mechanicalScale,
  tapeMeasure,
  visualEstimate,
  veterinary,
  showOfficial,
}

@immutable
class Weight {
  final String? id;
  final String animalId;
  final String userId;
  final String recordedBy;
  final double weightValue;
  final WeightUnit weightUnit;
  final DateTime measurementDate;
  final TimeOfDay? measurementTime;
  final MeasurementMethod measurementMethod;
  
  // Environmental factors
  final String? feedStatus; // 'fasted', 'fed', 'unknown'
  final String? waterStatus; // 'watered', 'restricted', 'unknown'
  final int? timeSinceFeeding; // in minutes
  
  // Quality indicators
  final int? confidenceLevel; // 1-10
  final bool isVerified;
  final String? verifiedBy;
  final DateTime? verifiedAt;
  
  // Show/competition context
  final bool isShowWeight;
  final String? showName;
  final String? showClass;
  
  // Notes and metadata
  final String? notes;
  final Map<String, dynamic>? weatherConditions;
  final String? healthStatus;
  final String? medicationNotes;
  
  // Calculated fields
  final int? daysSinceLastWeight;
  final double? weightChange;
  final double? adg; // Average Daily Gain
  
  // Status and audit
  final WeightStatus status;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  
  // Data quality
  final bool isOutlier;
  final String? outlierReason;
  
  const Weight({
    this.id,
    required this.animalId,
    required this.userId,
    required this.recordedBy,
    required this.weightValue,
    this.weightUnit = WeightUnit.lb,
    required this.measurementDate,
    this.measurementTime,
    this.measurementMethod = MeasurementMethod.digitalScale,
    this.feedStatus,
    this.waterStatus,
    this.timeSinceFeeding,
    this.confidenceLevel,
    this.isVerified = false,
    this.verifiedBy,
    this.verifiedAt,
    this.isShowWeight = false,
    this.showName,
    this.showClass,
    this.notes,
    this.weatherConditions,
    this.healthStatus,
    this.medicationNotes,
    this.daysSinceLastWeight,
    this.weightChange,
    this.adg,
    this.status = WeightStatus.active,
    this.createdAt,
    this.updatedAt,
    this.isOutlier = false,
    this.outlierReason,
  });
  
  // Convert weight to different unit
  double get weightInLbs {
    switch (weightUnit) {
      case WeightUnit.lb:
        return weightValue;
      case WeightUnit.kg:
        return weightValue * 2.20462;
    }
  }
  
  double get weightInKg {
    switch (weightUnit) {
      case WeightUnit.lb:
        return weightValue / 2.20462;
      case WeightUnit.kg:
        return weightValue;
    }
  }
  
  // Display helpers
  String get weightUnitDisplay {
    switch (weightUnit) {
      case WeightUnit.lb:
        return 'lbs';
      case WeightUnit.kg:
        return 'kg';
    }
  }
  
  String get measurementMethodDisplay {
    switch (measurementMethod) {
      case MeasurementMethod.digitalScale:
        return 'Digital Scale';
      case MeasurementMethod.mechanicalScale:
        return 'Mechanical Scale';
      case MeasurementMethod.tapeMeasure:
        return 'Tape Measure';
      case MeasurementMethod.visualEstimate:
        return 'Visual Estimate';
      case MeasurementMethod.veterinary:
        return 'Veterinary';
      case MeasurementMethod.showOfficial:
        return 'Show Official';
    }
  }
  
  String get statusDisplay {
    switch (status) {
      case WeightStatus.active:
        return 'Active';
      case WeightStatus.deleted:
        return 'Deleted';
      case WeightStatus.flagged:
        return 'Flagged';
      case WeightStatus.adjusted:
        return 'Adjusted';
    }
  }
  
  // Create from JSON (Supabase)
  factory Weight.fromJson(Map<String, dynamic> json) {
    return Weight(
      id: json['id']?.toString(),
      animalId: json['animal_id'] ?? '',
      userId: json['user_id'] ?? '',
      recordedBy: json['recorded_by'] ?? '',
      weightValue: (json['weight_value'] ?? 0).toDouble(),
      weightUnit: WeightUnit.values.firstWhere(
        (u) => u.name == json['weight_unit'],
        orElse: () => WeightUnit.lb,
      ),
      measurementDate: json['measurement_date'] != null
          ? DateTime.parse(json['measurement_date'])
          : DateTime.now(),
      measurementTime: json['measurement_time'] != null
          ? _parseTimeOfDay(json['measurement_time'])
          : null,
      measurementMethod: MeasurementMethod.values.firstWhere(
        (m) => m.name == _snakeToCamelCase(json['measurement_method'] ?? 'digital_scale'),
        orElse: () => MeasurementMethod.digitalScale,
      ),
      feedStatus: json['feed_status'],
      waterStatus: json['water_status'],
      timeSinceFeeding: json['time_since_feeding'],
      confidenceLevel: json['confidence_level'],
      isVerified: json['is_verified'] ?? false,
      verifiedBy: json['verified_by'],
      verifiedAt: json['verified_at'] != null
          ? DateTime.parse(json['verified_at'])
          : null,
      isShowWeight: json['is_show_weight'] ?? false,
      showName: json['show_name'],
      showClass: json['show_class'],
      notes: json['notes'],
      weatherConditions: json['weather_conditions'] as Map<String, dynamic>?,
      healthStatus: json['health_status'],
      medicationNotes: json['medication_notes'],
      daysSinceLastWeight: json['days_since_last_weight'],
      weightChange: json['weight_change']?.toDouble(),
      adg: json['adg']?.toDouble(),
      status: WeightStatus.values.firstWhere(
        (s) => s.name == json['status'],
        orElse: () => WeightStatus.active,
      ),
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'])
          : null,
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'])
          : null,
      isOutlier: json['is_outlier'] ?? false,
      outlierReason: json['outlier_reason'],
    );
  }
  
  // Convert to JSON for Supabase
  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      'animal_id': animalId,
      'user_id': userId,
      'recorded_by': recordedBy,
      'weight_value': weightValue,
      'weight_unit': weightUnit.name,
      'measurement_date': measurementDate.toIso8601String().split('T')[0], // Date only
      'measurement_time': measurementTime != null
          ? '${measurementTime!.hour.toString().padLeft(2, '0')}:${measurementTime!.minute.toString().padLeft(2, '0')}:00'
          : null,
      'measurement_method': _camelToSnakeCase(measurementMethod.name),
      'feed_status': feedStatus,
      'water_status': waterStatus,
      'time_since_feeding': timeSinceFeeding,
      'confidence_level': confidenceLevel,
      'is_verified': isVerified,
      'verified_by': verifiedBy,
      'verified_at': verifiedAt?.toIso8601String(),
      'is_show_weight': isShowWeight,
      'show_name': showName,
      'show_class': showClass,
      'notes': notes,
      'weather_conditions': weatherConditions,
      'health_status': healthStatus,
      'medication_notes': medicationNotes,
      'days_since_last_weight': daysSinceLastWeight,
      'weight_change': weightChange,
      'adg': adg,
      'status': status.name,
      'created_at': createdAt?.toIso8601String() ?? DateTime.now().toIso8601String(),
      'updated_at': DateTime.now().toIso8601String(),
      'is_outlier': isOutlier,
      'outlier_reason': outlierReason,
    };
  }
  
  // Create a copy with updated fields
  Weight copyWith({
    String? id,
    String? animalId,
    String? userId,
    String? recordedBy,
    double? weightValue,
    WeightUnit? weightUnit,
    DateTime? measurementDate,
    TimeOfDay? measurementTime,
    MeasurementMethod? measurementMethod,
    String? feedStatus,
    String? waterStatus,
    int? timeSinceFeeding,
    int? confidenceLevel,
    bool? isVerified,
    String? verifiedBy,
    DateTime? verifiedAt,
    bool? isShowWeight,
    String? showName,
    String? showClass,
    String? notes,
    Map<String, dynamic>? weatherConditions,
    String? healthStatus,
    String? medicationNotes,
    int? daysSinceLastWeight,
    double? weightChange,
    double? adg,
    WeightStatus? status,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? isOutlier,
    String? outlierReason,
  }) {
    return Weight(
      id: id ?? this.id,
      animalId: animalId ?? this.animalId,
      userId: userId ?? this.userId,
      recordedBy: recordedBy ?? this.recordedBy,
      weightValue: weightValue ?? this.weightValue,
      weightUnit: weightUnit ?? this.weightUnit,
      measurementDate: measurementDate ?? this.measurementDate,
      measurementTime: measurementTime ?? this.measurementTime,
      measurementMethod: measurementMethod ?? this.measurementMethod,
      feedStatus: feedStatus ?? this.feedStatus,
      waterStatus: waterStatus ?? this.waterStatus,
      timeSinceFeeding: timeSinceFeeding ?? this.timeSinceFeeding,
      confidenceLevel: confidenceLevel ?? this.confidenceLevel,
      isVerified: isVerified ?? this.isVerified,
      verifiedBy: verifiedBy ?? this.verifiedBy,
      verifiedAt: verifiedAt ?? this.verifiedAt,
      isShowWeight: isShowWeight ?? this.isShowWeight,
      showName: showName ?? this.showName,
      showClass: showClass ?? this.showClass,
      notes: notes ?? this.notes,
      weatherConditions: weatherConditions ?? this.weatherConditions,
      healthStatus: healthStatus ?? this.healthStatus,
      medicationNotes: medicationNotes ?? this.medicationNotes,
      daysSinceLastWeight: daysSinceLastWeight ?? this.daysSinceLastWeight,
      weightChange: weightChange ?? this.weightChange,
      adg: adg ?? this.adg,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      isOutlier: isOutlier ?? this.isOutlier,
      outlierReason: outlierReason ?? this.outlierReason,
    );
  }
  
  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Weight &&
        other.id == id &&
        other.animalId == animalId &&
        other.weightValue == weightValue &&
        other.measurementDate == measurementDate;
  }
  
  @override
  int get hashCode {
    return id.hashCode ^
        animalId.hashCode ^
        weightValue.hashCode ^
        measurementDate.hashCode;
  }
}

// Helper functions for string conversion
String _camelToSnakeCase(String camelCase) {
  return camelCase.replaceAllMapped(
    RegExp(r'([A-Z])'),
    (match) => '_${match.group(1)!.toLowerCase()}',
  );
}

String _snakeToCamelCase(String snakeCase) {
  List<String> parts = snakeCase.split('_');
  if (parts.isEmpty) return snakeCase;
  
  String result = parts[0];
  for (int i = 1; i < parts.length; i++) {
    if (parts[i].isNotEmpty) {
      result += parts[i][0].toUpperCase() + parts[i].substring(1);
    }
  }
  return result;
}

TimeOfDay? _parseTimeOfDay(String timeString) {
  try {
    List<String> parts = timeString.split(':');
    if (parts.length >= 2) {
      return TimeOfDay(
        hour: int.parse(parts[0]),
        minute: int.parse(parts[1]),
      );
    }
  } catch (e) {
    // Return null if parsing fails
  }
  return null;
}

// Weight statistics for dashboard display
@immutable
class WeightStatistics {
  final String animalId;
  final int totalWeights;
  final DateTime? firstWeightDate;
  final DateTime? lastWeightDate;
  final double? currentWeight;
  final double? startingWeight;
  final double? highestWeight;
  final double? lowestWeight;
  final double? averageAdg;
  final double? bestAdgPeriod;
  final double? worstAdgPeriod;
  final double? currentWeekAdg;
  final double? currentMonthAdg;
  final String? weightTrend; // 'increasing', 'decreasing', 'stable'
  final double? trendStrength;
  final int activeGoalsCount;
  final int achievedGoalsCount;
  final DateTime? lastCalculated;
  
  const WeightStatistics({
    required this.animalId,
    this.totalWeights = 0,
    this.firstWeightDate,
    this.lastWeightDate,
    this.currentWeight,
    this.startingWeight,
    this.highestWeight,
    this.lowestWeight,
    this.averageAdg,
    this.bestAdgPeriod,
    this.worstAdgPeriod,
    this.currentWeekAdg,
    this.currentMonthAdg,
    this.weightTrend,
    this.trendStrength,
    this.activeGoalsCount = 0,
    this.achievedGoalsCount = 0,
    this.lastCalculated,
  });
  
  // Total weight gain
  double? get totalWeightGain {
    if (startingWeight == null || currentWeight == null) return null;
    return currentWeight! - startingWeight!;
  }
  
  // Days of tracking
  int? get daysOfTracking {
    if (firstWeightDate == null || lastWeightDate == null) return null;
    return lastWeightDate!.difference(firstWeightDate!).inDays;
  }
  
  // Weight trend indicator
  bool get isGainingWeight => weightTrend == 'increasing';
  bool get isLosingWeight => weightTrend == 'decreasing';
  bool get isStableWeight => weightTrend == 'stable';
  
  factory WeightStatistics.fromJson(Map<String, dynamic> json) {
    return WeightStatistics(
      animalId: json['animal_id'] ?? '',
      totalWeights: json['total_weights'] ?? 0,
      firstWeightDate: json['first_weight_date'] != null
          ? DateTime.parse(json['first_weight_date'])
          : null,
      lastWeightDate: json['last_weight_date'] != null
          ? DateTime.parse(json['last_weight_date'])
          : null,
      currentWeight: json['current_weight']?.toDouble(),
      startingWeight: json['starting_weight']?.toDouble(),
      highestWeight: json['highest_weight']?.toDouble(),
      lowestWeight: json['lowest_weight']?.toDouble(),
      averageAdg: json['average_adg']?.toDouble(),
      bestAdgPeriod: json['best_adg_period']?.toDouble(),
      worstAdgPeriod: json['worst_adg_period']?.toDouble(),
      currentWeekAdg: json['current_week_adg']?.toDouble(),
      currentMonthAdg: json['current_month_adg']?.toDouble(),
      weightTrend: json['weight_trend'],
      trendStrength: json['trend_strength']?.toDouble(),
      activeGoalsCount: json['active_goals_count'] ?? 0,
      achievedGoalsCount: json['achieved_goals_count'] ?? 0,
      lastCalculated: json['last_calculated'] != null
          ? DateTime.parse(json['last_calculated'])
          : null,
    );
  }
  
  Map<String, dynamic> toJson() {
    return {
      'animal_id': animalId,
      'total_weights': totalWeights,
      'first_weight_date': firstWeightDate?.toIso8601String().split('T')[0],
      'last_weight_date': lastWeightDate?.toIso8601String().split('T')[0],
      'current_weight': currentWeight,
      'starting_weight': startingWeight,
      'highest_weight': highestWeight,
      'lowest_weight': lowestWeight,
      'average_adg': averageAdg,
      'best_adg_period': bestAdgPeriod,
      'worst_adg_period': worstAdgPeriod,
      'current_week_adg': currentWeekAdg,
      'current_month_adg': currentMonthAdg,
      'weight_trend': weightTrend,
      'trend_strength': trendStrength,
      'active_goals_count': activeGoalsCount,
      'achieved_goals_count': achievedGoalsCount,
      'last_calculated': lastCalculated?.toIso8601String(),
    };
  }
}