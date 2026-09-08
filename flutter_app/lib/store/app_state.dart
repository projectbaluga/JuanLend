import 'dart:convert';
import 'package:flutter/material.dart';
import '../models/borrower.dart';
import '../models/loan.dart';
import '../models/payment.dart';
import '../models/user.dart';
import '../utils/license_verifier.dart';
import '../utils/loan_utils.dart';
import '../utils/machine_id.dart';
import 'offline_store.dart';

class AppState extends ChangeNotifier {
  static const Map<String, List<String>> _allowedTransitions = {
    'pending': ['active', 'rejected'],
    'active': ['completed', 'defaulted'],
    'completed': [],
    'defaulted': [],
    'rejected': [],
  };

  static const String _envAppName = String.fromEnvironment('APP_NAME', defaultValue: '');
  static const String _envAppDescription = String.fromEnvironment('APP_DESCRIPTION', defaultValue: '');

  static const int _borrowerLimit = 5;

  final OfflineStore store;

  User? _currentUser;
  late String _currencyCode;
  late String _dateFormat;
  late String _businessName;
  late int _defaultTermPeriods;
  late double _defaultInterestRate;
  late String _defaultRepaymentFrequency;
  late String _defaultInterestMethod;
  late String _defaultPenaltyType;
  late double _defaultPenaltyValue;
  late ThemeMode _themeMode;
  bool _featuresUnlocked = false;
  String _machineId = '';
  late String _activePublicKeyHex;

  bool _isValidHex64(String str) {
    final clean = str.trim();
    return clean.length == 64 && RegExp(r'^[0-9a-fA-F]{64}$').hasMatch(clean);
  }

  AppState(this.store) {
    _loadSyncSettings();
    _initAndLoadSettings();
  }

  void _loadSyncSettings() {
    _currencyCode = store.getSetting('currencyCode', 'PHP');
    _dateFormat = store.getSetting('dateFormat', 'MMM d, yyyy');
    final defaultBusinessName = _envAppName.trim().isNotEmpty ? _envAppName.trim() : 'MicroLend Suite';
    _businessName = store.getSetting('businessName', defaultBusinessName);
    final termStr = store.getSetting('defaultTermPeriods', store.getSetting('defaultTermMonths', '6'));
    _defaultTermPeriods = int.tryParse(termStr) ?? 6;
    _defaultInterestRate = double.tryParse(store.getSetting('defaultInterestRate', '12.0')) ?? 12.0;
    _defaultRepaymentFrequency = store.getSetting('defaultRepaymentFrequency', 'monthly');
    _defaultInterestMethod = store.getSetting('defaultInterestMethod', 'reducing');
    _defaultPenaltyType = store.getSetting('defaultPenaltyType', 'none');
    _defaultPenaltyValue = double.tryParse(store.getSetting('defaultPenaltyValue', '0.0')) ?? 0.0;

    LoanUtils.defaultCurrencyCode = _currencyCode;
    LoanUtils.defaultDateFormat = _dateFormat;

    final savedTheme = store.getSetting('themeMode', 'dark');
    _themeMode = savedTheme == 'light' ? ThemeMode.light : ThemeMode.dark;

    final storedKey = store.getSetting('activePublicKeyHex', LicenseVerifier.masterPublicKeyHex);
    _activePublicKeyHex = _isValidHex64(storedKey) ? storedKey.trim() : LicenseVerifier.masterPublicKeyHex;

    final sessionUserId = store.getSetting('session_user_id', '');
    if (sessionUserId.isNotEmpty) {
      final userMaps = store.getCollection('users');
      final match = userMaps.where((m) => m['id'] == sessionUserId).toList();
      if (match.isNotEmpty) {
        _currentUser = User.fromMap(match.first);
      }
    }
  }

  Future<void> _initAndLoadSettings() async {
    _machineId = await MachineIdUtils.getMachineId();
    await _loadSettings();
    notifyListeners();
  }

  Future<void> reload() async {
    try {
      await store.reload();
    } catch (_) {}
    _machineId = await MachineIdUtils.getMachineId();
    await _loadSettings();
    notifyListeners();
  }

