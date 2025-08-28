import 'package:flutter/material.dart';
import '../../models/weight.dart';
import '../../models/weight_goal.dart';
import '../../models/animal.dart';
import '../../theme/app_theme.dart';
import 'weight_chart.dart';

/// Container widget that manages weight chart state and provides controls
/// This widget handles the chart configuration and user interactions
class WeightChartContainer extends StatefulWidget {
  final List<Weight> weights;
  final List<WeightGoal> goals;
  final List<Animal> animals;
  final String? initialAnimalId;
  final bool allowComparison;
  final bool allowGoalTracking;
  final Function(Weight)? onWeightSelected;
  final Function(WeightGoal)? onGoalSelected;
  final VoidCallback? onAddWeight;

  const WeightChartContainer({
    super.key,
    required this.weights,
    this.goals = const [],
    this.animals = const [],
    this.initialAnimalId,
    this.allowComparison = true,
    this.allowGoalTracking = true,
    this.onWeightSelected,
    this.onGoalSelected,
    this.onAddWeight,
  });

  @override
  State<WeightChartContainer> createState() => _WeightChartContainerState();
}

class _WeightChartContainerState extends State<WeightChartContainer> {
  WeightChartType _chartType = WeightChartType.weightProgression;
  String? _selectedAnimalId;
  bool _showADG = false;
  bool _showGoals = true;
  bool _showComparison = false;
  Duration? _timeRange;
  bool _isFullScreen = false;

  @override
  void initState() {
    super.initState();
    _selectedAnimalId = widget.initialAnimalId;
  }

