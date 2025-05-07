import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/services.dart';
import '../models/emi_model.dart';
import '../utils/formatter.dart';

class EmiCalculation {
  final int emi;
  final double rate;
  final int tenureYears;
  final int tenureMonths;
  final double principal;
  final double interest;
  final double total;
  final DateTime date;

  EmiCalculation({
    required this.emi,
    required this.rate,
    required this.tenureYears,
    required this.tenureMonths,
    required this.principal,
    required this.interest,
    required this.total,
    required this.date,
  });

  Map<String, dynamic> toJson() => {
        'emi': emi,
        'rate': rate,
        'tenureYears': tenureYears,
        'tenureMonths': tenureMonths,
        'principal': principal,
        'interest': interest,
        'total': total,
        'date': date.toIso8601String(),
      };

  static EmiCalculation fromJson(Map<String, dynamic> json) => EmiCalculation(
        emi: json['emi'],
        rate: json['rate'],
        tenureYears: json['tenureYears'],
        tenureMonths: json['tenureMonths'],
        principal: json['principal'],
        interest: json['interest'],
        total: json['total'],
        date: DateTime.parse(json['date']),
      );
}

class Amount extends StatefulWidget {
  const Amount({super.key});

  @override
  State<Amount> createState() => _AmountState();
}

class _AmountState extends State<Amount> {
  final _formKey = GlobalKey<FormState>();
  final _emiController = TextEditingController();
  final _rateController = TextEditingController();
  final _tenureController = TextEditingController();
  bool _isYears = true;

  double? _principal, _interest, _total;
  int? _emi, _tenure;
  double? _rate;
  bool _hasCalculated = false;

  List<EmiCalculation> _history = [];

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  @override
  void dispose() {
    _emiController.dispose();
    _rateController.dispose();
    _tenureController.dispose();
    super.dispose();
  }

