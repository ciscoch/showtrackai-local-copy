/// Feed cost analytics model
class FeedCostAnalytics {
  final String userId;
  final List<MonthlyFeedCost> monthlyData;
  final double totalCost;
  final double averageMonthlyCost;
  final Map<String, double> costByBrand;
  final Map<String, double> costByType;
  final String? topBrand;
  final String? topProduct;
  
  /// Monthly trends for chart display
  List<Map<String, dynamic>> get monthlyTrends {
    return monthlyData.map((data) => {
      'month': data.month.toIso8601String().substring(0, 7), // YYYY-MM format
      'total_cost': data.totalCost,
      'total_quantity': data.totalQuantity,
      'purchase_count': data.purchaseCount,
    }).toList();
  }

  FeedCostAnalytics({
    required this.userId,
    required this.monthlyData,
    required this.totalCost,
    required this.averageMonthlyCost,
    required this.costByBrand,
    required this.costByType,
    this.topBrand,
    this.topProduct,
  });

  factory FeedCostAnalytics.fromJson(Map<String, dynamic> json) {
    final data = (json['data'] as List?) ?? [];
    
    // Process monthly data
    final monthlyData = data
        .map((item) => MonthlyFeedCost.fromJson(item as Map<String, dynamic>))
        .toList();
    
    // Calculate totals
    double totalCost = 0.0;
    Map<String, double> costByBrand = {};
    Map<String, double> costByType = {};
    
    for (final item in data) {
      final cost = (item['total_cost'] as num?)?.toDouble() ?? 0.0;
      totalCost += cost;
      
      final brandName = item['brand_name']?.toString() ?? 'Unknown';
      costByBrand[brandName] = (costByBrand[brandName] ?? 0.0) + cost;
      
      final feedType = item['feed_type']?.toString() ?? 'Unknown';
      costByType[feedType] = (costByType[feedType] ?? 0.0) + cost;
    }
    
    // Find top brand and product
    String? topBrand;
    String? topProduct;
    double maxBrandCost = 0.0;
    double maxProductCost = 0.0;
    
    costByBrand.forEach((brand, cost) {
      if (cost > maxBrandCost) {
        maxBrandCost = cost;
        topBrand = brand;
      }
    });
    
    // Find top product from data
    Map<String, double> productCosts = {};
    for (final item in data) {
      final productName = item['product_name']?.toString();
      if (productName != null) {
        final cost = (item['total_cost'] as num?)?.toDouble() ?? 0.0;
        productCosts[productName] = (productCosts[productName] ?? 0.0) + cost;
      }
    }
    
    productCosts.forEach((product, cost) {
      if (cost > maxProductCost) {
        maxProductCost = cost;
        topProduct = product;
      }
    });
    
    final monthCount = monthlyData.isNotEmpty ? monthlyData.length : 1;
    
    return FeedCostAnalytics(
      userId: json['user_id']?.toString() ?? '',
      monthlyData: monthlyData,
      totalCost: totalCost,
      averageMonthlyCost: totalCost / monthCount,
      costByBrand: costByBrand,
      costByType: costByType,
      topBrand: topBrand,
      topProduct: topProduct,
    );
  }

  /// Get cost trend (positive = increasing, negative = decreasing)
  double get costTrend {
    if (monthlyData.length < 2) return 0.0;
    
    final recent = monthlyData.take(3).map((m) => m.totalCost).reduce((a, b) => a + b) / 3;
    final previous = monthlyData.skip(3).take(3).map((m) => m.totalCost).reduce((a, b) => a + b) / 3;
    
    return ((recent - previous) / previous) * 100;
  }

  /// Get formatted total cost
  String get formattedTotalCost => '\$${totalCost.toStringAsFixed(2)}';

  /// Get formatted average monthly cost
  String get formattedAverageCost => '\$${averageMonthlyCost.toStringAsFixed(2)}/month';

  /// Get cost breakdown by percentage
  Map<String, double> getCostBreakdownPercentage() {
    if (totalCost == 0) return {};
    
    Map<String, double> percentages = {};
    costByBrand.forEach((brand, cost) {
      percentages[brand] = (cost / totalCost) * 100;
    });
    
    return percentages;
  }
}

/// Monthly feed cost data
class MonthlyFeedCost {
  final DateTime month;
  final String? brandName;
  final String? productName;
  final String? feedType;
  final double totalQuantity;
  final double totalCost;
  final double avgUnitPrice;
  final int purchaseCount;

  const MonthlyFeedCost({
    required this.month,
    this.brandName,
    this.productName,
    this.feedType,
    required this.totalQuantity,
    required this.totalCost,
    required this.avgUnitPrice,
    required this.purchaseCount,
  });

