import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'package:encrypt/encrypt.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/borrower.dart';
import '../models/loan.dart';
import '../models/payment.dart';
import '../models/user.dart';
import '../utils/loan_utils.dart';

class OfflineStore {
  Future<void> _lock = Future.value();

  Future<T> _synchronized<T>(Future<T> Function() operation) async {
    final previous = _lock;
    final completer = Completer<void>();
    _lock = completer.future;
    await previous;
    try {
      return await operation();
    } finally {
      completer.complete();
    }
  }
  static const String _storagePrefix = 'microlend_';
  static const String _settingPrefix = '${_storagePrefix}setting_';
  static const String _keyStorageName = 'microlend_db_encryption_key';

  final SharedPreferences _prefs;
  final List<int> _encryptionKeyBytes;

  OfflineStore(this._prefs, this._encryptionKeyBytes);

  static Future<OfflineStore> init({FlutterSecureStorage? secureStorage}) async {
    final prefs = await SharedPreferences.getInstance();
    final storage = secureStorage ?? const FlutterSecureStorage();

    List<int>? keyBytes;
    try {
      final existingBase64 = await storage.read(key: _keyStorageName);
      if (existingBase64 != null && existingBase64.isNotEmpty) {
        keyBytes = base64Url.decode(existingBase64);
      } else {
        final rand = Random.secure();
        keyBytes = List<int>.generate(32, (_) => rand.nextInt(256));
        await storage.write(key: _keyStorageName, value: base64Url.encode(keyBytes));
      }
    } catch (_) {
      final fallbackKeyStr = prefs.getString('${_storagePrefix}_fallback_enc_key');
      if (fallbackKeyStr != null && fallbackKeyStr.isNotEmpty) {
        keyBytes = base64Url.decode(fallbackKeyStr);
      } else {
        final rand = Random.secure();
        keyBytes = List<int>.generate(32, (_) => rand.nextInt(256));
        await prefs.setString('${_storagePrefix}_fallback_enc_key', base64Url.encode(keyBytes));
      }
    }

    final store = OfflineStore(prefs, keyBytes);
    await store.migratePlaintextData();
    await store.seedInitialData();
    return store;
  }

  String _encryptValue(String plaintext) {
    if (plaintext.isEmpty) return '';
    final iv = IV.fromSecureRandom(12);
    final encrypter = Encrypter(AES(Key(Uint8List.fromList(_encryptionKeyBytes)), mode: AESMode.gcm));
    final encrypted = encrypter.encrypt(plaintext, iv: iv);
    return 'ENC:${iv.base64}:${encrypted.base64}';
  }

  String _decryptValue(String raw) {
    if (raw.isEmpty || !raw.startsWith('ENC:')) {
      return raw;
    }
    final parts = raw.split(':');
    if (parts.length != 3) return raw;
    try {
      final iv = IV.fromBase64(parts[1]);
      final encrypted = Encrypted.fromBase64(parts[2]);
      final encrypter = Encrypter(AES(Key(Uint8List.fromList(_encryptionKeyBytes)), mode: AESMode.gcm));
      return encrypter.decrypt(encrypted, iv: iv);
    } catch (_) {
      return raw;
    }
  }

  Future<void> migratePlaintextData() async {
    final keys = _prefs.getKeys();
    for (final key in keys) {
      if (key.startsWith(_storagePrefix) && !key.endsWith('_fallback_enc_key')) {
        final raw = _prefs.getString(key);
        if (raw != null && raw.isNotEmpty && !raw.startsWith('ENC:')) {
          final encrypted = _encryptValue(raw);
          await _prefs.setString(key, encrypted);
        }
      }
    }
  }

  Future<void> reload() async {
    try {
      await _prefs.reload();
    } catch (_) {}
  }

  String getSetting(String key, String defaultValue) {
    final raw = _prefs.getString('$_settingPrefix$key');
    if (raw == null || raw.isEmpty) return defaultValue;
    return _decryptValue(raw);
  }

  Future<void> setSetting(String key, String value) async {
    await _synchronized(() async {
      final encrypted = _encryptValue(value);
      await _prefs.setString('$_settingPrefix$key', encrypted);
    });
  }

  List<Map<String, dynamic>> getCollection(String collectionName) {
    final key = '$_storagePrefix$collectionName';
    final raw = _prefs.getString(key);
    if (raw == null || raw.isEmpty) return [];
    try {
      final decrypted = _decryptValue(raw);
      final List decoded = jsonDecode(decrypted);
      return decoded.map((e) => Map<String, dynamic>.from(e)).toList();
    } catch (e) {
      return [];
    }
  }

  Future<void> saveCollection(String collectionName, List<Map<String, dynamic>> items) async {
    await _synchronized(() async {
      final key = '$_storagePrefix$collectionName';
      final encrypted = _encryptValue(jsonEncode(items));
      await _prefs.setString(key, encrypted);
    });
  }

