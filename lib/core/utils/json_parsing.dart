/// Defensive readers for Laravel's hand-rolled JSON payloads.
///
/// The API has no API Resources, so shapes drift and the same logical field
/// arrives as different types depending on the endpoint: `score` is a JSON
/// *string* ("12.50") on exam cards because of the `decimal:2` cast, but a real
/// number in `partStatus`. `maxScore` in grades is a `number_format()` string.
/// Dates arrive as ISO 8601, "M d, Y", or `diffForHumans()` output.
///
/// Every accessor here returns a fallback instead of throwing, so one odd field
/// never blanks an entire screen.
extension JsonMap on Map<String, dynamic> {
  String asString(String key, {String fallback = ''}) {
    final Object? value = this[key];
    if (value == null) return fallback;
    if (value is String) return value;
    if (value is num || value is bool) return '$value';
    return fallback;
  }

  String? asStringOrNull(String key) {
    final Object? value = this[key];
    if (value == null) return null;
    if (value is String) return value.isEmpty ? null : value;
    if (value is num || value is bool) return '$value';
    return null;
  }

  double asDouble(String key, {double fallback = 0}) {
    final Object? value = this[key];
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? fallback;
    return fallback;
  }

  double? asDoubleOrNull(String key) {
    final Object? value = this[key];
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value);
    return null;
  }

  int asInt(String key, {int fallback = 0}) {
    final Object? value = this[key];
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value) ?? double.tryParse(value)?.toInt() ?? fallback;
    return fallback;
  }

  bool asBool(String key, {bool fallback = false}) {
    final Object? value = this[key];
    if (value is bool) return value;
    if (value is num) return value != 0;
    if (value is String) {
      if (value == '1' || value.toLowerCase() == 'true') return true;
      if (value == '0' || value.toLowerCase() == 'false') return false;
    }
    return fallback;
  }

  DateTime? asDateOrNull(String key) => parseFlexibleDate(this[key]);

  List<Map<String, dynamic>> asMapList(String key) {
    final Object? value = this[key];
    if (value is! List) return const [];
    return value.whereType<Map<String, dynamic>>().toList(growable: false);
  }

  /// Some payloads nest a collection under a key that can legitimately be null
  /// (`submissions` is null for a student who has submitted nothing).
  List<Map<String, dynamic>> asMapListOrEmpty(String key) => asMapList(key);

  Map<String, dynamic> asMap(String key) {
    final Object? value = this[key];
    return value is Map<String, dynamic> ? value : const {};
  }

  /// A payload key that is a map keyed by numeric id sent as a JSON string
  /// (`partDeadlines`, `answerDrafts`, `submissions` in the exam payload).
  Map<String, dynamic> asIdKeyedMap(String key) {
    final Object? value = this[key];
    if (value is! Map) return const {};
    return {
      for (final MapEntry<Object?, Object?> entry in value.entries)
        '${entry.key}': entry.value is Map<String, dynamic>
            ? entry.value as Map<String, dynamic>
            : <String, dynamic>{},
    };
  }
}

/// Parse the several date conventions this API emits.
///
/// Returns null rather than throwing: callers treat an unparseable date as
/// "no date" and hide the field, which is far better than crashing a list item.
DateTime? parseFlexibleDate(Object? raw) {
  if (raw == null) return null;
  if (raw is DateTime) return raw;
  if (raw is int) return DateTime.fromMillisecondsSinceEpoch(raw * 1000);
  if (raw is! String) return null;

  final String value = raw.trim();
  if (value.isEmpty) return null;

  final DateTime? iso = DateTime.tryParse(value);
  if (iso != null) return iso;

  // "Sep 01, 2026 08:30" — PHP's "M d, Y H:i", the format the XP history
  // endpoint emits. The clock is optional so "Sep 01, 2026" also parses.
  final RegExpMatch? named = RegExp(
    r'^([A-Za-z]{3})[a-z]*\s+(\d{1,2}),?\s+(\d{4})(?:[ ,]+(\d{1,2}):(\d{2}))?',
  ).firstMatch(value);
  if (named != null) {
    final int? month = _monthNumber(named.group(1)!);
    if (month != null) {
      return DateTime(
        int.parse(named.group(3)!),
        month,
        int.parse(named.group(2)!),
        int.tryParse(named.group(4) ?? '') ?? 0,
        int.tryParse(named.group(5) ?? '') ?? 0,
      );
    }
  }

  // "08:30 Sep 01, 2026" — clock first.
  final List<String> parts = value.split(RegExp(r'\s+'));
  if (parts.length == 2) {
    final DateTime? date = DateTime.tryParse(parts[1].replaceAll(',', ''));
    final List<String> clock = parts[0].split(':');
    if (date != null && clock.length == 2) {
      return DateTime(
        date.year,
        date.month,
        date.day,
        int.tryParse(clock[0]) ?? 0,
        int.tryParse(clock[1]) ?? 0,
      );
    }
  }

  // "Sep 01, 2026 08:30 AM" — the public profile's full_date.
  if (parts.length == 3) {
    final DateTime? date = DateTime.tryParse('${parts[0].replaceAll(',', '')} ${parts[1].replaceAll(',', '')}');
    if (date != null) {
      int hour = int.tryParse(parts[2].split(':').first) ?? 0;
      final String meridiem = parts.last.toUpperCase();
      if (meridiem == 'PM' && hour < 12) hour += 12;
      if (meridiem == 'AM' && hour == 12) hour = 0;
      final List<String> clock = parts[2].split(':');
      return DateTime(date.year, date.month, date.day, hour, int.tryParse(clock[1]) ?? 0);
    }
  }

  return null;
}

const List<String> _monthNames = <String>[
  'jan',
  'feb',
  'mar',
  'apr',
  'may',
  'jun',
  'jul',
  'aug',
  'sep',
  'oct',
  'nov',
  'dec',
];

int? _monthNumber(String name) {
  final int index = _monthNames.indexOf(name.toLowerCase());
  return index == -1 ? null : index + 1;
}