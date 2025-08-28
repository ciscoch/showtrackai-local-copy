import 'package:flutter/material.dart';
import '../../models/feed_analytics.dart';
import '../../theme/mobile_responsive_theme.dart';

/// Chart widget for displaying feed cost analytics with responsive design
class FeedAnalyticsChart extends StatelessWidget {
  final FeedCostAnalytics analytics;
  final bool showLegend;

  const FeedAnalyticsChart({
    Key? key,
    required this.analytics,
    this.showLegend = true,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final isSmall = ResponsiveUtils.isSmallScreen(context);
    
    return Container(
      height: isSmall ? 180 : 200,
      child: Column(
        children: [
          if (showLegend) ...[
            _buildLegend(context),
            const SizedBox(height: 16),
          ],
          
          Expanded(
            child: _buildChart(context),
          ),
        ],
      ),
    );
  }

  Widget _buildLegend(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: [
        _buildLegendItem(
          context,
          'Monthly Cost',
          ShowTrackColors.primary,
        ),
        _buildLegendItem(
          context,
          'Trend',
          ShowTrackColors.warning,
        ),
      ],
    );
  }

  Widget _buildLegendItem(BuildContext context, String label, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: ShowTrackColors.textSecondary,
          ),
        ),
      ],
    );
  }

  Widget _buildChart(BuildContext context) {
    // For this example, we'll create a simple bar chart representation
    // In a real app, you'd use a charting library like fl_chart
    
    final monthlyData = analytics.monthlyTrends;
    if (monthlyData.isEmpty) {
      return _buildEmptyChart(context);
    }
    
    final maxCost = monthlyData
        .map((data) => data['total_cost'] as double? ?? 0.0)
        .reduce((a, b) => a > b ? a : b);
    
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: monthlyData.asMap().entries.map((entry) {
          final index = entry.key;
          final data = entry.value;
          final cost = data['total_cost'] as double? ?? 0.0;
          final month = data['month'] as String? ?? '';
          
          return _buildBar(context, cost, maxCost, month, index);
        }).toList(),
      ),
    );
  }

  Widget _buildBar(BuildContext context, double cost, double maxCost, String month, int index) {
    final height = maxCost > 0 ? (cost / maxCost) * 120 : 0.0;
    final isHighlighted = index == 0; // Highlight current month
    
    return Container(
      width: 40,
      margin: const EdgeInsets.symmetric(horizontal: 2),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          // Cost label
          Text(
            '\$${cost.toStringAsFixed(0)}',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              fontSize: 10,
              fontWeight: FontWeight.w500,
              color: isHighlighted ? ShowTrackColors.primary : ShowTrackColors.textSecondary,
            ),
            textAlign: TextAlign.center,
          ),
          
          const SizedBox(height: 4),
          
          // Bar
          AnimatedContainer(
            duration: const Duration(milliseconds: 800),
            height: height,
            decoration: BoxDecoration(
              color: isHighlighted ? ShowTrackColors.primary : ShowTrackColors.primary.withOpacity(0.7),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
              gradient: isHighlighted 
                  ? LinearGradient(
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                      colors: [
                        ShowTrackColors.primary,
                        ShowTrackColors.primaryLight,
                      ],
                    )
                  : null,
            ),
            child: Container(), // Empty container for the bar
          ),
          
          const SizedBox(height: 4),
          
          // Month label
          Text(
            _formatMonthLabel(month),
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              fontSize: 9,
              color: ShowTrackColors.textSecondary,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyChart(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.insert_chart,
            size: 48,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 8),
          Text(
            'No data available',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Add feed purchases to see trends',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Colors.grey[500],
            ),
          ),
        ],
      ),
    );
  }

  String _formatMonthLabel(String month) {
    try {
      final date = DateTime.parse('$month-01');
      final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
                     'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
      return months[date.month - 1];
    } catch (e) {
      return month.substring(0, 3); // Fallback to first 3 chars
    }
  }
}