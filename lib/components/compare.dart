import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/emi_model.dart';
import '../utils/formatter.dart';

class Compare extends StatefulWidget {
  const Compare({super.key});

  @override
  State<Compare> createState() => _CompareState();
}

class _CompareState extends State<Compare> {
  final _formKey = GlobalKey<FormState>();

  // Controllers for Loan 1
  final TextEditingController _amount1Controller = TextEditingController();
  final TextEditingController _rate1Controller = TextEditingController();
  final TextEditingController _tenure1Controller = TextEditingController();
  String _emiType1 = 'Reducing';

  // Controllers for Loan 2
  final TextEditingController _amount2Controller = TextEditingController();
  final TextEditingController _rate2Controller = TextEditingController();
  final TextEditingController _tenure2Controller = TextEditingController();
  String _emiType2 = 'Reducing';

  // Results
  double? _emi1, _emi2;
  double? _interest1, _interest2;
  double? _total1, _total2;
  bool _hasCalculated = false;

  @override
  void dispose() {
    _amount1Controller.dispose();
    _rate1Controller.dispose();
    _tenure1Controller.dispose();
    _amount2Controller.dispose();
    _rate2Controller.dispose();
    _tenure2Controller.dispose();
    super.dispose();
  }

  double _parseAmount(TextEditingController controller) {
    try {
      final text = controller.text.replaceAll(RegExp(r'[^\d.]'), '');
      return double.tryParse(text) ?? 0.0;
    } catch (e) {
      return 0.0;
    }
  }

  double _parseRate(TextEditingController controller) {
    try {
      return double.tryParse(controller.text) ?? 0.0;
    } catch (e) {
      return 0.0;
    }
  }

  int _parseTenure(TextEditingController controller) {
    try {
      return int.tryParse(controller.text) ?? 0;
    } catch (e) {
      return 0;
    }
  }

  // Flat EMI calculation
  Map<String, double> _calculateFlat(double principal, double rate, int months) {
    if (principal <= 0 || rate <= 0 || months <= 0) {
      return {'emi': 0, 'interest': 0, 'total': 0};
    }
    double years = months / 12.0;
    double interest = principal * rate * years / 100.0;
    double total = principal + interest;
    double emi = total / months;
    return {'emi': emi, 'interest': interest, 'total': total};
  }

  // Reducing EMI calculation (using EmiModel)
  Map<String, double> _calculateReducing(double principal, double rate, int months) {
    if (principal <= 0 || rate <= 0 || months <= 0) {
      return {'emi': 0, 'interest': 0, 'total': 0};
    }
    final emiModel = EmiModel(
      loanAmount: principal,
      interestRate: rate,
      tenure: months,
      isYears: false,
    );
    return {
      'emi': emiModel.monthlyEmi,
      'interest': emiModel.totalInterestPayable,
      'total': emiModel.totalPayment,
    };
  }

  void _calculate() {
    if (!_formKey.currentState!.validate()) return;
    final amount1 = _parseAmount(_amount1Controller);
    final rate1 = _parseRate(_rate1Controller);
    final tenure1 = _parseTenure(_tenure1Controller);
    final amount2 = _parseAmount(_amount2Controller);
    final rate2 = _parseRate(_rate2Controller);
    final tenure2 = _parseTenure(_tenure2Controller);

    Map<String, double> res1 = _emiType1 == 'Reducing'
        ? _calculateReducing(amount1, rate1, tenure1)
        : _calculateFlat(amount1, rate1, tenure1);
    Map<String, double> res2 = _emiType2 == 'Reducing'
        ? _calculateReducing(amount2, rate2, tenure2)
        : _calculateFlat(amount2, rate2, tenure2);

    setState(() {
      _emi1 = res1['emi'];
      _interest1 = res1['interest'];
      _total1 = res1['total'];
      _emi2 = res2['emi'];
      _interest2 = res2['interest'];
      _total2 = res2['total'];
      _hasCalculated = true;
    });
  }

