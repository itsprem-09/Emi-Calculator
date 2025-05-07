import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'dart:math' as math;

import '../models/emi_model.dart';
import '../utils/formatter.dart';

class Emi extends StatefulWidget {
  const Emi({super.key});

  @override
  State<Emi> createState() => _EmiState();
}

class _EmiState extends State<Emi> with SingleTickerProviderStateMixin {

  final _formKey = GlobalKey<FormState>();

  // Controllers for the input fields
  final TextEditingController _loanAmountController =
  TextEditingController(text: '10,00,000');
  final TextEditingController _interestRateController =
  TextEditingController(text: '12.5');
  final TextEditingController _tenureController =
  TextEditingController(text: '20');


  // State variables
  bool _isYears = true;
  bool _hasCalculated = false;

  // Results
  double _emiAmount = 0;
  double _totalInterest = 0;
  double _totalPayment = 0;
  double _principalPercentage = 0;
  double _interestPercentage = 0;

  // History of calculations
  List<Map<String, dynamic>> _calculationHistory = [];

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  @override
  void dispose() {
    _loanAmountController.dispose();
    _interestRateController.dispose();
    _tenureController.dispose();
    super.dispose();
  }

  Future<void> _loadHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final historyJson = prefs.getStringList('calculation_history');

    if (historyJson != null) {
      setState(() {
        _calculationHistory = historyJson
            .map((item) => json.decode(item) as Map<String, dynamic>)
            .toList();
      });
    }
  }

  Future<void> _saveCalculation() async {
    final prefs = await SharedPreferences.getInstance();

    final calculation = {
      'loanAmount': _parseLoanAmount(),
      'interestRate': double.parse(_interestRateController.text),
      'tenure': int.parse(_tenureController.text),
      'isYears': _isYears,
      'emiAmount': _emiAmount,
      'totalInterest': _totalInterest,
      'totalPayment': _totalPayment,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    };

    _calculationHistory.insert(0, calculation);

    final historyJson =
    _calculationHistory.map((item) => json.encode(item)).toList();

    await prefs.setStringList('calculation_history', historyJson);
  }

  void _calculateEmi() {
    if (_formKey.currentState!.validate()) {
      try {
        final loanAmount = _parseLoanAmount();
        final interestRate =
            double.tryParse(_interestRateController.text) ?? 0.0;
        final tenure = int.tryParse(_tenureController.text) ?? 0;

        if (loanAmount <= 0 || tenure <= 0) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text('Please enter valid values greater than zero')),
          );
          return;
        }

        final emiModel = EmiModel(
          loanAmount: loanAmount,
          interestRate: interestRate,
          tenure: tenure,
          isYears: _isYears,
        );

        setState(() {
          _emiAmount = emiModel.monthlyEmi;
          _totalInterest = emiModel.totalInterestPayable;
          _totalPayment = emiModel.totalPayment;
          _principalPercentage = emiModel.principalPercentage;
          _interestPercentage = emiModel.interestPercentage;
          _hasCalculated = true;
        });
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Calculation error: ${e.toString()}')),
        );
      }
    }
  }

  double _parseLoanAmount() {
    try {
      // Remove commas and other non-numeric characters from the loan amount
      final amountText =
      _loanAmountController.text.replaceAll(RegExp(r'[^\d.]'), '');
      return double.tryParse(amountText) ?? 0.0;
    } catch (e) {
      return 0.0; // Return 0 as a fallback
    }
  }

  void _resetFields() {
    setState(() {
      _loanAmountController.text = '10,00,000';
      _interestRateController.text = '12.5';
      _tenureController.text = '20';
      _isYears = true;
      _hasCalculated = false;
    });
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
                  Text(
                    'Calculation History',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const Divider(),
              Expanded(
                child: _calculationHistory.isEmpty
                    ? const Center(
                  child: Text('No calculation history found'),
                )
                    : ListView.builder(
                  itemCount: _calculationHistory.length,
                  itemBuilder: (context, index) {
                    final calculation = _calculationHistory[index];
                    return Card(
                      elevation: 2,
                      margin: const EdgeInsets.symmetric(vertical: 8.0),
                      child: ListTile(
                        title: Text(
                          'EMI: ${Formatter.formatCurrency(calculation['emiAmount'])}',
                          style: const TextStyle(
                              fontWeight: FontWeight.bold),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Loan: ${Formatter.formatCurrency(calculation['loanAmount'])} @ ${calculation['interestRate']}%',
                            ),
                            Text(
                              'Tenure: ${calculation['tenure']} ${calculation['isYears'] ? 'years' : 'months'}',
                            ),
                            Text(
                              'Total: ${Formatter.formatCurrency(calculation['totalPayment'])}',
                            ),
                          ],
                        ),
                        trailing: Text(
                          DateTime.fromMillisecondsSinceEpoch(
                            calculation['timestamp'],
                          ).toString().split(' ')[0],
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
    final loanAmount = _parseLoanAmount();
    final interestRate = double.parse(_interestRateController.text);
    final tenure = int.parse(_tenureController.text);

    final emiModel = EmiModel(
      loanAmount: loanAmount,
      interestRate: interestRate,
      tenure: tenure,
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
                  Text(
                    'Amortization Schedule',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
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
                  const Text('Month',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  const Text('Remaining Principal',
                      style: TextStyle(fontWeight: FontWeight.bold)),
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
              'Calculate EMI',
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
                  // Loan Amount Input
                  const Text(
                    'Loan/Principal Amount',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  TextFormField(
                    controller: _loanAmountController,
                    keyboardType:
                    const TextInputType.numberWithOptions(decimal: false),
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      _AmountInputFormatter(),
                    ],
                    decoration: InputDecoration(
                      suffixIcon: Container(
                        padding: const EdgeInsets.all(12),
                        child: const Text(
                          '₹',
                          style: TextStyle(
                            color: Colors.grey,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8.0),
                      ),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter loan amount';
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
                    NumberToWords.convertToWords(_parseLoanAmount()),
                    style: const TextStyle(
                      color: Colors.grey,
                      fontSize: 12,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Interest Rate Input
                  const Text(
                    'Interest Rate Per Year',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  TextFormField(
                    controller: _interestRateController,
                    keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(
                          RegExp(r'^\d*\.?\d{0,2}')),
                    ],
                    decoration: InputDecoration(
                      suffixIcon: Container(
                        padding: const EdgeInsets.all(12),
                        child: const Text(
                          '%',
                          style: TextStyle(
                            color: Colors.grey,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8.0),
                      ),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter interest rate';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),

                  // Tenure Input
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Tenure in Years',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.grey[200],
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          children: [
                            GestureDetector(
                              onTap: () {
                                setState(() {
                                  _isYears = true;
                                });
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 8,
                                ),
                                decoration: BoxDecoration(
                                  color: _isYears
                                      ? Theme.of(context).primaryColor
                                      : Colors.transparent,
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  'YEARS',
                                  style: TextStyle(
                                    color:
                                    _isYears ? Colors.white : Colors.grey,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            ),
                            GestureDetector(
                              onTap: () {
                                setState(() {
                                  _isYears = false;
                                });
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 8,
                                ),
                                decoration: BoxDecoration(
                                  color: !_isYears
                                      ? Theme.of(context).primaryColor
                                      : Colors.transparent,
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  'MONTHS',
                                  style: TextStyle(
                                    color: !_isYears
                                        ? Colors.white
                                        : Colors.grey,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                  ),
                                ),
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
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                    ],
                    decoration: InputDecoration(
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8.0),
                      ),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter tenure';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 24),

                  // Action Buttons
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      SizedBox(
                        width: buttonWidth,
                        height: buttonHeight,
                        child: ElevatedButton.icon(
                          onPressed: _calculateEmi,
                          icon: const Icon(Icons.calculate, color: Colors.white, size: 20),
                          label: const Text(
                            'Calculate',
                            style: TextStyle(color: Colors.white, fontSize: 12),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF3498db),
                            padding: EdgeInsets.zero,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        ),
                      ),
                      SizedBox(
                        width: buttonWidth,
                        height: buttonHeight,
                        child: ElevatedButton.icon(
                          onPressed: _resetFields,
                          icon: const Icon(Icons.refresh, color: Colors.white, size: 20),
                          label: const Text(
                            'Reset',
                            style: TextStyle(color: Colors.white, fontSize: 12),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.grey[600],
                            padding: EdgeInsets.zero,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        ),
                      ),
                      SizedBox(
                        width: buttonWidth,
                        height: buttonHeight,
                        child: ElevatedButton.icon(
                          onPressed: _showHistory,
                          icon: const Icon(Icons.history, color: Colors.white, size: 20),
                          label: const Text(
                            'History',
                            style: TextStyle(color: Colors.white, fontSize: 12),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF2ecc71),
                            padding: EdgeInsets.zero,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: isSmallScreen ? 24 : 32),

                  // Results
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
                          const Text(
                            'EMI',
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.grey,
                            ),
                          ),
                          Text(
                            Formatter.formatCurrency(_emiAmount),
                            style: TextStyle(
                              fontSize: isSmallScreen ? 28 : 36,
                              fontWeight: FontWeight.bold,
                              color: const Color(0xFF3498db),
                            ),
                          ),
                          SizedBox(height: isSmallScreen ? 16 : 24),
                          Wrap(
                            spacing: isSmallScreen ? 8 : 16,
                            runSpacing: isSmallScreen ? 16 : 24,
                            alignment: WrapAlignment.spaceEvenly,
                            children: [
                              _buildResultItem(
                                'Principal Amount',
                                Formatter.formatCurrency(_parseLoanAmount()),
                                '${_principalPercentage.toStringAsFixed(2)}%',
                                Colors.green[800]!,
                              ),
                              _buildResultItem(
                                'Interest Payable',
                                Formatter.formatCurrency(_totalInterest),
                                '${_interestPercentage.toStringAsFixed(2)}%',
                                Colors.red[800]!,
                              ),
                              _buildResultItem(
                                'Total Payment',
                                Formatter.formatCurrency(_totalPayment),
                                '',
                                Colors.grey[800]!,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: isSmallScreen ? 16 : 24),

                    // Bottom Action Buttons
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
                            label: const Text(
                              'Schedule',
                              style: TextStyle(color: Colors.white, fontSize: 12),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF34495e),
                              padding: EdgeInsets.zero,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                          ),
                        ),
                        SizedBox(
                          width: buttonWidth,
                          height: buttonHeight,
                          child: ElevatedButton.icon(
                            onPressed: () {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Share functionality not implemented'),
                                ),
                              );
                            },
                            icon: const Icon(Icons.share, color: Colors.white, size: 20),
                            label: const Text(
                              'Share',
                              style: TextStyle(color: Colors.white, fontSize: 12),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF9b59b6),
                              padding: EdgeInsets.zero,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
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
                                const SnackBar(
                                  content: Text('Calculation saved successfully!'),
                                ),
                              );
                            },
                            icon: const Icon(Icons.save, color: Colors.white, size: 20),
                            label: const Text(
                              'Save',
                              style: TextStyle(color: Colors.white, fontSize: 12),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF27ae60),
                              padding: EdgeInsets.zero,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
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
      constraints: BoxConstraints(
        minWidth: 100,
        maxWidth: 120,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Flexible(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Colors.grey,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 4),
                const Icon(
                  Icons.add,
                  size: 14,
                  color: Colors.grey,
                ),
              ],
            ),
          ),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              value,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          if (percentage.isNotEmpty)
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                percentage,
                style: TextStyle(
                  fontSize: 12,
                  color: percentageColor,
                ),
              ),
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
