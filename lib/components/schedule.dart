import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:file_picker/file_picker.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:pdf/pdf.dart';
import 'package:printing/printing.dart';
import 'package:excel/excel.dart' as excel;
import 'dart:io';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:animated_custom_dropdown/custom_dropdown.dart';

class ScheduleScreen extends StatefulWidget {
  final List<Map<String, dynamic>> scheduleData;
  final double principal;
  final double interestRate;
  final int tenureMonths;
  final double emi;
  final DateTime startDate;
  final bool isYearly;

  const ScheduleScreen({
    super.key,
    required this.scheduleData,
    required this.principal,
    required this.interestRate,
    required this.tenureMonths,
    required this.emi,
    required this.startDate,
    this.isYearly = false,
  });

  @override
  State<ScheduleScreen> createState() => _ScheduleScreenState();
}

class _ScheduleScreenState extends State<ScheduleScreen> {
  late DateTime _emiStartDate;
  late bool _isYearly;
  late int _emiStartMonth;
  late int _emiStartYear;

  @override
  void initState() {
    super.initState();
    _emiStartDate = widget.startDate;
    _isYearly = widget.isYearly;
    _emiStartMonth = widget.startDate.month;
    _emiStartYear = widget.startDate.year;
  }

  void _pickStartDate() async {
    final now = DateTime.now();
    int selectedYear = _emiStartYear;
    int selectedMonth = _emiStartMonth;
    int minYear = now.year;
    int minMonth = now.month;
    final List<String> months = List.generate(12, (i) => DateFormat('MMMM').format(DateTime(0, i + 1)));
    final List<int> years = List.generate(15, (i) => minYear + i);
    String selectedMonthStr = months[selectedMonth - 1];
    String selectedYearStr = selectedYear.toString();
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Padding(
          padding: MediaQuery.of(context).viewInsets,
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.08),
                  blurRadius: 16,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: Colors.grey[300],
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const Text(
                    'Select EMI Start From',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20, color: Color(0xFF3498db)),
                  ),
                  const SizedBox(height: 20),
                  Card(
                    elevation: 2,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
                      child: SizedBox(
                        height: 80,
                        child: Row(
                          children: [
                            // Month Dropdown
                            Expanded(
                              child: CustomDropdown<String>(
                                hintText: 'Month',
                                items: months,
                                initialItem: selectedMonthStr,
                                decoration: CustomDropdownDecoration(
                                  closedFillColor: Colors.white,
                                  closedBorder: Border.all(color: const Color(0xFF3498db).withOpacity(0.2)),
                                  closedBorderRadius: BorderRadius.circular(12),
                                  closedSuffixIcon: const Icon(Icons.arrow_drop_down, color: Color(0xFF3498db)),
                                ),
                                onChanged: (val) {
                                  final isDisabled = (int.parse(selectedYearStr) == minYear && months.indexOf(val!) + 1 < minMonth);
                                  if (val != null && !isDisabled) {
                                    selectedMonthStr = val;
                                    selectedMonth = months.indexOf(val) + 1;
                                    (context as Element).markNeedsBuild();
                                  }
                                },
                                hintBuilder: (context, item, isSelected) {
                                  final isDisabled = (years[int.parse(selectedYearStr) - minYear] == minYear && months.indexOf(item) + 1 < minMonth);
                                  return Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                    child: Text(
                                      item,
                                      style: TextStyle(
                                        color: isDisabled ? Colors.grey : Colors.black,
                                        fontWeight: isDisabled ? FontWeight.normal : FontWeight.w500,
                                      ),
                                    ),
                                  );
                                },
                                excludeSelected: false,
                              ),
                            ),
                            const SizedBox(width: 18),
                            // Year Dropdown
                            Expanded(
                              child: CustomDropdown<String>(
                                hintText: 'Year',
                                items: years.map((e) => e.toString()).toList(),
                                initialItem: selectedYearStr,
                                decoration: CustomDropdownDecoration(
                                  closedFillColor: Colors.white,
                                  closedBorder: Border.all(color: const Color(0xFF3498db).withOpacity(0.2)),
                                  closedBorderRadius: BorderRadius.circular(12),
                                  closedSuffixIcon: const Icon(Icons.arrow_drop_down, color: Color(0xFF3498db)),
                                ),
                                onChanged: (val) {
                                  if (val != null) {
                                    selectedYearStr = val;
                                    selectedYear = int.parse(val);
                                    if (selectedYear == minYear && selectedMonth < minMonth) {
                                      selectedMonth = minMonth;
                                      selectedMonthStr = months[minMonth - 1];
                                    }
                                    (context as Element).markNeedsBuild();
                                  }
                                },
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        style: TextButton.styleFrom(foregroundColor: Colors.grey[700]),
                        child: const Text('Cancel', style: TextStyle(fontSize: 16)),
                      ),
                      const SizedBox(width: 16),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF3498db),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
                        ),
                        onPressed: () {
                          setState(() {
                            _emiStartMonth = selectedMonth;
                            _emiStartYear = selectedYear;
                            _emiStartDate = DateTime(selectedYear, selectedMonth);
                          });
                          Navigator.pop(context);
                        },
                        child: const Text('OK', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  List<Map<String, dynamic>> get _displayData {
    // Calculate the offset between the selected EMI start date and the original start date
    final int offset = (_emiStartYear - widget.startDate.year) * 12 + (_emiStartMonth - widget.startDate.month);
    final int startIndex = offset.clamp(0, widget.scheduleData.length - 1);
    final int endIndex = (startIndex + widget.tenureMonths).clamp(0, widget.scheduleData.length);
    final List<Map<String, dynamic>> slicedData = widget.scheduleData.sublist(startIndex, endIndex);
    if (!_isYearly) return slicedData;
    // Aggregate yearly
    List<Map<String, dynamic>> yearly = [];
    int year = _emiStartDate.year;
    double principal = 0, interest = 0, outstanding = widget.principal;
    for (int i = 0; i < slicedData.length; i++) {
      final month = DateTime(_emiStartDate.year, _emiStartDate.month + i);
      if (month.year != year || i == slicedData.length - 1) {
        yearly.add({
          'year': year,
          'principal': principal,
          'interest': interest,
          'outstanding': outstanding,
        });
        year = month.year;
        principal = 0;
        interest = 0;
      }
      principal += slicedData[i]['principal'] ?? 0;
      interest += slicedData[i]['interest'] ?? 0;
      outstanding = slicedData[i]['outstanding'] ?? 0;
    }
    return yearly;
  }

  Future<void> _exportPdf() async {
    final pdf = pw.Document();
    final font = await PdfGoogleFonts.nunitoRegular();
    final currencyFormat = NumberFormat.currency(locale: 'en_IN', symbol: '₹');
    final monthFormat = DateFormat('MMM-yyyy');
    pdf.addPage(
      pw.MultiPage(
        theme: pw.ThemeData.withFont(
          base: font,
        ),
        build: (context) => [
          pw.Text('Repayment Schedule', style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 10),
          pw.Text('Principal: ₹${widget.principal.toStringAsFixed(2)}'),
          pw.Text('Interest Rate: ${widget.interestRate.toStringAsFixed(2)}%'),
          pw.Text('Tenure: ${widget.tenureMonths} months'),
          pw.Text('EMI: ₹${widget.emi.toStringAsFixed(2)}'),
          pw.Text('EMI Start: ${DateFormat('MMM-yyyy').format(_emiStartDate)}'),
          pw.SizedBox(height: 10),
          pw.Table.fromTextArray(
            headers: _isYearly
                ? ['Sr.', 'Year', 'Principal', 'Interest', 'Outstanding']
                : ['Sr.', 'Month', 'Principal', 'Interest', 'Outstanding'],
            data: [
              for (int i = 0; i < _displayData.length; i++)
                _isYearly
                    ? [
                        (i + 1).toString(),
                        _displayData[i]['year'].toString(),
                        '₹${_displayData[i]['principal'].toStringAsFixed(2)}',
                        '₹${_displayData[i]['interest'].toStringAsFixed(2)}',
                        '₹${_displayData[i]['outstanding'].toStringAsFixed(2)}',
                      ]
                    : [
                        (i + 1).toString(),
                        monthFormat.format(DateTime(_emiStartDate.year, _emiStartDate.month + i)),
                        '₹${_displayData[i]['principal'].toStringAsFixed(2)}',
                        '₹${_displayData[i]['interest'].toStringAsFixed(2)}',
                        '₹${_displayData[i]['outstanding'].toStringAsFixed(2)}',
                      ]
            ],
            cellStyle: pw.TextStyle(fontSize: 9),
            headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
            cellAlignment: pw.Alignment.centerLeft,
            headerDecoration: pw.BoxDecoration(color: PdfColors.blue50),
          ),
        ],
      ),
    );
    await Printing.layoutPdf(onLayout: (format) async => pdf.save());
  }

  Future<void> _exportExcel() async {
    try {
      final ex = excel.Excel.createExcel();
      final sheet = ex['Schedule'];
      if (_isYearly) {
        sheet.appendRow(['Sr.', 'Year', 'Principal', 'Interest', 'Outstanding']);
        for (int i = 0; i < _displayData.length; i++) {
          sheet.appendRow([
            (i + 1).toString(),
            _displayData[i]['year'].toString(),
            _displayData[i]['principal'],
            _displayData[i]['interest'],
            _displayData[i]['outstanding'],
          ]);
        }
      } else {
        sheet.appendRow(['Sr.', 'Month', 'Principal', 'Interest', 'Outstanding']);
        final monthFormat = DateFormat('MMM-yyyy');
        for (int i = 0; i < _displayData.length; i++) {
          sheet.appendRow([
            (i + 1).toString(),
            monthFormat.format(DateTime(_emiStartDate.year, _emiStartDate.month + i)),
            _displayData[i]['principal'],
            _displayData[i]['interest'],
            _displayData[i]['outstanding'],
          ]);
        }
      }

      final bytes = ex.encode();
      if (bytes == null) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to generate Excel file')));
        }
        return;
      }

      if (kIsWeb) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Excel export is not supported on web.')));
        return;
      }

      // Get the temporary directory
      final directory = await getTemporaryDirectory();
      final String filePath = '${directory.path}/repayment_schedule.xlsx';
      
      // Write the file
      final File file = File(filePath);
      await file.writeAsBytes(bytes);

      // Share the file
      await Share.shareXFiles(
        [XFile(filePath)],
        text: 'Repayment Schedule',
      );

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Excel file generated successfully!')));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Excel export failed: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final currencyFormat = NumberFormat.currency(locale: 'en_IN', symbol: '₹');
    final monthFormat = DateFormat('MMM-yyyy');
    final isSmall = MediaQuery.of(context).size.width < 600;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Repayment Schedule', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
        backgroundColor: const Color(0xFF3498db),
        elevation: 0,
        iconTheme: IconThemeData(color: Colors.white),
      ),
      body: Column(
        children: [
          // EMI Info Row
          Container(
            color: const Color(0xFF3498db),
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    _InfoCard(
                      icon: Icons.account_balance_wallet,
                      title: 'Principal',
                      value: currencyFormat.format(widget.principal),
                    ),
                    const SizedBox(width: 16),
                    _InfoCard(
                      icon: Icons.percent,
                      title: 'Interest Rate',
                      value: '${widget.interestRate.toStringAsFixed(2)}%',
                    ),
                    const SizedBox(width: 16),
                    _InfoCard(
                      icon: Icons.calendar_today,
                      title: _isYearly ? 'Tenure' : 'Tenure',
                      value: _isYearly ? '${(widget.tenureMonths / 12).toStringAsFixed(1)} Years' : '${widget.tenureMonths} Months',
                    ),
                    const SizedBox(width: 16),
                    _InfoCard(
                      icon: Icons.payments,
                      title: 'EMI',
                      value: currencyFormat.format(widget.emi),
                    ),
                  ],
                ),
              ),
            ),
          ),
          // EMI Start From Row
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            child: Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: _pickStartDate,
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFeaf6fb),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFF3498db).withOpacity(0.3)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.calendar_month, color: Color(0xFF3498db), size: 20),
                          const SizedBox(width: 12),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'EMI Start From',
                                style: TextStyle(
                                  color: Color(0xFF3498db),
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              Text(
                                DateFormat('MMM yyyy').format(DateTime(_emiStartYear, _emiStartMonth)),
                                style: const TextStyle(
                                  color: Color(0xFF3498db),
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          const Spacer(),
                          const Icon(Icons.edit_calendar, color: Color(0xFF3498db), size: 20),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          // View Type and Export Buttons Row
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
            child: Row(
              children: [
                // View Type Selection
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFeaf6fb),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFF3498db).withOpacity(0.3)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Radio<bool>(
                        value: false,
                        groupValue: _isYearly,
                        onChanged: (v) => setState(() => _isYearly = false),
                        activeColor: const Color(0xFF3498db),
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      const Text('Monthly', style: TextStyle(fontSize: 12)),
                      Radio<bool>(
                        value: true,
                        groupValue: _isYearly,
                        onChanged: (v) => setState(() => _isYearly = true),
                        activeColor: const Color(0xFF3498db),
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      const Text('Yearly', style: TextStyle(fontSize: 12)),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                // Export Buttons
                _ExportButton(
                  icon: Icons.picture_as_pdf,
                  label: 'PDF',
                  color: const Color(0xFF3498db),
                  onPressed: _exportPdf,
                ),
                const SizedBox(width: 8),
                _ExportButton(
                  icon: Icons.table_chart,
                  label: 'Excel',
                  color: const Color(0xFF2ecc71),
                  onPressed: _exportExcel,
                ),
              ],
            ),
          ),
          // Data Table
          Expanded(
            child: Card(
              margin: const EdgeInsets.all(16),
              elevation: 4,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  return SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: ConstrainedBox(
                      constraints: BoxConstraints(minWidth: constraints.maxWidth),
                      child: SingleChildScrollView(
                        child: DataTable(
                          columnSpacing: 24,
                          headingRowColor: MaterialStateProperty.all(const Color(0xFFeaf6fb)),
                          dataRowColor: MaterialStateProperty.all(Colors.white),
                          headingTextStyle: const TextStyle(
                            color: Color(0xFF3498db),
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                          dataTextStyle: const TextStyle(
                            color: Color(0xFF2c3e50),
                            fontSize: 13,
                          ),
                          columns: _isYearly
                              ? const [
                                  DataColumn(label: Text('Sr.')),
                                  DataColumn(label: Text('Year')),
                                  DataColumn(label: Text('Principal')),
                                  DataColumn(label: Text('Interest')),
                                  DataColumn(label: Text('Outstanding')),
                                ]
                              : const [
                                  DataColumn(label: Text('Sr.')),
                                  DataColumn(label: Text('Month')),
                                  DataColumn(label: Text('Principal')),
                                  DataColumn(label: Text('Interest')),
                                  DataColumn(label: Text('Outstanding')),
                                ],
                          rows: [
                            for (int i = 0; i < _displayData.length; i++)
                              _isYearly
                                  ? DataRow(cells: [
                                      DataCell(Text('${i + 1}')),
                                      DataCell(Text(_displayData[i]['year'].toString())),
                                      DataCell(Text(currencyFormat.format(_displayData[i]['principal']))),
                                      DataCell(Text(currencyFormat.format(_displayData[i]['interest']))),
                                      DataCell(Text(currencyFormat.format(_displayData[i]['outstanding']))),
                                    ])
                                  : DataRow(cells: [
                                      DataCell(Text('${i + 1}')),
                                      DataCell(Text(monthFormat.format(DateTime(_emiStartDate.year, _emiStartDate.month + i)))),
                                      DataCell(Text(currencyFormat.format(_displayData[i]['principal']))),
                                      DataCell(Text(currencyFormat.format(_displayData[i]['interest']))),
                                      DataCell(Text(currencyFormat.format(_displayData[i]['outstanding']))),
                                    ]),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;

  const _InfoCard({
    required this.icon,
    required this.title,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          Icon(icon, color: Colors.white, size: 20),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 12,
                ),
              ),
              Text(
                value,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ExportButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onPressed;

  const _ExportButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: Colors.white, size: 16),
              const SizedBox(width: 4),
              Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
} 