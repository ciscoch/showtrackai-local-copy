import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import '../models/timeline_item.dart';
import 'timeline_service.dart';

/// Advanced analytics service for timeline data aggregation
/// Provides real-time insights, trend analysis, and predictive metrics
class TimelineAnalyticsService {
  static TimelineAnalyticsService? _instance;
  static TimelineAnalyticsService get instance => _instance ??= TimelineAnalyticsService._();
  TimelineAnalyticsService._();

  // Cache for computed analytics
  final Map<String, _AnalyticsCache> _analyticsCache = {};
  static const Duration _analyticsTtl = Duration(minutes: 15);

  /// Get comprehensive timeline analytics
  Future<TimelineAnalytics> getTimelineAnalytics({
    DateTime? startDate,
    DateTime? endDate,
    String? animalId,
    bool forceRefresh = false,
  }) async {
    final cacheKey = _generateAnalyticsCacheKey(startDate, endDate, animalId);
    
    // Check cache unless force refresh
    if (!forceRefresh) {
      final cached = _getFromCache(cacheKey);
      if (cached != null) {
        return cached;
      }
    }

    try {
      // Get base statistics
      final stats = await TimelineService.getTimelineStatistics(
        startDate: startDate,
        endDate: endDate,
      );

      // Get detailed timeline data for analysis
      final timelineData = await TimelineService.getTimelineItems(
        limit: 1000, // Get significant sample for analysis
        startDate: startDate,
        endDate: endDate,
        animalId: animalId,
      );

      // Compute advanced analytics
      final analytics = TimelineAnalytics(
        // Basic metrics
        totalItems: stats.totalItems,
        journalCount: stats.journalCount,
        expenseCount: stats.expenseCount,
        totalExpenses: stats.totalExpenses,
        averageQuality: stats.averageQuality,
        dateRange: DateRange(stats.startDate, stats.endDate),

        // Activity patterns
        activityTrends: _calculateActivityTrends(timelineData.items),
        productivityScore: _calculateProductivityScore(timelineData.items),
        consistencyRating: _calculateConsistencyRating(timelineData.items),

        // Financial insights
        expenseAnalysis: _calculateExpenseAnalysis(timelineData.items),
        budgetHealth: _calculateBudgetHealth(timelineData.items),
        costTrends: _calculateCostTrends(timelineData.items),

        // Learning analytics
        learningProgress: _calculateLearningProgress(timelineData.items),
        skillDevelopment: _calculateSkillDevelopment(timelineData.items),
        competencyGrowth: _calculateCompetencyGrowth(timelineData.items),

        // Predictive analytics
        forecasts: _generateForecasts(timelineData.items),
        recommendations: _generateRecommendations(timelineData.items),
        riskAlerts: _identifyRiskAlerts(timelineData.items),
      );

      // Cache the result
      _cacheAnalytics(cacheKey, analytics);

      return analytics;

    } catch (e) {
      debugPrint('Error computing timeline analytics: $e');
      throw Exception('Failed to compute timeline analytics: $e');
    }
  }

  /// Calculate activity trends (daily, weekly, monthly patterns)
  ActivityTrends _calculateActivityTrends(List<TimelineItem> items) {
    final now = DateTime.now();
    final thirtyDaysAgo = now.subtract(const Duration(days: 30));
    final sevenDaysAgo = now.subtract(const Duration(days: 7));

    // Group by time periods
    final dailyActivity = <DateTime, int>{};
    final weeklyActivity = <int, int>{};
    final monthlyActivity = <int, int>{};
    final hourlyActivity = <int, int>{};

    for (final item in items) {
      // Daily activity
      final day = DateTime(item.date.year, item.date.month, item.date.day);
      dailyActivity[day] = (dailyActivity[day] ?? 0) + 1;

      // Weekly activity (week of year)
      final weekOfYear = _getWeekOfYear(item.date);
      weeklyActivity[weekOfYear] = (weeklyActivity[weekOfYear] ?? 0) + 1;

      // Monthly activity
      monthlyActivity[item.date.month] = (monthlyActivity[item.date.month] ?? 0) + 1;

      // Hourly activity (hour of day)
      hourlyActivity[item.date.hour] = (hourlyActivity[item.date.hour] ?? 0) + 1;
    }

    // Calculate trends
    final last30Days = items.where((item) => item.date.isAfter(thirtyDaysAgo)).length;
    final last7Days = items.where((item) => item.date.isAfter(sevenDaysAgo)).length;
    
    return ActivityTrends(
      dailyAverage: last30Days / 30.0,
      weeklyAverage: last30Days / 4.0,
      peakActivityHour: _findPeakHour(hourlyActivity),
      mostActiveDay: _findMostActiveDay(dailyActivity),
      activityConsistency: _calculateConsistency(dailyActivity.values.toList()),
      trend: _calculateTrendDirection(dailyActivity),
    );
  }

