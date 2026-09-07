import 'dart:math';
import 'package:intl/intl.dart';
import '../models/borrower.dart';
import '../models/credit_assessment.dart';
import '../models/loan.dart';
import '../models/payment.dart';
import '../models/schedule_installment.dart';

class LoanStats {
  final double totalDisbursed;
  final double totalScheduled;
  final double totalPaid;
  final double outstandingBalance;
  final double overdueAmount;
  final double penaltyAmount;
  final double totalDueWithPenalty;
  final double creditBalance;
  final double payoffAmount;
  final int progressPct;
  final ScheduleInstallment? nextDue;
  final List<ScheduleInstallment> scheduleWithStatus;

  LoanStats({
    required this.totalDisbursed,
    required this.totalScheduled,
    required this.totalPaid,
    required this.outstandingBalance,
    required this.overdueAmount,
    required this.penaltyAmount,
    required this.totalDueWithPenalty,
    this.creditBalance = 0.0,
    required this.payoffAmount,
    required this.progressPct,
    this.nextDue,
    required this.scheduleWithStatus,
  });
}

class LoanUtils {
  static String defaultCurrencyCode = 'PHP';
  static String defaultDateFormat = 'MMM d, yyyy';

  static double round2(double val) {
    return (val * 100.0).round() / 100.0;
  }

  static int calculateTermDays(int termCount, String frequency) {
    final n = max(1, termCount);
    switch (frequency) {
      case 'daily':
        return n;
      case 'weekly':
        return n * 7;
      case 'biweekly':
        return n * 14;
      case 'monthly':
      default:
        return n * 30;
    }
  }

  static double calculateFeeAmount(
    double principal,
    String type,
    double value, {
    int termCount = 1,
    String frequency = 'monthly',
  }) {
    final p = max(0.0, principal);
    final val = max(0.0, value);

    if (type == 'percent') {
      return round2(p * (val / 100.0));
    } else if (type == 'fixed') {
      return round2(min(p, val));
    } else if (type == 'percent_per_day') {
      final days = calculateTermDays(termCount, frequency);
      return round2(p * (val / 100.0) * days);
    }
    return 0.0;
  }

  static double calculateTotalUpfrontFees({
    required double principal,
    String upfrontDeductionType = 'none',
    double upfrontDeductionValue = 0.0,
    String processingFeeType = 'none',
    double processingFeeValue = 0.0,
    String serviceFeeType = 'none',
    double serviceFeeValue = 0.0,
    String disbursementFeeType = 'none',
    double disbursementFeeValue = 0.0,
    String notarialFeeType = 'none',
    double notarialFeeValue = 0.0,
    String creditLifeInsuranceFeeType = 'none',
    double creditLifeInsuranceFeeValue = 0.0,
    int termCount = 1,
    String frequency = 'monthly',
  }) {
    final legacy = calculateUpfrontDeduction(principal, upfrontDeductionType, upfrontDeductionValue);
    final proc = calculateFeeAmount(principal, processingFeeType, processingFeeValue, termCount: termCount, frequency: frequency);
    final serv = calculateFeeAmount(principal, serviceFeeType, serviceFeeValue, termCount: termCount, frequency: frequency);
    final disb = calculateFeeAmount(principal, disbursementFeeType, disbursementFeeValue, termCount: termCount, frequency: frequency);
    final nota = calculateFeeAmount(principal, notarialFeeType, notarialFeeValue, termCount: termCount, frequency: frequency);
    final ins = calculateFeeAmount(principal, creditLifeInsuranceFeeType, creditLifeInsuranceFeeValue, termCount: termCount, frequency: frequency);

    return round2(legacy + proc + serv + disb + nota + ins);
  }

  static double calculateTotalFeesForLoan(Loan loan) {
    return calculateTotalUpfrontFees(
      principal: loan.principal,
      upfrontDeductionType: loan.upfrontDeductionType,
      upfrontDeductionValue: loan.upfrontDeductionValue,
      processingFeeType: loan.processingFeeType,
      processingFeeValue: loan.processingFeeValue,
      serviceFeeType: loan.serviceFeeType,
      serviceFeeValue: loan.serviceFeeValue,
      disbursementFeeType: loan.disbursementFeeType,
      disbursementFeeValue: loan.disbursementFeeValue,
      notarialFeeType: loan.notarialFeeType,
      notarialFeeValue: loan.notarialFeeValue,
      creditLifeInsuranceFeeType: loan.creditLifeInsuranceFeeType,
      creditLifeInsuranceFeeValue: loan.creditLifeInsuranceFeeValue,
      termCount: loan.termCount,
      frequency: loan.repaymentFrequency,
    );
  }

