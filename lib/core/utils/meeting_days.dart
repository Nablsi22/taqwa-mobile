/// Meeting days of a course (دورة), as the server stores them.
///
/// Weekdays use ISO numbering — Monday = 1 … Sunday = 7 — which is exactly
/// what Dart's [DateTime.weekday] returns, so no conversion is ever needed.
///
///   mandatory  (server: REQUIRED) a day every student is expected at —
///              winter: Saturday.
///   optional   (server: OPTIONAL) a day for those who come — winter:
///              Thursday. Whoever attends is
///              rewarded; nobody is ever counted absent or deducted.
///   extra      (server: EXTRA) any other day — a make-up session. Treated
///              like optional.
enum DayKind { mandatory, optional, extra }

class MeetingDays {
  const MeetingDays({this.requiredDays = const [], this.optionalDays = const []});

  final List<int> requiredDays;
  final List<int> optionalDays;

  /// A course created before meeting days existed has none configured.
  bool get isConfigured => requiredDays.isNotEmpty || optionalDays.isNotEmpty;

  bool isMeetingDay(DateTime day) =>
      requiredDays.contains(day.weekday) || optionalDays.contains(day.weekday);

  DayKind kindOf(DateTime day) {
    if (requiredDays.contains(day.weekday)) return DayKind.mandatory;
    if (optionalDays.contains(day.weekday)) return DayKind.optional;
    return DayKind.extra;
  }

  /// The day the attendance sheet should open on: today when today is a
  /// meeting day, otherwise the most recent meeting day of the past week —
  /// so an instructor recording Saturday's session on Sunday lands on
  /// Saturday instead of saving it under the wrong date. Without configured
  /// meeting days this is simply today, exactly as before.
  DateTime defaultAttendanceDay(DateTime now) {
    final today = DateTime(now.year, now.month, now.day);
    if (!isConfigured) return today;
    for (var back = 0; back < 7; back++) {
      final d = today.subtract(Duration(days: back));
      if (isMeetingDay(d)) return d;
    }
    return today;
  }

  /// `{ "required": [6], "optional": [4] }` or the course row's
  /// `requiredDays` / `optionalDays` arrays. Anything else → none.
  factory MeetingDays.fromLists(dynamic requiredRaw, dynamic optionalRaw) {
    return MeetingDays(
      requiredDays: _weekdays(requiredRaw),
      optionalDays: _weekdays(optionalRaw),
    );
  }

  factory MeetingDays.fromJson(dynamic json) {
    if (json is! Map) return const MeetingDays();
    return MeetingDays.fromLists(json['required'], json['optional']);
  }

  static List<int> _weekdays(dynamic raw) {
    if (raw is! List) return const [];
    final out = <int>[];
    for (final v in raw) {
      final n = v is num ? v.toInt() : int.tryParse('$v');
      if (n != null && n >= 1 && n <= 7 && !out.contains(n)) out.add(n);
    }
    out.sort();
    return List.unmodifiable(out);
  }
}

/// `2026-10-17` for a calendar day, independent of any time zone.
String isoDay(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

/// The server's `REQUIRED` / `OPTIONAL` / `EXTRA`; null for anything else.
DayKind? dayKindFromServer(Object? raw) {
  switch (raw) {
    case 'REQUIRED':
      return DayKind.mandatory;
    case 'OPTIONAL':
      return DayKind.optional;
    case 'EXTRA':
      return DayKind.extra;
  }
  return null;
}
