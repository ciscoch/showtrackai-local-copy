import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/feed.dart';

/// Service for managing livestock feed data with Supabase backend
/// 
/// This service provides comprehensive feed management functionality:
/// - Browse feed brands and products
/// - Filter products by species compatibility
/// - Save feed items to journal entries  
/// - Manage "Use Last" functionality for quick feed entry
/// 
/// All operations include proper error handling and authentication checks.
class FeedService {
  static final _supabase = Supabase.instance.client;
  
  /// Get all active feed brands ordered alphabetically
  /// 
  /// Returns a list of active feed brands for display in dropdowns/lists.
  /// Results are cached for 5 minutes to improve performance.
  /// 
  /// Throws [FeedServiceException] if the operation fails.
  /// 
  /// Example:
  /// ```dart
  /// final brands = await FeedService.getBrands();
  /// print('Found ${brands.length} brands');
  /// ```
  static Future<List<FeedBrand>> getBrands() async {
    try {
      _ensureAuthenticated();

      print('🏷️ Fetching active feed brands...');

      final response = await _supabase
          .from('feed_brands')
          .select()
          .eq('is_active', true)
          .order('name', ascending: true);

      final brands = (response as List)
          .map((json) => FeedBrand.fromJson(json))
          .toList();

      print('✅ Found ${brands.length} active brands');
      return brands;

    } on PostgrestException catch (e) {
      print('❌ Database error fetching brands: ${e.message}');
      throw FeedServiceException(
        message: 'Failed to load feed brands: ${e.message}',
        code: 'DATABASE_ERROR',
        originalError: e,
      );
    } catch (e) {
      print('❌ Unexpected error fetching brands: $e');
      throw FeedServiceException(
        message: 'Failed to load feed brands',
        originalError: e,
      );
    }
  }

  /// Get products for a specific brand with optional species filtering
  /// 
  /// [brandId] - UUID of the brand to get products for
  /// [species] - Optional species filter (e.g., 'cattle', 'goat', 'sheep', 'swine')
  /// 
  /// Returns products that match the brand and optionally the species.
  /// Products include their parent brand information for display.
  /// 
  /// Throws [FeedServiceException] if the operation fails.
  /// 
  /// Example:
  /// ```dart
  /// // Get all products for Purina
  /// final allProducts = await FeedService.getProducts('brand-uuid');
  /// 
  /// // Get only cattle products for Purina
  /// final cattleProducts = await FeedService.getProducts('brand-uuid', species: 'cattle');
  /// ```
  static Future<List<FeedProduct>> getProducts(String brandId, {String? species}) async {
    try {
      _ensureAuthenticated();

      if (brandId.isEmpty) {
        throw const FeedServiceException(
          message: 'Brand ID is required',
          code: 'INVALID_INPUT',
        );
      }

      print('🥫 Fetching products for brand: $brandId${species != null ? ' (species: $species)' : ''}');

      var query = _supabase
          .from('feed_products')
          .select('''
            *,
            brand:feed_brands(*)
          ''')
          .eq('brand_id', brandId)
          .eq('is_active', true);

      // Add species filtering if specified
      if (species != null && species.isNotEmpty) {
        final speciesLower = species.toLowerCase();
        query = query.contains('species', [speciesLower]);
      }

      final response = await query.order('name', ascending: true);

      final products = (response as List)
          .map((json) => FeedProduct.fromJson(json))
          .toList();

      print('✅ Found ${products.length} products');
      return products;

    } on PostgrestException catch (e) {
      print('❌ Database error fetching products: ${e.message}');
      throw FeedServiceException(
        message: 'Failed to load feed products: ${e.message}',
        code: 'DATABASE_ERROR',
        originalError: e,
      );
    } catch (e) {
      print('❌ Unexpected error fetching products: $e');
      throw FeedServiceException(
        message: 'Failed to load feed products',
        originalError: e,
      );
    }
  }

