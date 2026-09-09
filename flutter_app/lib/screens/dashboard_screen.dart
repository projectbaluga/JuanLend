import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../store/app_state.dart';
import '../utils/loan_utils.dart';
import '../widgets/app_badge.dart';
import '../widgets/app_progress_bar.dart';
import '../widgets/custom_card.dart';
import '../widgets/responsive_container.dart';
import '../widgets/stat_card.dart';

class DashboardScreen extends StatelessWidget {
  final Function(String) onSelectLoan;
  final Function(String) onSelectBorrower;

  const DashboardScreen({
    super.key,
    required this.onSelectLoan,
    required this.onSelectBorrower,
  });

  @override
  Widget build(BuildContext context) {
    final state = Provider.of<AppState>(context);
    final loans = state.loans;
    final borrowers = state.borrowers;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isDesktop = ResponsiveContainer.isDesktop(context);
    final isLargeDesktop = ResponsiveContainer.isLargeDesktop(context);

    final borrowerMap = {for (var b in borrowers) b.id: b};

    int activeLoansCount = 0;
    double totalDisbursed = 0.0;
    double outstandingBalance = 0.0;
    double overdueAmount = 0.0;
    double collectedThisMonth = 0.0;
    double expectedThisMonth = 0.0;
    double grandTotalCollected = 0.0;

    final now = DateTime.now();
    final currentYearMonth = '${now.year}-${now.month.toString().padLeft(2, '0')}';

    for (var loan in loans) {
      final stats = LoanUtils.getLoanStats(loan);

      if (loan.status == 'active') {
        activeLoansCount += 1;
      }

      if (['active', 'completed', 'defaulted'].contains(loan.status)) {
        totalDisbursed += stats.totalDisbursed;
        outstandingBalance += stats.outstandingBalance;
        overdueAmount += stats.overdueAmount;
      }

      for (var pay in loan.payments) {
        grandTotalCollected += pay.amount;
        if (pay.date.startsWith(currentYearMonth)) {
          collectedThisMonth += pay.amount;
        }
      }

      for (var inst in loan.schedule) {
        if (inst.dueDate.startsWith(currentYearMonth)) {
          expectedThisMonth += inst.amount;
        }
      }
    }

    final netProfit = grandTotalCollected - totalDisbursed;
    final capitalBalance = state.capital + netProfit;

    // Cash flow data
    final List<FlSpot> expectedSpots = [];
    final List<FlSpot> collectedSpots = [];
    final List<String> monthLabels = [];

    for (int i = -1; i < 5; i++) {
      final d = DateTime(now.year, now.month + i, 1);
      final yearMonth = '${d.year}-${d.month.toString().padLeft(2, '0')}';
      monthLabels.add(DateFormat('MMM').format(d));

      double exp = 0.0;
      double col = 0.0;

      for (var loan in loans) {
        if (['active', 'completed', 'defaulted'].contains(loan.status)) {
          for (var inst in loan.schedule) {
            if (inst.dueDate.startsWith(yearMonth)) {
              exp += inst.amount;
            }
          }
          for (var pay in loan.payments) {
            if (pay.date.startsWith(yearMonth)) {
              col += pay.amount;
            }
          }
        }
      }

      expectedSpots.add(FlSpot((i + 1).toDouble(), exp));
      collectedSpots.add(FlSpot((i + 1).toDouble(), col));
    }

    // Calculate Y-axis max scale
    double maxVal = 0.0;
    for (final spot in [...expectedSpots, ...collectedSpots]) {
      if (spot.y > maxVal) maxVal = spot.y;
    }

    double roundedMaxY = 1000.0;
    if (maxVal > 0) {
      double step = 250.0;
      if (maxVal > 5000) {
        step = 1000.0;
      } else if (maxVal > 1000) {
        step = 500.0;
      }
      roundedMaxY = (maxVal / step).ceil() * step;
    }

    // Donut chart status data
    final Map<String, int> statusCounts = {};
    for (var l in loans) {
      statusCounts[l.status] = (statusCounts[l.status] ?? 0) + 1;
    }

    final statusColors = <String, Color>{
      'active': const Color(0xFF10B981),
      'pending': const Color(0xFFF59E0B),
      'completed': const Color(0xFF3B82F6),
      'defaulted': const Color(0xFFEF4444),
      'rejected': const Color(0xFF6B7280),
    };

    final statusSections = statusCounts.entries.map((entry) {
      return PieChartSectionData(
        color: statusColors[entry.key] ?? Colors.grey,
        value: entry.value.toDouble(),
        title: '${entry.value}',
        radius: isDesktop ? 32 : 25,
        titleStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white),
      );
    }).toList();

