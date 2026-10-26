import 'package:intl/intl.dart';

final _dayMonth = DateFormat("EEE d 'de' MMM", 'es');
final _fullDate = DateFormat("EEEE d 'de' MMMM", 'es');
final _time = DateFormat('HH:mm', 'es');

String capitalize(String s) => s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);

/// "lun 20 de oct"
String shortDate(DateTime d) => _dayMonth.format(d);

/// "Lunes 20 de octubre"
String longDate(DateTime d) => capitalize(_fullDate.format(d));

String hourMinute(DateTime d) => _time.format(d);

/// "(faltan 3 días)", "(hoy)", "(vencida hace 2 días)"
String daysLeftLabel(int days) {
  if (days == 0) return 'hoy';
  if (days == 1) return 'mañana';
  if (days > 1) return 'faltan $days días';
  if (days == -1) return 'venció ayer';
  return 'venció hace ${-days} días';
}

/// "Hoy 14:00 – 16:00", "Mañana 7:00 – 9:00", "jue 23 de oct 14:00 – 16:00"
String slotLabel(DateTime start, DateTime end) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final day = DateTime(start.year, start.month, start.day);
  final diff = day.difference(today).inDays;
  final prefix = diff == 0
      ? 'Hoy'
      : diff == 1
      ? 'Mañana'
      : capitalize(shortDate(start));
  return '$prefix ${hourMinute(start)} – ${hourMinute(end)}';
}
