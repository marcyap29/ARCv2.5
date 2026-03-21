// Calendar day (YYYY-MM-DD) in the device local timezone — used for unified LUMARA daily quotas.

String lumaraLocalCalendarDate() {
  final n = DateTime.now();
  final y = n.year.toString().padLeft(4, '0');
  final m = n.month.toString().padLeft(2, '0');
  final d = n.day.toString().padLeft(2, '0');
  return '$y-$m-$d';
}
