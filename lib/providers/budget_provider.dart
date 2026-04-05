import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:sqflite/sqflite.dart';
import '../database/db_helper.dart';
import '../main.dart';

class BudgetProvider extends ChangeNotifier {
  List<Map<String, dynamic>> _transactions = [];
  double totalIncome = 0;
  double totalExpense = 0;
  double totalBalance = 0;

  List<Map<String, dynamic>> get transactions => _transactions;

  BudgetProvider() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      loadTransactions();
      loadSplitExpenses();
    });
  }

  Future<void> loadTransactions() async {
    final db = await DBHelper().database;
    final result = await db.query('transactions', orderBy: 'date DESC');
    _transactions = result;
    totalIncome = _transactions
        .where((t) => t['type'] == 'income')
        .fold(0.0, (sum, t) => sum + (t['amount'] as num).toDouble());
    totalExpense = _transactions
        .where((t) => t['type'] == 'expense')
        .fold(0.0, (sum, t) => sum + (t['amount'] as num).toDouble());
    totalBalance = totalIncome - totalExpense;
    notifyListeners();
  }

  Future<void> addTransaction(
      String title, double amount, String type, String category, String date, String notes) async {
    final db = await DBHelper().database;
    await db.insert('transactions', {
      'title': title,
      'amount': amount,
      'type': type,
      'category': category,
      'date': date,
      'notes': notes,
    });
    await loadTransactions();

    if (type == 'expense') {
      try {
        final month = date.substring(0, 7); // Ensure YYYY-MM
        await _checkBudgetLimits(category, month);
      } catch (e) {}
    }
  }

  Future<void> updateTransaction(
      int id, String title, double amount, String type, String category, String date, String notes) async {
    final db = await DBHelper().database;
    await db.update('transactions', {
      'title': title,
      'amount': amount,
      'type': type,
      'category': category,
      'date': date,
      'notes': notes,
    }, where: 'id = ?', whereArgs: [id]);
    await loadTransactions();
  }

  Future<void> deleteTransaction(int id) async {
    final db = await DBHelper().database;
    await db.delete('transactions', where: 'id = ?', whereArgs: [id]);
    await loadTransactions();
  }

  // Filter transactions by current week
  List<Map<String, dynamic>> getThisWeekTransactions() {
    final now = DateTime.now();
    final startOfWeek = now.subtract(Duration(days: now.weekday - 1));
    return _transactions.where((t) {
      final date = DateTime.parse(t['date']);
      return date.isAfter(startOfWeek) || 
             date.isAtSameMomentAs(startOfWeek);
    }).toList();
  }

  // Filter transactions by current month
  List<Map<String, dynamic>> getThisMonthTransactions() {
    final now = DateTime.now();
    return _transactions.where((t) {
      final date = DateTime.parse(t['date']);
      return date.month == now.month && date.year == now.year;
    }).toList();
  }

  // Group expenses by category for pie chart
  Map<String, double> getExpenseByCategory() {
    final expenses = _transactions.where((t) => t['type'] == 'expense');
    final Map<String, double> result = {};
    for (var t in expenses) {
      final cat = t['category'] as String;
      result[cat] = (result[cat] ?? 0) + (t['amount'] as num).toDouble();
    }
    return result;
  }

  // Get monthly totals for last 6 months for bar chart
  Map<String, Map<String, double>> getLast6MonthsSummary() {
    final Map<String, Map<String, double>> result = {};
    final now = DateTime.now();
    for (int i = 5; i >= 0; i--) {
      final month = DateTime(now.year, now.month - i, 1);
      final key = DateFormat('MMM').format(month);
      result[key] = {'income': 0, 'expense': 0};
    }
    for (var t in _transactions) {
      final date = DateTime.parse(t['date']);
      final key = DateFormat('MMM').format(date);
      if (result.containsKey(key)) {
        final type = t['type'] as String;
        result[key]![type] = 
          (result[key]![type] ?? 0) + (t['amount'] as num).toDouble();
      }
    }
    return result;
  }

  // --- BUDGETS & ALERTS --- //

  Future<void> setBudget(String category, String month, double amount) async {
    final db = await DBHelper().database;
    await db.insert(
      'budgets',
      {'category': category, 'month': month, 'amount': amount},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    notifyListeners();
  }

  Future<Map<String, double>> getBudgetsForMonth(String month) async {
    final db = await DBHelper().database;
    final List<Map<String, dynamic>> maps = await db.query(
      'budgets',
      where: 'month = ?',
      whereArgs: [month],
    );
    final Map<String, double> result = {};
    for (var map in maps) {
      result[map['category'] as String] = (map['amount'] as num).toDouble();
    }
    return result;
  }

  Future<Map<String, double>> getSpendingByCategory(String month) async {
    final Map<String, double> result = {};
    for (var t in _transactions) {
      final date = t['date'] as String;
      if (date.startsWith(month) && t['type'] == 'expense') {
        final cat = t['category'] as String;
        result[cat] = (result[cat] ?? 0) + (t['amount'] as num).toDouble();
      }
    }
    return result;
  }

  Future<void> _checkBudgetLimits(String category, String month) async {
    final budgets = await getBudgetsForMonth(month);
    if (!budgets.containsKey(category)) return;

    final budgetAmount = budgets[category]!;
    final spending = await getSpendingByCategory(month);
    final spentAmount = spending[category] ?? 0.0;
    
    final percentage = spentAmount / budgetAmount;
    if (percentage >= 0.8) {
      final prefs = await SharedPreferences.getInstance();
      final notificationsEnabled = prefs.getBool('notifications_enabled') ?? true;
      if (!notificationsEnabled) return;

      String keyBase = "budget_alert_${month}_$category";
      if (percentage >= 1.0) {
        String key = "${keyBase}_100";
        if (!(prefs.getBool(key) ?? false)) {
          _sendNotification("🚨 Budget Exceeded - $category", "You've exceeded your $category budget for this month!");
          await prefs.setBool(key, true);
        }
      } else {
        String key = "${keyBase}_80";
        if (!(prefs.getBool(key) ?? false)) {
          _sendNotification("⚠️ Budget Alert - $category", "You've used 80% of your $category budget this month");
          await prefs.setBool(key, true);
        }
      }
    }
  }

  Future<void> _sendNotification(String title, String body) async {
    const AndroidNotificationDetails androidPlatformChannelSpecifics = AndroidNotificationDetails(
      'budget_alerts', 'Budget Alerts',
      importance: Importance.max, priority: Priority.high,
    );
    const NotificationDetails platformChannelSpecifics = NotificationDetails(android: androidPlatformChannelSpecifics);
    await flutterLocalNotificationsPlugin.show(
      id: DateTime.now().millisecond, 
      title: title, 
      body: body, 
      notificationDetails: platformChannelSpecifics,
    );
  }

  // --- SPLIT EXPENSES --- //

  List<Map<String, dynamic>> _splitExpenses = [];
  List<Map<String, dynamic>> get splitExpenses => _splitExpenses;

  Future<void> loadSplitExpenses() async {
    final db = await DBHelper().database;
    final result = await db.query('split_expenses', orderBy: 'date DESC');
    _splitExpenses = result;
    notifyListeners();
  }

  Future<void> addSplitExpense(String title, double totalAmount, String date, String membersJson) async {
    final db = await DBHelper().database;
    await db.insert('split_expenses', {
      'title': title,
      'total_amount': totalAmount,
      'date': date,
      'members': membersJson,
      'created_at': DateTime.now().toIso8601String(),
    });
    await loadSplitExpenses();
  }

  Future<void> deleteSplitExpense(int id) async {
    final db = await DBHelper().database;
    await db.delete('split_expenses', where: 'id = ?', whereArgs: [id]);
    await loadSplitExpenses();
  }
}
