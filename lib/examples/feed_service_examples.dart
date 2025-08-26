import 'package:flutter/material.dart';
import '../models/feed.dart';
import '../services/feed_service.dart';

/// Comprehensive examples demonstrating FeedService usage patterns
/// 
/// This file contains practical examples showing how to use the FeedService
/// for common livestock feed management tasks in agricultural education apps.

/// Example 1: Basic Feed Selection UI
/// 
/// Shows how to load brands and products for user selection
class FeedSelectionExample {
  static Future<void> demonstrateFeedSelection() async {
    print('=== Feed Selection Example ===');
    
    try {
      // Load all available brands
      final brands = await FeedService.getBrands();
      print('Available brands: ${brands.map((b) => b.name).join(', ')}');
      
      if (brands.isNotEmpty) {
        // Get products for the first brand
        final selectedBrand = brands.first;
        final products = await FeedService.getProducts(selectedBrand.id);
        
        print('\nProducts for ${selectedBrand.name}:');
        for (final product in products) {
          print('  - ${product.name} (${product.type}) - Species: ${product.species.join(', ')}');
        }
        
        // Filter products for cattle only
        final cattleProducts = await FeedService.getProducts(
          selectedBrand.id,
          species: 'cattle'
        );
        
        print('\nCattle products for ${selectedBrand.name}: ${cattleProducts.length} items');
      }
      
    } catch (e) {
      print('Error in feed selection: $e');
    }
  }
}

/// Example 2: Journal Entry Feed Recording
/// 
/// Shows how to save feed items when creating journal entries
class JournalFeedRecordingExample {
  static Future<void> demonstrateFeedRecording(String journalEntryId) async {
    print('=== Journal Feed Recording Example ===');
    
    try {
      // Get brands and select one
      final brands = await FeedService.getBrands();
      final purinaBrand = brands.firstWhere(
        (brand) => brand.name.toLowerCase().contains('purina'),
        orElse: () => brands.first,
      );
      
      // Get products for the selected brand
      final products = await FeedService.getProducts(purinaBrand.id);
      final selectedProduct = products.first;
      
      // Create and save a feed item
      final feedItem = FeedItem.create(
        entryId: journalEntryId,
        userId: 'current-user-id', // This would come from auth
        brandId: purinaBrand.id,
        productId: selectedProduct.id,
        quantity: 5.5,
        unit: FeedUnit.lbs,
        note: 'Morning feeding - animal showed good appetite',
      );
      
      final savedItem = await FeedService.saveFeedItem(feedItem);
      print('Saved feed item: ${savedItem.displayName} - ${savedItem.formattedQuantity}');
      
      // Also save a hay item
      final hayItem = FeedItem.create(
        entryId: journalEntryId,
        userId: 'current-user-id',
        isHay: true,
        quantity: 3.0,
        unit: FeedUnit.flakes,
        note: 'Good quality hay',
      );
      
      final savedHay = await FeedService.saveFeedItem(hayItem);
      print('Saved hay item: ${savedHay.displayName} - ${savedHay.formattedQuantity}');
      
      // Get all feed items for this journal entry
      final allFeedItems = await FeedService.getFeedItemsForEntry(journalEntryId);
      print('\nAll feed items for this entry:');
      for (final item in allFeedItems) {
        print('  - ${item.displayName}: ${item.formattedQuantity}${item.note != null ? ' (${item.note})' : ''}');
      }
      
    } catch (e) {
      print('Error in feed recording: $e');
    }
  }
}

/// Example 3: "Use Last" Functionality
/// 
/// Shows how to implement quick feed entry using recent feeds
class UseLastFeedExample {
  static Future<void> demonstrateUseLastFeed(String newJournalEntryId) async {
    print('=== Use Last Feed Example ===');
    
    try {
      // Get user's recent feeds
      final recentFeeds = await FeedService.getUserRecentFeed(limit: 5);
      
      if (recentFeeds.isEmpty) {
        print('No recent feeds found');
        return;
      }
      
      print('Recent feeds:');
      for (int i = 0; i < recentFeeds.length; i++) {
        final feed = recentFeeds[i];
        print('  ${i + 1}. ${feed.displayName}: ${feed.formattedQuantity} (last used: ${feed.lastUsedAt})');
      }
      
      // Use the first recent feed for the new entry
      final selectedRecent = recentFeeds.first;
      final newFeedItem = selectedRecent.toFeedItem(
        entryId: newJournalEntryId,
        note: 'Using recent feed configuration',
      );
      
      final savedItem = await FeedService.saveFeedItem(newFeedItem);
      print('\nCreated new feed item from recent: ${savedItem.displayName}');
      
    } catch (e) {
      print('Error in use last feed: $e');
    }
  }
}

