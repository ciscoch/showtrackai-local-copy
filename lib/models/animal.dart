import 'package:flutter/foundation.dart';

enum AnimalSpecies {
  cattle,
  swine,
  sheep,
  goat,
  poultry,
  rabbit,
  other,
}

enum AnimalGender {
  male,
  female,
  steer,
  heifer,
  barrow,
  gilt,
  wether,
  doe,
  buck,
  ewe,
  ram,
}

@immutable
class Animal {
  final String? id;
  final String userId;
  final String name;
  final String? tag;
  final AnimalSpecies species;
  final String? breed;
  final AnimalGender? gender;
  final DateTime? birthDate;
  final double? purchaseWeight;
  final double? currentWeight;
  final DateTime? purchaseDate;
  final double? purchasePrice;
  final String? description;
  final String? photoUrl;
  final Map<String, dynamic>? metadata;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  
  const Animal({
    this.id,
    required this.userId,
    required this.name,
    this.tag,
    required this.species,
    this.breed,
    this.gender,
    this.birthDate,
    this.purchaseWeight,
    this.currentWeight,
    this.purchaseDate,
    this.purchasePrice,
    this.description,
    this.photoUrl,
    this.metadata,
    this.createdAt,
    this.updatedAt,
  });
  
  // Calculate age if birthDate is provided
  int? get ageInDays {
    if (birthDate == null) return null;
    return DateTime.now().difference(birthDate!).inDays;
  }
  
  int? get ageInMonths {
    final days = ageInDays;
    if (days == null) return null;
    return (days / 30).floor();
  }
  
  // Weight gain calculations
  double? get totalWeightGain {
    if (purchaseWeight == null || currentWeight == null) return null;
    return currentWeight! - purchaseWeight!;
  }
  
  double? get averageDailyGain {
    if (purchaseDate == null || totalWeightGain == null) return null;
    final daysOwned = DateTime.now().difference(purchaseDate!).inDays;
    if (daysOwned <= 0) return null;
    return totalWeightGain! / daysOwned;
  }
  
  // Species-specific helpers
  String get speciesDisplay {
    switch (species) {
      case AnimalSpecies.cattle:
        return 'Cattle';
      case AnimalSpecies.swine:
        return 'Swine';
      case AnimalSpecies.sheep:
        return 'Sheep';
      case AnimalSpecies.goat:
        return 'Goat';
      case AnimalSpecies.poultry:
        return 'Poultry';
      case AnimalSpecies.rabbit:
        return 'Rabbit';
      case AnimalSpecies.other:
        return 'Other';
    }
  }
  
  String get genderDisplay {
    if (gender == null) return 'Unknown';
    switch (gender!) {
      case AnimalGender.male:
        return 'Male';
      case AnimalGender.female:
        return 'Female';
      case AnimalGender.steer:
        return 'Steer';
      case AnimalGender.heifer:
        return 'Heifer';
      case AnimalGender.barrow:
        return 'Barrow';
      case AnimalGender.gilt:
        return 'Gilt';
      case AnimalGender.wether:
        return 'Wether';
      case AnimalGender.doe:
        return 'Doe';
      case AnimalGender.buck:
        return 'Buck';
      case AnimalGender.ewe:
        return 'Ewe';
      case AnimalGender.ram:
        return 'Ram';
    }
  }
  
  // Create from JSON (Supabase)
  factory Animal.fromJson(Map<String, dynamic> json) {
    return Animal(
      id: json['id']?.toString(),
      userId: json['user_id'] ?? '',
      name: json['name'] ?? '',
      tag: json['tag'],
      species: AnimalSpecies.values.firstWhere(
        (s) => s.name == json['species'],
        orElse: () => AnimalSpecies.other,
      ),
      breed: json['breed'],
      gender: json['gender'] != null
          ? AnimalGender.values.firstWhere(
              (g) => g.name == json['gender'],
              orElse: () => AnimalGender.male,
            )
          : null,
      birthDate: json['birth_date'] != null
          ? DateTime.parse(json['birth_date'])
          : null,
      purchaseWeight: json['purchase_weight']?.toDouble(),
      currentWeight: json['current_weight']?.toDouble(),
      purchaseDate: json['purchase_date'] != null
          ? DateTime.parse(json['purchase_date'])
          : null,
      purchasePrice: json['purchase_price']?.toDouble(),
      description: json['description'],
      photoUrl: json['photo_url'],
      metadata: json['metadata'] as Map<String, dynamic>?,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'])
          : null,
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'])
          : null,
    );
  }
  
  // Convert to JSON for Supabase
  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      'user_id': userId,
      'name': name,
      'tag': tag,
      'species': species.name,
      'breed': breed,
      'gender': gender?.name,
      'birth_date': birthDate?.toIso8601String(),
      'purchase_weight': purchaseWeight,
      'current_weight': currentWeight,
      'purchase_date': purchaseDate?.toIso8601String(),
      'purchase_price': purchasePrice,
      'description': description,
      'photo_url': photoUrl,
      'metadata': metadata,
      'created_at': createdAt?.toIso8601String() ?? DateTime.now().toIso8601String(),
      'updated_at': DateTime.now().toIso8601String(),
    };
  }
  
  // Create a copy with updated fields
  Animal copyWith({
    String? id,
    String? userId,
    String? name,
    String? tag,
    AnimalSpecies? species,
    String? breed,
    AnimalGender? gender,
    DateTime? birthDate,
    double? purchaseWeight,
    double? currentWeight,
    DateTime? purchaseDate,
    double? purchasePrice,
    String? description,
    String? photoUrl,
    Map<String, dynamic>? metadata,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Animal(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      name: name ?? this.name,
      tag: tag ?? this.tag,
      species: species ?? this.species,
      breed: breed ?? this.breed,
      gender: gender ?? this.gender,
      birthDate: birthDate ?? this.birthDate,
      purchaseWeight: purchaseWeight ?? this.purchaseWeight,
      currentWeight: currentWeight ?? this.currentWeight,
      purchaseDate: purchaseDate ?? this.purchaseDate,
      purchasePrice: purchasePrice ?? this.purchasePrice,
      description: description ?? this.description,
      photoUrl: photoUrl ?? this.photoUrl,
      metadata: metadata ?? this.metadata,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
  
  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Animal &&
        other.id == id &&
        other.userId == userId &&
        other.name == name &&
        other.tag == tag &&
        other.species == species;
  }
  
  @override
  int get hashCode {
    return id.hashCode ^
        userId.hashCode ^
        name.hashCode ^
        tag.hashCode ^
        species.hashCode;
  }
}