import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../models/loan.dart';
import '../models/schedule_installment.dart';
import '../store/app_state.dart';
import '../utils/loan_utils.dart';
import '../widgets/app_badge.dart';
import '../widgets/custom_card.dart';
import '../widgets/responsive_container.dart';
import '../widgets/screen_header.dart';
import '../widgets/search_filter_bar.dart';

class LoansScreen extends StatefulWidget {
  final Function(String) onSelectLoan;
  final String? initialBorrowerId;

  const LoansScreen({
    super.key,
    required this.onSelectLoan,
    this.initialBorrowerId,
  });

  @override
  State<LoansScreen> createState() => _LoansScreenState();
}

class _LoansScreenState extends State<LoansScreen> {
  String _searchTerm = '';
  String _statusFilter = 'all';

  @override
  void initState() {
    super.initState();
    if (widget.initialBorrowerId != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _showNewLoanDialog(context, initialBorrowerId: widget.initialBorrowerId);
      });
    }
  }

  void _showNewLoanDialog(BuildContext context, {String? initialBorrowerId}) {
    final state = Provider.of<AppState>(context, listen: false);
    final borrowers = state.borrowers;
    if (borrowers.isEmpty) return;

    String selectedBorrowerId = initialBorrowerId ?? borrowers.first.id;
    String selectedFrequency = state.defaultRepaymentFrequency;
    String selectedMethod = (state.defaultInterestMethod == 'flat' || state.defaultInterestMethod == 'one_time')
        ? state.defaultInterestMethod
        : 'flat';
    String selectedPenaltyType = state.defaultPenaltyType;
    bool deductInterestUpfront = false;

    final principalCtrl = TextEditingController();
    final rateCtrl = TextEditingController(text: state.defaultInterestRate.toString());
    final termCtrl = TextEditingController(text: state.defaultTermPeriods.toString());
    final purposeCtrl = TextEditingController();
    final dateCtrl = TextEditingController(text: DateTime.now().toIso8601String().split('T')[0]);
    final notesCtrl = TextEditingController();
    final penaltyValueCtrl = TextEditingController(text: state.defaultPenaltyValue.toString());

    String processingFeeType = 'none';
    final processingFeeCtrl = TextEditingController(text: '0');
    String serviceFeeType = 'none';
    final serviceFeeCtrl = TextEditingController(text: '0');
    String disbursementFeeType = 'none';
    final disbursementFeeCtrl = TextEditingController(text: '0');
    String notarialFeeType = 'none';
    final notarialFeeCtrl = TextEditingController(text: '0');
    String insuranceFeeType = 'none';
    final insuranceFeeCtrl = TextEditingController(text: '0');

    String? validationError;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      constraints: const BoxConstraints(maxWidth: 760),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final p = double.tryParse(principalCtrl.text.trim()) ?? 0.0;
            final r = double.tryParse(rateCtrl.text.trim()) ?? 0.0;
            final t = int.tryParse(termCtrl.text.trim()) ?? 1;

            final procVal = double.tryParse(processingFeeCtrl.text.trim()) ?? 0.0;
            final servVal = double.tryParse(serviceFeeCtrl.text.trim()) ?? 0.0;
            final disbVal = double.tryParse(disbursementFeeCtrl.text.trim()) ?? 0.0;
            final notaVal = double.tryParse(notarialFeeCtrl.text.trim()) ?? 0.0;
            final insVal = double.tryParse(insuranceFeeCtrl.text.trim()) ?? 0.0;

            final interestDeduction = deductInterestUpfront ? LoanUtils.round2(p * r / 100.0) : 0.0;

            final totalFees = LoanUtils.calculateTotalUpfrontFees(
              principal: p,
              upfrontDeductionType: deductInterestUpfront ? 'fixed' : 'none',
              upfrontDeductionValue: interestDeduction,
              processingFeeType: processingFeeType,
              processingFeeValue: procVal,
              serviceFeeType: serviceFeeType,
              serviceFeeValue: servVal,
              disbursementFeeType: disbursementFeeType,
              disbursementFeeValue: disbVal,
              notarialFeeType: notarialFeeType,
              notarialFeeValue: notaVal,
              creditLifeInsuranceFeeType: insuranceFeeType,
              creditLifeInsuranceFeeValue: insVal,
              termCount: t,
              frequency: selectedFrequency,
            );

            final netDisbursed = LoanUtils.round2(max(0.0, p - totalFees));

            final effectiveRate = deductInterestUpfront ? 0.0 : r;

            final schedPreview = (p > 0 && t > 0)
                ? LoanUtils.generateSchedule(
                    p,
                    effectiveRate,
                    t,
                    dateCtrl.text.trim(),
                    repaymentFrequency: selectedFrequency,
                    interestMethod: selectedMethod,
                  )
                : <ScheduleInstallment>[];


            String termLabel = 'Term (months)';
            switch (selectedFrequency) {
              case 'daily':
                termLabel = 'Term (days)';
                break;
              case 'weekly':
                termLabel = 'Term (weeks)';
                break;
              case 'biweekly':
                termLabel = 'Term (bi-weeks)';
                break;
              case 'monthly':
              default:
                termLabel = 'Term (months)';
                break;
            }

            final totalScheduled = schedPreview.fold(0.0, (sum, inst) => sum + inst.amount);
            final totalInterest = schedPreview.fold(0.0, (sum, inst) => sum + inst.interest);

            return Padding(
              padding: EdgeInsets.only(
                top: 16,
                left: 16,
                right: 16,
                bottom: MediaQuery.of(ctx).viewInsets.bottom + 16,
              ),
              child: Container(
                constraints: const BoxConstraints(maxHeight: 650),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Issue New Loan', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                        IconButton(
                          icon: const Icon(Icons.close, size: 20),
                          onPressed: () => Navigator.pop(ctx),
                        ),
                      ],
                    ),
                    const Divider(),
                    Expanded(
                      child: SingleChildScrollView(
                        child: LayoutBuilder(
                          builder: (context, constraints) {
                            final isWide = constraints.maxWidth >= 550;

                            Widget buildFieldPair(Widget left, Widget right) {
                              if (isWide) {
                                return Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Expanded(child: left),
                                    const SizedBox(width: 12),
                                    Expanded(child: right),
                                  ],
                                );
                              }
                              return Column(
                                children: [
                                  left,
                                  const SizedBox(height: 10),
                                  right,
                                ],
                              );
                            }

                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Step 1: Borrower & Amount
                                Card(
                                  elevation: 0,
                                  color: Theme.of(ctx).colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                                  margin: const EdgeInsets.only(bottom: 12),
                                  child: Padding(
                                    padding: const EdgeInsets.all(12.0),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        const Text('Step 1: Borrower & Amount', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF0284C7))),
                                        const SizedBox(height: 10),
                                        DropdownButtonFormField<String>(
                                          initialValue: selectedBorrowerId,
                                          decoration: const InputDecoration(labelText: 'Borrower *', border: OutlineInputBorder()),
                                          items: borrowers.map((b) {
                                            return DropdownMenuItem(value: b.id, child: Text(b.fullName));
                                          }).toList(),
                                          onChanged: (val) {
                                            if (val != null) setModalState(() => selectedBorrowerId = val);
                                          },
                                        ),
                                        const SizedBox(height: 10),
                                        buildFieldPair(
                                          TextField(
                                            controller: principalCtrl,
                                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                            decoration: InputDecoration(
                                              labelText: 'Principal Amount (${LoanUtils.currencySymbol(state.currencyCode)}) *',
                                              hintText: 'e.g. 5000',
                                              border: const OutlineInputBorder(),
                                            ),
                                            onChanged: (_) => setModalState(() {}),
                                          ),
                                          TextField(
                                            controller: rateCtrl,
                                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                            decoration: InputDecoration(
                                              labelText: 'Interest Rate (%) *',
                                              helperText: (selectedMethod == 'reducing' || selectedMethod == 'interest_only')
                                                  ? '% per year (per annum)'
                                                  : '% total for the whole term',
                                              border: const OutlineInputBorder(),
                                            ),
                                            onChanged: (_) => setModalState(() {}),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),

                                // Step 2: Loan Terms
                                Card(
                                  elevation: 0,
                                  color: Theme.of(ctx).colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                                  margin: const EdgeInsets.only(bottom: 12),
                                  child: Padding(
                                    padding: const EdgeInsets.all(12.0),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        const Text('Step 2: Loan Terms', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF0284C7))),
                                        const SizedBox(height: 10),
                                        buildFieldPair(
                                          DropdownButtonFormField<String>(
                                            initialValue: selectedFrequency,
                                            decoration: const InputDecoration(labelText: 'Repayment Frequency', border: OutlineInputBorder()),
                                            items: const [
                                              DropdownMenuItem(value: 'daily', child: Text('Daily')),
                                              DropdownMenuItem(value: 'weekly', child: Text('Weekly')),
                                              DropdownMenuItem(value: 'biweekly', child: Text('Bi-weekly')),
                                              DropdownMenuItem(value: 'monthly', child: Text('Monthly')),
                                            ],
                                            onChanged: (val) {
                                              if (val != null) setModalState(() => selectedFrequency = val);
                                            },
                                          ),
                                          TextField(
                                            controller: termCtrl,
                                            keyboardType: TextInputType.number,
                                            decoration: InputDecoration(labelText: '$termLabel *', border: const OutlineInputBorder()),
                                            onChanged: (_) => setModalState(() {}),
                                          ),
                                        ),
                                        const SizedBox(height: 10),
                                        Row(
                                          children: [
                                            Expanded(
                                              child: DropdownButtonFormField<String>(
                                                initialValue: selectedMethod,
                                                isExpanded: true,
                                                decoration: const InputDecoration(
                                                  labelText: 'Interest Method',
                                                  border: OutlineInputBorder(),
                                                ),
                                                items: const [
                                                  DropdownMenuItem(
                                                    value: 'flat',
                                                    child: Text('Flat / Add-on ("5-6")', overflow: TextOverflow.ellipsis),
                                                  ),
                                                  DropdownMenuItem(
                                                    value: 'one_time',
                                                    child: Text('One-Time Payment — single lump-sum repayment at the end', overflow: TextOverflow.ellipsis),
                                                  ),
                                                ],
                                                onChanged: (val) {
                                                  if (val != null) setModalState(() => selectedMethod = val);
                                                },
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 10),
                                        SwitchListTile(
                                          contentPadding: EdgeInsets.zero,
                                          title: const Text('Deduct Interest Upfront', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                                          subtitle: const Text('Interest is deducted from the disbursed cash; the borrower still repays the full principal.', style: TextStyle(fontSize: 11, color: Colors.grey)),
                                          value: deductInterestUpfront,
                                          onChanged: (val) => setModalState(() => deductInterestUpfront = val),
                                        ),
                                        const SizedBox(height: 10),
                                        buildFieldPair(
                                          TextField(
                                            controller: purposeCtrl,
                                            decoration: const InputDecoration(
                                              labelText: 'Loan Purpose *',
                                              hintText: 'e.g. Working Capital',
                                              border: OutlineInputBorder(),
                                            ),
                                            onChanged: (_) => setModalState(() {}),
                                          ),
                                          TextField(
                                            controller: dateCtrl,
                                            readOnly: true,
                                            decoration: const InputDecoration(
                                              labelText: 'Disbursement Date',
                                              suffixIcon: Icon(Icons.calendar_today, size: 18),
                                              border: OutlineInputBorder(),
                                            ),
                                            onTap: () async {
                                              DateTime initial;
                                              try {
                                                initial = DateTime.parse(dateCtrl.text.trim());
                                              } catch (_) {
                                                initial = DateTime.now();
                                              }
                                              final picked = await showDatePicker(
                                                context: context,
                                                initialDate: initial,
                                                firstDate: DateTime(2000),
                                                lastDate: DateTime(2100),
                                              );
                                              if (picked != null) {
                                                setModalState(() {
                                                  dateCtrl.text = picked.toIso8601String().split('T')[0];
                                                });
                                              }
                                            },
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),

                                // Step 3: Fees & Penalties (optional)
                                Theme(
                                  data: Theme.of(ctx).copyWith(dividerColor: Colors.transparent),
                                  child: Card(
                                    elevation: 0,
                                    color: Theme.of(ctx).colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                                    margin: const EdgeInsets.only(bottom: 12),
                                    child: ExpansionTile(
                                      title: const Text('Step 3: Fees & Penalties (optional)', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF0284C7))),
                                      subtitle: Text(
                                        totalFees > 0
                                            ? 'Total fees: ${LoanUtils.formatCurrency(totalFees, state.currencyCode)}'
                                            : 'No extra fees',
                                        style: TextStyle(fontSize: 11, color: totalFees > 0 ? Colors.redAccent : Colors.grey),
                                      ),
                                      tilePadding: const EdgeInsets.symmetric(horizontal: 12),
                                      childrenPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                      children: [
                                        buildFieldPair(
                                          Row(
                                            children: [
                                              Expanded(
                                                child: DropdownButtonFormField<String>(
                                                  initialValue: processingFeeType,
                                                  decoration: const InputDecoration(labelText: 'Processing Fee', border: OutlineInputBorder()),
                                                  items: const [
                                                    DropdownMenuItem(value: 'none', child: Text('None')),
                                                    DropdownMenuItem(value: 'fixed', child: Text('Fixed Amount')),
                                                    DropdownMenuItem(value: 'percent', child: Text('Percent (%)')),
                                                  ],
                                                  onChanged: (val) => setModalState(() => processingFeeType = val ?? 'none'),
                                                ),
                                              ),
                                              if (processingFeeType != 'none') ...[
                                                const SizedBox(width: 8),
                                                Expanded(
                                                  child: TextField(
                                                    controller: processingFeeCtrl,
                                                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                                    decoration: InputDecoration(
                                                      labelText: processingFeeType == 'fixed' ? 'Amount' : 'Rate (%)',
                                                      border: const OutlineInputBorder(),
                                                    ),
                                                    onChanged: (_) => setModalState(() {}),
                                                  ),
                                                ),
                                              ],
                                            ],
                                          ),
                                          Row(
                                            children: [
                                              Expanded(
                                                child: DropdownButtonFormField<String>(
                                                  initialValue: serviceFeeType,
                                                  decoration: const InputDecoration(labelText: 'Service Fee', border: OutlineInputBorder()),
                                                  items: const [
                                                    DropdownMenuItem(value: 'none', child: Text('None')),
                                                    DropdownMenuItem(value: 'fixed', child: Text('Fixed Amount')),
                                                    DropdownMenuItem(value: 'percent', child: Text('Percent (%)')),
                                                    DropdownMenuItem(value: 'percent_per_day', child: Text('Percent / Day (%/day)')),
                                                  ],
                                                  onChanged: (val) => setModalState(() => serviceFeeType = val ?? 'none'),
                                                ),
                                              ),
                                              if (serviceFeeType != 'none') ...[
                                                const SizedBox(width: 8),
                                                Expanded(
                                                  child: TextField(
                                                    controller: serviceFeeCtrl,
                                                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                                    decoration: InputDecoration(
                                                      labelText: serviceFeeType == 'fixed' ? 'Amount' : (serviceFeeType == 'percent_per_day' ? 'Daily %' : 'Rate (%)'),
                                                      border: const OutlineInputBorder(),
                                                    ),
                                                    onChanged: (_) => setModalState(() {}),
                                                  ),
                                                ),
                                              ],
                                            ],
                                          ),
                                        ),
                                        const SizedBox(height: 10),
                                        buildFieldPair(
                                          Row(
                                            children: [
                                              Expanded(
                                                child: DropdownButtonFormField<String>(
                                                  initialValue: disbursementFeeType,
                                                  decoration: const InputDecoration(labelText: 'Disbursement Fee', border: OutlineInputBorder()),
                                                  items: const [
                                                    DropdownMenuItem(value: 'none', child: Text('None')),
                                                    DropdownMenuItem(value: 'fixed', child: Text('Fixed Amount')),
                                                    DropdownMenuItem(value: 'percent', child: Text('Percent (%)')),
                                                  ],
                                                  onChanged: (val) => setModalState(() => disbursementFeeType = val ?? 'none'),
                                                ),
                                              ),
                                              if (disbursementFeeType != 'none') ...[
                                                const SizedBox(width: 8),
                                                Expanded(
                                                  child: TextField(
                                                    controller: disbursementFeeCtrl,
                                                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                                    decoration: InputDecoration(
                                                      labelText: disbursementFeeType == 'fixed' ? 'Amount' : 'Rate (%)',
                                                      border: const OutlineInputBorder(),
                                                    ),
                                                    onChanged: (_) => setModalState(() {}),
                                                  ),
                                                ),
                                              ],
                                            ],
                                          ),
                                          Row(
                                            children: [
                                              Expanded(
                                                child: DropdownButtonFormField<String>(
                                                  initialValue: notarialFeeType,
                                                  decoration: const InputDecoration(labelText: 'Notarial Fee', border: OutlineInputBorder()),
                                                  items: const [
                                                    DropdownMenuItem(value: 'none', child: Text('None')),
                                                    DropdownMenuItem(value: 'fixed', child: Text('Fixed Amount')),
                                                    DropdownMenuItem(value: 'percent', child: Text('Percent (%)')),
                                                  ],
                                                  onChanged: (val) => setModalState(() => notarialFeeType = val ?? 'none'),
                                                ),
                                              ),
                                              if (notarialFeeType != 'none') ...[
                                                const SizedBox(width: 8),
                                                Expanded(
                                                  child: TextField(
                                                    controller: notarialFeeCtrl,
                                                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                                    decoration: InputDecoration(
                                                      labelText: notarialFeeType == 'fixed' ? 'Amount' : 'Rate (%)',
                                                      border: const OutlineInputBorder(),
                                                    ),
                                                    onChanged: (_) => setModalState(() {}),
                                                  ),
                                                ),
                                              ],
                                            ],
                                          ),
                                        ),
                                        const SizedBox(height: 10),
                                        buildFieldPair(
                                          Row(
                                            children: [
                                              Expanded(
                                                child: DropdownButtonFormField<String>(
                                                  initialValue: insuranceFeeType,
                                                  decoration: const InputDecoration(labelText: 'Credit Life Insurance', border: OutlineInputBorder()),
                                                  items: const [
                                                    DropdownMenuItem(value: 'none', child: Text('None')),
                                                    DropdownMenuItem(value: 'fixed', child: Text('Fixed Amount')),
                                                    DropdownMenuItem(value: 'percent', child: Text('Percent (%)')),
                                                  ],
                                                  onChanged: (val) => setModalState(() => insuranceFeeType = val ?? 'none'),
                                                ),
                                              ),
                                              if (insuranceFeeType != 'none') ...[
                                                const SizedBox(width: 8),
                                                Expanded(
                                                  child: TextField(
                                                    controller: insuranceFeeCtrl,
                                                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                                    decoration: InputDecoration(
                                                      labelText: insuranceFeeType == 'fixed' ? 'Amount' : 'Rate (%)',
                                                      border: const OutlineInputBorder(),
                                                    ),
                                                    onChanged: (_) => setModalState(() {}),
                                                  ),
                                                ),
                                              ],
                                            ],
                                          ),
                                          Row(
                                            children: [
                                              Expanded(
                                                child: DropdownButtonFormField<String>(
                                                  initialValue: selectedPenaltyType,
                                                  decoration: const InputDecoration(labelText: 'Late Penalty Type', border: OutlineInputBorder()),
                                                  items: const [
                                                    DropdownMenuItem(value: 'none', child: Text('None')),
                                                    DropdownMenuItem(value: 'fixed_per_period', child: Text('Fixed per overdue period')),
                                                    DropdownMenuItem(value: 'percent_per_period', child: Text('Percent (%) per overdue period')),
                                                    DropdownMenuItem(value: 'fixed_once', child: Text('Fixed once when overdue')),
                                                  ],
                                                  onChanged: (val) {
                                                    if (val != null) setModalState(() => selectedPenaltyType = val);
                                                  },
                                                ),
                                              ),
                                              if (selectedPenaltyType != 'none') ...[
                                                const SizedBox(width: 8),
                                                Expanded(
                                                  child: TextField(
                                                    controller: penaltyValueCtrl,
                                                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                                    decoration: InputDecoration(
                                                      labelText: selectedPenaltyType == 'percent_per_period' ? 'Penalty Rate (%)' : 'Penalty Amount',
                                                      border: const OutlineInputBorder(),
                                                    ),
                                                    onChanged: (_) => setModalState(() {}),
                                                  ),
                                                ),
                                              ],
                                            ],
                                          ),
                                        ),
                                        const SizedBox(height: 10),
                                        TextField(
                                          controller: notesCtrl,
                                          decoration: const InputDecoration(labelText: 'Notes', border: OutlineInputBorder()),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),

                                // Step 4: Review Live Preview Box
                                Card(
                                  elevation: 0,
                                  color: Theme.of(ctx).colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
                                  margin: const EdgeInsets.only(bottom: 12),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                    side: BorderSide(
                                      color: Colors.grey.withValues(alpha: 0.3),
                                    ),
                                  ),
                                  child: Padding(
                                    padding: const EdgeInsets.all(12.0),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        const Text('Step 4: Review Loan Terms', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF0284C7))),
                                        const SizedBox(height: 10),

                                        if (p > 0) ...[
                                          Wrap(
                                            spacing: 16,
                                            runSpacing: 10,
                                            alignment: WrapAlignment.spaceBetween,
                                            children: [
                                              Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  Row(
                                                    mainAxisSize: MainAxisSize.min,
                                                    children: const [
                                                      Text('Borrower Receives', style: TextStyle(fontSize: 10, color: Colors.grey)),
                                                      SizedBox(width: 2),
                                                      Tooltip(
                                                        message: 'Net disbursed amount received by borrower after deducting upfront fees.',
                                                        child: Icon(Icons.info_outline, size: 12, color: Colors.grey),
                                                      ),
                                                    ],
                                                  ),
                                                  Text(LoanUtils.formatCurrency(netDisbursed, state.currencyCode),
                                                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF059669))),
                                                ],
                                              ),
                                              Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  Row(
                                                    mainAxisSize: MainAxisSize.min,
                                                    children: const [
                                                      Text('Total to Repay', style: TextStyle(fontSize: 10, color: Colors.grey)),
                                                      SizedBox(width: 2),
                                                      Tooltip(
                                                        message: 'Total scheduled repayment sum across all installments.',
                                                        child: Icon(Icons.info_outline, size: 12, color: Colors.grey),
                                                      ),
                                                    ],
                                                  ),
                                                  Text(LoanUtils.formatCurrency(totalScheduled, state.currencyCode),
                                                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF10B981))),
                                                ],
                                              ),
                                            ],
                                          ),

                                          const SizedBox(height: 8),
                                          const Divider(height: 8),
                                          const SizedBox(height: 4),

                                          Wrap(
                                            spacing: 14,
                                            runSpacing: 4,
                                            children: [
                                              Text('Total Fees: -${LoanUtils.formatCurrency(totalFees, state.currencyCode)}',
                                                  style: const TextStyle(fontSize: 11, color: Colors.redAccent)),
                                              Text('Total Interest: ${LoanUtils.formatCurrency(totalInterest, state.currencyCode)}',
                                                  style: const TextStyle(fontSize: 11, color: Colors.grey)),
                                            ],
                                          ),

                                          if (schedPreview.isNotEmpty) ...[
                                            const SizedBox(height: 6),
                                            Text('Installment Schedule: ${schedPreview.length} period(s) @ ${LoanUtils.formatCurrency(schedPreview.first.amount, state.currencyCode)} / period',
                                                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                                          ],
                                        ] else ...[
                                          const Text('Enter loan principal amount to view live calculation summary.', style: TextStyle(fontSize: 11, color: Colors.grey)),
                                        ],
                                      ],
                                    ),
                                  ),
                                ),

                                if (validationError != null) ...[
                                  Text(validationError!, style: const TextStyle(color: Colors.redAccent, fontSize: 12)),
                                  const SizedBox(height: 8),
                                ],
                              ],
                            );
                          },
                        ),
                      ),
                    ),
                    const Divider(),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        OutlinedButton(
                          onPressed: () => Navigator.pop(ctx),
                          child: const Text('Cancel'),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF059669),
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                          ),
                          onPressed: () async {
                            final penVal = double.tryParse(penaltyValueCtrl.text.trim()) ?? 0.0;
                            final purpose = purposeCtrl.text.trim().isEmpty ? 'Working Capital' : purposeCtrl.text.trim();

                            final err = LoanUtils.validateLoanParams(
                              principal: p,
                              interestRate: r,
                              termCount: t,
                              repaymentFrequency: selectedFrequency,
                              penaltyValue: penVal,
                              interestMethod: selectedMethod,
                              penaltyType: selectedPenaltyType,
                            );

                            if (err != null) {
                              setModalState(() => validationError = err);
                              return;
                            }

                            final selectedB = borrowers.firstWhere((b) => b.id == selectedBorrowerId);
                            final bLoans = state.loans.where((l) => l.borrowerId == selectedBorrowerId).toList();
                            final assessment = LoanUtils.assessBorrower(selectedB, bLoans);

                            final effectiveRate = deductInterestUpfront ? 0.0 : r;
                            final interestDeduction = deductInterestUpfront ? LoanUtils.round2(p * r / 100.0) : 0.0;

                            final sched = LoanUtils.generateSchedule(
                              p,
                              effectiveRate,
                              t,
                              dateCtrl.text.trim(),
                              repaymentFrequency: selectedFrequency,
                              interestMethod: selectedMethod,
                            );

                            final newLoan = Loan(
                              id: 'loan_${DateTime.now().millisecondsSinceEpoch}',
                              borrowerId: selectedBorrowerId,
                              principal: p,
                              interestRate: r,
                              termMonths: selectedFrequency == 'monthly' ? t : 0,
                              repaymentFrequency: selectedFrequency,
                              interestMethod: selectedMethod,
                              termCount: t,
                              purpose: purpose,
                              status: 'pending',
                              disbursementDate: dateCtrl.text.trim(),
                              upfrontDeductionType: deductInterestUpfront ? 'fixed' : 'none',
                              upfrontDeductionValue: interestDeduction,
                              processingFeeType: processingFeeType,
                              processingFeeValue: procVal,
                              serviceFeeType: serviceFeeType,
                              serviceFeeValue: servVal,
                              disbursementFeeType: disbursementFeeType,
                              disbursementFeeValue: disbVal,
                              notarialFeeType: notarialFeeType,
                              notarialFeeValue: notaVal,
                              creditLifeInsuranceFeeType: insuranceFeeType,
                              creditLifeInsuranceFeeValue: insVal,
                              penaltyType: selectedPenaltyType,
                              penaltyValue: penVal,
                              creditAssessment: assessment,
                              schedule: sched,
                              payments: [],
                              notes: notesCtrl.text.trim(),
                              createdAt: dateCtrl.text.trim(),
                            );

                            try {
                              await state.addLoan(newLoan);
                              if (!ctx.mounted) return;
                              Navigator.pop(ctx);

                              if (!context.mounted) return;
                              HapticFeedback.lightImpact();
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Loan created successfully')),
                              );
                            } catch (e) {
                              if (!context.mounted) return;
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Failed to create loan: ${e.toString().replaceAll('StateError: ', '')}')),
                              );
                            }
                          },
                          child: Text(
                            state.isSoloMode ? 'Create Active Loan' : 'Create Pending Loan',
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
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
    final borrowerMap = {for (var b in borrowers) b.id: b};

    final filtered = loans.where((loan) {
      final b = borrowerMap[loan.borrowerId];
      final matchesSearch = loan.purpose.toLowerCase().contains(_searchTerm.toLowerCase()) ||
          (b?.fullName.toLowerCase().contains(_searchTerm.toLowerCase()) ?? false) ||
          loan.principal.toString().contains(_searchTerm);

      final matchesStatus = _statusFilter == 'all' || loan.status == _statusFilter;

      return matchesSearch && matchesStatus;
    }).toList();

    final isDesktop = ResponsiveContainer.isDesktop(context);

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: ResponsiveContainer(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ScreenHeader(
              title: 'Loans Portfolio',
              action: (state.currentUser != null && state.currentUser!.role != 'viewer')
                  ? ElevatedButton.icon(
                      onPressed: () => _showNewLoanDialog(context),
                      icon: const Icon(Icons.add, size: 16),
                      label: const Text('New Loan'),
                    )
                  : null,
            ),
            const SizedBox(height: 12),
            SearchFilterBar<String>(
              hintText: 'Search purpose or borrower...',
              onSearchChanged: (val) => setState(() => _searchTerm = val),
              filterValue: _statusFilter,
              filterItems: const [
                DropdownMenuItem(value: 'all', child: Text('All Status')),
                DropdownMenuItem(value: 'pending', child: Text('Pending')),
                DropdownMenuItem(value: 'active', child: Text('Active')),
                DropdownMenuItem(value: 'completed', child: Text('Completed')),
                DropdownMenuItem(value: 'defaulted', child: Text('Defaulted')),
                DropdownMenuItem(value: 'rejected', child: Text('Rejected')),
              ],
              onFilterChanged: (val) => setState(() => _statusFilter = val ?? 'all'),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: filtered.isEmpty
                  ? Center(child: Text('No loans found.', style: TextStyle(fontSize: isDesktop ? 14 : 12)))
                  : LayoutBuilder(
                      builder: (context, constraints) {
                        Widget buildLoanCard(Loan loan) {
                          final b = borrowerMap[loan.borrowerId];
                          final stats = LoanUtils.getLoanStats(loan);

                          return CustomCard(
                            onTap: () => widget.onSelectLoan(loan.id),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Expanded(
                                      child: Text(
                                        b?.fullName ?? 'Unknown',
                                        style: TextStyle(fontSize: isDesktop ? 15 : 14, fontWeight: FontWeight.bold),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    AppBadge(text: loan.status, variant: loan.status),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '${loan.purpose} • ${LoanUtils.formatCurrency(loan.principal, state.currencyCode)} @ ${loan.interestRate}%',
                                  style: TextStyle(fontSize: isDesktop ? 12 : 11, color: Colors.grey),
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 8),
                                if (loan.status == 'pending')
                                  Align(
                                    alignment: Alignment.centerRight,
                                    child: (state.isSoloMode || (state.currentUser?.role == 'approver' && loan.createdBy != state.currentUser?.id))
                                        ? ElevatedButton.icon(
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: const Color(0xFF059669),
                                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                            ),
                                            onPressed: () async {
                                              if (loan.creditAssessment?.riskRating == 'high') {
                                                final confirm = await showDialog<bool>(
                                                  context: context,
                                                  builder: (ctx) => AlertDialog(
                                                    title: const Text('High Risk Loan Warning'),
                                                    content: Text(
                                                      'Borrower "${b?.fullName ?? ''}" is rated HIGH RISK (DTI ${loan.creditAssessment?.dtiPct ?? 0}%).\n\nAre you sure you want to approve this loan with explicit override?',
                                                    ),
                                                    actions: [
                                                      TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                                                      ElevatedButton(
                                                        style: ElevatedButton.styleFrom(backgroundColor: Colors.orangeAccent),
                                                        onPressed: () => Navigator.pop(ctx, true),
                                                        child: const Text('Approve Override', style: TextStyle(color: Colors.white)),
                                                      ),
                                                    ],
                                                  ),
                                                );
                                                if (confirm == true) {
                                                  await state.approveLoan(loan.id, overrideHighRisk: true);
                                                  if (!context.mounted) return;
                                                  HapticFeedback.lightImpact();
                                                  ScaffoldMessenger.of(context).showSnackBar(
                                                    const SnackBar(content: Text('Loan approved')),
                                                  );
                                                }
                                              } else {
                                                await state.approveLoan(loan.id);
                                                if (!context.mounted) return;
                                                HapticFeedback.lightImpact();
                                                ScaffoldMessenger.of(context).showSnackBar(
                                                  const SnackBar(content: Text('Loan approved')),
                                                );
                                              }
                                            },
                                            icon: const Icon(Icons.check, size: 14, color: Colors.white),
                                            label: const Text('Approve', style: TextStyle(fontSize: 11, color: Colors.white)),
                                          )
                                        : Text(
                                            loan.createdBy == state.currentUser?.id
                                                ? 'Awaiting Approval (Creator)'
                                                : 'Awaiting Approver',
                                            style: const TextStyle(fontSize: 11, color: Colors.orangeAccent),
                                          ),
                                  )
                                else
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text('Balance: ${LoanUtils.formatCurrency(stats.outstandingBalance, state.currencyCode)}',
                                          style: TextStyle(fontSize: isDesktop ? 12 : 11, fontWeight: FontWeight.bold)),
                                      Text('${stats.progressPct}% Paid',
                                          style: TextStyle(fontSize: isDesktop ? 12 : 11, color: Colors.grey)),
                                    ],
                                  ),
                              ],
                            ),
                          );
                        }

                        if (isDesktop) {
                          return RefreshIndicator(
                            onRefresh: () => state.reload(),
                            child: GridView.builder(
                              physics: const AlwaysScrollableScrollPhysics(),
                              itemCount: filtered.length,
                              gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                                maxCrossAxisExtent: 450,
                                mainAxisExtent: 130,
                                crossAxisSpacing: 12,
                                mainAxisSpacing: 12,
                              ),
                              itemBuilder: (context, idx) => buildLoanCard(filtered[idx]),
                            ),
                          );
                        }

                        return RefreshIndicator(
                          onRefresh: () => state.reload(),
                          child: ListView.separated(
                            physics: const AlwaysScrollableScrollPhysics(),
                            itemCount: filtered.length,
                            separatorBuilder: (_, __) => const SizedBox(height: 10),
                            itemBuilder: (context, idx) => buildLoanCard(filtered[idx]),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