  /// Calculate productivity score (0-100)
  double _calculateProductivityScore(List<TimelineItem> items) {
    if (items.isEmpty) return 0.0;

    double score = 0.0;
    int factors = 0;

    // Factor 1: Activity frequency (30%)
    final now = DateTime.now();
    final last30Days = now.subtract(const Duration(days: 30));
    final recentItems = items.where((item) => item.date.isAfter(last30Days)).length;
    final frequencyScore = min(recentItems / 30.0, 1.0) * 30; // Max 1 per day
    score += frequencyScore;
    factors++;

    // Factor 2: Content quality (25%)
    final qualityItems = items
        .where((item) => item.metadata?['quality'] != null)
        .toList();
    if (qualityItems.isNotEmpty) {
      final avgQuality = qualityItems
          .map((item) => item.metadata!['quality'] as double)
          .reduce((a, b) => a + b) / qualityItems.length;
      score += (avgQuality / 10.0) * 25;
    }
    factors++;

    // Factor 3: Learning engagement (20%)
    final journalItems = items.where((item) => item.type == TimelineItemType.journal).length;
    final engagementScore = min(journalItems / items.length, 1.0) * 20;
    score += engagementScore;
    factors++;

    // Factor 4: Financial tracking (15%)
    final expenseItems = items.where((item) => item.type == TimelineItemType.expense).length;
    final trackingScore = min(expenseItems / max(items.length * 0.3, 1), 1.0) * 15;
    score += trackingScore;
    factors++;

    // Factor 5: Consistency (10%)
    final consistencyScore = _calculateConsistencyRating(items) * 10;
    score += consistencyScore;
    factors++;

    return score / factors;
  }

  /// Calculate expense analysis
  ExpenseAnalysis _calculateExpenseAnalysis(List<TimelineItem> items) {
    final expenses = items
        .where((item) => item.type == TimelineItemType.expense && item.amount != null)
        .toList();

    if (expenses.isEmpty) {
      return ExpenseAnalysis(
        totalSpent: 0.0,
        averageExpense: 0.0,
        largestExpense: 0.0,
        categoryBreakdown: {},
        monthlyTrend: 0.0,
        budgetUtilization: 0.0,
      );
    }

    final amounts = expenses.map((e) => e.amount!).toList();
    final totalSpent = amounts.reduce((a, b) => a + b);
    final averageExpense = totalSpent / amounts.length;

    // Category breakdown
    final categoryBreakdown = <String, double>{};
    for (final expense in expenses) {
      final category = expense.category ?? 'other';
      categoryBreakdown[category] = (categoryBreakdown[category] ?? 0) + expense.amount!;
    }

    // Monthly trend (last 6 months)
    final now = DateTime.now();
    final monthlyAmounts = <int, double>{};
    for (final expense in expenses) {
      if (expense.date.isAfter(now.subtract(const Duration(days: 180)))) {
        final month = expense.date.month;
        monthlyAmounts[month] = (monthlyAmounts[month] ?? 0) + expense.amount!;
      }
    }

    final monthlyTrend = _calculateLinearTrend(monthlyAmounts.values.toList());

    return ExpenseAnalysis(
      totalSpent: totalSpent,
      averageExpense: averageExpense,
      largestExpense: amounts.reduce(max),
      categoryBreakdown: categoryBreakdown,
      monthlyTrend: monthlyTrend,
      budgetUtilization: 0.75, // This would come from user budget settings
    );
  }