  @override
  Widget build(BuildContext context) {
    if (_isFullScreen) {
      return _buildFullScreenChart();
    }

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildHeader(),
          _buildControlPanel(),
          SizedBox(
            height: 300,
            child: _buildChart(),
          ),
          _buildFooter(),
        ],
      ),
    );
  }

  Widget _buildFullScreenChart() {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Weight Analysis'),
        backgroundColor: AppTheme.primaryGreen,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            onPressed: () => setState(() => _isFullScreen = false),
            icon: const Icon(Icons.fullscreen_exit),
            tooltip: 'Exit Full Screen',
          ),
        ],
      ),
      body: Column(
        children: [
          Container(
            color: AppTheme.primaryGreen.withOpacity(0.05),
            child: _buildControlPanel(),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: _buildChart(),
            ),
          ),
          Container(
            color: Colors.grey[50],
            child: _buildFooter(),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.primaryGreen.withOpacity(0.05),
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(12),
          topRight: Radius.circular(12),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppTheme.primaryGreen.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              Icons.timeline,
              color: AppTheme.primaryGreen,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Weight Analytics',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  _getSubtitle(),
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () => setState(() => _isFullScreen = true),
            icon: const Icon(Icons.fullscreen),
            tooltip: 'Full Screen',
          ),
          if (widget.onAddWeight != null)
            IconButton(
              onPressed: widget.onAddWeight,
              icon: const Icon(Icons.add),
              tooltip: 'Add Weight',
            ),
        ],
      ),
    );
  }

  Widget _buildControlPanel() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Chart type and animal selection row
          Row(
            children: [
              Expanded(
                child: _buildChartTypeSelector(),
              ),
              const SizedBox(width: 16),
              if (widget.animals.length > 1)
                Expanded(
                  child: _buildAnimalSelector(),
                ),
            ],
          ),
          const SizedBox(height: 12),
          // Options row
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (_chartType == WeightChartType.weightProgression)
                _buildToggleChip(
                  label: 'Show ADG',
                  icon: Icons.speed,
                  isSelected: _showADG,
                  onTap: () => setState(() => _showADG = !_showADG),
                ),
              if (widget.allowGoalTracking && widget.goals.isNotEmpty)
                _buildToggleChip(
                  label: 'Show Goals',
                  icon: Icons.flag,
                  isSelected: _showGoals,
                  onTap: () => setState(() => _showGoals = !_showGoals),
                ),
              if (widget.allowComparison && widget.animals.length > 1)
                _buildToggleChip(
                  label: 'Compare Animals',
                  icon: Icons.compare,
                  isSelected: _showComparison,
                  onTap: () => setState(() => _showComparison = !_showComparison),
                ),
              _buildTimeRangeSelector(),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildChartTypeSelector() {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey[300]!),
        borderRadius: BorderRadius.circular(8),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<WeightChartType>(
          value: _chartType,
          isExpanded: true,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          items: WeightChartType.values.map((type) {
            return DropdownMenuItem(
              value: type,
              child: Row(
                children: [
                  Icon(_getChartTypeIcon(type), size: 16),
                  const SizedBox(width: 8),
                  Text(_getChartTypeLabel(type)),
                ],
              ),
            );
          }).toList(),
          onChanged: (value) {
            if (value != null) {
              setState(() {
                _chartType = value;
                // Auto-enable comparison for comparison chart type
                if (value == WeightChartType.comparison) {
                  _showComparison = true;
                }
              });
            }
          },
        ),
      ),
    );
  }

  Widget _buildAnimalSelector() {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey[300]!),
        borderRadius: BorderRadius.circular(8),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String?>(
          value: _selectedAnimalId,
          isExpanded: true,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          items: [
            const DropdownMenuItem<String?>(
              value: null,
              child: Text('All Animals'),
            ),
            ...widget.animals.map((animal) => DropdownMenuItem<String>(
              value: animal.id,
              child: Row(
                children: [
                  Icon(Icons.pets, size: 16, color: Colors.grey[600]),
                  const SizedBox(width: 8),
                  Expanded(child: Text(animal.name)),
                ],
              ),
            )),
          ],
          onChanged: (value) {
            setState(() {
              _selectedAnimalId = value;
              // Disable comparison when specific animal is selected
              if (value != null) {
                _showComparison = false;
              }
            });
          },
        ),
      ),
    );
  }

  Widget _buildToggleChip({
    required String label,
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return FilterChip(
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14),
          const SizedBox(width: 4),
          Text(label, style: const TextStyle(fontSize: 12)),
        ],
      ),
      selected: isSelected,
      onSelected: (_) => onTap(),
      selectedColor: AppTheme.primaryGreen.withOpacity(0.2),
      checkmarkColor: AppTheme.primaryGreen,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
    );
  }

  Widget _buildTimeRangeSelector() {
    return PopupMenuButton<Duration?>(
      child: FilterChip(
        label: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.date_range, size: 14),
            const SizedBox(width: 4),
            Text(_getTimeRangeLabel(), style: const TextStyle(fontSize: 12)),
          ],
        ),
        selected: _timeRange != null,
        selectedColor: AppTheme.accentBlue.withOpacity(0.2),
        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
      itemBuilder: (context) => [
        const PopupMenuItem<Duration?>(
          value: null,
          child: Text('All Time'),
        ),
        const PopupMenuItem<Duration>(
          value: Duration(days: 30),
          child: Text('Last 30 Days'),
        ),
        const PopupMenuItem<Duration>(
          value: Duration(days: 90),
          child: Text('Last 3 Months'),
        ),
        const PopupMenuItem<Duration>(
          value: Duration(days: 180),
          child: Text('Last 6 Months'),
        ),
        const PopupMenuItem<Duration>(
          value: Duration(days: 365),
          child: Text('Last Year'),
        ),
      ],
      onSelected: (timeRange) {
        setState(() {
          _timeRange = timeRange;
        });
      },
    );
  }

  Widget _buildChart() {
    return WeightChart(
      weights: widget.weights,
      goals: widget.goals,
      animals: widget.animals,
      selectedAnimalId: _selectedAnimalId,
      chartType: _chartType,
      showADG: _showADG,
      showGoals: _showGoals,
      showComparison: _showComparison,
      timeRange: _timeRange,
      onWeightTap: widget.onWeightSelected,
      onDataPointTap: () {
        // Handle chart interaction if needed
      },
    );
  }

  Widget _buildFooter() {
    final filteredWeights = _getFilteredWeights();
    final stats = _calculateQuickStats(filteredWeights);
    
    return Container(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Expanded(
            child: _buildStatItem(
              'Total Weights',
              stats['count']?.toString() ?? '0',
              Icons.scale,
            ),
          ),
          Container(
            width: 1,
            height: 30,
            color: Colors.grey[300],
          ),
          Expanded(
            child: _buildStatItem(
              'Latest Weight',
              stats['latest'] ?? '--',
              Icons.monitor_weight,
            ),
          ),
          Container(
            width: 1,
            height: 30,
            color: Colors.grey[300],
          ),
          Expanded(
            child: _buildStatItem(
              'Avg ADG',
              stats['avgAdg'] ?? '--',
              Icons.speed,
            ),
          ),
          if (_showGoals && widget.goals.isNotEmpty) ...[
            Container(
              width: 1,
              height: 30,
              color: Colors.grey[300],
            ),
            Expanded(
              child: _buildStatItem(
                'Goals',
                '${_getActiveGoalsCount()}',
                Icons.flag,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, String value, IconData icon) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          icon,
          size: 16,
          color: AppTheme.primaryGreen,
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: Colors.grey[600],
          ),
        ),
      ],
    );
  }

  List<Weight> _getFilteredWeights() {
    var filtered = widget.weights.where((w) => w.status == WeightStatus.active).toList();
    
    if (_selectedAnimalId != null && !_showComparison) {
      filtered = filtered.where((w) => w.animalId == _selectedAnimalId).toList();
    }
    
    if (_timeRange != null) {
      final cutoffDate = DateTime.now().subtract(_timeRange!);
      filtered = filtered.where((w) => w.measurementDate.isAfter(cutoffDate)).toList();
    }
    
    return filtered;
  }

  Map<String, dynamic> _calculateQuickStats(List<Weight> weights) {
    if (weights.isEmpty) {
      return {'count': 0, 'latest': '--', 'avgAdg': '--'};
    }

    // Sort by date
    weights.sort((a, b) => a.measurementDate.compareTo(b.measurementDate));

    final latestWeight = weights.last;
    final weightsWithAdg = weights.where((w) => w.adg != null).toList();
    
    double? avgAdg;
    if (weightsWithAdg.isNotEmpty) {
      final totalAdg = weightsWithAdg.map((w) => w.adg!).reduce((a, b) => a + b);
      avgAdg = totalAdg / weightsWithAdg.length;
    }

    return {
      'count': weights.length,
      'latest': '${latestWeight.weightValue.toStringAsFixed(1)} ${latestWeight.weightUnitDisplay}',
      'avgAdg': avgAdg != null ? '${avgAdg.toStringAsFixed(2)} lbs/day' : '--',
    };
  }

  int _getActiveGoalsCount() {
    var goals = widget.goals.where((g) => g.status == GoalStatus.active);
    
    if (_selectedAnimalId != null && !_showComparison) {
      goals = goals.where((g) => g.animalId == _selectedAnimalId);
    }
    
    return goals.length;
  }

  String _getSubtitle() {
    final weightCount = _getFilteredWeights().length;
    final animalCount = _showComparison 
        ? widget.animals.length 
        : 1;
    
    if (_showComparison && animalCount > 1) {
      return '$animalCount animals • $weightCount weights';
    } else {
      final animalName = _selectedAnimalId != null
          ? widget.animals.firstWhere((a) => a.id == _selectedAnimalId).name
          : 'All animals';
      return '$animalName • $weightCount weights';
    }
  }

  String _getTimeRangeLabel() {
    if (_timeRange == null) return 'All Time';
    
    final days = _timeRange!.inDays;
    if (days <= 30) return '30 Days';
    if (days <= 90) return '3 Months';
    if (days <= 180) return '6 Months';
    if (days <= 365) return '1 Year';
    return 'Custom';
  }

  IconData _getChartTypeIcon(WeightChartType type) {
    switch (type) {
      case WeightChartType.weightProgression:
        return Icons.timeline;
      case WeightChartType.adgTrend:
        return Icons.speed;
      case WeightChartType.goalProgress:
        return Icons.flag;
      case WeightChartType.comparison:
        return Icons.compare;
    }
  }

  String _getChartTypeLabel(WeightChartType type) {
    switch (type) {
      case WeightChartType.weightProgression:
        return 'Weight Progress';
      case WeightChartType.adgTrend:
        return 'ADG Trend';
      case WeightChartType.goalProgress:
        return 'Goal Progress';
      case WeightChartType.comparison:
        return 'Compare Animals';
    }
  }
}