  Future<void> _loadSettings() async {
    _loadSyncSettings();
    _currencyCode = store.getSetting('currencyCode', 'PHP');
    _dateFormat = store.getSetting('dateFormat', 'MMM d, yyyy');
    final defaultBusinessName = _envAppName.trim().isNotEmpty ? _envAppName.trim() : 'MicroLend Suite';
    _businessName = store.getSetting('businessName', defaultBusinessName);
    final termStr = store.getSetting('defaultTermPeriods', store.getSetting('defaultTermMonths', '6'));
    _defaultTermPeriods = int.tryParse(termStr) ?? 6;
    _defaultInterestRate = double.tryParse(store.getSetting('defaultInterestRate', '12.0')) ?? 12.0;
    _defaultRepaymentFrequency = store.getSetting('defaultRepaymentFrequency', 'monthly');
    _defaultInterestMethod = store.getSetting('defaultInterestMethod', 'reducing');
    _defaultPenaltyType = store.getSetting('defaultPenaltyType', 'none');
    _defaultPenaltyValue = double.tryParse(store.getSetting('defaultPenaltyValue', '0.0')) ?? 0.0;

    LoanUtils.defaultCurrencyCode = _currencyCode;
    LoanUtils.defaultDateFormat = _dateFormat;

    final savedTheme = store.getSetting('themeMode', 'dark');
    _themeMode = savedTheme == 'light' ? ThemeMode.light : ThemeMode.dark;

    final storedKey = store.getSetting('activePublicKeyHex', LicenseVerifier.masterPublicKeyHex);
    _activePublicKeyHex = _isValidHex64(storedKey) ? storedKey.trim() : LicenseVerifier.masterPublicKeyHex;

    final storedLicenseKey = store.getSetting('licenseKey', '');
    if (storedLicenseKey.isNotEmpty && _machineId.isNotEmpty) {
      _featuresUnlocked = await LicenseVerifier.verifyLicenseKey(
        storedLicenseKey,
        _machineId,
        overridePublicKeyHex: _activePublicKeyHex,
      );
    } else {
      _featuresUnlocked = false;
    }

    final sessionUserId = store.getSetting('session_user_id', '');
    if (sessionUserId.isNotEmpty) {
      final userMaps = store.getCollection('users');
      final match = userMaps.where((m) => m['id'] == sessionUserId).toList();
      if (match.isNotEmpty) {
        _currentUser = User.fromMap(match.first);
      }
    }
  }

  User? get currentUser => _currentUser;
  bool get isLoggedIn => _currentUser != null;

  Future<bool> login(String username, String password) async {
    final userMaps = store.getCollection('users');
    final users = userMaps.map((e) => User.fromMap(e)).toList();
    final match = users.where((u) => u.username.toLowerCase() == username.trim().toLowerCase()).toList();
    if (match.isEmpty) return false;

    final user = match.first;
    if (user.verifyPassword(password.trim())) {
      _currentUser = user;
      await store.setSetting('session_user_id', user.id);
      notifyListeners();
      return true;
    }
    return false;
  }

  Future<void> logout() async {
    _currentUser = null;
    await store.setSetting('session_user_id', '');
    notifyListeners();
  }

  String get appName => _envAppName.trim().isNotEmpty ? _envAppName.trim() : _businessName;
  String get appDescription {
    if (_envAppDescription.trim().isNotEmpty) {
      return _envAppDescription.trim();
    }
    return 'Local-first micro-lending management software designed for solo operators. '
        'Includes automated amortization scheduling, borrower credit risk scoring, payment tracking, and offline data persistence.';
  }
  String get currencyCode => _currencyCode;
  String get dateFormat => _dateFormat;
  String get businessName => _businessName;
  int get defaultTermPeriods => _defaultTermPeriods;
  double get defaultInterestRate => _defaultInterestRate;
  String get defaultRepaymentFrequency => _defaultRepaymentFrequency;
  String get defaultInterestMethod => _defaultInterestMethod;
  String get defaultPenaltyType => _defaultPenaltyType;
  double get defaultPenaltyValue => _defaultPenaltyValue;
  ThemeMode get themeMode => _themeMode;
  bool get isDarkMode => _themeMode == ThemeMode.dark;

  bool get isFeaturesUnlocked => _featuresUnlocked;
  String get machineId => _machineId;
  String get activePublicKeyHex => _activePublicKeyHex;

  Future<void> setActivePublicKey(String hex) async {
    final cleanHex = hex.trim();
    if (!_isValidHex64(cleanHex)) {
      throw ArgumentError('Invalid public key — must be 64 hex characters.');
    }

    _activePublicKeyHex = cleanHex;
    await store.setSetting('activePublicKeyHex', cleanHex);

    final storedLicenseKey = store.getSetting('licenseKey', '');
    if (storedLicenseKey.isNotEmpty && _machineId.isNotEmpty) {
      _featuresUnlocked = await LicenseVerifier.verifyLicenseKey(
        storedLicenseKey,
        _machineId,
        overridePublicKeyHex: _activePublicKeyHex,
      );
    } else {
      _featuresUnlocked = false;
    }

    notifyListeners();
  }

