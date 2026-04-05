import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:collection/collection.dart';
import '../providers/budget_provider.dart';
import '../theme/app_theme.dart';
import 'split_expense_screen.dart';

class SplitHistoryScreen extends StatelessWidget {
  const SplitHistoryScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<BudgetProvider>();
    final splits = provider.splitExpenses;

    if (splits.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('Split History')),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.call_split, size: 80, color: AppTheme.textMuted),
              const SizedBox(height: 16),
              const Text('No splits recorded yet', style: TextStyle(color: AppTheme.textMuted, fontSize: 18)),
            ],
          ),
        ),
        floatingActionButton: FloatingActionButton(
          onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SplitExpenseScreen())),
          child: const Icon(Icons.add),
        ),
      );
    }

    // Group by date
    final grouped = groupBy(splits, (Map<String, dynamic> split) {
      final date = DateTime.parse(split['date'] as String);
      return DateTime(date.year, date.month, date.day);
    });

    final sortedKeys = grouped.keys.toList()..sort((a, b) => b.compareTo(a));

    return Scaffold(
      appBar: AppBar(title: const Text('Split History')),
      body: ListView.builder(
        itemCount: sortedKeys.length,
        itemBuilder: (context, index) {
          final date = sortedKeys[index];
          final dateSplits = grouped[date]!;
          
          String dateString;
          final today = DateTime.now();
          if (date.year == today.year && date.month == today.month && date.day == today.day) {
            dateString = 'Today';
          } else {
            dateString = DateFormat('MMMM d, yyyy').format(date);
          }

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 8),
                child: Text(
                  dateString,
                  style: const TextStyle(color: AppTheme.textMuted, fontSize: 14, fontWeight: FontWeight.bold, letterSpacing: 1.2),
                ),
              ),
              ...dateSplits.map((split) {
                final members = jsonDecode(split['members'] as String) as List<dynamic>;
                final total = split['total_amount'] as num;
                
                return Dismissible(
                  key: Key(split['id'].toString()),
                  direction: DismissDirection.endToStart,
                  background: Container(
                    alignment: Alignment.centerRight,
                    color: AppTheme.expenseRed,
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: const Icon(Icons.delete, color: Colors.white),
                  ),
                  onDismissed: (_) {
                    provider.deleteSplitExpense(split['id']);
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${split['title']} deleted')));
                  },
                  child: Card(
                    margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    color: AppTheme.cardColor,
                    child: ExpansionTile(
                      title: Text(split['title'], style: const TextStyle(color: AppTheme.textWhite, fontWeight: FontWeight.bold)),
                      subtitle: Text('${members.length} members', style: const TextStyle(color: AppTheme.textMuted, fontSize: 12)),
                      trailing: Text('₹${total.toStringAsFixed(2)}', style: const TextStyle(color: AppTheme.primaryAccent, fontSize: 16, fontWeight: FontWeight.bold)),
                      children: members.map((m) {
                        return ListTile(
                          title: Text(m['name'], style: const TextStyle(color: AppTheme.textMuted)),
                          trailing: Text('₹${m['amount'].toString()}', style: const TextStyle(color: AppTheme.textWhite)),
                        );
                      }).toList(),
                    ),
                  ),
                );
              }).toList(),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SplitExpenseScreen())),
        child: const Icon(Icons.add),
      ),
    );
  }
}
