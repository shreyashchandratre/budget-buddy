import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/budget_provider.dart';
import '../theme/app_theme.dart';
import '../models/category.dart';

class CategoriesScreen extends StatelessWidget {
  const CategoriesScreen({Key? key}) : super(key: key);

  void _showAddEditCategoryDialog(BuildContext context, {Category? category}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _CategoryModal(category: category),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Categories'),
      ),
      body: Consumer<BudgetProvider>(
        builder: (context, provider, child) {
          final categories = provider.categories;

          return GridView.builder(
            padding: const EdgeInsets.all(16),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
              childAspectRatio: 1.1,
            ),
            itemCount: categories.length,
            itemBuilder: (context, index) {
              final cat = categories[index];
              final count = provider.categoryCounts[cat.id] ?? 0;
              Color catColor;
              try {
                catColor = Color(int.parse(cat.color.replaceFirst('#', '0xFF')));
              } catch (e) {
                catColor = AppTheme.primaryAccent;
              }

              return GestureDetector(
                onLongPress: () {
                  if (!cat.isDefault) {
                    _showOptionsDialog(context, cat, count);
                  }
                },
                child: Card(
                  elevation: 4,
                  clipBehavior: Clip.antiAlias,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          AppTheme.cardColor,
                          catColor.withOpacity(0.1),
                        ],
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 8,
                          color: catColor,
                        ),
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                if (cat.isDefault)
                                  const Align(
                                    alignment: Alignment.topRight,
                                    child: Icon(Icons.lock, size: 16, color: AppTheme.textMuted),
                                  ),
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: catColor.withOpacity(0.2),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Text(cat.icon, style: const TextStyle(fontSize: 32)),
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  cat.name,
                                  style: const TextStyle(
                                    color: AppTheme.textWhite,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                  textAlign: TextAlign.center,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '$count transactions',
                                  style: const TextStyle(color: AppTheme.textMuted, fontSize: 12),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        heroTag: 'add_cat_button',
        onPressed: () => _showAddEditCategoryDialog(context),
        child: const Icon(Icons.add),
      ),
    );
  }

  void _showOptionsDialog(BuildContext context, Category category, int txCount) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.cardColor,
        title: Text(category.name),
        content: const Text('Choose an action for this category.'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              _showAddEditCategoryDialog(context, category: category);
            },
            child: const Text('EDIT', style: TextStyle(color: AppTheme.primaryAccent)),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              if (txCount > 0) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Cannot delete category with active transactions.')),
                );
              } else {
                Provider.of<BudgetProvider>(context, listen: false).deleteCategory(category.id!).catchError((e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Error deleting category.')),
                  );
                });
              }
            },
            child: const Text('DELETE', style: TextStyle(color: AppTheme.expenseRed)),
          ),
        ],
      ),
    );
  }
}

class _CategoryModal extends StatefulWidget {
  final Category? category;
  const _CategoryModal({Key? key, this.category}) : super(key: key);

  @override
  State<_CategoryModal> createState() => _CategoryModalState();
}

class _CategoryModalState extends State<_CategoryModal> {
  final _nameController = TextEditingController();
  String _selectedEmoji = '🍔';
  String _selectedColor = '#FF6B6B';

  final List<String> emojis = ['🍔', '🚗', '🏠', '💊', '🛍️', '🎮', '💰', '📦', '✈️', '🐶', '📚', '☕'];
  final List<String> colors = [
    '#FF6B6B', '#4ECDC4', '#45B7D1', '#96CEB4', '#FFEAA7', '#DDA0DD',
    '#00B894', '#B2BEC3', '#FF9F43', '#EE5A24', '#009432', '#12CBC4'
  ];

  @override
  void initState() {
    super.initState();
    if (widget.category != null) {
      _nameController.text = widget.category!.name;
      _selectedEmoji = widget.category!.icon;
      _selectedColor = widget.category!.color;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_nameController.text.trim().isEmpty) return;
    
    final cat = Category(
      id: widget.category?.id,
      name: _nameController.text.trim(),
      icon: _selectedEmoji,
      color: _selectedColor,
    );

    final p = Provider.of<BudgetProvider>(context, listen: false);
    try {
      if (widget.category == null) {
        await p.addCategory(cat);
      } else {
        await p.updateCategory(cat);
      }
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Save failed: $e'),
          backgroundColor: AppTheme.expenseRed,
        ));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        top: 24, left: 24, right: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      decoration: const BoxDecoration(
        color: AppTheme.cardColor,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            widget.category == null ? 'Add Category' : 'Edit Category',
            style: const TextStyle(fontSize: 20, fontWeight: bold, color: AppTheme.textWhite),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          TextField(
            controller: _nameController,
            style: const TextStyle(color: AppTheme.textWhite),
            decoration: const InputDecoration(labelText: 'Category Name'),
          ),
          const SizedBox(height: 24),
          const Text('Icon', style: TextStyle(color: AppTheme.textMuted)),
          const SizedBox(height: 8),
          SizedBox(
            height: 50,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: emojis.length,
              itemBuilder: (context, index) {
                final e = emojis[index];
                return GestureDetector(
                  onTap: () => setState(() => _selectedEmoji = e),
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    margin: const EdgeInsets.only(right: 8),
                    decoration: BoxDecoration(
                      color: _selectedEmoji == e ? AppTheme.primaryAccent.withOpacity(0.3) : Colors.transparent,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: _selectedEmoji == e ? AppTheme.primaryAccent : Colors.transparent,
                      )
                    ),
                    child: Text(e, style: const TextStyle(fontSize: 24)),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 24),
          const Text('Color', style: TextStyle(color: AppTheme.textMuted)),
          const SizedBox(height: 8),
          SizedBox(
            height: 50,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: colors.length,
              itemBuilder: (context, index) {
                final c = colors[index];
                final actualColor = Color(int.parse(c.replaceFirst('#', '0xFF')));
                return GestureDetector(
                  onTap: () => setState(() => _selectedColor = c),
                  child: Container(
                    width: 40,
                    margin: const EdgeInsets.only(right: 12),
                    decoration: BoxDecoration(
                      color: actualColor,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: _selectedColor == c ? Colors.white : Colors.transparent,
                        width: 3,
                      )
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 32),
          const SizedBox(height: 32),
          Row(
            children: [
              Expanded(
                child: TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('CANCEL', style: TextStyle(color: AppTheme.textMuted)),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: ElevatedButton(
                  onPressed: _save,
                  child: const Text('SAVE CATEGORY'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// Ensure bold is defined
const bold = FontWeight.bold;