/// Example 4: Feed Search and Discovery
/// 
/// Shows how to implement search functionality for feeds
class FeedSearchExample {
  static Future<void> demonstrateFeedSearch() async {
    print('=== Feed Search Example ===');
    
    try {
      // Search for products containing "show"
      final showProducts = await FeedService.searchProducts('show', limit: 10);
      print('Products containing "show": ${showProducts.length} results');
      for (final product in showProducts) {
        print('  - ${product.displayName} (${product.type})');
      }
      
      // Search for cattle-specific supplements
      final cattleSupplements = await FeedService.searchProducts(
        'supplement',
        species: 'cattle',
        type: FeedType.supplement,
      );
      print('\nCattle supplements: ${cattleSupplements.length} results');
      for (final product in cattleSupplements) {
        print('  - ${product.displayName}');
      }
      
      // Get popular products
      final popularProducts = await FeedService.getPopularProducts(limit: 5);
      print('\nPopular products:');
      for (final product in popularProducts) {
        print('  - ${product.displayName}');
      }
      
      // Get all products for a specific species
      final goatProducts = await FeedService.getAllProducts(species: 'goat');
      print('\nAll goat products: ${goatProducts.length} items');
      
    } catch (e) {
      print('Error in feed search: $e');
    }
  }
}

/// Example 5: Feed Management UI Components
/// 
/// Flutter widget examples showing practical UI implementation
class FeedManagementWidgets {
  
  /// Dropdown widget for brand selection
  static Widget buildBrandDropdown({
    required List<FeedBrand> brands,
    required FeedBrand? selectedBrand,
    required Function(FeedBrand?) onChanged,
  }) {
    return DropdownButtonFormField<FeedBrand>(
      value: selectedBrand,
      decoration: const InputDecoration(
        labelText: 'Feed Brand',
        border: OutlineInputBorder(),
      ),
      items: brands.map((brand) {
        return DropdownMenuItem<FeedBrand>(
          value: brand,
          child: Text(brand.name),
        );
      }).toList(),
      onChanged: onChanged,
      validator: (value) => value == null ? 'Please select a brand' : null,
    );
  }
  
  /// Dropdown widget for product selection with species filtering
  static Widget buildProductDropdown({
    required List<FeedProduct> products,
    required FeedProduct? selectedProduct,
    required Function(FeedProduct?) onChanged,
    String? species,
  }) {
    // Filter products by species if specified
    final filteredProducts = species != null
        ? products.where((p) => p.isForSpecies(species)).toList()
        : products;
    
    return DropdownButtonFormField<FeedProduct>(
      value: selectedProduct,
      decoration: InputDecoration(
        labelText: species != null ? '$species Products' : 'Feed Products',
        border: const OutlineInputBorder(),
      ),
      items: filteredProducts.map((product) {
        return DropdownMenuItem<FeedProduct>(
          value: product,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(product.name),
              Text(
                '${product.type.displayName} - ${product.species.join(', ')}',
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ],
          ),
        );
      }).toList(),
      onChanged: onChanged,
      validator: (value) => value == null ? 'Please select a product' : null,
    );
  }
  
  /// Widget for quantity input with unit selection
  static Widget buildQuantityInput({
    required double quantity,
    required FeedUnit unit,
    required Function(double) onQuantityChanged,
    required Function(FeedUnit) onUnitChanged,
  }) {
    return Row(
      children: [
        Expanded(
          flex: 2,
          child: TextFormField(
            initialValue: quantity.toString(),
            decoration: const InputDecoration(
              labelText: 'Quantity',
              border: OutlineInputBorder(),
            ),
            keyboardType: TextInputType.number,
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Please enter quantity';
              }
              final parsed = double.tryParse(value);
              if (parsed == null || parsed <= 0) {
                return 'Please enter a valid positive number';
              }
              return null;
            },
            onChanged: (value) {
              final parsed = double.tryParse(value);
              if (parsed != null && parsed > 0) {
                onQuantityChanged(parsed);
              }
            },
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          flex: 1,
          child: DropdownButtonFormField<FeedUnit>(
            value: unit,
            decoration: const InputDecoration(
              labelText: 'Unit',
              border: OutlineInputBorder(),
            ),
            items: FeedUnit.values.map((feedUnit) {
              return DropdownMenuItem<FeedUnit>(
                value: feedUnit,
                child: Text(feedUnit.displayName),
              );
            }).toList(),
            onChanged: (newUnit) {
              if (newUnit != null) {
                onUnitChanged(newUnit);
              }
            },
          ),
        ),
      ],
    );
  }
  
  /// Widget for recent feeds list with "Use This" buttons
  static Widget buildRecentFeedsList({
    required List<UserFeedRecent> recentFeeds,
    required Function(UserFeedRecent) onUseRecent,
  }) {
    if (recentFeeds.isEmpty) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Text(
            'No recent feeds found. Your recently used feeds will appear here for quick access.',
            style: TextStyle(color: Colors.grey),
          ),
        ),
      );
    }
    
    return Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text(
              'Recent Feeds',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ),
          ...recentFeeds.map((recent) {
            return ListTile(
              title: Text(recent.displayName),
              subtitle: Text(
                '${recent.formattedQuantity} - Last used: ${_formatDate(recent.lastUsedAt)}',
              ),
              trailing: ElevatedButton(
                onPressed: () => onUseRecent(recent),
                child: const Text('Use This'),
              ),
            );
          }).toList(),
        ],
      ),
    );
  }
  
  /// Helper method to format dates nicely
  static String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);
    
    if (difference.inDays == 0) {
      return 'Today';
    } else if (difference.inDays == 1) {
      return 'Yesterday';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} days ago';
    } else {
      return '${date.month}/${date.day}/${date.year}';
    }
  }
}

