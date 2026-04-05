import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/budget_provider.dart';
import '../theme/app_theme.dart';
import '../utils/categories.dart';

class AddEditTransactionScreen extends StatefulWidget {
  final Map<String, dynamic>? transaction;

  const AddEditTransactionScreen({Key? key, this.transaction}) : super(key: key);

  @override
  State<AddEditTransactionScreen> createState() => _AddEditTransactionScreenState();
}

class _AddEditTransactionScreenState extends State<AddEditTransactionScreen> {
  final _formKey = GlobalKey<FormState>();
  
  late String _type;
  late String _selectedCategory;
  late TextEditingController _amountController;
  late TextEditingController _titleController;
  late TextEditingController _notesController;
  late DateTime _date;

  @override
  void initState() {
    super.initState();
    final tx = widget.transaction;
    _type = tx?['type'] ?? 'expense';
    _selectedCategory = tx?['category'] ?? 
        (_type == 'income' ? incomeCategories[0]['name']! : expenseCategories[0]['name']!);
    _amountController = TextEditingController(text: tx != null ? tx['amount'].toString() : '');
    _titleController = TextEditingController(text: tx?['title'] ?? '');
    _notesController = TextEditingController(text: tx?['notes'] ?? '');
    _date = tx?['date'] != null ? DateTime.parse(tx!['date'] as String) : DateTime.now();
  }

