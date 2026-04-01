String relativeTimeLabel(DateTime value) {
  final diff = DateTime.now().difference(value.toLocal());
  if (diff.inMinutes < 1) {
    return 'now';
  }
  if (diff.inMinutes < 60) {
    return '${diff.inMinutes}m ago';
  }
  if (diff.inHours < 24) {
    return '${diff.inHours}h ago';
  }
  return '${diff.inDays}d ago';
}

String absoluteLocalTimeLabel(DateTime value) {
  final local = value.toLocal();
  const months = <String>[
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  final month = months[local.month - 1];
  final day = local.day;
  final year = local.year;
  final hour24 = local.hour;
  final minute = local.minute.toString().padLeft(2, '0');
  final meridiem = hour24 >= 12 ? 'PM' : 'AM';
  final hour12 = hour24 == 0
      ? 12
      : hour24 > 12
      ? hour24 - 12
      : hour24;
  return '$month $day, $year, $hour12:$minute $meridiem ${_timeZoneLabel(local)}';
}

String adminDateTimeLabel(DateTime value) {
  return '${relativeTimeLabel(value)} | ${absoluteLocalTimeLabel(value)}';
}

String _timeZoneLabel(DateTime value) {
  final name = value.timeZoneName.trim();
  if (RegExp(r'^[A-Z]{2,5}$').hasMatch(name)) {
    return name;
  }

  final offset = value.timeZoneOffset;
  final sign = offset.isNegative ? '-' : '+';
  final absolute = offset.abs();
  final hours = absolute.inHours.toString().padLeft(2, '0');
  final minutes = (absolute.inMinutes % 60).toString().padLeft(2, '0');
  return 'UTC$sign$hours:$minutes';
}
