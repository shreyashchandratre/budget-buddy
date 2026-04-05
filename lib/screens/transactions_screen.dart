import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:collection/collection.dart';
import 'package:intl/intl.dart';
import '../providers/budget_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/transaction_tile.dart';
import 'add_edit_transaction_screen.dart';

class TransactionsScreen extends StatefulWidget {
  const TransactionsScreen({Key? key}) : super(key: key);

  @override
  State<TransactionsScreen> createState() => _TransactionsScreenState();
}

class _TransactionsScreenState extends State<TransactionsScreen> {
  String _searchQuery = '';
  String _filterType = 'all'; // 'all', 'income', 'expense'

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<BudgetProvider>();
    final transactions = provider.transactions;

    // Filter transactions
    List<Map<String, dynamic>> filteredList = transactions.where((tx) {
      final matchesSearch = (tx['title'] as String).toLowerCase().contains(_searchQuery) ||
          tx['amount'].toString().contains(_searchQuery);
      final matchesFilter = _filterType == 'all' || tx['type'] == _filterType;
      return matchesSearch && matchesFilter;
    }).toList();

    Widget bodyContent;
    if (filteredList.isEmpty) {
      bodyContent = const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.inbox_outlined, size: 80, color: AppTheme.textMuted),
            SizedBox(height: 16),
            Text(
              'No transactions found',
              style: TextStyle(color: AppTheme.textMuted, fontSize: 18),
            )
          ],
        ),
      );
    } else {
      // Group by date (ignoring time)
      final grouped = groupBy(filteredList, (Map<String, dynamic> tx) {
        final date = DateTime.parse(tx['date'] as String);
        return DateTime(date.year, date.month, date.day);
      });

      final sortedKeys = grouped.keys.toList()..sort((a, b) => b.compareTo(a));

      bodyContent = ListView.builder(
        itemCount: sortedKeys.length,
        itemBuilder: (context, index) {
          final date = sortedKeys[index];
          final dateTransactions = grouped[date]!;
          final isToday = date.day == DateTime.now().day &&
              date.month == DateTime.now().month &&
              date.year == DateTime.now().year;
          final isYesterday = date.day == DateTime.now().subtract(const Duration(days: 1)).day &&
              date.month == DateTime.now().subtract(const Duration(days: 1)).month &&
              date.year == DateTime.now().subtract(const Duration(days: 1)).year;

          String dateString;
          if (isToday) {
            dateString = 'Today';
          } else if (isYesterday) {
            dateString = 'Yesterday';
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
                  style: const TextStyle(
                    color: AppTheme.textMuted,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.2,
                  ),
                ),
              ),
              ...dateTransactions.map((tx) {
                return Dismissible(
                  key: Key(tx['id'].toString()),
                  direction: DismissDirection.endToStart,
                  background: Container(
                    alignment: Alignment.centerRight,
                    padding: const EdgeInsets.symmetric(horizontal: 24.0),
                    color: AppTheme.expenseRed,
                    child: const Icon(Icons.delete, color: Colors.white),
                  ),
                  onDismissed: (direction) {
                    provider.deleteTransaction(tx['id']);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('${tx['title']} deleted'),
                        action: SnackBarAction(
                          label: 'Undo',
                          onPressed: () {
                            provider.addTransaction(
                              tx['title'],
                              (tx['amount'] as num).toDouble(),
                              tx['type'],
                              tx['category'] ?? 'Other',
                              tx['date'],
                              tx['notes'],
                            ); 
                          },
                        ),
                      ),
                    );
                  },
                  child: TransactionTile(
                    transaction: tx,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => AddEditTransactionScreen(transaction: tx),
                        ),
                      );
                    },
                  ),
                );
              }).toList(),
            ],
          );
        },
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Transactions'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(130),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                child: TextField(
                  decoration: InputDecoration(
                    hintText: 'Search transactions...',
                    prefixIcon: const Icon(Icons.search, color: AppTheme.textMuted),
                    filled: true,
                    fillColor: AppTheme.cardColor,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                  onChanged: (val) {
                    setState(() {
                      _searchQuery = val.toLowerCase();
                    });
                  },
                ),
              ),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                child: Row(
                  children: [
                    _buildFilterChip('All', 'all'),
                    const SizedBox(width: 8),
                    _buildFilterChip('Income', 'income'),
                    const SizedBox(width: 8),
                    _buildFilterChip('Expense', 'expense'),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      body: bodyContent,
    );
  }

  Widget _buildFilterChip(String label, String value) {
    final isSelected = _filterType == value;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      selectedColor: AppTheme.primaryAccent,
      backgroundColor: AppTheme.cardColor,
      labelStyle: TextStyle(
        color: isSelected ? AppTheme.textWhite : AppTheme.textMuted,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
      ),
      onSelected: (selected) {
        setState(() {
          if (selected) {
            _filterType = value;
          }
        });
      },
    );
  }
}
