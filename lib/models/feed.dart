import 'package:uuid/uuid.dart';

/// Feed brand model for livestock feeds
class FeedBrand {
  final String id;
  final String name;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;

  const FeedBrand({
    required this.id,
    required this.name,
    this.isActive = true,
    required this.createdAt,
    required this.updatedAt,
  });

  factory FeedBrand.fromJson(Map<String, dynamic> json) {
    final id = json['id']?.toString() ?? '';
    final name = json['name']?.toString() ?? '';
    
    // Validate required fields
    if (id.isEmpty) {
      throw ArgumentError('FeedBrand id cannot be empty');
    }
    if (name.isEmpty) {
      throw ArgumentError('FeedBrand name cannot be empty');
    }
    
    return FeedBrand(
      id: id,
      name: name,
      isActive: json['is_active'] as bool? ?? true,
      createdAt: json['created_at'] != null ? DateTime.parse(json['created_at'].toString()) : DateTime.now(),
      updatedAt: json['updated_at'] != null ? DateTime.parse(json['updated_at'].toString()) : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'is_active': isActive,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  FeedBrand copyWith({
    String? id,
    String? name,
    bool? isActive,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return FeedBrand(
      id: id ?? this.id,
      name: name ?? this.name,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  String toString() => 'FeedBrand(id: $id, name: $name, isActive: $isActive)';

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is FeedBrand && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}

/// Feed product model for specific feed products
class FeedProduct {
  final String id;
  final String brandId;
  final String name;
  final List<String> species;
  final FeedType type;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;
  
  // Optional brand info (populated when joined)
  final FeedBrand? brand;

  const FeedProduct({
    required this.id,
    required this.brandId,
    required this.name,
    required this.species,
    required this.type,
    this.isActive = true,
    required this.createdAt,
    required this.updatedAt,
    this.brand,
  });

  factory FeedProduct.fromJson(Map<String, dynamic> json) {
    final id = json['id']?.toString() ?? '';
    final brandId = json['brand_id']?.toString() ?? '';
    final name = json['name']?.toString() ?? '';
    
    // Validate required fields
    if (id.isEmpty) {
      throw ArgumentError('FeedProduct id cannot be empty');
    }
    if (brandId.isEmpty) {
      throw ArgumentError('FeedProduct brandId cannot be empty');
    }
    if (name.isEmpty) {
      throw ArgumentError('FeedProduct name cannot be empty');
    }
    
    return FeedProduct(
      id: id,
      brandId: brandId,
      name: name,
      species: json['species'] != null 
          ? List<String>.from((json['species'] as List).map((e) => e?.toString() ?? '').where((s) => s.isNotEmpty))
          : [],
      type: FeedType.fromString(json['type']?.toString()),
      isActive: json['is_active'] as bool? ?? true,
      createdAt: json['created_at'] != null ? DateTime.parse(json['created_at'].toString()) : DateTime.now(),
      updatedAt: json['updated_at'] != null ? DateTime.parse(json['updated_at'].toString()) : DateTime.now(),
      brand: json['brand'] != null 
          ? FeedBrand.fromJson(json['brand'] as Map<String, dynamic>)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'brand_id': brandId,
      'name': name,
      'species': species,
      'type': type.value,
      'is_active': isActive,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      if (brand != null) 'brand': brand!.toJson(),
    };
  }

  FeedProduct copyWith({
    String? id,
    String? brandId,
    String? name,
    List<String>? species,
    FeedType? type,
    bool? isActive,
    DateTime? createdAt,
    DateTime? updatedAt,
    FeedBrand? brand,
  }) {
    return FeedProduct(
      id: id ?? this.id,
      brandId: brandId ?? this.brandId,
      name: name ?? this.name,
      species: species ?? this.species,
      type: type ?? this.type,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      brand: brand ?? this.brand,
    );
  }

  /// Get display name with brand
  String get displayName => brand != null ? '${brand!.name} $name' : name;

  /// Check if this product is suitable for a specific species
  bool isForSpecies(String speciesName) {
    return species.contains(speciesName.toLowerCase());
  }

  @override
  String toString() => 'FeedProduct(id: $id, name: $name, brand: ${brand?.name}, type: $type)';

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is FeedProduct && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}

/// Feed type enumeration
enum FeedType {
  feed('feed'),
  mineral('mineral'),
  supplement('supplement');

  const FeedType(this.value);

  final String value;

  static FeedType fromString(String? value) {
    if (value == null || value.isEmpty) {
      return FeedType.feed; // Default fallback
    }
    
    switch (value.toLowerCase()) {
      case 'feed':
        return FeedType.feed;
      case 'mineral':
        return FeedType.mineral;
      case 'supplement':
        return FeedType.supplement;
      default:
        return FeedType.feed; // Default fallback instead of throwing
    }
  }

  String get displayName {
    switch (this) {
      case FeedType.feed:
        return 'Feed';
      case FeedType.mineral:
        return 'Mineral';
      case FeedType.supplement:
        return 'Supplement';
    }
  }

  @override
  String toString() => displayName;
}

/// Feed unit enumeration
enum FeedUnit {
  lbs('lbs'),
  flakes('flakes'),
  bags('bags'),
  scoops('scoops');

  const FeedUnit(this.value);

  final String value;

  static FeedUnit fromString(String? value) {
    if (value == null || value.isEmpty) {
      return FeedUnit.lbs; // Default fallback
    }
    
    switch (value.toLowerCase()) {
      case 'lbs':
        return FeedUnit.lbs;
      case 'flakes':
        return FeedUnit.flakes;
      case 'bags':
        return FeedUnit.bags;
      case 'scoops':
        return FeedUnit.scoops;
      default:
        return FeedUnit.lbs; // Default fallback instead of throwing
    }
  }

  String get displayName {
    switch (this) {
      case FeedUnit.lbs:
        return 'lbs';
      case FeedUnit.flakes:
        return 'flakes';
      case FeedUnit.bags:
        return 'bags';
      case FeedUnit.scoops:
        return 'scoops';
    }
  }

  @override
  String toString() => displayName;
}

/// Feed item model for journal entries
class FeedItem {
  final String id;
  final String entryId;
  final String? brandId;
  final String? productId;
  final bool isHay;
  final double quantity;
  final FeedUnit unit;
  final String? note;
  final DateTime createdAt;
  final String userId;
  
  // Optional related objects (populated when joined)
  final FeedBrand? brand;
  final FeedProduct? product;

  const FeedItem({
    required this.id,
    required this.entryId,
    this.brandId,
    this.productId,
    this.isHay = false,
    required this.quantity,
    this.unit = FeedUnit.lbs,
    this.note,
    required this.createdAt,
    required this.userId,
    this.brand,
    this.product,
  });

  factory FeedItem.fromJson(Map<String, dynamic> json) {
    return FeedItem(
      id: json['id']?.toString() ?? '',
      entryId: json['entry_id']?.toString() ?? '',
      brandId: json['brand_id']?.toString(),
      productId: json['product_id']?.toString(),
      isHay: json['is_hay'] as bool? ?? false,
      quantity: json['quantity'] != null ? (json['quantity'] as num).toDouble() : 0.0,
      unit: FeedUnit.fromString(json['unit']?.toString() ?? 'lbs'),
      note: json['note']?.toString(),
      createdAt: json['created_at'] != null ? DateTime.parse(json['created_at'].toString()) : DateTime.now(),
      userId: json['user_id']?.toString() ?? '',
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
      'entry_id': entryId,
      'brand_id': brandId,
      'product_id': productId,
      'is_hay': isHay,
      'quantity': quantity,
      'unit': unit.value,
      'note': note,
      'created_at': createdAt.toIso8601String(),
      'user_id': userId,
      if (brand != null) 'brand': brand!.toJson(),
      if (product != null) 'product': product!.toJson(),
    };
  }

  /// Create a new feed item (generates UUID)
  factory FeedItem.create({
    required String entryId,
    required String userId,
    String? brandId,
    String? productId,
    bool isHay = false,
    required double quantity,
    FeedUnit unit = FeedUnit.lbs,
    String? note,
  }) {
    return FeedItem(
      id: const Uuid().v4(),
      entryId: entryId,
      userId: userId,
      brandId: brandId,
      productId: productId,
      isHay: isHay,
      quantity: quantity,
      unit: unit,
      note: note,
      createdAt: DateTime.now(),
    );
  }

  FeedItem copyWith({
    String? id,
    String? entryId,
    String? brandId,
    String? productId,
    bool? isHay,
    double? quantity,
    FeedUnit? unit,
    String? note,
    DateTime? createdAt,
    String? userId,
    FeedBrand? brand,
    FeedProduct? product,
  }) {
    return FeedItem(
      id: id ?? this.id,
      entryId: entryId ?? this.entryId,
      brandId: brandId ?? this.brandId,
      productId: productId ?? this.productId,
      isHay: isHay ?? this.isHay,
      quantity: quantity ?? this.quantity,
      unit: unit ?? this.unit,
      note: note ?? this.note,
      createdAt: createdAt ?? this.createdAt,
      userId: userId ?? this.userId,
      brand: brand ?? this.brand,
      product: product ?? this.product,
    );
  }

  /// Get display name for this feed item
  String get displayName {
    if (isHay) return 'Hay';
    if (product != null) return product!.displayName;
    if (brand != null) return brand!.name;
    return 'Unknown Feed';
  }

  /// Get formatted quantity with unit
  String get formattedQuantity => '$quantity ${unit.displayName}';

  @override
  String toString() => 'FeedItem(id: $id, name: $displayName, quantity: $formattedQuantity)';

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is FeedItem && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}

/// User's recent feed configuration for "Use Last" functionality
class UserFeedRecent {
  final String id;
  final String userId;
  final String? brandId;
  final String? productId;
  final bool isHay;
  final double quantity;
  final FeedUnit unit;
  final DateTime lastUsedAt;
  final DateTime updatedAt;
  
  // Optional related objects (populated when joined)
  final FeedBrand? brand;
  final FeedProduct? product;

  const UserFeedRecent({
    required this.id,
    required this.userId,
    this.brandId,
    this.productId,
    this.isHay = false,
    required this.quantity,
    this.unit = FeedUnit.lbs,
    required this.lastUsedAt,
    required this.updatedAt,
    this.brand,
    this.product,
  });

  factory UserFeedRecent.fromJson(Map<String, dynamic> json) {
    return UserFeedRecent(
      id: json['id']?.toString() ?? '',
      userId: json['user_id']?.toString() ?? '',
      brandId: json['brand_id']?.toString(),
      productId: json['product_id']?.toString(),
      isHay: json['is_hay'] as bool? ?? false,
      quantity: json['quantity'] != null ? (json['quantity'] as num).toDouble() : 0.0,
      unit: FeedUnit.fromString(json['unit']?.toString() ?? 'lbs'),
      lastUsedAt: json['last_used_at'] != null ? DateTime.parse(json['last_used_at'].toString()) : DateTime.now(),
      updatedAt: json['updated_at'] != null ? DateTime.parse(json['updated_at'].toString()) : DateTime.now(),
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
      'is_hay': isHay,
      'quantity': quantity,
      'unit': unit.value,
      'last_used_at': lastUsedAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      if (brand != null) 'brand': brand!.toJson(),
      if (product != null) 'product': product!.toJson(),
    };
  }

  /// Create feed item from this recent configuration
  FeedItem toFeedItem({
    required String entryId,
    String? note,
  }) {
    return FeedItem.create(
      entryId: entryId,
      userId: userId,
      brandId: brandId,
      productId: productId,
      isHay: isHay,
      quantity: quantity,
      unit: unit,
      note: note,
    );
  }

  /// Get display name for this recent feed
  String get displayName {
    if (isHay) return 'Hay';
    if (product != null) return product!.displayName;
    if (brand != null) return brand!.name;
    return 'Unknown Feed';
  }

  /// Get formatted quantity with unit
  String get formattedQuantity => '$quantity ${unit.displayName}';

  UserFeedRecent copyWith({
    String? id,
    String? userId,
    String? brandId,
    String? productId,
    bool? isHay,
    double? quantity,
    FeedUnit? unit,
    DateTime? lastUsedAt,
    DateTime? updatedAt,
    FeedBrand? brand,
    FeedProduct? product,
  }) {
    return UserFeedRecent(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      brandId: brandId ?? this.brandId,
      productId: productId ?? this.productId,
      isHay: isHay ?? this.isHay,
      quantity: quantity ?? this.quantity,
      unit: unit ?? this.unit,
      lastUsedAt: lastUsedAt ?? this.lastUsedAt,
      updatedAt: updatedAt ?? this.updatedAt,
      brand: brand ?? this.brand,
      product: product ?? this.product,
    );
  }

  @override
  String toString() => 'UserFeedRecent(name: $displayName, quantity: $formattedQuantity, lastUsed: $lastUsedAt)';

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is UserFeedRecent && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}

/// Exception class for feed-related errors
class FeedServiceException implements Exception {
  final String message;
  final String? code;
  final dynamic originalError;

  const FeedServiceException({
    required this.message,
    this.code,
    this.originalError,
  });

  @override
  String toString() {
    if (code != null) {
      return 'FeedServiceException($code): $message';
    }
    return 'FeedServiceException: $message';
  }
}