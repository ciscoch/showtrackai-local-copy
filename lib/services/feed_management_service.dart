import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/feed.dart';
import '../models/feed_inventory.dart';
import '../models/feed_analytics.dart';

/// Enhanced feed management service with full CRUD operations
/// Handles custom brands, products, inventory, and analytics
class FeedManagementService {
  static final _supabase = Supabase.instance.client;

  // ============================================================================
  // CUSTOM BRAND MANAGEMENT
  // ============================================================================

  /// Create a custom feed brand for the user
  static Future<FeedBrand> createCustomBrand({
    required String name,
    String? description,
    String? manufacturerWebsite,
    Map<String, dynamic>? contactInfo,
  }) async {
    try {
      _ensureAuthenticated();
      final currentUser = _supabase.auth.currentUser!;

      print('🏷️ Creating custom brand: $name');

      final brandData = {
        'name': name,
        'description': description,
        'manufacturer_website': manufacturerWebsite,
        'contact_info': contactInfo,
        'user_id': currentUser.id,
        'is_custom': true,
        'is_active': true,
      };

      final response = await _supabase
          .from('feed_brands')
          .insert(brandData)
          .select()
          .single();

      final brand = FeedBrand.fromJson(response);
      print('✅ Custom brand created: ${brand.id}');
      return brand;

    } on PostgrestException catch (e) {
      print('❌ Database error creating brand: ${e.message}');
      throw FeedServiceException(
        message: 'Failed to create custom brand: ${e.message}',
        code: 'DATABASE_ERROR',
        originalError: e,
      );
    } catch (e) {
      print('❌ Unexpected error creating brand: $e');
      throw FeedServiceException(
        message: 'Failed to create custom brand',
        originalError: e,
      );
    }
  }

  /// Update a custom feed brand
  static Future<FeedBrand> updateCustomBrand({
    required String brandId,
    required String name,
    String? description,
    String? manufacturerWebsite,
    Map<String, dynamic>? contactInfo,
    bool? isActive,
  }) async {
    try {
      _ensureAuthenticated();
      final currentUser = _supabase.auth.currentUser!;

      print('📝 Updating custom brand: $brandId');

      // Verify ownership
      final existing = await _supabase
          .from('feed_brands')
          .select('user_id, is_custom')
          .eq('id', brandId)
          .single();

      if (existing['user_id'] != currentUser.id || existing['is_custom'] != true) {
        throw const FeedServiceException(
          message: 'You can only update your own custom brands',
          code: 'UNAUTHORIZED',
        );
      }

      final updateData = {
        'name': name,
        'description': description,
        'manufacturer_website': manufacturerWebsite,
        'contact_info': contactInfo,
        'is_active': isActive,
        'updated_at': DateTime.now().toIso8601String(),
      };

      final response = await _supabase
          .from('feed_brands')
          .update(updateData)
          .eq('id', brandId)
          .select()
          .single();

      final brand = FeedBrand.fromJson(response);
      print('✅ Custom brand updated: ${brand.id}');
      return brand;

    } on PostgrestException catch (e) {
      print('❌ Database error updating brand: ${e.message}');
      throw FeedServiceException(
        message: 'Failed to update custom brand: ${e.message}',
        code: 'DATABASE_ERROR',
        originalError: e,
      );
    } catch (e) {
      print('❌ Unexpected error updating brand: $e');
      throw FeedServiceException(
        message: 'Failed to update custom brand',
        originalError: e,
      );
    }
  }

  /// Delete a custom feed brand
  static Future<void> deleteCustomBrand(String brandId) async {
    try {
      _ensureAuthenticated();
      final currentUser = _supabase.auth.currentUser!;

      print('🗑️ Deleting custom brand: $brandId');

      // Verify ownership
      final existing = await _supabase
          .from('feed_brands')
          .select('user_id, is_custom')
          .eq('id', brandId)
          .single();

      if (existing['user_id'] != currentUser.id || existing['is_custom'] != true) {
        throw const FeedServiceException(
          message: 'You can only delete your own custom brands',
          code: 'UNAUTHORIZED',
        );
      }

      await _supabase
          .from('feed_brands')
          .delete()
          .eq('id', brandId);

      print('✅ Custom brand deleted');

    } on PostgrestException catch (e) {
      print('❌ Database error deleting brand: ${e.message}');
      throw FeedServiceException(
        message: 'Failed to delete custom brand: ${e.message}',
        code: 'DATABASE_ERROR',
        originalError: e,
      );
    } catch (e) {
      print('❌ Unexpected error deleting brand: $e');
      throw FeedServiceException(
        message: 'Failed to delete custom brand',
        originalError: e,
      );
    }
  }

