import 'package:flutter/material.dart';
import '../models/feed.dart';
import '../models/animal.dart';
import '../services/feed_service.dart';

/// Feed Data Card widget for journal entries
/// 
/// This widget provides:
/// - Display of selected feed items
/// - Add Feed functionality
/// - Use Last functionality for recent feeds
/// - Edit/remove actions on feed items
/// 
class FeedDataCard extends StatefulWidget {
  final List<FeedItem> feedItems;
  final Function(List<FeedItem>) onFeedItemsChanged;
  final Animal? selectedAnimal;
  final bool showTitle;
  final EdgeInsets padding;

  const FeedDataCard({
    super.key,
    required this.feedItems,
    required this.onFeedItemsChanged,
    this.selectedAnimal,
    this.showTitle = true,
    this.padding = const EdgeInsets.all(16),
  });

  @override
  State<FeedDataCard> createState() => _FeedDataCardState();
}

class _FeedDataCardState extends State<FeedDataCard> {
  bool _isLoadingRecentFeeds = false;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: widget.padding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (widget.showTitle) ...[
              _buildHeader(),
              const SizedBox(height: 12),
            ],
            _buildContent(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        const Icon(Icons.restaurant, color: Colors.green),
        const SizedBox(width: 8),
        const Text(
          'Feed Data',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const Spacer(),
        _buildActionButtons(),
      ],
    );
  }

  Widget _buildActionButtons() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        OutlinedButton.icon(
          onPressed: _isLoadingRecentFeeds ? null : _useLastFeeds,
          icon: _isLoadingRecentFeeds
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.history, size: 16),
          label: const Text('Use Last'),
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            minimumSize: const Size(80, 32),
          ),
        ),
        const SizedBox(width: 8),
        ElevatedButton.icon(
          onPressed: _addFeed,
          icon: const Icon(Icons.add, size: 16),
          label: const Text('Add Feed'),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.green,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            minimumSize: const Size(80, 32),
          ),
        ),
      ],
    );
  }

  Widget _buildContent() {
    if (widget.feedItems.isEmpty) {
      return _buildEmptyState();
    }
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ...widget.feedItems.asMap().entries.map((entry) {
          final index = entry.key;
          final feedItem = entry.value;
          return _buildFeedTile(feedItem, index);
        }),
        const SizedBox(height: 8),
        _buildSummaryRow(),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 32),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        children: [
          Icon(
            Icons.restaurant_outlined,
            size: 48,
            color: Colors.grey.shade400,
          ),
          const SizedBox(height: 12),
          Text(
            'No feeds selected',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey.shade600,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Add feed items to track feeding activities',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeedTile(FeedItem feedItem, int index) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.green.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.green.shade200),
      ),
      child: Row(
        children: [
          Icon(
            feedItem.isHay ? Icons.grass : Icons.grain,
            color: Colors.green.shade700,
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _formatFeedDisplay(feedItem),
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: Colors.green.shade700,
                    fontSize: 15,
                  ),
                ),
                if (feedItem.note != null && feedItem.note!.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    feedItem.note!,
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.green.shade600,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
              ],
            ),
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                onPressed: () => _editFeed(index),
                icon: const Icon(Icons.edit, size: 18),
                color: Colors.grey.shade600,
                tooltip: 'Edit feed',
                constraints: const BoxConstraints(
                  minWidth: 32,
                  minHeight: 32,
                ),
                padding: const EdgeInsets.all(4),
              ),
              IconButton(
                onPressed: () => _removeFeed(index),
                icon: const Icon(Icons.close, size: 18),
                color: Colors.red.shade600,
                tooltip: 'Remove feed',
                constraints: const BoxConstraints(
                  minWidth: 32,
                  minHeight: 32,
                ),
                padding: const EdgeInsets.all(4),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryRow() {
    final totalItems = widget.feedItems.length;
    final hayCount = widget.feedItems.where((item) => item.isHay).length;
    final feedCount = totalItems - hayCount;
    
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: Colors.blue.shade200),
      ),
      child: Row(
        children: [
          Icon(Icons.summarize, size: 16, color: Colors.blue.shade700),
          const SizedBox(width: 8),
          Text(
            'Total: $totalItems items',
            style: TextStyle(
              fontWeight: FontWeight.w500,
              color: Colors.blue.shade700,
            ),
          ),
          if (hayCount > 0 || feedCount > 0) ...[
            Text(
              ' (${feedCount > 0 ? '$feedCount feed${feedCount != 1 ? 's' : ''}' : ''}${hayCount > 0 && feedCount > 0 ? ', ' : ''}${hayCount > 0 ? '$hayCount hay' : ''})',
              style: TextStyle(
                color: Colors.blue.shade600,
                fontSize: 13,
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _formatFeedDisplay(FeedItem feedItem) {
    if (feedItem.isHay) {
      return 'Hay · ${feedItem.formattedQuantity}';
    }
    
    // Format: "Brand — Product · {qty} lbs"
    final brandName = feedItem.brand?.name ?? 'Unknown Brand';
    final productName = feedItem.product?.name ?? 'Unknown Product';
    
    return '$brandName — $productName · ${feedItem.formattedQuantity}';
  }

  void _addFeed() {
    _showAddFeedModal();
  }

  void _editFeed(int index) {
    _showAddFeedModal(existingFeedItem: widget.feedItems[index], editIndex: index);
  }

  void _removeFeed(int index) {
    final updatedList = List<FeedItem>.from(widget.feedItems);
    updatedList.removeAt(index);
    widget.onFeedItemsChanged(updatedList);
  }

  Future<void> _useLastFeeds() async {
    setState(() => _isLoadingRecentFeeds = true);

    try {
      final recentFeeds = await FeedService.getUserRecentFeed(limit: 5);
      
      if (!mounted) return;

      if (recentFeeds.isEmpty) {
        _showMessage('No recent feeds found. Add some feeds first!');
        return;
      }

      // Show dialog to select recent feeds
      final selectedFeeds = await _showRecentFeedsDialog(recentFeeds);
      
      if (selectedFeeds != null && selectedFeeds.isNotEmpty) {
        // Convert recent feeds to feed items and add to current list
        final updatedList = List<FeedItem>.from(widget.feedItems);
        
        for (final recent in selectedFeeds) {
          final feedItem = recent.toFeedItem(
            entryId: '', // Will be set when saving journal entry
            note: null,
          );
          updatedList.add(feedItem);
        }
        
        widget.onFeedItemsChanged(updatedList);
        _showMessage('Added ${selectedFeeds.length} feed(s) from recent usage');
      }

    } catch (e) {
      if (mounted) {
        _showMessage('Failed to load recent feeds: ${e.toString()}');
      }
    } finally {
      if (mounted) {
        setState(() => _isLoadingRecentFeeds = false);
      }
    }
  }

  Future<void> _showAddFeedModal({FeedItem? existingFeedItem, int? editIndex}) async {
    final result = await showDialog<FeedItem>(
      context: context,
      builder: (context) => AddFeedModal(
        selectedAnimal: widget.selectedAnimal,
        existingFeedItem: existingFeedItem,
      ),
    );

    if (result != null) {
      final updatedList = List<FeedItem>.from(widget.feedItems);
      
      if (editIndex != null) {
        // Edit existing item
        updatedList[editIndex] = result;
      } else {
        // Add new item
        updatedList.add(result);
      }
      
      widget.onFeedItemsChanged(updatedList);
    }
  }

  Future<List<UserFeedRecent>?> _showRecentFeedsDialog(List<UserFeedRecent> recentFeeds) async {
    return await showDialog<List<UserFeedRecent>>(
      context: context,
      builder: (context) => _RecentFeedsDialog(recentFeeds: recentFeeds),
    );
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}

/// Recent Feeds Selection Dialog
class _RecentFeedsDialog extends StatefulWidget {
  final List<UserFeedRecent> recentFeeds;

  const _RecentFeedsDialog({required this.recentFeeds});

  @override
  State<_RecentFeedsDialog> createState() => _RecentFeedsDialogState();
}

class _RecentFeedsDialogState extends State<_RecentFeedsDialog> {
  final Set<UserFeedRecent> _selectedFeeds = {};

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Select Recent Feeds'),
      content: SizedBox(
        width: double.maxFinite,
        child: ListView.builder(
          shrinkWrap: true,
          itemCount: widget.recentFeeds.length,
          itemBuilder: (context, index) {
            final recentFeed = widget.recentFeeds[index];
            final isSelected = _selectedFeeds.contains(recentFeed);
            
            return CheckboxListTile(
              value: isSelected,
              onChanged: (selected) {
                setState(() {
                  if (selected == true) {
                    _selectedFeeds.add(recentFeed);
                  } else {
                    _selectedFeeds.remove(recentFeed);
                  }
                });
              },
              title: Text(_formatRecentFeedDisplay(recentFeed)),
              subtitle: Text(
                'Last used: ${_formatDate(recentFeed.lastUsedAt)}',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade600,
                ),
              ),
              secondary: Icon(
                recentFeed.isHay ? Icons.grass : Icons.grain,
                color: Colors.green,
              ),
            );
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(null),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _selectedFeeds.isEmpty
              ? null
              : () => Navigator.of(context).pop(_selectedFeeds.toList()),
          child: Text('Add ${_selectedFeeds.length} Feed${_selectedFeeds.length != 1 ? 's' : ''}'),
        ),
      ],
    );
  }

  String _formatRecentFeedDisplay(UserFeedRecent recentFeed) {
    if (recentFeed.isHay) {
      return 'Hay · ${recentFeed.formattedQuantity}';
    }
    
    final brandName = recentFeed.brand?.name ?? 'Unknown Brand';
    final productName = recentFeed.product?.name ?? 'Unknown Product';
    
    return '$brandName — $productName · ${recentFeed.formattedQuantity}';
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);
    
    if (diff.inDays == 0) {
      return 'Today';
    } else if (diff.inDays == 1) {
      return 'Yesterday';
    } else if (diff.inDays < 7) {
      return '${diff.inDays} days ago';
    } else {
      return '${date.month}/${date.day}/${date.year}';
    }
  }
}

/// Add Feed Modal Dialog
class AddFeedModal extends StatefulWidget {
  final Animal? selectedAnimal;
  final FeedItem? existingFeedItem;

  const AddFeedModal({
    super.key,
    this.selectedAnimal,
    this.existingFeedItem,
  });

  @override
  State<AddFeedModal> createState() => _AddFeedModalState();
}

class _AddFeedModalState extends State<AddFeedModal> {
  final _formKey = GlobalKey<FormState>();
  final _quantityController = TextEditingController();
  final _noteController = TextEditingController();

  bool _isHay = false;
  FeedBrand? _selectedBrand;
  FeedProduct? _selectedProduct;
  FeedUnit _selectedUnit = FeedUnit.lbs;

  List<FeedBrand> _brands = [];
  List<FeedProduct> _products = [];
  
  bool _isLoadingBrands = false;
  bool _isLoadingProducts = false;
  bool _isSearchingProducts = false;
  
  final _brandSearchController = TextEditingController();
  final _productSearchController = TextEditingController();
  
  List<FeedBrand> _filteredBrands = [];
  List<FeedProduct> _filteredProducts = [];

  @override
  void initState() {
    super.initState();
    _initializeForm();
    _loadBrands();
  }

  @override
  void dispose() {
    _quantityController.dispose();
    _noteController.dispose();
    _brandSearchController.dispose();
    _productSearchController.dispose();
    super.dispose();
  }

  void _initializeForm() {
    if (widget.existingFeedItem != null) {
      final existing = widget.existingFeedItem!;
      _isHay = existing.isHay;
      _quantityController.text = existing.quantity.toString();
      _selectedUnit = existing.unit;
      _noteController.text = existing.note ?? '';
      
      if (!_isHay) {
        // Will load brand/product from existing data after brands load
      }
    }
  }

  Future<void> _loadBrands() async {
    setState(() => _isLoadingBrands = true);
    
    try {
      final brands = await FeedService.getBrands();
      setState(() {
        _brands = brands;
        _filteredBrands = brands;
        _isLoadingBrands = false;
      });
      
      // If editing, find and set the existing brand
      if (widget.existingFeedItem != null && !_isHay) {
        final existingBrandId = widget.existingFeedItem!.brandId;
        if (existingBrandId != null) {
          final brand = _brands.firstWhere(
            (b) => b.id == existingBrandId,
            orElse: () => _brands.first,
          );
          _selectedBrand = brand;
          _brandSearchController.text = brand.name;
          await _loadProducts(brand.id);
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingBrands = false);
        _showError('Failed to load brands: ${e.toString()}');
      }
    }
  }

  Future<void> _loadProducts(String brandId) async {
    setState(() => _isLoadingProducts = true);
    
    try {
      final products = await FeedService.getProducts(
        brandId,
        species: widget.selectedAnimal?.species,
      );
      setState(() {
        _products = products;
        _filteredProducts = products;
        _isLoadingProducts = false;
      });
      
      // If editing, find and set the existing product
      if (widget.existingFeedItem != null) {
        final existingProductId = widget.existingFeedItem!.productId;
        if (existingProductId != null) {
          final product = _products.firstWhere(
            (p) => p.id == existingProductId,
            orElse: () => _products.isNotEmpty ? _products.first : _products.first,
          );
          if (_products.isNotEmpty) {
            _selectedProduct = product;
            _productSearchController.text = product.name;
          }
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingProducts = false);
        _showError('Failed to load products: ${e.toString()}');
      }
    }
  }

  void _filterBrands(String query) {
    setState(() {
      if (query.isEmpty) {
        _filteredBrands = _brands;
      } else {
        _filteredBrands = _brands
            .where((brand) => brand.name.toLowerCase().contains(query.toLowerCase()))
            .toList();
      }
    });
  }

  void _filterProducts(String query) {
    setState(() {
      if (query.isEmpty) {
        _filteredProducts = _products;
      } else {
        _filteredProducts = _products
            .where((product) => product.name.toLowerCase().contains(query.toLowerCase()))
            .toList();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 500, maxHeight: 600),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildHeader(),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: _buildForm(),
              ),
            ),
            _buildActions(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.green.shade50,
        border: Border(bottom: BorderSide(color: Colors.green.shade200)),
      ),
      child: Row(
        children: [
          Icon(Icons.restaurant, color: Colors.green.shade700),
          const SizedBox(width: 8),
          Text(
            widget.existingFeedItem != null ? 'Edit Feed' : 'Add Feed',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.green.shade700,
            ),
          ),
          const Spacer(),
          IconButton(
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.close),
            color: Colors.grey.shade600,
          ),
        ],
      ),
    );
  }

  Widget _buildForm() {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHayToggle(),
          const SizedBox(height: 16),
          if (!_isHay) ...[
            _buildBrandDropdown(),
            const SizedBox(height: 16),
            _buildProductDropdown(),
            const SizedBox(height: 16),
          ],
          _buildQuantityField(),
          const SizedBox(height: 16),
          _buildNoteField(),
        ],
      ),
    );
  }

  Widget _buildHayToggle() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _isHay ? Colors.orange.shade50 : Colors.blue.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: _isHay ? Colors.orange.shade200 : Colors.blue.shade200,
        ),
      ),
      child: Row(
        children: [
          Checkbox(
            value: _isHay,
            onChanged: (value) {
              setState(() {
                _isHay = value ?? false;
                if (_isHay) {
                  _selectedUnit = FeedUnit.flakes;
                  _selectedBrand = null;
                  _selectedProduct = null;
                  _brandSearchController.clear();
                  _productSearchController.clear();
                } else {
                  _selectedUnit = FeedUnit.lbs;
                }
              });
            },
            activeColor: Colors.orange,
          ),
          const SizedBox(width: 8),
          Icon(
            _isHay ? Icons.grass : Icons.grain,
            color: _isHay ? Colors.orange.shade700 : Colors.blue.shade700,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Is Hay?',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: _isHay ? Colors.orange.shade700 : Colors.blue.shade700,
                  ),
                ),
                Text(
                  _isHay
                      ? 'Quantity will be in flakes'
                      : 'Select brand and product below',
                  style: TextStyle(
                    fontSize: 12,
                    color: _isHay ? Colors.orange.shade600 : Colors.blue.shade600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBrandDropdown() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Brand *',
          style: const TextStyle(fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: _brandSearchController,
          decoration: InputDecoration(
            hintText: 'Search brands...',
            prefixIcon: const Icon(Icons.search),
            suffixIcon: _isLoadingBrands
                ? const Padding(
                    padding: EdgeInsets.all(12),
                    child: SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  )
                : _brandSearchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _brandSearchController.clear();
                          _filterBrands('');
                          _selectedBrand = null;
                        },
                      )
                    : null,
            border: const OutlineInputBorder(),
          ),
          onChanged: _filterBrands,
          validator: (value) {
            if (_selectedBrand == null) {
              return 'Please select a brand';
            }
            return null;
          },
        ),
        if (_filteredBrands.isNotEmpty && _brandSearchController.text.isNotEmpty) ...[
          const SizedBox(height: 4),
          Container(
            constraints: const BoxConstraints(maxHeight: 120),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey.shade300),
              borderRadius: BorderRadius.circular(4),
            ),
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: _filteredBrands.length,
              itemBuilder: (context, index) {
                final brand = _filteredBrands[index];
                return ListTile(
                  title: Text(brand.name),
                  dense: true,
                  onTap: () {
                    setState(() {
                      _selectedBrand = brand;
                      _brandSearchController.text = brand.name;
                      _selectedProduct = null;
                      _productSearchController.clear();
                      _filteredBrands = [];
                    });
                    _loadProducts(brand.id);
                  },
                );
              },
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildProductDropdown() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Product *',
          style: const TextStyle(fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: _productSearchController,
          decoration: InputDecoration(
            hintText: _selectedBrand != null
                ? 'Search products...'
                : 'Select a brand first',
            prefixIcon: const Icon(Icons.inventory),
            suffixIcon: _isLoadingProducts
                ? const Padding(
                    padding: EdgeInsets.all(12),
                    child: SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  )
                : _productSearchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _productSearchController.clear();
                          _filterProducts('');
                          _selectedProduct = null;
                        },
                      )
                    : null,
            border: const OutlineInputBorder(),
          ),
          enabled: _selectedBrand != null && !_isLoadingProducts,
          onChanged: _filterProducts,
          validator: (value) {
            if (_selectedProduct == null) {
              return 'Please select a product';
            }
            return null;
          },
        ),
        if (_filteredProducts.isNotEmpty && _productSearchController.text.isNotEmpty) ...[
          const SizedBox(height: 4),
          Container(
            constraints: const BoxConstraints(maxHeight: 120),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey.shade300),
              borderRadius: BorderRadius.circular(4),
            ),
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: _filteredProducts.length,
              itemBuilder: (context, index) {
                final product = _filteredProducts[index];
                return ListTile(
                  title: Text(product.name),
                  subtitle: Text('Type: ${product.type.displayName}'),
                  dense: true,
                  onTap: () {
                    setState(() {
                      _selectedProduct = product;
                      _productSearchController.text = product.name;
                      _filteredProducts = [];
                    });
                  },
                );
              },
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildQuantityField() {
    return Row(
      children: [
        Expanded(
          flex: 2,
          child: TextFormField(
            controller: _quantityController,
            decoration: InputDecoration(
              labelText: 'Quantity *',
              hintText: 'Enter amount',
              prefixIcon: const Icon(Icons.scale),
              border: const OutlineInputBorder(),
            ),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Quantity is required';
              }
              final quantity = double.tryParse(value);
              if (quantity == null || quantity <= 0) {
                return 'Enter a valid quantity';
              }
              return null;
            },
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: DropdownButtonFormField<FeedUnit>(
            value: _selectedUnit,
            decoration: const InputDecoration(
              labelText: 'Unit',
              border: OutlineInputBorder(),
            ),
            items: (_isHay ? [FeedUnit.flakes] : [FeedUnit.lbs, FeedUnit.bags, FeedUnit.scoops])
                .map((unit) => DropdownMenuItem(
                      value: unit,
                      child: Text(unit.displayName),
                    ))
                .toList(),
            onChanged: (value) {
              if (value != null) {
                setState(() {
                  _selectedUnit = value;
                });
              }
            },
          ),
        ),
      ],
    );
  }

  Widget _buildNoteField() {
    return TextFormField(
      controller: _noteController,
      decoration: const InputDecoration(
        labelText: 'Note (Optional)',
        hintText: 'Add any additional notes...',
        prefixIcon: Icon(Icons.note_add),
        border: OutlineInputBorder(),
      ),
      maxLines: 2,
    );
  }

  Widget _buildActions() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        border: Border(top: BorderSide(color: Colors.grey.shade200)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          const SizedBox(width: 12),
          ElevatedButton(
            onPressed: _saveFeed,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
            ),
            child: Text(widget.existingFeedItem != null ? 'Update Feed' : 'Add Feed'),
          ),
        ],
      ),
    );
  }

  void _saveFeed() {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final quantity = double.parse(_quantityController.text);
    final note = _noteController.text.trim();

    final feedItem = FeedItem.create(
      entryId: widget.existingFeedItem?.entryId ?? '',
      userId: widget.existingFeedItem?.userId ?? '',
      brandId: _isHay ? null : _selectedBrand?.id,
      productId: _isHay ? null : _selectedProduct?.id,
      isHay: _isHay,
      quantity: quantity,
      unit: _selectedUnit,
      note: note.isEmpty ? null : note,
    ).copyWith(
      // Preserve existing ID if editing
      id: widget.existingFeedItem?.id,
      // Set related objects for display
      brand: _selectedBrand,
      product: _selectedProduct,
    );

    Navigator.of(context).pop(feedItem);
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }
}