  static double calculateUpfrontDeduction(double principal, String type, double value) {
    return calculateFeeAmount(principal, type, value);
  }

  static double calculateNetDisbursed(double principal, String type, double value) {
    final deduction = calculateUpfrontDeduction(principal, type, value);
    return round2(max(0.0, principal - deduction));
  }

  static double calculateNetDisbursedForLoan(Loan loan) {
    final totalFees = calculateTotalFeesForLoan(loan);
    return round2(max(0.0, loan.principal - totalFees));
  }

  static double computeNominalRate({
    required double interestRate,
    required String interestMethod,
    required String repaymentFrequency,
    int termCount = 1,
    double principal = 0.0,
  }) {
    if (principal <= 0 && interestMethod == 'flat') return 0.0;

    double monthlyNIR = 0.0;
    if (interestMethod == 'flat' || interestMethod == 'one_time') {
      final totalInterest = principal * (interestRate / 100.0);
      double termMonths = 1.0;
      switch (repaymentFrequency) {
        case 'daily':
          termMonths = termCount / 30.4167;
          break;
        case 'weekly':
          termMonths = termCount / 4.3333;
          break;
        case 'biweekly':
          termMonths = termCount / 2.1667;
          break;
        case 'monthly':
        default:
          termMonths = termCount.toDouble();
          break;
      }
      if (termMonths <= 0) termMonths = 1.0;
      monthlyNIR = (totalInterest / principal) / termMonths * 100.0;
    } else {
      // 'reducing' or 'interest_only'
      // interestRate stored in Loan is annual percentage rate (e.g. 12% p.a.)
      monthlyNIR = interestRate / 12.0;
    }
    return round2(max(0.0, monthlyNIR));
  }

  static double computeEffectiveInterestRate({
    required double principal,
    required double interestRate,
    required int termCount,
    required String repaymentFrequency,
    required String interestMethod,
    double totalFees = 0.0,
    List<ScheduleInstallment>? schedule,
  }) {
    if (principal <= 0) return 0.0;

    final netDisbursed = max(0.01, principal - totalFees);
    final sched = (schedule != null && schedule.isNotEmpty)
        ? schedule
        : generateSchedule(
            principal,
            interestRate,
            termCount,
            '',
            repaymentFrequency: repaymentFrequency,
            interestMethod: interestMethod,
          );

    if (sched.isEmpty) return 0.0;

    final cashFlows = [ -netDisbursed, ...sched.map((s) => s.amount) ];

    // Solve periodic IRR 'r' using Newton-Raphson
    double r = 0.05; // Initial guess 5%
    for (int iter = 0; iter < 100; iter++) {
      double npv = 0.0;
      double dnpv = 0.0;
      for (int t = 0; t < cashFlows.length; t++) {
        final denom = pow(1 + r, t).toDouble();
        npv += cashFlows[t] / denom;
        if (t > 0) {
          dnpv -= t * cashFlows[t] / (denom * (1 + r));
        }
      }
      if (dnpv.abs() < 1e-10) break;
      final newR = r - npv / dnpv;
      if ((newR - r).abs() < 1e-7) {
        r = newR;
        break;
      }
      r = newR;
      if (r <= -0.99) {
        r = -0.9;
      }
    }

    if (r.isNaN || r.isInfinite || r < 0) {
      r = 0.0;
    }

    // Convert periodic rate 'r' to monthly Effective Interest Rate (EIR % / month)
    double monthlyEIR = 0.0;
    switch (repaymentFrequency) {
      case 'daily':
        monthlyEIR = (pow(1 + r, 30.4167) - 1) * 100.0;
        break;
      case 'weekly':
        monthlyEIR = (pow(1 + r, 4.3333) - 1) * 100.0;
        break;
      case 'biweekly':
        monthlyEIR = (pow(1 + r, 2.1667) - 1) * 100.0;
        break;
      case 'monthly':
      default:
        monthlyEIR = r * 100.0;
        break;
    }

    return round2(max(0.0, monthlyEIR));
  }

