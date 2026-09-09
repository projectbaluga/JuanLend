import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../models/borrower.dart';
import '../store/app_state.dart';
import '../utils/loan_utils.dart';
import '../widgets/app_badge.dart';
import '../widgets/custom_card.dart';
import '../widgets/responsive_container.dart';
import '../widgets/screen_header.dart';
import '../widgets/search_filter_bar.dart';

class BorrowersScreen extends StatefulWidget {
  final Function(String) onSelectBorrower;

  const BorrowersScreen({
    super.key,
    required this.onSelectBorrower,
  });

  @override
  State<BorrowersScreen> createState() => _BorrowersScreenState();
}

class _BorrowersScreenState extends State<BorrowersScreen> {
  String _searchTerm = '';
  String _riskFilter = 'all';

  void _showEditBorrowerDialog(BuildContext context, Borrower borrower) {
    final nameCtrl = TextEditingController(text: borrower.fullName);
    final emailCtrl = TextEditingController(text: borrower.email);
    final phoneCtrl = TextEditingController(text: borrower.phone);
    final addressCtrl = TextEditingController(text: borrower.address);
    final idCtrl = TextEditingController(text: borrower.idNumber);
    final empCtrl = TextEditingController(text: borrower.employment);
    final incomeCtrl = TextEditingController(text: borrower.monthlyIncome > 0 ? borrower.monthlyIncome.toString() : '');
    final scoreCtrl = TextEditingController(text: borrower.creditScore.toString());
    String selectedRisk = borrower.riskRating;

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
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Edit Borrower', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                TextField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(labelText: 'Full Name *', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: emailCtrl,
                        decoration: const InputDecoration(labelText: 'Email', border: OutlineInputBorder()),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextField(
                        controller: phoneCtrl,
                        decoration: const InputDecoration(labelText: 'Phone', border: OutlineInputBorder()),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: idCtrl,
                        decoration: const InputDecoration(labelText: 'ID Number', border: OutlineInputBorder()),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextField(
                        controller: empCtrl,
                        decoration: const InputDecoration(labelText: 'Employment', border: OutlineInputBorder()),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: incomeCtrl,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(labelText: 'Monthly Income', border: OutlineInputBorder()),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextField(
                        controller: scoreCtrl,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(labelText: 'Credit Score (0-100)', border: OutlineInputBorder()),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  initialValue: selectedRisk,
                  decoration: const InputDecoration(labelText: 'Risk Rating', border: OutlineInputBorder()),
                  items: const [
                    DropdownMenuItem(value: 'low', child: Text('Low Risk')),
                    DropdownMenuItem(value: 'medium', child: Text('Medium Risk')),
                    DropdownMenuItem(value: 'high', child: Text('High Risk')),
                  ],
                  onChanged: (val) => selectedRisk = val ?? 'medium',
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: addressCtrl,
                  decoration: const InputDecoration(labelText: 'Address', border: OutlineInputBorder()),
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
                        if (nameCtrl.text.trim().isEmpty) return;
                        final updates = {
                          'fullName': nameCtrl.text.trim(),
                          'email': emailCtrl.text.trim(),
                          'phone': phoneCtrl.text.trim(),
                          'address': addressCtrl.text.trim(),
                          'idNumber': idCtrl.text.trim(),
                          'employment': empCtrl.text.trim(),
                          'monthlyIncome': double.tryParse(incomeCtrl.text.trim()) ?? 0.0,
                          'creditScore': int.tryParse(scoreCtrl.text.trim()) ?? 50,
                          'riskRating': selectedRisk,
                        };

                        try {
                          await Provider.of<AppState>(context, listen: false).updateBorrower(borrower.id, updates);
                          if (!ctx.mounted) return;
                          Navigator.pop(ctx);

                          if (!context.mounted) return;
                          HapticFeedback.lightImpact();
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Borrower updated successfully')),
                          );
                        } catch (e) {
                          if (!context.mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Failed to update borrower: ${e.toString().replaceAll('StateError: ', '')}')),
                          );
                        }
                      },
                      child: const Text('Update Borrower'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _confirmDeleteBorrower(BuildContext context, Borrower borrower) {
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Delete Borrower?'),
          content: Text('Are you sure you want to delete "${borrower.fullName}"? This action cannot be undone.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
              onPressed: () async {
                Navigator.pop(ctx);
                try {
                  await Provider.of<AppState>(context, listen: false).deleteBorrower(borrower.id);
                  if (!context.mounted) return;
                  HapticFeedback.lightImpact();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Borrower deleted successfully')),
                  );
                } catch (e) {
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Failed to delete borrower: ${e.toString().replaceAll('StateError: ', '')}')),
                  );
                }
              },
              child: const Text('Delete', style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );
  }

  void _showAddBorrowerDialog(BuildContext context) {
    final nameCtrl = TextEditingController();
    final emailCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    final addressCtrl = TextEditingController();
    final idCtrl = TextEditingController();
    final empCtrl = TextEditingController();
    final incomeCtrl = TextEditingController();
    final scoreCtrl = TextEditingController(text: '50');
    String selectedRisk = 'medium';

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
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Add New Borrower', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                TextField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(labelText: 'Full Name *', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: emailCtrl,
                        decoration: const InputDecoration(labelText: 'Email', border: OutlineInputBorder()),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextField(
                        controller: phoneCtrl,
                        decoration: const InputDecoration(labelText: 'Phone', border: OutlineInputBorder()),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: idCtrl,
                        decoration: const InputDecoration(labelText: 'ID Number', border: OutlineInputBorder()),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextField(
                        controller: empCtrl,
                        decoration: const InputDecoration(labelText: 'Employment', border: OutlineInputBorder()),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: incomeCtrl,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(labelText: 'Monthly Income (\$)', border: OutlineInputBorder()),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextField(
                        controller: scoreCtrl,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(labelText: 'Credit Score (0-100)', border: OutlineInputBorder()),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  initialValue: selectedRisk,
                  decoration: const InputDecoration(labelText: 'Risk Rating', border: OutlineInputBorder()),
                  items: const [
                    DropdownMenuItem(value: 'low', child: Text('Low Risk')),
                    DropdownMenuItem(value: 'medium', child: Text('Medium Risk')),
                    DropdownMenuItem(value: 'high', child: Text('High Risk')),
                  ],
                  onChanged: (val) => selectedRisk = val ?? 'medium',
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: addressCtrl,
                  decoration: const InputDecoration(labelText: 'Address', border: OutlineInputBorder()),
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
                        if (nameCtrl.text.trim().isEmpty) return;
                        final newBorrower = Borrower(
                          id: 'bor_${DateTime.now().millisecondsSinceEpoch}',
                          fullName: nameCtrl.text.trim(),
                          email: emailCtrl.text.trim(),
                          phone: phoneCtrl.text.trim(),
                          address: addressCtrl.text.trim(),
                          idNumber: idCtrl.text.trim(),
                          employment: empCtrl.text.trim(),
                          monthlyIncome: double.tryParse(incomeCtrl.text.trim()) ?? 0.0,
                          creditScore: int.tryParse(scoreCtrl.text.trim()) ?? 50,
                          riskRating: selectedRisk,
                          notes: '',
                          createdAt: DateTime.now().toIso8601String().split('T')[0],
                        );

                        try {
                          await Provider.of<AppState>(context, listen: false).addBorrower(newBorrower);
                          if (!ctx.mounted) return;
                          Navigator.pop(ctx);

                          if (!context.mounted) return;
                          HapticFeedback.lightImpact();
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Borrower added successfully')),
                          );
                        } catch (e) {
                          if (!context.mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Failed to add borrower: ${e.toString().replaceAll('StateError: ', '')}')),
                          );
                        }
                      },
                      child: const Text('Save Borrower'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = Provider.of<AppState>(context);
    final borrowers = state.borrowers;
    final loans = state.loans;

    final filtered = borrowers.where((b) {
      final matchesSearch = b.fullName.toLowerCase().contains(_searchTerm.toLowerCase()) ||
          b.email.toLowerCase().contains(_searchTerm.toLowerCase()) ||
          b.phone.contains(_searchTerm) ||
          b.idNumber.toLowerCase().contains(_searchTerm.toLowerCase());

      final bLoans = loans.where((l) => l.borrowerId == b.id).toList();
      final assessment = LoanUtils.assessBorrower(b, bLoans);

      final matchesRisk = _riskFilter == 'all' || assessment.riskRating == _riskFilter;

      return matchesSearch && matchesRisk;
    }).toList();

    final isDesktop = ResponsiveContainer.isDesktop(context);

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: ResponsiveContainer(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ScreenHeader(
              title: 'Borrowers',
              titleSuffix: (!state.isFeaturesUnlocked && borrowers.length >= 5)
                  ? Text(
                      '(Limit reached — unlock in Settings)',
                      style: TextStyle(fontSize: isDesktop ? 12 : 11, color: Colors.amberAccent, fontWeight: FontWeight.w500),
                    )
                  : null,
              action: ElevatedButton.icon(
                onPressed: () => _showAddBorrowerDialog(context),
                icon: const Icon(Icons.person_add, size: 16),
                label: const Text('Add Borrower'),
              ),
            ),
            const SizedBox(height: 12),
            SearchFilterBar<String>(
              hintText: 'Search by name, email, phone...',
              onSearchChanged: (val) => setState(() => _searchTerm = val),
              filterValue: _riskFilter,
              filterItems: const [
                DropdownMenuItem(value: 'all', child: Text('All Risk')),
                DropdownMenuItem(value: 'low', child: Text('Low Risk')),
                DropdownMenuItem(value: 'medium', child: Text('Medium Risk')),
                DropdownMenuItem(value: 'high', child: Text('High Risk')),
              ],
              onFilterChanged: (val) => setState(() => _riskFilter = val ?? 'all'),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: filtered.isEmpty
                  ? Center(child: Text('No borrowers found.', style: TextStyle(fontSize: isDesktop ? 14 : 12)))
                  : LayoutBuilder(
                      builder: (context, constraints) {
                        Widget buildBorrowerCard(Borrower b) {
                          final bLoans = loans.where((l) => l.borrowerId == b.id).toList();
                          final assessment = LoanUtils.assessBorrower(b, bLoans);

                          return CustomCard(
                            onTap: () => widget.onSelectBorrower(b.id),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Expanded(
                                      child: Text(
                                        b.fullName,
                                        style: TextStyle(fontSize: isDesktop ? 15 : 14, fontWeight: FontWeight.bold),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    AppBadge(text: assessment.riskRating, variant: assessment.riskRating),
                                    PopupMenuButton<String>(
                                      icon: const Icon(Icons.more_vert, size: 18, color: Colors.grey),
                                      onSelected: (val) {
                                        if (val == 'edit') {
                                          _showEditBorrowerDialog(context, b);
                                        } else if (val == 'delete') {
                                          _confirmDeleteBorrower(context, b);
                                        }
                                      },
                                      itemBuilder: (ctx) => [
                                        const PopupMenuItem(
                                          value: 'edit',
                                          child: Row(
                                            children: [
                                              Icon(Icons.edit, size: 16),
                                              SizedBox(width: 8),
                                              Text('Edit Borrower', style: TextStyle(fontSize: 12)),
                                            ],
                                          ),
                                        ),
                                        const PopupMenuItem(
                                          value: 'delete',
                                          child: Row(
                                            children: [
                                              Icon(Icons.delete, size: 16, color: Colors.redAccent),
                                              SizedBox(width: 8),
                                              Text('Delete Borrower', style: TextStyle(fontSize: 12, color: Colors.redAccent)),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '${b.email.isNotEmpty ? b.email : b.phone} • Income: ${LoanUtils.formatCurrency(b.monthlyIncome)}',
                                  style: TextStyle(fontSize: isDesktop ? 12 : 11, color: Colors.grey),
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 6),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text('Credit Score: ${assessment.creditScore}/100',
                                        style: TextStyle(fontSize: isDesktop ? 12 : 11, fontWeight: FontWeight.bold)),
                                    Text('${bLoans.length} loan(s)',
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
                                mainAxisExtent: 110,
                                crossAxisSpacing: 12,
                                mainAxisSpacing: 12,
                              ),
                              itemBuilder: (context, idx) => buildBorrowerCard(filtered[idx]),
                            ),
                          );
                        }

                        return RefreshIndicator(
                          onRefresh: () => state.reload(),
                          child: ListView.separated(
                            physics: const AlwaysScrollableScrollPhysics(),
                            itemCount: filtered.length,
                            separatorBuilder: (_, __) => const SizedBox(height: 10),
                            itemBuilder: (context, idx) => buildBorrowerCard(filtered[idx]),
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
