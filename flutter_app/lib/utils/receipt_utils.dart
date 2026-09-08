import '../models/borrower.dart';
import '../models/loan.dart';
import '../models/payment.dart';
import '../models/payment_allocation.dart';
import 'loan_utils.dart';

class ReceiptUtils {
  static String generatePaymentReceipt({
    required String businessName,
    required Borrower borrower,
    required Loan loan,
    required Payment payment,
    required double runningOutstandingBalance,
    String? currencyCode,
    PaymentAllocation? allocation,
  }) {
    final cur = currencyCode ?? LoanUtils.defaultCurrencyCode;
    final buffer = StringBuffer();

    buffer.writeln('========================================');
    buffer.writeln('           OFFICIAL RECEIPT            ');
    buffer.writeln('========================================');
    buffer.writeln(businessName.isNotEmpty ? businessName.toUpperCase() : 'MICROLEND SUITE');
    buffer.writeln('----------------------------------------');
    buffer.writeln('Receipt Ref: ${payment.id}');
    buffer.writeln('Date: ${LoanUtils.formatDate(payment.date)}');
    buffer.writeln('Borrower: ${borrower.fullName}');
    buffer.writeln('Loan ID: ${loan.id}');
    buffer.writeln('Purpose: ${loan.purpose}');
    buffer.writeln('----------------------------------------');
    buffer.writeln('Amount Paid: ${LoanUtils.formatCurrency(payment.amount, cur)}');
    buffer.writeln('Payment Method: ${payment.method}');
    if (payment.note.isNotEmpty) {
      buffer.writeln('Note: ${payment.note}');
    }

    if (allocation != null) {
      buffer.writeln('----------------------------------------');
      buffer.writeln('PAYMENT ALLOCATION BREAKDOWN:');
      if (allocation.coveredInstallmentNos.isNotEmpty) {
        buffer.writeln('Covered Installments: ${allocation.coveredInstallmentsRange}');
      }
      buffer.writeln('Principal Portion: ${LoanUtils.formatCurrency(allocation.principalPortion, cur)}');
      buffer.writeln('Interest Portion:  ${LoanUtils.formatCurrency(allocation.interestPortion, cur)}');
      if (allocation.penaltyPortion > 0) {
        buffer.writeln('Penalty Portion:   ${LoanUtils.formatCurrency(allocation.penaltyPortion, cur)}');
      }
      if (allocation.excessAmount > 0) {
        buffer.writeln('Excess / Overpayment: ${LoanUtils.formatCurrency(allocation.excessAmount, cur)}');
      }
    } else if (payment.principalPortion > 0 || payment.interestPortion > 0 || payment.excessAmount > 0) {
      buffer.writeln('----------------------------------------');
      buffer.writeln('PAYMENT ALLOCATION BREAKDOWN:');
      buffer.writeln('Principal Portion: ${LoanUtils.formatCurrency(payment.principalPortion, cur)}');
      buffer.writeln('Interest Portion:  ${LoanUtils.formatCurrency(payment.interestPortion, cur)}');
      if (payment.penaltyPortion > 0) {
        buffer.writeln('Penalty Portion:   ${LoanUtils.formatCurrency(payment.penaltyPortion, cur)}');
      }
      if (payment.excessAmount > 0) {
        buffer.writeln('Excess / Overpayment: ${LoanUtils.formatCurrency(payment.excessAmount, cur)}');
      }
    }

    buffer.writeln('----------------------------------------');
    buffer.writeln('Remaining Balance: ${LoanUtils.formatCurrency(runningOutstandingBalance, cur)}');
    buffer.writeln('========================================');
    buffer.writeln('       Thank you for your payment!      ');
    buffer.writeln('========================================');

    return buffer.toString();
  }

