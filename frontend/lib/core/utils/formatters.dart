import 'package:intl/intl.dart';

class AppFormatters {
  AppFormatters._();

  static final NumberFormat _currency = NumberFormat.currency(
    locale: 'vi_VN',
    symbol: '₫',
    decimalDigits: 0,
  );
  static final NumberFormat _number = NumberFormat.decimalPattern('vi_VN');
  static final DateFormat _dateTime = DateFormat('dd/MM/yyyy HH:mm', 'vi_VN');
  static final DateFormat _date = DateFormat('dd/MM/yyyy', 'vi_VN');

  static String currency(num value) => _currency.format(value);

  static String number(num value) => _number.format(value);

  static String dateTime(DateTime value) {
    return _dateTime.format(value.toLocal());
  }

  static String date(DateTime value) {
    return _date.format(value.toLocal());
  }

  static String inputNumber(num value) {
    if (value == value.roundToDouble()) {
      return value.toStringAsFixed(0);
    }
    return value.toStringAsFixed(2);
  }

  static String stockStatusLabel(String label) => label;
}
