import 'feed.dart';

/// Feed inventory model for tracking stock levels
class FeedInventory {
  final String id;
  final String userId;
  final String? brandId;
  final String? productId;
  final double currentQuantity;
  final String unit;
  final double? minimumQuantity;
  final double? maximumQuantity;
  final String? storageLocation;
  final String? binNumber;
  final DateTime? lastPurchaseDate;
  final double? lastPurchasePrice;
  final double? averageCost;
  final double? totalValue;
  final String? notes;
  final DateTime createdAt;
  final DateTime updatedAt;
  
  // Related objects
  final FeedBrand? brand;
  final FeedProduct? product;

  const FeedInventory({
    required this.id,
    required this.userId,
    this.brandId,
    this.productId,
    required this.currentQuantity,
    required this.unit,
    this.minimumQuantity,
    this.maximumQuantity,
    this.storageLocation,
    this.binNumber,
    this.lastPurchaseDate,
    this.lastPurchasePrice,
    this.averageCost,
    this.totalValue,
    this.notes,
    required this.createdAt,
    required this.updatedAt,
    this.brand,
    this.product,
  });

  factory FeedInventory.fromJson(Map<String, dynamic> json) {
    return FeedInventory(
      id: json['id']?.toString() ?? '',
      userId: json['user_id']?.toString() ?? '',
      brandId: json['brand_id']?.toString(),
      productId: json['product_id']?.toString(),
      currentQuantity: (json['current_quantity'] as num?)?.toDouble() ?? 0.0,
      unit: json['unit']?.toString() ?? 'lbs',
      minimumQuantity: (json['minimum_quantity'] as num?)?.toDouble(),
      maximumQuantity: (json['maximum_quantity'] as num?)?.toDouble(),
      storageLocation: json['storage_location']?.toString(),
      binNumber: json['bin_number']?.toString(),
      lastPurchaseDate: json['last_purchase_date'] != null 
          ? DateTime.parse(json['last_purchase_date'].toString())
          : null,
      lastPurchasePrice: (json['last_purchase_price'] as num?)?.toDouble(),
      averageCost: (json['average_cost'] as num?)?.toDouble(),
      totalValue: (json['total_value'] as num?)?.toDouble(),
      notes: json['notes']?.toString(),
      createdAt: json['created_at'] != null 
          ? DateTime.parse(json['created_at'].toString())
          : DateTime.now(),
      updatedAt: json['updated_at'] != null 
          ? DateTime.parse(json['updated_at'].toString())
          : DateTime.now(),
      brand: json['brand'] != null 
          ? FeedBrand.fromJson(json['brand'] as Map<String, dynamic>)
          : null,
      product: json['product'] != null 
          ? FeedProduct.fromJson(json['product'] as Map<String, dynamic>)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'brand_id': brandId,
      'product_id': productId,
      'current_quantity': currentQuantity,
      'unit': unit,
      'minimum_quantity': minimumQuantity,
      'maximum_quantity': maximumQuantity,
      'storage_location': storageLocation,
      'bin_number': binNumber,
      'last_purchase_date': lastPurchaseDate?.toIso8601String(),
      'last_purchase_price': lastPurchasePrice,
      'average_cost': averageCost,
      'total_value': totalValue,
      'notes': notes,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      if (brand != null) 'brand': brand!.toJson(),
      if (product != null) 'product': product!.toJson(),
    };
  }

  /// Get display name for inventory item
  String get displayName {
    if (product != null) return product!.displayName;
    if (brand != null) return brand!.name;
    return 'Unknown Feed';
  }

  /// Get stock status
  StockStatus get stockStatus {
    if (minimumQuantity != null && currentQuantity <= minimumQuantity!) {
      return StockStatus.low;
    }
    if (maximumQuantity != null && currentQuantity >= maximumQuantity!) {
      return StockStatus.overstock;
    }
    return StockStatus.normal;
  }

  /// Get formatted quantity
  String get formattedQuantity => '$currentQuantity $unit';

  /// Get formatted value
  String get formattedValue => totalValue != null 
      ? '\$${totalValue!.toStringAsFixed(2)}'
      : 'N/A';