  Future<Map<String, dynamic>> addItem(String collectionName, Map<String, dynamic> item) async {
    return await _synchronized(() async {
      final key = '$_storagePrefix$collectionName';
      final raw = _prefs.getString(key);
      List<Map<String, dynamic>> collection = [];
      if (raw != null && raw.isNotEmpty) {
        try {
          final decrypted = _decryptValue(raw);
          final List decoded = jsonDecode(decrypted);
          collection = decoded.map((e) => Map<String, dynamic>.from(e)).toList();
        } catch (_) {}
      }

      final newItem = {
        'id': item['id'] ?? '${collectionName.substring(0, 3)}_${DateTime.now().millisecondsSinceEpoch}',
        'createdAt': DateTime.now().toIso8601String(),
        ...item,
      };

      final updated = [newItem, ...collection];
      final encrypted = _encryptValue(jsonEncode(updated));
      await _prefs.setString(key, encrypted);
      return newItem;
    });
  }

  Future<Map<String, dynamic>?> updateItem(String collectionName, String id, Map<String, dynamic> updates) async {
    return await _synchronized(() async {
      final key = '$_storagePrefix$collectionName';
      final raw = _prefs.getString(key);
      List<Map<String, dynamic>> collection = [];
      if (raw != null && raw.isNotEmpty) {
        try {
          final decrypted = _decryptValue(raw);
          final List decoded = jsonDecode(decrypted);
          collection = decoded.map((e) => Map<String, dynamic>.from(e)).toList();
        } catch (_) {}
      }

      Map<String, dynamic>? updatedItem;
      final updated = collection.map((item) {
        if (item['id'] == id) {
          updatedItem = {
            ...item,
            ...updates,
            'updatedAt': DateTime.now().toIso8601String(),
          };
          return updatedItem!;
        }
        return item;
      }).toList();

      final encrypted = _encryptValue(jsonEncode(updated));
      await _prefs.setString(key, encrypted);
      return updatedItem;
    });
  }

  Future<void> deleteItem(String collectionName, String id) async {
    await _synchronized(() async {
      final key = '$_storagePrefix$collectionName';
      final raw = _prefs.getString(key);
      List<Map<String, dynamic>> collection = [];
      if (raw != null && raw.isNotEmpty) {
        try {
          final decrypted = _decryptValue(raw);
          final List decoded = jsonDecode(decrypted);
          collection = decoded.map((e) => Map<String, dynamic>.from(e)).toList();
        } catch (_) {}
      }
      final updated = collection.where((item) => item['id'] != id).toList();
      final encrypted = _encryptValue(jsonEncode(updated));
      await _prefs.setString(key, encrypted);
    });
  }

  Future<Map<String, dynamic>?> appendToItemArray(
    String collectionName,
    String id,
    String arrayField,
    Map<String, dynamic> element, {
    String idField = 'id',
  }) async {
    return await _synchronized(() async {
      final key = '$_storagePrefix$collectionName';
      final raw = _prefs.getString(key);
      List<Map<String, dynamic>> collection = [];
      if (raw != null && raw.isNotEmpty) {
        try {
          final decrypted = _decryptValue(raw);
          final List decoded = jsonDecode(decrypted);
          collection = decoded.map((e) => Map<String, dynamic>.from(e)).toList();
        } catch (_) {}
      }

      Map<String, dynamic>? updatedItem;
      final updated = collection.map((item) {
        if (item['id'] == id) {
          final existingArrayRaw = item[arrayField] is List ? List.from(item[arrayField]) : [];
          final existingArray = existingArrayRaw.map((e) => Map<String, dynamic>.from(e as Map)).toList();

          final elementId = element[idField];
          final exists = elementId != null && existingArray.any((e) => e[idField] == elementId);

          if (!exists) {
            existingArray.add(element);
          }

          updatedItem = {
            ...item,
            arrayField: existingArray,
            'updatedAt': DateTime.now().toIso8601String(),
          };
          return updatedItem!;
        }
        return item;
      }).toList();

      final encrypted = _encryptValue(jsonEncode(updated));
      await _prefs.setString(key, encrypted);
      return updatedItem;
    });
  }

  Future<void> clearAllData() async {
    await saveCollection('borrowers', []);
    await saveCollection('loans', []);
    await saveCollection('users', []);
  }