  static String generateStatementOfAccount({
    required String businessName,
    required Borrower borrower,
    required Loan loan,
    required LoanStats stats,
    String? currencyCode,
  }) {
    final cur = currencyCode ?? LoanUtils.defaultCurrencyCode;
    final buffer = StringBuffer();

    buffer.writeln('========================================');
    buffer.writeln('       STATEMENT OF ACCOUNT (SOA)       ');
    buffer.writeln('========================================');
    buffer.writeln(businessName.isNotEmpty ? businessName.toUpperCase() : 'MICROLEND SUITE');
    buffer.writeln('Date Generated: ${LoanUtils.formatDate(DateTime.now().toIso8601String().split('T')[0])}');
    buffer.writeln('----------------------------------------');
    buffer.writeln('BORROWER DETAILS:');
    buffer.writeln('Name: ${borrower.fullName}');
    buffer.writeln('Contact: ${borrower.phone.isNotEmpty ? borrower.phone : borrower.email}');
    buffer.writeln('Address: ${borrower.address.isNotEmpty ? borrower.address : "N/A"}');
    buffer.writeln('----------------------------------------');
    buffer.writeln('LOAN DETAILS:');
    buffer.writeln('Loan ID: ${loan.id}');
    buffer.writeln('Purpose: ${loan.purpose}');
    buffer.writeln('Principal: ${LoanUtils.formatCurrency(loan.principal, cur)}');
    buffer.writeln('Interest Rate: ${loan.interestRate}%');
    buffer.writeln('Frequency: ${loan.repaymentFrequency.toUpperCase()}');
    buffer.writeln('Interest Method: ${loan.interestMethod.replaceAll('_', ' ').toUpperCase()}');
    buffer.writeln('Disbursement Date: ${LoanUtils.formatDate(loan.disbursementDate)}');
    buffer.writeln('Status: ${loan.status.toUpperCase()}');
    buffer.writeln('----------------------------------------');
    buffer.writeln('AMORTIZATION SCHEDULE:');
    buffer.writeln('#   Due Date     Amount     Status');

    for (final inst in stats.scheduleWithStatus) {
      final noStr = inst.installmentNo.toString().padRight(3);
      final dateStr = LoanUtils.formatDate(inst.dueDate, 'yyyy-MM-dd').padRight(12);
      final amtStr = LoanUtils.formatCurrency(inst.amount, cur).padRight(10);
      final statusStr = inst.status.toUpperCase();
      buffer.writeln('$noStr $dateStr $amtStr $statusStr');
    }

    buffer.writeln('----------------------------------------');
    buffer.writeln('SUMMARY:');
    buffer.writeln('Total Scheduled:     ${LoanUtils.formatCurrency(stats.totalScheduled, cur)}');
    buffer.writeln('Total Paid:          ${LoanUtils.formatCurrency(stats.totalPaid, cur)}');
    buffer.writeln('Outstanding Balance: ${LoanUtils.formatCurrency(stats.outstandingBalance, cur)}');
    if (stats.penaltyAmount > 0) {
      buffer.writeln('Penalty Amount:      ${LoanUtils.formatCurrency(stats.penaltyAmount, cur)}');
      buffer.writeln('TOTAL DUE WITH PENALTY: ${LoanUtils.formatCurrency(stats.totalDueWithPenalty, cur)}');
    } else {
      buffer.writeln('TOTAL DUE:           ${LoanUtils.formatCurrency(stats.outstandingBalance, cur)}');
    }
    if (stats.creditBalance > 0) {
      buffer.writeln('Credit Balance / Overpayment: ${LoanUtils.formatCurrency(stats.creditBalance, cur)}');
    }
    buffer.writeln('========================================');

    return buffer.toString();
  }