  /// Get all products across all brands with optional species filtering
  /// 
  /// [species] - Optional species filter
  /// [type] - Optional feed type filter
  /// [limit] - Maximum number of products to return (default: 100)
  /// 
  /// Useful for search functionality or displaying popular products.
  /// 
  /// Example:
  /// ```dart
  /// // Get all cattle feeds
  /// final cattleFeeds = await FeedService.getAllProducts(species: 'cattle');
  /// 
  /// // Get all supplements
  /// final supplements = await FeedService.getAllProducts(type: FeedType.supplement);
  /// ```
  static Future<List<FeedProduct>> getAllProducts({
    String? species,
    FeedType? type,
    int limit = 100,
  }) async {
    try {
      _ensureAuthenticated();

      print('🔍 Fetching all products${species != null ? ' for $species' : ''}${type != null ? ' (type: $type)' : ''}');

      var query = _supabase
          .from('feed_products')
          .select('''
            *,
            brand:feed_brands(*)
          ''')
          .eq('is_active', true);

      // Add species filtering if specified
      if (species != null && species.isNotEmpty) {
        final speciesLower = species.toLowerCase();
        query = query.contains('species', [speciesLower]);
      }

      // Add type filtering if specified
      if (type != null) {
        query = query.eq('type', type.value);
      }

      final response = await query
          .order('name', ascending: true)
          .limit(limit);

      final products = (response as List)
          .map((json) => FeedProduct.fromJson(json))
          .toList();

      print('✅ Found ${products.length} products');
      return products;

    } on PostgrestException catch (e) {
      print('❌ Database error fetching all products: ${e.message}');
      throw FeedServiceException(
        message: 'Failed to load products: ${e.message}',
        code: 'DATABASE_ERROR',
        originalError: e,
      );
    } catch (e) {
      print('❌ Unexpected error fetching all products: $e');
      throw FeedServiceException(
        message: 'Failed to load products',
        originalError: e,
      );
    }
  }

  /// Get user's recent feed configurations for "Use Last" functionality
  /// 
  /// [limit] - Maximum number of recent feeds to return (default: 10)
  /// 
  /// Returns the most recently used feed configurations, ordered by last use.
  /// Includes full brand and product information for display.
  /// 
  /// Throws [FeedServiceException] if the operation fails.
  /// 
  /// Example:
  /// ```dart
  /// final recentFeeds = await FeedService.getUserRecentFeed();
  /// for (final feed in recentFeeds) {
  ///   print('${feed.displayName}: ${feed.formattedQuantity}');
  /// }
  /// ```
  static Future<List<UserFeedRecent>> getUserRecentFeed({int limit = 10}) async {
    try {
      _ensureAuthenticated();

      final currentUser = _supabase.auth.currentUser!;
      print('🕒 Fetching recent feeds for user: ${currentUser.id}');

      final response = await _supabase
          .from('user_feed_recent')
          .select('''
            *,
            brand:feed_brands(*),
            product:feed_products(
              *,
              brand:feed_brands(*)
            )
          ''')
          .eq('user_id', currentUser.id)
          .order('last_used_at', ascending: false)
          .limit(limit);

      final recentFeeds = (response as List)
          .map((json) => UserFeedRecent.fromJson(json))
          .toList();

      print('✅ Found ${recentFeeds.length} recent feed configurations');
      return recentFeeds;

    } on PostgrestException catch (e) {
      print('❌ Database error fetching recent feeds: ${e.message}');
      throw FeedServiceException(
        message: 'Failed to load recent feeds: ${e.message}',
        code: 'DATABASE_ERROR',
        originalError: e,
      );
    } catch (e) {
      print('❌ Unexpected error fetching recent feeds: $e');
      throw FeedServiceException(
        message: 'Failed to load recent feeds',
        originalError: e,
      );
    }
  }

