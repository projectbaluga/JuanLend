import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:microlend/models/borrower.dart';
import 'package:microlend/models/credit_assessment.dart';
import 'package:microlend/models/loan.dart';
import 'package:microlend/models/payment.dart';
import 'package:microlend/models/schedule_installment.dart';
import 'package:microlend/store/offline_store.dart';
import 'package:microlend/store/app_state.dart';
import 'package:microlend/utils/license_verifier.dart';
import 'package:microlend/utils/loan_utils.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AppState loan lifecycle, RBAC, race protection & overpayment', () {
    late OfflineStore store;
    late AppState appState;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      store = await OfflineStore.init();
      appState = AppState(store);
      // Login seeded default admin (username: 'admin', password: 'admin123')
      await appState.login('admin', 'admin123');
    });

    test('solo mode auto-activates loan creation and bypasses separation of duties', () async {
      expect(appState.isSoloMode, isTrue);

      final soloLoan = Loan(
        id: 'solo_loan_1',
        borrowerId: 'b1',
        principal: 3000.0,
        interestRate: 10.0,
        termMonths: 6,
        purpose: 'Solo Operator Loan',
        status: 'pending',
        disbursementDate: '2026-03-01',
        schedule: [],
        payments: [],
        notes: '',
      );

      await appState.addLoan(soloLoan);

      final created = appState.loans.firstWhere((l) => l.id == 'solo_loan_1');
      expect(created.status, 'active');
      expect(created.schedule.isNotEmpty, isTrue);
      expect(created.createdBy, appState.currentUser!.id);

      // Transitioning status or approving if pending does not throw separation of duties error in solo mode
      await appState.markLoanStatus('solo_loan_1', 'completed');
      expect(appState.loans.firstWhere((l) => l.id == 'solo_loan_1').status, 'completed');
    });

    test('RBAC role enforcement, createUser and separation of duties', () async {
      // 1. Create officer user using admin (approver role)
      await appState.createUser('officer_jane', 'officer123', 'officer');
      await appState.createUser('viewer_bob', 'viewer123', 'viewer');

      expect(appState.isSoloMode, isFalse);

      // 2. Viewer role cannot create loans or users
      await appState.login('viewer_bob', 'viewer123');
      final loanCandidate = Loan(
        id: 'viewer_loan',
        borrowerId: 'b1',
        principal: 1000.0,
        interestRate: 10.0,
        termMonths: 6,
        purpose: 'Viewer Loan',
        status: 'pending',
        disbursementDate: '2026-01-01',
        schedule: [],
        payments: [],
        notes: '',
      );
      expect(() => appState.addLoan(loanCandidate), throwsStateError);
      expect(() => appState.createUser('test_u', 'pwd', 'officer'), throwsStateError);

      // 3. Officer role CAN create loan
      await appState.login('officer_jane', 'officer123');
      final officerLoan = Loan(
        id: 'officer_loan_1',
        borrowerId: 'b1',
        principal: 2000.0,
        interestRate: 10.0,
        termMonths: 6,
        purpose: 'Officer Created Loan',
        status: 'pending',
        disbursementDate: '2026-01-01',
        schedule: [],
        payments: [],
        notes: '',
      );
      await appState.addLoan(officerLoan);
      expect(appState.loans.any((l) => l.id == 'officer_loan_1'), isTrue);

      // 4. Officer role CANNOT approve loan
      expect(() => appState.approveLoan('officer_loan_1'), throwsStateError);

      // 5. Approver role CAN approve loan created by officer
      await appState.login('admin', 'admin123');
      await appState.approveLoan('officer_loan_1');
      var approvedLoan = appState.loans.firstWhere((l) => l.id == 'officer_loan_1');
      expect(approvedLoan.status, 'active');

      // 6. Approver role CANNOT approve loan created by themselves (separation of duties)
      final approverOwnLoan = Loan(
        id: 'approver_own_loan',
        borrowerId: 'b1',
        principal: 1500.0,
        interestRate: 12.0,
        termMonths: 6,
        purpose: 'Approver Own Loan',
        status: 'pending',
        disbursementDate: '2026-01-01',
        schedule: [],
        payments: [],
        notes: '',
      );
      await appState.addLoan(approverOwnLoan); // createdBy set to 'usr_admin'
      expect(() => appState.approveLoan('approver_own_loan'), throwsStateError);
    });

    test('approving a weekly/flat loan preserves frequency, method, and installment count', () async {
      await appState.createUser('officer_weekly', 'officer123', 'officer');
      await appState.login('officer_weekly', 'officer123');

      final pendingWeeklyLoan = Loan(
        id: 'weekly_flat_loan_test',
        borrowerId: 'b1',
        principal: 1000.0,
        interestRate: 20.0,
        termMonths: 0,
        repaymentFrequency: 'weekly',
        interestMethod: 'flat',
        termCount: 10,
        purpose: 'Weekly Flat Test',
        status: 'pending',
        disbursementDate: '2026-02-01',
        schedule: [],
        payments: [],
        notes: '',
      );
      await appState.addLoan(pendingWeeklyLoan);

      await appState.login('admin', 'admin123');
      await appState.approveLoan('weekly_flat_loan_test');

      final approved = appState.loans.firstWhere((l) => l.id == 'weekly_flat_loan_test');
      expect(approved.status, 'active');
      expect(approved.repaymentFrequency, 'weekly');
      expect(approved.interestMethod, 'flat');
      expect(approved.termCount, 10);
      expect(approved.schedule.length, 10);
    });

    test('illegal status transitions are rejected', () async {
      await appState.createUser('officer_trans', 'officer123', 'officer');
      await appState.login('officer_trans', 'officer123');

      final pendingLoan = Loan(
        id: 'trans_pending',
        borrowerId: 'b1',
        principal: 1000.0,
        interestRate: 10.0,
        termMonths: 6,
        purpose: 'Transition Test Pending',
        status: 'pending',
        disbursementDate: '2026-01-01',
        schedule: [],
        payments: [],
        notes: '',
      );
      final activeLoan = Loan(
        id: 'trans_active',
        borrowerId: 'b1',
        principal: 1000.0,
        interestRate: 10.0,
        termMonths: 6,
        purpose: 'Transition Test Active',
        status: 'active',
        disbursementDate: '2026-01-01',
        schedule: [],
        payments: [],
        notes: '',
      );
      final completedLoan = Loan(
        id: 'trans_completed',
        borrowerId: 'b1',
        principal: 1000.0,
        interestRate: 10.0,
        termMonths: 6,
        purpose: 'Transition Test Completed',
        status: 'completed',
        disbursementDate: '2026-01-01',
        schedule: [],
        payments: [],
        notes: '',
      );
      final defaultedLoan = Loan(
        id: 'trans_defaulted',
        borrowerId: 'b1',
        principal: 1000.0,
        interestRate: 10.0,
        termMonths: 6,
        purpose: 'Transition Test Defaulted',
        status: 'defaulted',
        disbursementDate: '2026-01-01',
        schedule: [],
        payments: [],
        notes: '',
      );

      await appState.addLoan(pendingLoan);
      await appState.addLoan(activeLoan);
      await appState.addLoan(completedLoan);
      await appState.addLoan(defaultedLoan);

      await appState.login('admin', 'admin123');

      // Re-approving active or completed loan is rejected
      expect(() => appState.approveLoan('trans_active'), throwsArgumentError);
      expect(() => appState.approveLoan('trans_completed'), throwsArgumentError);

      // Illegal status transitions via markLoanStatus are rejected
      expect(() => appState.markLoanStatus('trans_pending', 'completed'), throwsArgumentError);
      expect(() => appState.markLoanStatus('trans_pending', 'defaulted'), throwsArgumentError);
      expect(() => appState.markLoanStatus('trans_defaulted', 'completed'), throwsArgumentError);
      expect(() => appState.markLoanStatus('trans_completed', 'active'), throwsArgumentError);
    });

    test('changePassword updates password hash with new salt and rejects wrong old password', () async {
      final adminUser = appState.currentUser!;
      final oldSalt = adminUser.salt;

      // Wrong old password throws error
      expect(
        () => appState.changePassword(adminUser.id, 'wrong_old', 'new_pass_123'),
        throwsArgumentError,
      );

      // Successful change password
      await appState.changePassword(adminUser.id, 'admin123', 'new_pass_123');

      final updatedUser = appState.currentUser!;
      expect(updatedUser.salt, isNot(equals(oldSalt))); // Salt re-generated
      expect(updatedUser.mustChangePassword, false);

      // Old password no longer verifies
      expect(updatedUser.verifyPassword('admin123'), false);
      expect(updatedUser.verifyPassword('new_pass_123'), true);
    });

    test('concurrent recordPayment via Future.wait persists both payments without lost updates', () async {
      await appState.createUser('officer_test', 'officer123', 'officer');
      await appState.login('officer_test', 'officer123');

      final activeLoan = Loan(
        id: 'loan_concurrent_pay',
        borrowerId: 'b1',
        principal: 1000.0,
        interestRate: 10.0,
        termMonths: 6,
        purpose: 'Concurrent Payment Test',
        status: 'active',
        disbursementDate: '2026-01-01',
        schedule: [],
        payments: [],
        notes: '',
      );
      await appState.addLoan(activeLoan);

      final pay1 = Payment(id: 'pay_conc_1', date: '2026-02-01', amount: 150.0, method: 'Cash', note: 'Pay 1');
      final pay2 = Payment(id: 'pay_conc_2', date: '2026-02-01', amount: 250.0, method: 'Check', note: 'Pay 2');

      // Fire both recordPayment calls concurrently
      await Future.wait([
        appState.recordPayment('loan_concurrent_pay', pay1),
        appState.recordPayment('loan_concurrent_pay', pay2),
      ]);

      final updatedLoan = appState.loans.firstWhere((l) => l.id == 'loan_concurrent_pay');
      expect(updatedLoan.payments.length, 2);
      expect(updatedLoan.payments.any((p) => p.id == 'pay_conc_1'), isTrue);
      expect(updatedLoan.payments.any((p) => p.id == 'pay_conc_2'), isTrue);

      // Idempotency: re-applying pay1 again does not duplicate
      await appState.recordPayment('loan_concurrent_pay', pay1);
      final refetched = appState.loans.firstWhere((l) => l.id == 'loan_concurrent_pay');
      expect(refetched.payments.length, 2);
    });

    test('verify no hardcoded demo credentials remain in login_screen.dart', () {
      final loginScreenFile = File('lib/screens/login_screen.dart');
      expect(loginScreenFile.existsSync(), isTrue);
      final content = loginScreenFile.readAsStringSync();

      expect(content.contains("text: 'approver'"), isFalse);
      expect(content.contains("text: 'approver123'"), isFalse);
      expect(content.contains("Demo Credentials"), isFalse);
      expect(content.contains("_quickFill"), isFalse);
    });

    test('AppState appName returns active app branding name', () {
      expect(appState.appName, equals(appState.businessName));
    });

    test('reload re-hydrates preferences and notifies listeners', () async {
      bool notified = false;
      appState.addListener(() => notified = true);

      await store.saveCollection('borrowers', [
        {
          'id': 'b_reload_test',
          'fullName': 'Reload Borrower',
          'email': 'reload@example.com',
          'phone': '1234567890',
          'address': 'Reload St',
          'idNumber': 'ID-RELOAD',
          'employment': 'Self',
          'monthlyIncome': 5000.0,
          'creditScore': 75,
          'riskRating': 'low',
          'notes': '',
          'createdAt': '2026-01-01',
        }
      ]);

      await appState.reload();

      expect(notified, isTrue);
      expect(appState.borrowers.any((b) => b.id == 'b_reload_test'), isTrue);
    });

    test('defaultTermPeriods reads setting and supports legacy defaultTermMonths key fallback', () async {
      await store.setSetting('defaultTermMonths', '12');
      final legacyState = AppState(store);
      expect(legacyState.defaultTermPeriods, 12);

      await legacyState.setDefaultTermPeriods(24);
      expect(legacyState.defaultTermPeriods, 24);
      expect(store.getSetting('defaultTermPeriods', ''), '24');
    });

    test('high risk loan blocks approval unless overrideHighRisk is true', () async {
      await appState.createUser('officer_hr', 'officer123', 'officer');
      await appState.login('officer_hr', 'officer123');

      final highRiskAssessment = CreditAssessment(
        creditScore: 30,
        baseCreditScore: 30,
        dtiPct: 75,
        riskRating: 'high',
        monthlyDebt: 3000.0,
        completedCount: 0,
        defaultedCount: 1,
        activeCount: 1,
      );

      final highRiskLoan = Loan(
        id: 'high_risk_loan_1',
        borrowerId: 'b1',
        principal: 5000.0,
        interestRate: 15.0,
        termMonths: 6,
        purpose: 'High Risk Test',
        status: 'pending',
        disbursementDate: '2026-01-01',
        creditAssessment: highRiskAssessment,
        schedule: [],
        payments: [],
        notes: '',
      );

      await appState.addLoan(highRiskLoan);

      await appState.login('admin', 'admin123');

      // Approving without override throws StateError
      expect(() => appState.approveLoan('high_risk_loan_1'), throwsStateError);

      // Approving with override succeeds
      await appState.approveLoan('high_risk_loan_1', overrideHighRisk: true);
      final approved = appState.loans.firstWhere((l) => l.id == 'high_risk_loan_1');
      expect(approved.status, 'active');
    });

    test('LicenseVerifier.verifyUnlockCode accurately verifies master code', () {
      expect(LicenseVerifier.verifyUnlockCode('MICROLEND-FULL-UNLOCK'), isTrue);
      expect(LicenseVerifier.verifyUnlockCode('  MICROLEND-FULL-UNLOCK  \n'), isTrue);
      expect(LicenseVerifier.verifyUnlockCode('WRONG-CODE'), isFalse);
      expect(LicenseVerifier.verifyUnlockCode(''), isFalse);
    });

    test('borrower limit enforcement, unlocking with master code, and lockFeatures', () async {
      expect(appState.isFeaturesUnlocked, isFalse);

      final initialCount = appState.borrowers.length;
      final neededToAdd = 5 - initialCount;

      for (int i = 0; i < neededToAdd; i++) {
        await appState.addBorrower(Borrower(
          id: 'b_lim_$i',
          fullName: 'Borrower $i',
          email: 'b$i@example.com',
          phone: '123456789$i',
          address: 'Address $i',
          idNumber: 'ID-$i',
          employment: 'Self',
          monthlyIncome: 3000.0,
          creditScore: 60,
          riskRating: 'medium',
          notes: '',
          createdAt: '2026-01-01',
        ));
      }

      expect(appState.borrowers.length, 5);

      // 6th borrower while locked throws StateError
      expect(
        () => appState.addBorrower(Borrower(
          id: 'b_lim_6',
          fullName: 'Borrower 6',
          email: 'b6@example.com',
          phone: '1234567896',
          address: 'Address 6',
          idNumber: 'ID-6',
          employment: 'Self',
          monthlyIncome: 3000.0,
          creditScore: 60,
          riskRating: 'medium',
          notes: '',
          createdAt: '2026-01-01',
        )),
        throwsStateError,
      );

      // 1. Invalid / empty code fails
      final wrongRes = await appState.unlockFeatures('invalid_code_string');
      expect(wrongRes, isFalse);
      expect(appState.isFeaturesUnlocked, isFalse);

      final emptyRes = await appState.unlockFeatures('');
      expect(emptyRes, isFalse);
      expect(appState.isFeaturesUnlocked, isFalse);

      // 2. Correct master unlock code succeeds
      final unlockRes = await appState.unlockFeatures('  MICROLEND-FULL-UNLOCK  ');
      expect(unlockRes, isTrue);
      expect(appState.isFeaturesUnlocked, isTrue);

      // 3. Adding 6th borrower succeeds when unlocked
      await appState.addBorrower(Borrower(
        id: 'b_lim_6',
        fullName: 'Borrower 6',
        email: 'b6@example.com',
        phone: '1234567896',
        address: 'Address 6',
        idNumber: 'ID-6',
        employment: 'Self',
        monthlyIncome: 3000.0,
        creditScore: 60,
        riskRating: 'medium',
        notes: '',
        createdAt: '2026-01-01',
      ));

      expect(appState.borrowers.length, 6);

      // 4. Persistence across reload()
      await appState.reload();
      expect(appState.isFeaturesUnlocked, isTrue);

      // 5. lockFeatures re-locks and persists
      await appState.lockFeatures();
      expect(appState.isFeaturesUnlocked, isFalse);

      await appState.reload();
      expect(appState.isFeaturesUnlocked, isFalse);
    });

    test('completion accounts for penalties and overpayment produces credit balance', () async {
      await appState.createUser('officer_pay', 'officer123', 'officer');
      await appState.login('officer_pay', 'officer123');

      final oldDueDate = '2020-01-01'; // Overdue date to trigger penalty
      final schedule = [
        ScheduleInstallment(
          installmentNo: 1,
          dueDate: oldDueDate,
          amount: 500.0,
          principal: 450.0,
          interest: 50.0,
          balance: 0.0,
        ),
      ];

      final loanWithPenalty = Loan(
        id: 'loan_penalty_1',
        borrowerId: 'b1',
        principal: 450.0,
        interestRate: 10.0,
        termMonths: 1,
        purpose: 'Test Penalty Completion',
        status: 'active',
        disbursementDate: '2019-12-01',
        penaltyType: 'fixed_once',
        penaltyValue: 50.0,
        schedule: schedule,
        payments: [],
        notes: '',
      );

      await appState.addLoan(loanWithPenalty);

      // Total scheduled is 500.0, penalty is 50.0, total required for completion is 550.0.
      // 1st payment: 500.0 (covers scheduled amount only)
      final pay1 = Payment(id: 'p1', date: '2026-01-01', amount: 500.0, method: 'Cash', note: '');
      await appState.recordPayment('loan_penalty_1', pay1);

      var updatedLoan = appState.loans.firstWhere((l) => l.id == 'loan_penalty_1');
      expect(updatedLoan.status, 'active');

      // 2nd payment: 100.0 (covers 50.0 penalty + 50.0 overpayment)
      final pay2 = Payment(id: 'p2', date: '2026-01-02', amount: 100.0, method: 'Cash', note: '');
      await appState.recordPayment('loan_penalty_1', pay2);

      updatedLoan = appState.loans.firstWhere((l) => l.id == 'loan_penalty_1');
      expect(updatedLoan.status, 'completed');

      final stats = LoanUtils.getLoanStats(updatedLoan);
      expect(stats.creditBalance, 50.0);
    });

    test('allPayments getter flattens, joins borrowers, sorts descending, and handles legacy payments', () async {
      await appState.createUser('officer_log', 'officer123', 'officer');
      await appState.login('officer_log', 'officer123');

      final borrower = Borrower(
        id: 'bor_log_1',
        fullName: 'Payment Log Borrower',
        email: 'log@example.com',
        phone: '09123456789',
        address: '123 Log St',
        idNumber: 'ID-LOG',
        employment: 'Employed',
        monthlyIncome: 25000.0,
        creditScore: 75,
        riskRating: 'low',
        notes: '',
      );
      await appState.addBorrower(borrower);

      final legacyPayment = Payment.fromMap({
        'id': 'p_legacy_1',
        'date': '2026-01-10',
        'amount': 500.0,
        'method': 'Cash',
        'note': 'Legacy Payment Note',
      });
      expect(legacyPayment.recordedBy, '');
      expect(legacyPayment.recordedByRole, '');
      expect(legacyPayment.recordedAt, '');

      final loan1 = Loan(
        id: 'loan_log_1',
        borrowerId: 'bor_log_1',
        principal: 5000.0,
        interestRate: 10.0,
        termMonths: 6,
        purpose: 'Payment Log Loan 1',
        status: 'active',
        disbursementDate: '2026-01-01',
        schedule: [],
        payments: [legacyPayment],
        notes: '',
      );
      await appState.addLoan(loan1);

      final newPayment = Payment(
        id: 'p_new_1',
        date: '2026-02-15',
        amount: 750.0,
        method: 'GCash / E-Wallet',
        note: 'New Payment Note',
      );
      await appState.recordPayment('loan_log_1', newPayment);

      final allPayments = appState.allPayments;
      expect(allPayments.isNotEmpty, isTrue);

      final latestEntry = allPayments.firstWhere((e) => e.payment.id == 'p_new_1');
      expect(latestEntry.payment.amount, 750.0);
      expect(latestEntry.borrower.fullName, 'Payment Log Borrower');
      expect(latestEntry.loan.purpose, 'Payment Log Loan 1');
      expect(latestEntry.payment.recordedBy, 'officer_log');
      expect(latestEntry.payment.recordedByRole, 'officer');
      expect(latestEntry.payment.recordedAt.isNotEmpty, isTrue);

      final legacyEntry = allPayments.firstWhere((e) => e.payment.id == 'p_legacy_1');
      expect(legacyEntry.payment.recordedBy, '');

      expect(allPayments.first.payment.date.compareTo(allPayments.last.payment.date) >= 0, isTrue);
    });

    test('rolloverLoan and topUpLoan work correctly with permissions and limits', () async {
      await appState.createUser('officer_rt', 'officer123', 'officer');
      await appState.login('officer_rt', 'officer123');

      final borrower = Borrower(
        id: 'bor_topup',
        fullName: 'Topup Borrower',
        email: '',
        phone: '',
        address: '',
        idNumber: '',
        employment: '',
        monthlyIncome: 10000.0, // Credit limit = 50,000
        creditScore: 80,
        riskRating: 'low',
        notes: '',
      );
      await appState.addBorrower(borrower);

      final loan = Loan(
        id: 'active_loan_topup',
        borrowerId: 'bor_topup',
        principal: 5000.0,
        interestRate: 12.0,
        termMonths: 6,
        purpose: 'TopUp Test',
        status: 'active',
        disbursementDate: '2026-01-01',
        schedule: LoanUtils.generateSchedule(5000.0, 12.0, 6, '2026-01-01'),
        payments: [],
        notes: '',
      );
      await appState.addLoan(loan);

      // Top up 2000 principal
      await appState.topUpLoan(loan.id, additionalPrincipal: 2000.0);
      final toppedUpLoan = appState.loans.firstWhere((l) => l.id == loan.id);
      expect(toppedUpLoan.principal, 7000.0);

      // Rollover by extending 2 periods with fixed fee
      await appState.rolloverLoan(loan.id, extensionPeriods: 2, extensionFeeValue: 150.0, extensionFeeType: 'fixed');
      final rolledOverLoan = appState.loans.firstWhere((l) => l.id == loan.id);
      expect(rolledOverLoan.termCount, 8);
      expect(rolledOverLoan.serviceFeeValue, 150.0);
    });
  });
}