  /// Get user's custom brands
  static Future<List<FeedBrand>> getUserCustomBrands() async {
    try {
      _ensureAuthenticated();
      final currentUser = _supabase.auth.currentUser!;

      print('🏷️ Fetching user custom brands');

      final response = await _supabase
          .from('feed_brands')
          .select()
          .eq('user_id', currentUser.id)
          .eq('is_custom', true)
          .order('name', ascending: true);

      final brands = (response as List)
          .map((json) => FeedBrand.fromJson(json))
          .toList();

      print('✅ Found ${brands.length} custom brands');
      return brands;

    } on PostgrestException catch (e) {
      print('❌ Database error fetching custom brands: ${e.message}');
      throw FeedServiceException(
        message: 'Failed to load custom brands: ${e.message}',
        code: 'DATABASE_ERROR',
        originalError: e,
      );
    } catch (e) {
      print('❌ Unexpected error fetching custom brands: $e');
      throw FeedServiceException(
        message: 'Failed to load custom brands',
        originalError: e,
      );
    }
  }

  // ============================================================================
  // CUSTOM PRODUCT MANAGEMENT
  // ============================================================================

  /// Create a custom feed product
  static Future<FeedProduct> createCustomProduct({
    required String brandId,
    required String name,
    required List<String> species,
    required FeedType type,
    String? description,
    double? proteinPercentage,
    double? fatPercentage,
    double? fiberPercentage,
    Map<String, dynamic>? nutritionalInfo,
    double? defaultCostPerUnit,
    String defaultUnit = 'lbs',
    double? packagingSize,
    String? packagingUnit,
    String? barcode,
    String? sku,
  }) async {
    try {
      _ensureAuthenticated();
      final currentUser = _supabase.auth.currentUser!;

      print('📦 Creating custom product: $name');

      final productData = {
        'brand_id': brandId,
        'name': name,
        'species': species,
        'type': type.value,
        'description': description,
        'protein_percentage': proteinPercentage,
        'fat_percentage': fatPercentage,
        'fiber_percentage': fiberPercentage,
        'nutritional_info': nutritionalInfo,
        'default_cost_per_unit': defaultCostPerUnit,
        'default_unit': defaultUnit,
        'packaging_size': packagingSize,
        'packaging_unit': packagingUnit,
        'barcode': barcode,
        'sku': sku,
        'user_id': currentUser.id,
        'is_custom': true,
        'is_active': true,
      };

      final response = await _supabase
          .from('feed_products')
          .insert(productData)
          .select('''
            *,
            brand:feed_brands(*)
          ''')
          .single();

      final product = FeedProduct.fromJson(response);
      print('✅ Custom product created: ${product.id}');
      return product;

    } on PostgrestException catch (e) {
      print('❌ Database error creating product: ${e.message}');
      throw FeedServiceException(
        message: 'Failed to create custom product: ${e.message}',
        code: 'DATABASE_ERROR',
        originalError: e,
      );
    } catch (e) {
      print('❌ Unexpected error creating product: $e');
      throw FeedServiceException(
        message: 'Failed to create custom product',
        originalError: e,
      );
    }
  }

