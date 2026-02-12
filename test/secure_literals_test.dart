import 'package:flutter_test/flutter_test.dart';
import 'package:secure_literals/secure_literals.dart';

void main() {
  test('SecureLiterals decrypts values correctly', () {
    // String
    expect(SecureLiterals.apiKey, 'SUPER_SECRET_KEY_12345');
    // Int
    expect(SecureLiterals.maxRetries, 5);
    // List<String>
    expect(SecureLiterals.serverEndpoints, [
      'https://api.one.com',
      'https://api.two.com',
    ]);
    // List<int>
    expect(SecureLiterals.retryDelays, [1000, 2000, 5000]);
  });

  test('SecureLiterals caching works', () {
    final firstAccess = SecureLiterals.apiKey;
    final secondAccess = SecureLiterals.apiKey;
    expect(
      identical(firstAccess, secondAccess),
      isTrue,
    ); // Strings might be interned, but let's check values at least.

    // For lists, reference equality check
    final list1 = SecureLiterals.serverEndpoints;
    final list2 = SecureLiterals.serverEndpoints;
    expect(identical(list1, list2), isTrue);
  });
}
