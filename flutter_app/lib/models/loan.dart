import 'credit_application.dart';
import 'credit_assessment.dart';
import 'payment.dart';
import 'schedule_installment.dart';

class Loan {
  final String id;
  final String borrowerId;
  final double principal;
  final double interestRate;
  final int termMonths;
  final String repaymentFrequency; // 'daily', 'weekly', 'biweekly', 'monthly'
  final String interestMethod; // 'flat', 'one_time'
  final int termCount;
  final String purpose;
  final String status;
  final String disbursementDate;
  final String upfrontDeductionType; // 'none', 'fixed', 'percent'
  final double upfrontDeductionValue;
  final String processingFeeType; // 'none', 'fixed', 'percent', 'percent_per_day'
  final double processingFeeValue;
  final String serviceFeeType; // 'none', 'fixed', 'percent', 'percent_per_day'
  final double serviceFeeValue;
  final String disbursementFeeType; // 'none', 'fixed', 'percent', 'percent_per_day'
  final double disbursementFeeValue;
  final String notarialFeeType; // 'none', 'fixed', 'percent', 'percent_per_day'
  final double notarialFeeValue;
  final String creditLifeInsuranceFeeType; // 'none', 'fixed', 'percent', 'percent_per_day'
  final double creditLifeInsuranceFeeValue;
  final String penaltyType; // 'none', 'fixed_per_period', 'percent_per_period', 'fixed_once'
  final double penaltyValue;
  final double accruedPenalty;
  final CreditAssessment? creditAssessment;
  final List<ScheduleInstallment> schedule;
  final List<Payment> payments;
  final List<CreditApplication> creditApplications;
  final String notes;
  final String? createdBy;
  final String? createdAt;
  final String? updatedAt;

  Loan({
    required this.id,
    required this.borrowerId,
    required this.principal,
    required this.interestRate,
    required this.termMonths,
    this.repaymentFrequency = 'monthly',
    this.interestMethod = 'flat',
    int? termCount,
    required this.purpose,
    required this.status,
    required this.disbursementDate,
    this.upfrontDeductionType = 'none',
    this.upfrontDeductionValue = 0.0,
    this.processingFeeType = 'none',
    this.processingFeeValue = 0.0,
    this.serviceFeeType = 'none',
    this.serviceFeeValue = 0.0,
    this.disbursementFeeType = 'none',
    this.disbursementFeeValue = 0.0,
    this.notarialFeeType = 'none',
    this.notarialFeeValue = 0.0,
    this.creditLifeInsuranceFeeType = 'none',
    this.creditLifeInsuranceFeeValue = 0.0,
    this.penaltyType = 'none',
    this.penaltyValue = 0.0,
    this.accruedPenalty = 0.0,
    this.creditAssessment,
    required this.schedule,
    required this.payments,
    List<CreditApplication>? creditApplications,
    required this.notes,
    this.createdBy,
    this.createdAt,
    this.updatedAt,
  })  : creditApplications = creditApplications ?? [],
        termCount = termCount ?? termMonths;

