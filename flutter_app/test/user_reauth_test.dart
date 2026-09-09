import 'package:flutter_test/flutter_test.dart';
import 'package:microlend/models/user.dart';

void main() {
  test('User verifyPassword validates correct and incorrect credentials', () {
    final salt = User.generateSalt();
    final hash = User.hashPassword('admin123', salt);

    final user = User(
      id: 'usr_test',
      username: 'admin',
      passwordHash: hash,
      salt: salt,
      role: 'approver',
    );

    expect(user.verifyPassword('admin123'), isTrue);
    expect(user.verifyPassword('wrongpass'), isFalse);
    expect(user.verifyPassword(' ADMIN123 '), isFalse);
  });
}