  static double computeAPR({
    required double effectiveMonthlyRate,
  }) {
    // Annualized percentage rate = monthly EIR * 12
    return round2(max(0.0, effectiveMonthlyRate * 12.0));
  }

  static String currencySymbol([String? currencyCode]) {
    final code = currencyCode ?? defaultCurrencyCode;
    switch (code.toUpperCase()) {
      case 'EUR':
        return '€';
      case 'PHP':
        return '₱';
      case 'GBP':
        return '£';
      case 'USD':
      default:
        return '\$';
    }
  }

  static String formatCurrency(double amount, [String? currencyCode]) {
    final code = currencyCode ?? defaultCurrencyCode;
    final symbol = currencySymbol(code);
    final formatter = NumberFormat.currency(locale: 'en_US', symbol: symbol, decimalDigits: 2);
    return formatter.format(amount);
  }

  static String formatDate(String? dateStr, [String? formatPattern]) {
    if (dateStr == null || dateStr.isEmpty) return 'N/A';
    final pattern = formatPattern ?? defaultDateFormat;
    try {
      final dt = DateTime.parse(dateStr);
      return DateFormat(pattern).format(dt);
    } catch (_) {
      return dateStr;
    }
  }

  static String formatPercent(double rate) {
    return '${rate.toStringAsFixed(1)}%';
  }

  static DateTime calculateDueDate(DateTime startDate, String frequency, int periodIndex) {
    switch (frequency) {
      case 'daily':
        return startDate.add(Duration(days: periodIndex));
      case 'weekly':
        return startDate.add(Duration(days: periodIndex * 7));
      case 'biweekly':
        return startDate.add(Duration(days: periodIndex * 14));
      case 'monthly':
      default:
        var year = startDate.year;
        var month = startDate.month + periodIndex;
        while (month > 12) {
          month -= 12;
          year += 1;
        }
        final day = min(startDate.day, 28);
        return DateTime(year, month, day);
    }
  }