  void _calculate() {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _emi = int.tryParse(_emiController.text.replaceAll(',', ''));
      _rate = double.tryParse(_rateController.text);
      _tenure = int.tryParse(_tenureController.text);
      if (_emi == null || _rate == null || _tenure == null) {
        _principal = _interest = _total = null;
        _hasCalculated = false;
        return;
      }
      int months = _isYears ? _tenure! * 12 : _tenure!;
      double r = _rate! / 12 / 100;
      double principal = _emi! * ((1 - (1 / (pow(1 + r, months)))) / r);
      double total = _emi! * months.toDouble();
      double interest = total - principal;
      _principal = principal;
      _interest = interest;
      _total = total;
      _hasCalculated = true;
    });
  }

  void _reset() {
    setState(() {
      _emiController.clear();
      _rateController.clear();
      _tenureController.clear();
      _principal = _interest = _total = null;
      _hasCalculated = false;
    });
  }

  Future<void> _saveCalculation() async {
    if (_emi == null || _rate == null || _tenure == null || _principal == null || _interest == null || _total == null) return;
    final calc = EmiCalculation(
      emi: _emi!,
      rate: _rate!,
      tenureYears: _isYears ? _tenure! : 0,
      tenureMonths: !_isYears ? _tenure! : 0,
      principal: _principal!,
      interest: _interest!,
      total: _total!,
      date: DateTime.now(),
    );
    setState(() {
      _history.insert(0, calc);
    });
    final prefs = await SharedPreferences.getInstance();
    final list = _history.map((e) => jsonEncode(e.toJson())).toList();
    await prefs.setStringList('emi_history', list);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Calculation saved!')));
  }

  Future<void> _loadHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList('emi_history') ?? [];
    setState(() {
      _history = list.map((e) => EmiCalculation.fromJson(jsonDecode(e))).toList();
    });
  }

  void _showHistory() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.7,
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Calculation History', style: Theme.of(context).textTheme.titleLarge),
                IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
              ],
            ),
            const Divider(),
            Expanded(
              child: _history.isEmpty
                  ? const Center(child: Text('No calculation history found'))
                  : ListView.builder(
                      itemCount: _history.length,
                      itemBuilder: (context, index) {
                        final e = _history[index];
                        return Card(
                          elevation: 2,
                          margin: const EdgeInsets.symmetric(vertical: 8.0),
                          child: ListTile(
                            title: Text(
                              'EMI: ${Formatter.formatCurrency(e.emi.toDouble())}',
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Principal: ${Formatter.formatCurrency(e.principal)} @ ${e.rate}%',
                                ),
                                Text(
                                  'Tenure: ${e.tenureYears > 0 ? '${e.tenureYears} years' : '${e.tenureMonths} months'}',
                                ),
                                Text(
                                  'Total: ${Formatter.formatCurrency(e.total)}',
                                ),
                              ],
                            ),
                            trailing: Text(
                              e.date.toString().split(' ')[0],
                              style: const TextStyle(color: Colors.grey),
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  void _showSchedule() {
    if (_emi == null || _rate == null || _tenure == null) return;
    final emiModel = EmiModel(
      loanAmount: _principal ?? 0,
      interestRate: _rate!,
      tenure: _isYears ? _tenure! : _tenure!,
      isYears: _isYears,
    );
    final schedule = emiModel.generateAmortizationSchedule();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (BuildContext context) {
        return Container(
          height: MediaQuery.of(context).size.height * 0.7,
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Amortization Schedule', style: Theme.of(context).textTheme.titleLarge),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const Divider(),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Month', style: TextStyle(fontWeight: FontWeight.bold)),
                  const Text('Remaining Principal', style: TextStyle(fontWeight: FontWeight.bold)),
                ],
              ),
              const SizedBox(height: 8),
              Expanded(
                child: ListView.builder(
                  itemCount: schedule.length,
                  itemBuilder: (context, index) {
                    final month = (index + 1).toString();
                    final remainingPrincipal = schedule[month] ?? 0.0;
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(month),
                          Text(_formatIndianCurrency(remainingPrincipal)),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  String _formatIndian(int value) {
    return Formatter.formatCurrency(value.toDouble());
  }

  String _formatIndianCurrency(double value) {
    return Formatter.formatCurrency(value);
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final isSmallScreen = screenSize.width < 600;
    final padding = isSmallScreen ? 16.0 : 24.0;
    final buttonHeight = isSmallScreen ? 40.0 : 48.0;
    final buttonWidth = isSmallScreen ? 100.0 : 120.0;

    return SingleChildScrollView(
      child: Column(
        children: [
          Container(
            color: const Color(0xFF3498db),
            padding: EdgeInsets.symmetric(horizontal: padding, vertical: 12.0),
            width: double.infinity,
            child: Text(
              'Calculate Loan Amount',
              style: TextStyle(
                color: Colors.white,
                fontSize: isSmallScreen ? 20 : 24,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          Padding(
            padding: EdgeInsets.all(padding),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // const Text('One Lakh', style: TextStyle(color: Colors.red, fontSize: 12)),
                  const SizedBox(height: 4),
                  const Text('EMI', style: TextStyle(fontWeight: FontWeight.bold)),
                  TextFormField(
                    controller: _emiController,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly, _AmountInputFormatter()],
                    decoration: InputDecoration(
                      suffixIcon: Container(
                        padding: const EdgeInsets.all(12),
                        child: const Text('₹', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
                      ),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8.0)),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter EMI';
                      }
                      return null;
                    },
                    onChanged: (value) {
                      setState(() {
                        // Trigger rebuild to update amount in words
                      });
                    },
                  ),
                  const SizedBox(height: 4),
                  Text(
                    NumberToWords.convertToWords(double.tryParse(_emiController.text.replaceAll(',', '')) ?? 0),
                    style: const TextStyle(
                      color: Colors.grey,
                      fontSize: 12,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text('Interest Rate Per Year', style: TextStyle(fontWeight: FontWeight.bold)),
                  TextFormField(
                    controller: _rateController,
                    keyboardType: TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}'))],
                    decoration: InputDecoration(
                      suffixIcon: Container(
                        padding: const EdgeInsets.all(12),
                        child: const Text('%', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
                      ),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8.0)),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter interest rate';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Tenure in Years', style: TextStyle(fontWeight: FontWeight.bold)),
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.grey[200],
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          children: [
                            GestureDetector(
                              onTap: () => setState(() => _isYears = true),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                decoration: BoxDecoration(
                                  color: _isYears ? Theme.of(context).primaryColor : Colors.transparent,
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text('YEARS', style: TextStyle(color: _isYears ? Colors.white : Colors.grey, fontWeight: FontWeight.bold, fontSize: 12)),
                              ),
                            ),
                            GestureDetector(
                              onTap: () => setState(() => _isYears = false),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                decoration: BoxDecoration(
                                  color: !_isYears ? Theme.of(context).primaryColor : Colors.transparent,
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text('MONTHS', style: TextStyle(color: !_isYears ? Colors.white : Colors.grey, fontWeight: FontWeight.bold, fontSize: 12)),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _tenureController,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: InputDecoration(
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8.0)),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter tenure';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      SizedBox(
                        width: buttonWidth,
                        height: buttonHeight,
                        child: ElevatedButton.icon(
                          onPressed: _calculate,
                          icon: const Icon(Icons.calculate, color: Colors.white, size: 20),
                          label: const Text('Calculate', style: TextStyle(color: Colors.white, fontSize: 12)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF3498db),
                            padding: EdgeInsets.zero,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                        ),
                      ),
                      SizedBox(
                        width: buttonWidth,
                        height: buttonHeight,
                        child: ElevatedButton.icon(
                          onPressed: _reset,
                          icon: const Icon(Icons.refresh, color: Colors.white, size: 20),
                          label: const Text('Reset', style: TextStyle(color: Colors.white, fontSize: 12)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.grey[600],
                            padding: EdgeInsets.zero,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                        ),
                      ),
                      SizedBox(
                        width: buttonWidth,
                        height: buttonHeight,
                        child: ElevatedButton.icon(
                          onPressed: _showHistory,
                          icon: const Icon(Icons.history, color: Colors.white, size: 20),
                          label: const Text('History', style: TextStyle(color: Colors.white, fontSize: 12)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF2ecc71),
                            padding: EdgeInsets.zero,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: isSmallScreen ? 24 : 32),
                  if (_hasCalculated) ...[
                    Container(
                      width: double.infinity,
                      padding: EdgeInsets.all(isSmallScreen ? 16 : 24),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.grey.withOpacity(0.3),
                            spreadRadius: 1,
                            blurRadius: 5,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          const Text('Amount', style: TextStyle(fontSize: 16, color: Colors.grey)),
                          Text('${_formatIndianCurrency(_principal ?? 0)}', style: TextStyle(fontSize: isSmallScreen ? 28 : 36, fontWeight: FontWeight.bold, color: const Color(0xFF3498db))),
                          SizedBox(height: isSmallScreen ? 16 : 24),
                          Wrap(
                            spacing: isSmallScreen ? 8 : 16,
                            runSpacing: isSmallScreen ? 16 : 24,
                            alignment: WrapAlignment.spaceEvenly,
                            children: [
                              _buildResultItem('Principal Amount', '${_formatIndianCurrency(_principal ?? 0)}', '${((_principal! / _total!) * 100).toStringAsFixed(2)}%', Colors.green[800]!),
                              _buildResultItem('Interest Payable', '${_formatIndianCurrency(_interest ?? 0)}', '${((_interest! / _total!) * 100).toStringAsFixed(2)}%', Colors.red[800]!),
                              _buildResultItem('Total Payment', '${_formatIndianCurrency(_total ?? 0)}', '', Colors.blue[800]!),
                            ],
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: isSmallScreen ? 16 : 24),
                    Wrap(
                      spacing: isSmallScreen ? 8 : 12,
                      runSpacing: isSmallScreen ? 8 : 12,
                      alignment: WrapAlignment.spaceEvenly,
                      children: [
                        SizedBox(
                          width: buttonWidth,
                          height: buttonHeight,
                          child: ElevatedButton.icon(
                            onPressed: _showSchedule,
                            icon: const Icon(Icons.schedule, color: Colors.white, size: 20),
                            label: const Text('Schedule', style: TextStyle(color: Colors.white, fontSize: 12)),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF34495e),
                              padding: EdgeInsets.zero,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                          ),
                        ),
                        SizedBox(
                          width: buttonWidth,
                          height: buttonHeight,
                          child: ElevatedButton.icon(
                            onPressed: () {},
                            icon: const Icon(Icons.share, color: Colors.white, size: 20),
                            label: const Text('Share', style: TextStyle(color: Colors.white, fontSize: 12)),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF9b59b6),
                              padding: EdgeInsets.zero,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                          ),
                        ),
                        SizedBox(
                          width: buttonWidth,
                          height: buttonHeight,
                          child: ElevatedButton.icon(
                            onPressed: _saveCalculation,
                            icon: const Icon(Icons.save, color: Colors.white, size: 20),
                            label: const Text('Save', style: TextStyle(color: Colors.white, fontSize: 12)),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF27ae60),
                              padding: EdgeInsets.zero,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResultItem(String title, String value, String percentage, Color percentageColor) {
    return Container(
      constraints: const BoxConstraints(minWidth: 100, maxWidth: 120),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(title, style: const TextStyle(fontSize: 12, color: Colors.grey)),
          ),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(value, style: const TextStyle(fontWeight: FontWeight.bold), textAlign: TextAlign.center),
          ),
          if (percentage.isNotEmpty)
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(percentage, style: TextStyle(fontSize: 12, color: percentageColor)),
            ),
        ],
      ),
    );
  }
}

// Custom input formatter for amount with commas
class _AmountInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue,
      TextEditingValue newValue,
      ) {
    if (newValue.text.isEmpty) {
      return newValue;
    }

    // Remove all non-digits
    final digits = newValue.text.replaceAll(RegExp(r'[^\d]'), '');

    // Format with commas (Indian number system)
    final formattedValue = _formatWithIndianNumberSystem(digits);

    return TextEditingValue(
      text: formattedValue,
      selection: TextSelection.collapsed(offset: formattedValue.length),
    );
  }

  String _formatWithIndianNumberSystem(String input) {
    if (input.isEmpty) return input;

    // Split off any decimal portion
    final parts = input.split('.');
    final integerPart = parts[0];
    final decimalPart = parts.length > 1 ? '.${parts[1]}' : '';

    // If ≤3 digits, no commas needed
    if (integerPart.length <= 3) {
      return '$integerPart$decimalPart';
    }

    // Last 3 digits, and everything left of them
    final lastThree = integerPart.substring(integerPart.length - 3);
    final rest = integerPart.substring(0, integerPart.length - 3);

    // Place commas every 2 digits in the 'rest'
    final reg = RegExp(r'\B(?=(\d{2})+(?!\d))');
    final formattedRest = rest.replaceAll(reg, ',');

    return '$formattedRest,$lastThree$decimalPart';
  }
}
