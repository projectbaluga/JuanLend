import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart';
import 'package:pointycastle/digests/sha256.dart';
import 'package:pointycastle/key_derivators/api.dart';
import 'package:pointycastle/key_derivators/pbkdf2.dart';
import 'package:pointycastle/macs/hmac.dart';

class User {
  final String id;
  final String username;
  final String passwordHash;
  final String salt;
  final String role; // 'officer', 'approver', 'viewer'
  final bool mustChangePassword;

  User({
    required this.id,
    required this.username,
    required this.passwordHash,
    required this.salt,
    required this.role,
    this.mustChangePassword = false,
  });

  static const int kPbkdf2Iterations = 100000;
  static const String kAlgoPrefix = 'pbkdf2_sha256\$100000\$';

  static String hashPassword(String password, String salt, {int iterations = kPbkdf2Iterations}) {
    final derivator = PBKDF2KeyDerivator(HMac(SHA256Digest(), 64));
    derivator.init(Pbkdf2Parameters(utf8.encode(salt), iterations, 32));
    final keyBytes = derivator.process(utf8.encode(password));
    final hashBase64 = base64Url.encode(keyBytes);
    return 'pbkdf2_sha256\$$iterations\$$hashBase64';
  }

  static String generateSalt([int length = 16]) {
    final rand = Random.secure();
    final values = List<int>.generate(length, (i) => rand.nextInt(256));
    return base64Url.encode(values);
  }

  bool verifyPassword(String password) {
    if (passwordHash.startsWith('pbkdf2_sha256\$')) {
      final parts = passwordHash.split('\$');
      if (parts.length == 3) {
        final iterations = int.tryParse(parts[1]) ?? kPbkdf2Iterations;
        final computed = hashPassword(password, salt, iterations: iterations);
        return computed == passwordHash;
      }
    }

    // Legacy single-pass SHA-256 fallback
    final bytes = utf8.encode('$salt:$password');
    final legacyHash = sha256.convert(bytes).toString();
    return passwordHash == legacyHash;
  }

  factory User.fromMap(Map<String, dynamic> map) {
    return User(
      id: map['id']?.toString() ?? '',
      username: map['username']?.toString() ?? '',
      passwordHash: map['password_hash']?.toString() ?? map['passwordHash']?.toString() ?? '',
      salt: map['salt']?.toString() ?? '',
      role: map['role']?.toString() ?? 'viewer',
      mustChangePassword: map['must_change_password'] == true || map['mustChangePassword'] == true,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'username': username,
      'password_hash': passwordHash,
      'salt': salt,
      'role': role,
      'must_change_password': mustChangePassword,
    };
  }

  User copyWith({
    String? id,
    String? username,
    String? passwordHash,
    String? salt,
    String? role,
    bool? mustChangePassword,
  }) {
    return User(
      id: id ?? this.id,
      username: username ?? this.username,
      passwordHash: passwordHash ?? this.passwordHash,
      salt: salt ?? this.salt,
      role: role ?? this.role,
      mustChangePassword: mustChangePassword ?? this.mustChangePassword,
    );
  }
}
