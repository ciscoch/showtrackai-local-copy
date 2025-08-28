import 'package:flutter/material.dart';
import '../../models/feed_inventory.dart';
import '../../theme/mobile_responsive_theme.dart';

/// Card widget for displaying Feed Conversion Ratio tracking information
class FCRTrackingCard extends StatelessWidget {
  final FCRPerformance performance;
  final VoidCallback? onTap;

  const FCRTrackingCard({
    Key? key,
    required this.performance,
    this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final isSmall = ResponsiveUtils.isSmallScreen(context);
    
    return Card(
      margin: EdgeInsets.all(isSmall ? 4 : 8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: ResponsiveUtils.getResponsivePadding(context),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header with animal name and species
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: _getFCRColor(performance.fcrRating).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      _getSpeciesIcon(performance.species),
                      color: _getFCRColor(performance.fcrRating),
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          performance.animalName ?? 'Unknown Animal',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (performance.species != null)
                          Text(
                            performance.species!.toLowerCase(),
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: ShowTrackColors.textSecondary,
                            ),
                          ),
                      ],
                    ),
                  ),
                  _buildFCRRatingChip(context),
                ],
              ),
              
              const SizedBox(height: 16),
              
              // Key metrics row
              Row(
                children: [
                  Expanded(
                    child: _buildMetricColumn(
                      context,
                      'FCR',
                      performance.formattedFCR,
                      Icons.trending_up,
                      _getFCRColor(performance.fcrRating),
                    ),
                  ),
                  Expanded(
                    child: _buildMetricColumn(
                      context,
                      'Weight Gain',
                      '${performance.weightGain.toStringAsFixed(1)} lbs',
                      Icons.fitness_center,
                      ShowTrackColors.primary,
                    ),
                  ),
                  Expanded(
                    child: _buildMetricColumn(
                      context,
                      'Feed Used',
                      '${performance.totalFeedConsumed.toStringAsFixed(0)} lbs',
                      Icons.grass,
                      ShowTrackColors.info,
                    ),
                  ),
                ],
              ),
              
              const SizedBox(height: 12),
              
              // Timeline and cost
              Row(
                children: [
                  Icon(
                    Icons.calendar_today,
                    size: 14,
                    color: ShowTrackColors.textSecondary,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    _formatDateRange(),
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: ShowTrackColors.textSecondary,
                    ),
                  ),
                  const Spacer(),
                  if (performance.costPerPoundGain != null) ...[
                    Icon(
                      Icons.attach_money,
                      size: 14,
                      color: ShowTrackColors.success,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      performance.formattedCostPerPound,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: ShowTrackColors.success,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ],
              ),
              
              // Performance indicator bar
              const SizedBox(height: 12),
              _buildPerformanceBar(context),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFCRRatingChip(BuildContext context) {
    final color = _getFCRColor(performance.fcrRating);
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        performance.fcrRating,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
          color: color,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  Widget _buildMetricColumn(
    BuildContext context,
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    return Column(
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(height: 4),
        Text(
          value,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.bold,
            color: color,
          ),
          textAlign: TextAlign.center,
        ),
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: ShowTrackColors.textSecondary,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildPerformanceBar(BuildContext context) {
    final fcrValue = performance.feedConversionRatio ?? 0;
    final normalizedValue = (6 - fcrValue).clamp(0, 6) / 6; // Invert: lower FCR = better
    final color = _getFCRColor(performance.fcrRating);
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Efficiency',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: ShowTrackColors.textSecondary,
              ),
            ),
            Text(
              '${(normalizedValue * 100).toInt()}%',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: color,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        LinearProgressIndicator(
          value: normalizedValue,
          backgroundColor: Colors.grey[200],
          valueColor: AlwaysStoppedAnimation<Color>(color),
          minHeight: 6,
        ),
      ],
    );
  }

  String _formatDateRange() {
    final start = performance.startDate;
    final end = performance.endDate;
    final duration = end.difference(start).inDays;
    
    if (duration <= 7) return '${duration}d period';
    if (duration <= 30) return '${(duration / 7).floor()}w period';
    return '${(duration / 30).floor()}mo period';
  }

  Color _getFCRColor(String rating) {
    switch (rating.toLowerCase()) {
      case 'excellent':
        return ShowTrackColors.success;
      case 'good':
        return ShowTrackColors.primary;
      case 'average':
        return ShowTrackColors.warning;
      case 'needs improvement':
        return ShowTrackColors.error;
      default:
        return ShowTrackColors.textSecondary;
    }
  }

  IconData _getSpeciesIcon(String? species) {
    if (species == null) return Icons.pets;
    
    switch (species.toLowerCase()) {
      case 'cattle':
      case 'cow':
      case 'beef':
      case 'dairy':
        return Icons.agriculture;
      case 'pig':
      case 'swine':
        return Icons.agriculture;
      case 'sheep':
      case 'lamb':
        return Icons.agriculture;
      case 'goat':
        return Icons.agriculture;
      case 'chicken':
      case 'poultry':
        return Icons.agriculture;
      default:
        return Icons.pets;
    }
  }
}