/// Example 6: Complete Feed Entry Form
/// 
/// A complete stateful widget showing how to combine all feed service features
class CompleteFeedEntryForm extends StatefulWidget {
  final String journalEntryId;
  final String? animalSpecies;
  final Function(List<FeedItem>) onFeedItemsAdded;
  
  const CompleteFeedEntryForm({
    Key? key,
    required this.journalEntryId,
    this.animalSpecies,
    required this.onFeedItemsAdded,
  }) : super(key: key);
  
  @override
  State<CompleteFeedEntryForm> createState() => _CompleteFeedEntryFormState();
}

class _CompleteFeedEntryFormState extends State<CompleteFeedEntryForm> {
  final _formKey = GlobalKey<FormState>();
  
  List<FeedBrand> _brands = [];
  List<FeedProduct> _products = [];
  List<UserFeedRecent> _recentFeeds = [];
  List<FeedItem> _currentFeedItems = [];
  
  FeedBrand? _selectedBrand;
  FeedProduct? _selectedProduct;
  bool _isHay = false;
  double _quantity = 1.0;
  FeedUnit _unit = FeedUnit.lbs;
  String _note = '';
  bool _loading = true;
  String? _error;
  
  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }
  
  Future<void> _loadInitialData() async {
    try {
      setState(() {
        _loading = true;
        _error = null;
      });
      
      // Load brands and recent feeds in parallel
      final results = await Future.wait([
        FeedService.getBrands(),
        FeedService.getUserRecentFeed(),
      ]);
      
      setState(() {
        _brands = results[0] as List<FeedBrand>;
        _recentFeeds = results[1] as List<UserFeedRecent>;
        _loading = false;
      });
      
    } catch (e) {
      setState(() {
        _error = 'Failed to load feed data: $e';
        _loading = false;
      });
    }
  }
  
  Future<void> _onBrandChanged(FeedBrand? brand) async {
    if (brand == null) return;
    
    try {
      final products = await FeedService.getProducts(
        brand.id,
        species: widget.animalSpecies,
      );
      
      setState(() {
        _selectedBrand = brand;
        _products = products;
        _selectedProduct = null;
      });
      
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load products: $e')),
      );
    }
  }
  
  Future<void> _addFeedItem() async {
    if (!_formKey.currentState!.validate()) return;
    
    try {
      final feedItem = FeedItem.create(
        entryId: widget.journalEntryId,
        userId: 'current-user-id', // Get from auth service
        brandId: _isHay ? null : _selectedBrand?.id,
        productId: _isHay ? null : _selectedProduct?.id,
        isHay: _isHay,
        quantity: _quantity,
        unit: _unit,
        note: _note.isNotEmpty ? _note : null,
      );
      
      final savedItem = await FeedService.saveFeedItem(feedItem);
      
      setState(() {
        _currentFeedItems.add(savedItem);
        _resetForm();
      });
      
      widget.onFeedItemsAdded(_currentFeedItems);
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Added ${savedItem.displayName}')),
      );
      
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to add feed item: $e')),
      );
    }
  }
  
  void _resetForm() {
    _selectedBrand = null;
    _selectedProduct = null;
    _products.clear();
    _isHay = false;
    _quantity = 1.0;
    _unit = FeedUnit.lbs;
    _note = '';
  }
  
  void _useRecentFeed(UserFeedRecent recent) {
    setState(() {
      _isHay = recent.isHay;
      _quantity = recent.quantity;
      _unit = recent.unit;
      
      if (!recent.isHay && recent.brand != null) {
        _selectedBrand = recent.brand;
        _selectedProduct = recent.product;
        if (_selectedBrand != null) {
          _onBrandChanged(_selectedBrand);
        }
      }
    });
  }
  
  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('Error: $_error'),
            ElevatedButton(
              onPressed: _loadInitialData,
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }
    
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Recent feeds section
          if (_recentFeeds.isNotEmpty)
            FeedManagementWidgets.buildRecentFeedsList(
              recentFeeds: _recentFeeds,
              onUseRecent: _useRecentFeed,
            ),
          
          const SizedBox(height: 16),
          
          // Hay toggle
          SwitchListTile(
            title: const Text('This is hay/roughage'),
            value: _isHay,
            onChanged: (value) {
              setState(() {
                _isHay = value;
                if (value) {
                  _selectedBrand = null;
                  _selectedProduct = null;
                  _products.clear();
                }
              });
            },
          ),
          
          if (!_isHay) ...[
            // Brand selection
            FeedManagementWidgets.buildBrandDropdown(
              brands: _brands,
              selectedBrand: _selectedBrand,
              onChanged: _onBrandChanged,
            ),
            
            const SizedBox(height: 16),
            
            // Product selection
            if (_products.isNotEmpty)
              FeedManagementWidgets.buildProductDropdown(
                products: _products,
                selectedProduct: _selectedProduct,
                onChanged: (product) => setState(() => _selectedProduct = product),
                species: widget.animalSpecies,
              ),
          ],
          
          const SizedBox(height: 16),
          
          // Quantity and unit
          FeedManagementWidgets.buildQuantityInput(
            quantity: _quantity,
            unit: _unit,
            onQuantityChanged: (quantity) => setState(() => _quantity = quantity),
            onUnitChanged: (unit) => setState(() => _unit = unit),
          ),
          
          const SizedBox(height: 16),
          
          // Notes
          TextFormField(
            decoration: const InputDecoration(
              labelText: 'Notes (optional)',
              border: OutlineInputBorder(),
              hintText: 'e.g., Morning feeding, good appetite',
            ),
            maxLines: 2,
            onChanged: (value) => _note = value,
          ),
          
          const SizedBox(height: 16),
          
          // Add button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _addFeedItem,
              child: const Text('Add Feed Item'),
            ),
          ),
          
          // Current feed items
          if (_currentFeedItems.isNotEmpty) ...[
            const SizedBox(height: 16),
            const Text('Feed Items Added:', style: TextStyle(fontWeight: FontWeight.bold)),
            ..._currentFeedItems.map((item) {
              return ListTile(
                title: Text(item.displayName),
                subtitle: Text('${item.formattedQuantity}${item.note != null ? ' - ${item.note}' : ''}'),
                trailing: IconButton(
                  icon: const Icon(Icons.delete),
                  onPressed: () async {
                    try {
                      await FeedService.deleteFeedItem(item.id);
                      setState(() {
                        _currentFeedItems.remove(item);
                      });
                      widget.onFeedItemsAdded(_currentFeedItems);
                    } catch (e) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Failed to delete: $e')),
                      );
                    }
                  },
                ),
              );
            }).toList(),
          ],
        ],
      ),
    );
  }
}

/// Example 7: Running All Examples
/// 
/// Demonstrates how to run all examples in sequence
class FeedServiceExampleRunner {
  static Future<void> runAllExamples() async {
    print('========================================');
    print('RUNNING FEED SERVICE EXAMPLES');
    print('========================================');
    
    // Example 1: Basic feed selection
    await FeedSelectionExample.demonstrateFeedSelection();
    print('\n');
    
    // Example 2: Journal feed recording
    const sampleJournalId = 'sample-journal-entry-id';
    await JournalFeedRecordingExample.demonstrateFeedRecording(sampleJournalId);
    print('\n');
    
    // Example 3: Use last feed
    const newJournalId = 'new-journal-entry-id';
    await UseLastFeedExample.demonstrateUseLastFeed(newJournalId);
    print('\n');
    
    // Example 4: Feed search
    await FeedSearchExample.demonstrateFeedSearch();
    print('\n');
    
    print('========================================');
    print('ALL EXAMPLES COMPLETED');
    print('========================================');
  }
}