  /// Update a custom feed product
  static Future<FeedProduct> updateCustomProduct({
    required String productId,
    required String name,
    required List<String> species,
    required FeedType type,
    String? description,
    double? proteinPercentage,
    double? fatPercentage,
    double? fiberPercentage,
    Map<String, dynamic>? nutritionalInfo,
    double? defaultCostPerUnit,
    String? defaultUnit,
    double? packagingSize,
    String? packagingUnit,
    String? barcode,
    String? sku,
    bool? isActive,
  }) async {
    try {
      _ensureAuthenticated();
      final currentUser = _supabase.auth.currentUser!;

      print('📝 Updating custom product: $productId');

      // Verify ownership
      final existing = await _supabase
          .from('feed_products')
          .select('user_id, is_custom')
          .eq('id', productId)
          .single();

      if (existing['user_id'] != currentUser.id || existing['is_custom'] != true) {
        throw const FeedServiceException(
          message: 'You can only update your own custom products',
          code: 'UNAUTHORIZED',
        );
      }

      final updateData = {
        'name': name,
        'species': species,
        'type': type.value,
        'description': description,
        'protein_percentage': proteinPercentage,
        'fat_percentage': fatPercentage,
        'fiber_percentage': fiberPercentage,
        'nutritional_info': nutritionalInfo,
        'default_cost_per_unit': defaultCostPerUnit,
        'default_unit': defaultUnit,
        'packaging_size': packagingSize,
        'packaging_unit': packagingUnit,
        'barcode': barcode,
        'sku': sku,
        'is_active': isActive,
        'updated_at': DateTime.now().toIso8601String(),
      };

      final response = await _supabase
          .from('feed_products')
          .update(updateData)
          .eq('id', productId)
          .select('''
            *,
            brand:feed_brands(*)
          ''')
          .single();

      final product = FeedProduct.fromJson(response);
      print('✅ Custom product updated: ${product.id}');
      return product;

    } on PostgrestException catch (e) {
      print('❌ Database error updating product: ${e.message}');
      throw FeedServiceException(
        message: 'Failed to update custom product: ${e.message}',
        code: 'DATABASE_ERROR',
        originalError: e,
      );
    } catch (e) {
      print('❌ Unexpected error updating product: $e');
      throw FeedServiceException(
        message: 'Failed to update custom product',
        originalError: e,
      );
    }
  }

  /// Delete a custom feed product
  static Future<void> deleteCustomProduct(String productId) async {
    try {
      _ensureAuthenticated();
      final currentUser = _supabase.auth.currentUser!;

      print('🗑️ Deleting custom product: $productId');

      // Verify ownership
      final existing = await _supabase
          .from('feed_products')
          .select('user_id, is_custom')
          .eq('id', productId)
          .single();

      if (existing['user_id'] != currentUser.id || existing['is_custom'] != true) {
        throw const FeedServiceException(
          message: 'You can only delete your own custom products',
          code: 'UNAUTHORIZED',
        );
      }

      await _supabase
          .from('feed_products')
          .delete()
          .eq('id', productId);

      print('✅ Custom product deleted');

    } on PostgrestException catch (e) {
      print('❌ Database error deleting product: ${e.message}');
      throw FeedServiceException(
        message: 'Failed to delete custom product: ${e.message}',
        code: 'DATABASE_ERROR',
        originalError: e,
      );
    } catch (e) {
      print('❌ Unexpected error deleting product: $e');
      throw FeedServiceException(
        message: 'Failed to delete custom product',
        originalError: e,
      );
    }
  }

  /// Get user's custom products
  static Future<List<FeedProduct>> getUserCustomProducts() async {
    try {
      _ensureAuthenticated();
      final currentUser = _supabase.auth.currentUser!;

      print('📦 Fetching user custom products');

      final response = await _supabase
          .from('feed_products')
          .select('''
            *,
            brand:feed_brands(*)
          ''')
          .eq('user_id', currentUser.id)
          .eq('is_custom', true)
          .order('name', ascending: true);

      final products = (response as List)
          .map((json) => FeedProduct.fromJson(json))
          .toList();

      print('✅ Found ${products.length} custom products');
      return products;

    } on PostgrestException catch (e) {
      print('❌ Database error fetching custom products: ${e.message}');
      throw FeedServiceException(
        message: 'Failed to load custom products: ${e.message}',
        code: 'DATABASE_ERROR',
        originalError: e,
      );
    } catch (e) {
      print('❌ Unexpected error fetching custom products: $e');
      throw FeedServiceException(
        message: 'Failed to load custom products',
        originalError: e,
      );
    }
  }

