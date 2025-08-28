import 'package:flutter/material.dart';

/// Expense model for tracking financial transactions
class Expense {
  final String? id;
  final String userId;
  final String title;
  final String description;
  final double amount;
  final DateTime date;
  final String category;
  final String? animalId;
  final String? projectId;
  final String? vendorName;
  final String? receiptUrl;
  final List<String>? tags;
  final String paymentMethod;
  final bool isRecurring;
  final String? recurringFrequency;
  final DateTime? nextDueDate;
  final bool isPaid;
  final DateTime? paidDate;
  final String? notes;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  
  // Integration fields
  final String? journalEntryId; // Link to related journal entry
  final String? invoiceNumber;
  final double? taxAmount;
  final String? budgetCategory;
  
  Expense({
    this.id,
    required this.userId,
    required this.title,
    required this.description,
    required this.amount,
    required this.date,
    required this.category,
    this.animalId,
    this.projectId,
    this.vendorName,
    this.receiptUrl,
    this.tags,
    this.paymentMethod = 'cash',
    this.isRecurring = false,
    this.recurringFrequency,
    this.nextDueDate,
    this.isPaid = true,
    this.paidDate,
    this.notes,
    this.createdAt,
    this.updatedAt,
    this.journalEntryId,
    this.invoiceNumber,
    this.taxAmount,
    this.budgetCategory,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'user_id': userId,
    'title': title,
    'description': description,
    'amount': amount,
    'date': date.toIso8601String(),
    'category': category,
    'animal_id': animalId,
    'project_id': projectId,
    'vendor_name': vendorName,
    'receipt_url': receiptUrl,
    'tags': tags,
    'payment_method': paymentMethod,
    'is_recurring': isRecurring,
    'recurring_frequency': recurringFrequency,
    'next_due_date': nextDueDate?.toIso8601String(),
    'is_paid': isPaid,
    'paid_date': paidDate?.toIso8601String(),
    'notes': notes,
    'created_at': createdAt?.toIso8601String(),
    'updated_at': updatedAt?.toIso8601String(),
    'journal_entry_id': journalEntryId,
    'invoice_number': invoiceNumber,
    'tax_amount': taxAmount,
    'budget_category': budgetCategory,
  };

  factory Expense.fromJson(Map<String, dynamic> json) => Expense(
    id: json['id'],
    userId: json['user_id'],
    title: json['title'],
    description: json['description'],
    amount: (json['amount'] ?? 0).toDouble(),
    date: DateTime.parse(json['date']),
    category: json['category'],
    animalId: json['animal_id'],
    projectId: json['project_id'],
    vendorName: json['vendor_name'],
    receiptUrl: json['receipt_url'],
    tags: json['tags'] != null ? List<String>.from(json['tags']) : null,
    paymentMethod: json['payment_method'] ?? 'cash',
    isRecurring: json['is_recurring'] ?? false,
    recurringFrequency: json['recurring_frequency'],
    nextDueDate: json['next_due_date'] != null 
        ? DateTime.parse(json['next_due_date']) 
        : null,
    isPaid: json['is_paid'] ?? true,
    paidDate: json['paid_date'] != null 
        ? DateTime.parse(json['paid_date']) 
        : null,
    notes: json['notes'],
    createdAt: json['created_at'] != null 
        ? DateTime.parse(json['created_at']) 
        : null,
    updatedAt: json['updated_at'] != null 
        ? DateTime.parse(json['updated_at']) 
        : null,
    journalEntryId: json['journal_entry_id'],
    invoiceNumber: json['invoice_number'],
    taxAmount: json['tax_amount']?.toDouble(),
    budgetCategory: json['budget_category'],
  );

  Expense copyWith({
    String? id,
    String? userId,
    String? title,
    String? description,
    double? amount,
    DateTime? date,
    String? category,
    String? animalId,
    String? projectId,
    String? vendorName,
    String? receiptUrl,
    List<String>? tags,
    String? paymentMethod,
    bool? isRecurring,
    String? recurringFrequency,
    DateTime? nextDueDate,
    bool? isPaid,
    DateTime? paidDate,
    String? notes,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? journalEntryId,
    String? invoiceNumber,
    double? taxAmount,
    String? budgetCategory,
  }) {
    return Expense(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      title: title ?? this.title,
      description: description ?? this.description,
      amount: amount ?? this.amount,
      date: date ?? this.date,
      category: category ?? this.category,
      animalId: animalId ?? this.animalId,
      projectId: projectId ?? this.projectId,
      vendorName: vendorName ?? this.vendorName,
      receiptUrl: receiptUrl ?? this.receiptUrl,
      tags: tags ?? this.tags,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      isRecurring: isRecurring ?? this.isRecurring,
      recurringFrequency: recurringFrequency ?? this.recurringFrequency,
      nextDueDate: nextDueDate ?? this.nextDueDate,
      isPaid: isPaid ?? this.isPaid,
      paidDate: paidDate ?? this.paidDate,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      journalEntryId: journalEntryId ?? this.journalEntryId,
      invoiceNumber: invoiceNumber ?? this.invoiceNumber,
      taxAmount: taxAmount ?? this.taxAmount,
      budgetCategory: budgetCategory ?? this.budgetCategory,
    );
  }
}

/// Expense categories for agricultural education
class ExpenseCategories {
  static const List<String> categories = [
    'feed',
    'health_veterinary',
    'equipment',
    'transportation',
    'show_entry',
    'supplies',
    'housing',
    'breeding',
    'processing',
    'marketing',
    'utilities',
    'insurance',
    'registration',
    'training',
    'other',
  ];

