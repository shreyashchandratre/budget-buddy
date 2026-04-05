import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/budget_provider.dart';
import '../theme/app_theme.dart';
import '../utils/categories.dart';

class BudgetScreen extends StatefulWidget {
  const BudgetScreen({Key? key}) : super(key: key);

  @override
  State<BudgetScreen> createState() => _BudgetScreenState();
}

class _BudgetScreenState extends State<BudgetScreen> {
  DateTime _currentMonth = DateTime.now();

  @override
  Widget build(BuildContext context) {
    final monthStr = DateFormat('yyyy-MM').format(_currentMonth);
    final provider = context.watch<BudgetProvider>();

    return Scaffold(
      appBar: AppBar(title: const Text('Monthly Budgets')),
      body: Column(
        children: [
          _buildMonthSelector(),
          Expanded(
            child: FutureBuilder(
              future: Future.wait([
                provider.getBudgetsForMonth(monthStr),
                provider.getSpendingByCategory(monthStr),
              ]),
              builder: (context, AsyncSnapshot<List<Map<String, double>>> snapshot) {
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final budgets = snapshot.data![0];
                final spendings = snapshot.data![1];

                return ListView.builder(
                  padding: const EdgeInsets.all(16.0),
                  itemCount: expenseCategories.length,
                  itemBuilder: (context, index) {
                    final cat = expenseCategories[index];
                    final catName = cat['name']!;
                    final emoji = cat['emoji']!;

                    final budgetAmount = budgets[catName];
                    final spentAmount = spendings[catName] ?? 0.0;

                    return _buildCategoryRow(catName, emoji, budgetAmount, spentAmount, monthStr, provider);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMonthSelector() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: const BoxDecoration(
        color: AppTheme.cardColor,
        border: Border(bottom: BorderSide(color: Colors.black26)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_left, color: AppTheme.textWhite),
            onPressed: () {
              setState(() {
                _currentMonth = DateTime(_currentMonth.year, _currentMonth.month - 1);
              });
            },
          ),
          Text(
            DateFormat('MMMM yyyy').format(_currentMonth),
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.textWhite),
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right, color: AppTheme.textWhite),
            onPressed: () {
              setState(() {
                _currentMonth = DateTime(_currentMonth.year, _currentMonth.month + 1);
              });
            },
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryRow(
    String catName,
    String emoji,
    double? budgetAmount,
    double spentAmount,
    String monthStr,
    BudgetProvider provider,
  ) {
    final currencyFormatter = NumberFormat.currency(symbol: '₹', decimalDigits: 0, locale: 'en_IN');

    Widget content;
    if (budgetAmount == null) {
      content = Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text('$emoji $catName', style: const TextStyle(fontSize: 16, color: AppTheme.textWhite)),
          TextButton(
            onPressed: () => _showBudgetModal(catName, emoji, monthStr, null, provider),
            style: TextButton.styleFrom(foregroundColor: AppTheme.primaryAccent),
            child: const Text('Set Budget'),
          ),
        ],
      );
    } else {
      double pct = spentAmount / budgetAmount;
      if (pct > 1.0) pct = 1.0;
      
      Color progressColor = AppTheme.incomeGreen;
      if (pct >= 0.8 && pct < 1.0) progressColor = Colors.orange;
      if (pct >= 1.0) progressColor = AppTheme.expenseRed;

      final usedPctLabel = ((spentAmount / budgetAmount) * 100).toStringAsFixed(0);

      content = Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('$emoji $catName', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.textWhite)),
              Row(
                children: [
                  Text(currencyFormatter.format(budgetAmount), style: const TextStyle(color: AppTheme.textWhite)),
                  IconButton(
                    icon: const Icon(Icons.edit, size: 16, color: AppTheme.textMuted),
                    onPressed: () => _showBudgetModal(catName, emoji, monthStr, budgetAmount, provider),
                  )
                ],
              )
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Spent: ${currencyFormatter.format(spentAmount)}', style: const TextStyle(color: AppTheme.textMuted, fontSize: 12)),
              Text('$usedPctLabel% used', style: TextStyle(color: progressColor, fontSize: 12, fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 8),
          LinearProgressIndicator(
            value: pct,
            backgroundColor: Colors.white12,
            valueColor: AlwaysStoppedAnimation<Color>(progressColor),
            minHeight: 8,
            borderRadius: BorderRadius.circular(4),
          )
        ],
      );
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.cardColor,
        borderRadius: BorderRadius.circular(16),
      ),
      child: content,
    );
  }

  void _showBudgetModal(String catName, String emoji, String monthStr, double? currentBudget, BudgetProvider provider) {
    final controller = TextEditingController(text: currentBudget?.toInt().toString() ?? '');
    
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.cardColor,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
            left: 24,
            right: 24,
            top: 24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('$emoji Set Budget: $catName', style: const TextStyle(fontSize: 18, color: AppTheme.textWhite, fontWeight: FontWeight.bold)),
              const SizedBox(height: 24),
              TextField(
                controller: controller,
                keyboardType: TextInputType.number,
                style: const TextStyle(color: AppTheme.textWhite),
                decoration: const InputDecoration(
                  labelText: 'Amount',
                  prefixText: '₹ ',
                  border: OutlineInputBorder(),
                  focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: AppTheme.primaryAccent)),
                ),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('CANCEL', style: TextStyle(color: AppTheme.textMuted)),
                    ),
                  ),
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryAccent),
                      onPressed: () {
                        final val = double.tryParse(controller.text);
                        if (val != null && val > 0) {
                          provider.setBudget(catName, monthStr, val);
                          Navigator.pop(context);
                          setState(() {}); // trigger rebuild to re-fetch
                        }
                      },
                      child: const Text('SAVE'),
                    ),
                  )
                ],
              ),
              const SizedBox(height: 24),
            ],
          ),
        );
      },
    );
  }
}