  FeedInventory copyWith({
    String? id,
    String? userId,
    String? brandId,
    String? productId,
    double? currentQuantity,
    String? unit,
    double? minimumQuantity,
    double? maximumQuantity,
    String? storageLocation,
    String? binNumber,
    DateTime? lastPurchaseDate,
    double? lastPurchasePrice,
    double? averageCost,
    double? totalValue,
    String? notes,
    DateTime? createdAt,
    DateTime? updatedAt,
    FeedBrand? brand,
    FeedProduct? product,
  }) {
    return FeedInventory(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      brandId: brandId ?? this.brandId,
      productId: productId ?? this.productId,
      currentQuantity: currentQuantity ?? this.currentQuantity,
      unit: unit ?? this.unit,
      minimumQuantity: minimumQuantity ?? this.minimumQuantity,
      maximumQuantity: maximumQuantity ?? this.maximumQuantity,
      storageLocation: storageLocation ?? this.storageLocation,
      binNumber: binNumber ?? this.binNumber,
      lastPurchaseDate: lastPurchaseDate ?? this.lastPurchaseDate,
      lastPurchasePrice: lastPurchasePrice ?? this.lastPurchasePrice,
      averageCost: averageCost ?? this.averageCost,
      totalValue: totalValue ?? this.totalValue,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      brand: brand ?? this.brand,
      product: product ?? this.product,
    );
  }

  @override
  String toString() => 'FeedInventory(id: $id, name: $displayName, quantity: $formattedQuantity, status: $stockStatus)';

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is FeedInventory && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}

/// Stock status enumeration
enum StockStatus {
  low('Low Stock'),
  normal('Normal'),
  overstock('Overstocked');

  const StockStatus(this.displayName);
  final String displayName;
}

/// Feed purchase model
class FeedPurchase {
  final String id;
  final String userId;
  final String? inventoryId;
  final String? brandId;
  final String? productId;
  final DateTime purchaseDate;
  final double quantity;
  final String unit;
  final double unitPrice;
  final double? totalCost;
  final String? vendorName;
  final String? vendorContact;
  final String? invoiceNumber;
  final String? lotNumber;
  final DateTime? expirationDate;
  final String? notes;
  final String? receiptUrl;
  final DateTime createdAt;
  final DateTime updatedAt;
  
  // Related objects
  final FeedBrand? brand;
  final FeedProduct? product;

  const FeedPurchase({
    required this.id,
    required this.userId,
    this.inventoryId,
    this.brandId,
    this.productId,
    required this.purchaseDate,
    required this.quantity,
    required this.unit,
    required this.unitPrice,
    this.totalCost,
    this.vendorName,
    this.vendorContact,
    this.invoiceNumber,
    this.lotNumber,
    this.expirationDate,
    this.notes,
    this.receiptUrl,
    required this.createdAt,
    required this.updatedAt,
    this.brand,
    this.product,
  });