  static const Map<String, String> categoryDisplayNames = {
    'feed': 'Feed & Nutrition',
    'health_veterinary': 'Health & Veterinary',
    'equipment': 'Equipment & Tools',
    'transportation': 'Transportation',
    'show_entry': 'Show Entry Fees',
    'supplies': 'General Supplies',
    'housing': 'Housing & Facilities',
    'breeding': 'Breeding Services',
    'processing': 'Processing Costs',
    'marketing': 'Marketing & Sales',
    'utilities': 'Utilities',
    'insurance': 'Insurance',
    'registration': 'Registration Fees',
    'training': 'Training & Education',
    'other': 'Other',
  };

  static const Map<String, IconData> categoryIcons = {
    'feed': Icons.grass,
    'health_veterinary': Icons.medical_services,
    'equipment': Icons.build,
    'transportation': Icons.local_shipping,
    'show_entry': Icons.emoji_events,
    'supplies': Icons.inventory,
    'housing': Icons.home,
    'breeding': Icons.pets,
    'processing': Icons.precision_manufacturing,
    'marketing': Icons.campaign,
    'utilities': Icons.bolt,
    'insurance': Icons.security,
    'registration': Icons.badge,
    'training': Icons.school,
    'other': Icons.more_horiz,
  };

  static const Map<String, Color> categoryColors = {
    'feed': Color(0xFF4CAF50),
    'health_veterinary': Color(0xFFE91E63),
    'equipment': Color(0xFF9C27B0),
    'transportation': Color(0xFF2196F3),
    'show_entry': Color(0xFFFF9800),
    'supplies': Color(0xFF795548),
    'housing': Color(0xFF607D8B),
    'breeding': Color(0xFF8BC34A),
    'processing': Color(0xFF3F51B5),
    'marketing': Color(0xFFFF5722),
    'utilities': Color(0xFFFFC107),
    'insurance': Color(0xFF00BCD4),
    'registration': Color(0xFF673AB7),
    'training': Color(0xFF009688),
    'other': Color(0xFF9E9E9E),
  };

  static String getDisplayName(String category) {
    return categoryDisplayNames[category] ?? category;
  }

  static IconData getIcon(String category) {
    return categoryIcons[category] ?? Icons.attach_money;
  }

  static Color getColor(String category) {
    return categoryColors[category] ?? const Color(0xFF757575);
  }
}

/// Payment methods
class PaymentMethods {
  static const List<String> methods = [
    'cash',
    'check',
    'credit_card',
    'debit_card',
    'bank_transfer',
    'grant',
    'scholarship',
    'fundraising',
    'sponsor',
    'other',
  ];

  static const Map<String, String> methodDisplayNames = {
    'cash': 'Cash',
    'check': 'Check',
    'credit_card': 'Credit Card',
    'debit_card': 'Debit Card',
    'bank_transfer': 'Bank Transfer',
    'grant': 'Grant/Award',
    'scholarship': 'Scholarship',
    'fundraising': 'Fundraising',
    'sponsor': 'Sponsor',
    'other': 'Other',
  };

  static String getDisplayName(String method) {
    return methodDisplayNames[method] ?? method;
  }
}