  void _reset() {
    setState(() {
      _amount1Controller.clear();
      _rate1Controller.clear();
      _tenure1Controller.clear();
      _emiType1 = 'Reducing';
      _amount2Controller.clear();
      _rate2Controller.clear();
      _tenure2Controller.clear();
      _emiType2 = 'Reducing';
      _emi1 = _emi2 = _interest1 = _interest2 = _total1 = _total2 = null;
      _hasCalculated = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final isSmallScreen = screenSize.width < 600;
    final padding = isSmallScreen ? 12.0 : 24.0;
    final buttonHeight = isSmallScreen ? 40.0 : 48.0;
    final buttonWidth = isSmallScreen ? 100.0 : 120.0;
    final labelStyle = TextStyle(fontWeight: FontWeight.bold, color: Colors.grey[800]);
    final valueStyle = TextStyle(fontWeight: FontWeight.bold, color: Colors.red[700], fontSize: isSmallScreen ? 18 : 22);
    final diffStyle = TextStyle(fontWeight: FontWeight.bold, color: Colors.red[800], fontSize: isSmallScreen ? 16 : 18);
    final resultLabelStyle = TextStyle(color: Colors.blueGrey[700], fontWeight: FontWeight.bold);

    return SingleChildScrollView(
      child: Column(
        children: [
          Container(
            color: const Color(0xFF3498db),
            padding: EdgeInsets.symmetric(horizontal: padding, vertical: 12.0),
            width: double.infinity,
            child: const Text(
              'Compare Loan',
              style: TextStyle(
                color: Colors.white,
                fontSize: 22,
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
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          color: Colors.grey[300],
                          child: const Center(
                            child: Text('Loan-1', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.blueGrey)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          color: Colors.grey[300],
                          child: const Center(
                            child: Text('Loan-2', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.blueGrey)),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 7),
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          children: [
                            Text(
                              NumberToWords.convertToWords(_parseAmount(_amount1Controller)),
                              style: const TextStyle(
                                color: Colors.grey,
                                fontSize: 12,
                                fontStyle: FontStyle.italic,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          children: [
                            Text(
                              NumberToWords.convertToWords(_parseAmount(_amount2Controller)),
                              style: const TextStyle(
                                color: Colors.grey,
                                fontSize: 12,
                                fontStyle: FontStyle.italic,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            TextFormField(
                              controller: _amount1Controller,
                              keyboardType: const TextInputType.numberWithOptions(decimal: false),
                              inputFormatters: [FilteringTextInputFormatter.digitsOnly, _AmountInputFormatter()],
                              decoration: InputDecoration(
                                labelText: 'Amount',
                                suffixIcon: const Padding(
                                  padding: EdgeInsets.all(12),
                                  child: Text('₹', style: TextStyle(fontWeight: FontWeight.bold)),
                                ),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8.0)),
                              ),
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Enter amount';
                                }
                                return null;
                              },
                              onChanged: (value) {
                                setState(() {});
                              },
                            ),
                            const SizedBox(height: 10),
                            GestureDetector(
                              onTap: () async {
                                final selected = await _showEmiTypeSelector(context, _emiType1);
                                if (selected != null && selected != _emiType1) {
                                  setState(() {
                                    _emiType1 = selected;
                                  });
                                }
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                decoration: BoxDecoration(
                                  color: Colors.grey[200],
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: Colors.blueGrey[300]!, width: 1.5),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.blueGrey.withOpacity(0.05),
                                      blurRadius: 6,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Row(
                                      children: [
                                        Icon(_emiType1 == 'Reducing' ? Icons.trending_down : Icons.horizontal_rule,
                                            color: _emiType1 == 'Reducing' ? Colors.blueGrey[700] : Colors.orange[700]),
                                        const SizedBox(width: 8),
                                        Text(_emiType1, style: TextStyle(fontWeight: FontWeight.w600, color: Colors.blueGrey[800])),
                                      ],
                                    ),
                                    const Icon(Icons.keyboard_arrow_down_rounded, color: Colors.blueGrey, size: 22),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            TextFormField(
                              controller: _amount2Controller,
                              keyboardType: const TextInputType.numberWithOptions(decimal: false),
                              inputFormatters: [FilteringTextInputFormatter.digitsOnly, _AmountInputFormatter()],
                              decoration: InputDecoration(
                                labelText: 'Amount',
                                suffixIcon: const Padding(
                                  padding: EdgeInsets.all(12),
                                  child: Text('₹', style: TextStyle(fontWeight: FontWeight.bold)),
                                ),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8.0)),
                              ),
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Enter amount';
                                }
                                return null;
                              },
                              onChanged: (value) {
                                setState(() {});
                              },
                            ),
                            const SizedBox(height: 10),
                            GestureDetector(
                              onTap: () async {
                                final selected = await _showEmiTypeSelector(context, _emiType2);
                                if (selected != null && selected != _emiType2) {
                                  setState(() {
                                    _emiType2 = selected;
                                  });
                                }
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                decoration: BoxDecoration(
                                  color: Colors.grey[200],
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: Colors.blueGrey[300]!, width: 1.5),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.blueGrey.withOpacity(0.05),
                                      blurRadius: 6,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Row(
                                      children: [
                                        Icon(_emiType2 == 'Reducing' ? Icons.trending_down : Icons.horizontal_rule,
                                            color: _emiType2 == 'Reducing' ? Colors.blueGrey[700] : Colors.orange[700]),
                                        const SizedBox(width: 8),
                                        Text(_emiType2, style: TextStyle(fontWeight: FontWeight.w600, color: Colors.blueGrey[800])),
                                      ],
                                    ),
                                    const Icon(Icons.keyboard_arrow_down_rounded, color: Colors.blueGrey, size: 22),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 15),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _rate1Controller,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^[0-9]*\.?[0-9]{0,2}'))],
                          decoration: InputDecoration(
                            labelText: 'Interest',
                            suffixIcon: const Padding(
                              padding: EdgeInsets.all(12),
                              child: Text('%', style: TextStyle(fontWeight: FontWeight.bold)),
                            ),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8.0)),
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Enter rate';
                            }
                            return null;
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextFormField(
                          controller: _rate2Controller,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^[0-9]*\.?[0-9]{0,2}'))],
                          decoration: InputDecoration(
                            labelText: 'Interest',
                            suffixIcon: const Padding(
                              padding: EdgeInsets.all(12),
                              child: Text('%', style: TextStyle(fontWeight: FontWeight.bold)),
                            ),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8.0)),
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Enter rate';
                            }
                            return null;
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 15),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _tenure1Controller,
                          keyboardType: TextInputType.number,
                          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                          decoration: InputDecoration(
                            labelText: 'Tenure',
                            suffixIcon: const Padding(
                              padding: EdgeInsets.all(12),
                              child: Text('MONTHS', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 10)),
                            ),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8.0)),
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Enter tenure';
                            }
                            return null;
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextFormField(
                          controller: _tenure2Controller,
                          keyboardType: TextInputType.number,
                          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                          decoration: InputDecoration(
                            labelText: 'Tenure',
                            suffixIcon: const Padding(
                              padding: EdgeInsets.all(12),
                              child: Text('MONTHS', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 10)),
                            ),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8.0)),
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Enter tenure';
                            }
                            return null;
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
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
                    ],
                  ),
                  const SizedBox(height: 20),
                  if (_hasCalculated) ...[
                    Column(
                      children: [
                        _ResultBlock(
                          label: 'EMI',
                          value1: Formatter.formatCurrency(_emi1 ?? 0),
                          value2: Formatter.formatCurrency(_emi2 ?? 0),
                          diff: Formatter.formatCurrency(((_emi1 ?? 0) - (_emi2 ?? 0)).abs()),
                          color: Colors.blue[600]!,
                          bgGradient: [Colors.blue[50]!, Colors.white],
                        ),
                        const SizedBox(height: 16),
                        _ResultBlock(
                          label: 'Interest Payable',
                          value1: Formatter.formatCurrency(_interest1 ?? 0),
                          value2: Formatter.formatCurrency(_interest2 ?? 0),
                          diff: Formatter.formatCurrency(((_interest1 ?? 0) - (_interest2 ?? 0)).abs()),
                          color: Colors.deepPurple,
                          bgGradient: [Colors.deepPurple[50]!, Colors.white],
                        ),
                        const SizedBox(height: 16),
                        _ResultBlock(
                          label: 'Total Repayment',
                          value1: Formatter.formatCurrency(_total1 ?? 0),
                          value2: Formatter.formatCurrency(_total2 ?? 0),
                          diff: Formatter.formatCurrency(((_total1 ?? 0) - (_total2 ?? 0)).abs()),
                          color: Colors.orange[700]!,
                          bgGradient: [Colors.orange[50]!, Colors.white],
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

  Future<String?> _showEmiTypeSelector(BuildContext context, String currentValue) async {
    return showModalBottomSheet<String>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 16),
            const Text('Select EMI Type', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            const SizedBox(height: 8),
            ListTile(
              leading: Icon(Icons.trending_down, color: Colors.blueGrey[700]),
              title: const Text('Reducing', style: TextStyle(fontWeight: FontWeight.w500)),
              tileColor: currentValue == 'Reducing' ? Colors.blueGrey[50] : null,
              onTap: () => Navigator.pop(context, 'Reducing'),
            ),
            ListTile(
              leading: Icon(Icons.horizontal_rule, color: Colors.orange[700]),
              title: const Text('Flat', style: TextStyle(fontWeight: FontWeight.w500)),
              tileColor: currentValue == 'Flat' ? Colors.orange[50] : null,
              onTap: () => Navigator.pop(context, 'Flat'),
            ),
            const SizedBox(height: 16),
          ],
        );
      },
    );
  }
}

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