  factory Loan.fromMap(Map<String, dynamic> map) {
    final termM = (map['term_months'] as num?)?.toInt() ?? (map['termMonths'] as num?)?.toInt() ?? 1;
    final termC = (map['term_count'] as num?)?.toInt() ?? (map['termCount'] as num?)?.toInt() ?? termM;

    return Loan(
      id: map['id']?.toString() ?? '',
      borrowerId: map['borrower_id']?.toString() ?? map['borrowerId']?.toString() ?? '',
      principal: (map['principal'] as num?)?.toDouble() ?? 0.0,
      interestRate: (map['interest_rate'] as num?)?.toDouble() ?? (map['interestRate'] as num?)?.toDouble() ?? 0.0,
      termMonths: termM,
      repaymentFrequency: map['repayment_frequency']?.toString() ?? map['repaymentFrequency']?.toString() ?? 'monthly',
      interestMethod: map['interest_method']?.toString() ?? map['interestMethod']?.toString() ?? 'reducing',
      termCount: termC,
      purpose: map['purpose']?.toString() ?? '',
      status: map['status']?.toString() ?? 'pending',
      disbursementDate: map['disbursement_date']?.toString() ?? map['disbursementDate']?.toString() ?? '',
      upfrontDeductionType: map['upfront_deduction_type']?.toString() ?? map['upfrontDeductionType']?.toString() ?? 'none',
      upfrontDeductionValue: (map['upfront_deduction_value'] as num?)?.toDouble() ?? (map['upfrontDeductionValue'] as num?)?.toDouble() ?? 0.0,
      processingFeeType: map['processing_fee_type']?.toString() ?? map['processingFeeType']?.toString() ?? 'none',
      processingFeeValue: (map['processing_fee_value'] as num?)?.toDouble() ?? (map['processingFeeValue'] as num?)?.toDouble() ?? 0.0,
      serviceFeeType: map['service_fee_type']?.toString() ?? map['serviceFeeType']?.toString() ?? 'none',
      serviceFeeValue: (map['service_fee_value'] as num?)?.toDouble() ?? (map['serviceFeeValue'] as num?)?.toDouble() ?? 0.0,
      disbursementFeeType: map['disbursement_fee_type']?.toString() ?? map['disbursementFeeType']?.toString() ?? 'none',
      disbursementFeeValue: (map['disbursement_fee_value'] as num?)?.toDouble() ?? (map['disbursementFeeValue'] as num?)?.toDouble() ?? 0.0,
      notarialFeeType: map['notarial_fee_type']?.toString() ?? map['notarialFeeType']?.toString() ?? 'none',
      notarialFeeValue: (map['notarial_fee_value'] as num?)?.toDouble() ?? (map['notarialFeeValue'] as num?)?.toDouble() ?? 0.0,
      creditLifeInsuranceFeeType: map['credit_life_insurance_fee_type']?.toString() ?? map['creditLifeInsuranceFeeType']?.toString() ?? 'none',
      creditLifeInsuranceFeeValue: (map['credit_life_insurance_fee_value'] as num?)?.toDouble() ?? (map['creditLifeInsuranceFeeValue'] as num?)?.toDouble() ?? 0.0,
      penaltyType: map['penalty_type']?.toString() ?? map['penaltyType']?.toString() ?? 'none',
      penaltyValue: (map['penalty_value'] as num?)?.toDouble() ?? (map['penaltyValue'] as num?)?.toDouble() ?? 0.0,
      accruedPenalty: (map['accrued_penalty'] as num?)?.toDouble() ?? (map['accruedPenalty'] as num?)?.toDouble() ?? 0.0,
      creditAssessment: map['credit_assessment'] != null
          ? CreditAssessment.fromMap(Map<String, dynamic>.from(map['credit_assessment']))
          : null,
      schedule: map['schedule'] != null
          ? (map['schedule'] as List).map((e) => ScheduleInstallment.fromMap(Map<String, dynamic>.from(e))).toList()
          : [],
      payments: map['payments'] != null
          ? (map['payments'] as List).map((e) => Payment.fromMap(Map<String, dynamic>.from(e))).toList()
          : [],
      creditApplications: map['credit_applications'] != null
          ? (map['credit_applications'] as List).map((e) => CreditApplication.fromMap(Map<String, dynamic>.from(e))).toList()
          : (map['creditApplications'] != null
              ? (map['creditApplications'] as List).map((e) => CreditApplication.fromMap(Map<String, dynamic>.from(e))).toList()
              : []),
      notes: map['notes']?.toString() ?? '',
      createdBy: map['created_by']?.toString() ?? map['createdBy']?.toString(),
      createdAt: map['createdAt']?.toString(),
      updatedAt: map['updatedAt']?.toString(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'borrower_id': borrowerId,
      'principal': principal,
      'interest_rate': interestRate,
      'term_months': termMonths,
      'repayment_frequency': repaymentFrequency,
      'interest_method': interestMethod,
      'term_count': termCount,
      'purpose': purpose,
      'status': status,
      'disbursement_date': disbursementDate,
      'upfront_deduction_type': upfrontDeductionType,
      'upfront_deduction_value': upfrontDeductionValue,
      'processing_fee_type': processingFeeType,
      'processing_fee_value': processingFeeValue,
      'service_fee_type': serviceFeeType,
      'service_fee_value': serviceFeeValue,
      'disbursement_fee_type': disbursementFeeType,
      'disbursement_fee_value': disbursementFeeValue,
      'notarial_fee_type': notarialFeeType,
      'notarial_fee_value': notarialFeeValue,
      'credit_life_insurance_fee_type': creditLifeInsuranceFeeType,
      'credit_life_insurance_fee_value': creditLifeInsuranceFeeValue,
      'penalty_type': penaltyType,
      'penalty_value': penaltyValue,
      'accrued_penalty': accruedPenalty,
      if (creditAssessment != null) 'credit_assessment': creditAssessment!.toMap(),
      'schedule': schedule.map((e) => e.toMap()).toList(),
      'payments': payments.map((e) => e.toMap()).toList(),
      'credit_applications': creditApplications.map((e) => e.toMap()).toList(),
      'notes': notes,
      if (createdBy != null) 'created_by': createdBy,
      if (createdAt != null) 'createdAt': createdAt,
      if (updatedAt != null) 'updatedAt': updatedAt,
    };
  }

  Loan copyWith({
    String? id,
    String? borrowerId,
    double? principal,
    double? interestRate,
    int? termMonths,
    String? repaymentFrequency,
    String? interestMethod,
    int? termCount,
    String? purpose,
    String? status,
    String? disbursementDate,
    String? upfrontDeductionType,
    double? upfrontDeductionValue,
    String? processingFeeType,
    double? processingFeeValue,
    String? serviceFeeType,
    double? serviceFeeValue,
    String? disbursementFeeType,
    double? disbursementFeeValue,
    String? notarialFeeType,
    double? notarialFeeValue,
    String? creditLifeInsuranceFeeType,
    double? creditLifeInsuranceFeeValue,
    String? penaltyType,
    double? penaltyValue,
    double? accruedPenalty,
    CreditAssessment? creditAssessment,
    List<ScheduleInstallment>? schedule,
    List<Payment>? payments,
    List<CreditApplication>? creditApplications,
    String? notes,
    String? createdBy,
    String? createdAt,
    String? updatedAt,
  }) {
    return Loan(
      id: id ?? this.id,
      borrowerId: borrowerId ?? this.borrowerId,
      principal: principal ?? this.principal,
      interestRate: interestRate ?? this.interestRate,
      termMonths: termMonths ?? this.termMonths,
      repaymentFrequency: repaymentFrequency ?? this.repaymentFrequency,
      interestMethod: interestMethod ?? this.interestMethod,
      termCount: termCount ?? this.termCount,
      purpose: purpose ?? this.purpose,
      status: status ?? this.status,
      disbursementDate: disbursementDate ?? this.disbursementDate,
      upfrontDeductionType: upfrontDeductionType ?? this.upfrontDeductionType,
      upfrontDeductionValue: upfrontDeductionValue ?? this.upfrontDeductionValue,
      processingFeeType: processingFeeType ?? this.processingFeeType,
      processingFeeValue: processingFeeValue ?? this.processingFeeValue,
      serviceFeeType: serviceFeeType ?? this.serviceFeeType,
      serviceFeeValue: serviceFeeValue ?? this.serviceFeeValue,
      disbursementFeeType: disbursementFeeType ?? this.disbursementFeeType,
      disbursementFeeValue: disbursementFeeValue ?? this.disbursementFeeValue,
      notarialFeeType: notarialFeeType ?? this.notarialFeeType,
      notarialFeeValue: notarialFeeValue ?? this.notarialFeeValue,
      creditLifeInsuranceFeeType: creditLifeInsuranceFeeType ?? this.creditLifeInsuranceFeeType,
      creditLifeInsuranceFeeValue: creditLifeInsuranceFeeValue ?? this.creditLifeInsuranceFeeValue,
      penaltyType: penaltyType ?? this.penaltyType,
      penaltyValue: penaltyValue ?? this.penaltyValue,
      accruedPenalty: accruedPenalty ?? this.accruedPenalty,
      creditAssessment: creditAssessment ?? this.creditAssessment,
      schedule: schedule ?? this.schedule,
      payments: payments ?? this.payments,
      creditApplications: creditApplications ?? this.creditApplications,
      notes: notes ?? this.notes,
      createdBy: createdBy ?? this.createdBy,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
