import 'package:flutter_test/flutter_test.dart';
import 'package:school_office_management/core/services/secure_password_service.dart';

void main() {
  group('SecurePasswordService', () {
    test('hashes and verifies a correct password', () {
      final service = SecurePasswordService();
      final hash = service.hashPassword('Secret123!');
      expect(service.verifyPassword('Secret123!', hash), isTrue);
    });

    test('rejects a wrong password', () {
      final service = SecurePasswordService();
      final hash = service.hashPassword('Secret123!');
      expect(service.verifyPassword('wrong-password', hash), isFalse);
    });

    test('uses a unique salt per hash (same password hashes differently)', () {
      final service = SecurePasswordService();
      final first = service.hashPassword('same-password');
      final second = service.hashPassword('same-password');
      expect(first, isNot(second));
      expect(service.verifyPassword('same-password', first), isTrue);
      expect(service.verifyPassword('same-password', second), isTrue);
    });

    test(r'stored format is pbkdf2-sha256$iterations$salt$hash', () {
      final service = SecurePasswordService();
      final hash = service.hashPassword('anything');
      final parts = hash.split(r'$');
      expect(parts.length, 4);
      expect(parts[0], 'pbkdf2-sha256');
      expect(int.tryParse(parts[1]), SecurePasswordService.defaultIterations);
    });

    test('never contains the plain-text password', () {
      const password = 'S3cretValue!';
      final service = SecurePasswordService();
      final hash = service.hashPassword(password);
      expect(hash.contains(password), isFalse);
    });

    test('malformed stored hash fails closed without throwing', () {
      final service = SecurePasswordService();
      expect(service.verifyPassword('x', ''), isFalse);
      expect(service.verifyPassword('x', 'not-a-hash'), isFalse);
      expect(service.verifyPassword('x', r'pbkdf2-sha256$abc$def'), isFalse);
      expect(service.verifyPassword('x', r'bcrypt$abc$def$ghi$jkl'), isFalse);
    });
  });
}