  // ============================================================================
  // INVENTORY MANAGEMENT
  // ============================================================================

  /// Get current feed inventory
  static Future<List<FeedInventory>> getInventory() async {
    try {
      _ensureAuthenticated();
      final currentUser = _supabase.auth.currentUser!;

      print('📦 Fetching feed inventory');

      final response = await _supabase
          .from('feed_inventory')
          .select('''
            *,
            brand:feed_brands(*),
            product:feed_products(*)
          ''')
          .eq('user_id', currentUser.id)
          .order('current_quantity', ascending: false);

      final inventory = (response as List)
          .map((json) => FeedInventory.fromJson(json))
          .toList();

      print('✅ Found ${inventory.length} inventory items');
      return inventory;

    } on PostgrestException catch (e) {
      print('❌ Database error fetching inventory: ${e.message}');
      throw FeedServiceException(
        message: 'Failed to load inventory: ${e.message}',
        code: 'DATABASE_ERROR',
        originalError: e,
      );
    } catch (e) {
      print('❌ Unexpected error fetching inventory: $e');
      throw FeedServiceException(
        message: 'Failed to load inventory',
        originalError: e,
      );
    }
  }

  /// Add a feed purchase
  static Future<FeedPurchase> addPurchase({
    required String brandId,
    required String productId,
    required DateTime purchaseDate,
    required double quantity,
    required double unitPrice,
    String unit = 'lbs',
    String? vendorName,
    String? vendorContact,
    String? invoiceNumber,
    String? lotNumber,
    DateTime? expirationDate,
    String? notes,
    String? receiptUrl,
  }) async {
    try {
      _ensureAuthenticated();
      final currentUser = _supabase.auth.currentUser!;

      print('💰 Adding feed purchase');

      final purchaseData = {
        'user_id': currentUser.id,
        'brand_id': brandId,
        'product_id': productId,
        'purchase_date': purchaseDate.toIso8601String().split('T')[0],
        'quantity': quantity,
        'unit': unit,
        'unit_price': unitPrice,
        'vendor_name': vendorName,
        'vendor_contact': vendorContact,
        'invoice_number': invoiceNumber,
        'lot_number': lotNumber,
        'expiration_date': expirationDate?.toIso8601String().split('T')[0],
        'notes': notes,
        'receipt_url': receiptUrl,
      };

      final response = await _supabase
          .from('feed_purchases')
          .insert(purchaseData)
          .select('''
            *,
            brand:feed_brands(*),
            product:feed_products(*)
          ''')
          .single();

      final purchase = FeedPurchase.fromJson(response);
      print('✅ Feed purchase added: ${purchase.id}');
      return purchase;

    } on PostgrestException catch (e) {
      print('❌ Database error adding purchase: ${e.message}');
      throw FeedServiceException(
        message: 'Failed to add purchase: ${e.message}',
        code: 'DATABASE_ERROR',
        originalError: e,
      );
    } catch (e) {
      print('❌ Unexpected error adding purchase: $e');
      throw FeedServiceException(
        message: 'Failed to add purchase',
        originalError: e,
      );
    }
  }

  /// Update inventory levels
  static Future<FeedInventory> updateInventory({
    required String inventoryId,
    double? minimumQuantity,
    double? maximumQuantity,
    String? storageLocation,
    String? binNumber,
    String? notes,
  }) async {
    try {
      _ensureAuthenticated();

      print('📝 Updating inventory: $inventoryId');

      final updateData = {
        'minimum_quantity': minimumQuantity,
        'maximum_quantity': maximumQuantity,
        'storage_location': storageLocation,
        'bin_number': binNumber,
        'notes': notes,
        'updated_at': DateTime.now().toIso8601String(),
      };

      final response = await _supabase
          .from('feed_inventory')
          .update(updateData)
          .eq('id', inventoryId)
          .select('''
            *,
            brand:feed_brands(*),
            product:feed_products(*)
          ''')
          .single();

      final inventory = FeedInventory.fromJson(response);
      print('✅ Inventory updated: ${inventory.id}');
      return inventory;

    } on PostgrestException catch (e) {
      print('❌ Database error updating inventory: ${e.message}');
      throw FeedServiceException(
        message: 'Failed to update inventory: ${e.message}',
        code: 'DATABASE_ERROR',
        originalError: e,
      );
    } catch (e) {
      print('❌ Unexpected error updating inventory: $e');
      throw FeedServiceException(
        message: 'Failed to update inventory',
        originalError: e,
      );
    }
  }

