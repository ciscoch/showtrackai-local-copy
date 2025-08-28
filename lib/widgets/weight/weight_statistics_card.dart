import 'package:flutter/material.dart';
import '../../models/weight.dart';
import '../../models/weight_goal.dart';
import '../../models/animal.dart';
import '../../theme/app_theme.dart';

/// Dashboard card showing weight statistics and ADG analytics
/// Features trend indicators, progress charts, and quick insights
class WeightStatisticsCard extends StatefulWidget {
  final List<Weight> weights;
  final List<WeightGoal> goals;
  final List<Animal> animals;
  final VoidCallback onViewDetails;
  final String? selectedAnimalId;

  const WeightStatisticsCard({
    super.key,
    required this.weights,
    required this.goals,
    required this.animals,
    required this.onViewDetails,
    this.selectedAnimalId,
  });

  @override
  State<WeightStatisticsCard> createState() => _WeightStatisticsCardState();
}

class _WeightStatisticsCardState extends State<WeightStatisticsCard> {
  String? _selectedAnimalId;

  @override
  void initState() {
    super.initState();
    _selectedAnimalId = widget.selectedAnimalId;
  }

  List<Weight> get _filteredWeights {
    var filtered = widget.weights.where((w) => w.status == WeightStatus.active).toList();
    if (_selectedAnimalId != null) {
      filtered = filtered.where((w) => w.animalId == _selectedAnimalId).toList();
    }
    return filtered;
  }

  WeightStatistics get _statistics {
    final weights = _filteredWeights;
    if (weights.isEmpty) {
      return WeightStatistics(
        animalId: _selectedAnimalId ?? 'all',
        totalWeights: 0,
      );
    }

    // Sort by date
    weights.sort((a, b) => a.measurementDate.compareTo(b.measurementDate));

    final firstWeight = weights.first;
    final lastWeight = weights.last;
    final currentWeight = lastWeight.weightValue;
    final startingWeight = firstWeight.weightValue;

    // Calculate ADG values
    final validAdgs = weights
        .where((w) => w.adg != null)
        .map((w) => w.adg!)
        .toList();

    double? averageAdg;
    double? bestAdg;
    double? worstAdg;
    
    if (validAdgs.isNotEmpty) {
      averageAdg = validAdgs.reduce((a, b) => a + b) / validAdgs.length;
      bestAdg = validAdgs.reduce((a, b) => a > b ? a : b);
      worstAdg = validAdgs.reduce((a, b) => a < b ? a : b);
    }

    // Recent trend analysis
    final recentWeights = weights.where((w) => 
      w.measurementDate.isAfter(DateTime.now().subtract(const Duration(days: 7)))
    ).toList();
    
    double? currentWeekAdg;
    if (recentWeights.length >= 2) {
      final weekStart = recentWeights.first;
      final weekEnd = recentWeights.last;
      final daysDiff = weekEnd.measurementDate.difference(weekStart.measurementDate).inDays;
      if (daysDiff > 0) {
        currentWeekAdg = (weekEnd.weightValue - weekStart.weightValue) / daysDiff;
      }
    }

    // Trend direction
    String? weightTrend;
    if (averageAdg != null) {
      if (averageAdg > 0.5) {
        weightTrend = 'increasing';
      } else if (averageAdg < -0.1) {
        weightTrend = 'decreasing';
      } else {
        weightTrend = 'stable';
      }
    }

    return WeightStatistics(
      animalId: _selectedAnimalId ?? 'all',
      totalWeights: weights.length,
      firstWeightDate: firstWeight.measurementDate,
      lastWeightDate: lastWeight.measurementDate,
      currentWeight: currentWeight,
      startingWeight: startingWeight,
      highestWeight: weights.map((w) => w.weightValue).reduce((a, b) => a > b ? a : b),
      lowestWeight: weights.map((w) => w.weightValue).reduce((a, b) => a < b ? a : b),
      averageAdg: averageAdg,
      bestAdgPeriod: bestAdg,
      worstAdgPeriod: worstAdg,
      currentWeekAdg: currentWeekAdg,
      weightTrend: weightTrend,
      lastCalculated: DateTime.now(),
    );
  }