  static List<ScheduleInstallment> generateSchedule(
    double principal,
    double interestRate,
    int termCount,
    String disbursementDate, {
    String repaymentFrequency = 'monthly',
    String interestMethod = 'reducing',
  }) {
    final p = max(0.0, principal);
    final rate = max(0.0, interestRate);
    final isOneTime = interestMethod == 'one_time';
    final n = isOneTime ? 1 : max(1, termCount);

    DateTime startDate;
    try {
      startDate = disbursementDate.isNotEmpty ? DateTime.parse(disbursementDate) : DateTime.now();
    } catch (_) {
      startDate = DateTime.now();
    }

    final List<ScheduleInstallment> schedule = [];

    if (interestMethod == 'flat') {
      // Note: Flat/Add-on ("5-6") interest is intentionally period-independent (total interest = principal * rate / 100) regardless of term length.
      final totalInterest = p * (rate / 100.0);
      final principalPerPeriod = p / n;
      final interestPerPeriod = totalInterest / n;
      double balance = p;

      for (int i = 1; i <= n; i++) {
        final dueDate = calculateDueDate(startDate, repaymentFrequency, i);
        final dueDateStr = DateFormat('yyyy-MM-dd').format(dueDate);

        double prin = principalPerPeriod;
        double instInterest = interestPerPeriod;

        if (i == n) {
          prin = balance;
          balance = 0.0;
        } else {
          balance -= prin;
        }

        schedule.add(ScheduleInstallment(
          installmentNo: i,
          dueDate: dueDateStr,
          amount: round2(prin + instInterest),
          principal: round2(prin),
          interest: round2(instInterest),
          balance: max(0.0, round2(balance)),
        ));
      }
      return schedule;
    }

    if (interestMethod == 'interest_only') {
      double perPeriodRate = 0.0;
      switch (repaymentFrequency) {
        case 'daily':
          perPeriodRate = (rate / 100.0) / 365.0;
          break;
        case 'weekly':
          perPeriodRate = (rate / 100.0) / 52.0;
          break;
        case 'biweekly':
          perPeriodRate = (rate / 100.0) / 26.0;
          break;
        case 'monthly':
        default:
          perPeriodRate = (rate / 100.0) / 12.0;
          break;
      }

      final interestPerPeriod = p * perPeriodRate;
      double balance = p;

      for (int i = 1; i <= n; i++) {
        final dueDate = calculateDueDate(startDate, repaymentFrequency, i);
        final dueDateStr = DateFormat('yyyy-MM-dd').format(dueDate);

        final prin = (i == n) ? p : 0.0;
        if (i == n) balance = 0.0;

        schedule.add(ScheduleInstallment(
          installmentNo: i,
          dueDate: dueDateStr,
          amount: round2(prin + interestPerPeriod),
          principal: round2(prin),
          interest: round2(interestPerPeriod),
          balance: max(0.0, round2(balance)),
        ));
      }
      return schedule;
    }

    if (interestMethod == 'one_time') {
      // Note: One-time payment interest is intentionally period-independent.
      final dueDate = calculateDueDate(startDate, repaymentFrequency, 1);
      final dueDateStr = DateFormat('yyyy-MM-dd').format(dueDate);
      final totalInterest = p * (rate / 100.0);

      schedule.add(ScheduleInstallment(
        installmentNo: 1,
        dueDate: dueDateStr,
        amount: round2(p + totalInterest),
        principal: round2(p),
        interest: round2(totalInterest),
        balance: 0.0,
      ));
      return schedule;
    }

    // Default: 'reducing' (amortizing balance)
    double perPeriodRate = 0.0;
    switch (repaymentFrequency) {
      case 'daily':
        perPeriodRate = (rate / 100.0) / 365.0;
        break;
      case 'weekly':
        perPeriodRate = (rate / 100.0) / 52.0;
        break;
      case 'biweekly':
        perPeriodRate = (rate / 100.0) / 26.0;
        break;
      case 'monthly':
      default:
        perPeriodRate = (rate / 100.0) / 12.0;
        break;
    }

    final r = perPeriodRate;
    double periodPayment = 0.0;
    if (r > 0) {
      periodPayment = (p * r * pow(1 + r, n)) / (pow(1 + r, n) - 1);
    } else {
      periodPayment = p / n;
    }

    double balance = p;

    for (int i = 1; i <= n; i++) {
      final dueDate = calculateDueDate(startDate, repaymentFrequency, i);
      final dueDateStr = DateFormat('yyyy-MM-dd').format(dueDate);

      final interestForPeriod = balance * r;
      double principalForPeriod = periodPayment - interestForPeriod;

      if (i == n || (balance - principalForPeriod) < 0.01) {
        principalForPeriod = balance;
        balance = 0.0;
      } else {
        balance -= principalForPeriod;
      }

      final installmentAmount = principalForPeriod + interestForPeriod;

      schedule.add(ScheduleInstallment(
        installmentNo: i,
        dueDate: dueDateStr,
        amount: round2(installmentAmount),
        principal: round2(principalForPeriod),
        interest: round2(interestForPeriod),
        balance: max(0.0, round2(balance)),
      ));
    }

    return schedule;
  }

  static const double kPaymentEpsilon = 0.005;

  static List<ScheduleInstallment> getScheduleWithStatus(
    List<ScheduleInstallment> schedule,
    List<Payment> payments, [
    String loanStatus = 'active',
    DateTime? referenceDate,
  ]) {
    final refDate = referenceDate ?? DateTime.now();
    final cutoffDate = DateTime(refDate.year, refDate.month, refDate.day, 23, 59, 59, 999);

    double availablePayment = payments.fold(0.0, (sum, p) => sum + p.amount);

    return schedule.map((inst) {
      final instAmount = inst.amount;
      double paidAmount = 0.0;
      String status = 'pending';

      if (availablePayment >= instAmount - kPaymentEpsilon) {
        paidAmount = instAmount;
        availablePayment = max(0.0, availablePayment - instAmount);
        status = 'paid';
      } else if (availablePayment > kPaymentEpsilon) {
        paidAmount = availablePayment;
        availablePayment = 0.0;
        status = 'partial';
      } else {
        paidAmount = 0.0;
      }

      if (status != 'paid') {
        try {
          final due = DateTime.parse(inst.dueDate);
          final dueCutoff = DateTime(due.year, due.month, due.day, 23, 59, 59, 999);
          if (dueCutoff.isBefore(cutoffDate)) {
            status = 'overdue';
          }
        } catch (_) {}
      }

      if (loanStatus == 'rejected') {
        status = 'cancelled';
      } else if (loanStatus == 'defaulted' && status != 'paid') {
        status = 'overdue';
      }

      final remainingAmount = max(0.0, round2(instAmount - paidAmount));

      return inst.copyWith(
        paidAmount: round2(paidAmount),
        remainingAmount: remainingAmount,
        status: status,
      );
    }).toList();
  }

