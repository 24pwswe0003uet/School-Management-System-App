import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';

/// Passwords are never stored in plain text.
///
/// Each password is hashed with PBKDF2-HMAC-SHA256 using a random per-user
/// salt and a configurable iteration count. Stored format:
///   `pbkdf2-sha256$<iterations>$<saltBase64>$<hashBase64>`
class SecurePasswordService {
  SecurePasswordService({this.iterations = defaultIterations});

  /// Balanced for an offline desktop app on modest hardware while remaining a
  /// strong one-way derivation. Tune here if hardware requires it.
  static const int defaultIterations = 120000;
  static const int saltLength = 16;
  static const int derivedKeyLength = 32; // SHA-256 output size in bytes.

  static const String _algoTag = 'pbkdf2-sha256';

  final int iterations;
  final Random _random = Random.secure();

  String hashPassword(String password) {
    final salt = _randomBytes(saltLength);
    final derivedKey = _pbkdf2(password, salt, iterations, derivedKeyLength);
    return '$_algoTag\$'
        '$iterations\$'
        '${base64Encode(salt)}\$'
        '${base64Encode(derivedKey)}';
  }

  /// Returns true when [password] matches [storedHash].
  ///
  /// Comparison is constant-time to avoid timing side-channels. Malformed
  /// stored hashes fail closed (return false) instead of throwing.
  bool verifyPassword(String password, String storedHash) {
    final parts = storedHash.split(r'$');
    if (parts.length != 4 || parts[0] != _algoTag) {
      return false;
    }
    final storedIterations = int.tryParse(parts[1]);
    final salt = _tryDecodeBase64(parts[2]);
    final expected = _tryDecodeBase64(parts[3]);
    if (storedIterations == null || salt == null || expected == null) {
      return false;
    }
    final actual = _pbkdf2(password, salt, storedIterations, expected.length);
    return _constantTimeEquals(actual, expected);
  }

  /// PBKDF2 as defined in RFC 2898 using HMAC-SHA256 as the PRF.
  Uint8List _pbkdf2(
    String password,
    List<int> salt,
    int iterationCount,
    int keyLength,
  ) {
    final hmac = Hmac(sha256, utf8.encode(password));
    const blockSize = 32;
    final blockCount = (keyLength / blockSize).ceil();
    final output = BytesBuilder();

    for (var blockIndex = 1; blockIndex <= blockCount; blockIndex++) {
      // U1 = PRF(password, salt || INT_32_BE(blockIndex))
      var u = hmac.convert([...salt, ..._int32BigEndian(blockIndex)]).bytes;
      final block = Uint8List.fromList(u);
      // T = U1 ^ U2 ^ ... ^ Uc
      for (var i = 1; i < iterationCount; i++) {
        u = hmac.convert(u).bytes;
        for (var j = 0; j < blockSize; j++) {
          block[j] ^= u[j];
        }
      }
      output.add(block);
    }

    final allBytes = output.toBytes();
    return Uint8List.sublistView(allBytes, 0, keyLength);
  }

  Uint8List _randomBytes(int length) {
    final bytes = Uint8List(length);
    for (var i = 0; i < length; i++) {
      bytes[i] = _random.nextInt(256);
    }
    return bytes;
  }

  List<int> _int32BigEndian(int value) => [
    (value >> 24) & 0xff,
    (value >> 16) & 0xff,
    (value >> 8) & 0xff,
    value & 0xff,
  ];

  static Uint8List? _tryDecodeBase64(String value) {
    try {
      return base64Decode(value);
    } on FormatException {
      return null;
    }
  }

  bool _constantTimeEquals(List<int> a, List<int> b) {
    if (a.length != b.length) {
      return false;
    }
    var difference = 0;
    for (var i = 0; i < a.length; i++) {
      difference |= a[i] ^ b[i];
    }
    return difference == 0;
  }
}