/// Simplified weight chart widget for dashboard cards
class WeightMiniChart extends StatelessWidget {
  final List<Weight> weights;
  final String? animalId;
  final Color? color;
  final double height;
  final bool showLabels;

  const WeightMiniChart({
    super.key,
    required this.weights,
    this.animalId,
    this.color,
    this.height = 60,
    this.showLabels = false,
  });

  @override
  Widget build(BuildContext context) {
    final filteredWeights = weights
        .where((w) => 
          w.status == WeightStatus.active &&
          (animalId == null || w.animalId == animalId))
        .toList();

    if (filteredWeights.isEmpty) {
      return SizedBox(
        height: height,
        child: Center(
          child: Text(
            'No Data',
            style: TextStyle(
              color: Colors.grey[500],
              fontSize: 12,
            ),
          ),
        ),
      );
    }

    return SizedBox(
      height: height,
      child: CustomPaint(
        painter: WeightMiniChartPainter(
          weights: filteredWeights,
          color: color ?? AppTheme.primaryGreen,
          showLabels: showLabels,
        ),
        child: Container(),
      ),
    );
  }
}

/// Custom painter for mini weight chart
class WeightMiniChartPainter extends CustomPainter {
  final List<Weight> weights;
  final Color color;
  final bool showLabels;

