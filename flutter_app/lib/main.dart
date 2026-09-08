import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'screens/borrower_detail_screen.dart';
import 'screens/borrowers_screen.dart';
import 'screens/dashboard_screen.dart';
import 'screens/loan_detail_screen.dart';
import 'screens/loans_screen.dart';
import 'screens/login_screen.dart';
import 'screens/payment_log_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/users_screen.dart';
import 'widgets/responsive_container.dart';
import 'store/app_state.dart';
import 'store/offline_store.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final offlineStore = await OfflineStore.init();

  runApp(
    ChangeNotifierProvider(
      create: (_) => AppState(offlineStore),
      child: const MicroLendApp(),
    ),
  );
}

const String _envAppName = String.fromEnvironment('APP_NAME', defaultValue: 'JuanLend');
final String appTitle = _envAppName.trim().isEmpty ? 'JuanLend' : _envAppName;

class MicroLendApp extends StatelessWidget {
  const MicroLendApp({super.key});

  @override
  Widget build(BuildContext context) {
    final state = Provider.of<AppState>(context);

    return MaterialApp(
      title: appTitle,
      debugShowCheckedModeBanner: false,
      themeMode: state.themeMode,
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.light,
        scaffoldBackgroundColor: const Color(0xFFFAFAFA),
        colorScheme: const ColorScheme.light(
          surface: Colors.white,
          primary: Color(0xFF18181B),
        ),
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF09090B),
        colorScheme: const ColorScheme.dark(
          surface: Color(0xFF18181B),
          primary: Colors.white,
        ),
      ),
      home: !state.isLoggedIn
          ? const LoginScreen()
          : (state.currentUser?.mustChangePassword == true
              ? const ForcePasswordChangeScreen()
              : const MainShell()),
    );
  }
}

class ForcePasswordChangeScreen extends StatefulWidget {
  const ForcePasswordChangeScreen({super.key});

  @override
  State<ForcePasswordChangeScreen> createState() => _ForcePasswordChangeScreenState();
}