  factory MonthlyFeedCost.fromJson(Map<String, dynamic> json) {
    return MonthlyFeedCost(
      month: DateTime.parse(json['month'].toString()),
      brandName: json['brand_name']?.toString(),
      productName: json['product_name']?.toString(),
      feedType: json['feed_type']?.toString(),
      totalQuantity: (json['total_quantity'] as num?)?.toDouble() ?? 0.0,
      totalCost: (json['total_cost'] as num?)?.toDouble() ?? 0.0,
      avgUnitPrice: (json['avg_unit_price'] as num?)?.toDouble() ?? 0.0,
      purchaseCount: (json['purchase_count'] as num?)?.toInt() ?? 0,
    );
  }

  /// Get formatted month
  String get formattedMonth {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 
                    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${months[month.month - 1]} ${month.year}';
  }

  /// Get formatted cost
  String get formattedCost => '\$${totalCost.toStringAsFixed(2)}';

  /// Get cost per unit
  double get costPerUnit => totalQuantity > 0 ? totalCost / totalQuantity : 0.0;
}

/// Feed efficiency metrics
class FeedEfficiencyMetrics {
  final double avgFCR;
  final double bestFCR;
  final double worstFCR;
  final double avgCostPerPound;
  final int totalAnimalsTracked;
  final double totalWeightGain;
  final double totalFeedUsed;
  final Map<String, double> fcrBySpecies;
  final List<String> topPerformers;
  final List<String> needsImprovement;

  const FeedEfficiencyMetrics({
    required this.avgFCR,
    required this.bestFCR,
    required this.worstFCR,
    required this.avgCostPerPound,
    required this.totalAnimalsTracked,
    required this.totalWeightGain,
    required this.totalFeedUsed,
    required this.fcrBySpecies,
    required this.topPerformers,
    required this.needsImprovement,
  });

  factory FeedEfficiencyMetrics.fromPerformanceData(List<Map<String, dynamic>> data) {
    if (data.isEmpty) {
      return const FeedEfficiencyMetrics(
        avgFCR: 0.0,
        bestFCR: 0.0,
        worstFCR: 0.0,
        avgCostPerPound: 0.0,
        totalAnimalsTracked: 0,
        totalWeightGain: 0.0,
        totalFeedUsed: 0.0,
        fcrBySpecies: {},
        topPerformers: [],
        needsImprovement: [],
      );
    }

    // Calculate metrics
    double totalFCR = 0.0;
    double bestFCR = double.infinity;
    double worstFCR = 0.0;
    double totalCost = 0.0;
    double totalWeightGain = 0.0;
    double totalFeedUsed = 0.0;
    Map<String, List<double>> fcrBySpeciesData = {};
    List<String> topPerformers = [];
    List<String> needsImprovement = [];
    Set<String> uniqueAnimals = {};

    for (final item in data) {
      final fcr = (item['feed_conversion_ratio'] as num?)?.toDouble();
      final weightGain = (item['weight_gain'] as num?)?.toDouble() ?? 0.0;
      final feedConsumed = (item['total_feed_consumed'] as num?)?.toDouble() ?? 0.0;
      final costPerPound = (item['cost_per_pound_gain'] as num?)?.toDouble() ?? 0.0;
      final animalName = item['animal_name']?.toString() ?? 'Unknown';
      final species = item['species']?.toString() ?? 'Unknown';
      final rating = item['fcr_rating']?.toString() ?? 'Unknown';

      if (fcr != null) {
        totalFCR += fcr;
        if (fcr < bestFCR) bestFCR = fcr;
        if (fcr > worstFCR) worstFCR = fcr;

        // Track by species
        if (!fcrBySpeciesData.containsKey(species)) {
          fcrBySpeciesData[species] = [];
        }
        fcrBySpeciesData[species]!.add(fcr);

        // Track performers
        if (rating == 'Excellent' || rating == 'Good') {
          topPerformers.add(animalName);
        } else if (rating == 'Needs Improvement') {
          needsImprovement.add(animalName);
        }
      }

      totalWeightGain += weightGain;
      totalFeedUsed += feedConsumed;
      totalCost += costPerPound * weightGain;
      uniqueAnimals.add(animalName);
    }

    // Calculate averages
    final avgFCR = data.isNotEmpty ? totalFCR / data.length : 0.0;
    final avgCostPerPound = totalWeightGain > 0 ? totalCost / totalWeightGain : 0.0;

    // Calculate average FCR by species
    Map<String, double> fcrBySpecies = {};
    fcrBySpeciesData.forEach((species, fcrList) {
      if (fcrList.isNotEmpty) {
        fcrBySpecies[species] = fcrList.reduce((a, b) => a + b) / fcrList.length;
      }
    });

    return FeedEfficiencyMetrics(
      avgFCR: avgFCR,
      bestFCR: bestFCR == double.infinity ? 0.0 : bestFCR,
      worstFCR: worstFCR,
      avgCostPerPound: avgCostPerPound,
      totalAnimalsTracked: uniqueAnimals.length,
      totalWeightGain: totalWeightGain,
      totalFeedUsed: totalFeedUsed,
      fcrBySpecies: fcrBySpecies,
      topPerformers: topPerformers.take(5).toList(),
      needsImprovement: needsImprovement.take(5).toList(),
    );
  }

