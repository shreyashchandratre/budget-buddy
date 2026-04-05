import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../providers/budget_provider.dart';
import '../theme/app_theme.dart';

class AnalyticsScreen extends StatefulWidget {
  const AnalyticsScreen({Key? key}) : super(key: key);

  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen> {
  bool _isThisMonth = true;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Analytics'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildToggle(),
            const SizedBox(height: 24),
            _buildSummaryCards(),
            const SizedBox(height: 32),
            _buildPieChartSection(),
            const SizedBox(height: 32),
            _buildBarChartSection(),
            const SizedBox(height: 100), // padding for scroll
          ],
        ),
      ),
    );
  }

  Widget _buildToggle() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A2E),
        borderRadius: BorderRadius.circular(30),
      ),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _isThisMonth = false),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: !_isThisMonth ? AppTheme.primaryAccent : Colors.transparent,
                  borderRadius: BorderRadius.circular(30),
                ),
                child: Center(
                  child: Text(
                    'This Week',
                    style: TextStyle(
                      color: !_isThisMonth ? Colors.white : AppTheme.textMuted,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _isThisMonth = true),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: _isThisMonth ? AppTheme.primaryAccent : Colors.transparent,
                  borderRadius: BorderRadius.circular(30),
                ),
                child: Center(
                  child: Text(
                    'This Month',
                    style: TextStyle(
                      color: _isThisMonth ? Colors.white : AppTheme.textMuted,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCards() {
    final provider = context.watch<BudgetProvider>();
    final txList = _isThisMonth ? provider.getThisMonthTransactions() : provider.getThisWeekTransactions();

    double income = 0;
    double expense = 0;
    for (var tx in txList) {
      if (tx['type'] == 'income') {
        income += (tx['amount'] as num).toDouble();
      } else {
        expense += (tx['amount'] as num).toDouble();
      }
    }
    double balance = income - expense;

    return Row(
      children: [
        Expanded(child: _buildCard('Income', income, const Color(0xFF00B894), Icons.arrow_downward)),
        const SizedBox(width: 8),
        Expanded(child: _buildCard('Expense', expense, const Color(0xFFFF6B6B), Icons.arrow_upward)),
        const SizedBox(width: 8),
        Expanded(child: _buildCard('Balance', balance, const Color(0xFF7C3AED), Icons.account_balance_wallet)),
      ],
    );
  }

  Widget _buildCard(String label, double amount, Color color, IconData iconData) {
    final currencyFormatter = NumberFormat.currency(symbol: '₹', decimalDigits: 0, locale: 'en_IN');

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A2E),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(iconData, color: color, size: 24),
          const SizedBox(height: 8),
          Text(label, style: const TextStyle(color: AppTheme.textWhite, fontSize: 12)),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              currencyFormatter.format(amount),
              style: const TextStyle(color: AppTheme.textWhite, fontWeight: FontWeight.bold, fontSize: 16),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPieChartSection() {
    final provider = context.watch<BudgetProvider>();
    final data = provider.getExpenseByCategory();
    final totalExpense = data.values.fold(0.0, (sum, v) => sum + v);

    if (totalExpense == 0) {
      return Container(
        height: 200,
        decoration: BoxDecoration(
          color: const Color(0xFF1A1A2E),
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Center(
          child: Text('No expense data yet', style: TextStyle(color: AppTheme.textMuted)),
        ),
      );
    }

    final currencyFormatter = NumberFormat.currency(symbol: '₹', decimalDigits: 0, locale: 'en_IN');

    final colors = {
      'Food': const Color(0xFFFF6B6B),
      'Transport': const Color(0xFF4ECDC4),
      'Shopping': const Color(0xFFFFEAA7),
      'Health': const Color(0xFF96CEB4),
      'Bills': const Color(0xFF45B7D1),
      'Other': const Color(0xFFB2BEC3),
    };

    List<PieChartSectionData> sections = [];
    data.forEach((key, value) {
      if (value > 0) {
        final percentage = (value / totalExpense) * 100;
        sections.add(
          PieChartSectionData(
            color: colors[key] ?? colors['Other']!,
            value: value,
            title: '${percentage.toStringAsFixed(1)}%',
            radius: 40,
            titleStyle: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.black),
          ),
        );
      }
    });

    return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF1A1A2E),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Spending by Category',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.textWhite)),
            const SizedBox(height: 24),
            SizedBox(
              height: 200,
              child: Stack(
                children: [
                  PieChart(
                    PieChartData(
                      sectionsSpace: 2,
                      centerSpaceRadius: 60,
                      sections: sections,
                    ),
                  ),
                  Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text('Total', style: TextStyle(color: AppTheme.textMuted, fontSize: 12)),
                        Text(currencyFormatter.format(totalExpense),
                            style: const TextStyle(
                                color: AppTheme.textWhite, fontSize: 16, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            ...data.entries.where((e) => e.value > 0).map((e) {
              final catColor = colors[e.key] ?? colors['Other']!;
              final percentage = (e.value / totalExpense) * 100;
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  children: [
                    Container(width: 12, height: 12, decoration: BoxDecoration(shape: BoxShape.circle, color: catColor)),
                    const SizedBox(width: 8),
                    Expanded(child: Text(e.key, style: const TextStyle(color: AppTheme.textWhite))),
                    Text(currencyFormatter.format(e.value), style: const TextStyle(color: AppTheme.textWhite, fontWeight: FontWeight.bold)),
                    const SizedBox(width: 8),
                    SizedBox(width: 50, child: Text('${percentage.toStringAsFixed(1)}%', style: const TextStyle(color: AppTheme.textMuted), textAlign: TextAlign.right,)),
                  ],
                ),
              );
            }).toList(),
          ],
        ));
  }

  Widget _buildBarChartSection() {
    final provider = context.watch<BudgetProvider>();
    final summary = provider.getLast6MonthsSummary();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A2E),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Monthly Overview',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.textWhite)),
          const SizedBox(height: 24),
          SizedBox(
            height: 250,
            child: BarChart(
              BarChartData(
                alignment: BarChartAlignment.spaceAround,
                maxY: _getMaxY(summary),
                barTouchData: BarTouchData(enabled: false),
                titlesData: FlTitlesData(
                  show: true,
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (double value, _) {
                        if (value.toInt() < 0 || value.toInt() >= summary.keys.length) return const SizedBox.shrink();
                        final val = summary.keys.elementAt(value.toInt());
                        return Padding(padding: const EdgeInsets.only(top: 8), child: Text(val, style: const TextStyle(color: AppTheme.textMuted, fontSize: 12)));
                      },
                      reservedSize: 28,
                    ),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 42,
                      getTitlesWidget: (value, meta) {
                        return Text('₹${(value / 1000).toStringAsFixed(0)}k', style: const TextStyle(color: AppTheme.textMuted, fontSize: 10));
                      },
                    ),
                  ),
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                ),
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  getDrawingHorizontalLine: (value) => const FlLine(color: Color(0x1FFFFFFF), strokeWidth: 1),
                ),
                borderData: FlBorderData(show: false),
                barGroups: _generateBarGroups(summary),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(width: 12, height: 12, decoration: const BoxDecoration(shape: BoxShape.circle, color: Color(0xFF00B894))),
              const SizedBox(width: 4),
              const Text('Income', style: TextStyle(color: AppTheme.textMuted, fontSize: 12)),
              const SizedBox(width: 16),
              Container(width: 12, height: 12, decoration: const BoxDecoration(shape: BoxShape.circle, color: Color(0xFFFF6B6B))),
              const SizedBox(width: 4),
              const Text('Expense', style: TextStyle(color: AppTheme.textMuted, fontSize: 12)),
            ],
          ),
        ],
      ),
    );
  }

  double _getMaxY(Map<String, Map<String, double>> summary) {
    double maxVal = 0;
    for (var m in summary.values) {
      if (m['income']! > maxVal) maxVal = m['income']!;
      if (m['expense']! > maxVal) maxVal = m['expense']!;
    }
    return maxVal < 1000 ? 1000 : maxVal * 1.2;
  }

  List<BarChartGroupData> _generateBarGroups(Map<String, Map<String, double>> summary) {
    List<BarChartGroupData> groups = [];
    int index = 0;
    summary.forEach((key, val) {
      groups.add(
        BarChartGroupData(
          x: index,
          barRods: [
            BarChartRodData(
              toY: val['income']!,
              color: const Color(0xFF00B894),
              width: 8,
              borderRadius: const BorderRadius.only(topLeft: Radius.circular(4), topRight: Radius.circular(4)),
            ),
            BarChartRodData(
              toY: val['expense']!,
              color: const Color(0xFFFF6B6B),
              width: 8,
              borderRadius: const BorderRadius.only(topLeft: Radius.circular(4), topRight: Radius.circular(4)),
            ),
          ],
        ),
      );
      index++;
    });
    return groups;
  }
}