  WeightMiniChartPainter({
    required this.weights,
    required this.color,
    required this.showLabels,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (weights.length < 2) return;

    final sortedWeights = List<Weight>.from(weights)
      ..sort((a, b) => a.measurementDate.compareTo(b.measurementDate));

    final minWeight = sortedWeights.map((w) => w.weightValue).reduce((a, b) => a < b ? a : b);
    final maxWeight = sortedWeights.map((w) => w.weightValue).reduce((a, b) => a > b ? a : b);
    final weightRange = maxWeight - minWeight;

    if (weightRange == 0) return;

    final paint = Paint()
      ..color = color
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    final path = Path();
    final margin = showLabels ? 20.0 : 5.0;
    final chartWidth = size.width - (margin * 2);
    final chartHeight = size.height - (margin * 2);

    for (int i = 0; i < sortedWeights.length; i++) {
      final weight = sortedWeights[i];
      final x = margin + (chartWidth * i / (sortedWeights.length - 1));
      final normalizedWeight = (weight.weightValue - minWeight) / weightRange;
      final y = size.height - margin - (chartHeight * normalizedWeight);

      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }

    canvas.drawPath(path, paint);

    // Draw filled area under curve
    final fillPath = Path.from(path);
    fillPath.lineTo(size.width - margin, size.height - margin);
    fillPath.lineTo(margin, size.height - margin);
    fillPath.close();

    canvas.drawPath(
      fillPath,
      Paint()
        ..color = color.withOpacity(0.2)
        ..style = PaintingStyle.fill,
    );

    // Draw data points
    final pointPaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    for (int i = 0; i < sortedWeights.length; i++) {
      final weight = sortedWeights[i];
      final x = margin + (chartWidth * i / (sortedWeights.length - 1));
      final normalizedWeight = (weight.weightValue - minWeight) / weightRange;
      final y = size.height - margin - (chartHeight * normalizedWeight);

      canvas.drawCircle(Offset(x, y), 2, pointPaint);
    }

    // Draw labels if enabled
    if (showLabels && sortedWeights.isNotEmpty) {
      final textStyle = TextStyle(
        color: Colors.grey[700],
        fontSize: 10,
      );

      // First weight label
      final firstWeight = sortedWeights.first;
      final firstLabel = TextPainter(
        text: TextSpan(
          text: firstWeight.weightValue.toStringAsFixed(0),
          style: textStyle,
        ),
        textDirection: TextDirection.ltr,
      );
      firstLabel.layout();
      firstLabel.paint(canvas, Offset(margin, 2));

      // Last weight label
      final lastWeight = sortedWeights.last;
      final lastLabel = TextPainter(
        text: TextSpan(
          text: lastWeight.weightValue.toStringAsFixed(0),
          style: textStyle,
        ),
        textDirection: TextDirection.ltr,
      );
      lastLabel.layout();
      lastLabel.paint(
        canvas,
        Offset(size.width - margin - lastLabel.width, 2),
      );
    }
  }

  @override
  bool shouldRepaint(covariant WeightMiniChartPainter oldDelegate) {
    return oldDelegate.weights != weights ||
           oldDelegate.color != color ||
           oldDelegate.showLabels != showLabels;
  }
}