  @override
  void dispose() {
    _amountController.dispose();
    _titleController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_formKey.currentState!.validate()) {
      final title = _titleController.text.trim();
      final amount = double.parse(_amountController.text);
      final notes = _notesController.text.trim();
      final date = _date.toIso8601String();

      final provider = Provider.of<BudgetProvider>(context, listen: false);
      if (widget.transaction == null) {
        await provider.addTransaction(title, amount, _type, _selectedCategory, date, notes);
      } else {
        await provider.updateTransaction(widget.transaction!['id'], title, amount, _type, _selectedCategory, date, notes);
      }
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Transaction saved securely to database!'),
            backgroundColor: AppTheme.incomeGreen,
            duration: Duration(seconds: 2),
          ),
        );
        Navigator.pop(context);
      }
    }
  }

  Future<void> _delete() async {
    if (widget.transaction != null) {
      await Provider.of<BudgetProvider>(context, listen: false).deleteTransaction(widget.transaction!['id']);
      if (mounted) Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.transaction != null;

    return Scaffold(
      appBar: AppBar(
        title: Text(isEditing ? 'Edit Transaction' : 'Add Transaction'),
        actions: [
          if (isEditing)
            IconButton(
              icon: const Icon(Icons.delete_outline, color: AppTheme.expenseRed),
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (context) => AlertDialog(
                    backgroundColor: AppTheme.cardColor,
                    title: const Text('Delete Transaction?'),
                    content: const Text('This action cannot be undone.'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('CANCEL', style: TextStyle(color: AppTheme.textMuted)),
                      ),
                      TextButton(
                        onPressed: () {
                          Navigator.pop(context); // close dialog
                          _delete(); // delete and close screen
                        },
                        child: const Text('DELETE', style: TextStyle(color: AppTheme.expenseRed)),
                      ),
                    ],
                  ),
                );
              },
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Type Toggle
              Container(
                decoration: BoxDecoration(
                  color: AppTheme.cardColor,
                  borderRadius: BorderRadius.circular(30),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () {
                          if (_type != 'income') {
                            setState(() {
                              _type = 'income';
                              _selectedCategory = incomeCategories[0]['name']!;
                            });
                          }
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          decoration: BoxDecoration(
                            color: _type == 'income' ? AppTheme.incomeGreen : Colors.transparent,
                            borderRadius: BorderRadius.circular(30),
                          ),
                          child: Center(
                            child: Text(
                              'INCOME',
                              style: TextStyle(
                                color: _type == 'income' ? Colors.white : AppTheme.textMuted,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      child: GestureDetector(
                        onTap: () {
                          if (_type != 'expense') {
                            setState(() {
                              _type = 'expense';
                              _selectedCategory = expenseCategories[0]['name']!;
                            });
                          }
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          decoration: BoxDecoration(
                            color: _type == 'expense' ? AppTheme.expenseRed : Colors.transparent,
                            borderRadius: BorderRadius.circular(30),
                          ),
                          child: Center(
                            child: Text(
                              'EXPENSE',
                              style: TextStyle(
                                color: _type == 'expense' ? Colors.white : AppTheme.textMuted,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),

              // Amount Input
              TextFormField(
                controller: _amountController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 48, fontWeight: FontWeight.bold, color: AppTheme.textWhite),
                decoration: const InputDecoration(
                  hintText: '0.00',
                  hintStyle: TextStyle(fontSize: 48, color: AppTheme.textMuted),
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  fillColor: Colors.transparent,
                  prefixText: '₹ ',
                  prefixStyle: TextStyle(fontSize: 48, color: AppTheme.textMuted),
                ),
                validator: (val) {
                  if (val == null || val.isEmpty) return 'Enter amount';
                  if (double.tryParse(val) == null) return 'Invalid amount';
                  return null;
                },
              ),
              const SizedBox(height: 32),

              // Categories
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: 2.5,
                ),
                itemCount: _type == 'income' ? incomeCategories.length : expenseCategories.length,
                itemBuilder: (context, index) {
                  final cat = _type == 'income' ? incomeCategories[index] : expenseCategories[index];
                  final isSelected = _selectedCategory == cat['name'];
                  return GestureDetector(
                    onTap: () {
                      setState(() {
                        _selectedCategory = cat['name']!;
                      });
                    },
                    child: Container(
                      decoration: BoxDecoration(
                        color: AppTheme.cardColor,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isSelected ? const Color(0xFF7C3AED) : Colors.transparent,
                          width: 2,
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(cat['emoji']!, style: const TextStyle(fontSize: 18)),
                          const SizedBox(width: 8),
                          Flexible(
                            child: Text(
                              cat['name']!,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: isSelected ? AppTheme.textWhite : AppTheme.textMuted,
                                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 32),

              // Title
              TextFormField(
                controller: _titleController,
                style: const TextStyle(color: AppTheme.textWhite),
                decoration: const InputDecoration(
                  labelText: 'Title',
                  prefixIcon: Icon(Icons.title, color: AppTheme.textMuted),
                ),
                validator: (val) => val == null || val.isEmpty ? 'Enter a title' : null,
              ),
              const SizedBox(height: 24),

              // Date
              GestureDetector(
                onTap: () async {
                  final selected = await showDatePicker(
                    context: context,
                    initialDate: _date,
                    firstDate: DateTime(2000),
                    lastDate: DateTime(2100),
                    builder: (context, child) {
                      return Theme(
                        data: Theme.of(context).copyWith(
                          colorScheme: const ColorScheme.dark(
                            primary: AppTheme.primaryAccent,
                            onPrimary: Colors.white,
                            surface: AppTheme.cardColor,
                            onSurface: AppTheme.textWhite,
                          ),
                        ),
                        child: child!,
                      );
                    },
                  );
                  if (selected != null) {
                    setState(() {
                      _date = selected;
                    });
                  }
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                  decoration: BoxDecoration(
                    color: AppTheme.cardColor,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.calendar_today, color: AppTheme.textMuted),
                      const SizedBox(width: 16),
                      Text(
                        DateFormat('MMMM d, yyyy').format(_date),
                        style: const TextStyle(color: AppTheme.textWhite, fontSize: 16),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // Notes
              TextFormField(
                controller: _notesController,
                style: const TextStyle(color: AppTheme.textWhite),
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Notes (optional)',
                  alignLabelWithHint: true,
                ),
              ),
              const SizedBox(height: 40),

              // Save Button
              Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  gradient: const LinearGradient(
                    colors: [Color(0xFF9D4EDD), AppTheme.primaryAccent],
                  ),
                ),
                child: ElevatedButton(
                  onPressed: _save,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    shadowColor: Colors.transparent,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: const Text('SAVE TRANSACTION', style: TextStyle(fontSize: 16, letterSpacing: 1.2)),
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}
