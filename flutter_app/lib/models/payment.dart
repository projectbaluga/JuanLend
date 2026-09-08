class Payment {
  final String id;
  final String date;
  final double amount;
  final String method;
  final String note;
  final String recordedBy;
  final String recordedByRole;
  final String recordedAt;
  final double principalPortion;
  final double interestPortion;
  final double penaltyPortion;
  final double excessAmount;

  Payment({
    required this.id,
    required this.date,
    required this.amount,
    required this.method,
    required this.note,
    this.recordedBy = '',
    this.recordedByRole = '',
    this.recordedAt = '',
    this.principalPortion = 0.0,
    this.interestPortion = 0.0,
    this.penaltyPortion = 0.0,
    this.excessAmount = 0.0,
  });

  factory Payment.fromMap(Map<String, dynamic> map) {
    return Payment(
      id: map['id']?.toString() ?? '',
      date: map['date']?.toString() ?? '',
      amount: (map['amount'] as num?)?.toDouble() ?? 0.0,
      method: map['method']?.toString() ?? '',
      note: map['note']?.toString() ?? '',
      recordedBy: map['recorded_by']?.toString() ?? map['recordedBy']?.toString() ?? '',
      recordedByRole: map['recorded_by_role']?.toString() ?? map['recordedByRole']?.toString() ?? '',
      recordedAt: map['recorded_at']?.toString() ?? map['recordedAt']?.toString() ?? '',
      principalPortion: (map['principal_portion'] as num?)?.toDouble() ?? (map['principalPortion'] as num?)?.toDouble() ?? 0.0,
      interestPortion: (map['interest_portion'] as num?)?.toDouble() ?? (map['interestPortion'] as num?)?.toDouble() ?? 0.0,
      penaltyPortion: (map['penalty_portion'] as num?)?.toDouble() ?? (map['penaltyPortion'] as num?)?.toDouble() ?? 0.0,
      excessAmount: (map['excess_amount'] as num?)?.toDouble() ?? (map['excessAmount'] as num?)?.toDouble() ?? 0.0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'date': date,
      'amount': amount,
      'method': method,
      'note': note,
      'recorded_by': recordedBy,
      'recorded_by_role': recordedByRole,
      'recorded_at': recordedAt,
      'principal_portion': principalPortion,
      'interest_portion': interestPortion,
      'penalty_portion': penaltyPortion,
      'excess_amount': excessAmount,
    };
  }

  Payment copyWith({
    String? id,
    String? date,
    double? amount,
    String? method,
    String? note,
    String? recordedBy,
    String? recordedByRole,
    String? recordedAt,
    double? principalPortion,
    double? interestPortion,
    double? penaltyPortion,
    double? excessAmount,
  }) {
    return Payment(
      id: id ?? this.id,
      date: date ?? this.date,
      amount: amount ?? this.amount,
      method: method ?? this.method,
      note: note ?? this.note,
      recordedBy: recordedBy ?? this.recordedBy,
      recordedByRole: recordedByRole ?? this.recordedByRole,
      recordedAt: recordedAt ?? this.recordedAt,
      principalPortion: principalPortion ?? this.principalPortion,
      interestPortion: interestPortion ?? this.interestPortion,
      penaltyPortion: penaltyPortion ?? this.penaltyPortion,
      excessAmount: excessAmount ?? this.excessAmount,
    );
  }
}