    // Overdue loans
    final overdueLoans = loans.where((loan) {
      final stats = LoanUtils.getLoanStats(loan);
      return stats.overdueAmount > 0 && loan.status != 'completed';
    }).toList();

    // Recent loans
    final recentLoans = [...loans]..sort((a, b) => (b.createdAt ?? '').compareTo(a.createdAt ?? ''));

    int statGridColumns = 2;
    double statChildAspectRatio = 1.3;
    if (isLargeDesktop) {
      statGridColumns = 4;
      statChildAspectRatio = 1.5;
    } else if (isDesktop) {
      statGridColumns = 3;
      statChildAspectRatio = 1.4;
    }

    return RefreshIndicator(
      onRefresh: () async {
        await state.reload();
      },
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16.0),
        child: ResponsiveContainer(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Stat Cards Grid
            GridView.count(
              crossAxisCount: statGridColumns,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: statChildAspectRatio,
              children: [
                StatCard(
                  title: 'Capital (Puhunan)',
                  value: LoanUtils.formatCurrency(state.capital, state.currencyCode),
                  subtext: 'Starting capital fund',
                  icon: Icons.account_balance,
                ),
                StatCard(
                  title: 'Capital Balance',
                  value: LoanUtils.formatCurrency(capitalBalance, state.currencyCode),
                  subtext: 'Capital + profit',
                  icon: Icons.account_balance_wallet,
                ),
                StatCard(
                  title: 'Net Profit',
                  value: LoanUtils.formatCurrency(netProfit, state.currencyCode),
                  subtext: 'Collected - disbursed',
                  icon: Icons.show_chart,
                ),
                StatCard(
                  title: 'Total Disbursed',
                  value: LoanUtils.formatCurrency(totalDisbursed, state.currencyCode),
                  subtext: 'All-time disbursed loans',
                  icon: Icons.attach_money,
                ),
                StatCard(
                  title: 'Total Collected',
                  value: LoanUtils.formatCurrency(grandTotalCollected, state.currencyCode),
                  subtext: 'All-time repayments',
                  icon: Icons.monetization_on,
                ),
                StatCard(
                  title: 'Active Loans',
                  value: '$activeLoansCount',
                  subtext: 'In good standing',
                  icon: Icons.trending_up,
                ),
                StatCard(
                  title: 'Outstanding',
                  value: LoanUtils.formatCurrency(outstandingBalance, state.currencyCode),
                  subtext: 'Remaining balance',
                  icon: Icons.access_time,
                ),
                StatCard(
                  title: 'Overdue',
                  value: LoanUtils.formatCurrency(overdueAmount, state.currencyCode),
                  subtext: 'Requires attention',
                  icon: Icons.warning_amber_rounded,
                ),
                StatCard(
                  title: 'Collected (Month)',
                  value: LoanUtils.formatCurrency(collectedThisMonth, state.currencyCode),
                  subtext: 'Recorded this month',
                  icon: Icons.check_circle_outline,
                ),
                StatCard(
                  title: 'Expected (Month)',
                  value: LoanUtils.formatCurrency(expectedThisMonth, state.currencyCode),
                  subtext: 'Scheduled this month',
                  icon: Icons.calendar_today,
                ),
              ],
            ),

            const SizedBox(height: 20),

            // 6-Month Cash Flow Line/Area Chart
            CustomCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '6-Month Expected Cash Flow',
                    style: TextStyle(
                      fontSize: isDesktop ? 16 : 14,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : Colors.black,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Expected vs Collected payments',
                    style: TextStyle(fontSize: isDesktop ? 12 : 11, color: isDark ? Colors.grey.shade400 : Colors.grey.shade600),
                  ),
                  const SizedBox(height: 8),
                  // Legend for Cash Flow Chart
                  Row(
                    children: [
                      Container(width: 10, height: 10, decoration: const BoxDecoration(color: Colors.grey, shape: BoxShape.circle)),
                      const SizedBox(width: 4),
                      Text('Expected', style: TextStyle(fontSize: isDesktop ? 12 : 11, color: isDark ? Colors.grey.shade300 : Colors.grey.shade700)),
                      const SizedBox(width: 16),
                      Container(width: 10, height: 10, decoration: const BoxDecoration(color: Color(0xFF10B981), shape: BoxShape.circle)),
                      const SizedBox(width: 4),
                      Text('Collected', style: TextStyle(fontSize: isDesktop ? 12 : 11, color: isDark ? Colors.grey.shade300 : Colors.grey.shade700)),
                    ],
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    height: isDesktop ? 280 : 160,
                    child: LineChart(
                      LineChartData(
                        minX: 0,
                        maxX: (monthLabels.length - 1).toDouble(),
                        minY: 0,
                        maxY: roundedMaxY,
                        gridData: const FlGridData(show: false),
                        titlesData: FlTitlesData(
                          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                          leftTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              reservedSize: isDesktop ? 45 : 35,
                              interval: roundedMaxY / 4,
                              getTitlesWidget: (val, meta) {
                                if (val < 0 || val > roundedMaxY) return const SizedBox.shrink();
                                String text = val >= 1000
                                    ? '${(val / 1000).toStringAsFixed(val % 1000 == 0 ? 0 : 1)}k'
                                    : val.toInt().toString();
                                return Text(text, style: TextStyle(fontSize: isDesktop ? 11 : 9, color: isDark ? Colors.grey.shade400 : Colors.grey.shade600));
                              },
                            ),
                          ),
                          bottomTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              interval: 1,
                              reservedSize: 22,
                              getTitlesWidget: (val, meta) {
                                final idx = val.toInt();
                                if (idx >= 0 && idx < monthLabels.length) {
                                  return Text(monthLabels[idx], style: TextStyle(fontSize: isDesktop ? 12 : 10, color: isDark ? Colors.grey.shade400 : Colors.grey.shade600));
                                }
                                return const SizedBox.shrink();
                              },
                            ),
                          ),
                        ),
                        borderData: FlBorderData(show: false),
                        lineBarsData: [
                          LineChartBarData(
                            spots: expectedSpots,
                            isCurved: true,
                            color: Colors.grey,
                            barWidth: 2,
                            belowBarData: BarAreaData(show: true, color: Colors.grey.withValues(alpha: 0.1)),
                          ),
                          LineChartBarData(
                            spots: collectedSpots,
                            isCurved: true,
                            color: const Color(0xFF10B981),
                            barWidth: 2,
                            belowBarData: BarAreaData(show: true, color: const Color(0xFF10B981).withValues(alpha: 0.2)),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // Loans by Status Donut Chart Card
            if (statusCounts.isNotEmpty) ...[
              CustomCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Loans by Status',
                      style: TextStyle(
                        fontSize: isDesktop ? 16 : 14,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : Colors.black,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        SizedBox(
                          width: isDesktop ? 130 : 100,
                          height: isDesktop ? 130 : 100,
                          child: PieChart(
                            PieChartData(
                              sectionsSpace: 2,
                              centerSpaceRadius: isDesktop ? 30 : 22,
                              sections: statusSections,
                            ),
                          ),
                        ),
                        const SizedBox(width: 20),
                        Expanded(
                          child: Wrap(
                            spacing: 12,
                            runSpacing: 8,
                            children: statusCounts.entries.map((entry) {
                              final color = statusColors[entry.key] ?? Colors.grey;
                              return Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(width: 10, height: 10, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
                                  const SizedBox(width: 6),
                                  Text(
                                    '${entry.key.toUpperCase()}: ${entry.value}',
                                    style: TextStyle(fontSize: isDesktop ? 12 : 11, color: isDark ? Colors.grey.shade300 : Colors.grey.shade700),
                                  ),
                                ],
                              );
                            }).toList(),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
            ],

            // Overdue Loans List Card
            CustomCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.warning, color: Colors.redAccent, size: 18),
                          const SizedBox(width: 6),
                          Text(
                            'Overdue Repayments',
                            style: TextStyle(fontSize: isDesktop ? 16 : 14, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                      AppBadge(text: '${overdueLoans.length} requiring action', variant: 'high'),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (overdueLoans.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12.0),
                      child: Text('No overdue loans!', style: TextStyle(fontSize: isDesktop ? 13 : 12, color: Colors.grey)),
                    )
                  else
                    ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: overdueLoans.length,
                      separatorBuilder: (_, __) => const Divider(height: 16),
                      itemBuilder: (context, idx) {
                        final loan = overdueLoans[idx];
                        final b = borrowerMap[loan.borrowerId];
                        final stats = LoanUtils.getLoanStats(loan);

                        return InkWell(
                          onTap: () => onSelectLoan(loan.id),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  InkWell(
                                    onTap: () {
                                      if (loan.borrowerId.isNotEmpty) {
                                        onSelectBorrower(loan.borrowerId);
                                      }
                                    },
                                    child: Text(
                                      b?.fullName ?? 'Unknown',
                                      style: TextStyle(
                                        fontSize: isDesktop ? 14 : 13,
                                        fontWeight: FontWeight.bold,
                                        decoration: TextDecoration.underline,
                                      ),
                                    ),
                                  ),
                                  Text(
                                    '${loan.purpose} • ${LoanUtils.formatCurrency(loan.principal, state.currencyCode)}',
                                    style: TextStyle(fontSize: isDesktop ? 12 : 11, color: Colors.grey),
                                  ),
                                ],
                              ),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    '${LoanUtils.formatCurrency(stats.overdueAmount, state.currencyCode)} overdue',
                                    style: TextStyle(fontSize: isDesktop ? 13 : 12, fontWeight: FontWeight.bold, color: Colors.redAccent),
                                  ),
                                  if (stats.nextDue != null)
                                    Text(
                                      'Due ${LoanUtils.formatDate(stats.nextDue!.dueDate)}',
                                      style: TextStyle(fontSize: isDesktop ? 11 : 10, color: Colors.grey),
                                    ),
                                ],
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                ],
              ),
            ),

            const SizedBox(height: 20),

              // Recent Loans List
              CustomCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Recent Loans & Progress',
                      style: TextStyle(fontSize: isDesktop ? 16 : 14, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 12),
                    ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: recentLoans.length > 5 ? 5 : recentLoans.length,
                      separatorBuilder: (_, __) => const Divider(height: 16),
                      itemBuilder: (context, idx) {
                        final loan = recentLoans[idx];
                        final b = borrowerMap[loan.borrowerId];
                        final stats = LoanUtils.getLoanStats(loan);

                        return InkWell(
                          onTap: () => onSelectLoan(loan.id),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  InkWell(
                                    onTap: () {
                                      if (loan.borrowerId.isNotEmpty) {
                                        onSelectBorrower(loan.borrowerId);
                                      }
                                    },
                                    child: Text(
                                      '${b?.fullName ?? 'Unknown'} (${LoanUtils.formatCurrency(loan.principal, state.currencyCode)})',
                                      style: TextStyle(
                                        fontSize: isDesktop ? 14 : 13,
                                        fontWeight: FontWeight.bold,
                                        decoration: TextDecoration.underline,
                                      ),
                                    ),
                                  ),
                                  AppBadge(text: loan.status, variant: loan.status),
                                ],
                              ),
                              const SizedBox(height: 6),
                              if (loan.status == 'active' || loan.status == 'completed')
                                AppProgressBar(percentage: stats.progressPct)
                              else
                                Text(
                                  'Purpose: ${loan.purpose}',
                                  style: TextStyle(fontSize: isDesktop ? 12 : 11, color: Colors.grey),
                                ),
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
