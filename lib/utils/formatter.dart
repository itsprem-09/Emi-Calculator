import 'package:intl/intl.dart';

class Formatter {
  static final NumberFormat _currencyFormat = NumberFormat.currency(
    symbol: '₹ ',
    locale: 'en_IN',
    decimalDigits: 0,
  );

  static final NumberFormat _percentFormat = NumberFormat.percentPattern('en_IN')
    ..maximumFractionDigits = 2;

  static String formatCurrency(double amount) {
    return _currencyFormat.format(amount);
  }

  static String formatPercent(double percentage) {
    return _percentFormat.format(percentage / 100);
  }

  static String formatNumber(double number, {int decimalPlaces = 2}) {
    return NumberFormat.decimalPattern('en_IN')
        .format(double.parse(number.toStringAsFixed(decimalPlaces)));
  }
}

class NumberToWords {
  static String convertToWords(double number) {
    if (number == 0) return 'Zero';

    final rupees = number.floor();
    final paise = ((number - rupees) * 100).round();

    String result = _convertToWords(rupees);
    if (paise > 0) {
      result += ' and ${_convertToWords(paise)} paise';
    }
    return result;
  }

  static String _convertToWords(int number) {
    if (number == 0) return '';

    final units = ['', 'One', 'Two', 'Three', 'Four', 'Five', 'Six', 'Seven', 'Eight', 'Nine'];
    final teens = ['Ten', 'Eleven', 'Twelve', 'Thirteen', 'Fourteen', 'Fifteen', 'Sixteen', 'Seventeen', 'Eighteen', 'Nineteen'];
    final tens = ['', '', 'Twenty', 'Thirty', 'Forty', 'Fifty', 'Sixty', 'Seventy', 'Eighty', 'Ninety'];

    if (number < 10) return units[number];
    if (number < 20) return teens[number - 10];
    if (number < 100) return tens[number ~/ 10] + (number % 10 != 0 ? ' ' + units[number % 10] : '');
    if (number < 1000) return units[number ~/ 100] + ' Hundred' + (number % 100 != 0 ? ' and ' + _convertToWords(number % 100) : '');
    if (number < 100000) return _convertToWords(number ~/ 1000) + ' Thousand' + (number % 1000 != 0 ? ' ' + _convertToWords(number % 1000) : '');
    if (number < 10000000) return _convertToWords(number ~/ 100000) + ' Lakh' + (number % 100000 != 0 ? ' ' + _convertToWords(number % 100000) : '');
    return _convertToWords(number ~/ 10000000) + ' Crore' + (number % 10000000 != 0 ? ' ' + _convertToWords(number % 10000000) : '');
  }
}