  /// Get formatted average FCR
  String get formattedAvgFCR => '${avgFCR.toStringAsFixed(2)}:1';

  /// Get formatted best FCR
  String get formattedBestFCR => '${bestFCR.toStringAsFixed(2)}:1';

  /// Get formatted worst FCR
  String get formattedWorstFCR => '${worstFCR.toStringAsFixed(2)}:1';

  /// Get formatted average cost per pound
  String get formattedAvgCostPerPound => '\$${avgCostPerPound.toStringAsFixed(2)}/lb';

  /// Get overall efficiency rating
  String get overallEfficiencyRating {
    if (avgFCR == 0.0) return 'No Data';
    if (avgFCR < 3.0) return 'Excellent';
    if (avgFCR < 4.0) return 'Good';
    if (avgFCR < 5.0) return 'Average';
    return 'Needs Improvement';
  }

  /// Get feed efficiency percentage (compared to industry standard)
  double getEfficiencyPercentage(double industryStandard) {
    if (avgFCR == 0.0 || industryStandard == 0.0) return 0.0;
    return ((industryStandard - avgFCR) / industryStandard) * 100;
  }
}

/// Inventory valuation model
class InventoryValuation {
  final double totalValue;
  final int totalItems;
  final int lowStockItems;
  final int overstockItems;
  final Map<String, double> valueByBrand;
  final Map<String, double> valueByType;
  final double averageItemValue;
  final double projectedMonthlyUsage;

  const InventoryValuation({
    required this.totalValue,
    required this.totalItems,
    required this.lowStockItems,
    required this.overstockItems,
    required this.valueByBrand,
    required this.valueByType,
    required this.averageItemValue,
    required this.projectedMonthlyUsage,
  });

  factory InventoryValuation.fromInventoryData(List<Map<String, dynamic>> data) {
    if (data.isEmpty) {
      return const InventoryValuation(
        totalValue: 0.0,
        totalItems: 0,
        lowStockItems: 0,
        overstockItems: 0,
        valueByBrand: {},
        valueByType: {},
        averageItemValue: 0.0,
        projectedMonthlyUsage: 0.0,
      );
    }

    double totalValue = 0.0;
    int lowStockItems = 0;
    int overstockItems = 0;
    Map<String, double> valueByBrand = {};
    Map<String, double> valueByType = {};

    for (final item in data) {
      final value = (item['total_value'] as num?)?.toDouble() ?? 0.0;
      final stockStatus = item['stock_status']?.toString() ?? 'Normal';
      final brandName = item['brand_name']?.toString() ?? 'Unknown';
      
      totalValue += value;
      
      if (stockStatus == 'Low Stock') lowStockItems++;
      if (stockStatus == 'Overstocked') overstockItems++;
      
      valueByBrand[brandName] = (valueByBrand[brandName] ?? 0.0) + value;
      
      // Note: Type information might need to be joined from products table
      // For now, using a placeholder
      valueByType['feed'] = (valueByType['feed'] ?? 0.0) + value;
    }

    final averageItemValue = data.isNotEmpty ? totalValue / data.length : 0.0;
    
    // Calculate projected monthly usage based on average consumption
    // This would need historical data to be accurate
    final projectedMonthlyUsage = totalValue * 0.3; // Placeholder: assume 30% monthly usage

    return InventoryValuation(
      totalValue: totalValue,
      totalItems: data.length,
      lowStockItems: lowStockItems,
      overstockItems: overstockItems,
      valueByBrand: valueByBrand,
      valueByType: valueByType,
      averageItemValue: averageItemValue,
      projectedMonthlyUsage: projectedMonthlyUsage,
    );
  }

  /// Get formatted total value
  String get formattedTotalValue => '\$${totalValue.toStringAsFixed(2)}';

  /// Get formatted average item value
  String get formattedAverageValue => '\$${averageItemValue.toStringAsFixed(2)}';

  /// Get formatted projected monthly usage
  String get formattedMonthlyUsage => '\$${projectedMonthlyUsage.toStringAsFixed(2)}/month';

  /// Get inventory health status
  String get healthStatus {
    if (lowStockItems > totalItems * 0.3) return 'Critical - Many Low Stock Items';
    if (overstockItems > totalItems * 0.3) return 'Warning - Overstocked';
    if (lowStockItems > 0) return 'Attention - Some Low Stock';
    return 'Healthy';
  }

  /// Get months of inventory on hand
  double get monthsOnHand {
    if (projectedMonthlyUsage == 0) return 0.0;
    return totalValue / projectedMonthlyUsage;
  }
}