class _ResultBlock extends StatelessWidget {
  final String label;
  final String value1;
  final String value2;
  final String diff;
  final Color color;
  final List<Color> bgGradient;
  const _ResultBlock({required this.label, required this.value1, required this.value2, required this.diff, required this.color, required this.bgGradient});
  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: bgGradient,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.08),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
        border: Border.all(color: color.withOpacity(0.18), width: 1.2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(label, style: TextStyle(fontWeight: FontWeight.bold, color: color, fontSize: 16)),
              Container(
                padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 12),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.13),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  'Difference: $diff',
                  style: TextStyle(fontWeight: FontWeight.bold, color: color, fontSize: 14, fontStyle: FontStyle.italic),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    const Text('Loan 1', style: TextStyle(fontSize: 12, color: Colors.black54)),
                    const SizedBox(height: 2),
                    Text(value1, style: TextStyle(fontWeight: FontWeight.bold, color: color, fontSize: 18)),
                  ],
                ),
              ),
              Container(
                width: 1,
                height: 32,
                color: color.withOpacity(0.13),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    const Text('Loan 2', style: TextStyle(fontSize: 12, color: Colors.black54)),
                    const SizedBox(height: 2),
                    Text(value2, style: TextStyle(fontWeight: FontWeight.bold, color: color, fontSize: 18)),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
