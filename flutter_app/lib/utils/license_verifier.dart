import 'dart:convert';
import 'package:cryptography/cryptography.dart';

class LicenseVerifier {
  // Master embedded Ed25519 public key hex
  static const String masterPublicKeyHex = '9de600b6222feba1b719b762236aab6d59c1c42887b2fba9462014fffe985766';

  static Future<bool> verifyLicenseKey(
    String licenseKey,
    String machineId, {
    String? overridePublicKeyHex,
  }) async {
    final cleanKey = licenseKey.trim().replaceAll(RegExp(r'\s+'), '');
    final cleanMachineId = machineId.trim();

    if (cleanKey.isEmpty || cleanMachineId.isEmpty) {
      return false;
    }

    try {
      List<int> signatureBytes;
      try {
        signatureBytes = base64.decode(cleanKey);
      } catch (_) {
        signatureBytes = _hexToBytes(cleanKey);
      }

      if (signatureBytes.length != 64) {
        return false;
      }

      final pubHex = overridePublicKeyHex ?? masterPublicKeyHex;
      final pubBytes = _hexToBytes(pubHex);

      final algorithm = Ed25519();
      final publicKey = SimplePublicKey(pubBytes, type: KeyPairType.ed25519);

      final signature = Signature(
        signatureBytes,
        publicKey: publicKey,
      );

      final messageBytes = utf8.encode(cleanMachineId);
      final isValid = await algorithm.verify(
        messageBytes,
        signature: signature,
      );

      return isValid;
    } catch (_) {
      return false;
    }
  }

  static List<int> _hexToBytes(String hex) {
    final cleanHex = hex.replaceAll(RegExp(r'[^0-9a-fA-F]'), '');
    final result = <int>[];
    for (var i = 0; i < cleanHex.length; i += 2) {
      final part = cleanHex.substring(i, i + 2);
      result.add(int.parse(part, radix: 16));
    }
    return result;
  }
}