  static String generateDisclosureStatement({
    required String businessName,
    required Borrower borrower,
    required Loan loan,
    String? currencyCode,
  }) {
    final cur = currencyCode ?? LoanUtils.defaultCurrencyCode;
    final totalFees = LoanUtils.calculateTotalFeesForLoan(loan);
    final netDisbursed = LoanUtils.calculateNetDisbursedForLoan(loan);

    final totalScheduledInterest = loan.schedule.fold(0.0, (sum, inst) => sum + inst.interest);
    final totalRepayable = loan.schedule.fold(0.0, (sum, inst) => sum + inst.amount);

    final monthlyNIR = LoanUtils.computeNominalRate(
      interestRate: loan.interestRate,
      interestMethod: loan.interestMethod,
      repaymentFrequency: loan.repaymentFrequency,
      termCount: loan.termCount,
      principal: loan.principal,
    );

    final monthlyEIR = LoanUtils.computeEffectiveInterestRate(
      principal: loan.principal,
      interestRate: loan.interestRate,
      termCount: loan.termCount,
      repaymentFrequency: loan.repaymentFrequency,
      interestMethod: loan.interestMethod,
      totalFees: totalFees,
      schedule: loan.schedule,
    );

    final apr = LoanUtils.computeAPR(effectiveMonthlyRate: monthlyEIR);

    final procFee = LoanUtils.calculateFeeAmount(loan.principal, loan.processingFeeType, loan.processingFeeValue, termCount: loan.termCount, frequency: loan.repaymentFrequency);
    final servFee = LoanUtils.calculateFeeAmount(loan.principal, loan.serviceFeeType, loan.serviceFeeValue, termCount: loan.termCount, frequency: loan.repaymentFrequency);
    final disbFee = LoanUtils.calculateFeeAmount(loan.principal, loan.disbursementFeeType, loan.disbursementFeeValue, termCount: loan.termCount, frequency: loan.repaymentFrequency);
    final notaFee = LoanUtils.calculateFeeAmount(loan.principal, loan.notarialFeeType, loan.notarialFeeValue, termCount: loan.termCount, frequency: loan.repaymentFrequency);
    final insFee = LoanUtils.calculateFeeAmount(loan.principal, loan.creditLifeInsuranceFeeType, loan.creditLifeInsuranceFeeValue, termCount: loan.termCount, frequency: loan.repaymentFrequency);
    final legacyUpfront = LoanUtils.calculateUpfrontDeduction(loan.principal, loan.upfrontDeductionType, loan.upfrontDeductionValue);

    final buffer = StringBuffer();

    buffer.writeln('====================================================');
    buffer.writeln('  DISCLOSURE STATEMENT ON LOAN/CREDIT TRANSACTION   ');
    buffer.writeln('        (As Required under R.A. 3765 / SEC MC 3)    ');
    buffer.writeln('====================================================');
    buffer.writeln('Lender: ${businessName.isNotEmpty ? businessName.toUpperCase() : "MICROLEND SUITE"}');
    buffer.writeln('Borrower: ${borrower.fullName}');
    buffer.writeln('Address: ${borrower.address.isNotEmpty ? borrower.address : "N/A"}');
    buffer.writeln('Loan ID: ${loan.id}');
    buffer.writeln('Date: ${LoanUtils.formatDate(loan.disbursementDate)}');
    buffer.writeln('----------------------------------------------------');
    buffer.writeln('1. LOAN AMOUNT / CASH PRICE:          ${LoanUtils.formatCurrency(loan.principal, cur)}');
    buffer.writeln('----------------------------------------------------');
    buffer.writeln('2. ITEMIZED FINANCE CHARGES / FEES:');
    if (procFee > 0) buffer.writeln('   a. Processing Fee:               ${LoanUtils.formatCurrency(procFee, cur)}');
    if (servFee > 0) buffer.writeln('   b. Service Fee:                  ${LoanUtils.formatCurrency(servFee, cur)}');
    if (disbFee > 0) buffer.writeln('   c. Disbursement Fee:             ${LoanUtils.formatCurrency(disbFee, cur)}');
    if (notaFee > 0) buffer.writeln('   d. Notarial Fee:                 ${LoanUtils.formatCurrency(notaFee, cur)}');
    if (insFee > 0) buffer.writeln('   e. Credit Life Insurance:        ${LoanUtils.formatCurrency(insFee, cur)}');
    if (legacyUpfront > 0) buffer.writeln('   f. Other Upfront Deductions:     ${LoanUtils.formatCurrency(legacyUpfront, cur)}');
    if (totalFees == 0) buffer.writeln('   (No upfront fees or charges applied)');
    buffer.writeln('   -------------------------------------------------');
    buffer.writeln('   TOTAL ITEMIZED FEES / CHARGES:     ${LoanUtils.formatCurrency(totalFees, cur)}');
    buffer.writeln('----------------------------------------------------');
    buffer.writeln('3. NET PROCEEDS DISBURSED:            ${LoanUtils.formatCurrency(netDisbursed, cur)}');
    buffer.writeln('----------------------------------------------------');
    buffer.writeln('4. INTEREST & REPAYMENT TERMS:');
    buffer.writeln('   a. Nominal Interest Rate (NIR):    ${monthlyNIR.toStringAsFixed(2)}% per month');
    buffer.writeln('   b. Total Interest Amount:          ${LoanUtils.formatCurrency(totalScheduledInterest, cur)}');
    buffer.writeln('   c. Repayment Frequency:            ${loan.repaymentFrequency.toUpperCase()}');
    buffer.writeln('   d. Number of Installments:         ${loan.termCount}');
    buffer.writeln('   e. Total Amount Repayable:         ${LoanUtils.formatCurrency(totalRepayable, cur)}');
    buffer.writeln('----------------------------------------------------');
    buffer.writeln('5. EFFECTIVE COST OF CREDIT (R.A. 3765 / SEC MC 3):');
    buffer.writeln('   a. Effective Interest Rate (EIR):   ${monthlyEIR.toStringAsFixed(2)}% per month');
    buffer.writeln('   b. Annual Percentage Rate (APR):    ${apr.toStringAsFixed(2)}% per annum');
    buffer.writeln('----------------------------------------------------');
    buffer.writeln('6. PENALTY / LATE PAYMENT CHARGES:');
    buffer.writeln('   Type: ${loan.penaltyType.replaceAll('_', ' ').toUpperCase()}');
    buffer.writeln('   Rate/Amount: ${loan.penaltyValue} (${loan.penaltyType.contains("percent") ? "%" : cur})');
    buffer.writeln('====================================================');
    buffer.writeln('I ACKNOWLEDGE RECEIPT OF A COPY OF THIS DISCLOSURE');
    buffer.writeln('STATEMENT PRIOR TO THE CONSUMMATION OF THE CREDIT');
    buffer.writeln('TRANSACTION.');
    buffer.writeln('');
    buffer.writeln('Borrower Signature: ________________________________');
    buffer.writeln('Date: ______________________________________________');
    buffer.writeln('====================================================');

    return buffer.toString();
  }
}