  /// Get low stock items
  static Future<List<FeedInventory>> getLowStockItems() async {
    try {
      _ensureAuthenticated();
      final currentUser = _supabase.auth.currentUser!;

      print('⚠️ Checking for low stock items');

      final response = await _supabase
          .from('v_inventory_status')
          .select()
          .eq('user_id', currentUser.id)
          .eq('stock_status', 'Low Stock');

      final items = (response as List)
          .map((json) => FeedInventory.fromJson(json))
          .toList();

      print('✅ Found ${items.length} low stock items');
      return items;

    } on PostgrestException catch (e) {
      print('❌ Database error fetching low stock: ${e.message}');
      throw FeedServiceException(
        message: 'Failed to check low stock: ${e.message}',
        code: 'DATABASE_ERROR',
        originalError: e,
      );
    } catch (e) {
      print('❌ Unexpected error fetching low stock: $e');
      throw FeedServiceException(
        message: 'Failed to check low stock',
        originalError: e,
      );
    }
  }

  // ============================================================================
  // FCR TRACKING
  // ============================================================================

  /// Start FCR tracking period
  static Future<FeedConversionTracking> startFCRTracking({
    required String animalId,
    required double startWeight,
    required DateTime startDate,
  }) async {
    try {
      _ensureAuthenticated();
      final currentUser = _supabase.auth.currentUser!;

      print('📊 Starting FCR tracking for animal: $animalId');

      final trackingData = {
        'user_id': currentUser.id,
        'animal_id': animalId,
        'start_date': startDate.toIso8601String().split('T')[0],
        'start_weight': startWeight,
        'end_date': startDate.toIso8601String().split('T')[0], // Will be updated
        'end_weight': startWeight, // Will be updated
        'total_feed_consumed': 0.0, // Will be accumulated
        'feed_unit': 'lbs',
      };

      final response = await _supabase
          .from('feed_conversion_tracking')
          .insert(trackingData)
          .select()
          .single();

      final tracking = FeedConversionTracking.fromJson(response);
      print('✅ FCR tracking started: ${tracking.id}');
      return tracking;

    } on PostgrestException catch (e) {
      print('❌ Database error starting FCR tracking: ${e.message}');
      throw FeedServiceException(
        message: 'Failed to start FCR tracking: ${e.message}',
        code: 'DATABASE_ERROR',
        originalError: e,
      );
    } catch (e) {
      print('❌ Unexpected error starting FCR tracking: $e');
      throw FeedServiceException(
        message: 'Failed to start FCR tracking',
        originalError: e,
      );
    }
  }

  /// Complete FCR tracking period
  static Future<FeedConversionTracking> completeFCRTracking({
    required String trackingId,
    required double endWeight,
    required double totalFeedConsumed,
    required DateTime endDate,
    double? totalFeedCost,
    String? notes,
  }) async {
    try {
      _ensureAuthenticated();

      print('📊 Completing FCR tracking: $trackingId');

      final updateData = {
        'end_date': endDate.toIso8601String().split('T')[0],
        'end_weight': endWeight,
        'total_feed_consumed': totalFeedConsumed,
        'total_feed_cost': totalFeedCost,
        'notes': notes,
        'updated_at': DateTime.now().toIso8601String(),
      };

      final response = await _supabase
          .from('feed_conversion_tracking')
          .update(updateData)
          .eq('id', trackingId)
          .select()
          .single();

      final tracking = FeedConversionTracking.fromJson(response);
      print('✅ FCR tracking completed. FCR: ${tracking.feedConversionRatio}');
      return tracking;

    } on PostgrestException catch (e) {
      print('❌ Database error completing FCR tracking: ${e.message}');
      throw FeedServiceException(
        message: 'Failed to complete FCR tracking: ${e.message}',
        code: 'DATABASE_ERROR',
        originalError: e,
      );
    } catch (e) {
      print('❌ Unexpected error completing FCR tracking: $e');
      throw FeedServiceException(
        message: 'Failed to complete FCR tracking',
        originalError: e,
      );
    }
  }