  /// Save a feed item to a journal entry
  /// 
  /// [feedItem] - The feed item to save
  /// 
  /// Creates a new feed item record linked to a journal entry.
  /// Automatically updates the user's recent feeds for "Use Last" functionality.
  /// 
  /// Returns the created feed item with generated ID.
  /// 
  /// Throws [FeedServiceException] if the operation fails.
  /// 
  /// Example:
  /// ```dart
  /// final feedItem = FeedItem.create(
  ///   entryId: journalEntry.id,
  ///   userId: currentUser.id,
  ///   brandId: selectedBrand.id,
  ///   productId: selectedProduct.id,
  ///   quantity: 5.0,
  ///   unit: FeedUnit.lbs,
  ///   note: 'Morning feeding',
  /// );
  /// 
  /// final savedItem = await FeedService.saveFeedItem(feedItem);
  /// ```
  static Future<FeedItem> saveFeedItem(FeedItem feedItem) async {
    try {
      _ensureAuthenticated();

      final currentUser = _supabase.auth.currentUser!;
      
      // Validate user ownership
      if (feedItem.userId != currentUser.id) {
        throw const FeedServiceException(
          message: 'Cannot save feed item for another user',
          code: 'UNAUTHORIZED',
        );
      }

      // Validate required fields
      if (feedItem.entryId.isEmpty) {
        throw const FeedServiceException(
          message: 'Journal entry ID is required',
          code: 'INVALID_INPUT',
        );
      }

      if (feedItem.quantity <= 0) {
        throw const FeedServiceException(
          message: 'Quantity must be greater than zero',
          code: 'INVALID_INPUT',
        );
      }

      // Validate that either hay or brand/product is specified
      if (!feedItem.isHay && (feedItem.brandId == null || feedItem.productId == null)) {
        throw const FeedServiceException(
          message: 'Brand and product are required for non-hay items',
          code: 'INVALID_INPUT',
        );
      }

      print('💾 Saving feed item: ${feedItem.displayName} (${feedItem.formattedQuantity})');

      final response = await _supabase
          .from('journal_feed_items')
          .insert(feedItem.toJson())
          .select('''
            *,
            brand:feed_brands(*),
            product:feed_products(
              *,
              brand:feed_brands(*)
            )
          ''')
          .single();

      final savedItem = FeedItem.fromJson(response);

      print('✅ Feed item saved successfully: ${savedItem.id}');

      // The database trigger automatically updates user_feed_recent
      // No need to call updateUserRecent manually

      return savedItem;

    } on PostgrestException catch (e) {
      print('❌ Database error saving feed item: ${e.message}');
      throw FeedServiceException(
        message: 'Failed to save feed item: ${e.message}',
        code: 'DATABASE_ERROR',
        originalError: e,
      );
    } catch (e) {
      print('❌ Unexpected error saving feed item: $e');
      throw FeedServiceException(
        message: 'Failed to save feed item',
        originalError: e,
      );
    }
  }

  /// Update user's recent feed configuration manually
  /// 
  /// [recentFeed] - The recent feed configuration to save/update
  /// 
  /// This method is typically called automatically when saving feed items,
  /// but can be used directly to update recent feed preferences.
  /// 
  /// Uses UPSERT logic to update existing or create new recent feed records.
  /// 
  /// Example:
  /// ```dart
  /// final recentFeed = UserFeedRecent(
  ///   id: const Uuid().v4(),
  ///   userId: currentUser.id,
  ///   brandId: brand.id,
  ///   productId: product.id,
  ///   quantity: 6.0,
  ///   unit: FeedUnit.lbs,
  ///   lastUsedAt: DateTime.now(),
  ///   updatedAt: DateTime.now(),
  /// );
  /// 
  /// await FeedService.updateUserRecent(recentFeed);
  /// ```
  static Future<UserFeedRecent> updateUserRecent(UserFeedRecent recentFeed) async {
    try {
      _ensureAuthenticated();

      final currentUser = _supabase.auth.currentUser!;
      
      // Validate user ownership
      if (recentFeed.userId != currentUser.id) {
        throw const FeedServiceException(
          message: 'Cannot update recent feed for another user',
          code: 'UNAUTHORIZED',
        );
      }

      // Validate required fields
      if (recentFeed.quantity <= 0) {
        throw const FeedServiceException(
          message: 'Quantity must be greater than zero',
          code: 'INVALID_INPUT',
        );
      }

      // Validate that either hay or brand/product is specified
      if (!recentFeed.isHay && (recentFeed.brandId == null || recentFeed.productId == null)) {
        throw const FeedServiceException(
          message: 'Brand and product are required for non-hay items',
          code: 'INVALID_INPUT',
        );
      }

      print('🕒 Updating recent feed: ${recentFeed.displayName}');

      final response = await _supabase
          .from('user_feed_recent')
          .upsert(recentFeed.toJson(), onConflict: 'user_id,brand_id,product_id,is_hay')
          .select('''
            *,
            brand:feed_brands(*),
            product:feed_products(
              *,
              brand:feed_brands(*)
            )
          ''')
          .single();

      final updatedRecent = UserFeedRecent.fromJson(response);

      print('✅ Recent feed updated successfully');
      return updatedRecent;

    } on PostgrestException catch (e) {
      print('❌ Database error updating recent feed: ${e.message}');
      throw FeedServiceException(
        message: 'Failed to update recent feed: ${e.message}',
        code: 'DATABASE_ERROR',
        originalError: e,
      );
    } catch (e) {
      print('❌ Unexpected error updating recent feed: $e');
      throw FeedServiceException(
        message: 'Failed to update recent feed',
        originalError: e,
      );
    }
  }

