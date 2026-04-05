import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../theme/app_theme.dart';
import '../utils/categories.dart';

class TransactionTile extends StatelessWidget {
  final Map<String, dynamic> transaction;
  final VoidCallback? onTap;

  const TransactionTile({
    Key? key,
    required this.transaction,
    this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final bool isIncome = transaction['type'] == 'income';
    final currencyFormatter = NumberFormat.currency(symbol: '₹', decimalDigits: 2, locale: 'en_IN');
    final dateFormatter = DateFormat('MMM d, yyyy');
    DateTime date = DateTime.parse(transaction['date'] as String);

    final String catName = transaction['category'] as String? ?? 'Other';
    String emoji = '📦';
    if (isIncome) {
      final found = incomeCategories.firstWhere((c) => c['name'] == catName, orElse: () => {'emoji': '📦'});
      emoji = found['emoji']!;
    } else {
      final found = expenseCategories.firstWhere((c) => c['name'] == catName, orElse: () => {'emoji': '📦'});
      emoji = found['emoji']!;
    }

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: ListTile(
        onTap: onTap,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        title: Text(
          transaction['title'] as String,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text('$emoji $catName', style: const TextStyle(fontSize: 13, color: AppTheme.textMuted)),
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              '${isIncome ? '+' : '-'}${currencyFormatter.format(transaction['amount'])}',
              style: TextStyle(
                color: isIncome ? AppTheme.incomeGreen : AppTheme.expenseRed,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              dateFormatter.format(date),
              style: const TextStyle(fontSize: 12, color: AppTheme.textMuted),
            ),
          ],
        ),
      ),
    );
  }
}
