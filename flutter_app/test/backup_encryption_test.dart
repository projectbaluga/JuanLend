import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:microlend/store/offline_store.dart';
import 'package:microlend/store/app_state.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AppState exportDataJson and importDataJson with encryption and HMAC', () {
    late OfflineStore store;
    late AppState appState;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      store = await OfflineStore.init();
      appState = AppState(store);
      await appState.login('admin', 'admin123');
    });

    test('unencrypted backup export contains payload and HMAC signature', () {
      final jsonStr = appState.exportDataJson();
      final decoded = jsonDecode(jsonStr) as Map<String, dynamic>;

      expect(decoded['encrypted'], false);
      expect(decoded.containsKey('payload'), isTrue);
      expect(decoded.containsKey('signature'), isTrue);
      expect(decoded['signature'], isNotEmpty);
    });

    test('importing valid unencrypted backup succeeds', () async {
      final jsonStr = appState.exportDataJson();
      expect(() async => await appState.importDataJson(jsonStr), returnsNormally);
    });

    test('tampered unencrypted backup fails HMAC verification', () async {
      final jsonStr = appState.exportDataJson();
      final decoded = jsonDecode(jsonStr) as Map<String, dynamic>;

      // Tamper with payload
      decoded['payload']['borrowers'] = [
        {
          'id': 'hacked_b',
          'fullName': 'Hacker',
        }
      ];

      final tamperedJson = jsonEncode(decoded);
      expect(
        () async => await appState.importDataJson(tamperedJson),
        throwsA(isA<FormatException>().having(
          (e) => e.message,
          'message',
          contains('Backup integrity check failed'),
        )),
      );
    });

    test('encrypted backup export and import with passphrase', () async {
      final passphrase = 'SecretPassphrase123!';
      final encryptedJson = appState.exportDataJson(passphrase: passphrase);
      final decoded = jsonDecode(encryptedJson) as Map<String, dynamic>;

      expect(decoded['encrypted'], true);
      expect(decoded['kdf'], 'pbkdf2_sha256');
      expect(decoded.containsKey('ciphertext'), isTrue);
      expect(decoded.containsKey('salt'), isTrue);
      expect(decoded.containsKey('iv'), isTrue);

      // Attempting import without passphrase throws exception
      expect(
        () async => await appState.importDataJson(encryptedJson),
        throwsA(isA<FormatException>().having(
          (e) => e.message,
          'message',
          contains('Backup file is encrypted'),
        )),
      );

      // Attempting import with wrong passphrase throws exception
      expect(
        () async => await appState.importDataJson(encryptedJson, passphrase: 'WrongPassphrase'),
        throwsA(isA<FormatException>().having(
          (e) => e.message,
          'message',
          contains('Failed to decrypt backup'),
        )),
      );

      // Import with correct passphrase succeeds
      expect(() async => await appState.importDataJson(encryptedJson, passphrase: passphrase), returnsNormally);
    });
  });
}
