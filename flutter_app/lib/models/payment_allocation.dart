class PaymentAllocation {
  final String paymentId;
  final double totalAmount;
  final double principalPortion;
  final double interestPortion;
  final double penaltyPortion;
  final double excessAmount;
  final List<int> coveredInstallmentNos;

  PaymentAllocation({
    required this.paymentId,
    required this.totalAmount,
    required this.principalPortion,
    required this.interestPortion,
    required this.penaltyPortion,
    required this.excessAmount,
    required this.coveredInstallmentNos,
  });

  String get coveredInstallmentsRange {
    if (coveredInstallmentNos.isEmpty) return 'None';
    if (coveredInstallmentNos.length == 1) return '#${coveredInstallmentNos.first}';
    final sorted = List<int>.from(coveredInstallmentNos)..sort();
    bool isSequential = true;
    for (int i = 0; i < sorted.length - 1; i++) {
      if (sorted[i + 1] != sorted[i] + 1) {
        isSequential = false;
        break;
      }
    }
    if (isSequential) {
      return '#${sorted.first}–#${sorted.last}';
    }
    return sorted.map((n) => '#$n').join(', ');
  }
}
