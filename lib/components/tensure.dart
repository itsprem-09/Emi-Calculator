import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'dart:math' as math;

import '../models/emi_model.dart';
import '../utils/formatter.dart';

class Tensure extends StatefulWidget {
  const Tensure({super.key});

  @override
  State<Tensure> createState() => _TensureState();
}

class _TensureState extends State<Tensure> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _loanAmountController = TextEditingController();
  final TextEditingController _emiController = TextEditingController();
  final TextEditingController _interestRateController = TextEditingController();

  bool _hasCalculated = false;
  double _principal = 0;
  double _emi = 0;
  double _rate = 0;
  int _tenureMonths = 0;
  double _interest = 0;
  double _total = 0;
  double _principalPercent = 0;
  double _interestPercent = 0;

  List<Map<String, dynamic>> _history = [];

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  @override
  void dispose() {
    _loanAmountController.dispose();
    _emiController.dispose();
    _interestRateController.dispose();
    super.dispose();
  }

  Future<void> _loadHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final historyJson = prefs.getStringList('tenure_history');
    if (historyJson != null) {
      setState(() {
        _history = historyJson.map((item) => json.decode(item) as Map<String, dynamic>).toList();
      });
    }
  }

  Future<void> _saveCalculation() async {
    final prefs = await SharedPreferences.getInstance();
    final calculation = {
      'loanAmount': _principal,
      'emi': _emi,
      'interestRate': _rate,
      'tenureMonths': _tenureMonths,
      'interest': _interest,
      'total': _total,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    };
    _history.insert(0, calculation);
    final historyJson = _history.map((item) => json.encode(item)).toList();
    await prefs.setStringList('tenure_history', historyJson);
  }

  double _parseLoanAmount() {
    try {
      final amountText = _loanAmountController.text.replaceAll(RegExp(r'[^\d.]'), '');
      return double.tryParse(amountText) ?? 0.0;
    } catch (e) {
      return 0.0;
    }
  }

  double _parseEmi() {
    try {
      final emiText = _emiController.text.replaceAll(RegExp(r'[^\d.]'), '');
      return double.tryParse(emiText) ?? 0.0;
    } catch (e) {
      return 0.0;
    }
  }

  void _resetFields() {
    setState(() {
      _loanAmountController.clear();
      _emiController.clear();
      _interestRateController.clear();
      _hasCalculated = false;
    });
  }

  void _calculateTenure() {
    if (_formKey.currentState!.validate()) {
      final principal = _parseLoanAmount();
      final emi = _parseEmi();
      final rate = double.tryParse(_interestRateController.text) ?? 0.0;
      if (principal <= 0 || emi <= 0 || rate <= 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please enter valid values greater than zero')),
        );
        return;
      }
      final r = rate / 12 / 100;
      if (emi <= principal * r) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: Row(
              children: const [
                Icon(Icons.warning_amber_rounded, color: Colors.grey, size: 32),
                SizedBox(width: 8),
                Text('Alert'),
              ],
            ),
            content: Text('Enter your EMI more than ${(principal * r).toStringAsFixed(1)}'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('OK'),
              ),
            ],
          ),
        );
        return;
      }
      // n = (log(E) - log(E - P*r)) / log(1 + r)
      final n = (math.log(emi) - math.log(emi - principal * r)) / math.log(1 + r);
      final tenureMonths = n.ceil();
      final total = emi * tenureMonths;
      final interest = total - principal;
      setState(() {
        _principal = principal;
        _emi = emi;
        _rate = rate;
        _tenureMonths = tenureMonths;
        _interest = interest;
        _total = total;
        _principalPercent = (principal / total) * 100;
        _interestPercent = (interest / total) * 100;
        _hasCalculated = true;
      });
    }
  }

  void _showHistory() {
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
                          final calculation = _history[index];
                          return Card(
                            elevation: 2,
                            margin: const EdgeInsets.symmetric(vertical: 8.0),
                            child: ListTile(
                              title: Text(
                                'Tenure: ${calculation['tenureMonths']} months',
                                style: const TextStyle(fontWeight: FontWeight.bold),
                              ),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Loan: ${Formatter.formatCurrency(calculation['loanAmount'])}'),
                                  Text('EMI: ${Formatter.formatCurrency(calculation['emi'])} @ ${calculation['interestRate']}%'),
                                  Text('Total: ${Formatter.formatCurrency(calculation['total'])}'),
                                ],
                              ),
                              trailing: Text(
                                DateTime.fromMillisecondsSinceEpoch(calculation['timestamp']).toString().split(' ')[0],
                                style: const TextStyle(color: Colors.grey),
                              ),
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

  void _showSchedule() {
    final emiModel = EmiModel(
      loanAmount: _principal,
      interestRate: _rate,
      tenure: _tenureMonths,
      isYears: false,
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
                  IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
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
                          Text(Formatter.formatCurrency(remainingPrincipal)),
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
              'Calculate Loan Tenure',
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
                  const Text(
                    'Loan Amount',
                    style: TextStyle(
                      color: Colors.black,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  TextFormField(
                    controller: _loanAmountController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: false),
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      _AmountInputFormatter(),
                    ],
                    decoration: InputDecoration(
                      suffixIcon: Container(
                        padding: const EdgeInsets.all(12),
                        child: const Text('₹', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
                      ),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8.0)),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter loan amount';
                      }
                      return null;
                    },
                    onChanged: (value) {
                      setState(() {});
                    },
                  ),
                  const SizedBox(height: 4),
                  Text(
                    NumberToWords.convertToWords(_parseLoanAmount()),
                    style: const TextStyle(
                      color: Colors.grey,
                      fontSize: 12,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text('EMI', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black)),
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
                      setState(() {});
                    },
                  ),
                  const SizedBox(height: 16),
                  const Text('Interest Rate Per Year', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black)),
                  TextFormField(
                    controller: _interestRateController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
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
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      SizedBox(
                        width: buttonWidth,
                        height: buttonHeight,
                        child: ElevatedButton.icon(
                          onPressed: _calculateTenure,
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
                          onPressed: _resetFields,
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
                    Center(
                      child: Column(
                        children: [
                          const Text('Tenure (in Months)', style: TextStyle(color: Colors.blueAccent, fontSize: 18, fontWeight: FontWeight.bold)),
                          Text('$_tenureMonths', style: const TextStyle(color: Colors.blueAccent, fontSize: 48, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
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
                          Wrap(
                            spacing: isSmallScreen ? 8 : 16,
                            runSpacing: isSmallScreen ? 8 : 16,
                            alignment: WrapAlignment.center,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              _buildResultItem('Principal Amount', Formatter.formatCurrency(_principal), '${_principalPercent.toStringAsFixed(2)}%', Colors.green[800]!),
                              const Text('+', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 24)),
                              _buildResultItem('Interest Payable', Formatter.formatCurrency(_interest), '${_interestPercent.toStringAsFixed(2)}%', Colors.red[800]!),
                              const Text('=', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 24)),
                              _buildResultItem('Total Payment', Formatter.formatCurrency(_total), '', Colors.green[800]!),
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
                            onPressed: () {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Share functionality not implemented')),
                              );
                            },
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
                            onPressed: () {
                              _saveCalculation();
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Calculation saved successfully!')),
                              );
                            },
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
    final decimalPart = parts.length > 1 ? '.{parts[1]}' : '';

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