  /// Generate predictive forecasts
  List<Forecast> _generateForecasts(List<TimelineItem> items) {
    final forecasts = <Forecast>[];

    // Activity forecast
    final activityTrend = _calculateActivityTrends(items);
    forecasts.add(Forecast(
      type: 'activity',
      period: 'next_30_days',
      prediction: activityTrend.dailyAverage * 30,
      confidence: 0.75,
      description: 'Expected timeline entries in next 30 days',
    ));

    // Expense forecast
    final expenses = items
        .where((item) => item.type == TimelineItemType.expense && item.amount != null)
        .toList();
    
    if (expenses.isNotEmpty) {
      final last30DaysExpenses = expenses
          .where((item) => item.date.isAfter(DateTime.now().subtract(const Duration(days: 30))))
          .map((item) => item.amount!)
          .fold(0.0, (sum, amount) => sum + amount);
      
      forecasts.add(Forecast(
        type: 'expense',
        period: 'next_30_days',
        prediction: last30DaysExpenses * 1.05, // 5% growth assumption
        confidence: 0.65,
        description: 'Projected expenses for next 30 days',
      ));
    }

    return forecasts;
  }

  /// Generate personalized recommendations
  List<Recommendation> _generateRecommendations(List<TimelineItem> items) {
    final recommendations = <Recommendation>[];

    // Activity consistency recommendation
    final consistency = _calculateConsistencyRating(items);
    if (consistency < 0.6) {
      recommendations.add(Recommendation(
        type: 'consistency',
        priority: 'high',
        title: 'Improve Activity Consistency',
        description: 'Try to log activities more regularly for better tracking.',
        actionItems: [
          'Set daily reminders',
          'Use quick entry templates',
          'Track smaller activities',
        ],
      ));
    }

    // Quality improvement recommendation
    final journalItems = items.where((item) => item.type == TimelineItemType.journal).toList();
    final qualityItems = journalItems
        .where((item) => item.metadata?['quality'] != null)
        .toList();
    
    if (qualityItems.isNotEmpty) {
      final avgQuality = qualityItems
          .map((item) => item.metadata!['quality'] as double)
          .reduce((a, b) => a + b) / qualityItems.length;
      
      if (avgQuality < 7.0) {
        recommendations.add(Recommendation(
          type: 'quality',
          priority: 'medium',
          title: 'Enhance Entry Quality',
          description: 'Add more detail to your journal entries.',
          actionItems: [
            'Include photos and observations',
            'Record learning outcomes',
            'Add measurement data',
          ],
        ));
      }
    }

    // Budget management recommendation
    final expenses = items
        .where((item) => item.type == TimelineItemType.expense)
        .toList();
    
    if (expenses.length < journalItems.length * 0.3) {
      recommendations.add(Recommendation(
        type: 'financial',
        priority: 'medium',
        title: 'Track More Expenses',
        description: 'Recording expenses helps with budget planning.',
        actionItems: [
          'Log feed purchases',
          'Track veterinary costs',
          'Record equipment expenses',
        ],
      ));
    }

    return recommendations;
  }

  /// Helper methods for calculations
  double _calculateConsistencyRating(List<TimelineItem> items) {
    if (items.length < 7) return 0.0;

    final now = DateTime.now();
    final last30Days = now.subtract(const Duration(days: 30));
    final recentItems = items
        .where((item) => item.date.isAfter(last30Days))
        .toList();

    if (recentItems.isEmpty) return 0.0;

    // Group by day
    final dailyCount = <DateTime, int>{};
    for (final item in recentItems) {
      final day = DateTime(item.date.year, item.date.month, item.date.day);
      dailyCount[day] = (dailyCount[day] ?? 0) + 1;
    }

    // Calculate consistency (lower standard deviation = higher consistency)
    final counts = dailyCount.values.toList();
    if (counts.isEmpty) return 0.0;

    final mean = counts.reduce((a, b) => a + b) / counts.length;
    final variance = counts
        .map((count) => pow(count - mean, 2))
        .reduce((a, b) => a + b) / counts.length;
    final stdDev = sqrt(variance);

    // Convert to 0-1 scale (lower stdDev = higher consistency)
    return max(0.0, 1.0 - (stdDev / mean));
  }

