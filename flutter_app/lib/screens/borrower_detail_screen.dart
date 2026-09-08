import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../store/app_state.dart';
import '../utils/loan_utils.dart';
import '../widgets/app_badge.dart';
import '../widgets/app_progress_bar.dart';
import '../widgets/custom_card.dart';
import '../widgets/responsive_container.dart';

class BorrowerDetailScreen extends StatelessWidget {
  final String borrowerId;
  final VoidCallback onBack;
  final Function(String) onSelectLoan;
  final Function(String) onCreateLoanForBorrower;

  const BorrowerDetailScreen({
    super.key,
    required this.borrowerId,
    required this.onBack,
    required this.onSelectLoan,
    required this.onCreateLoanForBorrower,
  });

  @override
  Widget build(BuildContext context) {
    final state = Provider.of<AppState>(context);
    final borrowers = state.borrowers;
    final loans = state.loans;

    final borrower = borrowers.firstWhere(
      (b) => b.id == borrowerId,
      orElse: () => borrowers.first,
    );

    final borrowerLoans = loans.where((l) => l.borrowerId == borrower.id).toList();
    final assessment = LoanUtils.assessBorrower(borrower, borrowerLoans);

    final activeOutstanding = borrowerLoans
        .where((l) => l.status == 'active' || l.status == 'defaulted')
        .fold(0.0, (sum, l) => sum + LoanUtils.getLoanStats(l).outstandingBalance);

    final isDesktop = ResponsiveContainer.isDesktop(context);

    return Scaffold(
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: ResponsiveContainer(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  if (!isDesktop)
                    Text(
                      borrower.fullName,
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    )
                  else
                    const SizedBox.shrink(),
                  ElevatedButton.icon(
                    onPressed: () => onCreateLoanForBorrower(borrower.id),
                    icon: const Icon(Icons.add_card, size: 16),
                    label: const Text('Issue New Loan'),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // Contact Info Card
            CustomCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        borrower.fullName,
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      AppBadge(text: '${assessment.riskRating} risk', variant: assessment.riskRating),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text('ID: ${borrower.idNumber.isNotEmpty ? borrower.idNumber : 'N/A'}',
                      style: const TextStyle(fontSize: 12, color: Colors.grey)),
                  const SizedBox(height: 12),
                  const Divider(),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(Icons.email_outlined, size: 14, color: Colors.grey),
                      const SizedBox(width: 6),
                      Text(borrower.email.isNotEmpty ? borrower.email : 'No email',
                          style: const TextStyle(fontSize: 12)),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      const Icon(Icons.phone_outlined, size: 14, color: Colors.grey),
                      const SizedBox(width: 6),
                      Text(borrower.phone.isNotEmpty ? borrower.phone : 'No phone',
                          style: const TextStyle(fontSize: 12)),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      const Icon(Icons.location_on_outlined, size: 14, color: Colors.grey),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(borrower.address.isNotEmpty ? borrower.address : 'No address',
                            style: const TextStyle(fontSize: 12), overflow: TextOverflow.ellipsis),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      const Icon(Icons.work_outline, size: 14, color: Colors.grey),
                      const SizedBox(width: 6),
                      Text(borrower.employment.isNotEmpty ? borrower.employment : 'N/A',
                          style: const TextStyle(fontSize: 12)),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Risk Assessment Card
            CustomCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Credit Risk Assessment', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Derived Credit Score', style: TextStyle(fontSize: 12, color: Colors.grey)),
                      Text('${assessment.creditScore} / 100', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Monthly Income', style: TextStyle(fontSize: 12, color: Colors.grey)),
                      Text(LoanUtils.formatCurrency(borrower.monthlyIncome), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Debt-To-Income (DTI)', style: TextStyle(fontSize: 12, color: Colors.grey)),
                      Text('${assessment.dtiPct}%', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    ],
                  ),
                  const SizedBox(height: 10),
                  const Divider(),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Active Outstanding Debt', style: TextStyle(fontSize: 12, color: Colors.grey)),
                      Text(LoanUtils.formatCurrency(activeOutstanding),
                          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF10B981))),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Loan History Card
            CustomCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Loan History (${borrowerLoans.length})', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  if (borrowerLoans.isEmpty)
                    const Text('No loans found.', style: TextStyle(fontSize: 12, color: Colors.grey))
                  else
                    ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: borrowerLoans.length,
                      separatorBuilder: (_, __) => const Divider(height: 16),
                      itemBuilder: (context, idx) {
                        final loan = borrowerLoans[idx];
                        final stats = LoanUtils.getLoanStats(loan);

                        return InkWell(
                          onTap: () => onSelectLoan(loan.id),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(loan.purpose, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                                  AppBadge(text: loan.status, variant: loan.status),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Principal: ${LoanUtils.formatCurrency(loan.principal)} @ ${loan.interestRate}% • ${loan.termMonths} mo',
                                style: const TextStyle(fontSize: 11, color: Colors.grey),
                              ),
                              const SizedBox(height: 6),
                              if (loan.status == 'active' || loan.status == 'completed')
                                AppProgressBar(percentage: stats.progressPct),
                            ],
                          ),
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
