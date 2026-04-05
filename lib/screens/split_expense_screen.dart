import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/budget_provider.dart';
import '../theme/app_theme.dart';

class SplitExpenseScreen extends StatefulWidget {
  const SplitExpenseScreen({Key? key}) : super(key: key);

  @override
  State<SplitExpenseScreen> createState() => _SplitExpenseScreenState();
}

class _SplitExpenseScreenState extends State<SplitExpenseScreen> {
  final _formKey = GlobalKey<FormState>();
  
  final _titleController = TextEditingController();
  final _amountController = TextEditingController();
  final _memberController = TextEditingController();
  
  DateTime _date = DateTime.now();
  String _splitType = 'Equal'; // 'Equal' or 'Custom'
  
  List<Map<String, dynamic>> _members = [];

  @override
  void dispose() {
    _titleController.dispose();
    _amountController.dispose();
    _memberController.dispose();
    super.dispose();
  }

  void _addMember() {
    final name = _memberController.text.trim();
    if (name.isNotEmpty) {
      setState(() {
        _members.add({'name': name, 'amount': 0.0});
        _memberController.clear();
        _recalculateEqualSplit();
      });
    }
  }

  void _removeMember(int index) {
    setState(() {
      _members.removeAt(index);
      _recalculateEqualSplit();
    });
  }

  void _recalculateEqualSplit() {
    if (_splitType != 'Equal' || _members.isEmpty) return;
    
    final total = double.tryParse(_amountController.text) ?? 0.0;
    final splitAmount = total / _members.length;
    for (var m in _members) {
      m['amount'] = splitAmount;
    }
  }

  Future<void> _saveSplit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_members.length < 2) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Minimum 2 members required')));
      return;
    }

    final total = double.tryParse(_amountController.text) ?? 0.0;
    double memSum = 0.0;
    for (var m in _members) memSum += m['amount'];
    
    if ((total - memSum).abs() > 0.1) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Member amounts must equal total amount')));
      return;
    }

    final jsonMembers = jsonEncode(_members);
    await Provider.of<BudgetProvider>(context, listen: false).addSplitExpense(
      _titleController.text.trim(),
      total,
      _date.toIso8601String(),
      jsonMembers,
    );

    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Split Expense')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: _amountController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                style: const TextStyle(fontSize: 36, color: AppTheme.textWhite, fontWeight: FontWeight.bold),
                decoration: const InputDecoration(
                  labelText: 'Total Amount',
                  prefixText: '₹ ',
                  border: OutlineInputBorder(),
                  focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: AppTheme.primaryAccent)),
                ),
                onChanged: (val) => _recalculateEqualSplit(),
                validator: (val) => (val == null || double.tryParse(val) == null || double.parse(val) <= 0) ? 'Enter valid total' : null,
              ),
              const SizedBox(height: 24),
              TextFormField(
                controller: _titleController,
                style: const TextStyle(color: AppTheme.textWhite),
                decoration: const InputDecoration(
                  labelText: 'Expense Title',
                  border: OutlineInputBorder(),
                ),
                validator: (val) => (val == null || val.isEmpty) ? 'Enter a title' : null,
              ),
              const SizedBox(height: 24),
              GestureDetector(
                onTap: () async {
                  final selected = await showDatePicker(
                    context: context,
                    initialDate: _date,
                    firstDate: DateTime(2000),
                    lastDate: DateTime(2100),
                  );
                  if (selected != null) {
                    setState(() { _date = selected; });
                  }
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                  decoration: BoxDecoration(color: AppTheme.cardColor, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.white24)),
                  child: Row(
                    children: [
                      const Icon(Icons.calendar_today, color: AppTheme.textMuted),
                      const SizedBox(width: 16),
                      Text(DateFormat('MMMM d, yyyy').format(_date), style: const TextStyle(color: AppTheme.textWhite, fontSize: 16)),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _memberController,
                      style: const TextStyle(color: AppTheme.textWhite),
                      decoration: const InputDecoration(labelText: 'Member Name', border: OutlineInputBorder()),
                    ),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryAccent, padding: const EdgeInsets.all(16)),
                    onPressed: _addMember,
                    child: const Text('Add'),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                children: _members.asMap().entries.map((entry) {
                  return Chip(
                    label: Text(entry.value['name']),
                    onDeleted: () => _removeMember(entry.key),
                    deleteIconColor: AppTheme.expenseRed,
                  );
                }).toList(),
              ),

              const SizedBox(height: 24),
              Container(
                decoration: BoxDecoration(color: AppTheme.cardColor, borderRadius: BorderRadius.circular(30)),
                child: Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () { setState(() { _splitType = 'Equal'; _recalculateEqualSplit(); }); },
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          decoration: BoxDecoration(
                            color: _splitType == 'Equal' ? AppTheme.primaryAccent : Colors.transparent,
                            borderRadius: BorderRadius.circular(30),
                          ),
                          child: Center(child: Text('Equal', style: TextStyle(color: _splitType == 'Equal' ? Colors.white : AppTheme.textMuted, fontWeight: FontWeight.bold))),
                        ),
                      ),
                    ),
                    Expanded(
                      child: GestureDetector(
                        onTap: () { setState(() { _splitType = 'Custom'; }); },
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          decoration: BoxDecoration(
                            color: _splitType == 'Custom' ? AppTheme.primaryAccent : Colors.transparent,
                            borderRadius: BorderRadius.circular(30),
                          ),
                          child: Center(child: Text('Custom', style: TextStyle(color: _splitType == 'Custom' ? Colors.white : AppTheme.textMuted, fontWeight: FontWeight.bold))),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),
              if (_members.isNotEmpty) ...[
                const Text('Split Summary', style: TextStyle(color: AppTheme.textMuted, fontSize: 16)),
                const SizedBox(height: 12),
                ..._members.asMap().entries.map((e) {
                  final idx = e.key;
                  final member = e.value;
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Row(
                      children: [
                        Expanded(child: Text(member['name'], style: const TextStyle(color: AppTheme.textWhite, fontSize: 16))),
                        _splitType == 'Equal' 
                          ? Text('₹${member['amount'].toStringAsFixed(2)}', style: const TextStyle(color: AppTheme.textWhite, fontSize: 16, fontWeight: FontWeight.bold))
                          : SizedBox(
                              width: 120,
                              child: TextFormField(
                                initialValue: member['amount'] > 0 ? member['amount'].toString() : '',
                                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                style: const TextStyle(color: AppTheme.textWhite),
                                decoration: const InputDecoration(prefixText: '₹', isDense: true, border: OutlineInputBorder()),
                                onChanged: (val) {
                                  _members[idx]['amount'] = double.tryParse(val) ?? 0.0;
                                },
                              ),
                            )
                      ],
                    ),
                  );
                }).toList()
              ],

              const SizedBox(height: 48),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryAccent, padding: const EdgeInsets.symmetric(vertical: 16)),
                  onPressed: _saveSplit,
                  child: const Text('SAVE SPLIT', style: TextStyle(fontSize: 16, letterSpacing: 1.2)),
                ),
              )
            ],
          ),
        ),
      ),
    );
  }
}
