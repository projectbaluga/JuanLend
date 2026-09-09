class CreditApplication {
  final String id;
  final double amount;
  final int appliedToInstallmentNo;
  final String date;
  final String appliedBy;

  CreditApplication({
    required this.id,
    required this.amount,
    required this.appliedToInstallmentNo,
    required this.date,
    required this.appliedBy,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'amount': amount,
      'appliedToInstallmentNo': appliedToInstallmentNo,
      'date': date,
      'appliedBy': appliedBy,
    };
  }

  factory CreditApplication.fromMap(Map<String, dynamic> map) {
    return CreditApplication(
      id: map['id'] ?? '',
      amount: (map['amount'] is num) ? (map['amount'] as num).toDouble() : 0.0,
      appliedToInstallmentNo: (map['appliedToInstallmentNo'] is num)
          ? (map['appliedToInstallmentNo'] as num).toInt()
          : 0,
      date: map['date'] ?? '',
      appliedBy: map['appliedBy'] ?? '',
    );
  }

  CreditApplication copyWith({
    String? id,
    double? amount,
    int? appliedToInstallmentNo,
    String? date,
    String? appliedBy,
  }) {
    return CreditApplication(
      id: id ?? this.id,
      amount: amount ?? this.amount,
      appliedToInstallmentNo: appliedToInstallmentNo ?? this.appliedToInstallmentNo,
      date: date ?? this.date,
      appliedBy: appliedBy ?? this.appliedBy,
    );
  }
}
