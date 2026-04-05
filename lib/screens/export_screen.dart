import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import '../providers/budget_provider.dart';
import '../theme/app_theme.dart';

class ExportScreen extends StatefulWidget {
  const ExportScreen({Key? key}) : super(key: key);

  @override
  State<ExportScreen> createState() => _ExportScreenState();
}

class _ExportScreenState extends State<ExportScreen> {
  String _dateRangeRaw = 'This Month';
  DateTime? _customStart;
  DateTime? _customEnd;

  List<Map<String, dynamic>> _filteredTransactions = [];
  double _totalIncome = 0;
  double _totalExpense = 0;
  List<int>? _pdfBytes;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _calculateStats();
    });
  }

  void _calculateStats() {
    final provider = context.read<BudgetProvider>();
    final allTx = provider.transactions;
    final now = DateTime.now();

    DateTime start;
    DateTime end;

    if (_dateRangeRaw == 'This Week') {
      start = now.subtract(Duration(days: now.weekday - 1));
      end = now;
    } else if (_dateRangeRaw == 'This Month') {
      start = DateTime(now.year, now.month, 1);
      end = DateTime(now.year, now.month + 1, 0); // last day
    } else if (_dateRangeRaw == 'Last Month') {
      start = DateTime(now.year, now.month - 1, 1);
      end = DateTime(now.year, now.month, 0);
    } else {
      start = _customStart ?? DateTime(2000);
      end = _customEnd ?? DateTime(2100);
    }

    // Filter
    _filteredTransactions = allTx.where((t) {
      final d = DateTime.parse(t['date'] as String);
      return (d.isAfter(start.subtract(const Duration(days: 1))) && 
              d.isBefore(end.add(const Duration(days: 1))));
    }).toList();

    _totalIncome = 0;
    _totalExpense = 0;
    for (var t in _filteredTransactions) {
      if (t['type'] == 'income') {
        _totalIncome += (t['amount'] as num).toDouble();
      } else {
        _totalExpense += (t['amount'] as num).toDouble();
      }
    }

    setState(() {});
  }

  Future<void> _generatePdf() async {
    final pdf = pw.Document();
    final fontData = await PdfGoogleFonts.robotoRegular();
    final boldFontData = await PdfGoogleFonts.robotoBold();
    
    final currencyFormat = NumberFormat.currency(symbol: 'Rs.', decimalDigits: 2);
    final dateFormat = DateFormat('MMM d, yyyy');

    String periodLabel = _dateRangeRaw;
    if (_dateRangeRaw == 'Custom' && _customStart != null && _customEnd != null) {
      periodLabel = '${dateFormat.format(_customStart!)} - ${dateFormat.format(_customEnd!)}';
    }

    // Page 1: Summary
    pdf.addPage(pw.Page(
      pageFormat: PdfPageFormat.a4,
      build: (pw.Context context) {
        return pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text('BudgetBuddy', style: pw.TextStyle(font: boldFontData, fontSize: 32, color: PdfColor.fromHex('#7C3AED'))),
            pw.SizedBox(height: 20),
            pw.Text('Financial Report', style: pw.TextStyle(font: boldFontData, fontSize: 24)),
            pw.Text('Period: $periodLabel', style: pw.TextStyle(font: fontData, fontSize: 14)),
            pw.Text('Generated on: ${dateFormat.format(DateTime.now())}', style: pw.TextStyle(font: fontData, fontSize: 14, color: PdfColors.grey700)),
            pw.SizedBox(height: 40),
            pw.Container(
              padding: const pw.EdgeInsets.all(20),
              decoration: pw.BoxDecoration(
                border: pw.Border.all(color: PdfColors.grey300),
                borderRadius: pw.BorderRadius.circular(8),
              ),
              child: pw.Column(
                children: [
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text('Total Income', style: pw.TextStyle(font: boldFontData, fontSize: 16)),
                      pw.Text(currencyFormat.format(_totalIncome), style: pw.TextStyle(font: boldFontData, fontSize: 16, color: PdfColors.green)),
                    ],
                  ),
                  pw.Divider(color: PdfColors.grey300),
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text('Total Expense', style: pw.TextStyle(font: boldFontData, fontSize: 16)),
                      pw.Text(currencyFormat.format(_totalExpense), style: pw.TextStyle(font: boldFontData, fontSize: 16, color: PdfColors.red)),
                    ],
                  ),
                  pw.Divider(color: PdfColors.grey300),
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text('Net Balance', style: pw.TextStyle(font: boldFontData, fontSize: 18)),
                      pw.Text(currencyFormat.format(_totalIncome - _totalExpense), style: pw.TextStyle(font: boldFontData, fontSize: 18, color: PdfColor.fromHex('#7C3AED'))),
                    ],
                  ),
                ]
              )
            )
          ],
        );
      },
    ));

    // Page 2+: Transactions
    final List<List<String>> tableData = _filteredTransactions.map((tx) {
      final date = DateTime.parse(tx['date'] as String);
      return [
        dateFormat.format(date),
        tx['title'] as String,
        tx['category'] as String? ?? 'Other',
        tx['type'] as String,
        currencyFormat.format((tx['amount'] as num).toDouble()),
      ];
    }).toList();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        header: (context) => pw.Text('Transaction List', style: pw.TextStyle(font: boldFontData, fontSize: 20)),
        footer: (context) => pw.Container(
          alignment: pw.Alignment.centerRight,
          margin: const pw.EdgeInsets.only(top: 10),
          child: pw.Text('Generated by BudgetBuddy - Page ${context.pageNumber}', style: pw.TextStyle(color: PdfColors.grey)),
        ),
        build: (context) => [
          pw.SizedBox(height: 20),
          pw.TableHelper.fromTextArray(
            headers: ['Date', 'Title', 'Category', 'Type', 'Amount'],
            data: tableData,
            border: pw.TableBorder.all(color: PdfColors.grey300),
            headerStyle: pw.TextStyle(font: boldFontData, color: PdfColors.white),
            headerDecoration: pw.BoxDecoration(color: PdfColor.fromHex('#7C3AED')),
            cellStyle: pw.TextStyle(font: fontData, fontSize: 10),
            cellAlignment: pw.Alignment.centerLeft,
            cellAlignments: {
              4: pw.Alignment.centerRight,
            }
          ),
        ],
      )
    );

    final bytes = await pdf.save();
    setState(() {
      _pdfBytes = bytes;
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('PDF Generated Successfully!')));
    }
  }

  Future<void> _sharePdf() async {
    if (_pdfBytes == null) return;
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/BudgetBuddy_Report.pdf');
    await file.writeAsBytes(_pdfBytes!);
    await Share.shareXFiles([XFile(file.path)], text: 'My BudgetBuddy Report');
  }

  @override
  Widget build(BuildContext context) {
    final currencyFormatter = NumberFormat.currency(symbol: '₹', decimalDigits: 2, locale: 'en_IN');

    return Scaffold(
      appBar: AppBar(title: const Text('Export Report')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Dropdown
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(color: AppTheme.cardColor, borderRadius: BorderRadius.circular(12)),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  dropdownColor: AppTheme.cardColor,
                  style: const TextStyle(color: AppTheme.textWhite, fontSize: 16),
                  value: _dateRangeRaw,
                  items: ['This Week', 'This Month', 'Last Month', 'Custom'].map((s) {
                    return DropdownMenuItem(value: s, child: Text(s));
                  }).toList(),
                  onChanged: (val) async {
                    if (val == 'Custom') {
                      final picked = await showDateRangePicker(
                        context: context,
                        firstDate: DateTime(2000),
                        lastDate: DateTime(2100),
                      );
                      if (picked != null) {
                        _customStart = picked.start;
                        _customEnd = picked.end;
                      } else {
                        return; // cancelled
                      }
                    }
                    setState(() { _dateRangeRaw = val!; });
                    _calculateStats();
                  },
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Preview Card
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppTheme.cardColor,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppTheme.primaryAccent.withOpacity(0.3)),
              ),
              child: Column(
                children: [
                  const Text('Report Preview', style: TextStyle(color: AppTheme.textMuted, fontSize: 14)),
                  const SizedBox(height: 16),
                  _buildPreviewRow('Total Income', currencyFormatter.format(_totalIncome), AppTheme.incomeGreen),
                  const SizedBox(height: 8),
                  _buildPreviewRow('Total Expense', currencyFormatter.format(_totalExpense), AppTheme.expenseRed),
                  const Divider(color: Colors.white24, height: 32),
                  _buildPreviewRow('Net Balance', currencyFormatter.format(_totalIncome - _totalExpense), AppTheme.primaryAccent),
                  const SizedBox(height: 16),
                  Text('${_filteredTransactions.length} Transactions Found', style: const TextStyle(color: AppTheme.textMuted)),
                ],
              ),
            ),
            const SizedBox(height: 32),

            // Generate Button
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryAccent,
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              onPressed: _generatePdf,
              child: const Text('GENERATE PDF', style: TextStyle(fontSize: 16, letterSpacing: 1.2)),
            ),
            
            if (_pdfBytes != null) ...[
              const SizedBox(height: 16),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  side: const BorderSide(color: AppTheme.primaryAccent),
                ),
                icon: const Icon(Icons.share, color: AppTheme.primaryAccent),
                label: const Text('SHARE PDF', style: TextStyle(color: AppTheme.primaryAccent, fontSize: 16)),
                onPressed: _sharePdf,
              ),
              const SizedBox(height: 16),
              TextButton.icon(
                onPressed: () => Printing.layoutPdf(onLayout: (format) => Uint8List.fromList(_pdfBytes!)),
                icon: const Icon(Icons.print, color: AppTheme.textMuted),
                label: const Text('SYSTEM PRINT / PREVIEW', style: TextStyle(color: AppTheme.textMuted)),
              ),
            ]
          ],
        ),
      ),
    );
  }

  Widget _buildPreviewRow(String label, String value, Color col) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(color: AppTheme.textWhite, fontSize: 16, fontWeight: FontWeight.bold)),
        Text(value, style: TextStyle(color: col, fontSize: 16, fontWeight: FontWeight.bold)),
      ],
    );
  }
}
