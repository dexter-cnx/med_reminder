import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:med_reminder_offline/l10n/csv_validator.dart';

void main() {
  test('production translation CSV passes validation', () {
    final csv = File('assets/translations.csv').readAsStringSync();
    expect(validateTranslationCsv(csv), isEmpty);
  });

  test('validator rejects duplicate keys', () {
    const csv = 'key,en,th\nhello,Hello,สวัสดี\nhello,Hi,หวัดดี\n';
    expect(
      validateTranslationCsv(csv).map((issue) => issue.message),
      contains('Duplicate key: hello'),
    );
  });

  test('validator rejects rows with no translations', () {
    const csv = 'key,en,th\nempty,,\n';
    final messages = validateTranslationCsv(csv).map((issue) => issue.message).toList();
    expect(messages, contains('All translations are empty for key: empty'));
    expect(messages, contains('English fallback is empty for key: empty'));
  });

  test('validator rejects placeholder mismatch', () {
    const csv = 'key,en,th\nremaining,"{count} remaining",เหลือ\n';
    expect(
      validateTranslationCsv(csv).map((issue) => issue.message).join('\n'),
      contains('Placeholder mismatch for remaining [th]'),
    );
  });
}
