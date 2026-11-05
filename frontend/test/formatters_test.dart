import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:inventory_frontend/core/utils/formatters.dart';

void main() {
  setUpAll(() async {
    await initializeDateFormatting('vi_VN');
  });

  test('formats VND currency with Vietnamese grouping', () {
    final formatted = AppFormatters.currency(1234567);
    expect(formatted, contains('1.234.567'));
    expect(formatted, contains('₫'));
  });

  test('formats numbers with Vietnamese grouping', () {
    expect(AppFormatters.number(1234567), '1.234.567');
  });

  test('formats local date and time', () {
    final value = DateTime(2026, 11, 3, 8, 15);
    expect(AppFormatters.dateTime(value), '03/11/2026 08:15');
    expect(AppFormatters.date(value), '03/11/2026');
  });

  test('formats input values without unnecessary decimals', () {
    expect(AppFormatters.inputNumber(250000), '250000');
    expect(AppFormatters.inputNumber(250000.5), '250000.50');
  });
}
