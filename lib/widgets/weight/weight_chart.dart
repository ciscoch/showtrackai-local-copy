import 'package:flutter/material.dart';
import 'dart:math' as math;
import 'package:intl/intl.dart';
import '../../models/weight.dart';
import '../../models/weight_goal.dart';
import '../../models/animal.dart';
import '../../theme/app_theme.dart';

/// Comprehensive weight chart widget for visualizing weight progression and ADG data
/// Features:
/// - Line chart showing weight progression over time
/// - ADG trend visualization
/// - Goal progress tracking with target lines
/// - Multi-animal comparison charts
/// - Show weight markers on timeline
/// - Interactive tooltips and responsive design
class WeightChart extends StatefulWidget {
  final List<Weight> weights;
  final List<WeightGoal> goals;
  final List<Animal> animals;
  final String? selectedAnimalId;
  final WeightChartType chartType;
  final bool showADG;
  final bool showGoals;
  final bool showComparison;
  final Duration? timeRange;
  final VoidCallback? onDataPointTap;
  final Function(Weight)? onWeightTap;

  const WeightChart({
    super.key,
    required this.weights,
    this.goals = const [],
    this.animals = const [],
    this.selectedAnimalId,
    this.chartType = WeightChartType.weightProgression,
    this.showADG = false,
    this.showGoals = true,
    this.showComparison = false,
    this.timeRange,
    this.onDataPointTap,
    this.onWeightTap,
  });

  @override
  State<WeightChart> createState() => _WeightChartState();
}