  Future<bool> unlockFeatures(String licenseKey, {String? overridePublicKeyHex}) async {
    final key = licenseKey.trim();
    if (key.isEmpty || _machineId.isEmpty) return false;

    final pubHex = overridePublicKeyHex ?? _activePublicKeyHex;
    final isValid = await LicenseVerifier.verifyLicenseKey(key, _machineId, overridePublicKeyHex: pubHex);
    if (isValid) {
      _featuresUnlocked = true;
      await store.setSetting('licenseKey', key);
      notifyListeners();
      return true;
    }
    return false;
  }

  Future<void> lockFeatures() async {
    _featuresUnlocked = false;
    await store.setSetting('licenseKey', '');
    notifyListeners();
  }

  Future<void> setBusinessName(String name) async {
    _businessName = name;
    await store.setSetting('businessName', name);
    notifyListeners();
  }

  Future<void> setCurrencyCode(String code) async {
    _currencyCode = code;
    LoanUtils.defaultCurrencyCode = code;
    await store.setSetting('currencyCode', code);
    notifyListeners();
  }

  Future<void> setDateFormat(String format) async {
    _dateFormat = format;
    LoanUtils.defaultDateFormat = format;
    await store.setSetting('dateFormat', format);
    notifyListeners();
  }

  Future<void> setDefaultTermPeriods(int periods) async {
    _defaultTermPeriods = periods;
    await store.setSetting('defaultTermPeriods', periods.toString());
    notifyListeners();
  }

  Future<void> setDefaultInterestRate(double rate) async {
    _defaultInterestRate = rate;
    await store.setSetting('defaultInterestRate', rate.toString());
    notifyListeners();
  }

  Future<void> setDefaultRepaymentFrequency(String freq) async {
    _defaultRepaymentFrequency = freq;
    await store.setSetting('defaultRepaymentFrequency', freq);
    notifyListeners();
  }

  Future<void> setDefaultInterestMethod(String method) async {
    _defaultInterestMethod = method;
    await store.setSetting('defaultInterestMethod', method);
    notifyListeners();
  }

  Future<void> setDefaultPenaltyType(String type) async {
    _defaultPenaltyType = type;
    await store.setSetting('defaultPenaltyType', type);
    notifyListeners();
  }

  Future<void> setDefaultPenaltyValue(double value) async {
    _defaultPenaltyValue = value;
    await store.setSetting('defaultPenaltyValue', value.toString());
    notifyListeners();
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    _themeMode = mode;
    await store.setSetting('themeMode', mode == ThemeMode.light ? 'light' : 'dark');
    notifyListeners();
  }

  void toggleTheme() {
    setThemeMode(isDarkMode ? ThemeMode.light : ThemeMode.dark);
  }

  List<User> get users {
    return store
        .getCollection('users')
        .map((e) => User.fromMap(e))
        .toList();
  }

  bool get isSoloMode => users.length <= 1;

  Future<void> changePassword(String userId, String oldPassword, String newPassword) async {
    final userMaps = store.getCollection('users');
    final match = userMaps.where((m) => m['id'] == userId).toList();
    if (match.isEmpty) {
      throw ArgumentError('User not found.');
    }

    final targetUser = User.fromMap(match.first);
    if (!targetUser.verifyPassword(oldPassword.trim())) {
      throw ArgumentError('Incorrect current password.');
    }

    final newSalt = User.generateSalt();
    final newHash = User.hashPassword(newPassword.trim(), newSalt);

    await store.updateItem('users', userId, {
      'password_hash': newHash,
      'salt': newSalt,
      'must_change_password': false,
    });

    if (_currentUser?.id == userId) {
      _currentUser = _currentUser!.copyWith(
        passwordHash: newHash,
        salt: newSalt,
        mustChangePassword: false,
      );
    }
    notifyListeners();
  }