  static double calculatePenalty(Loan loan, List<ScheduleInstallment> scheduleWithStatus, DateTime referenceDate) {
    final type = loan.penaltyType;
    final val = max(0.0, loan.penaltyValue);
    final accrued = max(0.0, loan.accruedPenalty);

    // SEC MC 3 s.2022 Total Cost of Credit Cap: Total Interest + Fees + Penalties <= 100% of Principal
    final totalScheduledInterest = loan.schedule.fold(0.0, (sum, inst) => sum + inst.interest);
    final totalFees = calculateTotalFeesForLoan(loan);
    final maxAllowedPenalty = max(0.0, round2(loan.principal - totalScheduledInterest - totalFees));

    if (type == 'none' || val == 0.0) return round2(min(accrued, maxAllowedPenalty));

    final overdueInsts = scheduleWithStatus.where((inst) => inst.status == 'overdue').toList();

    double newlyIncurred = 0.0;
    if (overdueInsts.isNotEmpty) {
      if (type == 'percent_per_period') {
        for (final inst in overdueInsts) {
          newlyIncurred += inst.remainingAmount * (val / 100.0);
        }
      } else if (type == 'fixed_per_period') {
        newlyIncurred = val * overdueInsts.length;
      } else if (type == 'fixed_once') {
        // fixed_once applies at most once over the life of the loan
        newlyIncurred = accrued > 0 ? 0.0 : val;
      }
    }

    final totalPenalty = round2(accrued + newlyIncurred);
    return round2(min(totalPenalty, maxAllowedPenalty));
  }

  static double computeEarlyPayoffAmount(Loan loan, [DateTime? asOfDate]) {
    final stats = getLoanStats(loan, asOfDate);
    if (loan.interestMethod != 'reducing') {
      return stats.totalDueWithPenalty;
    }

    double remainingPrincipal = 0.0;
    for (final inst in stats.scheduleWithStatus) {
      if (inst.status != 'paid') {
        final paidPct = inst.amount > 0 ? (inst.paidAmount / inst.amount) : 0.0;
        final unpaidPrin = inst.principal * (1.0 - paidPct);
        remainingPrincipal += unpaidPrin;
      }
    }
    remainingPrincipal = round2(remainingPrincipal);

    if (remainingPrincipal <= 0) {
      return round2(stats.penaltyAmount);
    }

    DateTime lastDate;
    try {
      if (loan.payments.isNotEmpty) {
        lastDate = DateTime.parse(loan.payments.last.date);
      } else if (loan.disbursementDate.isNotEmpty) {
        lastDate = DateTime.parse(loan.disbursementDate);
      } else {
        lastDate = DateTime.now();
      }
    } catch (_) {
      lastDate = DateTime.now();
    }

    final refDate = asOfDate ?? DateTime.now();
    final daysElapsed = max(0, refDate.difference(lastDate).inDays);

    final dailyRate = (loan.interestRate / 100.0) / 365.0;
    final accruedInterest = round2(remainingPrincipal * dailyRate * daysElapsed);

    final payoff = round2(remainingPrincipal + accruedInterest + stats.penaltyAmount);
    return min(payoff, stats.totalDueWithPenalty);
  }

  static bool isCoveredSmallLoan({
    required double principal,
    required int termCount,
    required String repaymentFrequency,
    bool isUnsecured = true,
  }) {
    if (principal > 10000) return false;
    final termDays = calculateTermDays(termCount, repaymentFrequency);
    if (termDays > 120) return false; // 4 months max
    return isUnsecured;
  }