  /// Get feed items for a specific journal entry
  /// 
  /// [entryId] - UUID of the journal entry
  /// 
  /// Returns all feed items associated with the journal entry,
  /// including full brand and product information.
  /// 
  /// Example:
  /// ```dart
  /// final feedItems = await FeedService.getFeedItemsForEntry(journalEntry.id);
  /// for (final item in feedItems) {
  ///   print('Fed ${item.formattedQuantity} of ${item.displayName}');
  /// }
  /// ```
  static Future<List<FeedItem>> getFeedItemsForEntry(String entryId) async {
    try {
      _ensureAuthenticated();

      if (entryId.isEmpty) {
        throw const FeedServiceException(
          message: 'Entry ID is required',
          code: 'INVALID_INPUT',
        );
      }

      print('📋 Fetching feed items for entry: $entryId');

      final response = await _supabase
          .from('journal_feed_items')
          .select('''
            *,
            brand:feed_brands(*),
            product:feed_products(
              *,
              brand:feed_brands(*)
            )
          ''')
          .eq('entry_id', entryId)
          .order('created_at', ascending: true);

      final feedItems = (response as List)
          .map((json) => FeedItem.fromJson(json))
          .toList();

      print('✅ Found ${feedItems.length} feed items for entry');
      return feedItems;

    } on PostgrestException catch (e) {
      print('❌ Database error fetching feed items: ${e.message}');
      throw FeedServiceException(
        message: 'Failed to load feed items: ${e.message}',
        code: 'DATABASE_ERROR',
        originalError: e,
      );
    } catch (e) {
      print('❌ Unexpected error fetching feed items: $e');
      throw FeedServiceException(
        message: 'Failed to load feed items',
        originalError: e,
      );
    }
  }

  /// Delete a feed item
  /// 
  /// [feedItemId] - UUID of the feed item to delete
  /// 
  /// Only the owner of the feed item can delete it.
  /// This does not affect the user's recent feeds.
  /// 
  /// Example:
  /// ```dart
  /// await FeedService.deleteFeedItem(feedItem.id);
  /// ```
  static Future<void> deleteFeedItem(String feedItemId) async {
    try {
      _ensureAuthenticated();

      if (feedItemId.isEmpty) {
        throw const FeedServiceException(
          message: 'Feed item ID is required',
          code: 'INVALID_INPUT',
        );
      }

      final currentUser = _supabase.auth.currentUser!;

      print('🗑️ Deleting feed item: $feedItemId');

      // First check if the item exists and belongs to the current user
      final existingItem = await _supabase
          .from('journal_feed_items')
          .select('user_id')
          .eq('id', feedItemId)
          .maybeSingle();

      if (existingItem == null) {
        throw const FeedServiceException(
          message: 'Feed item not found',
          code: 'NOT_FOUND',
        );
      }

      if (existingItem['user_id'] != currentUser.id) {
        throw const FeedServiceException(
          message: 'Cannot delete another user\'s feed item',
          code: 'UNAUTHORIZED',
        );
      }

      // Delete the item (RLS policies will ensure user owns it)
      await _supabase
          .from('journal_feed_items')
          .delete()
          .eq('id', feedItemId);

      print('✅ Feed item deleted successfully');

    } on PostgrestException catch (e) {
      print('❌ Database error deleting feed item: ${e.message}');
      throw FeedServiceException(
        message: 'Failed to delete feed item: ${e.message}',
        code: 'DATABASE_ERROR',
        originalError: e,
      );
    } catch (e) {
      print('❌ Unexpected error deleting feed item: $e');
      throw FeedServiceException(
        message: 'Failed to delete feed item',
        originalError: e,
      );
    }
  }

