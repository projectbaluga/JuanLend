import 'borrower.dart';
import 'loan.dart';
import 'payment.dart';

class PaymentLogEntry {
  final Payment payment;
  final Loan loan;
  final Borrower borrower;
  final double outstandingBalanceAtPayment;

  PaymentLogEntry({
    required this.payment,
    required this.loan,
    required this.borrower,
    this.outstandingBalanceAtPayment = 0.0,
  });
}