class _WeightChartState extends State<WeightChart>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _animation;
  
  Weight? _hoveredWeight;
  WeightGoal? _hoveredGoal;
  Offset? _tooltipPosition;
  
  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    _animation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOutCubic,
    );
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  List<Weight> get _filteredWeights {
    var filtered = widget.weights.where((w) => w.status == WeightStatus.active).toList();
    
    // Filter by animal if specified
    if (widget.selectedAnimalId != null && !widget.showComparison) {
      filtered = filtered.where((w) => w.animalId == widget.selectedAnimalId).toList();
    }
    
    // Filter by time range
    if (widget.timeRange != null) {
      final cutoffDate = DateTime.now().subtract(widget.timeRange!);
      filtered = filtered.where((w) => w.measurementDate.isAfter(cutoffDate)).toList();
    }
    
    // Sort by date
    filtered.sort((a, b) => a.measurementDate.compareTo(b.measurementDate));
    
    return filtered;
  }

  List<WeightGoal> get _filteredGoals {
    if (!widget.showGoals) return [];
    
    var filtered = widget.goals.where((g) => g.status == GoalStatus.active).toList();
    
    if (widget.selectedAnimalId != null && !widget.showComparison) {
      filtered = filtered.where((g) => g.animalId == widget.selectedAnimalId).toList();
    }
    
    return filtered;
  }

  Map<String, List<Weight>> get _weightsByAnimal {
    final Map<String, List<Weight>> result = {};
    
    for (final weight in _filteredWeights) {
      result.putIfAbsent(weight.animalId, () => []).add(weight);
    }
    
    // Sort each animal's weights by date
    for (final weights in result.values) {
      weights.sort((a, b) => a.measurementDate.compareTo(b.measurementDate));
    }
    
    return result;
  }

  Animal? _getAnimalById(String animalId) {
    try {
      return widget.animals.firstWhere((a) => a.id == animalId);
    } catch (e) {
      return null;
    }
  }

  String _getAnimalName(String animalId) {
    final animal = _getAnimalById(animalId);
    return animal?.name ?? 'Unknown Animal';
  }

  Color _getAnimalColor(String animalId, {int index = 0}) {
    // Generate consistent colors for each animal
    final colors = [
      AppTheme.primaryGreen,
      AppTheme.accentBlue,
      AppTheme.accentOrange,
      Colors.purple,
      Colors.teal,
      Colors.amber,
      Colors.pink,
      Colors.indigo,
    ];
    
    final hash = animalId.hashCode;
    return colors[hash.abs() % colors.length];
  }

  @override
  Widget build(BuildContext context) {
    if (_filteredWeights.isEmpty) {
      return _EmptyChart();
    }

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildHeader(),
          _buildChartControls(),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: _buildChart(),
            ),
          ),
          if (widget.showComparison) _buildLegend(),
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
          Icon(
            _getChartIcon(),
            color: AppTheme.primaryGreen,
            size: 24,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _getChartTitle(),
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  _getChartSubtitle(),
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChartControls() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          _buildChartTypeSelector(),
          if (widget.chartType == WeightChartType.weightProgression) ...[
            _buildToggleChip(
              label: 'Show ADG',
              icon: Icons.speed,
              isSelected: widget.showADG,
              onTap: () {
                // This would be handled by parent widget
                widget.onDataPointTap?.call();
              },
            ),
            _buildToggleChip(
              label: 'Goals',
              icon: Icons.flag,
              isSelected: widget.showGoals,
              onTap: () {
                // This would be handled by parent widget
                widget.onDataPointTap?.call();
              },
            ),
          ],
          if (widget.animals.length > 1)
            _buildToggleChip(
              label: 'Compare',
              icon: Icons.compare,
              isSelected: widget.showComparison,
              onTap: () {
                // This would be handled by parent widget
                widget.onDataPointTap?.call();
              },
            ),
        ],
      ),
    );
  }

  Widget _buildChartTypeSelector() {
    return DropdownButtonHideUnderline(
      child: DropdownButton<WeightChartType>(
        value: widget.chartType,
        isDense: true,
        items: WeightChartType.values.map((type) {
          return DropdownMenuItem(
            value: type,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(_getChartTypeIcon(type), size: 16),
                const SizedBox(width: 8),
                Text(_getChartTypeLabel(type)),
              ],
            ),
          );
        }).toList(),
        onChanged: (value) {
          // This would be handled by parent widget
          if (value != null) {
            widget.onDataPointTap?.call();
          }
        },
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
          Icon(icon, size: 16),
          const SizedBox(width: 4),
          Text(label),
        ],
      ),
      selected: isSelected,
      onSelected: (_) => onTap(),
      selectedColor: AppTheme.primaryGreen.withOpacity(0.2),
      checkmarkColor: AppTheme.primaryGreen,
    );
  }

  Widget _buildChart() {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Stack(
          children: [
            CustomPaint(
              painter: WeightChartPainter(
                weights: _filteredWeights,
                goals: _filteredGoals,
                weightsByAnimal: _weightsByAnimal,
                chartType: widget.chartType,
                showADG: widget.showADG,
                showGoals: widget.showGoals,
                showComparison: widget.showComparison,
                animationProgress: _animation.value,
                hoveredWeight: _hoveredWeight,
                hoveredGoal: _hoveredGoal,
                getAnimalColor: _getAnimalColor,
                getAnimalName: _getAnimalName,
              ),
              child: GestureDetector(
                onTapDown: _handleTapDown,
                onPanUpdate: _handlePanUpdate,
                onPanEnd: _handlePanEnd,
                child: Container(),
              ),
            ),
            if (_hoveredWeight != null && _tooltipPosition != null)
              _buildTooltip(),
          ],
        );
      },
    );
  }

  Widget _buildLegend() {
    if (!widget.showComparison || _weightsByAnimal.length <= 1) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(12),
          bottomRight: Radius.circular(12),
        ),
      ),
      child: Wrap(
        spacing: 16,
        runSpacing: 8,
        children: _weightsByAnimal.keys.map((animalId) {
          final animal = _getAnimalById(animalId);
          final color = _getAnimalColor(animalId);
          
          return Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 16,
                height: 3,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                animal?.name ?? 'Unknown Animal',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          );
        }).toList(),
      ),
    );
  }

  Widget _buildTooltip() {
    final weight = _hoveredWeight!;
    final position = _tooltipPosition!;
    
    return Positioned(
      left: position.dx,
      top: position.dy,
      child: Material(
        color: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.8),
            borderRadius: BorderRadius.circular(8),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.2),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _getAnimalName(weight.animalId),
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '${weight.weightValue.toStringAsFixed(1)} ${weight.weightUnitDisplay}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                DateFormat('MMM d, yyyy').format(weight.measurementDate),
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 11,
                ),
              ),
              if (weight.adg != null) ...[
                const SizedBox(height: 2),
                Text(
                  'ADG: ${weight.adg!.toStringAsFixed(2)} lbs/day',
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 11,
                  ),
                ),
              ],
              if (weight.isShowWeight) ...[
                const SizedBox(height: 2),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.emoji_events,
                      color: Colors.amber,
                      size: 12,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Show Weight',
                      style: const TextStyle(
                        color: Colors.amber,
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  void _handleTapDown(TapDownDetails details) {
    final RenderBox renderBox = context.findRenderObject() as RenderBox;
    final localPosition = renderBox.globalToLocal(details.globalPosition);
    
    // Find the closest weight point
    final closestWeight = _findClosestWeight(localPosition);
    
    if (closestWeight != null) {
      widget.onWeightTap?.call(closestWeight);
      setState(() {
        _hoveredWeight = closestWeight;
        _tooltipPosition = localPosition;
      });
    }
  }

  void _handlePanUpdate(DragUpdateDetails details) {
    final RenderBox renderBox = context.findRenderObject() as RenderBox;
    final localPosition = renderBox.globalToLocal(details.globalPosition);
    
    final closestWeight = _findClosestWeight(localPosition);
    
    setState(() {
      _hoveredWeight = closestWeight;
      _tooltipPosition = closestWeight != null ? localPosition : null;
    });
  }

  void _handlePanEnd(DragEndDetails details) {
    setState(() {
      _hoveredWeight = null;
      _tooltipPosition = null;
    });
  }

  Weight? _findClosestWeight(Offset position) {
    // This is a simplified implementation
    // In a real chart, you'd convert screen coordinates to data coordinates
    final weights = _filteredWeights;
    if (weights.isEmpty) return null;
    
    // For now, just return a weight if the tap is within the chart area
    final chartHeight = 300.0; // Approximate chart height
    if (position.dy >= 50 && position.dy <= chartHeight - 50) {
      final index = ((position.dx / 300.0) * weights.length).round().clamp(0, weights.length - 1);
      return weights.isEmpty ? null : weights[math.min(index, weights.length - 1)];
    }
    
    return null;
  }

  IconData _getChartIcon() {
    switch (widget.chartType) {
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

  String _getChartTitle() {
    switch (widget.chartType) {
      case WeightChartType.weightProgression:
        return widget.showComparison ? 'Weight Comparison' : 'Weight Progress';
      case WeightChartType.adgTrend:
        return 'Average Daily Gain';
      case WeightChartType.goalProgress:
        return 'Goal Progress';
      case WeightChartType.comparison:
        return 'Multi-Animal Comparison';
    }
  }

  String _getChartSubtitle() {
    final animalCount = widget.showComparison 
        ? _weightsByAnimal.keys.length 
        : 1;
    final weightCount = _filteredWeights.length;
    
    if (widget.showComparison && animalCount > 1) {
      return '$animalCount animals • $weightCount total weights';
    } else {
      final animalName = widget.selectedAnimalId != null
          ? _getAnimalName(widget.selectedAnimalId!)
          : 'All animals';
      return '$animalName • $weightCount weights';
    }
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
        return 'Comparison';
    }
  }
}

/// Empty state widget when no weight data is available
class _EmptyChart extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Container(
        height: 300,
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.timeline_outlined,
              size: 64,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              'No Weight Data',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Record weight measurements to see charts',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Colors.grey[500],
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

/// Custom painter for drawing the weight chart
class WeightChartPainter extends CustomPainter {
  final List<Weight> weights;
  final List<WeightGoal> goals;
  final Map<String, List<Weight>> weightsByAnimal;
  final WeightChartType chartType;
  final bool showADG;
  final bool showGoals;
  final bool showComparison;
  final double animationProgress;
  final Weight? hoveredWeight;
  final WeightGoal? hoveredGoal;
  final Color Function(String, {int index}) getAnimalColor;
  final String Function(String) getAnimalName;

  WeightChartPainter({
    required this.weights,
    required this.goals,
    required this.weightsByAnimal,
    required this.chartType,
    required this.showADG,
    required this.showGoals,
    required this.showComparison,
    required this.animationProgress,
    this.hoveredWeight,
    this.hoveredGoal,
    required this.getAnimalColor,
    required this.getAnimalName,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (weights.isEmpty) return;

    final chartArea = Rect.fromLTWH(
      60, // Left margin for Y-axis labels
      20, // Top margin
      size.width - 80, // Right margin
      size.height - 60, // Bottom margin for X-axis labels
    );

    _drawAxes(canvas, chartArea);
    
    switch (chartType) {
      case WeightChartType.weightProgression:
        _drawWeightProgressionChart(canvas, chartArea);
        break;
      case WeightChartType.adgTrend:
        _drawADGTrendChart(canvas, chartArea);
        break;
      case WeightChartType.goalProgress:
        _drawGoalProgressChart(canvas, chartArea);
        break;
      case WeightChartType.comparison:
        _drawComparisonChart(canvas, chartArea);
        break;
    }
    
    if (showGoals && goals.isNotEmpty) {
      _drawGoalLines(canvas, chartArea);
    }
  }

  void _drawAxes(Canvas canvas, Rect chartArea) {
    final paint = Paint()
      ..color = Colors.grey[300]!
      ..strokeWidth = 1;

    // X-axis
    canvas.drawLine(
      Offset(chartArea.left, chartArea.bottom),
      Offset(chartArea.right, chartArea.bottom),
      paint,
    );

    // Y-axis
    canvas.drawLine(
      Offset(chartArea.left, chartArea.top),
      Offset(chartArea.left, chartArea.bottom),
      paint,
    );

    _drawAxisLabels(canvas, chartArea);
    _drawGridLines(canvas, chartArea);
  }

  void _drawAxisLabels(Canvas canvas, Rect chartArea) {
    // This would draw axis labels and values
    // Simplified implementation
    final textStyle = TextStyle(
      color: Colors.grey[600],
      fontSize: 12,
    );
    
    // Y-axis labels (weight values)
    if (weights.isNotEmpty) {
      final minWeight = weights.map((w) => w.weightValue).reduce(math.min);
      final maxWeight = weights.map((w) => w.weightValue).reduce(math.max);
      
      for (int i = 0; i <= 5; i++) {
        final value = minWeight + (maxWeight - minWeight) * i / 5;
        final y = chartArea.bottom - (chartArea.height * i / 5);
        
        final textPainter = TextPainter(
          text: TextSpan(
            text: value.toStringAsFixed(0),
            style: textStyle,
          ),
          textDirection: TextDirection.ltr,
        );
        textPainter.layout();
        textPainter.paint(
          canvas,
          Offset(chartArea.left - 40, y - textPainter.height / 2),
        );
      }
    }
  }

  void _drawGridLines(Canvas canvas, Rect chartArea) {
    final paint = Paint()
      ..color = Colors.grey[200]!
      ..strokeWidth = 0.5;

    // Horizontal grid lines
    for (int i = 1; i < 5; i++) {
      final y = chartArea.top + (chartArea.height * i / 5);
      canvas.drawLine(
        Offset(chartArea.left, y),
        Offset(chartArea.right, y),
        paint,
      );
    }

    // Vertical grid lines (simplified)
    final numLines = math.min(weights.length, 10);
    for (int i = 1; i < numLines; i++) {
      final x = chartArea.left + (chartArea.width * i / numLines);
      canvas.drawLine(
        Offset(x, chartArea.top),
        Offset(x, chartArea.bottom),
        paint,
      );
    }
  }

  void _drawWeightProgressionChart(Canvas canvas, Rect chartArea) {
    if (showComparison && weightsByAnimal.length > 1) {
      _drawMultipleWeightLines(canvas, chartArea);
    } else {
      _drawSingleWeightLine(canvas, chartArea, weights, getAnimalColor(weights.first.animalId));
    }
  }

  void _drawMultipleWeightLines(Canvas canvas, Rect chartArea) {
    int index = 0;
    for (final entry in weightsByAnimal.entries) {
      final animalId = entry.key;
      final animalWeights = entry.value;
      final color = getAnimalColor(animalId, index: index);
      
      _drawSingleWeightLine(canvas, chartArea, animalWeights, color);
      index++;
    }
  }

  void _drawSingleWeightLine(Canvas canvas, Rect chartArea, List<Weight> weightsData, Color color) {
    if (weightsData.length < 2) return;

    final paint = Paint()
      ..color = color
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke;

    final path = Path();
    final points = <Offset>[];

    // Calculate min/max for scaling
    final allWeights = showComparison 
        ? weights.map((w) => w.weightValue).toList()
        : weightsData.map((w) => w.weightValue).toList();
    final minWeight = allWeights.reduce(math.min);
    final maxWeight = allWeights.reduce(math.max);
    final weightRange = maxWeight - minWeight;

    final sortedWeights = List<Weight>.from(weightsData)
      ..sort((a, b) => a.measurementDate.compareTo(b.measurementDate));

    for (int i = 0; i < sortedWeights.length; i++) {
      final weight = sortedWeights[i];
      
      final x = chartArea.left + (chartArea.width * i / (sortedWeights.length - 1));
      final normalizedWeight = weightRange > 0 ? (weight.weightValue - minWeight) / weightRange : 0.5;
      final y = chartArea.bottom - (chartArea.height * normalizedWeight);
      
      final point = Offset(x, y);
      points.add(point);
      
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        // Apply animation
        final animatedX = chartArea.left + ((x - chartArea.left) * animationProgress);
        path.lineTo(animatedX, y);
      }
    }

    canvas.drawPath(path, paint);

    // Draw data points
    final pointPaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    for (int i = 0; i < points.length; i++) {
      final point = points[i];
      final animatedPoint = Offset(
        chartArea.left + ((point.dx - chartArea.left) * animationProgress),
        point.dy,
      );
      
      final weight = sortedWeights[i];
      final radius = weight.isShowWeight ? 6.0 : 4.0;
      
      // Highlight hovered point
      if (hoveredWeight == weight) {
        canvas.drawCircle(
          animatedPoint,
          radius + 3,
          Paint()..color = color.withOpacity(0.3),
        );
      }
      
      canvas.drawCircle(animatedPoint, radius, pointPaint);
      
      // Show markers for show weights
      if (weight.isShowWeight) {
        canvas.drawCircle(
          animatedPoint,
          radius + 2,
          Paint()
            ..color = Colors.amber
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2,
        );
      }
    }
  }

  void _drawADGTrendChart(Canvas canvas, Rect chartArea) {
    final weightsWithADG = weights.where((w) => w.adg != null).toList();
    if (weightsWithADG.isEmpty) return;

    final paint = Paint()
      ..color = AppTheme.accentBlue
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    final path = Path();
    final minADG = weightsWithADG.map((w) => w.adg!).reduce(math.min);
    final maxADG = weightsWithADG.map((w) => w.adg!).reduce(math.max);
    final adgRange = maxADG - minADG;

    weightsWithADG.sort((a, b) => a.measurementDate.compareTo(b.measurementDate));

    for (int i = 0; i < weightsWithADG.length; i++) {
      final weight = weightsWithADG[i];
      final adg = weight.adg!;
      
      final x = chartArea.left + (chartArea.width * i / (weightsWithADG.length - 1));
      final normalizedADG = adgRange > 0 ? (adg - minADG) / adgRange : 0.5;
      final y = chartArea.bottom - (chartArea.height * normalizedADG);
      
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        final animatedX = chartArea.left + ((x - chartArea.left) * animationProgress);
        path.lineTo(animatedX, y);
      }
    }

    canvas.drawPath(path, paint);

    // Draw zero line for ADG
    if (minADG < 0 && maxADG > 0) {
      final zeroY = chartArea.bottom - (chartArea.height * (-minADG / adgRange));
      canvas.drawLine(
        Offset(chartArea.left, zeroY),
        Offset(chartArea.right, zeroY),
        Paint()
          ..color = Colors.red.withOpacity(0.5)
          ..strokeWidth = 1
          ..style = PaintingStyle.stroke,
      );
    }
  }

  void _drawGoalProgressChart(Canvas canvas, Rect chartArea) {
    // This would show progress toward goals over time
    // Simplified implementation showing goal target lines
    _drawGoalLines(canvas, chartArea);
  }

  void _drawComparisonChart(Canvas canvas, Rect chartArea) {
    _drawMultipleWeightLines(canvas, chartArea);
  }

  void _drawGoalLines(Canvas canvas, Rect chartArea) {
    if (goals.isEmpty) return;

    final paint = Paint()
      ..color = Colors.orange
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    for (final goal in goals) {
      // Calculate goal line position
      final allWeights = weights.map((w) => w.weightValue).toList();
      if (allWeights.isEmpty) continue;
      
      final minWeight = allWeights.reduce(math.min);
      final maxWeight = allWeights.reduce(math.max);
      final weightRange = maxWeight - minWeight;
      
      final normalizedGoal = weightRange > 0 
          ? (goal.targetWeight - minWeight) / weightRange 
          : 0.5;
      final goalY = chartArea.bottom - (chartArea.height * normalizedGoal);
      
      // Draw dashed line
      _drawDashedLine(
        canvas,
        Offset(chartArea.left, goalY),
        Offset(chartArea.right, goalY),
        paint,
      );
      
      // Goal label
      final textPainter = TextPainter(
        text: TextSpan(
          text: '${goal.targetWeight.toStringAsFixed(0)} lbs',
          style: TextStyle(
            color: Colors.orange[700],
            fontSize: 10,
            fontWeight: FontWeight.w500,
          ),
        ),
        textDirection: TextDirection.ltr,
      );
      textPainter.layout();
      textPainter.paint(
        canvas,
        Offset(chartArea.right - textPainter.width - 5, goalY - textPainter.height - 2),
      );
    }
  }

  void _drawDashedLine(Canvas canvas, Offset start, Offset end, Paint paint) {
    const dashWidth = 5.0;
    const dashSpace = 3.0;
    
    final distance = (end - start).distance;
    final normalizedVector = (end - start) / distance;
    
    double currentDistance = 0;
    while (currentDistance < distance) {
      final dashEnd = math.min(currentDistance + dashWidth, distance);
      canvas.drawLine(
        start + normalizedVector * currentDistance,
        start + normalizedVector * dashEnd,
        paint,
      );
      currentDistance += dashWidth + dashSpace;
    }
  }

  @override
  bool shouldRepaint(covariant WeightChartPainter oldDelegate) {
    return oldDelegate.weights != weights ||
           oldDelegate.goals != goals ||
           oldDelegate.animationProgress != animationProgress ||
           oldDelegate.hoveredWeight != hoveredWeight ||
           oldDelegate.chartType != chartType ||
           oldDelegate.showADG != showADG ||
           oldDelegate.showGoals != showGoals ||
           oldDelegate.showComparison != showComparison;
  }
}

/// Types of weight charts available
enum WeightChartType {
  weightProgression,
  adgTrend,
  goalProgress,
  comparison,
}