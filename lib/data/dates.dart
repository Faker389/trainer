String _pad(int v) => v.toString().padLeft(2, '0');

String dateKey(DateTime d) => '${d.year}-${_pad(d.month)}-${_pad(d.day)}';

DateTime parseDateKey(String key) {
  final p = key.split('-');
  return DateTime(int.parse(p[0]), int.parse(p[1]), int.parse(p[2]));
}

DateTime today() {
  final n = DateTime.now();
  return DateTime(n.year, n.month, n.day);
}

DateTime startOfWeek(DateTime d) => DateTime(d.year, d.month, d.day - (d.weekday - 1));

const weekdayNames = ['Poniedziałek', 'Wtorek', 'Środa', 'Czwartek', 'Piątek', 'Sobota', 'Niedziela'];
const weekdayShort = ['pon', 'wt', 'śr', 'czw', 'pt', 'sob', 'nd'];
const _monthGenitive = [
  'stycznia',
  'lutego',
  'marca',
  'kwietnia',
  'maja',
  'czerwca',
  'lipca',
  'sierpnia',
  'września',
  'października',
  'listopada',
  'grudnia',
];

String formatDay(DateTime d) {
  final year = d.year != DateTime.now().year ? ' ${d.year}' : '';
  return '${weekdayShort[d.weekday - 1]}, ${d.day} ${_monthGenitive[d.month - 1]}$year';
}

String formatShortDate(DateTime d) => '${_pad(d.day)}.${_pad(d.month)}';

/// Number without trailing zeros, Polish decimal comma.
String fmtNum(double v, [int maxDecimals = 2]) {
  if (v == v.roundToDouble()) return v.toInt().toString();
  var s = v.toStringAsFixed(maxDecimals);
  while (s.endsWith('0')) {
    s = s.substring(0, s.length - 1);
  }
  if (s.endsWith('.')) s = s.substring(0, s.length - 1);
  return s.replaceAll('.', ',');
}

double? parseNum(String s) => double.tryParse(s.replaceAll(',', '.').trim());

String fmtDuration(int seconds) {
  final h = seconds ~/ 3600, m = (seconds % 3600) ~/ 60, s = seconds % 60;
  return h > 0 ? '$h:${_pad(m)}:${_pad(s)}' : '$m:${_pad(s)}';
}