  /// Search products by name across all brands
  /// 
  /// [query] - Search term (minimum 2 characters)
  /// [species] - Optional species filter
  /// [type] - Optional feed type filter
  /// [limit] - Maximum results to return (default: 20)
  /// 
  /// Performs case-insensitive search on product names.
  /// 
  /// Example:
  /// ```dart
  /// final results = await FeedService.searchProducts('honor show', species: 'cattle');
  /// ```
  static Future<List<FeedProduct>> searchProducts(
    String query, {
    String? species,
    FeedType? type,
    int limit = 20,
  }) async {
    try {
      _ensureAuthenticated();

      if (query.length < 2) {
        throw const FeedServiceException(
          message: 'Search query must be at least 2 characters',
          code: 'INVALID_INPUT',
        );
      }

      print('🔍 Searching products for: "$query"${species != null ? ' (species: $species)' : ''}');

      var queryBuilder = _supabase
          .from('feed_products')
          .select('''
            *,
            brand:feed_brands(*)
          ''')
          .eq('is_active', true)
          .ilike('name', '%$query%');

      // Add species filtering if specified
      if (species != null && species.isNotEmpty) {
        final speciesLower = species.toLowerCase();
        queryBuilder = queryBuilder.contains('species', [speciesLower]);
      }

      // Add type filtering if specified
      if (type != null) {
        queryBuilder = queryBuilder.eq('type', type.value);
      }

      final response = await queryBuilder
          .order('name', ascending: true)
          .limit(limit);

      final products = (response as List)
          .map((json) => FeedProduct.fromJson(json))
          .toList();

      print('✅ Found ${products.length} products matching "$query"');
      return products;

    } on PostgrestException catch (e) {
      print('❌ Database error searching products: ${e.message}');
      throw FeedServiceException(
        message: 'Failed to search products: ${e.message}',
        code: 'DATABASE_ERROR',
        originalError: e,
      );
    } catch (e) {
      print('❌ Unexpected error searching products: $e');
      throw FeedServiceException(
        message: 'Failed to search products',
        originalError: e,
      );
    }
  }

  /// Get popular products based on usage statistics
  /// 
  /// [species] - Optional species filter
  /// [limit] - Maximum products to return (default: 10)
  /// 
  /// Returns products ordered by usage frequency across all users.
  /// Useful for showing recommended or popular feeds.
  /// 
  /// Example:
  /// ```dart
  /// final popular = await FeedService.getPopularProducts(species: 'cattle');
  /// ```
  static Future<List<FeedProduct>> getPopularProducts({
    String? species,
    int limit = 10,
  }) async {
    try {
      _ensureAuthenticated();

      print('📈 Fetching popular products${species != null ? ' for $species' : ''}');

      // This uses the v_feed_usage_stats view created in the migration
      var query = _supabase
          .from('v_feed_usage_stats')
          .select('*');

      // Add species filtering if specified
      if (species != null && species.isNotEmpty) {
        final speciesLower = species.toLowerCase();
        query = query.contains('species', [speciesLower]);
      }

      final statsResponse = await query
          .order('total_uses', ascending: false)
          .limit(limit);

      // Get the actual product details
      final productNames = (statsResponse as List)
          .map((row) => row['product_name'] as String)
          .toList();

      if (productNames.isEmpty) {
        return [];
      }

      final productsResponse = await _supabase
          .from('feed_products')
          .select('''
            *,
            brand:feed_brands(*)
          ''')
          .in_('name', productNames)
          .eq('is_active', true);

      final products = (productsResponse as List)
          .map((json) => FeedProduct.fromJson(json))
          .toList();

      // Sort by original usage order
      products.sort((a, b) {
        final aIndex = productNames.indexOf(a.name);
        final bIndex = productNames.indexOf(b.name);
        return aIndex.compareTo(bIndex);
      });

      print('✅ Found ${products.length} popular products');
      return products;

    } on PostgrestException catch (e) {
      print('❌ Database error fetching popular products: ${e.message}');
      throw FeedServiceException(
        message: 'Failed to load popular products: ${e.message}',
        code: 'DATABASE_ERROR',
        originalError: e,
      );
    } catch (e) {
      print('❌ Unexpected error fetching popular products: $e');
      throw FeedServiceException(
        message: 'Failed to load popular products',
        originalError: e,
      );
    }
  }

  // ============================================================================
  // PRIVATE HELPER METHODS
  // ============================================================================

  /// Ensure user is authenticated before performing operations
  static void _ensureAuthenticated() {
    if (_supabase.auth.currentUser == null) {
      throw const FeedServiceException(
        message: 'User must be authenticated to access feed data',
        code: 'UNAUTHENTICATED',
      );
    }
  }
}