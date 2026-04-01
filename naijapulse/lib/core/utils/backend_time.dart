DateTime? parseBackendDateTimeOrNull(Object? value) {
  final raw = value?.toString().trim() ?? '';
  if (raw.isEmpty) {
    return null;
  }

  final hasTimezone =
      raw.endsWith('Z') || RegExp(r'[+-]\d{2}:\d{2}$').hasMatch(raw);
  final normalized = hasTimezone ? raw : '${raw}Z';
  final parsed = DateTime.tryParse(normalized);
  if (parsed == null) {
    return null;
  }
  return parsed.toLocal();
}

DateTime parseBackendDateTime(Object? value, {DateTime? fallback}) {
  return parseBackendDateTimeOrNull(value) ??
      fallback ??
      DateTime.fromMillisecondsSinceEpoch(0);
}
