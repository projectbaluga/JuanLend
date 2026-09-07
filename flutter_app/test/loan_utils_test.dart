import 'package:flutter_test/flutter_test.dart';
import 'package:microlend/models/borrower.dart';
import 'package:microlend/models/loan.dart';
import 'package:microlend/models/payment.dart';
import 'package:microlend/models/schedule_installment.dart';
import 'package:microlend/utils/loan_utils.dart';

void main() {
  group('LoanUtils Formatting', () {
    test('currencySymbol returns expected symbol for code', () {
      expect(LoanUtils.currencySymbol('PHP'), '₱');
      expect(LoanUtils.currencySymbol('USD'), '\$');
      expect(LoanUtils.currencySymbol('EUR'), '€');
      expect(LoanUtils.currencySymbol('GBP'), '£');
    });

    test('formatCurrency returns formatted string with selected currency symbol', () {
      expect(LoanUtils.formatCurrency(1250.5, 'USD'), '\$1,250.50');
      expect(LoanUtils.formatCurrency(1250.5, 'EUR'), '€1,250.50');
      expect(LoanUtils.formatCurrency(1250.5, 'PHP'), '₱1,250.50');
      expect(LoanUtils.formatCurrency(1250.5, 'GBP'), '£1,250.50');
      expect(LoanUtils.formatCurrency(0.0), '₱0.00');
    });

    test('formatDate formats date properly', () {
      expect(LoanUtils.formatDate('2025-01-15'), 'Jan 15, 2025');
      expect(LoanUtils.formatDate(''), 'N/A');
    });

    test('formatPercent formats percentage string', () {
      expect(LoanUtils.formatPercent(12.5), '12.5%');
    });
  });

  group('LoanUtils Upfront Deduction', () {
    test('calculates upfront deduction correctly for percent and fixed types', () {
      expect(LoanUtils.calculateUpfrontDeduction(1000.0, 'none', 50.0), 0.0);
      expect(LoanUtils.calculateUpfrontDeduction(1000.0, 'fixed', 50.0), 50.0);
      expect(LoanUtils.calculateUpfrontDeduction(1000.0, 'percent', 5.0), 50.0);
      expect(LoanUtils.calculateUpfrontDeduction(1000.0, 'fixed', 1500.0), 1000.0);
    });

    test('calculates net disbursed correctly', () {
      expect(LoanUtils.calculateNetDisbursed(1000.0, 'none', 0.0), 1000.0);
      expect(LoanUtils.calculateNetDisbursed(1000.0, 'fixed', 50.0), 950.0);
      expect(LoanUtils.calculateNetDisbursed(1000.0, 'percent', 2.5), 975.0);
    });

    test('getLoanStats uses net disbursed for totalDisbursed', () {
      final loan = Loan(
        id: 'l1',
        borrowerId: 'b1',
        principal: 1000.0,
        interestRate: 12.0,
        termMonths: 12,
        purpose: 'Test',
        status: 'active',
        disbursementDate: '2025-01-01',
        upfrontDeductionType: 'percent',
        upfrontDeductionValue: 5.0,
        schedule: [],
        payments: [],
        notes: '',
      );

      final stats = LoanUtils.getLoanStats(loan);
      expect(stats.totalDisbursed, 950.0);
    });
  });

  group('LoanUtils.generateSchedule', () {
    test('generates 12 month amortizing loan schedule correctly', () {
      final schedule = LoanUtils.generateSchedule(1000.0, 12.0, 12, '2025-01-01');
      expect(schedule.length, 12);
      expect(schedule[0].dueDate, '2025-02-01');
      expect(schedule[0].amount, greaterThan(0.0));
      expect(schedule[11].balance, 0.0);
    });

    test('handles 0% interest rate gracefully', () {
      final schedule = LoanUtils.generateSchedule(1200.0, 0.0, 12, '2025-01-01');
      expect(schedule.length, 12);
      expect(schedule[0].amount, 100.0);
      expect(schedule[0].interest, 0.0);
      expect(schedule[11].balance, 0.0);
    });

    test('LoanUtils.generateSchedule handles flat "5-6" interest method correctly', () {
      // 1000 principal, 20% flat rate (add-on), 10 weekly installments
      final schedule = LoanUtils.generateSchedule(
        1000.0,
        20.0,
        10,
        '2026-01-01',
        repaymentFrequency: 'weekly',
        interestMethod: 'flat',
      );

      expect(schedule.length, 10);
      // Total interest = 1000 * 20% = 200. Total repayable = 1200. Per weekly installment = 120.
      expect(schedule[0].amount, 120.0);
      expect(schedule[0].principal, 100.0);
      expect(schedule[0].interest, 20.0);
      expect(schedule[0].dueDate, '2026-01-08');
      expect(schedule[9].dueDate, '2026-03-12');
    });

    test('LoanUtils.generateSchedule handles interest-only balloon interest method', () {
      final schedule = LoanUtils.generateSchedule(
        1200.0,
        12.0,
        12,
        '2026-01-01',
        repaymentFrequency: 'monthly',
        interestMethod: 'interest_only',
      );

      expect(schedule.length, 12);
      // Monthly interest = 1200 * (12%/12) = 12.0
      expect(schedule[0].amount, 12.0);
      expect(schedule[0].principal, 0.0);
      expect(schedule[0].interest, 12.0);

      // Final installment includes full principal balloon (1200 + 12 = 1212)
      expect(schedule[11].amount, 1212.0);
      expect(schedule[11].principal, 1200.0);
      expect(schedule[11].interest, 12.0);
    });

    test('LoanUtils.generateSchedule handles one-time lump sum payment', () {
      final schedule = LoanUtils.generateSchedule(
        500.0,
        10.0,
        1,
        '2026-01-01',
        repaymentFrequency: 'monthly',
        interestMethod: 'one_time',
      );

      expect(schedule.length, 1);
      expect(schedule[0].amount, 550.0);
      expect(schedule[0].principal, 500.0);
      expect(schedule[0].interest, 50.0);
      expect(schedule[0].dueDate, '2026-02-01');
    });
  });

  group('LoanUtils.getScheduleWithStatus', () {
    test('marks installments as paid or partial based on payments', () {
      final schedule = [
        ScheduleInstallment(installmentNo: 1, dueDate: '2025-02-01', amount: 100.0, principal: 90.0, interest: 10.0, balance: 900.0),
        ScheduleInstallment(installmentNo: 2, dueDate: '2025-03-01', amount: 100.0, principal: 91.0, interest: 9.0, balance: 809.0),
      ];
      final payments = [Payment(id: 'p1', date: '2025-01-10', amount: 150.0, method: 'Cash', note: '')];
      final result = LoanUtils.getScheduleWithStatus(schedule, payments, 'active', DateTime.parse('2025-01-15'));

      expect(result[0].status, 'paid');
      expect(result[0].paidAmount, 100.0);
      expect(result[1].status, 'partial');
      expect(result[1].paidAmount, 50.0);
      expect(result[1].remainingAmount, 50.0);
    });

    test('LoanUtils.getScheduleWithStatus handles floating point residue with epsilon tolerance', () {
      final schedule = [
        ScheduleInstallment(installmentNo: 1, dueDate: '2099-01-01', amount: 958.33, principal: 900.0, interest: 58.33, balance: 1916.67),
        ScheduleInstallment(installmentNo: 2, dueDate: '2099-02-01', amount: 958.33, principal: 900.0, interest: 58.33, balance: 1016.67),
        ScheduleInstallment(installmentNo: 3, dueDate: '2099-03-01', amount: 958.34, principal: 900.0, interest: 58.34, balance: 0.0),
      ];

      final payments = [
        Payment(id: 'p1', date: '2026-01-01', amount: 1916.659, method: 'Cash', note: ''),
      ];

      final statusSched = LoanUtils.getScheduleWithStatus(schedule, payments);
      expect(statusSched[0].status, 'paid');
      expect(statusSched[0].remainingAmount, 0.0);
      expect(statusSched[1].status, 'paid');
      expect(statusSched[1].remainingAmount, 0.0);
      expect(statusSched[2].status, 'pending');
    });
  });

  group('LoanUtils.assessBorrower', () {
    test('calculates credit score, DTI and risk rating', () {
      final borrower = Borrower(
        id: 'b1',
        fullName: 'Elena',
        email: '',
        phone: '',
        address: '',
        idNumber: '',
        employment: '',
        monthlyIncome: 4000.0,
        creditScore: 80,
        riskRating: 'low',
        notes: '',
      );
      final loans = [
        Loan(
          id: 'l1',
          borrowerId: 'b1',
          principal: 1000.0,
          interestRate: 10.0,
          termMonths: 12,
          purpose: 'Test',
          status: 'active',
          disbursementDate: '2025-01-01',
          schedule: [ScheduleInstallment(installmentNo: 1, dueDate: '2025-02-01', amount: 400.0, principal: 390.0, interest: 10.0, balance: 600.0)],
          payments: [],
          notes: '',
        ),
      ];

      final assessment = LoanUtils.assessBorrower(borrower, loans);
      expect(assessment.dtiPct, 10);
      expect(assessment.riskRating, 'low');
    });

    test('DTI normalization converts daily repayment frequency to monthly debt (~30.4x)', () {
      final borrower = Borrower(
        id: 'b2',
        fullName: 'Daily Borrower',
        email: '',
        phone: '',
        address: '',
        idNumber: '',
        employment: '',
        monthlyIncome: 3000.0,
        creditScore: 75,
        riskRating: 'low',
        notes: '',
      );

      final dailyLoan = Loan(
        id: 'daily_l1',
        borrowerId: 'b2',
        principal: 1000.0,
        interestRate: 12.0,
        termMonths: 0,
        repaymentFrequency: 'daily',
        termCount: 30,
        purpose: 'Daily Test',
        status: 'active',
        disbursementDate: '2026-01-01',
        schedule: [ScheduleInstallment(installmentNo: 1, dueDate: '2026-01-02', amount: 35.0, principal: 33.0, interest: 2.0, balance: 967.0)],
        payments: [],
        notes: '',
      );

      final assessment = LoanUtils.assessBorrower(borrower, [dailyLoan]);
      // Daily 35.0 * 30.4167 = ~1064.58 monthly debt. DTI = 1064.58 / 3000 = ~35%
      expect(assessment.monthlyDebt, closeTo(1064.58, 1.0));
      expect(assessment.dtiPct, 35);
    });
  });

  group('LoanUtils.computeEarlyPayoffAmount and validateLoanParams', () {
    test('early payoff amount for reducing loan is less than sum of remaining scheduled installments', () {
      final schedule = LoanUtils.generateSchedule(10000.0, 12.0, 12, '2026-01-01');
      final loan = Loan(
        id: 'reducing_early_payoff',
        borrowerId: 'b1',
        principal: 10000.0,
        interestRate: 12.0,
        termMonths: 12,
        repaymentFrequency: 'monthly',
        interestMethod: 'reducing',
        termCount: 12,
        purpose: 'Early Payoff Test',
        status: 'active',
        disbursementDate: '2026-01-01',
        schedule: schedule,
        payments: [],
        notes: '',
      );

      final stats = LoanUtils.getLoanStats(loan, DateTime.parse('2026-01-15'));
      // Total scheduled includes 12 months of interest (~10,661.85). Early payoff at day 14 should be ~10,040 (principal + 14 days interest)
      expect(stats.payoffAmount, lessThan(stats.totalScheduled));
      expect(stats.payoffAmount, greaterThan(10000.0));
    });

    test('validateLoanParams rejects negative interest, negative penalty, and excessive tenure', () {
      expect(LoanUtils.validateLoanParams(principal: -100, interestRate: 10, termCount: 6, repaymentFrequency: 'monthly', penaltyValue: 0), isNotNull);
      expect(LoanUtils.validateLoanParams(principal: 1000, interestRate: -5, termCount: 6, repaymentFrequency: 'monthly', penaltyValue: 0), isNotNull);
      expect(LoanUtils.validateLoanParams(principal: 1000, interestRate: 10, termCount: 6, repaymentFrequency: 'monthly', penaltyValue: -10), isNotNull);
      expect(LoanUtils.validateLoanParams(principal: 1000, interestRate: 10, termCount: 100, repaymentFrequency: 'monthly', penaltyValue: 0), isNotNull);
      expect(LoanUtils.validateLoanParams(principal: 1000, interestRate: 10, termCount: 12, repaymentFrequency: 'monthly', penaltyValue: 0), isNull);
    });
  });

  group('EIR, APR, Layered Fees & Philippine Regulatory Caps Tests', () {
    test('computeNominalRate, computeEffectiveInterestRate, and computeAPR calculate correctly', () {
      final monthlyNIR = LoanUtils.computeNominalRate(
        interestRate: 12.0,
        interestMethod: 'reducing',
        repaymentFrequency: 'monthly',
        termCount: 12,
        principal: 10000.0,
      );
      expect(monthlyNIR, 1.0); // 12% / 12 = 1.0% per month

      final monthlyEIR = LoanUtils.computeEffectiveInterestRate(
        principal: 10000.0,
        interestRate: 12.0,
        termCount: 12,
        repaymentFrequency: 'monthly',
        interestMethod: 'reducing',
        totalFees: 300.0, // ₱300 upfront processing fee
      );
      expect(monthlyEIR, greaterThan(monthlyNIR)); // EIR > NIR due to upfront fee
      expect(monthlyEIR, closeTo(1.48, 0.1));

      final apr = LoanUtils.computeAPR(effectiveMonthlyRate: monthlyEIR);
      expect(apr, closeTo(monthlyEIR * 12, 0.01));
    });

    test('calculateTotalUpfrontFees handles percent_per_day daily service fee (Tala model)', () {
      // ₱1,000 principal, 0.5% per day service fee for 15 days
      final totalFees = LoanUtils.calculateTotalUpfrontFees(
        principal: 1000.0,
        serviceFeeType: 'percent_per_day',
        serviceFeeValue: 0.5,
        termCount: 15,
        frequency: 'daily',
      );
      // 0.5% * 15 days = 7.5% of 1,000 = ₱75.00
      expect(totalFees, 75.0);
    });

    test('isCoveredSmallLoan identifies loans <= P10,000 and <= 4 months', () {
      expect(
        LoanUtils.isCoveredSmallLoan(principal: 5000, termCount: 3, repaymentFrequency: 'monthly'),
        isTrue,
      );
      expect(
        LoanUtils.isCoveredSmallLoan(principal: 15000, termCount: 3, repaymentFrequency: 'monthly'),
        isFalse, // principal > 10k
      );
      expect(
        LoanUtils.isCoveredSmallLoan(principal: 5000, termCount: 6, repaymentFrequency: 'monthly'),
        isFalse, // term > 4 months (180 days)
      );
    });

    test('validateLoanParams enforces SEC/BSP regulatory caps on covered loans', () {
      // Nominal rate > 6% per month (e.g. 84% annual = 7%/month)
      final errHighNIR = LoanUtils.validateLoanParams(
        principal: 5000,
        interestRate: 84.0, // 7% / mo
        termCount: 3,
        repaymentFrequency: 'monthly',
        penaltyValue: 0,
        enforceCoveredCaps: true,
      );
      expect(errHighNIR, contains('Nominal interest rate'));

      // Penalty > 5% per month
      final errHighPenalty = LoanUtils.validateLoanParams(
        principal: 5000,
        interestRate: 12.0,
        termCount: 3,
        repaymentFrequency: 'monthly',
        penaltyValue: 10.0,
        penaltyType: 'percent_per_period',
        enforceCoveredCaps: true,
      );
      expect(errHighPenalty, contains('Penalty rate'));
    });

    test('calculatePenalty enforces 100%-of-principal total-cost cap (Interest + Fees + Penalties <= Principal)', () {
      final schedule = [
        ScheduleInstallment(installmentNo: 1, dueDate: '2025-01-01', amount: 1000.0, principal: 800.0, interest: 200.0, balance: 0.0),
      ];

      // Principal = 1000. Interest = 200. Fees = 300. Max penalty allowed = 1000 - 200 - 300 = 500.
      final loan = Loan(
        id: 'cap_test_loan',
        borrowerId: 'b1',
        principal: 1000.0,
        interestRate: 20.0,
        termMonths: 1,
        purpose: 'Cap Test',
        status: 'active',
        disbursementDate: '2025-01-01',
        processingFeeType: 'fixed',
        processingFeeValue: 300.0,
        penaltyType: 'fixed_per_period',
        penaltyValue: 800.0, // Attempted penalty = 800
        schedule: schedule,
        payments: [],
        notes: '',
      );

      final statusSched = LoanUtils.getScheduleWithStatus(schedule, [], 'active', DateTime.parse('2025-02-01'));
      final penalty = LoanUtils.calculatePenalty(loan, statusSched, DateTime.parse('2025-02-01'));

      // Penalty should be capped at 500.0 so Total Cost = 200 + 300 + 500 = 1000 (100% of principal)
      expect(penalty, 500.0);
    });
  });
}