  factory FeedPurchase.fromJson(Map<String, dynamic> json) {
    return FeedPurchase(
      id: json['id']?.toString() ?? '',
      userId: json['user_id']?.toString() ?? '',
      inventoryId: json['inventory_id']?.toString(),
      brandId: json['brand_id']?.toString(),
      productId: json['product_id']?.toString(),
      purchaseDate: DateTime.parse(json['purchase_date'].toString()),
      quantity: (json['quantity'] as num).toDouble(),
      unit: json['unit']?.toString() ?? 'lbs',
      unitPrice: (json['unit_price'] as num).toDouble(),
      totalCost: (json['total_cost'] as num?)?.toDouble(),
      vendorName: json['vendor_name']?.toString(),
      vendorContact: json['vendor_contact']?.toString(),
      invoiceNumber: json['invoice_number']?.toString(),
      lotNumber: json['lot_number']?.toString(),
      expirationDate: json['expiration_date'] != null 
          ? DateTime.parse(json['expiration_date'].toString())
          : null,
      notes: json['notes']?.toString(),
      receiptUrl: json['receipt_url']?.toString(),
      createdAt: json['created_at'] != null 
          ? DateTime.parse(json['created_at'].toString())
          : DateTime.now(),
      updatedAt: json['updated_at'] != null 
          ? DateTime.parse(json['updated_at'].toString())
          : DateTime.now(),
      brand: json['brand'] != null 
          ? FeedBrand.fromJson(json['brand'] as Map<String, dynamic>)
          : null,
      product: json['product'] != null 
          ? FeedProduct.fromJson(json['product'] as Map<String, dynamic>)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'inventory_id': inventoryId,
      'brand_id': brandId,
      'product_id': productId,
      'purchase_date': purchaseDate.toIso8601String(),
      'quantity': quantity,
      'unit': unit,
      'unit_price': unitPrice,
      'total_cost': totalCost,
      'vendor_name': vendorName,
      'vendor_contact': vendorContact,
      'invoice_number': invoiceNumber,
      'lot_number': lotNumber,
      'expiration_date': expirationDate?.toIso8601String(),
      'notes': notes,
      'receipt_url': receiptUrl,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      if (brand != null) 'brand': brand!.toJson(),
      if (product != null) 'product': product!.toJson(),
    };
  }

  /// Get display name for purchase
  String get displayName {
    if (product != null) return product!.displayName;
    if (brand != null) return brand!.name;
    return 'Feed Purchase';
  }

  /// Get formatted quantity
  String get formattedQuantity => '$quantity $unit';

  /// Get formatted cost
  String get formattedCost => totalCost != null 
      ? '\$${totalCost!.toStringAsFixed(2)}'
      : '\$${(quantity * unitPrice).toStringAsFixed(2)}';

  /// Check if expired
  bool get isExpired => expirationDate != null && expirationDate!.isBefore(DateTime.now());

  /// Days until expiration
  int? get daysUntilExpiration {
    if (expirationDate == null) return null;
    final diff = expirationDate!.difference(DateTime.now());
    return diff.inDays;
  }

  @override
  String toString() => 'FeedPurchase(id: $id, name: $displayName, date: $purchaseDate, cost: $formattedCost)';

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is FeedPurchase && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}

/// Feed conversion tracking model
class FeedConversionTracking {
  final String id;
  final String userId;
  final String? animalId;
  final DateTime startDate;
  final DateTime endDate;
  final double startWeight;
  final double endWeight;
  final double? weightGain;
  final double totalFeedConsumed;
  final String feedUnit;
  final double? feedConversionRatio;
  final double? totalFeedCost;
  final double? costPerPoundGain;
  final String? notes;
  final DateTime createdAt;
  final DateTime updatedAt;

  const FeedConversionTracking({
    required this.id,
    required this.userId,
    this.animalId,
    required this.startDate,
    required this.endDate,
    required this.startWeight,
    required this.endWeight,
    this.weightGain,
    required this.totalFeedConsumed,
    required this.feedUnit,
    this.feedConversionRatio,
    this.totalFeedCost,
    this.costPerPoundGain,
    this.notes,
    required this.createdAt,
    required this.updatedAt,
  });