  /// Get FCR history for an animal
  static Future<List<FeedConversionTracking>> getAnimalFCRHistory(String animalId) async {
    try {
      _ensureAuthenticated();

      print('📊 Fetching FCR history for animal: $animalId');

      final response = await _supabase
          .from('feed_conversion_tracking')
          .select()
          .eq('animal_id', animalId)
          .order('end_date', ascending: false);

      final history = (response as List)
          .map((json) => FeedConversionTracking.fromJson(json))
          .toList();

      print('✅ Found ${history.length} FCR records');
      return history;

    } on PostgrestException catch (e) {
      print('❌ Database error fetching FCR history: ${e.message}');
      throw FeedServiceException(
        message: 'Failed to load FCR history: ${e.message}',
        code: 'DATABASE_ERROR',
        originalError: e,
      );
    } catch (e) {
      print('❌ Unexpected error fetching FCR history: $e');
      throw FeedServiceException(
        message: 'Failed to load FCR history',
        originalError: e,
      );
    }
  }

  // ============================================================================
  // ANALYTICS
  // ============================================================================

  /// Get feed cost analytics
  static Future<FeedCostAnalytics> getCostAnalytics({
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    try {
      _ensureAuthenticated();
      final currentUser = _supabase.auth.currentUser!;

      print('📊 Fetching feed cost analytics');

      var query = _supabase
          .from('v_feed_cost_analytics')
          .select()
          .eq('user_id', currentUser.id);

      if (startDate != null) {
        query = query.gte('month', startDate.toIso8601String());
      }
      if (endDate != null) {
        query = query.lte('month', endDate.toIso8601String());
      }

      final response = await query.order('month', ascending: false);

      final analytics = FeedCostAnalytics.fromJson({
        'data': response,
        'user_id': currentUser.id,
      });

      print('✅ Cost analytics loaded');
      return analytics;

    } on PostgrestException catch (e) {
      print('❌ Database error fetching analytics: ${e.message}');
      throw FeedServiceException(
        message: 'Failed to load analytics: ${e.message}',
        code: 'DATABASE_ERROR',
        originalError: e,
      );
    } catch (e) {
      print('❌ Unexpected error fetching analytics: $e');
      throw FeedServiceException(
        message: 'Failed to load analytics',
        originalError: e,
      );
    }
  }

  /// Get FCR performance metrics
  static Future<List<FCRPerformance>> getFCRPerformance() async {
    try {
      _ensureAuthenticated();
      final currentUser = _supabase.auth.currentUser!;

      print('📊 Fetching FCR performance metrics');

      final response = await _supabase
          .from('v_fcr_performance')
          .select()
          .eq('user_id', currentUser.id)
          .order('end_date', ascending: false);

      final performance = (response as List)
          .map((json) => FCRPerformance.fromJson(json))
          .toList();

      print('✅ Found ${performance.length} FCR performance records');
      return performance;

    } on PostgrestException catch (e) {
      print('❌ Database error fetching FCR performance: ${e.message}');
      throw FeedServiceException(
        message: 'Failed to load FCR performance: ${e.message}',
        code: 'DATABASE_ERROR',
        originalError: e,
      );
    } catch (e) {
      print('❌ Unexpected error fetching FCR performance: $e');
      throw FeedServiceException(
        message: 'Failed to load FCR performance',
        originalError: e,
      );
    }
  }

  // ============================================================================
  // HELPER METHODS
  // ============================================================================

  /// Ensure user is authenticated
  static void _ensureAuthenticated() {
    if (_supabase.auth.currentUser == null) {
      throw const FeedServiceException(
        message: 'User must be authenticated to manage feeds',
        code: 'UNAUTHENTICATED',
      );
    }
  }
}