  int _getWeekOfYear(DateTime date) {
    final firstDayOfYear = DateTime(date.year, 1, 1);
    final dayOfYear = date.difference(firstDayOfYear).inDays;
    return (dayOfYear / 7).ceil();
  }

  int _findPeakHour(Map<int, int> hourlyActivity) {
    if (hourlyActivity.isEmpty) return 12; // Default to noon
    return hourlyActivity.entries
        .reduce((a, b) => a.value > b.value ? a : b)
        .key;
  }

  DateTime _findMostActiveDay(Map<DateTime, int> dailyActivity) {
    if (dailyActivity.isEmpty) return DateTime.now();
    return dailyActivity.entries
        .reduce((a, b) => a.value > b.value ? a : b)
        .key;
  }

  double _calculateLinearTrend(List<double> values) {
    if (values.length < 2) return 0.0;
    
    final n = values.length;
    final sumX = n * (n - 1) / 2; // Sum of indices 0,1,2...n-1
    final sumY = values.reduce((a, b) => a + b);
    final sumXY = values.asMap().entries
        .map((entry) => entry.key * entry.value)
        .reduce((a, b) => a + b);
    final sumXX = (n * (n - 1) * (2 * n - 1) / 6); // Sum of squares

    return (n * sumXY - sumX * sumY) / (n * sumXX - sumX * sumX);
  }

  double _calculateConsistency(List<int> values) {
    if (values.length < 2) return 0.0;
    
    final mean = values.reduce((a, b) => a + b) / values.length;
    final variance = values
        .map((v) => pow(v - mean, 2))
        .reduce((a, b) => a + b) / values.length;
    
    return mean > 0 ? 1.0 - (sqrt(variance) / mean) : 0.0;
  }

  String _calculateTrendDirection(Map<DateTime, int> dailyActivity) {
    final sortedEntries = dailyActivity.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));
    
    if (sortedEntries.length < 7) return 'insufficient_data';
    
    final recentWeek = sortedEntries.takeLast(7).map((e) => e.value).reduce((a, b) => a + b);
    final previousWeek = sortedEntries
        .skip(max(0, sortedEntries.length - 14))
        .take(7)
        .map((e) => e.value)
        .reduce((a, b) => a + b);
    
    if (recentWeek > previousWeek * 1.1) return 'increasing';
    if (recentWeek < previousWeek * 0.9) return 'decreasing';
    return 'stable';
  }

  // Cache management
  _AnalyticsCache? _getFromCache(String key) {
    final cached = _analyticsCache[key];
    if (cached == null) return null;
    
    if (DateTime.now().difference(cached.timestamp) > _analyticsTtl) {
      _analyticsCache.remove(key);
      return null;
    }
    
    return cached;
  }

  void _cacheAnalytics(String key, TimelineAnalytics analytics) {
    _analyticsCache[key] = _AnalyticsCache(analytics, DateTime.now());
  }

  String _generateAnalyticsCacheKey(DateTime? start, DateTime? end, String? animalId) {
    return [
      'analytics',
      start?.millisecondsSinceEpoch.toString() ?? '',
      end?.millisecondsSinceEpoch.toString() ?? '',
      animalId ?? 'all',
    ].join('_');
  }

  List<RiskAlert> _identifyRiskAlerts(List<TimelineItem> items) {
    // This would implement risk identification logic
    return [];
  }

  LearningProgress _calculateLearningProgress(List<TimelineItem> items) {
    // This would implement learning analytics
    return LearningProgress(
      totalActivities: items.where((i) => i.type == TimelineItemType.journal).length,
      competenciesAddressed: 0,
      skillsImproved: [],
      progressRate: 0.0,
    );
  }

  Map<String, double> _calculateSkillDevelopment(List<TimelineItem> items) {
    return {};
  }

  double _calculateCompetencyGrowth(List<TimelineItem> items) {
    return 0.0;
  }

  BudgetHealth _calculateBudgetHealth(List<TimelineItem> items) {
    return BudgetHealth(
      status: 'good',
      utilizationRate: 0.75,
      projectedOverrun: 0.0,
      savingsOpportunities: [],
    );
  }

  Map<String, double> _calculateCostTrends(List<TimelineItem> items) {
    return {};
  }
}