  List<WeightGoal> get _activeGoals {
    var goals = widget.goals.where((g) => g.status == GoalStatus.active).toList();
    if (_selectedAnimalId != null) {
      goals = goals.where((g) => g.animalId == _selectedAnimalId).toList();
    }
    return goals;
  }

  Animal? _getAnimalById(String animalId) {
    try {
      return widget.animals.firstWhere((a) => a.id == animalId);
    } catch (e) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final stats = _statistics;
    final activeGoals = _activeGoals;

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with Animal Filter
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryGreen.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.analytics,
                    color: AppTheme.primaryGreen,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'Weight Analytics',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: widget.onViewDetails,
                  icon: const Icon(Icons.open_in_full),
                  tooltip: 'View Details',
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Animal Filter
            if (widget.animals.length > 1)
              DropdownButtonFormField<String>(
                value: _selectedAnimalId,
                decoration: const InputDecoration(
                  labelText: 'Filter by Animal',
                  prefixIcon: Icon(Icons.pets, size: 20),
                  isDense: true,
                ),
                items: [
                  const DropdownMenuItem<String>(
                    value: null,
                    child: Text('All Animals'),
                  ),
                  ...widget.animals.map((animal) => DropdownMenuItem<String>(
                    value: animal.id,
                    child: Text(animal.name),
                  )),
                ],
                onChanged: (value) {
                  setState(() {
                    _selectedAnimalId = value;
                  });
                },
              ),

            if (widget.animals.length > 1)
              const SizedBox(height: 16),

            if (stats.totalWeights == 0)
              _EmptyState()
            else ...[
              // Key Metrics Row
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey[50],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: _MetricTile(
                            title: 'Current Weight',
                            value: '${stats.currentWeight?.toStringAsFixed(1) ?? '--'} lbs',
                            icon: Icons.monitor_weight,
                            color: AppTheme.primaryGreen,
                          ),
                        ),
                        Expanded(
                          child: _MetricTile(
                            title: 'Total Gain',
                            value: stats.totalWeightGain != null
                                ? '${stats.totalWeightGain! > 0 ? "+" : ""}${stats.totalWeightGain!.toStringAsFixed(1)} lbs'
                                : '--',
                            icon: stats.totalWeightGain != null && stats.totalWeightGain! > 0
                                ? Icons.trending_up
                                : Icons.trending_down,
                            color: stats.totalWeightGain != null && stats.totalWeightGain! > 0
                                ? Colors.green
                                : Colors.red,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: _MetricTile(
                            title: 'Avg ADG',
                            value: stats.averageAdg != null
                                ? '${stats.averageAdg!.toStringAsFixed(2)} lbs/day'
                                : '--',
                            icon: Icons.speed,
                            color: AppTheme.accentBlue,
                          ),
                        ),
                        Expanded(
                          child: _MetricTile(
                            title: 'Days Tracked',
                            value: stats.daysOfTracking?.toString() ?? '--',
                            icon: Icons.calendar_today,
                            color: AppTheme.accentOrange,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Trend Indicator
              if (stats.weightTrend != null)
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: _getTrendColor(stats.weightTrend!).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: _getTrendColor(stats.weightTrend!).withOpacity(0.3),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        _getTrendIcon(stats.weightTrend!),
                        color: _getTrendColor(stats.weightTrend!),
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _getTrendText(stats.weightTrend!),
                        style: TextStyle(
                          color: _getTrendColor(stats.weightTrend!),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const Spacer(),
                      if (stats.currentWeekAdg != null)
                        Text(
                          'Recent: ${stats.currentWeekAdg! > 0 ? "+" : ""}${stats.currentWeekAdg!.toStringAsFixed(2)} lbs/day',
                          style: TextStyle(
                            color: Colors.grey[700],
                            fontSize: 13,
                          ),
                        ),
                    ],
                  ),
                ),

              if (stats.weightTrend != null)
                const SizedBox(height: 16),

              // Performance Insights
              if (stats.bestAdgPeriod != null || stats.worstAdgPeriod != null)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Performance Range',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        if (stats.bestAdgPeriod != null)
                          Expanded(
                            child: _PerformanceChip(
                              label: 'Best Period',
                              value: '${stats.bestAdgPeriod!.toStringAsFixed(2)} lbs/day',
                              color: Colors.green,
                              icon: Icons.arrow_upward,
                            ),
                          ),
                        if (stats.bestAdgPeriod != null && stats.worstAdgPeriod != null)
                          const SizedBox(width: 8),
                        if (stats.worstAdgPeriod != null)
                          Expanded(
                            child: _PerformanceChip(
                              label: 'Lowest Period',
                              value: '${stats.worstAdgPeriod!.toStringAsFixed(2)} lbs/day',
                              color: stats.worstAdgPeriod! < 0 ? Colors.red : Colors.orange,
                              icon: Icons.arrow_downward,
                            ),
                          ),
                      ],
                    ),
                  ],
                ),

              if (stats.bestAdgPeriod != null || stats.worstAdgPeriod != null)
                const SizedBox(height: 16),

              // Active Goals Summary
              if (activeGoals.isNotEmpty)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Goal Progress',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    ...activeGoals.take(2).map((goal) => _GoalProgressItem(goal: goal)),
                    if (activeGoals.length > 2)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: TextButton(
                          onPressed: widget.onViewDetails,
                          child: Text('View ${activeGoals.length - 2} more goals'),
                        ),
                      ),
                  ],
                ),
            ],
          ],
        ),
      ),
    );
  }

  Color _getTrendColor(String trend) {
    switch (trend) {
      case 'increasing':
        return Colors.green;
      case 'decreasing':
        return Colors.red;
      default:
        return Colors.orange;
    }
  }

  IconData _getTrendIcon(String trend) {
    switch (trend) {
      case 'increasing':
        return Icons.trending_up;
      case 'decreasing':
        return Icons.trending_down;
      default:
        return Icons.trending_flat;
    }
  }

  String _getTrendText(String trend) {
    switch (trend) {
      case 'increasing':
        return 'Gaining Weight Consistently';
      case 'decreasing':
        return 'Weight Loss Detected';
      default:
        return 'Weight Stable';
    }
  }
}

