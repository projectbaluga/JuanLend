import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import '../models/borrower.dart';
import '../models/loan.dart';
import '../models/payment.dart';
import '../store/app_state.dart';
import '../utils/loan_utils.dart';
import '../utils/receipt_utils.dart';
import '../widgets/app_badge.dart';
import '../widgets/app_progress_bar.dart';
import '../widgets/custom_card.dart';
import '../widgets/responsive_container.dart';

class LoanDetailScreen extends StatelessWidget {
  final String loanId;
  final VoidCallback onBack;
  final Function(String) onSelectBorrower;

  const LoanDetailScreen({
    super.key,
    required this.loanId,
    required this.onBack,
    required this.onSelectBorrower,
  });

  Future<bool> _showConfirmDialog({
    required BuildContext context,
    required String title,
    required String message,
    String confirmText = 'Confirm',
    Color? confirmColor,
  }) async {
    final res = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: confirmColor != null
                ? ElevatedButton.styleFrom(backgroundColor: confirmColor)
                : null,
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(confirmText, style: confirmColor != null ? const TextStyle(color: Colors.white) : null),
          ),
        ],
      ),
    );
    return res ?? false;
  }

  void _showTextDialog({
    required BuildContext context,
    required String title,
    required String textContent,
  }) {
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: Text(title),
          content: SizedBox(
            width: double.maxFinite,
            height: 320,
            child: SingleChildScrollView(
              child: SelectableText(
                textContent,
                style: const TextStyle(fontFamily: 'monospace', fontSize: 11),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Clipboard.setData(ClipboardData(text: textContent));
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Copied to clipboard!')),
                );
              },
              child: const Text('Copy Text'),
            ),
            ElevatedButton.icon(
              onPressed: () {
                // ignore: deprecated_member_use
                Share.share(textContent, subject: title);
              },
              icon: const Icon(Icons.share, size: 14),
              label: const Text('Share'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }

  void _showEditLoanDialog(BuildContext context, Loan loan, AppState state) {
    final purposeCtrl = TextEditingController(text: loan.purpose);
    final notesCtrl = TextEditingController(text: loan.notes);
    final dateCtrl = TextEditingController(text: loan.disbursementDate);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(
            top: 16,
            left: 16,
            right: 16,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 16,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Edit Loan Details', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              TextField(
                controller: purposeCtrl,
                decoration: const InputDecoration(labelText: 'Purpose', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: dateCtrl,
                decoration: const InputDecoration(labelText: 'Disbursement Date (YYYY-MM-DD)', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: notesCtrl,
                decoration: const InputDecoration(labelText: 'Notes', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: () async {
                      final updates = {
                        'purpose': purposeCtrl.text.trim().isEmpty ? loan.purpose : purposeCtrl.text.trim(),
                        'disbursement_date': dateCtrl.text.trim().isEmpty ? loan.disbursementDate : dateCtrl.text.trim(),
                        'notes': notesCtrl.text.trim(),
                        'updatedAt': DateTime.now().toIso8601String(),
                      };

                      try {
                        await state.updateLoan(loan.id, updates);
                        if (!ctx.mounted) return;
                        Navigator.pop(ctx);

                        if (!context.mounted) return;
                        HapticFeedback.lightImpact();
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Loan updated successfully')),
                        );
                      } catch (e) {
                        if (!context.mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Failed to update loan: $e')),
                        );
                      }
                    },
                    child: const Text('Save Changes'),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  void _showRecordPaymentDialog(
    BuildContext context,
    Loan loan,
    Borrower borrower,
    AppState state,
  ) {
    final amountCtrl = TextEditingController();
    final noteCtrl = TextEditingController();
    final dateCtrl = TextEditingController(text: DateTime.now().toIso8601String().split('T')[0]);
    String selectedMethod = 'Cash';

    final stats = LoanUtils.getLoanStats(loan);
    final maxAmount = stats.totalDueWithPenalty;

    bool isSaving = false;
    String? errorMessage;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                top: 16,
                left: 16,
                right: 16,
                bottom: MediaQuery.of(ctx).viewInsets.bottom + 16,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Record Repayment', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  TextField(
                    controller: amountCtrl,
                    enabled: !isSaving,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(
                      labelText: 'Amount *',
                      helperText: 'Max amount due: ${LoanUtils.formatCurrency(maxAmount, state.currencyCode)}',
                      errorText: errorMessage,
                      border: const OutlineInputBorder(),
                    ),
                    onChanged: (_) {
                      if (errorMessage != null) {
                        setModalState(() {
                          errorMessage = null;
                        });
                      }
                    },
                  ),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<String>(
                    initialValue: selectedMethod,
                    decoration: const InputDecoration(labelText: 'Method', border: OutlineInputBorder()),
                    items: const [
                      DropdownMenuItem(value: 'Cash', child: Text('Cash')),
                      DropdownMenuItem(value: 'GCash / E-Wallet', child: Text('GCash / E-Wallet')),
                      DropdownMenuItem(value: 'Bank Transfer', child: Text('Bank Transfer')),
                      DropdownMenuItem(value: 'Check', child: Text('Check')),
                    ],
                    onChanged: isSaving ? null : (val) => selectedMethod = val ?? 'Cash',
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: dateCtrl,
                    enabled: !isSaving,
                    decoration: const InputDecoration(labelText: 'Payment Date (YYYY-MM-DD)', border: OutlineInputBorder()),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: noteCtrl,
                    enabled: !isSaving,
                    decoration: const InputDecoration(labelText: 'Note', border: OutlineInputBorder()),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: isSaving ? null : () => Navigator.pop(ctx),
                        child: const Text('Cancel'),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        onPressed: isSaving
                            ? null
                            : () async {
                                final amt = double.tryParse(amountCtrl.text.trim()) ?? 0.0;
                                if (amt <= 0) {
                                  setModalState(() {
                                    errorMessage = 'Please enter a valid amount greater than 0';
                                  });
                                  return;
                                }

                                if (amt > maxAmount + 0.001) {
                                  setModalState(() {
                                    errorMessage = 'Amount cannot exceed balance due (${LoanUtils.formatCurrency(maxAmount, state.currencyCode)})';
                                  });
                                  return;
                                }

                                setModalState(() {
                                  isSaving = true;
                                  errorMessage = null;
                                });

                                final randSuffix = Random().nextInt(900000) + 100000;
                                final payment = Payment(
                                  id: 'pay_${DateTime.now().microsecondsSinceEpoch}_$randSuffix',
                                  date: dateCtrl.text.trim(),
                                  amount: amt,
                                  method: selectedMethod,
                                  note: noteCtrl.text.trim(),
                                );

                                await state.recordPayment(loan.id, payment);
                                if (!ctx.mounted) return;
                                Navigator.pop(ctx);

                                final updatedLoan = state.loans.firstWhere((l) => l.id == loan.id, orElse: () => loan);
                                final updatedStats = LoanUtils.getLoanStats(updatedLoan);
                                final allocations = LoanUtils.allocatePayments(
                                  updatedLoan.schedule,
                                  updatedLoan.payments,
                                  penaltyAmount: updatedStats.penaltyAmount,
                                );
                                final curAlloc = allocations[payment.id];

                                final receiptText = ReceiptUtils.generatePaymentReceipt(
                                  businessName: state.businessName,
                                  borrower: borrower,
                                  loan: updatedLoan,
                                  payment: payment,
                                  runningOutstandingBalance: updatedStats.outstandingBalance,
                                  currencyCode: state.currencyCode,
                                  allocation: curAlloc,
                                );

                                if (!context.mounted) return;
                                _showTextDialog(
                                  context: context,
                                  title: 'Official Payment Receipt',
                                  textContent: receiptText,
                                );
                              },
                        child: isSaving
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Text('Save & View Receipt'),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = Provider.of<AppState>(context);
    final loans = state.loans;
    final borrowers = state.borrowers;

    final loan = loans.firstWhere((l) => l.id == loanId, orElse: () => loans.first);
    final borrower = borrowers.firstWhere((b) => b.id == loan.borrowerId, orElse: () => borrowers.first);
    final stats = LoanUtils.getLoanStats(loan);

    final isApprover = state.currentUser != null && (state.isSoloMode || state.currentUser!.role == 'approver');
    final isOfficerOrApprover = state.currentUser != null &&
        (state.isSoloMode || state.currentUser!.role == 'officer' || state.currentUser!.role == 'approver');
    final canApproveThisLoan = isApprover && (state.isSoloMode || loan.createdBy != state.currentUser?.id);

    final totalFees = LoanUtils.calculateTotalFeesForLoan(loan);
    final netDisbursed = LoanUtils.calculateNetDisbursedForLoan(loan);


    return Scaffold(
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: ResponsiveContainer(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
            // Status Transitions & Action Bar
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    OutlinedButton.icon(
                      onPressed: () {
                        final soaText = ReceiptUtils.generateStatementOfAccount(
                          businessName: state.businessName,
                          borrower: borrower,
                          loan: loan,
                          stats: stats,
                          currencyCode: state.currencyCode,
                        );
                        _showTextDialog(
                          context: context,
                          title: 'Statement of Account (SOA)',
                          textContent: soaText,
                        );
                      },
                      icon: const Icon(Icons.receipt_long, size: 16),
                      label: const Text('Statement of Account'),
                    ),
                    OutlinedButton.icon(
                      onPressed: () => _showEditLoanDialog(context, loan, state),
                      icon: const Icon(Icons.edit, size: 16),
                      label: const Text('Edit Loan'),
                    ),
                    if (isApprover)
                      OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(foregroundColor: Colors.redAccent),
                        onPressed: () async {
                          final confirm = await _showConfirmDialog(
                            context: context,
                            title: 'Delete Loan?',
                            message: 'Are you sure you want to delete this loan? This action cannot be undone.',
                            confirmText: 'Delete Loan',
                            confirmColor: Colors.redAccent,
                          );
                          if (confirm) {
                            try {
                              await state.deleteLoan(loan.id);
                              if (!context.mounted) return;
                              HapticFeedback.lightImpact();
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Loan deleted successfully')),
                              );
                              onBack();
                            } catch (e) {
                              if (!context.mounted) return;
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Delete failed: $e')),
                              );
                            }
                          }
                        },
                        icon: const Icon(Icons.delete_forever, size: 16),
                        label: const Text('Delete Loan'),
                      ),
                  ],
                ),
                Row(
                  children: [
                    if (loan.status == 'pending') ...[
                      if (canApproveThisLoan)
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF059669)),
                          onPressed: () async {
                            try {
                              if (loan.creditAssessment?.riskRating == 'high') {
                                final confirm = await _showConfirmDialog(
                                  context: context,
                                  title: 'High Risk Loan Warning',
                                  message: 'Borrower "${borrower.fullName}" is rated HIGH RISK (DTI ${loan.creditAssessment?.dtiPct ?? 0}%).\n\nAre you sure you want to approve this loan with explicit override?',
                                  confirmText: 'Approve Override',
                                  confirmColor: Colors.orangeAccent,
                                );
                                if (confirm) {
                                  await state.approveLoan(loan.id, overrideHighRisk: true);
                                  if (!context.mounted) return;
                                  HapticFeedback.lightImpact();
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('Loan approved')),
                                  );
                                }
                              } else {
                                final confirm = await _showConfirmDialog(
                                  context: context,
                                  title: 'Approve Loan',
                                  message: 'Approve this loan?',
                                  confirmText: 'Approve',
                                  confirmColor: const Color(0xFF059669),
                                );
                                if (confirm) {
                                  await state.approveLoan(loan.id);
                                  if (!context.mounted) return;
                                  HapticFeedback.lightImpact();
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('Loan approved')),
                                  );
                                }
                              }
                            } catch (e) {
                              if (!context.mounted) return;
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Action failed: ${e.toString().replaceAll('StateError: ', '').replaceAll('ArgumentError: ', '')}')),
                              );
                            }
                          },
                          icon: const Icon(Icons.check, size: 16, color: Colors.white),
                          label: const Text('Approve', style: TextStyle(color: Colors.white)),
                        ),
                      if (isApprover) ...[
                        const SizedBox(width: 8),
                        OutlinedButton.icon(
                          onPressed: () async {
                            try {
                              final confirm = await _showConfirmDialog(
                                context: context,
                                title: 'Reject Loan',
                                message: 'Reject this loan? This cannot be undone.',
                                confirmText: 'Reject',
                                confirmColor: Colors.redAccent,
                              );
                              if (confirm) {
                                await state.markLoanStatus(loan.id, 'rejected');
                                if (!context.mounted) return;
                                HapticFeedback.lightImpact();
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Loan marked rejected')),
                                );
                              }
                            } catch (e) {
                              if (!context.mounted) return;
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Action failed: ${e.toString().replaceAll('StateError: ', '').replaceAll('ArgumentError: ', '')}')),
                              );
                            }
                          },
                          icon: const Icon(Icons.close, size: 16),
                          label: const Text('Reject'),
                        ),
                      ],
                      if (!canApproveThisLoan && !state.isSoloMode)
                        Text(
                          loan.createdBy == state.currentUser?.id
                              ? ' (Creator cannot approve own loan)'
                              : ' (Requires Approver Role)',
                          style: const TextStyle(fontSize: 11, color: Colors.orangeAccent),
                        ),
                    ],
                    if (loan.status == 'active') ...[
                      if (isOfficerOrApprover)
                        ElevatedButton.icon(
                          onPressed: () => _showRecordPaymentDialog(context, loan, borrower, state),
                          icon: const Icon(Icons.add, size: 16),
                          label: const Text('Record Payment'),
                        ),
                      if (isApprover) ...[
                        const SizedBox(width: 8),
                        OutlinedButton(
                          onPressed: () async {
                            try {
                              final confirm = await _showConfirmDialog(
                                context: context,
                                title: 'Complete Loan',
                                message: 'Mark loan as completed?',
                                confirmText: 'Complete',
                              );
                              if (confirm) {
                                await state.markLoanStatus(loan.id, 'completed');
                                if (!context.mounted) return;
                                HapticFeedback.lightImpact();
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Loan marked completed')),
                                );
                              }
                            } catch (e) {
                              if (!context.mounted) return;
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Action failed: ${e.toString().replaceAll('StateError: ', '').replaceAll('ArgumentError: ', '')}')),
                              );
                            }
                          },
                          child: const Text('Complete'),
                        ),
                        const SizedBox(width: 8),
                        OutlinedButton(
                          style: OutlinedButton.styleFrom(foregroundColor: Colors.redAccent),
                          onPressed: () async {
                            try {
                              final confirm = await _showConfirmDialog(
                                context: context,
                                title: 'Default Loan',
                                message: 'Mark loan as defaulted? This penalizes the borrower\'s credit score and forces their risk rating to HIGH.',
                                confirmText: 'Mark Defaulted',
                                confirmColor: Colors.redAccent,
                              );
                              if (confirm) {
                                await state.markLoanStatus(loan.id, 'defaulted');
                                if (!context.mounted) return;
                                HapticFeedback.lightImpact();
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Loan marked defaulted')),
                                );
                              }
                            } catch (e) {
                              if (!context.mounted) return;
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Action failed: ${e.toString().replaceAll('StateError: ', '').replaceAll('ArgumentError: ', '')}')),
                              );
                            }
                          },
                          child: const Text('Default'),
                        ),
                      ],
                    ],
                  ],
                ),
              ],
            ),

            const SizedBox(height: 12),

            // Overview Card
            CustomCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(loan.purpose, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      Row(
                        children: [
                          AppBadge(text: loan.repaymentFrequency, variant: 'low'),
                          const SizedBox(width: 4),
                          AppBadge(text: loan.status, variant: loan.status),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Principal: ${LoanUtils.formatCurrency(loan.principal, state.currencyCode)} @ ${loan.interestRate}% • ${loan.termCount} ${loan.repaymentFrequency} period(s) (${loan.interestMethod.replaceAll('_', ' ')})',
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                  if (totalFees > 0) ...[
                    const SizedBox(height: 6),
                    Text('Itemized Fees: -${LoanUtils.formatCurrency(totalFees, state.currencyCode)}',
                        style: const TextStyle(fontSize: 11, color: Colors.redAccent)),
                    Text('Borrower Receives (Net Disbursed): ${LoanUtils.formatCurrency(netDisbursed, state.currencyCode)}',
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF059669))),
                  ],
                  const SizedBox(height: 12),
                  AppProgressBar(percentage: stats.progressPct),
                  const SizedBox(height: 12),
                  const Divider(),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 16,
                    runSpacing: 10,
                    alignment: WrapAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Total Scheduled', style: TextStyle(fontSize: 10, color: Colors.grey)),
                          Text(LoanUtils.formatCurrency(stats.totalScheduled, state.currencyCode), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                        ],
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Total Paid', style: TextStyle(fontSize: 10, color: Colors.grey)),
                          Text(LoanUtils.formatCurrency(stats.totalPaid, state.currencyCode),
                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF10B981))),
                        ],
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Outstanding', style: TextStyle(fontSize: 10, color: Colors.grey)),
                          Text(LoanUtils.formatCurrency(stats.outstandingBalance, state.currencyCode), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                        ],
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Overdue', style: TextStyle(fontSize: 10, color: Colors.grey)),
                          Text(LoanUtils.formatCurrency(stats.overdueAmount, state.currencyCode),
                              style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: stats.overdueAmount > 0 ? Colors.redAccent : Colors.white)),
                        ],
                      ),
                      if (stats.penaltyAmount > 0)
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Penalty', style: TextStyle(fontSize: 10, color: Colors.redAccent)),
                            Text(LoanUtils.formatCurrency(stats.penaltyAmount, state.currencyCode),
                                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.redAccent)),
                          ],
                        ),
                    ],
                  ),
                  if (stats.penaltyAmount > 0) ...[
                    const SizedBox(height: 6),
                    Text('Total Due with Penalty: ${LoanUtils.formatCurrency(stats.totalDueWithPenalty, state.currencyCode)}',
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.redAccent)),
                  ],
                  if (stats.creditBalance > 0) ...[
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFF059669).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFF059669).withValues(alpha: 0.4)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.account_balance_wallet, color: Color(0xFF059669), size: 20),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Credit Balance / Overpayment: ${LoanUtils.formatCurrency(stats.creditBalance, state.currencyCode)}',
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF059669)),
                                ),
                                const Text(
                                  'Borrower has overpaid past the total loan obligation. Refund or credit available.',
                                  style: TextStyle(fontSize: 10, color: Colors.grey),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Borrower Summary Card
            CustomCard(
              onTap: () => onSelectBorrower(borrower.id),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(borrower.fullName, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                      Text(borrower.email.isNotEmpty ? borrower.email : borrower.phone,
                          style: const TextStyle(fontSize: 11, color: Colors.grey)),
                    ],
                  ),
                  AppBadge(text: borrower.riskRating, variant: borrower.riskRating),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Amortization Schedule Table Card
            CustomCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Amortization Schedule', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final availableWidth = constraints.maxWidth;
                      final isWide = availableWidth >= 600;

                      if (isWide) {
                        final dynamicFontSize = availableWidth > 1000 ? 13.0 : (availableWidth > 800 ? 12.0 : 11.0);
                        final dynamicSpacing = (availableWidth - 500) / 10;
                        final colSpacing = dynamicSpacing.clamp(12.0, 28.0);

                        return SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: ConstrainedBox(
                            constraints: BoxConstraints(minWidth: availableWidth),
                            child: DataTable(
                              columnSpacing: colSpacing,
                              headingRowHeight: 36,
                              dataRowMinHeight: 38,
                              dataRowMaxHeight: 38,
                              columns: [
                                DataColumn(label: Text('#', style: TextStyle(fontSize: dynamicFontSize, fontWeight: FontWeight.bold))),
                                DataColumn(label: Text('Due Date', style: TextStyle(fontSize: dynamicFontSize, fontWeight: FontWeight.bold))),
                                DataColumn(label: Text('Amount', style: TextStyle(fontSize: dynamicFontSize, fontWeight: FontWeight.bold))),
                                DataColumn(label: Text('Principal', style: TextStyle(fontSize: dynamicFontSize, fontWeight: FontWeight.bold))),
                                DataColumn(label: Text('Interest', style: TextStyle(fontSize: dynamicFontSize, fontWeight: FontWeight.bold))),
                                DataColumn(label: Text('Paid', style: TextStyle(fontSize: dynamicFontSize, fontWeight: FontWeight.bold))),
                                DataColumn(label: Text('Remaining', style: TextStyle(fontSize: dynamicFontSize, fontWeight: FontWeight.bold))),
                                DataColumn(label: Text('Balance', style: TextStyle(fontSize: dynamicFontSize, fontWeight: FontWeight.bold))),
                                DataColumn(label: Text('Status', style: TextStyle(fontSize: dynamicFontSize, fontWeight: FontWeight.bold))),
                              ],
                              rows: stats.scheduleWithStatus.map((inst) {
                                return DataRow(
                                  cells: [
                                    DataCell(Text('${inst.installmentNo}', style: TextStyle(fontSize: dynamicFontSize))),
                                    DataCell(Text(LoanUtils.formatDate(inst.dueDate), style: TextStyle(fontSize: dynamicFontSize))),
                                    DataCell(Text(LoanUtils.formatCurrency(inst.amount, state.currencyCode), style: TextStyle(fontSize: dynamicFontSize, fontWeight: FontWeight.bold))),
                                    DataCell(Text(LoanUtils.formatCurrency(inst.principal, state.currencyCode), style: TextStyle(fontSize: dynamicFontSize, color: Colors.grey))),
                                    DataCell(Text(LoanUtils.formatCurrency(inst.interest, state.currencyCode), style: TextStyle(fontSize: dynamicFontSize, color: Colors.grey))),
                                    DataCell(Text(LoanUtils.formatCurrency(inst.paidAmount, state.currencyCode), style: TextStyle(fontSize: dynamicFontSize, fontWeight: FontWeight.bold, color: const Color(0xFF10B981)))),
                                    DataCell(Text(LoanUtils.formatCurrency(inst.remainingAmount, state.currencyCode), style: TextStyle(fontSize: dynamicFontSize, fontWeight: FontWeight.bold, color: inst.remainingAmount > 0 ? Colors.redAccent : Colors.grey))),
                                    DataCell(Text(LoanUtils.formatCurrency(inst.balance, state.currencyCode), style: TextStyle(fontSize: dynamicFontSize, color: Colors.grey))),
                                    DataCell(AppBadge(text: inst.status, variant: inst.status)),
                                  ],
                                );
                              }).toList(),
                            ),
                          ),
                        );
                      }

                      return ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: stats.scheduleWithStatus.length,
                        separatorBuilder: (_, __) => const Divider(height: 12),
                        itemBuilder: (context, idx) {
                          final inst = stats.scheduleWithStatus[idx];
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 2.0),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      '#${inst.installmentNo} • Due ${LoanUtils.formatDate(inst.dueDate)}',
                                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      'P: ${LoanUtils.formatCurrency(inst.principal, state.currencyCode)} | I: ${LoanUtils.formatCurrency(inst.interest, state.currencyCode)}',
                                      style: const TextStyle(fontSize: 10, color: Colors.grey),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      'Paid: ${LoanUtils.formatCurrency(inst.paidAmount, state.currencyCode)} | Rem: ${LoanUtils.formatCurrency(inst.remainingAmount, state.currencyCode)} | Bal: ${LoanUtils.formatCurrency(inst.balance, state.currencyCode)}',
                                      style: const TextStyle(fontSize: 10, color: Colors.grey),
                                    ),
                                    const SizedBox(height: 4),
                                    SizedBox(
                                      width: 120,
                                      child: AppProgressBar(
                                        percentage: inst.amount > 0 ? ((inst.paidAmount / inst.amount) * 100).round() : 0,
                                        showLabel: false,
                                      ),
                                    ),
                                  ],
                                ),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text(
                                      LoanUtils.formatCurrency(inst.amount, state.currencyCode),
                                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                                    ),
                                    const SizedBox(height: 2),
                                    AppBadge(text: inst.status, variant: inst.status),
                                  ],
                                ),
                              ],
                            ),
                          );
                        },
                      );
                    },
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Payments Log Card
            CustomCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Payment Log (${loan.payments.length})', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  if (loan.payments.isEmpty)
                    const Text('No payments recorded yet.', style: TextStyle(fontSize: 11, color: Colors.grey))
                  else
                    Builder(
                      builder: (context) {
                        final allocations = LoanUtils.allocatePayments(
                          loan.schedule,
                          loan.payments,
                          penaltyAmount: stats.penaltyAmount,
                        );

                        return ListView.separated(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: loan.payments.length,
                          separatorBuilder: (_, __) => const Divider(height: 12),
                          itemBuilder: (context, idx) {
                            final p = loan.payments[idx];
                            final alloc = allocations[p.id];

                            final recBy = p.recordedBy.isNotEmpty
                                ? (p.recordedByRole.isNotEmpty ? '${p.recordedBy} (${p.recordedByRole})' : p.recordedBy)
                                : '';

                            final coveredText = alloc != null && alloc.coveredInstallmentNos.isNotEmpty
                                ? 'Applied to installments: ${alloc.coveredInstallmentsRange}'
                                : '';

                            final principalVal = alloc?.principalPortion ?? p.principalPortion;
                            final interestVal = alloc?.interestPortion ?? p.interestPortion;
                            final penaltyVal = alloc?.penaltyPortion ?? p.penaltyPortion;
                            final excessVal = alloc?.excessAmount ?? p.excessAmount;

                            return Theme(
                              data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                              child: ExpansionTile(
                                tilePadding: EdgeInsets.zero,
                                childrenPadding: const EdgeInsets.only(bottom: 8.0, top: 4.0),
                                title: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(LoanUtils.formatCurrency(p.amount, state.currencyCode),
                                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF10B981))),
                                        Text('via ${p.method}${p.note.isNotEmpty ? ' • ${p.note}' : ''}',
                                            style: const TextStyle(fontSize: 10, color: Colors.grey)),
                                        if (coveredText.isNotEmpty) ...[
                                          const SizedBox(height: 2),
                                          Text(coveredText, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w500, color: Color(0xFF0284C7))),
                                        ],
                                      ],
                                    ),
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.end,
                                      children: [
                                        Text(LoanUtils.formatDate(p.date), style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                                        if (recBy.isNotEmpty)
                                          Text('By $recBy', style: const TextStyle(fontSize: 9, color: Colors.grey)),
                                      ],
                                    ),
                                  ],
                                ),
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(8.0),
                                    decoration: BoxDecoration(
                                      color: Theme.of(context).brightness == Brightness.dark
                                          ? const Color(0xFF27272A)
                                          : Colors.grey.shade100,
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            Text('Principal Portion:', style: const TextStyle(fontSize: 11, color: Colors.grey)),
                                            Text(LoanUtils.formatCurrency(principalVal, state.currencyCode),
                                                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                                          ],
                                        ),
                                        const SizedBox(height: 2),
                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            Text('Interest Portion:', style: const TextStyle(fontSize: 11, color: Colors.grey)),
                                            Text(LoanUtils.formatCurrency(interestVal, state.currencyCode),
                                                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                                          ],
                                        ),
                                        if (penaltyVal > 0) ...[
                                          const SizedBox(height: 2),
                                          Row(
                                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                            children: [
                                              Text('Penalty Paid:', style: const TextStyle(fontSize: 11, color: Colors.redAccent)),
                                              Text(LoanUtils.formatCurrency(penaltyVal, state.currencyCode),
                                                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.redAccent)),
                                            ],
                                          ),
                                        ],
                                        if (excessVal > 0) ...[
                                          const SizedBox(height: 2),
                                          Row(
                                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                            children: [
                                              Text('Excess / Overpayment:', style: const TextStyle(fontSize: 11, color: Color(0xFF059669))),
                                              Text(LoanUtils.formatCurrency(excessVal, state.currencyCode),
                                                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF059669))),
                                            ],
                                          ),
                                        ],
                                        if (p.recordedAt.isNotEmpty) ...[
                                          const Divider(height: 10),
                                          Text('Recorded At: ${p.recordedAt}', style: const TextStyle(fontSize: 10, color: Colors.grey)),
                                        ],
                                        if (isOfficerOrApprover) ...[
                                          const SizedBox(height: 8),
                                          Align(
                                            alignment: Alignment.centerRight,
                                            child: TextButton.icon(
                                              style: TextButton.styleFrom(
                                                foregroundColor: Colors.redAccent,
                                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                              ),
                                              onPressed: () async {
                                                final confirm = await _showConfirmDialog(
                                                  context: context,
                                                  title: 'Void Payment?',
                                                  message: 'Are you sure you want to void this payment of ${LoanUtils.formatCurrency(p.amount, state.currencyCode)}? The loan schedule balance will be recalculated.',
                                                  confirmText: 'Void Payment',
                                                  confirmColor: Colors.redAccent,
                                                );
                                                if (confirm) {
                                                  try {
                                                    await state.voidPayment(loan.id, p.id);
                                                    if (!context.mounted) return;
                                                    HapticFeedback.lightImpact();
                                                    ScaffoldMessenger.of(context).showSnackBar(
                                                      const SnackBar(content: Text('Payment voided successfully')),
                                                    );
                                                  } catch (e) {
                                                    if (!context.mounted) return;
                                                    ScaffoldMessenger.of(context).showSnackBar(
                                                      SnackBar(content: Text('Failed to void payment: $e')),
                                                    );
                                                  }
                                                }
                                              },
                                              icon: const Icon(Icons.remove_circle_outline, size: 14),
                                              label: const Text('Void / Reverse Payment', style: TextStyle(fontSize: 11)),
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        );
                      },
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
      ),
    );
  }
}
