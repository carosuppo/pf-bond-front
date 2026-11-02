import 'package:bond_front/features/auth/utils/minimum_account_age.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final today = DateTime(2026, 10, 28);

  test('accepts a person who has turned 13', () {
    expect(
      validateMinimumAccountAge(DateTime(2013, 10, 28), today: today),
      isNull,
    );
  });

  test('rejects a person whose 13th birthday is tomorrow', () {
    expect(
      validateMinimumAccountAge(DateTime(2013, 10, 29), today: today),
      isNotNull,
    );
  });

  test('requires a birth date and formats its API representation', () {
    expect(validateMinimumAccountAge(null, today: today), isNotNull);
    expect(serializeBirthDate(DateTime(2013, 10, 8)), '2013-10-08');
    expect(formatBirthDate(DateTime(2013, 10, 8)), '08/10/2013');
  });
}