class _ForcePasswordChangeScreenState extends State<ForcePasswordChangeScreen> {
  final _oldPasswordCtrl = TextEditingController();
  final _newPasswordCtrl = TextEditingController();
  final _confirmPasswordCtrl = TextEditingController();
  String? _errorMsg;
  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    final state = Provider.of<AppState>(context);
    final user = state.currentUser;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Password Change Required'),
        actions: [
          IconButton(icon: const Icon(Icons.logout), onPressed: state.logout),
        ],
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: ResponsiveContainer(
            maxWidth: 420,
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Icon(Icons.lock_reset, size: 48, color: Colors.orangeAccent),
                    const SizedBox(height: 12),
                    Text(
                      'Welcome, ${user?.username ?? "User"}',
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'You must change your initial password before proceeding.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                    const SizedBox(height: 20),
                    if (_errorMsg != null) ...[
                      Text(_errorMsg!, style: const TextStyle(color: Colors.redAccent, fontSize: 12), textAlign: TextAlign.center),
                      const SizedBox(height: 12),
                    ],
                    TextField(
                      controller: _oldPasswordCtrl,
                      obscureText: true,
                      decoration: const InputDecoration(labelText: 'Current Password', border: OutlineInputBorder()),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _newPasswordCtrl,
                      obscureText: true,
                      decoration: const InputDecoration(labelText: 'New Password', border: OutlineInputBorder()),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _confirmPasswordCtrl,
                      obscureText: true,
                      decoration: const InputDecoration(labelText: 'Confirm New Password', border: OutlineInputBorder()),
                    ),
                    const SizedBox(height: 20),
                    ElevatedButton(
                      onPressed: _isLoading
                          ? null
                          : () async {
                              final oldP = _oldPasswordCtrl.text.trim();
                              final newP = _newPasswordCtrl.text.trim();
                              final confP = _confirmPasswordCtrl.text.trim();

                              if (oldP.isEmpty || newP.isEmpty) {
                                setState(() => _errorMsg = 'Please enter all fields.');
                                return;
                              }

                              if (newP != confP) {
                                setState(() => _errorMsg = 'New passwords do not match.');
                                return;
                              }

                              setState(() {
                                _isLoading = true;
                                _errorMsg = null;
                              });

                              try {
                                await state.changePassword(user!.id, oldP, newP);
                              } catch (e) {
                                setState(() {
                                  _isLoading = false;
                                  _errorMsg = e.toString().replaceAll('ArgumentError: ', '');
                                });
                              }
                            },
                      child: _isLoading
                          ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2))
                          : const Text('Update Password & Continue'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _NavDestination {
  final String key;
  final String label;
  final IconData iconOutline;
  final IconData iconSelected;
  final Widget Function(_MainShellState state) builder;

  const _NavDestination({
    required this.key,
    required this.label,
    required this.iconOutline,
    required this.iconSelected,
    required this.builder,
  });
}

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _currentIndex = 0;
  String? _selectedBorrowerId;
  String? _selectedLoanId;
  String? _issueLoanBorrowerId;

  List<_NavDestination> _getNavDestinations(bool isSoloMode) {
    return [
      _NavDestination(
        key: 'dashboard',
        label: 'Dashboard',
        iconOutline: Icons.dashboard_outlined,
        iconSelected: Icons.dashboard,
        builder: (s) => DashboardScreen(
          onSelectLoan: (id) => s.setState(() => s._selectedLoanId = id),
          onSelectBorrower: (id) => s.setState(() => s._selectedBorrowerId = id),
        ),
      ),
      _NavDestination(
        key: 'borrowers',
        label: 'Borrowers',
        iconOutline: Icons.people_outline,
        iconSelected: Icons.people,
        builder: (s) => BorrowersScreen(
          onSelectBorrower: (id) => s.setState(() => s._selectedBorrowerId = id),
        ),
      ),
      _NavDestination(
        key: 'loans',
        label: 'Loans',
        iconOutline: Icons.credit_card_outlined,
        iconSelected: Icons.credit_card,
        builder: (s) => LoansScreen(
          onSelectLoan: (id) => s.setState(() => s._selectedLoanId = id),
          initialBorrowerId: s._issueLoanBorrowerId,
        ),
      ),
      _NavDestination(
        key: 'payments',
        label: 'Payments',
        iconOutline: Icons.receipt_long_outlined,
        iconSelected: Icons.receipt_long,
        builder: (s) => PaymentLogScreen(
          onSelectLoan: (id) => s.setState(() => s._selectedLoanId = id),
        ),
      ),
      if (!isSoloMode)
        _NavDestination(
          key: 'users',
          label: 'Users',
          iconOutline: Icons.manage_accounts_outlined,
          iconSelected: Icons.manage_accounts,
          builder: (s) => const UsersScreen(),
        ),
      _NavDestination(
        key: 'settings',
        label: 'Settings',
        iconOutline: Icons.settings_outlined,
        iconSelected: Icons.settings,
        builder: (s) => const SettingsScreen(),
      ),
    ];
  }

  void _navigateToTab(int index) {
    setState(() {
      _currentIndex = index;
      _selectedBorrowerId = null;
      _selectedLoanId = null;
      _issueLoanBorrowerId = null;
    });
  }

  void _navigateToKey(String key, List<_NavDestination> destinations) {
    final idx = destinations.indexWhere((d) => d.key == key);
    if (idx != -1) {
      _navigateToTab(idx);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = Provider.of<AppState>(context);
    final isDesktop = ResponsiveContainer.isDesktop(context);
    final isLargeDesktop = ResponsiveContainer.isLargeDesktop(context);

    final destinations = _getNavDestinations(state.isSoloMode);
    if (_currentIndex >= destinations.length) {
      _currentIndex = 0;
    }

    final activeDest = destinations[_currentIndex];
    final categoryTabName = activeDest.label;

    String title = appTitle;
    if (_selectedLoanId != null) {
      title = 'Loan Details';
    } else if (_selectedBorrowerId != null) {
      title = 'Borrower Profile';
    } else {
      title = categoryTabName;
    }

    Widget content;
    if (_selectedLoanId != null) {
      content = LoanDetailScreen(
        key: ValueKey('loan_$_selectedLoanId'),
        loanId: _selectedLoanId!,
        onBack: () => setState(() => _selectedLoanId = null),
        onSelectBorrower: (id) {
          setState(() {
            _selectedLoanId = null;
            _selectedBorrowerId = id;
          });
        },
      );
    } else if (_selectedBorrowerId != null) {
      content = BorrowerDetailScreen(
        key: ValueKey('borrower_$_selectedBorrowerId'),
        borrowerId: _selectedBorrowerId!,
        onBack: () => setState(() => _selectedBorrowerId = null),
        onSelectLoan: (id) => setState(() => _selectedLoanId = id),
        onCreateLoanForBorrower: (borrowerId) {
          setState(() {
            _selectedBorrowerId = null;
            _issueLoanBorrowerId = borrowerId;
            _navigateToKey('loans', destinations);
          });
        },
      );
    } else {
      content = KeyedSubtree(
        key: ValueKey('tab_${activeDest.key}'),
        child: activeDest.builder(this),
      );
    }

    final animatedContent = AnimatedSwitcher(
      duration: const Duration(milliseconds: 250),
      transitionBuilder: (Widget child, Animation<double> animation) {
        final offsetAnimation = Tween<Offset>(
          begin: const Offset(0.02, 0.0),
          end: Offset.zero,
        ).animate(animation);
        return FadeTransition(
          opacity: animation,
          child: SlideTransition(
            position: offsetAnimation,
            child: child,
          ),
        );
      },
      child: content,
    );

    final desktopHeader = Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border(bottom: BorderSide(color: Colors.grey.withValues(alpha: 0.15))),
      ),
      child: Row(
        children: [
          if (_selectedLoanId != null || _selectedBorrowerId != null) ...[
            IconButton(
              icon: const Icon(Icons.arrow_back),
              tooltip: 'Back',
              onPressed: () {
                setState(() {
                  _selectedLoanId = null;
                  _selectedBorrowerId = null;
                });
              },
            ),
            const SizedBox(width: 8),
            Text(categoryTabName, style: const TextStyle(fontSize: 14, color: Colors.grey)),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 6),
              child: Icon(Icons.chevron_right, size: 16, color: Colors.grey),
            ),
          ],
          Text(
            title,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );

    final bodyWidget = isDesktop
        ? Row(
            children: [
              NavigationRail(
                extended: isLargeDesktop,
                selectedIndex: _currentIndex,
                onDestinationSelected: _navigateToTab,
                labelType: isLargeDesktop ? NavigationRailLabelType.none : NavigationRailLabelType.all,
                indicatorColor: Theme.of(context).colorScheme.primary.withValues(alpha: 0.12),
                leading: Container(
                  padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.primary,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          Icons.account_balance,
                          color: Theme.of(context).colorScheme.onPrimary,
                          size: 20,
                        ),
                      ),
                      if (isLargeDesktop) ...[
                        const SizedBox(width: 10),
                        Text(
                          appTitle,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                      ],
                    ],
                  ),
                ),
                trailing: Expanded(
                  child: Align(
                    alignment: Alignment.bottomCenter,
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 16.0),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (state.currentUser != null) ...[
                            Tooltip(
                              message: '${state.currentUser!.username} (${state.currentUser!.role})',
                              child: Container(
                                padding: EdgeInsets.symmetric(horizontal: isLargeDesktop ? 12 : 8, vertical: 6),
                                margin: const EdgeInsets.symmetric(horizontal: 8),
                                decoration: BoxDecoration(
                                  color: Colors.grey.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.person, size: 16),
                                    if (isLargeDesktop) ...[
                                      const SizedBox(width: 6),
                                      Flexible(
                                        child: Text(
                                          '${state.currentUser!.username} (${state.currentUser!.role})',
                                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(height: 8),
                            IconButton(
                              icon: const Icon(Icons.logout, size: 20),
                              onPressed: state.logout,
                              tooltip: 'Sign Out',
                            ),
                          ],
                          IconButton(
                            icon: Icon(state.isDarkMode ? Icons.wb_sunny : Icons.nightlight_round, size: 20),
                            onPressed: state.toggleTheme,
                            tooltip: 'Toggle Theme',
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                destinations: destinations.map((d) {
                  return NavigationRailDestination(
                    icon: Icon(d.iconOutline),
                    selectedIcon: Icon(d.iconSelected),
                    label: Text(d.label),
                  );
                }).toList(),
              ),
              const VerticalDivider(thickness: 1, width: 1),
              Expanded(
                child: Column(
                  children: [
                    desktopHeader,
                    Expanded(child: animatedContent),
                  ],
                ),
              ),
            ],
          )
        : animatedContent;

    return Scaffold(
      appBar: isDesktop
          ? null
          : AppBar(
              leading: (_selectedLoanId != null || _selectedBorrowerId != null)
                  ? IconButton(
                      icon: const Icon(Icons.arrow_back),
                      tooltip: 'Back',
                      onPressed: () {
                        setState(() {
                          _selectedLoanId = null;
                          _selectedBorrowerId = null;
                        });
                      },
                    )
                  : null,
              title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
              actions: [
                if (state.currentUser != null) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.grey.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.person, size: 14),
                        const SizedBox(width: 4),
                        Text(
                          '${state.currentUser!.username} (${state.currentUser!.role})',
                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.logout, size: 20),
                    onPressed: state.logout,
                    tooltip: 'Sign Out',
                  ),
                ],
                IconButton(
                  icon: Icon(state.isDarkMode ? Icons.wb_sunny : Icons.nightlight_round),
                  onPressed: state.toggleTheme,
                  tooltip: 'Toggle Theme',
                ),
              ],
            ),
      body: SafeArea(child: bodyWidget),
      bottomNavigationBar: isDesktop
          ? null
          : BottomNavigationBar(
              currentIndex: _currentIndex,
              onTap: _navigateToTab,
              type: BottomNavigationBarType.fixed,
              items: destinations.map((d) {
                return BottomNavigationBarItem(
                  icon: Icon(d.iconOutline),
                  activeIcon: Icon(d.iconSelected),
                  label: d.label,
                );
              }).toList(),
            ),
    );
  }
}