  Future<void> createUser(String username, String password, String role) async {
    if (_currentUser == null || _currentUser!.role != 'approver') {
      throw StateError('Unauthorized: Only approvers can create users.');
    }

    final uName = username.trim();
    if (uName.isEmpty || password.trim().isEmpty) {
      throw ArgumentError('Username and password cannot be empty.');
    }

    if (users.any((u) => u.username.toLowerCase() == uName.toLowerCase())) {
      throw ArgumentError('Username already exists.');
    }

    final salt = User.generateSalt();
    final passwordHash = User.hashPassword(password.trim(), salt);

    final newUser = User(
      id: 'usr_${DateTime.now().millisecondsSinceEpoch}',
      username: uName,
      passwordHash: passwordHash,
      salt: salt,
      role: role,
      mustChangePassword: false,
    );

    await store.addItem('users', newUser.toMap());
    notifyListeners();
  }

  Future<void> updateUserRole(String userId, String newRole) async {
    if (_currentUser == null || _currentUser!.role != 'approver') {
      throw StateError('Unauthorized: Only approvers can update user roles.');
    }

    await store.updateItem('users', userId, {'role': newRole});

    if (_currentUser?.id == userId) {
      _currentUser = _currentUser!.copyWith(role: newRole);
    }
    notifyListeners();
  }

  Future<void> deleteUser(String userId) async {
    if (_currentUser == null || _currentUser!.role != 'approver') {
      throw StateError('Unauthorized: Only approvers can delete users.');
    }

    if (_currentUser!.id == userId) {
      throw ArgumentError('Cannot delete your own account.');
    }

    await store.deleteItem('users', userId);
    notifyListeners();
  }

  List<Borrower> get borrowers {
    return store
        .getCollection('borrowers')
        .map((e) => Borrower.fromMap(e))
        .toList();
  }

  List<Loan> get loans {
    return store
        .getCollection('loans')
        .map((e) => Loan.fromMap(e))
        .toList();
  }

  String exportDataJson() {
    final data = {
      'borrowers': store.getCollection('borrowers'),
      'loans': store.getCollection('loans'),
      'exportedAt': DateTime.now().toIso8601String(),
    };
    return const JsonEncoder.withIndent('  ').convert(data);
  }

  Future<void> importDataJson(String jsonStr) async {
    final decoded = jsonDecode(jsonStr);
    if (decoded is! Map<String, dynamic> ||
        !decoded.containsKey('borrowers') ||
        !decoded.containsKey('loans') ||
        decoded['borrowers'] is! List ||
        decoded['loans'] is! List) {
      throw const FormatException('Invalid backup file format: missing borrowers or loans data.');
    }

    final List borrowersList = decoded['borrowers'];
    final List loansList = decoded['loans'];

    final borrowers = borrowersList.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    final loans = loansList.map((e) => Map<String, dynamic>.from(e as Map)).toList();

    await store.saveCollection('borrowers', borrowers);
    await store.saveCollection('loans', loans);
    notifyListeners();
  }

  Future<void> clearAllData() async {
    await store.clearAllData();
    notifyListeners();
  }

  Future<void> restoreSampleData() async {
    await store.seedInitialData(force: true);
    notifyListeners();
  }

  Future<void> addBorrower(Borrower borrower) async {
    if (!_featuresUnlocked && borrowers.length >= _borrowerLimit) {
      throw StateError('Borrower limit reached (5). Unlock full features in Settings to add more.');
    }
    await store.addItem('borrowers', borrower.toMap());
    notifyListeners();
  }

  Future<void> updateBorrower(String id, Map<String, dynamic> updates) async {
    await store.updateItem('borrowers', id, updates);
    notifyListeners();
  }

  Future<void> deleteBorrower(String id) async {
    await store.deleteItem('borrowers', id);
    notifyListeners();
  }

  Future<void> addLoan(Loan loan) async {
    if (_currentUser == null || (!isSoloMode && _currentUser!.role == 'viewer')) {
      throw StateError('Unauthorized: Role "${_currentUser?.role ?? "unauthenticated"}" cannot create loans.');
    }

    final createdBy = loan.createdBy ?? _currentUser!.id;

    if (isSoloMode) {
      final disbursementDate = loan.disbursementDate.isNotEmpty
          ? loan.disbursementDate
          : DateTime.now().toIso8601String().split('T')[0];

      final schedule = loan.schedule.isNotEmpty
          ? loan.schedule
          : LoanUtils.generateSchedule(
              loan.principal,
              loan.interestRate,
              loan.termCount,
              disbursementDate,
              repaymentFrequency: loan.repaymentFrequency,
              interestMethod: loan.interestMethod,
            );

      final soloLoan = loan.copyWith(
        status: 'active',
        disbursementDate: disbursementDate,
        schedule: schedule,
        createdBy: createdBy,
      );
      await store.addItem('loans', soloLoan.toMap());
    } else {
      final loanToSave = loan.copyWith(createdBy: createdBy);
      await store.addItem('loans', loanToSave.toMap());
    }
    notifyListeners();
  }

