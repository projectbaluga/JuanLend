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

class DashboardScreen extends StatefulWidget {
  final Function(String) onSelectLoan;
  final Function(String) onSelectBorrower;
  final VoidCallback? onViewLoans;
  final VoidCallback? onViewBorrowers;

  const DashboardScreen({
    super.key,
    required this.onSelectLoan,
    required this.onSelectBorrower,
    this.onViewLoans,
    this.onViewBorrowers,
  });

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final GlobalKey _overdueSectionKey = GlobalKey();
  final ScrollController _scrollController = ScrollController();
  int? _touchedStatusIndex;

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToOverdue() {
    final context = _overdueSectionKey.currentContext;
    if (context != null) {
      Scrollable.ensureVisible(
        context,
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeInOut,
      );
    }
  }

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) {
      return 'Good Morning';
    } else if (hour < 18) {
      return 'Good Afternoon';
    } else {
      return 'Good Evening';
    }
  }

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
    double grandTotalCollected = 0.0;

    final now = DateTime.now();

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
      }
    }

    final netProfit = grandTotalCollected - totalDisbursed;
    final capitalBalance = state.capital + netProfit;

    final metrics = LoanUtils.computeDashboardMetrics(loans, now);

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

    final statusEntries = statusCounts.entries.toList();
    final statusSections = statusEntries.asMap().entries.map((mapEntry) {
      final idx = mapEntry.key;
      final entry = mapEntry.value;
      final isTouched = idx == _touchedStatusIndex;
      final radius = isTouched ? (isDesktop ? 38.0 : 30.0) : (isDesktop ? 32.0 : 25.0);

      return PieChartSectionData(
        color: statusColors[entry.key] ?? Colors.grey,
        value: entry.value.toDouble(),
        title: '${entry.value}',
        radius: radius,
        titleStyle: TextStyle(
          fontSize: isTouched ? 13 : 11,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
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
      statChildAspectRatio = 1.45;
    } else if (isDesktop) {
      statGridColumns = 3;
      statChildAspectRatio = 1.35;
    }

    return RefreshIndicator(
      onRefresh: () async {
        await state.reload();
      },
      child: SingleChildScrollView(
        controller: _scrollController,
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16.0),
        child: ResponsiveContainer(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Welcome / Greeting Summary Header
              CustomCard(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${_getGreeting()}, ${state.businessName}',
                            style: TextStyle(
                              fontSize: isDesktop ? 20 : 16,
                              fontWeight: FontWeight.bold,
                              color: isDark ? Colors.white : Colors.black,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Portfolio Overview • ${loans.length} Total Loans • ${metrics.activeBorrowersCount} Active Borrowers',
                            style: TextStyle(
                              fontSize: isDesktop ? 12 : 11,
                              color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (isDesktop)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: const Color(0xFF10B981).withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.4)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.today, color: Color(0xFF10B981), size: 18),
                            const SizedBox(width: 8),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text("Today's Collections", style: TextStyle(fontSize: 10, color: Colors.grey)),
                                Text(
                                  LoanUtils.formatCurrency(metrics.todaysCollections, state.currencyCode),
                                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF10B981)),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // Empty Portfolio Call to Action
              if (loans.isEmpty) ...[
                CustomCard(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 24.0, horizontal: 16.0),
                    child: Center(
                      child: Column(
                        children: [
                          const Icon(Icons.account_balance_wallet_outlined, size: 48, color: Colors.grey),
                          const SizedBox(height: 12),
                          const Text(
                            'No Loans Issued Yet',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 6),
                          const Text(
                            'Get started by adding borrowers and issuing your first loan.',
                            style: TextStyle(fontSize: 12, color: Colors.grey),
                          ),
                          const SizedBox(height: 16),
                          if (widget.onViewLoans != null)
                            ElevatedButton.icon(
                              onPressed: widget.onViewLoans,
                              icon: const Icon(Icons.add, size: 16),
                              label: const Text('Issue New Loan'),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
              ],

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
                    accentColor: const Color(0xFF0284C7),
                  ),
                  StatCard(
                    title: 'Capital Balance',
                    value: LoanUtils.formatCurrency(capitalBalance, state.currencyCode),
                    subtext: 'Capital + profit',
                    icon: Icons.account_balance_wallet,
                    accentColor: const Color(0xFF059669),
                  ),
                  StatCard(
                    title: 'Net Profit',
                    value: LoanUtils.formatCurrency(netProfit, state.currencyCode),
                    subtext: 'Collected - disbursed',
                    icon: Icons.show_chart,
                    accentColor: netProfit >= 0 ? const Color(0xFF10B981) : Colors.redAccent,
                  ),
                  StatCard(
                    title: 'Collection Rate',
                    value: '${metrics.collectionRate}%',
                    subtext: 'Repaid / Disbursed',
                    icon: Icons.pie_chart_outline,
                    accentColor: const Color(0xFF10B981),
                  ),
                  StatCard(
                    title: 'Portfolio at Risk',
                    value: '${metrics.portfolioAtRisk}%',
                    subtext: 'Overdue / Outstanding',
                    icon: Icons.security,
                    accentColor: metrics.portfolioAtRisk > 0 ? Colors.redAccent : const Color(0xFF10B981),
                    onTap: overdueLoans.isNotEmpty ? _scrollToOverdue : null,
                  ),
                  StatCard(
                    title: 'Today\'s Collections',
                    value: LoanUtils.formatCurrency(metrics.todaysCollections, state.currencyCode),
                    subtext: 'Recorded today',
                    icon: Icons.today,
                    accentColor: const Color(0xFF059669),
                  ),
                  StatCard(
                    title: 'Due This Week',
                    value: LoanUtils.formatCurrency(metrics.dueThisWeek, state.currencyCode),
                    subtext: 'Next 7 days due',
                    icon: Icons.date_range,
                    accentColor: const Color(0xFFF59E0B),
                  ),
                  StatCard(
                    title: 'Total Disbursed',
                    value: LoanUtils.formatCurrency(totalDisbursed, state.currencyCode),
                    subtext: 'All-time disbursed loans',
                    icon: Icons.attach_money,
                    accentColor: const Color(0xFF3B82F6),
                    onTap: widget.onViewLoans,
                  ),
                  StatCard(
                    title: 'Total Collected',
                    value: LoanUtils.formatCurrency(grandTotalCollected, state.currencyCode),
                    subtext: 'All-time repayments',
                    icon: Icons.monetization_on,
                    accentColor: const Color(0xFF10B981),
                  ),
                  StatCard(
                    title: 'Active Loans',
                    value: '$activeLoansCount',
                    subtext: '${metrics.activeBorrowersCount} active borrowers',
                    icon: Icons.trending_up,
                    accentColor: const Color(0xFF10B981),
                    onTap: widget.onViewLoans,
                  ),
                  StatCard(
                    title: 'Outstanding',
                    value: LoanUtils.formatCurrency(outstandingBalance, state.currencyCode),
                    subtext: 'Remaining balance',
                    icon: Icons.access_time,
                    accentColor: const Color(0xFF8B5CF6),
                  ),
                  StatCard(
                    title: 'Overdue',
                    value: LoanUtils.formatCurrency(overdueAmount, state.currencyCode),
                    subtext: '${overdueLoans.length} loans requiring action',
                    icon: Icons.warning_amber_rounded,
                    accentColor: overdueLoans.isNotEmpty ? Colors.redAccent : Colors.grey,
                    onTap: overdueLoans.isNotEmpty ? _scrollToOverdue : null,
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
                          lineTouchData: LineTouchData(
                            enabled: true,
                            touchTooltipData: LineTouchTooltipData(
                              getTooltipItems: (touchedSpots) {
                                return touchedSpots.map((spot) {
                                  final month = monthLabels[spot.spotIndex];
                                  final isCollected = spot.barIndex == 1;
                                  final label = isCollected ? 'Collected' : 'Expected';
                                  final val = LoanUtils.formatCurrency(spot.y, state.currencyCode);
                                  return LineTooltipItem(
                                    '$month • $label\n$val',
                                    TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: isCollected ? const Color(0xFF10B981) : Colors.white,
                                    ),
                                  );
                                }).toList();
                              },
                            ),
                          ),
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
                                pieTouchData: PieTouchData(
                                  touchCallback: (FlTouchEvent event, pieTouchResponse) {
                                    setState(() {
                                      if (!event.isInterestedForInteractions ||
                                          pieTouchResponse == null ||
                                          pieTouchResponse.touchedSection == null) {
                                        _touchedStatusIndex = -1;
                                        return;
                                      }
                                      _touchedStatusIndex =
                                          pieTouchResponse.touchedSection!.touchedSectionIndex;
                                    });
                                  },
                                ),
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
                key: _overdueSectionKey,
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
                            onTap: () => widget.onSelectLoan(loan.id),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    InkWell(
                                      onTap: () {
                                        if (loan.borrowerId.isNotEmpty) {
                                          widget.onSelectBorrower(loan.borrowerId);
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
                          onTap: () => widget.onSelectLoan(loan.id),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  InkWell(
                                    onTap: () {
                                      if (loan.borrowerId.isNotEmpty) {
                                        widget.onSelectBorrower(loan.borrowerId);
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