/// Data classes for analytics
class TimelineAnalytics {
  final int totalItems;
  final int journalCount;
  final int expenseCount;
  final double totalExpenses;
  final double? averageQuality;
  final DateRange dateRange;
  final ActivityTrends activityTrends;
  final double productivityScore;
  final double consistencyRating;
  final ExpenseAnalysis expenseAnalysis;
  final BudgetHealth budgetHealth;
  final Map<String, double> costTrends;
  final LearningProgress learningProgress;
  final Map<String, double> skillDevelopment;
  final double competencyGrowth;
  final List<Forecast> forecasts;
  final List<Recommendation> recommendations;
  final List<RiskAlert> riskAlerts;

  TimelineAnalytics({
    required this.totalItems,
    required this.journalCount,
    required this.expenseCount,
    required this.totalExpenses,
    this.averageQuality,
    required this.dateRange,
    required this.activityTrends,
    required this.productivityScore,
    required this.consistencyRating,
    required this.expenseAnalysis,
    required this.budgetHealth,
    required this.costTrends,
    required this.learningProgress,
    required this.skillDevelopment,
    required this.competencyGrowth,
    required this.forecasts,
    required this.recommendations,
    required this.riskAlerts,
  });
}

// Supporting classes would be defined here...
class DateRange {
  final DateTime? start;
  final DateTime? end;
  DateRange(this.start, this.end);
}

class ActivityTrends {
  final double dailyAverage;
  final double weeklyAverage;
  final int peakActivityHour;
  final DateTime mostActiveDay;
  final double activityConsistency;
  final String trend;

  ActivityTrends({
    required this.dailyAverage,
    required this.weeklyAverage,
    required this.peakActivityHour,
    required this.mostActiveDay,
    required this.activityConsistency,
    required this.trend,
  });
}

class ExpenseAnalysis {
  final double totalSpent;
  final double averageExpense;
  final double largestExpense;
  final Map<String, double> categoryBreakdown;
  final double monthlyTrend;
  final double budgetUtilization;

  ExpenseAnalysis({
    required this.totalSpent,
    required this.averageExpense,
    required this.largestExpense,
    required this.categoryBreakdown,
    required this.monthlyTrend,
    required this.budgetUtilization,
  });
}

class Forecast {
  final String type;
  final String period;
  final double prediction;
  final double confidence;
  final String description;

  Forecast({
    required this.type,
    required this.period,
    required this.prediction,
    required this.confidence,
    required this.description,
  });
}

class Recommendation {
  final String type;
  final String priority;
  final String title;
  final String description;
  final List<String> actionItems;

  Recommendation({
    required this.type,
    required this.priority,
    required this.title,
    required this.description,
    required this.actionItems,
  });
}

class RiskAlert {
  final String type;
  final String severity;
  final String message;
  final List<String> actions;

  RiskAlert({
    required this.type,
    required this.severity,
    required this.message,
    required this.actions,
  });
}

class LearningProgress {
  final int totalActivities;
  final int competenciesAddressed;
  final List<String> skillsImproved;
  final double progressRate;

  LearningProgress({
    required this.totalActivities,
    required this.competenciesAddressed,
    required this.skillsImproved,
    required this.progressRate,
  });
}

class BudgetHealth {
  final String status;
  final double utilizationRate;
  final double projectedOverrun;
  final List<String> savingsOpportunities;

  BudgetHealth({
    required this.status,
    required this.utilizationRate,
    required this.projectedOverrun,
    required this.savingsOpportunities,
  });
}

class _AnalyticsCache {
  final TimelineAnalytics data;
  final DateTime timestamp;

  _AnalyticsCache(this.data, this.timestamp);
}