import '../../../core/utils/meeting_days.dart';

/// A دورة (course/term) — the unit of points isolation.
///
/// Every course is completely independent: its own points, leaderboard and
/// statistics. Starting a new course deletes nothing — students and all past
/// courses stay exactly as they are, the new course simply has no points rows
/// yet, so every balance in it reads 0.
///
/// Mirrors the backend `Term` model plus the counters `GET /terms` attaches.
class Term {
  final int id;

  /// Slug identifier, e.g. `summer-2026`. Latin letters, digits and `-`.
  final String name;

  /// Display name, e.g. «الدورة الصيفية 2026». This is what the UI shows.
  final String nameAr;

  final DateTime startDate;

  /// `null` while the course is still running.
  final DateTime? endDate;

  /// Exactly one course is active at a time; new points land in it.
  final bool isActive;

  // ── Counters from GET /terms. Zero when the backend predates them. ──
  final double totalPoints;
  final int recitationCount;
  final int activeStudentCount;

  /// Weekdays of the course (ISO, Monday = 1). Empty on a server that
  /// predates meeting days — see [MeetingDays.isConfigured].
  final List<int> requiredDays;
  final List<int> optionalDays;

  const Term({
    required this.id,
    required this.name,
    required this.nameAr,
    required this.startDate,
    this.endDate,
    required this.isActive,
    this.totalPoints = 0,
    this.recitationCount = 0,
    this.activeStudentCount = 0,
    this.requiredDays = const [],
    this.optionalDays = const [],
  });

  MeetingDays get meetingDays => MeetingDays(requiredDays: requiredDays, optionalDays: optionalDays);

  /// A course that has ended. Used to caption archived views.
  bool get isFinished => endDate != null && !isActive;

  /// `2026-06-06 — الآن` / `2025-09-01 — 2026-06-05`
  String get periodLabel {
    final from = _formatDate(startDate);
    final to = endDate == null ? 'الآن' : _formatDate(endDate!);
    return '$from — $to';
  }

  static String _formatDate(DateTime d) =>
      '${d.year}/${d.month.toString().padLeft(2, '0')}/${d.day.toString().padLeft(2, '0')}';

  factory Term.fromJson(Map<String, dynamic> json) {
    return Term(
      id: _toInt(json['id']),
      name: (json['name'] ?? '').toString(),
      nameAr: (json['nameAr'] ?? json['name'] ?? '').toString(),
      startDate: _toDate(json['startDate']) ?? DateTime.now(),
      endDate: _toDate(json['endDate']),
      isActive: json['isActive'] == true,
      totalPoints: _toDouble(json['totalPoints']),
      recitationCount: _toInt(json['recitationCount']),
      activeStudentCount: _toInt(json['activeStudentCount']),
      requiredDays: MeetingDays.fromLists(json['requiredDays'], null).requiredDays,
      optionalDays: MeetingDays.fromLists(null, json['optionalDays']).optionalDays,
    );
  }

  @override
  bool operator ==(Object other) => other is Term && other.id == id;

  @override
  int get hashCode => id.hashCode;
}

// ─────────────────────────────────────────────────────────────────
// Defensive coercion. Prisma serialises Decimal as String and Int as
// number; never raw-cast a value that crossed the wire.
// ─────────────────────────────────────────────────────────────────
int _toInt(dynamic v) {
  if (v is int) return v;
  if (v is num) return v.toInt();
  if (v is String) return int.tryParse(v) ?? (num.tryParse(v)?.toInt() ?? 0);
  return 0;
}

double _toDouble(dynamic v) {
  if (v is double) return v;
  if (v is num) return v.toDouble();
  if (v is String) return double.tryParse(v) ?? 0;
  return 0;
}

DateTime? _toDate(dynamic v) {
  if (v == null) return null;
  if (v is DateTime) return v;
  return DateTime.tryParse(v.toString());
}
