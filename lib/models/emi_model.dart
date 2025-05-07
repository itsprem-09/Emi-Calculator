class EmiModel {
  final double loanAmount;
  final double interestRate;
  final int tenure;
  final bool isYears;

  EmiModel({
    required this.loanAmount,
    required this.interestRate,
    required this.tenure,
    this.isYears = true,
  });

  double get monthlyEmi {
    // Validate inputs to avoid calculation errors
    if (loanAmount <= 0 || tenure <= 0) {
      return 0.0;
    }

    // Convert interest rate from annual to monthly
    final monthlyInterestRate = (interestRate / 12) / 100;

    // Convert tenure to months if it's in years
    final tenureInMonths = isYears ? tenure * 12 : tenure;

    // Calculate EMI using formula: P * r * (1+r)^n / ((1+r)^n - 1)
    if (monthlyInterestRate == 0) {
      return loanAmount / tenureInMonths;
    }

    // Handle potential calculation issues with try-catch
    try {
      final onePlusR = 1 + monthlyInterestRate;
      final powerTerm = pow(onePlusR, tenureInMonths);

      if (powerTerm <= 1) {
        return loanAmount / tenureInMonths; // Fallback if calculation fails
      }

      final emi = loanAmount *
          monthlyInterestRate *
          powerTerm /
          (powerTerm - 1);

      return emi.isFinite ? emi : 0.0; // Check for infinity or NaN
    } catch (e) {
      // Return a simple division if the complex calculation fails
      return loanAmount / tenureInMonths;
    }
  }

  double get totalPayment {
    final tenureInMonths = isYears ? tenure * 12 : tenure;
    return monthlyEmi * tenureInMonths;
  }

  double get totalInterestPayable {
    return totalPayment - loanAmount;
  }

  double get principalPercentage {
    return (loanAmount / totalPayment) * 100;
  }

  double get interestPercentage {
    return (totalInterestPayable / totalPayment) * 100;
  }

  Map<String, double> generateAmortizationSchedule() {
    final tenureInMonths = isYears ? tenure * 12 : tenure;
    final monthlyInterestRate = (interestRate / 12) / 100;
    final schedule = <String, double>{};

    double remainingPrincipal = loanAmount;

    for (int month = 1; month <= tenureInMonths; month++) {
      final interestForMonth = remainingPrincipal * monthlyInterestRate;
      final principalForMonth = monthlyEmi - interestForMonth;

      remainingPrincipal -= principalForMonth;
      schedule['$month'] = remainingPrincipal > 0 ? remainingPrincipal : 0;
    }

    return schedule;
  }
}

// Helper function for power calculation
double pow(double base, int exponent) {
  double result = 1.0;
  for (int i = 0; i < exponent; i++) {
    result *= base;
  }
  return result;
}