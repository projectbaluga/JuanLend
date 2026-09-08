class LicenseVerifier {
  /// Single embedded master unlock code distributed to customers to unlock full features.
  static const String masterUnlockCode = 'MICROLEND-FULL-UNLOCK';

  /// Verifies if the provided [code] matches the embedded [masterUnlockCode],
  /// trimming only surrounding whitespace.
  static bool verifyUnlockCode(String code) {
    return code.trim() == masterUnlockCode;
  }
}