  static String? validateLoanParams({
    required double principal,
    required double interestRate,
    required int termCount,
    required String repaymentFrequency,
    required double penaltyValue,
    String interestMethod = 'reducing',
    double totalFees = 0.0,
    String penaltyType = 'none',
    bool enforceCoveredCaps = false,
  }) {
    if (principal <= 0) return 'Principal must be greater than 0.';
    if (principal > 10000000) return 'Principal exceeds maximum allowed limit (₱10,000,000).';
    if (interestRate < 0 || interestRate > 100) return 'Interest rate must be between 0% and 100%.';
    if (penaltyValue < 0) return 'Penalty value cannot be negative.';

    int maxTerms = 60;
    switch (repaymentFrequency) {
      case 'daily':
        maxTerms = 365;
        break;
      case 'weekly':
        maxTerms = 104;
        break;
      case 'biweekly':
        maxTerms = 52;
        break;
      case 'monthly':
      default:
        maxTerms = 60;
        break;
    }

    if (termCount <= 0 || termCount > maxTerms) {
      return 'Term count for $repaymentFrequency frequency must be between 1 and $maxTerms.';
    }

    final isCovered = enforceCoveredCaps || isCoveredSmallLoan(
      principal: principal,
      termCount: termCount,
      repaymentFrequency: repaymentFrequency,
    );

    if (isCovered) {
      final monthlyNIR = computeNominalRate(
        interestRate: interestRate,
        interestMethod: interestMethod,
        repaymentFrequency: repaymentFrequency,
        termCount: termCount,
        principal: principal,
      );
      if (monthlyNIR > 6.001) {
        return 'Nominal interest rate (${monthlyNIR.toStringAsFixed(1)}%/mo) exceeds regulatory cap of 6%/month for covered small loans (SEC MC 3 s.2022).';
      }

      final monthlyEIR = computeEffectiveInterestRate(
        principal: principal,
        interestRate: interestRate,
        termCount: termCount,
        repaymentFrequency: repaymentFrequency,
        interestMethod: interestMethod,
        totalFees: totalFees,
      );
      if (monthlyEIR > 15.001) {
        return 'Effective interest rate (${monthlyEIR.toStringAsFixed(1)}%/mo) exceeds regulatory cap of 15%/month for covered small loans (SEC MC 3 s.2022 / BSP Circular 1133).';
      }

      if (penaltyType == 'percent_per_period' && penaltyValue > 5.001) {
        return 'Penalty rate (${penaltyValue.toStringAsFixed(1)}%/mo) exceeds regulatory cap of 5%/month for covered small loans (SEC MC 3 s.2022).';
      }
    }

    return null;
  }

  static LoanStats getLoanStats(Loan loan, [DateTime? referenceDate]) {
    final payments = loan.payments;
    final schedule = loan.schedule;

    final totalPaid = payments.fold(0.0, (sum, p) => sum + p.amount);
    final totalScheduled = schedule.fold(0.0, (sum, s) => sum + s.amount) > 0
        ? schedule.fold(0.0, (sum, s) => sum + s.amount)
        : loan.principal;

    final scheduleWithStatus = getScheduleWithStatus(schedule, payments, loan.status, referenceDate);

    final outstandingBalance = scheduleWithStatus.fold(0.0, (sum, inst) => sum + inst.remainingAmount);

    final overdueAmount = scheduleWithStatus
        .where((inst) => inst.status == 'overdue')
        .fold(0.0, (sum, inst) => sum + inst.remainingAmount);

    final progressPct = totalScheduled > 0
        ? min(100, ((totalPaid / totalScheduled) * 100).round())
        : 0;

    ScheduleInstallment? nextDue;
    try {
      nextDue = scheduleWithStatus.firstWhere(
        (inst) => inst.status == 'pending' || inst.status == 'overdue' || inst.status == 'partial',
      );
    } catch (_) {
      nextDue = null;
    }

    final netDisbursed = calculateNetDisbursedForLoan(loan);

    final refDate = referenceDate ?? DateTime.now();
    final penaltyAmount = calculatePenalty(loan, scheduleWithStatus, refDate);
    final totalDueWithPenalty = round2(outstandingBalance + penaltyAmount);

    final totalRequired = round2(totalScheduled + penaltyAmount);
    final creditBalance = totalPaid > totalRequired ? round2(totalPaid - totalRequired) : 0.0;

    // Compute early payoff figure
    double payoff = totalDueWithPenalty;
    if (loan.interestMethod == 'reducing') {
      double remainingPrincipal = 0.0;
      for (final inst in scheduleWithStatus) {
        if (inst.status != 'paid') {
          final paidPct = inst.amount > 0 ? (inst.paidAmount / inst.amount) : 0.0;
          final unpaidPrin = inst.principal * (1.0 - paidPct);
          remainingPrincipal += unpaidPrin;
        }
      }
      remainingPrincipal = round2(remainingPrincipal);

      if (remainingPrincipal <= 0) {
        payoff = round2(penaltyAmount);
      } else {
        DateTime lastDate;
        try {
          if (loan.payments.isNotEmpty) {
            lastDate = DateTime.parse(loan.payments.last.date);
          } else if (loan.disbursementDate.isNotEmpty) {
            lastDate = DateTime.parse(loan.disbursementDate);
          } else {
            lastDate = DateTime.now();
          }
        } catch (_) {
          lastDate = DateTime.now();
        }

        final daysElapsed = max(0, refDate.difference(lastDate).inDays);
        final dailyRate = (loan.interestRate / 100.0) / 365.0;
        final accruedInterest = round2(remainingPrincipal * dailyRate * daysElapsed);

        payoff = min(round2(remainingPrincipal + accruedInterest + penaltyAmount), totalDueWithPenalty);
      }
    }

    return LoanStats(
      totalDisbursed: netDisbursed,
      totalScheduled: round2(totalScheduled),
      totalPaid: round2(totalPaid),
      outstandingBalance: round2(outstandingBalance),
      overdueAmount: round2(overdueAmount),
      penaltyAmount: penaltyAmount,
      totalDueWithPenalty: totalDueWithPenalty,
      creditBalance: creditBalance,
      payoffAmount: payoff,
      progressPct: progressPct,
      nextDue: nextDue,
      scheduleWithStatus: scheduleWithStatus,
    );
  }

