import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/expense.dart';

/// Service for managing expense/financial transactions
class ExpenseService {
  static final _supabase = Supabase.instance.client;

  /// Get all expenses for the current user
  static Future<List<Expense>> getExpenses({
    int? limit,
    int? offset,
    String? animalId,
    String? category,
    DateTime? startDate,
    DateTime? endDate,
    bool? isPaid,
  }) async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) throw Exception('User not authenticated');

      // Start building query
      var query = _supabase
          .from('expenses')
          .select()
          .eq('user_id', user.id);

      // Add filters
      if (animalId != null) {
        query = query.eq('animal_id', animalId);
      }

      if (category != null) {
        query = query.eq('category', category);
      }

      if (isPaid != null) {
        query = query.eq('is_paid', isPaid);
      }

      if (startDate != null) {
        query = query.gte('date', startDate.toIso8601String());
      }

      if (endDate != null) {
        query = query.lte('date', endDate.toIso8601String());
      }

      // Apply ordering and pagination last
      final orderedQuery = query.order('date', ascending: false);

      final finalQuery = (offset != null && limit != null)
          ? orderedQuery.range(offset, offset + limit - 1)
          : (limit != null)
              ? orderedQuery.limit(limit)
              : orderedQuery;

      final response = await finalQuery;
      
      return (response as List)
          .map((json) => Expense.fromJson(json))
          .toList();
    } catch (e) {
      print('Error getting expenses: $e');
      rethrow;
    }
  }

  /// Get a single expense by ID
  static Future<Expense?> getExpenseById(String id) async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) throw Exception('User not authenticated');

      final response = await _supabase
          .from('expenses')
          .select()
          .eq('id', id)
          .eq('user_id', user.id)
          .single();

      return Expense.fromJson(response);
    } catch (e) {
      print('Error getting expense by ID: $e');
      return null;
    }
  }

  /// Create a new expense
  static Future<Expense> createExpense(Expense expense) async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) throw Exception('User not authenticated');

      final data = expense.toJson();
      data['user_id'] = user.id;
      data.remove('id'); // Let database generate ID
      data['created_at'] = DateTime.now().toIso8601String();
      data['updated_at'] = DateTime.now().toIso8601String();

      final response = await _supabase
          .from('expenses')
          .insert(data)
          .select()
          .single();

      return Expense.fromJson(response);
    } catch (e) {
      print('Error creating expense: $e');
      rethrow;
    }
  }

  /// Update an existing expense
  static Future<Expense> updateExpense(Expense expense) async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) throw Exception('User not authenticated');

      if (expense.id == null) {
        throw Exception('Expense ID is required for update');
      }

      final data = expense.toJson();
      data['updated_at'] = DateTime.now().toIso8601String();

      final response = await _supabase
          .from('expenses')
          .update(data)
          .eq('id', expense.id!)
          .eq('user_id', user.id)
          .select()
          .single();

      return Expense.fromJson(response);
    } catch (e) {
      print('Error updating expense: $e');
      rethrow;
    }
  }

  /// Delete an expense
  static Future<void> deleteExpense(String id) async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) throw Exception('User not authenticated');

      await _supabase
          .from('expenses')
          .delete()
          .eq('id', id)
          .eq('user_id', user.id);
    } catch (e) {
      print('Error deleting expense: $e');
      rethrow;
    }
  }

  /// Get expense statistics
  static Future<Map<String, dynamic>> getExpenseStats({
    DateTime? startDate,
    DateTime? endDate,
    String? animalId,
  }) async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) throw Exception('User not authenticated');

      var query = _supabase
          .from('expenses')
          .select('amount, category, date, is_paid')
          .eq('user_id', user.id);

      if (animalId != null) {
        query = query.eq('animal_id', animalId);
      }

      if (startDate != null) {
        query = query.gte('date', startDate.toIso8601String());
      }

      if (endDate != null) {
        query = query.lte('date', endDate.toIso8601String());
      }

      final response = await query;
      final expenses = response as List;

      // Calculate statistics
      double totalAmount = 0;
      double paidAmount = 0;
      double unpaidAmount = 0;
      Map<String, double> categoryTotals = {};
      
      for (final expense in expenses) {
        final amount = (expense['amount'] ?? 0).toDouble();
        final category = expense['category'] ?? 'other';
        final isPaid = expense['is_paid'] ?? true;
        
        totalAmount += amount;
        
        if (isPaid) {
          paidAmount += amount;
        } else {
          unpaidAmount += amount;
        }
        
        categoryTotals[category] = (categoryTotals[category] ?? 0) + amount;
      }

      // Sort categories by amount
      final sortedCategories = categoryTotals.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));

      return {
        'totalAmount': totalAmount,
        'paidAmount': paidAmount,
        'unpaidAmount': unpaidAmount,
        'transactionCount': expenses.length,
        'categoryBreakdown': Map.fromEntries(sortedCategories),
        'topCategory': sortedCategories.isNotEmpty ? sortedCategories.first.key : null,
        'averageAmount': expenses.isNotEmpty ? totalAmount / expenses.length : 0,
      };
    } catch (e) {
      print('Error getting expense stats: $e');
      return {
        'totalAmount': 0,
        'paidAmount': 0,
        'unpaidAmount': 0,
        'transactionCount': 0,
        'categoryBreakdown': {},
        'topCategory': null,
        'averageAmount': 0,
      };
    }
  }

  /// Get expenses grouped by date for timeline
  static Future<Map<DateTime, List<Expense>>> getExpensesByDate({
    DateTime? startDate,
    DateTime? endDate,
    String? animalId,
  }) async {
    try {
      final expenses = await getExpenses(
        startDate: startDate,
        endDate: endDate,
        animalId: animalId,
      );

      final Map<DateTime, List<Expense>> groupedExpenses = {};
      
      for (final expense in expenses) {
        final dateKey = DateTime(
          expense.date.year,
          expense.date.month,
          expense.date.day,
        );
        
        if (!groupedExpenses.containsKey(dateKey)) {
          groupedExpenses[dateKey] = [];
        }
        
        groupedExpenses[dateKey]!.add(expense);
      }

      return groupedExpenses;
    } catch (e) {
      print('Error getting expenses by date: $e');
      return {};
    }
  }

  /// Create expense from journal entry (if it contains financial data)
  static Future<Expense?> createExpenseFromJournal({
    required String journalId,
    required double amount,
    required String title,
    required String description,
    required String category,
    required DateTime date,
    String? animalId,
  }) async {
    try {
      final expense = Expense(
        userId: _supabase.auth.currentUser!.id,
        title: title,
        description: description,
        amount: amount,
        date: date,
        category: category,
        animalId: animalId,
        journalEntryId: journalId,
        notes: 'Created from journal entry',
      );

      return await createExpense(expense);
    } catch (e) {
      print('Error creating expense from journal: $e');
      return null;
    }
  }
}