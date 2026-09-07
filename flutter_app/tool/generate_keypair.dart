// ignore_for_file: avoid_print

/// NOTE: Keypair generation is a rare/one-time administration operation.
/// It is NOT part of the routine license-issuing flow.
/// To generate a new Ed25519 keypair manually, run:
///   `dart run tool/generate_keypair.dart`
/// Update `masterPublicKeyHex` in `lib/utils/license_verifier.dart` with the new public key
/// and set `LICENSE_PRIVATE_KEY` in GitHub Repository Secrets with the matching private seed.
library;

import 'package:cryptography/cryptography.dart';

void main() async {
  final algorithm = Ed25519();
  final keyPair = await algorithm.newKeyPair();

  final pubKey = await keyPair.extractPublicKey();
  final privBytes = await keyPair.extractPrivateKeyBytes();

  final pubKeyHex = pubKey.bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  final privSeedHex = privBytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();

  print('=== MicroLend Ed25519 Key Pair Generator ===');
  print('WARNING: Store the Private Key (seed hex) securely as a GitHub Repository Secret (LICENSE_PRIVATE_KEY).');
  print('NEVER commit or publicly share the Private Key.');
  print('The Public Key (hex) should be embedded into flutter_app/lib/utils/license_verifier.dart as masterPublicKeyHex.');
  print('');
  print('Private Key (seed hex): $privSeedHex');
  print('Public Key (hex): $pubKeyHex');
}
