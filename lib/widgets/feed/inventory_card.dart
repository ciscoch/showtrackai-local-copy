import 'package:flutter/material.dart';
import '../../models/feed_inventory.dart';
import '../../theme/mobile_responsive_theme.dart';

/// Card widget for displaying feed inventory information
class InventoryCard extends StatelessWidget {
  final FeedInventory inventory;
  final VoidCallback? onTap;

  const InventoryCard({
    Key? key,
    required this.inventory,
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
              // Header row with name and status
              Row(
                children: [
                  Expanded(
                    child: Text(
                      inventory.displayName,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  _buildStatusChip(context),
                ],
              ),
              
              const SizedBox(height: 12),
              
              // Quantity and location
              Row(
                children: [
                  Icon(
                    Icons.inventory_2,
                    size: 16,
                    color: ShowTrackColors.textSecondary,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    inventory.formattedQuantity,
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: ShowTrackColors.primary,
                    ),
                  ),
                  if (inventory.storageLocation != null) ...[
                    const SizedBox(width: 16),
                    Icon(
                      Icons.location_on,
                      size: 16,
                      color: ShowTrackColors.textSecondary,
                    ),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text(
                        inventory.storageLocation!,
                        style: Theme.of(context).textTheme.bodySmall,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ],
              ),
              
              const SizedBox(height: 8),
              
              // Value and last purchase
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  if (inventory.totalValue != null)
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Value',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: ShowTrackColors.textSecondary,
                          ),
                        ),
                        Text(
                          inventory.formattedValue,
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w500,
                            color: ShowTrackColors.success,
                          ),
                        ),
                      ],
                    ),
                  
                  if (inventory.lastPurchaseDate != null)
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          'Last Purchase',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: ShowTrackColors.textSecondary,
                          ),
                        ),
                        Text(
                          _formatDate(inventory.lastPurchaseDate!),
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                ],
              ),
              
              // Low stock warning
              if (inventory.stockStatus == StockStatus.low)
                Container(
                  margin: const EdgeInsets.only(top: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: ShowTrackColors.warning.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: ShowTrackColors.warning.withOpacity(0.3),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.warning,
                        size: 12,
                        color: ShowTrackColors.warning,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Low Stock',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: ShowTrackColors.warning,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusChip(BuildContext context) {
    Color chipColor;
    String statusText;
    
    switch (inventory.stockStatus) {
      case StockStatus.low:
        chipColor = ShowTrackColors.warning;
        statusText = 'Low';
        break;
      case StockStatus.overstock:
        chipColor = ShowTrackColors.info;
        statusText = 'High';
        break;
      case StockStatus.normal:
        chipColor = ShowTrackColors.success;
        statusText = 'OK';
        break;
    }
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: chipColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        statusText,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
          color: chipColor,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date).inDays;
    
    if (difference == 0) return 'Today';
    if (difference == 1) return 'Yesterday';
    if (difference < 7) return '${difference}d ago';
    if (difference < 30) return '${(difference / 7).floor()}w ago';
    
    return '${date.month}/${date.day}/${date.year}';
  }
}