  Future<void> seedInitialData({bool force = false}) async {
    final existingBorrowers = getCollection('borrowers');
    final existingLoans = getCollection('loans');
    final existingUsers = getCollection('users');

    if (force || existingUsers.isEmpty) {
      final adminSalt = User.generateSalt();
      final defaultAdmin = User(
        id: 'usr_admin',
        username: 'admin',
        passwordHash: User.hashPassword('admin123', adminSalt),
        salt: adminSalt,
        role: 'approver',
        mustChangePassword: true,
      );
      await saveCollection('users', [defaultAdmin.toMap()]);
    }

    if (!force && (existingBorrowers.isNotEmpty || existingLoans.isNotEmpty)) {
      return;
    }

    if (force) {
      await clearAllData();
    }

    final today = DateTime.now();

    String monthsAgo(int m) {
      final d = DateTime(today.year, today.month - m, today.day);
      return DateFormat('yyyy-MM-dd').format(d);
    }

    final sampleBorrowers = [
      Borrower(
        id: 'bor_elena_01',
        fullName: 'Elena Rostova',
        email: 'elena.rostova@example.com',
        phone: '+1 (555) 234-5678',
        address: '742 Evergreen Terrace, Springfield, IL',
        idNumber: 'ID-8839201',
        employment: 'Senior Software Engineer at TechCorp',
        monthlyIncome: 6800.0,
        creditScore: 82,
        riskRating: 'low',
        notes: 'Reliable client, always pays on or ahead of time. High income-to-debt ratio.',
        createdAt: monthsAgo(6),
      ),
      Borrower(
        id: 'bor_marcus_02',
        fullName: 'Marcus Vance',
        email: 'm.vance@example.com',
        phone: '+1 (555) 876-5432',
        address: '1048 Ocean Avenue, Santa Monica, CA',
        idNumber: 'ID-4421098',
        employment: 'Retail Store Manager at Urban Outfitters',
        monthlyIncome: 3900.0,
        creditScore: 62,
        riskRating: 'medium',
        notes: 'Seasonal store sales fluctuations. Keeps good communication.',
        createdAt: monthsAgo(4),
      ),
      Borrower(
        id: 'bor_aisha_03',
        fullName: 'Aisha Patel',
        email: 'aisha.design@example.com',
        phone: '+1 (555) 345-6789',
        address: '302 Pine Street, Austin, TX',
        idNumber: 'ID-9920112',
        employment: 'Freelance UI/UX Designer',
        monthlyIncome: 2900.0,
        creditScore: 55,
        riskRating: 'medium',
        notes: 'New applicant requesting working capital for new workstation setup.',
        createdAt: monthsAgo(1),
      ),
    ];

    await saveCollection('borrowers', sampleBorrowers.map((b) => b.toMap()).toList());

    // Loan 1
    final loan1Disbursed = monthsAgo(2);
    final loan1Schedule = LoanUtils.generateSchedule(5000.0, 10.0, 12, loan1Disbursed);
    final loan1Payments = [
      Payment(
        id: 'pay_01',
        date: monthsAgo(1),
        amount: loan1Schedule[0].amount,
        method: 'Bank Transfer',
        note: 'Installment 1 paid',
      ),
      Payment(
        id: 'pay_02',
        date: monthsAgo(0),
        amount: loan1Schedule[1].amount,
        method: 'Bank Transfer',
        note: 'Installment 2 paid',
      ),
    ];

    // Loan 2
    final loan2Disbursed = monthsAgo(3);
    final loan2Schedule = LoanUtils.generateSchedule(3000.0, 14.0, 6, loan2Disbursed);
    final loan2Payments = [
      Payment(
        id: 'pay_03',
        date: monthsAgo(2),
        amount: loan2Schedule[0].amount,
        method: 'Debit Card',
        note: 'Installment 1 paid',
      ),
      Payment(
        id: 'pay_04',
        date: monthsAgo(1),
        amount: 150.0,
        method: 'Cash',
        note: 'Partial payment for installment 2',
      ),
    ];

    // Loan 3
    final loan3Disbursed = DateFormat('yyyy-MM-dd').format(today);
    final loan3Schedule = LoanUtils.generateSchedule(2500.0, 12.0, 6, loan3Disbursed);

    final sampleLoans = [
      Loan(
        id: 'loan_elena_01',
        borrowerId: 'bor_elena_01',
        principal: 5000.0,
        interestRate: 10.0,
        termMonths: 12,
        purpose: 'Tech Equipment Purchase',
        status: 'active',
        disbursementDate: loan1Disbursed,
        creditAssessment: LoanUtils.assessBorrower(sampleBorrowers[0], []),
        schedule: loan1Schedule,
        payments: loan1Payments,
        notes: 'Computer upgrade financing for freelance business expansion.',
        createdAt: loan1Disbursed,
      ),
      Loan(
        id: 'loan_marcus_02',
        borrowerId: 'bor_marcus_02',
        principal: 3000.0,
        interestRate: 14.0,
        termMonths: 6,
        purpose: 'Retail Inventory Restock',
        status: 'active',
        disbursementDate: loan2Disbursed,
        creditAssessment: LoanUtils.assessBorrower(sampleBorrowers[1], []),
        schedule: loan2Schedule,
        payments: loan2Payments,
        notes: 'Inventory financing for seasonal merchandise.',
        createdAt: loan2Disbursed,
      ),
      Loan(
        id: 'loan_aisha_03',
        borrowerId: 'bor_aisha_03',
        principal: 2500.0,
        interestRate: 12.0,
        termMonths: 6,
        purpose: 'Studio Design Workstation',
        status: 'pending',
        disbursementDate: loan3Disbursed,
        creditAssessment: LoanUtils.assessBorrower(sampleBorrowers[2], []),
        schedule: loan3Schedule,
        payments: [],
        notes: 'Awaiting final approval on design portfolio verification.',
        createdAt: loan3Disbursed,
      ),
    ];

    await saveCollection('loans', sampleLoans.map((l) => l.toMap()).toList());
  }
}