  static CreditAssessment assessBorrower(Borrower borrower, List<Loan> borrowerLoans) {
    final baseCreditScore = borrower.creditScore;
    final monthlyIncome = borrower.monthlyIncome;

    final activeLoans = borrowerLoans.where((l) => l.status == 'active').toList();
    double monthlyDebt = 0.0;

    for (final loan in activeLoans) {
      double periodAmount = 0.0;
      if (loan.schedule.isNotEmpty) {
        periodAmount = loan.schedule[0].amount;
      } else if (loan.principal > 0 && loan.termCount > 0) {
        periodAmount = loan.principal / loan.termCount;
      }

      double multiplier = 1.0;
      switch (loan.repaymentFrequency) {
        case 'daily':
          multiplier = 30.4167; // 365 / 12
          break;
        case 'weekly':
          multiplier = 4.3333; // 52 / 12
          break;
        case 'biweekly':
          multiplier = 2.1667; // 26 / 12
          break;
        case 'monthly':
        default:
          multiplier = 1.0;
          break;
      }

      monthlyDebt += periodAmount * multiplier;
    }

    final dtiPct = monthlyIncome > 0
        ? ((monthlyDebt / monthlyIncome) * 100).round()
        : (monthlyDebt > 0 ? 100 : 0);

    final completedLoans = borrowerLoans.where((l) => l.status == 'completed').toList();
    final defaultedLoans = borrowerLoans.where((l) => l.status == 'defaulted').toList();

    int scoreAdjustment = 0;
    scoreAdjustment += min(30, completedLoans.length * 10);
    scoreAdjustment -= defaultedLoans.length * 25;

    if (dtiPct > 50) {
      scoreAdjustment -= 15;
    } else if (dtiPct > 35) {
      scoreAdjustment -= 5;
    }

    final derivedScore = max(0, min(100, baseCreditScore + scoreAdjustment));

    String riskRating = 'medium';
    if (derivedScore >= 70 && dtiPct <= 35) {
      riskRating = 'low';
    } else if (derivedScore < 45 || dtiPct > 50 || defaultedLoans.isNotEmpty) {
      riskRating = 'high';
    }

    return CreditAssessment(
      creditScore: derivedScore,
      baseCreditScore: baseCreditScore,
      dtiPct: dtiPct,
      riskRating: riskRating,
      monthlyDebt: round2(monthlyDebt),
      completedCount: completedLoans.length,
      defaultedCount: defaultedLoans.length,
      activeCount: activeLoans.length,
    );
  }
}
