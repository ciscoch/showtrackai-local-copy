import 'package:flutter/material.dart';
import 'journal_entry.dart';
import 'expense.dart';

/// Unified timeline item that can represent either a journal entry or expense
class TimelineItem {
  final String id;
  final DateTime date;
  final TimelineItemType type;
  final String title;
  final String description;
  final String? animalId;
  final String? animalName;
  final double? amount;
  final String? category;
  final List<String>? tags;
  final String? imageUrl;
  final Map<String, dynamic>? metadata;
  
  // Original data references
  final JournalEntry? journalEntry;
  final Expense? expense;

  TimelineItem({
    required this.id,
    required this.date,
    required this.type,
    required this.title,
    required this.description,
    this.animalId,
    this.animalName,
    this.amount,
    this.category,
    this.tags,
    this.imageUrl,
    this.metadata,
    this.journalEntry,
    this.expense,
  });

  /// Create timeline item from journal entry
  factory TimelineItem.fromJournal(JournalEntry journal, {String? animalName}) {
    return TimelineItem(
      id: journal.id ?? 'journal_${DateTime.now().millisecondsSinceEpoch}',
      date: journal.date,
      type: TimelineItemType.journal,
      title: journal.title,
      description: journal.description,
      animalId: journal.animalId,
      animalName: animalName,
      amount: journal.financialValue,
      category: journal.category,
      tags: journal.tags,
      imageUrl: journal.photos?.isNotEmpty == true ? journal.photos!.first : null,
      metadata: {
        'duration': journal.duration,
        'aetSkills': journal.aetSkills,
        'qualityScore': journal.qualityScore,
        'ffaStandards': journal.ffaStandards,
        'hasAiInsights': journal.aiInsights != null,
        'locationData': journal.locationData != null,
        'weatherData': journal.weatherData != null,
      },
      journalEntry: journal,
    );
  }

  /// Create timeline item from expense
  factory TimelineItem.fromExpense(Expense expense, {String? animalName}) {
    return TimelineItem(
      id: expense.id ?? 'expense_${DateTime.now().millisecondsSinceEpoch}',
      date: expense.date,
      type: TimelineItemType.expense,
      title: expense.title,
      description: expense.description,
      animalId: expense.animalId,
      animalName: animalName,
      amount: expense.amount,
      category: expense.category,
      tags: expense.tags,
      imageUrl: expense.receiptUrl,
      metadata: {
        'vendorName': expense.vendorName,
        'paymentMethod': expense.paymentMethod,
        'isPaid': expense.isPaid,
        'isRecurring': expense.isRecurring,
        'hasReceipt': expense.receiptUrl != null,
        'taxAmount': expense.taxAmount,
      },
      expense: expense,
    );
  }

  /// Get icon for timeline item
  IconData get icon {
    switch (type) {
      case TimelineItemType.journal:
        return _getJournalIcon();
      case TimelineItemType.expense:
        return ExpenseCategories.getIcon(category ?? 'other');
    }
  }

  /// Get color for timeline item
  Color get color {
    switch (type) {
      case TimelineItemType.journal:
        return _getJournalColor();
      case TimelineItemType.expense:
        return ExpenseCategories.getColor(category ?? 'other');
    }
  }

  IconData _getJournalIcon() {
    switch (category) {
      case 'daily_care':
        return Icons.pets;
      case 'health_check':
        return Icons.medical_services;
      case 'feeding':
        return Icons.restaurant;
      case 'training':
        return Icons.fitness_center;
      case 'show_prep':
        return Icons.star;
      case 'veterinary':
        return Icons.local_hospital;
      case 'breeding':
        return Icons.family_restroom;
      case 'financial':
        return Icons.attach_money;
      case 'competition':
        return Icons.emoji_events;
      default:
        return Icons.note;
    }
  }

  Color _getJournalColor() {
    switch (category) {
      case 'daily_care':
        return const Color(0xFF4CAF50);
      case 'health_check':
        return const Color(0xFFE91E63);
      case 'feeding':
        return const Color(0xFFFF9800);
      case 'training':
        return const Color(0xFF2196F3);
      case 'show_prep':
        return const Color(0xFFFFD700);
      case 'veterinary':
        return const Color(0xFF9C27B0);
      case 'breeding':
        return const Color(0xFF795548);
      case 'financial':
        return const Color(0xFF009688);
      case 'competition':
        return const Color(0xFFFF5722);
      default:
        return const Color(0xFF607D8B);
    }
  }

  /// Check if item has location data
  bool get hasLocation {
    if (type == TimelineItemType.journal && journalEntry != null) {
      return journalEntry!.locationData != null;
    }
    return false;
  }

  /// Check if item has weather data
  bool get hasWeather {
    if (type == TimelineItemType.journal && journalEntry != null) {
      return journalEntry!.weatherData != null;
    }
    return false;
  }

  /// Check if item has AI insights
  bool get hasAiInsights {
    if (type == TimelineItemType.journal && journalEntry != null) {
      return journalEntry!.aiInsights != null;
    }
    return false;
  }

  /// Get formatted amount string
  String get formattedAmount {
    if (amount == null) return '';
    return '\$${amount!.toStringAsFixed(2)}';
  }

  /// Get subtitle text for display
  String get subtitle {
    final parts = <String>[];
    
    if (animalName != null) {
      parts.add(animalName!);
    }
    
    if (type == TimelineItemType.journal) {
      final duration = metadata?['duration'];
      if (duration != null) {
        parts.add('${duration} min');
      }
      final score = metadata?['qualityScore'];
      if (score != null) {
        parts.add('Score: $score%');
      }
    } else if (type == TimelineItemType.expense) {
      if (amount != null) {
        parts.add(formattedAmount);
      }
      final vendor = metadata?['vendorName'];
      if (vendor != null) {
        parts.add(vendor);
      }
    }
    
    return parts.join(' • ');
  }
}

enum TimelineItemType {
  journal,
  expense;

  String get displayName {
    switch (this) {
      case TimelineItemType.journal:
        return 'Journal Entry';
      case TimelineItemType.expense:
        return 'Expense';
    }
  }

  IconData get typeIcon {
    switch (this) {
      case TimelineItemType.journal:
        return Icons.book;
      case TimelineItemType.expense:
        return Icons.attach_money;
    }
  }
}