import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'dart:math' as math;
import '../utils/formatter.dart';
import '../models/emi_model.dart';
import 'schedule.dart';
import 'package:share_plus/share_plus.dart';

class Roi extends StatefulWidget {
  const Roi({super.key});

  @override
  State<Roi> createState() => _RoiState();
}

class _RoiState extends State<Roi> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _loanAmountController = TextEditingController();
  final TextEditingController _emiController = TextEditingController();
  final TextEditingController _tenureController = TextEditingController();
  bool _isYears = true;

  bool _hasCalculated = false;
  double _principal = 0;
  double _emi = 0;
  int _tenure = 0;
  double _rate = 0;
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
    _tenureController.dispose();
    super.dispose();
  }

  Future<void> _loadHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final historyJson = prefs.getStringList('roi_history');
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
      'rate': _rate,
      'tenure': _tenure,
      'isYears': _isYears,
      'interest': _interest,
      'total': _total,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    };
    _history.insert(0, calculation);
    final historyJson = _history.map((item) => json.encode(item)).toList();
    await prefs.setStringList('roi_history', historyJson);
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
      _tenureController.clear();
      _isYears = true;
      _hasCalculated = false;
    });
  }

  // Numerical method to estimate interest rate from EMI, principal, and tenure
  double _calculateRate({required double principal, required double emi, required int tenureMonths}) {
    double low = 0.0;
    double high = 100.0;
    double guess = 0.0;
    for (int i = 0; i < 100; i++) {
      guess = (low + high) / 2;
      double r = guess / 12 / 100;
      double calculatedEmi = principal * r * math.pow(1 + r, tenureMonths) / (math.pow(1 + r, tenureMonths) - 1);
      if (calculatedEmi.isNaN || calculatedEmi.isInfinite) break;
      if ((calculatedEmi - emi).abs() < 0.01) break;
      if (calculatedEmi > emi) {
        high = guess;
      } else {
        low = guess;
      }
    }
    return guess;
  }

  void _calculateRoi() {
    if (_formKey.currentState!.validate()) {
      final principal = _parseLoanAmount();
      final emi = _parseEmi();
      final tenure = int.tryParse(_tenureController.text) ?? 0;
      if (principal <= 0 || emi <= 0 || tenure <= 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please enter valid values greater than zero')),
        );
        return;
      }
      final tenureMonths = _isYears ? tenure * 12 : tenure;
      // Check if EMI is too low for the given principal and tenure
      double minEmi = 0;
      if (tenureMonths > 0) {
        minEmi = principal / tenureMonths;
      }
      if (emi <= minEmi) {
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
            content: const Text('Increase the EMI or decrease loan amount'),
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
      final rate = _calculateRate(principal: principal, emi: emi, tenureMonths: tenureMonths);
      final total = emi * tenureMonths;
      final interest = total - principal;
      setState(() {
        _principal = principal;
        _emi = emi;
        _rate = rate;
        _tenure = tenure;
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
                                'ROI: ${Formatter.formatNumber(calculation['rate'], decimalPlaces: 2)}%',
                                style: const TextStyle(fontWeight: FontWeight.bold),
                              ),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Loan: ${Formatter.formatCurrency(calculation['loanAmount'])}'),
                                  Text('EMI: ${Formatter.formatCurrency(calculation['emi'])}'),
                                  Text('Tenure: ${calculation['tenure']} ${calculation['isYears'] ? 'years' : 'months'}'),
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
    final tenureMonths = _isYears ? _tenure * 12 : _tenure;
    final emi = _emi;
    final principal = _principal;
    final rate = _rate;
    if (principal <= 0 || rate <= 0 || tenureMonths <= 0) return;
    final emiModel = EmiModel(
      loanAmount: principal,
      interestRate: rate,
      tenure: tenureMonths,
      isYears: false,
    );
    final monthlyInterestRate = (rate / 12) / 100;
    double remainingPrincipal = principal;
    final List<Map<String, dynamic>> scheduleData = [];
    for (int i = 1; i <= tenureMonths; i++) {
      final interest = remainingPrincipal * monthlyInterestRate;
      final principalPaid = emi - interest;
      remainingPrincipal -= principalPaid;
      scheduleData.add({
        'principal': principalPaid > 0 ? principalPaid : 0,
        'interest': interest > 0 ? interest : 0,
        'outstanding': remainingPrincipal > 0 ? remainingPrincipal : 0,
      });
    }
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => SizedBox(
        height: MediaQuery.of(context).size.height * 0.92,
        child: ScheduleScreen(
          scheduleData: scheduleData,
          principal: principal,
          interestRate: rate,
          tenureMonths: tenureMonths,
          emi: emi,
          startDate: DateTime.now(),
          isYearly: false,
        ),
      ),
    );
  }

  void _shareResult() {
    if (!_hasCalculated) return;
    final loanAmount = Formatter.formatCurrency(_principal);
    final emi = Formatter.formatCurrency(_emi);
    final rate = _rate.isNaN ? '--' : _rate.toStringAsFixed(2);
    final tenureStr = _isYears ? '$_tenure Years (${_tenure * 12} Months)' : '$_tenure Months';
    final totalInterest = Formatter.formatCurrency(_interest);
    final totalPayment = Formatter.formatCurrency(_total);
    final message = '''EMI Calculation\n\nLoan Amount: $loanAmount\nInterest Rate: $rate %\nLoan Tenure : $tenureStr\n\nEMI: $emi\nTotal Interest Payable: $totalInterest\nTotal Payable Amount : $totalPayment\n\nDownload 4.6★ rated App for EMI Calculation, Loan comparison with advanced feature like Processing Fees, GST on Interest, Fixed Rate etc.\nCalculated Using\nAndroid: http://diet.vc/a_aemi\niPhone: http://diet.vc/a_iemi''';
    Share.share(message, subject: 'EMI Calculation');
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
              'Calculate Interest',
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
                    style: TextStyle(fontWeight: FontWeight.bold),
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
                    style: const TextStyle(color: Colors.grey, fontSize: 12, fontStyle: FontStyle.italic),
                  ),
                  const SizedBox(height: 16),
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
                      setState(() {});
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
                              onTap: () {
                                setState(() {
                                  _isYears = true;
                                });
                              },
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
                              onTap: () {
                                setState(() {
                                  _isYears = false;
                                });
                              },
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
                          onPressed: _calculateRoi,
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
                          const Text('Interest Rate (%)', style: TextStyle(color: Colors.blueAccent, fontSize: 18, fontWeight: FontWeight.bold)),
                          Text(
                            _rate.isNaN ? '--' : Formatter.formatNumber(_rate, decimalPlaces: 2),
                            style: const TextStyle(color: Colors.blueAccent, fontSize: 48, fontWeight: FontWeight.bold),
                          ),
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
                            onPressed: _shareResult,
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
            child: Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Flexible(
                  child: Text(
                    title,
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 4),
                const Icon(Icons.add, size: 14, color: Colors.grey),
              ],
            ),
          ),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
          ),
          if (percentage.isNotEmpty)
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                percentage,
                style: TextStyle(fontSize: 12, color: percentageColor),
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
    final digits = newValue.text.replaceAll(RegExp(r'[^\d]'), '');
    final formattedValue = _formatWithIndianNumberSystem(digits);
    return TextEditingValue(
      text: formattedValue,
      selection: TextSelection.collapsed(offset: formattedValue.length),
    );
  }

  String _formatWithIndianNumberSystem(String input) {
    if (input.isEmpty) return input;
    final parts = input.split('.');
    final integerPart = parts[0];
    final decimalPart = parts.length > 1 ? '.${parts[1]}' : '';
    if (integerPart.length <= 3) {
      return '$integerPart$decimalPart';
    }
    final lastThree = integerPart.substring(integerPart.length - 3);
    final rest = integerPart.substring(0, integerPart.length - 3);
    final reg = RegExp(r'\B(?=(\d{2})+(?!\d))');
    final formattedRest = rest.replaceAll(reg, ',');
    return '$formattedRest,$lastThree$decimalPart';
  }
}
