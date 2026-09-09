import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:microlend/models/loan.dart';
import 'package:microlend/models/payment.dart';
import 'package:microlend/store/offline_store.dart';
import 'package:microlend/store/app_state.dart';
import 'package:microlend/utils/loan_utils.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Held credit and manual credit application tests', () {
    late OfflineStore store;
    late AppState appState;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      store = await OfflineStore.init();
      appState = AppState(store);
      await appState.login('admin', 'admin123');
    });

    test('Overpayment does not cascade into future non-due installments and is held as credit', () async {
      // 2 installments of 1,100 each
      final schedule = LoanUtils.generateSchedule(2000.0, 10.0, 2, '2026-01-01');
      expect(schedule.length, 2);
      expect(schedule[0].amount, 1100.0);
      expect(schedule[1].amount, 1100.0);

      final testLoan = Loan(
        id: 'held_cred_loan_1',
        borrowerId: 'b1',
        principal: 2000.0,
        interestRate: 10.0,
        termMonths: 2,
        purpose: 'Held Credit Test Loan',
        status: 'active',
        disbursementDate: '2026-01-01',
        schedule: schedule,
        payments: [],
        notes: '',
      );
      await appState.addLoan(testLoan);

      // Record a payment of 1,500 on Installment #1 (which requires 1,100)
      final pay1 = Payment(
        id: 'p_overpay_1',
        date: '2026-01-10',
        amount: 1500.0,
        method: 'Cash',
        note: 'Overpayment on #1',
      );

      // Evaluate stats as of 2026-01-15 (only installment #1 is due, #2 is due 2026-02-01)
      final refDate = DateTime(2026, 1, 15);
      await appState.recordPayment('held_cred_loan_1', pay1);

      final updatedLoan = appState.loans.firstWhere((l) => l.id == 'held_cred_loan_1');
      final stats = LoanUtils.getLoanStats(updatedLoan, refDate);

      // Installment #1 should be paid
      expect(stats.scheduleWithStatus[0].status, 'paid');
      expect(stats.scheduleWithStatus[0].paidAmount, 1100.0);

      // Installment #2 should NOT be partial; it remains pending and 0 paid
      expect(stats.scheduleWithStatus[1].status, 'pending');
      expect(stats.scheduleWithStatus[1].paidAmount, 0.0);

      // The 400 overpayment must be accumulated in heldCredit
      expect(stats.heldCredit, 400.0);
    });

    test('applyCredit reduces heldCredit and marks target installment paid with specified date', () async {
      final schedule = LoanUtils.generateSchedule(2000.0, 10.0, 2, '2026-01-01');

      final testLoan = Loan(
        id: 'held_cred_loan_2',
        borrowerId: 'b1',
        principal: 2000.0,
        interestRate: 10.0,
        termMonths: 2,
        purpose: 'Apply Credit Test Loan',
        status: 'active',
        disbursementDate: '2026-01-01',
        schedule: schedule,
        payments: [],
        notes: '',
      );
      await appState.addLoan(testLoan);

      // Overpay on installment #1 with 1,500
      final pay1 = Payment(
        id: 'p_overpay_2',
        date: '2026-01-10',
        amount: 1500.0,
        method: 'Cash',
        note: 'Overpayment on #1',
      );
      await appState.recordPayment('held_cred_loan_2', pay1);

      final refDate = DateTime(2026, 1, 15);
      var updatedLoan = appState.loans.firstWhere((l) => l.id == 'held_cred_loan_2');
      var stats = LoanUtils.getLoanStats(updatedLoan, refDate);
      expect(stats.heldCredit, 400.0);

      // Apply 400 credit to installment #2
      await appState.applyCredit(
        'held_cred_loan_2',
        installmentNo: 2,
        amount: 400.0,
        date: '2026-01-15',
      );

      updatedLoan = appState.loans.firstWhere((l) => l.id == 'held_cred_loan_2');
      expect(updatedLoan.creditApplications.length, 1);
      expect(updatedLoan.creditApplications.first.amount, 400.0);
      expect(updatedLoan.creditApplications.first.appliedToInstallmentNo, 2);
      expect(updatedLoan.creditApplications.first.date, '2026-01-15');

      stats = LoanUtils.getLoanStats(updatedLoan, refDate);

      // Held credit should now be 0.0
      expect(stats.heldCredit, 0.0);

      // Installment #2 should now have 400.0 paid amount (status partial since 1,100 is needed)
      expect(stats.scheduleWithStatus[1].paidAmount, 400.0);
      expect(stats.scheduleWithStatus[1].status, 'partial');
    });
  });
}
