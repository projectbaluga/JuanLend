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

  group('LoanUtils.validateLoanParams & Kaltas-Agad Upfront Interest Deduction', () {
    test('validateLoanParams rejects negative interest, negative penalty, and excessive tenure', () {
      expect(LoanUtils.validateLoanParams(principal: -100, interestRate: 10, termCount: 6, repaymentFrequency: 'monthly', penaltyValue: 0), isNotNull);
      expect(LoanUtils.validateLoanParams(principal: 1000, interestRate: -5, termCount: 6, repaymentFrequency: 'monthly', penaltyValue: 0), isNotNull);
      expect(LoanUtils.validateLoanParams(principal: 1000, interestRate: 10, termCount: 6, repaymentFrequency: 'monthly', penaltyValue: -10), isNotNull);
      expect(LoanUtils.validateLoanParams(principal: 1000, interestRate: 10, termCount: 100, repaymentFrequency: 'monthly', penaltyValue: 0), isNotNull);
      expect(LoanUtils.validateLoanParams(principal: 1000, interestRate: 10, termCount: 12, repaymentFrequency: 'monthly', penaltyValue: 0), isNull);
    });

    test('kaltas-agad upfront interest deduction calculates net disbursed = 4500, total scheduled = 5000, and zero interest in schedule', () {
      final p = 5000.0;
      final r = 10.0;
      final termCount = 30;
      final frequency = 'daily';

      final interestDeduction = LoanUtils.round2(p * r / 100.0); // 500.0
      expect(interestDeduction, 500.0);

      final totalFees = LoanUtils.calculateTotalUpfrontFees(
        principal: p,
        upfrontDeductionType: 'fixed',
        upfrontDeductionValue: interestDeduction,
      );
      expect(totalFees, 500.0);

      final netDisbursed = LoanUtils.calculateNetDisbursed(p, 'fixed', interestDeduction);
      expect(netDisbursed, 4500.0);

      final schedule = LoanUtils.generateSchedule(
        p,
        0.0, // interest-free installments because interest is deducted upfront
        termCount,
        '2026-01-01',
        repaymentFrequency: frequency,
        interestMethod: 'flat',
      );

      expect(schedule.length, 30);
      final totalScheduled = schedule.fold(0.0, (sum, inst) => sum + inst.amount);
      final totalInterest = schedule.fold(0.0, (sum, inst) => sum + inst.interest);

      expect(totalScheduled, closeTo(5000.0, 0.01));
      expect(totalInterest, 0.0);
      expect(schedule.first.interest, 0.0);
      expect(schedule.first.principal, closeTo(166.67, 0.1));
    });
  });

  group('Upfront Fees & Penalty Tests', () {
    test('calculateTotalUpfrontFees handles percent_per_day daily service fee', () {
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
  });
}