class _EmptyState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          children: [
            Icon(
              Icons.analytics_outlined,
              size: 48,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              'No Weight Data',
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Record weights to see analytics',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}

class _MetricTile extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;

  const _MetricTile({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              color: color,
              size: 16,
            ),
            const SizedBox(width: 4),
            Text(
              title,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: color,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}

class _PerformanceChip extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  final IconData icon;

  const _PerformanceChip({
    required this.label,
    required this.value,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                icon,
                color: color,
                size: 14,
              ),
              const SizedBox(width: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.grey[700],
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class _GoalProgressItem extends StatelessWidget {
  final WeightGoal goal;

  const _GoalProgressItem({
    required this.goal,
  });

  @override
  Widget build(BuildContext context) {
    final progress = goal.progressPercentage ?? 0;
    final isOnTrack = goal.isOnTrack;
    final daysLeft = goal.daysRemaining ?? 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  goal.goalName,
                  style: const TextStyle(
                    fontWeight: FontWeight.w500,
                    fontSize: 13,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: (isOnTrack ? Colors.green : Colors.orange).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  isOnTrack ? 'On Track' : 'Behind',
                  style: TextStyle(
                    color: isOnTrack ? Colors.green : Colors.orange,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: LinearProgressIndicator(
                  value: progress / 100,
                  backgroundColor: Colors.grey[300],
                  valueColor: AlwaysStoppedAnimation<Color>(
                    isOnTrack ? Colors.green : Colors.orange,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '${progress.toStringAsFixed(0)}%',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            '$daysLeft days remaining',
            style: TextStyle(
              fontSize: 11,
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }
}