import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../models/timeline_item.dart';
import '../models/expense.dart';
import '../models/journal_entry.dart';
import '../theme/mobile_responsive_theme.dart';

/// Enhanced card widget for displaying timeline items with mobile optimizations
class TimelineItemCard extends StatefulWidget {
  final TimelineItem item;
  final VoidCallback? onTap;
  final bool showFullMetadata;
  final EdgeInsets? margin;

  const TimelineItemCard({
    super.key,
    required this.item,
    this.onTap,
    this.showFullMetadata = true,
    this.margin,
  });
  
  @override
  State<TimelineItemCard> createState() => _TimelineItemCardState();
}

class _TimelineItemCardState extends State<TimelineItemCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  bool _isPressed = false;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 150),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: 0.95,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));
  }
  
  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isSmallScreen = ResponsiveUtils.isSmallScreen(context);
    final cardMargin = widget.margin ?? EdgeInsets.symmetric(
      horizontal: isSmallScreen ? 12 : 16,
      vertical: 4,
    );
    
    return AnimatedBuilder(
      animation: _scaleAnimation,
      builder: (context, child) {
        return Transform.scale(
          scale: _scaleAnimation.value,
          child: Container(
            margin: cardMargin,
            child: Material(
              color: ShowTrackColors.surface,
              borderRadius: BorderRadius.circular(16),
              elevation: _isPressed ? 8 : 2,
              shadowColor: widget.item.color.withOpacity(0.2),
              child: InkWell(
                onTap: widget.onTap,
                onTapDown: _onTapDown,
                onTapUp: _onTapUp,
                onTapCancel: _onTapCancel,
                borderRadius: BorderRadius.circular(16),
                splashColor: widget.item.color.withOpacity(0.1),
                highlightColor: widget.item.color.withOpacity(0.05),
                child: Container(
                  padding: EdgeInsets.all(isSmallScreen ? 12 : 16),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: widget.item.color.withOpacity(0.1),
                      width: 1,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildHeader(context, isSmallScreen),
                      const SizedBox(height: 12),
                      _buildContent(context, isSmallScreen),
                      if (widget.showFullMetadata) ...[
                        const SizedBox(height: 12),
                        _buildMetadata(context, isSmallScreen),
                      ],
                      if (widget.item.tags != null && widget.item.tags!.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        _buildTags(context, isSmallScreen),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
  
  void _onTapDown(TapDownDetails details) {
    setState(() => _isPressed = true);
    _animationController.forward();
    HapticFeedback.lightImpact();
  }
  
  void _onTapUp(TapUpDetails details) {
    setState(() => _isPressed = false);
    _animationController.reverse();
  }
  
  void _onTapCancel() {
    setState(() => _isPressed = false);
    _animationController.reverse();
  }
  
  Widget _buildHeader(BuildContext context, bool isSmallScreen) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Enhanced timeline indicator
        Container(
          width: isSmallScreen ? 44 : 48,
          height: isSmallScreen ? 44 : 48,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                widget.item.color.withOpacity(0.8),
                widget.item.color,
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                color: widget.item.color.withOpacity(0.3),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Icon(
            widget.item.icon,
            color: Colors.white,
            size: isSmallScreen ? 20 : 24,
          ),
        ),
        const SizedBox(width: 12),
        
        // Content area
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Title and amount
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      widget.item.title,
                      style: TextStyle(
                        fontSize: ResponsiveUtils.getResponsiveFontSize(
                          context,
                          baseSize: isSmallScreen ? 14 : 16,
                        ),
                        fontWeight: FontWeight.bold,
                        color: ShowTrackColors.textPrimary,
                        height: 1.2,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (widget.item.amount != null) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: isSmallScreen ? 6 : 8,
                        vertical: isSmallScreen ? 3 : 4,
                      ),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: widget.item.type == TimelineItemType.expense
                              ? [Colors.red.withOpacity(0.1), Colors.red.withOpacity(0.2)]
                              : [Colors.green.withOpacity(0.1), Colors.green.withOpacity(0.2)],
                        ),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: widget.item.type == TimelineItemType.expense
                              ? Colors.red.withOpacity(0.3)
                              : Colors.green.withOpacity(0.3),
                          width: 1,
                        ),
                      ),
                      child: Text(
                        widget.item.formattedAmount,
                        style: TextStyle(
                          fontSize: ResponsiveUtils.getResponsiveFontSize(
                            context,
                            baseSize: isSmallScreen ? 12 : 14,
                          ),
                          fontWeight: FontWeight.bold,
                          color: widget.item.type == TimelineItemType.expense
                              ? Colors.red[700]
                              : Colors.green[700],
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              
              // Time and status indicators
              const SizedBox(height: 6),
              Row(
                children: [
                  Icon(
                    Icons.schedule,
                    size: isSmallScreen ? 12 : 14,
                    color: ShowTrackColors.textSecondary,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    DateFormat('h:mm a').format(widget.item.date),
                    style: TextStyle(
                      fontSize: ResponsiveUtils.getResponsiveFontSize(
                        context,
                        baseSize: 11,
                      ),
                      color: ShowTrackColors.textSecondary,
                    ),
                  ),
                  if (widget.item.animalName != null) ...[
                    const SizedBox(width: 12),
                    Icon(
                      Icons.pets,
                      size: isSmallScreen ? 12 : 14,
                      color: ShowTrackColors.primary,
                    ),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text(
                        widget.item.animalName!,
                        style: TextStyle(
                          fontSize: ResponsiveUtils.getResponsiveFontSize(
                            context,
                            baseSize: 11,
                          ),
                          color: ShowTrackColors.primary,
                          fontWeight: FontWeight.w500,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                  const Spacer(),
                  // Status indicators
                  if (widget.item.type == TimelineItemType.expense &&
                      widget.item.expense?.isPaid == false)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: ShowTrackColors.warning.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: ShowTrackColors.warning.withOpacity(0.3),
                          width: 1,
                        ),
                      ),
                      child: Text(
                        'Unpaid',
                        style: TextStyle(
                          fontSize: 9,
                          color: ShowTrackColors.warning,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                ],
              ),
              
              // Subtitle section
              if (widget.item.subtitle.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(
                  widget.item.subtitle,
                  style: TextStyle(
                    fontSize: ResponsiveUtils.getResponsiveFontSize(
                      context,
                      baseSize: 12,
                    ),
                    color: ShowTrackColors.textSecondary,
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ],
          ),
        ),
        // Arrow indicator
        Icon(
          Icons.chevron_right,
          color: ShowTrackColors.textHint,
          size: isSmallScreen ? 20 : 24,
        ),
      ],
    );
  }
  
  Widget _buildContent(BuildContext context, bool isSmallScreen) {
    return Text(
      widget.item.description,
      maxLines: isSmallScreen ? 2 : 3,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(
        fontSize: ResponsiveUtils.getResponsiveFontSize(
          context,
          baseSize: 14,
        ),
        height: 1.4,
        color: ShowTrackColors.textPrimary,
      ),
    );
  }
  
  Widget _buildMetadata(BuildContext context, bool isSmallScreen) {
    final metadataChips = _getMetadataChips(context, isSmallScreen);
    
    if (metadataChips.isEmpty) return const SizedBox.shrink();
    
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: metadataChips,
    );
  }
  
  List<Widget> _getMetadataChips(BuildContext context, bool isSmallScreen) {
    final chips = <Widget>[];
    
    // Category chip
    if (widget.item.category != null) {
      chips.add(_buildChip(
        context,
        Icons.category_outlined,
        _getCategoryDisplayName(widget.item.category!),
        ShowTrackColors.info,
        isSmallScreen,
      ));
    }
    
    // Location indicator
    if (widget.item.hasLocation) {
      chips.add(_buildChip(
        context,
        Icons.location_on,
        'Location',
        ShowTrackColors.success,
        isSmallScreen,
      ));
    }
    
    // Weather indicator
    if (widget.item.hasWeather) {
      chips.add(_buildChip(
        context,
        Icons.cloud,
        'Weather',
        ShowTrackColors.warning,
        isSmallScreen,
      ));
    }
    
    // AI insights indicator
    if (widget.item.hasAiInsights) {
      chips.add(_buildChip(
        context,
        Icons.auto_awesome,
        'AI Analysis',
        Colors.deepPurple,
        isSmallScreen,
      ));
    }
    
    // Expense-specific metadata
    if (widget.item.type == TimelineItemType.expense) {
      // Vendor name
      final vendor = widget.item.metadata?['vendorName'];
      if (vendor != null) {
        chips.add(_buildChip(
          context,
          Icons.store,
          vendor,
          Colors.teal,
          isSmallScreen,
        ));
      }
      
      // Receipt indicator
      if (widget.item.metadata?['hasReceipt'] == true) {
        chips.add(_buildChip(
          context,
          Icons.receipt,
          'Receipt',
          Colors.cyan,
          isSmallScreen,
        ));
      }
    }
    
    // Journal-specific metadata
    if (widget.item.type == TimelineItemType.journal) {
      // Duration
      final duration = widget.item.metadata?['duration'];
      if (duration != null) {
        chips.add(_buildChip(
          context,
          Icons.timer,
          '${duration} min',
          Colors.deepOrange,
          isSmallScreen,
        ));
      }
      
      // Quality score
      final score = widget.item.metadata?['qualityScore'];
      if (score != null) {
        chips.add(_buildChip(
          context,
          Icons.star,
          '${score}%',
          Colors.amber,
          isSmallScreen,
        ));
      }
    }
    
    return chips.take(isSmallScreen ? 3 : 5).toList();
  }
  
  Widget _buildTags(BuildContext context, bool isSmallScreen) {
    return Wrap(
      spacing: 4,
      runSpacing: 4,
      children: widget.item.tags!
          .take(isSmallScreen ? 2 : 3)
          .map((tag) => Container(
                padding: EdgeInsets.symmetric(
                  horizontal: isSmallScreen ? 6 : 8,
                  vertical: 2,
                ),
                decoration: BoxDecoration(
                  color: ShowTrackColors.textHint.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: ShowTrackColors.textHint.withOpacity(0.3),
                  ),
                ),
                child: Text(
                  '#$tag',
                  style: TextStyle(
                    fontSize: ResponsiveUtils.getResponsiveFontSize(
                      context,
                      baseSize: 10,
                    ),
                    color: ShowTrackColors.textSecondary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ))
          .toList(),
    );
  }

  Widget _buildChip(
    BuildContext context,
    IconData icon,
    String label,
    Color color,
    bool isSmallScreen,
  ) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isSmallScreen ? 6 : 8,
        vertical: isSmallScreen ? 3 : 4,
      ),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            color.withOpacity(0.1),
            color.withOpacity(0.15),
          ],
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: color.withOpacity(0.3),
          width: 0.5,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: isSmallScreen ? 10 : 12,
            color: color,
          ),
          const SizedBox(width: 3),
          Text(
            label,
            style: TextStyle(
              fontSize: ResponsiveUtils.getResponsiveFontSize(
                context,
                baseSize: isSmallScreen ? 9 : 10,
              ),
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  String _getCategoryDisplayName(String category) {
    // Try expense category first
    if (ExpenseCategories.categoryDisplayNames.containsKey(category)) {
      return ExpenseCategories.getDisplayName(category);
    }
    
    // Try journal category
    if (JournalCategories.categoryDisplayNames.containsKey(category)) {
      return JournalCategories.getDisplayName(category);
    }
    
    // Fallback to raw category
    return category;
  }
}