  Future<void> updateLoan(String id, Map<String, dynamic> updates) async {
    await store.updateItem('loans', id, updates);
    notifyListeners();
  }

  Future<void> approveLoan(String loanId, {bool overrideHighRisk = false}) async {
    if (_currentUser == null || (!isSoloMode && _currentUser!.role != 'approver')) {
      throw StateError('Unauthorized: Only approvers can approve loans.');
    }

    final loan = loans.firstWhere((l) => l.id == loanId);
    if (loan.status != 'pending') {
      throw ArgumentError('Cannot approve loan with status "${loan.status}". Only pending loans can be approved.');
    }

    if (!isSoloMode && loan.createdBy != null && loan.createdBy == _currentUser!.id) {
      throw StateError('Unauthorized: Separation of duties violation. Loan creator cannot approve their own loan.');
    }

    if (loan.creditAssessment?.riskRating == 'high' && !overrideHighRisk) {
      throw StateError('HighRiskLoan: Borrower is rated HIGH RISK (DTI ${loan.creditAssessment?.dtiPct ?? 0}%). Explicit override required to approve.');
    }

    final disbursementDate = loan.disbursementDate.isNotEmpty
        ? loan.disbursementDate
        : DateTime.now().toIso8601String().split('T')[0];

    final updatedSchedule = loan.schedule.isNotEmpty
        ? loan.schedule
        : LoanUtils.generateSchedule(
            loan.principal,
            loan.interestRate,
            loan.termCount,
            disbursementDate,
            repaymentFrequency: loan.repaymentFrequency,
            interestMethod: loan.interestMethod,
          );

    await store.updateItem('loans', loanId, {
      'status': 'active',
      'disbursement_date': disbursementDate,
      'schedule': updatedSchedule.map((e) => e.toMap()).toList(),
    });
    notifyListeners();
  }

  Future<void> markLoanStatus(String loanId, String status) async {
    if (_currentUser == null || (!isSoloMode && _currentUser!.role != 'approver')) {
      throw StateError('Unauthorized: Only approvers can change loan status.');
    }

    final loan = loans.firstWhere((l) => l.id == loanId);
    final allowed = _allowedTransitions[loan.status] ?? [];
    if (!allowed.contains(status)) {
      throw ArgumentError('Cannot transition loan status from "${loan.status}" to "$status".');
    }
    await store.updateItem('loans', loanId, {'status': status});
    notifyListeners();
  }

  Future<void> recordPayment(String loanId, Payment payment) async {
    if (_currentUser == null || (_currentUser!.role != 'officer' && _currentUser!.role != 'approver')) {
      throw StateError('Unauthorized: Role "${_currentUser?.role ?? "unauthenticated"}" cannot record payments.');
    }

    final existingLoan = loans.firstWhere((l) => l.id == loanId);
    final statsBefore = LoanUtils.getLoanStats(existingLoan);
    final accruedPenaltyNow = statsBefore.penaltyAmount;
    final totalRequired = LoanUtils.round2(statsBefore.totalScheduled + accruedPenaltyNow);

    if (accruedPenaltyNow > existingLoan.accruedPenalty) {
      await store.updateItem('loans', loanId, {'accrued_penalty': accruedPenaltyNow});
    }

    final updatedLoanMap = await store.appendToItemArray(
      'loans',
      loanId,
      'payments',
      payment.toMap(),
    );

    if (updatedLoanMap == null) return;

    final updatedLoan = Loan.fromMap(updatedLoanMap);
    final statsAfter = LoanUtils.getLoanStats(updatedLoan);

    if (statsAfter.totalPaid >= totalRequired && existingLoan.status == 'active') {
      await store.updateItem('loans', loanId, {'status': 'completed'});
    }

    notifyListeners();
  }

