import 'package:flutter/material.dart';
import '../../models/feed.dart';
import '../../models/feed_inventory.dart';
import '../../models/feed_analytics.dart';
import '../../services/feed_management_service.dart';
import '../../theme/mobile_responsive_theme.dart';
import '../../widgets/feed/custom_brand_dialog.dart';
import '../../widgets/feed/custom_product_dialog.dart';
import '../../widgets/feed/feed_purchase_dialog.dart';
import '../../widgets/feed/inventory_card.dart';
import '../../widgets/feed/fcr_tracking_card.dart';
import '../../widgets/feed/feed_analytics_chart.dart';

/// Main feed management screen with tabs for different features
class FeedManagementScreen extends StatefulWidget {
  const FeedManagementScreen({Key? key}) : super(key: key);

  @override
  State<FeedManagementScreen> createState() => _FeedManagementScreenState();
}

class _FeedManagementScreenState extends State<FeedManagementScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  
  // Data lists
  List<FeedBrand> _customBrands = [];
  List<FeedProduct> _customProducts = [];
  List<FeedInventory> _inventory = [];
  List<FeedInventory> _lowStockItems = [];
  List<FeedConversionTracking> _fcrHistory = [];
  FeedCostAnalytics? _costAnalytics;
  List<FCRPerformance> _fcrPerformance = [];
  
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // Load all data in parallel
      final results = await Future.wait([
        FeedManagementService.getUserCustomBrands(),
        FeedManagementService.getUserCustomProducts(),
        FeedManagementService.getInventory(),
        FeedManagementService.getLowStockItems(),
        FeedManagementService.getCostAnalytics(),
        FeedManagementService.getFCRPerformance(),
      ]);

      setState(() {
        _customBrands = results[0] as List<FeedBrand>;
        _customProducts = results[1] as List<FeedProduct>;
        _inventory = results[2] as List<FeedInventory>;
        _lowStockItems = results[3] as List<FeedInventory>;
        _costAnalytics = results[4] as FeedCostAnalytics;
        _fcrPerformance = results[5] as List<FCRPerformance>;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  void _showAddBrandDialog() {
    showDialog(
      context: context,
      builder: (context) => CustomBrandDialog(
        onSave: (brand) async {
          await _loadData();
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Brand "${brand.name}" created successfully'),
                backgroundColor: Colors.green,
              ),
            );
          }
        },
      ),
    );
  }

  void _showEditBrandDialog(FeedBrand brand) {
    showDialog(
      context: context,
      builder: (context) => CustomBrandDialog(
        brand: brand,
        onSave: (updatedBrand) async {
          await _loadData();
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Brand "${updatedBrand.name}" updated successfully'),
                backgroundColor: Colors.green,
              ),
            );
          }
        },
      ),
    );
  }

  void _showAddProductDialog() {
    showDialog(
      context: context,
      builder: (context) => CustomProductDialog(
        brands: _customBrands,
        onSave: (product) async {
          await _loadData();
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Product "${product.name}" created successfully'),
                backgroundColor: Colors.green,
              ),
            );
          }
        },
      ),
    );
  }

  void _showEditProductDialog(FeedProduct product) {
    showDialog(
      context: context,
      builder: (context) => CustomProductDialog(
        brands: _customBrands,
        product: product,
        onSave: (updatedProduct) async {
          await _loadData();
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Product "${updatedProduct.name}" updated successfully'),
                backgroundColor: Colors.green,
              ),
            );
          }
        },
      ),
    );
  }

  void _showAddPurchaseDialog() {
    showDialog(
      context: context,
      builder: (context) => FeedPurchaseDialog(
        brands: _customBrands,
        products: _customProducts,
        onSave: (purchase) async {
          await _loadData();
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Purchase recorded: ${purchase.formattedCost}'),
                backgroundColor: Colors.green,
              ),
            );
          }
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Feed Management'),
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabs: const [
            Tab(text: 'Brands', icon: Icon(Icons.business)),
            Tab(text: 'Products', icon: Icon(Icons.inventory)),
            Tab(text: 'Inventory', icon: Icon(Icons.warehouse)),
            Tab(text: 'Analytics', icon: Icon(Icons.analytics)),
            Tab(text: 'FCR Tracking', icon: Icon(Icons.trending_up)),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error_outline,
                          size: 64, color: Colors.red),
                      const SizedBox(height: 16),
                      Text('Error: $_errorMessage'),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _loadData,
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                )
              : TabBarView(
                  controller: _tabController,
                  children: [
                    _buildBrandsTab(),
                    _buildProductsTab(),
                    _buildInventoryTab(),
                    _buildAnalyticsTab(),
                    _buildFCRTab(),
                  ],
                ),
      floatingActionButton: _buildFAB(),
    );
  }

  Widget? _buildFAB() {
    switch (_tabController.index) {
      case 0: // Brands
        return FloatingActionButton.extended(
          onPressed: _showAddBrandDialog,
          label: const Text('Add Brand'),
          icon: const Icon(Icons.add),
          tooltip: 'Add a new custom feed brand',
          heroTag: 'add_brand_fab',
        );
      case 1: // Products
        return FloatingActionButton.extended(
          onPressed: _showAddProductDialog,
          label: const Text('Add Product'),
          icon: const Icon(Icons.add),
          tooltip: 'Add a new custom feed product',
          heroTag: 'add_product_fab',
        );
      case 2: // Inventory
        return FloatingActionButton.extended(
          onPressed: _showAddPurchaseDialog,
          label: const Text('Add Purchase'),
          icon: const Icon(Icons.add_shopping_cart),
          tooltip: 'Record a new feed purchase',
          heroTag: 'add_purchase_fab',
        );
      default:
        return null;
    }
  }

  Widget _buildBrandsTab() {
    if (_customBrands.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.business_outlined,
                size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              'No custom brands yet',
              style: TextStyle(fontSize: 18, color: Colors.grey[600]),
            ),
            const SizedBox(height: 8),
            const Text('Add your first custom feed brand'),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _showAddBrandDialog,
              icon: const Icon(Icons.add),
              label: const Text('Add Brand'),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _customBrands.length,
      itemBuilder: (context, index) {
        final brand = _customBrands[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: Theme.of(context).primaryColor.withOpacity(0.1),
              child: Text(
                brand.name.substring(0, 1).toUpperCase(),
                style: TextStyle(
                  color: Theme.of(context).primaryColor,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            title: Text(brand.name),
            subtitle: brand.description != null
                ? Text(
                    brand.description!,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  )
                : null,
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (!brand.isActive)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.orange.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Text(
                      'Inactive',
                      style: TextStyle(
                        color: Colors.orange,
                        fontSize: 12,
                      ),
                    ),
                  ),
                PopupMenuButton<String>(
                  onSelected: (value) async {
                    switch (value) {
                      case 'edit':
                        _showEditBrandDialog(brand);
                        break;
                      case 'delete':
                        final confirm = await showDialog<bool>(
                          context: context,
                          builder: (context) => AlertDialog(
                            title: const Text('Delete Brand'),
                            content: Text(
                              'Are you sure you want to delete "${brand.name}"? '
                              'This will also remove all associated products.',
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(context, false),
                                child: const Text('Cancel'),
                              ),
                              TextButton(
                                onPressed: () => Navigator.pop(context, true),
                                style: TextButton.styleFrom(
                                  foregroundColor: Colors.red,
                                ),
                                child: const Text('Delete'),
                              ),
                            ],
                          ),
                        );
                        if (confirm == true) {
                          await FeedManagementService.deleteCustomBrand(brand.id);
                          await _loadData();
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Brand "${brand.name}" deleted'),
                                backgroundColor: Colors.orange,
                              ),
                            );
                          }
                        }
                        break;
                    }
                  },
                  itemBuilder: (context) => [
                    const PopupMenuItem(
                      value: 'edit',
                      child: ListTile(
                        leading: Icon(Icons.edit),
                        title: Text('Edit'),
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'delete',
                      child: ListTile(
                        leading: Icon(Icons.delete, color: Colors.red),
                        title: Text('Delete', style: TextStyle(color: Colors.red)),
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            onTap: () => _showEditBrandDialog(brand),
          ),
        );
      },
    );
  }

  Widget _buildProductsTab() {
    if (_customProducts.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.inventory_outlined,
                size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              'No custom products yet',
              style: TextStyle(fontSize: 18, color: Colors.grey[600]),
            ),
            const SizedBox(height: 8),
            const Text('Add your first custom feed product'),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _showAddProductDialog,
              icon: const Icon(Icons.add),
              label: const Text('Add Product'),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _customProducts.length,
      itemBuilder: (context, index) {
        final product = _customProducts[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: ExpansionTile(
            leading: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: _getTypeColor(product.type).withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                _getTypeIcon(product.type),
                color: _getTypeColor(product.type),
              ),
            ),
            title: Text(product.displayName),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Type: ${product.type.displayName}'),
                if (product.species.isNotEmpty)
                  Text('Species: ${product.species.join(", ")}'),
              ],
            ),
            trailing: PopupMenuButton<String>(
              onSelected: (value) async {
                switch (value) {
                  case 'edit':
                    _showEditProductDialog(product);
                    break;
                  case 'delete':
                    final confirm = await showDialog<bool>(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: const Text('Delete Product'),
                        content: Text(
                          'Are you sure you want to delete "${product.name}"?',
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context, false),
                            child: const Text('Cancel'),
                          ),
                          TextButton(
                            onPressed: () => Navigator.pop(context, true),
                            style: TextButton.styleFrom(
                              foregroundColor: Colors.red,
                            ),
                            child: const Text('Delete'),
                          ),
                        ],
                      ),
                    );
                    if (confirm == true) {
                      await FeedManagementService.deleteCustomProduct(product.id);
                      await _loadData();
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Product "${product.name}" deleted'),
                            backgroundColor: Colors.orange,
                          ),
                        );
                      }
                    }
                    break;
                }
              },
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'edit',
                  child: ListTile(
                    leading: Icon(Icons.edit),
                    title: Text('Edit'),
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
                const PopupMenuItem(
                  value: 'delete',
                  child: ListTile(
                    leading: Icon(Icons.delete, color: Colors.red),
                    title: Text('Delete', style: TextStyle(color: Colors.red)),
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
              ],
            ),
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (product.description != null) ...[
                      const Text('Description:',
                          style: TextStyle(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 4),
                      Text(product.description!),
                      const SizedBox(height: 12),
                    ],
                    if (product.proteinPercentage != null ||
                        product.fatPercentage != null ||
                        product.fiberPercentage != null) ...[
                      const Text('Nutritional Info:',
                          style: TextStyle(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          if (product.proteinPercentage != null)
                            _buildNutrientChip(
                                'Protein', product.proteinPercentage!),
                          if (product.fatPercentage != null)
                            _buildNutrientChip('Fat', product.fatPercentage!),
                          if (product.fiberPercentage != null)
                            _buildNutrientChip('Fiber', product.fiberPercentage!),
                        ],
                      ),
                      const SizedBox(height: 12),
                    ],
                    if (product.defaultCostPerUnit != null) ...[
                      Row(
                        children: [
                          const Icon(Icons.attach_money,
                              size: 16, color: Colors.green),
                          const SizedBox(width: 4),
                          Text(
                            'Default Cost: \$${product.defaultCostPerUnit!.toStringAsFixed(2)}/${product.defaultUnit ?? "unit"}',
                            style: const TextStyle(color: Colors.green),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildInventoryTab() {
    if (_inventory.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.warehouse_outlined,
                size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              'No inventory tracked yet',
              style: TextStyle(fontSize: 18, color: Colors.grey[600]),
            ),
            const SizedBox(height: 8),
            const Text('Add your first feed purchase to start tracking'),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _showAddPurchaseDialog,
              icon: const Icon(Icons.add_shopping_cart),
              label: const Text('Add Purchase'),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadData,
      child: CustomScrollView(
        slivers: [
          // Low stock warning
          if (_lowStockItems.isNotEmpty)
            SliverToBoxAdapter(
              child: Container(
                margin: ResponsiveUtils.getResponsivePadding(context),
                padding: ResponsiveUtils.getResponsivePadding(context),
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.orange.withOpacity(0.3)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: const [
                        Icon(Icons.warning, color: Colors.orange),
                        SizedBox(width: 8),
                        Text(
                          'Low Stock Alert',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.orange,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${_lowStockItems.length} item(s) are running low',
                      style: TextStyle(color: Colors.grey[700]),
                    ),
                    const SizedBox(height: 8),
                    ...(_lowStockItems.take(3).map((item) => Padding(
                          padding: const EdgeInsets.symmetric(vertical: 2),
                          child: Text(
                            '• ${item.displayName}: ${item.formattedQuantity}',
                            style: TextStyle(color: Colors.grey[700]),
                          ),
                        ))),
                  ],
                ),
              ),
            ),
          
          // Responsive inventory grid
          SliverPadding(
            padding: ResponsiveUtils.getResponsivePadding(context),
            sliver: SliverGrid(
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: ResponsiveUtils.getGridConfig(context)['crossAxisCount'],
                childAspectRatio: ResponsiveUtils.getGridConfig(context)['childAspectRatio'],
                crossAxisSpacing: ResponsiveUtils.getGridConfig(context)['spacing'],
                mainAxisSpacing: ResponsiveUtils.getGridConfig(context)['spacing'],
              ),
              delegate: SliverChildBuilderDelegate(
                (context, index) => InventoryCard(
                  inventory: _inventory[index],
                  onTap: () {
                    _showInventoryDetails(_inventory[index]);
                  },
                ),
                childCount: _inventory.length,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showInventoryDetails(FeedInventory inventory) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        maxChildSize: 0.9,
        minChildSize: 0.5,
        expand: false,
        builder: (context, scrollController) => Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      inventory.displayName,
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              // Add inventory details here
              Text('Current Stock: ${inventory.formattedQuantity}'),
              if (inventory.storageLocation != null)
                Text('Location: ${inventory.storageLocation}'),
              if (inventory.totalValue != null)
                Text('Total Value: ${inventory.formattedValue}'),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAnalyticsTab() {
    if (_costAnalytics == null) {
      return const Center(child: CircularProgressIndicator());
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Cost summary cards
          Row(
            children: [
              Expanded(
                child: _buildSummaryCard(
                  'Total Cost',
                  _costAnalytics!.formattedTotalCost,
                  Icons.attach_money,
                  Colors.green,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildSummaryCard(
                  'Monthly Average',
                  _costAnalytics!.formattedAverageCost,
                  Icons.calendar_month,
                  Colors.blue,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          
          // Cost trend
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Cost Trend',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    height: 200,
                    child: FeedAnalyticsChart(
                      analytics: _costAnalytics!,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          
          // Cost breakdown by brand
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Cost by Brand',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  ..._costAnalytics!.costByBrand.entries.map((entry) {
                    final percentage = (entry.value / _costAnalytics!.totalCost) * 100;
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(entry.key),
                              Text(
                                '\$${entry.value.toStringAsFixed(2)} (${percentage.toStringAsFixed(1)}%)',
                                style: const TextStyle(fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          LinearProgressIndicator(
                            value: percentage / 100,
                            backgroundColor: Colors.grey[200],
                          ),
                        ],
                      ),
                    );
                  }),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFCRTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // FCR summary
          if (_fcrPerformance.isNotEmpty) ...[
            const Text(
              'Feed Conversion Performance',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            ..._fcrPerformance.take(5).map((performance) => Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: FCRTrackingCard(
                    performance: performance,
                    onTap: () {
                      // Show FCR details
                    },
                  ),
                )),
          ] else ...[
            Center(
              child: Column(
                children: [
                  Icon(Icons.trending_up_outlined,
                      size: 64, color: Colors.grey[400]),
                  const SizedBox(height: 16),
                  Text(
                    'No FCR tracking data yet',
                    style: TextStyle(fontSize: 18, color: Colors.grey[600]),
                  ),
                  const SizedBox(height: 8),
                  const Text('Start tracking feed conversion for your animals'),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSummaryCard(
    String title,
    String value,
    IconData icon,
    Color color,
  ) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: color, size: 20),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 14,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              value,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNutrientChip(String label, double value) {
    return Container(
      margin: const EdgeInsets.only(right: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.blue.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(
        '$label: ${value.toStringAsFixed(1)}%',
        style: const TextStyle(
          color: Colors.blue,
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  Color _getTypeColor(FeedType type) {
    switch (type) {
      case FeedType.feed:
        return Colors.green;
      case FeedType.mineral:
        return Colors.blue;
      case FeedType.supplement:
        return Colors.orange;
    }
  }

  IconData _getTypeIcon(FeedType type) {
    switch (type) {
      case FeedType.feed:
        return Icons.grass;
      case FeedType.mineral:
        return Icons.science;
      case FeedType.supplement:
        return Icons.medication;
    }
  }
}