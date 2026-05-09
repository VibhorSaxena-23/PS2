import 'package:intl/intl.dart';

class Formatters {
  Formatters._();

  static final NumberFormat _currency = NumberFormat.currency(
    locale: 'en_IN',
    symbol: 'INR ',
    decimalDigits: 0,
  );

  static final DateFormat _dateTime = DateFormat('dd MMM yyyy, hh:mm a');
  static final DateFormat _date = DateFormat('dd MMM yyyy');

  static String price(double value) => _currency.format(value);

  static String date(DateTime value) => _date.format(value);

  static String dateTime(DateTime value) => _dateTime.format(value);
}