  Future<void> rolloverLoan(
    String loanId, {
    required int extensionPeriods,
    double extensionFeeValue = 0.0,
    String extensionFeeType = 'fixed',
  }) async {
    if (_currentUser == null || (!isSoloMode && _currentUser!.role != 'officer' && _currentUser!.role != 'approver')) {
      throw StateError('Unauthorized: Role "${_currentUser?.role ?? "unauthenticated"}" cannot perform loan rollover.');
    }

    final loan = loans.firstWhere((l) => l.id == loanId);
    if (loan.status != 'active') {
      throw ArgumentError('Cannot rollover loan with status "${loan.status}". Only active loans can be rolled over.');
    }

    if (extensionPeriods <= 0) {
      throw ArgumentError('Extension periods must be greater than 0.');
    }

    final stats = LoanUtils.getLoanStats(loan);
    final remainingBalance = stats.outstandingBalance > 0 ? stats.outstandingBalance : loan.principal;

    final newTermCount = loan.termCount + extensionPeriods;
    final extensionFee = LoanUtils.calculateFeeAmount(
      remainingBalance,
      extensionFeeType,
      extensionFeeValue,
      termCount: extensionPeriods,
      frequency: loan.repaymentFrequency,
    );

    final newServiceFeeValue = loan.serviceFeeValue + extensionFee;

    final updatedSchedule = LoanUtils.generateSchedule(
      remainingBalance,
      loan.interestRate,
      extensionPeriods,
      DateTime.now().toIso8601String().split('T')[0],
      repaymentFrequency: loan.repaymentFrequency,
      interestMethod: loan.interestMethod,
    );

    // Combine original remaining schedule / adjustments with new schedule
    final newScheduleList = [
      ...loan.schedule,
      ...updatedSchedule.map((inst) => inst.copyWith(
            installmentNo: loan.schedule.length + inst.installmentNo,
          )),
    ];

    await store.updateItem('loans', loanId, {
      'term_count': newTermCount,
      'term_months': loan.repaymentFrequency == 'monthly' ? newTermCount : loan.termMonths,
      'service_fee_type': 'fixed',
      'service_fee_value': newServiceFeeValue,
      'schedule': newScheduleList.map((e) => e.toMap()).toList(),
      'updatedAt': DateTime.now().toIso8601String(),
    });

    notifyListeners();
  }

  Future<void> topUpLoan(
    String loanId, {
    required double additionalPrincipal,
    String? newDisbursementDate,
  }) async {
    if (_currentUser == null || (!isSoloMode && _currentUser!.role != 'officer' && _currentUser!.role != 'approver')) {
      throw StateError('Unauthorized: Role "${_currentUser?.role ?? "unauthenticated"}" cannot top up loans.');
    }

    final loan = loans.firstWhere((l) => l.id == loanId);
    if (loan.status != 'active') {
      throw ArgumentError('Cannot top up loan with status "${loan.status}". Only active loans can be topped up.');
    }

    if (additionalPrincipal <= 0) {
      throw ArgumentError('Additional principal must be greater than 0.');
    }

    // Verify credit limit based on borrower monthly income assessment if available
    final borrowerMatch = borrowers.where((b) => b.id == loan.borrowerId).toList();
    if (borrowerMatch.isNotEmpty) {
      final borrower = borrowerMatch.first;
      final assessment = LoanUtils.assessBorrower(borrower, loans);

      // Max total outstanding debt allowed = 5x monthly income (or 50,000 if no income specified)
      final creditLimit = borrower.monthlyIncome > 0 ? (borrower.monthlyIncome * 5.0) : 50000.0;
      if ((loan.principal + additionalPrincipal) > creditLimit) {
        throw ArgumentError('Top-up exceeds borrower credit limit (${LoanUtils.formatCurrency(creditLimit, currencyCode)}). Current assessment: DTI ${assessment.dtiPct}%.');
      }
    }

    final newPrincipal = LoanUtils.round2(loan.principal + additionalPrincipal);
    if (newPrincipal > 10000000) {
      throw ArgumentError('New total principal exceeds maximum allowed limit (₱10,000,000).');
    }

    final disbDate = (newDisbursementDate != null && newDisbursementDate.isNotEmpty)
        ? newDisbursementDate
        : (loan.disbursementDate.isNotEmpty ? loan.disbursementDate : DateTime.now().toIso8601String().split('T')[0]);

    final newSchedule = LoanUtils.generateSchedule(
      newPrincipal,
      loan.interestRate,
      loan.termCount,
      disbDate,
      repaymentFrequency: loan.repaymentFrequency,
      interestMethod: loan.interestMethod,
    );

    await store.updateItem('loans', loanId, {
      'principal': newPrincipal,
      'schedule': newSchedule.map((e) => e.toMap()).toList(),
      'updatedAt': DateTime.now().toIso8601String(),
    });

    notifyListeners();
  }
}
