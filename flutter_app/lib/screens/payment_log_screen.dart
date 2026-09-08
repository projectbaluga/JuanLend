import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import '../models/payment_log_entry.dart';
import '../store/app_state.dart';
import '../utils/loan_utils.dart';
import '../widgets/app_badge.dart';
import '../widgets/custom_card.dart';
import '../widgets/responsive_container.dart';
import '../widgets/stat_card.dart';

class PaymentLogScreen extends StatefulWidget {
  final Function(String loanId) onSelectLoan;

  const PaymentLogScreen({
    super.key,
    required this.onSelectLoan,
  });

  @override
  State<PaymentLogScreen> createState() => _PaymentLogScreenState();
}

class _PaymentLogScreenState extends State<PaymentLogScreen> {
  String _searchQuery = '';
  String _selectedMethod = 'all';
  String _dateFilter = 'all'; // 'all', 'this_month', 'this_year'

  void _showExportDialog(BuildContext context, String exportText) {
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Export Payment Log Data'),
          content: SizedBox(
            width: double.maxFinite,
            height: 300,
            child: SingleChildScrollView(
              child: SelectableText(
                exportText,
                style: const TextStyle(fontFamily: 'monospace', fontSize: 11),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Clipboard.setData(ClipboardData(text: exportText));
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Payment log copied to clipboard!')),
                );
              },
              child: const Text('Copy to Clipboard'),
            ),
            ElevatedButton.icon(
              onPressed: () {
                // ignore: deprecated_member_use
                Share.share(exportText, subject: 'Payment Log Export');
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

  String _generateCsv(List<PaymentLogEntry> entries, String currencyCode) {
    final buffer = StringBuffer();
    buffer.writeln('Date,Borrower,Loan Purpose,Amount,Method,Recorded By,Recorded At,Note');

    for (final e in entries) {
      final p = e.payment;
      final dateEsc = '"${p.date.replaceAll('"', '""')}"';
      final borrowerEsc = '"${e.borrower.fullName.replaceAll('"', '""')}"';
      final purposeEsc = '"${e.loan.purpose.replaceAll('"', '""')}"';
      final amount = p.amount.toStringAsFixed(2);
      final methodEsc = '"${p.method.replaceAll('"', '""')}"';
      final recBy = p.recordedBy.isNotEmpty
          ? (p.recordedByRole.isNotEmpty ? '${p.recordedBy} (${p.recordedByRole})' : p.recordedBy)
          : '—';
      final recByEsc = '"${recBy.replaceAll('"', '""')}"';
      final recAtEsc = '"${p.recordedAt.replaceAll('"', '""')}"';
      final noteEsc = '"${p.note.replaceAll('"', '""')}"';

      buffer.writeln('$dateEsc,$borrowerEsc,$purposeEsc,$amount,$methodEsc,$recByEsc,$recAtEsc,$noteEsc');
    }

    return buffer.toString();
  }

  List<PaymentLogEntry> _filterEntries(List<PaymentLogEntry> allEntries) {
    final now = DateTime.now();
    final currentYearMonth = DateFormat('yyyy-MM').format(now);
    final currentYear = DateFormat('yyyy').format(now);

    return allEntries.where((e) {
      final p = e.payment;

      // Method filter
      if (_selectedMethod != 'all') {
        if (p.method.toLowerCase() != _selectedMethod.toLowerCase()) {
          return false;
        }
      }

      // Date range filter
      if (_dateFilter == 'this_month') {
        if (!p.date.startsWith(currentYearMonth)) {
          return false;
        }
      } else if (_dateFilter == 'this_year') {
        if (!p.date.startsWith(currentYear)) {
          return false;
        }
      }

      // Search query filter (borrower name, method, note, purpose)
      if (_searchQuery.trim().isNotEmpty) {
        final q = _searchQuery.trim().toLowerCase();
        final matchBorrower = e.borrower.fullName.toLowerCase().contains(q);
        final matchMethod = p.method.toLowerCase().contains(q);
        final matchNote = p.note.toLowerCase().contains(q);
        final matchPurpose = e.loan.purpose.toLowerCase().contains(q);
        final matchRecBy = p.recordedBy.toLowerCase().contains(q);

        if (!matchBorrower && !matchMethod && !matchNote && !matchPurpose && !matchRecBy) {
          return false;
        }
      }

      return true;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final state = Provider.of<AppState>(context);
    final allEntries = state.allPayments;
    final filteredEntries = _filterEntries(allEntries);

    final now = DateTime.now();
    final currentYearMonth = DateFormat('yyyy-MM').format(now);

    final totalCollectedFiltered = filteredEntries.fold(0.0, (sum, e) => sum + e.payment.amount);
    final paymentCountFiltered = filteredEntries.length;
    final avgPaymentFiltered = paymentCountFiltered > 0 ? (totalCollectedFiltered / paymentCountFiltered) : 0.0;

    final collectedThisMonth = allEntries
        .where((e) => e.payment.date.startsWith(currentYearMonth))
        .fold(0.0, (sum, e) => sum + e.payment.amount);

    return Scaffold(
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: ResponsiveContainer(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Summary Stat Cards
              LayoutBuilder(
                builder: (context, constraints) {
                  final cols = ResponsiveContainer.gridColumnsForWidth(constraints.maxWidth);
                  return GridView.count(
                    crossAxisCount: cols,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    childAspectRatio: 2.2,
                    children: [
                      StatCard(
                        title: 'Total Collected',
                        value: LoanUtils.formatCurrency(totalCollectedFiltered, state.currencyCode),
                        subtext: 'Filtered total ($paymentCountFiltered payments)',
                        icon: Icons.payments_outlined,
                      ),
                      StatCard(
                        title: 'Payment Count',
                        value: '$paymentCountFiltered',
                        subtext: 'Matching transactions',
                        icon: Icons.receipt_long_outlined,
                      ),
                      StatCard(
                        title: 'This Month',
                        value: LoanUtils.formatCurrency(collectedThisMonth, state.currencyCode),
                        subtext: '${DateFormat('MMMM yyyy').format(now)} collections',
                        icon: Icons.calendar_month_outlined,
                      ),
                      StatCard(
                        title: 'Average Payment',
                        value: LoanUtils.formatCurrency(avgPaymentFiltered, state.currencyCode),
                        subtext: 'Per transaction average',
                        icon: Icons.analytics_outlined,
                      ),
                    ],
                  );
                },
              ),

              const SizedBox(height: 16),

              // Search + Filter Bar + Export Button Row
              CustomCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            onChanged: (val) => setState(() => _searchQuery = val),
                            decoration: const InputDecoration(
                              hintText: 'Search borrower, method, note, purpose...',
                              prefixIcon: Icon(Icons.search, size: 18),
                              isDense: true,
                              contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton.icon(
                          onPressed: () {
                            final csvText = _generateCsv(filteredEntries, state.currencyCode);
                            _showExportDialog(context, csvText);
                          },
                          icon: const Icon(Icons.download, size: 16),
                          label: const Text('Export CSV'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 12,
                      runSpacing: 8,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text('Method: ', style: TextStyle(fontSize: 12, color: Colors.grey)),
                            DropdownButton<String>(
                              value: _selectedMethod,
                              isDense: true,
                              items: const [
                                DropdownMenuItem(value: 'all', child: Text('All Methods')),
                                DropdownMenuItem(value: 'Cash', child: Text('Cash')),
                                DropdownMenuItem(value: 'GCash / E-Wallet', child: Text('GCash / E-Wallet')),
                                DropdownMenuItem(value: 'Bank Transfer', child: Text('Bank Transfer')),
                                DropdownMenuItem(value: 'Check', child: Text('Check')),
                              ],
                              onChanged: (val) {
                                if (val != null) setState(() => _selectedMethod = val);
                              },
                            ),
                          ],
                        ),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text('Period: ', style: TextStyle(fontSize: 12, color: Colors.grey)),
                            DropdownButton<String>(
                              value: _dateFilter,
                              isDense: true,
                              items: const [
                                DropdownMenuItem(value: 'all', child: Text('All Time')),
                                DropdownMenuItem(value: 'this_month', child: Text('This Month')),
                                DropdownMenuItem(value: 'this_year', child: Text('This Year')),
                              ],
                              onChanged: (val) {
                                if (val != null) setState(() => _dateFilter = val);
                              },
                            ),
                          ],
                        ),
                        Text(
                          'Showing ${filteredEntries.length} of ${allEntries.length} record(s)',
                          style: const TextStyle(fontSize: 11, color: Colors.grey),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // Payments Table / List View
              CustomCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Transaction Log', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                        Text(
                          'Total: ${LoanUtils.formatCurrency(totalCollectedFiltered, state.currencyCode)}',
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF10B981)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    if (filteredEntries.isEmpty)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 24.0),
                        child: Center(
                          child: Text('No payment records match the current search filter.',
                              style: TextStyle(fontSize: 12, color: Colors.grey)),
                        ),
                      )
                    else
                      LayoutBuilder(
                        builder: (context, constraints) {
                          final availableWidth = constraints.maxWidth;
                          final isWide = availableWidth >= 700;

                          if (isWide) {
                            return SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: ConstrainedBox(
                                constraints: BoxConstraints(minWidth: availableWidth),
                                child: DataTable(
                                  showCheckboxColumn: false,
                                  headingRowHeight: 38,
                                  dataRowMinHeight: 44,
                                  dataRowMaxHeight: 52,
                                  columnSpacing: 16,
                                  columns: const [
                                    DataColumn(label: Text('Date', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                                    DataColumn(label: Text('Borrower', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                                    DataColumn(label: Text('Loan Purpose', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                                    DataColumn(label: Text('Amount', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                                    DataColumn(label: Text('Method', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                                    DataColumn(label: Text('Recorded By', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                                    DataColumn(label: Text('Note', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                                  ],
                                  rows: filteredEntries.map((e) {
                                    final p = e.payment;
                                    final recByStr = p.recordedBy.isNotEmpty
                                        ? (p.recordedByRole.isNotEmpty ? '${p.recordedBy} (${p.recordedByRole})' : p.recordedBy)
                                        : '—';

                                    return DataRow(
                                      onSelectChanged: (_) => widget.onSelectLoan(e.loan.id),
                                      cells: [
                                        DataCell(Text(LoanUtils.formatDate(p.date), style: const TextStyle(fontSize: 12))),
                                        DataCell(
                                          Column(
                                            mainAxisAlignment: MainAxisAlignment.center,
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(e.borrower.fullName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                                              Text(e.borrower.phone.isNotEmpty ? e.borrower.phone : e.borrower.email,
                                                  style: const TextStyle(fontSize: 10, color: Colors.grey)),
                                            ],
                                          ),
                                        ),
                                        DataCell(Text(e.loan.purpose, style: const TextStyle(fontSize: 12))),
                                        DataCell(Text(LoanUtils.formatCurrency(p.amount, state.currencyCode),
                                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF10B981)))),
                                        DataCell(AppBadge(text: p.method, variant: 'low')),
                                        DataCell(
                                          Tooltip(
                                            message: p.recordedAt.isNotEmpty ? 'Recorded at ${p.recordedAt}' : 'Recorded by system',
                                            child: Text(recByStr, style: const TextStyle(fontSize: 11, color: Colors.grey)),
                                          ),
                                        ),
                                        DataCell(Text(p.note.isNotEmpty ? p.note : '—', style: const TextStyle(fontSize: 11, color: Colors.grey))),
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
                            itemCount: filteredEntries.length,
                            separatorBuilder: (_, __) => const Divider(height: 16),
                            itemBuilder: (context, idx) {
                              final e = filteredEntries[idx];
                              final p = e.payment;
                              final recByStr = p.recordedBy.isNotEmpty
                                  ? (p.recordedByRole.isNotEmpty ? '${p.recordedBy} (${p.recordedByRole})' : p.recordedBy)
                                  : '';

                              return InkWell(
                                onTap: () => widget.onSelectLoan(e.loan.id),
                                borderRadius: BorderRadius.circular(8),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 4.0, horizontal: 4.0),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text(e.borrower.fullName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                          Text(
                                            LoanUtils.formatCurrency(p.amount, state.currencyCode),
                                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF10B981)),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 2),
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text('${e.loan.purpose} • ${LoanUtils.formatDate(p.date)}',
                                              style: const TextStyle(fontSize: 11, color: Colors.grey)),
                                          AppBadge(text: p.method, variant: 'low'),
                                        ],
                                      ),
                                      if (p.note.isNotEmpty || recByStr.isNotEmpty) ...[
                                        const SizedBox(height: 4),
                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            if (p.note.isNotEmpty)
                                              Expanded(
                                                child: Text('Note: ${p.note}',
                                                    style: const TextStyle(fontSize: 10, color: Colors.grey),
                                                    maxLines: 1,
                                                    overflow: TextOverflow.ellipsis),
                                              ),
                                            if (recByStr.isNotEmpty)
                                              Text('By $recByStr', style: const TextStyle(fontSize: 10, color: Colors.grey)),
                                          ],
                                        ),
                                      ],
                                    ],
                                  ),
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
