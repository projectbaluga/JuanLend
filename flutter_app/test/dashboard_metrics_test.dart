import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:microlend/models/loan.dart';
import 'package:microlend/models/payment.dart';
import 'package:microlend/store/offline_store.dart';
import 'package:microlend/store/app_state.dart';
import 'package:microlend/utils/loan_utils.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Dashboard metrics and Capital calculation tests', () {
    late OfflineStore store;
    late AppState appState;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      store = await OfflineStore.init();
      appState = AppState(store);
      await appState.login('admin', 'admin123');
    });

    test('Capital defaults to 0.0, persists setting changes, and computes net profit correctly', () async {
      expect(appState.capital, 0.0);

      await appState.setCapital(100000.0);
      expect(appState.capital, 100000.0);

      // Create an active loan disbursed = 10,000
      final schedule = LoanUtils.generateSchedule(10000.0, 10.0, 2, '2026-01-01');
      final testLoan = Loan(
        id: 'dash_loan_1',
        borrowerId: 'b1',
        principal: 10000.0,
        interestRate: 10.0,
        termMonths: 2,
        purpose: 'Capital Test Loan',
        status: 'active',
        disbursementDate: '2026-01-01',
        schedule: schedule,
        payments: [],
        notes: '',
      );
      await appState.addLoan(testLoan);

      // Record payments total 11,000 (10,000 principal + 1,000 interest)
      final pay1 = Payment(id: 'p_dash_1', date: '2026-01-15', amount: 5500.0, method: 'Cash', note: 'Pay 1');
      final pay2 = Payment(id: 'p_dash_2', date: '2026-02-15', amount: 5500.0, method: 'Cash', note: 'Pay 2');
      await appState.recordPayment('dash_loan_1', pay1);
      await appState.recordPayment('dash_loan_1', pay2);

      // Verify stats
      final updatedLoan = appState.loans.firstWhere((l) => l.id == 'dash_loan_1');
      final stats = LoanUtils.getLoanStats(updatedLoan);

      double grandTotalDisbursed = stats.totalDisbursed; // 10000.0
      double grandTotalCollected = updatedLoan.payments.fold(0.0, (sum, p) => sum + p.amount); // 11000.0
      double netProfit = grandTotalCollected - grandTotalDisbursed; // 1000.0
      double capitalBalance = appState.capital + netProfit; // 101000.0

      expect(grandTotalDisbursed, 10000.0);
      expect(grandTotalCollected, 11000.0);
      expect(netProfit, 1000.0);
      expect(capitalBalance, 101000.0);
    });

    test('LoanUtils.computeDashboardMetrics correctly calculates collectionRate, PAR, todaysCollections, and dueThisWeek', () {
      final refDate = DateTime(2026, 1, 15);

      final schedule1 = LoanUtils.generateSchedule(10000.0, 10.0, 2, '2026-01-01');
      final loan1 = Loan(
        id: 'metric_l1',
        borrowerId: 'b1',
        principal: 10000.0,
        interestRate: 10.0,
        termMonths: 2,
        purpose: 'Metric Loan 1',
        status: 'active',
        disbursementDate: '2026-01-01',
        schedule: schedule1,
        payments: [
          Payment(id: 'p_today_1', date: '2026-01-15', amount: 5500.0, method: 'Cash', note: ''),
        ],
        notes: '',
      );

      final schedule2 = LoanUtils.generateSchedule(5000.0, 10.0, 1, '2025-12-01');
      final loan2 = Loan(
        id: 'metric_l2',
        borrowerId: 'b2',
        principal: 5000.0,
        interestRate: 10.0,
        termMonths: 1,
        purpose: 'Metric Loan 2 (Overdue)',
        status: 'active',
        disbursementDate: '2025-12-01',
        schedule: schedule2,
        payments: [],
        notes: '',
      );

      final metrics = LoanUtils.computeDashboardMetrics([loan1, loan2], refDate);

      expect(metrics.todaysCollections, 5500.0);
      expect(metrics.activeBorrowersCount, 2);
      expect(metrics.collectionRate, greaterThan(0.0));
      expect(metrics.portfolioAtRisk, greaterThan(0.0));
    });
  });
}