  factory FeedConversionTracking.fromJson(Map<String, dynamic> json) {
    return FeedConversionTracking(
      id: json['id']?.toString() ?? '',
      userId: json['user_id']?.toString() ?? '',
      animalId: json['animal_id']?.toString(),
      startDate: DateTime.parse(json['start_date'].toString()),
      endDate: DateTime.parse(json['end_date'].toString()),
      startWeight: (json['start_weight'] as num).toDouble(),
      endWeight: (json['end_weight'] as num).toDouble(),
      weightGain: (json['weight_gain'] as num?)?.toDouble(),
      totalFeedConsumed: (json['total_feed_consumed'] as num).toDouble(),
      feedUnit: json['feed_unit']?.toString() ?? 'lbs',
      feedConversionRatio: (json['feed_conversion_ratio'] as num?)?.toDouble(),
      totalFeedCost: (json['total_feed_cost'] as num?)?.toDouble(),
      costPerPoundGain: (json['cost_per_pound_gain'] as num?)?.toDouble(),
      notes: json['notes']?.toString(),
      createdAt: json['created_at'] != null 
          ? DateTime.parse(json['created_at'].toString())
          : DateTime.now(),
      updatedAt: json['updated_at'] != null 
          ? DateTime.parse(json['updated_at'].toString())
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'animal_id': animalId,
      'start_date': startDate.toIso8601String(),
      'end_date': endDate.toIso8601String(),
      'start_weight': startWeight,
      'end_weight': endWeight,
      'weight_gain': weightGain,
      'total_feed_consumed': totalFeedConsumed,
      'feed_unit': feedUnit,
      'feed_conversion_ratio': feedConversionRatio,
      'total_feed_cost': totalFeedCost,
      'cost_per_pound_gain': costPerPoundGain,
      'notes': notes,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  /// Get tracking period in days
  int get periodDays => endDate.difference(startDate).inDays;

  /// Get FCR rating
  FCRRating get fcrRating {
    if (feedConversionRatio == null) return FCRRating.unknown;
    if (feedConversionRatio! < 3.0) return FCRRating.excellent;
    if (feedConversionRatio! < 4.0) return FCRRating.good;
    if (feedConversionRatio! < 5.0) return FCRRating.average;
    return FCRRating.needsImprovement;
  }

  /// Get formatted FCR
  String get formattedFCR => feedConversionRatio != null 
      ? '${feedConversionRatio!.toStringAsFixed(2)}:1'
      : 'N/A';

  /// Get formatted cost per pound
  String get formattedCostPerPound => costPerPoundGain != null 
      ? '\$${costPerPoundGain!.toStringAsFixed(2)}/lb'
      : 'N/A';

  @override
  String toString() => 'FeedConversionTracking(id: $id, FCR: $formattedFCR, rating: ${fcrRating.displayName})';

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is FeedConversionTracking && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}

/// FCR rating enumeration
enum FCRRating {
  excellent('Excellent'),
  good('Good'),
  average('Average'),
  needsImprovement('Needs Improvement'),
  unknown('Unknown');

  const FCRRating(this.displayName);
  final String displayName;
}

/// FCR performance model
class FCRPerformance {
  final String userId;
  final String? animalName;
  final String? species;
  final DateTime startDate;
  final DateTime endDate;
  final double weightGain;
  final double totalFeedConsumed;
  final double? feedConversionRatio;
  final double? costPerPoundGain;
  final String fcrRating;

  const FCRPerformance({
    required this.userId,
    this.animalName,
    this.species,
    required this.startDate,
    required this.endDate,
    required this.weightGain,
    required this.totalFeedConsumed,
    this.feedConversionRatio,
    this.costPerPoundGain,
    required this.fcrRating,
  });

  factory FCRPerformance.fromJson(Map<String, dynamic> json) {
    return FCRPerformance(
      userId: json['user_id']?.toString() ?? '',
      animalName: json['animal_name']?.toString(),
      species: json['species']?.toString(),
      startDate: DateTime.parse(json['start_date'].toString()),
      endDate: DateTime.parse(json['end_date'].toString()),
      weightGain: (json['weight_gain'] as num).toDouble(),
      totalFeedConsumed: (json['total_feed_consumed'] as num).toDouble(),
      feedConversionRatio: (json['feed_conversion_ratio'] as num?)?.toDouble(),
      costPerPoundGain: (json['cost_per_pound_gain'] as num?)?.toDouble(),
      fcrRating: json['fcr_rating']?.toString() ?? 'Unknown',
    );
  }

  /// Get formatted FCR
  String get formattedFCR => feedConversionRatio != null 
      ? '${feedConversionRatio!.toStringAsFixed(2)}:1'
      : 'N/A';

  /// Get formatted cost per pound
  String get formattedCostPerPound => costPerPoundGain != null 
      ? '\$${costPerPoundGain!.toStringAsFixed(2)}/lb'
      : 'N/A';

  @override
  String toString() => 'FCRPerformance(animal: $animalName, FCR: $formattedFCR, rating: $fcrRating)';
}