import '../../terms/data/term_model.dart';
import 'recitation_api.dart';

/// One course's part of a student's recitation record.
///
/// The server keeps every course's recitations apart (`term_id`). A student's
/// page shows them the way a teacher or a parent reads a record: the current
/// course first, then each earlier course under its own heading. Every row is
/// exactly what the server returned; nothing is merged or recomputed.
class CourseSection {
  CourseSection({
    required this.termId,
    required this.isCurrent,
    required this.name,
    required this.period,
    required this.recitations,
    required this.hadith,
  });

  /// `null` only for rows whose course could not be identified.
  final int? termId;
  final bool isCurrent;

  /// The course's name («الدورة الصيفية 2026») when the signed-in account may
  /// list courses (admin and teachers); `null` otherwise.
  final String? name;

  /// `2026/06/06 — 2026/09/18`. From the course itself when known, otherwise
  /// the span of this section's own entries. Empty when there is nothing to
  /// date.
  final String period;

  /// Quran recitations, newest first.
  final List<Map<String, dynamic>> recitations;

  /// Nawawi-40 recordings, newest first.
  final List<Map<String, dynamic>> hadith;

  int get count => recitations.length + hadith.length;
  bool get isEmpty => count == 0;

  /// «الدورة الحالية» / «دورة سابقة».
  String get kindLabel => isCurrent ? 'الدورة الحالية' : 'دورة سابقة';

  /// The line under the kind label: the course's name, or the kind itself
  /// when the name is unknown.
  String get title => name ?? (isCurrent ? 'الدورة الحالية' : 'دورة سابقة');
}

/// A student's recitations across every course, split by course.
class StudentRecitationTimeline {
  const StudentRecitationTimeline({
    required this.sections,
    required this.lastRecitation,
  });

  static const empty = StudentRecitationTimeline(
    sections: [],
    lastRecitation: null,
  );

  /// The current course first, then earlier courses, most recent first.
  final List<CourseSection> sections;

  /// The «آخر تسميع» summary as the server built it.
  final Map<String, dynamic>? lastRecitation;

  /// Every Quran recitation in display order (current course first).
  List<Map<String, dynamic>> get allRecitations =>
      [for (final s in sections) ...s.recitations];

  /// Every Nawawi-40 recording in display order.
  List<Map<String, dynamic>> get allHadith =>
      [for (final s in sections) ...s.hadith];

  bool get isEmpty => sections.every((s) => s.isEmpty);

  /// True when at least one earlier course has entries.
  bool get hasEarlierCourses =>
      sections.any((s) => !s.isCurrent && !s.isEmpty);

  /// Splits the server's two answers into sections.
  ///
  /// [current] is the history read with no `termId` (the active course).
  /// [all] is the same read with `termId=0` (every course); `null` when that
  /// read failed, in which case the page shows the current course only,
  /// exactly as before.
  ///
  /// The current section is precisely [current] — matched by row id, so it
  /// never depends on dates. Every other recitation is grouped by its own
  /// `termId`. Hadith rows carry no `termId`, so an earlier one is placed by
  /// its date: inside a known course's period when [courses] is given,
  /// otherwise in the earlier section whose dates surround it (or the
  /// nearest one).
  factory StudentRecitationTimeline.build({
    required StudentRecitationsEnvelope current,
    StudentRecitationsEnvelope? all,
    Map<int, Term> courses = const {},
  }) {
    final currentId = current.termId;
    final currentTerm = currentId == null ? null : courses[currentId];
    final currentSection = CourseSection(
      termId: currentId,
      isCurrent: true,
      name: currentTerm?.nameAr,
      period: currentTerm?.periodLabel ?? '',
      recitations: _newestFirst(current.history, _recitationDay),
      hadith: _newestFirst(current.hadithEntries, _hadithDay),
    );

    if (all == null) {
      return StudentRecitationTimeline(
        sections: [currentSection],
        lastRecitation: current.lastRecitation,
      );
    }

    final currentRecIds = {for (final r in current.history) _id(r)};
    final currentHadithIds = {for (final h in current.hadithEntries) _id(h)};

    // Earlier recitations, grouped by the course the server stored them in.
    final groups = <int?, _Group>{};
    for (final r in all.history) {
      if (currentRecIds.contains(_id(r))) continue;
      final termId = _termIdOf(r);
      if (termId != null && termId == currentId) continue;
      (groups[termId] ??= _Group(termId)).recitations.add(r);
    }

    // Earlier hadith rows, placed by date.
    for (final h in all.hadithEntries) {
      if (currentHadithIds.contains(_id(h))) continue;
      final day = _hadithDay(h);
      final termId = _courseByPeriod(day, courses, exclude: currentId) ??
          _groupByDates(day, groups.values);
      (groups[termId] ??= _Group(termId)).hadith.add(h);
    }

    final earlier = groups.values.toList()
      ..sort((a, b) {
        final ta = a.termId == null ? null : courses[a.termId];
        final tb = b.termId == null ? null : courses[b.termId];
        if (ta != null && tb != null) return tb.startDate.compareTo(ta.startDate);
        return (b.latestDay ?? DateTime(0)).compareTo(a.latestDay ?? DateTime(0));
      });

    return StudentRecitationTimeline(
      sections: [
        currentSection,
        for (final g in earlier)
          CourseSection(
            termId: g.termId,
            isCurrent: false,
            name: g.termId == null ? null : courses[g.termId]?.nameAr,
            period: (g.termId == null ? null : courses[g.termId]?.periodLabel) ??
                g.periodFromEntries,
            recitations: _newestFirst(g.recitations, _recitationDay),
            hadith: _newestFirst(g.hadith, _hadithDay),
          ),
      ],
      lastRecitation: current.lastRecitation ?? all.lastRecitation,
    );
  }

  // ── helpers ──────────────────────────────────────────────────────────

  static String _id(Map<String, dynamic> row) => row['id']?.toString() ?? '';

  static int? _termIdOf(Map<String, dynamic> row) {
    final v = row['termId'];
    if (v is int) return v;
    if (v is num) return v.toInt();
    if (v is String) return int.tryParse(v);
    return null;
  }

  /// Local calendar day of a server date or timestamp.
  static DateTime? _day(dynamic raw) {
    final d = DateTime.tryParse(raw?.toString() ?? '');
    if (d == null) return null;
    final local = d.toLocal();
    return DateTime(local.year, local.month, local.day);
  }

  static DateTime? _recitationDay(Map<String, dynamic> r) =>
      _day(r['date'] ?? r['createdAt']);

  static DateTime? _hadithDay(Map<String, dynamic> h) => _day(h['createdAt']);

  static List<Map<String, dynamic>> _newestFirst(
    List<Map<String, dynamic>> rows,
    DateTime? Function(Map<String, dynamic>) dayOf,
  ) {
    // The server already sends newest first; a stable sort keeps its order
    // within a day.
    final indexed = rows.asMap().entries.toList()
      ..sort((a, b) {
        final da = dayOf(a.value) ?? DateTime(0);
        final db = dayOf(b.value) ?? DateTime(0);
        final c = db.compareTo(da);
        return c != 0 ? c : a.key.compareTo(b.key);
      });
    return [for (final e in indexed) e.value];
  }

  /// The course (other than [exclude]) whose period contains [day].
  static int? _courseByPeriod(
    DateTime? day,
    Map<int, Term> courses, {
    int? exclude,
  }) {
    if (day == null) return null;
    for (final t in courses.values) {
      if (t.id == exclude) continue;
      final start = DateTime(t.startDate.year, t.startDate.month, t.startDate.day);
      final end = t.endDate == null
          ? null
          : DateTime(t.endDate!.year, t.endDate!.month, t.endDate!.day);
      if (!day.isBefore(start) && (end == null || !day.isAfter(end))) return t.id;
    }
    return null;
  }

  /// The earlier section whose entries surround [day]; otherwise the one
  /// whose dates are nearest; otherwise none (`null` = unidentified course).
  static int? _groupByDates(DateTime? day, Iterable<_Group> groups) {
    if (day == null) return groups.isEmpty ? null : groups.first.termId;
    _Group? nearest;
    var best = 1 << 30;
    for (final g in groups) {
      final first = g.earliestDay;
      final last = g.latestDay;
      if (first == null || last == null) continue;
      if (!day.isBefore(first) && !day.isAfter(last)) return g.termId;
      final gap = day.isBefore(first)
          ? first.difference(day).inDays
          : day.difference(last).inDays;
      if (gap < best) {
        best = gap;
        nearest = g;
      }
    }
    return nearest?.termId;
  }
}

/// Mutable bucket used while splitting; becomes an immutable [CourseSection].
class _Group {
  _Group(this.termId);

  final int? termId;
  final List<Map<String, dynamic>> recitations = [];
  final List<Map<String, dynamic>> hadith = [];

  Iterable<DateTime> get _days sync* {
    for (final r in recitations) {
      final d = StudentRecitationTimeline._recitationDay(r);
      if (d != null) yield d;
    }
    for (final h in hadith) {
      final d = StudentRecitationTimeline._hadithDay(h);
      if (d != null) yield d;
    }
  }

  DateTime? get earliestDay {
    DateTime? m;
    for (final d in _days) {
      if (m == null || d.isBefore(m)) m = d;
    }
    return m;
  }

  DateTime? get latestDay {
    DateTime? m;
    for (final d in _days) {
      if (m == null || d.isAfter(m)) m = d;
    }
    return m;
  }

  String get periodFromEntries {
    final a = earliestDay;
    final b = latestDay;
    if (a == null || b == null) return '';
    return a == b ? _fmt(a) : '${_fmt(a)} — ${_fmt(b)}';
  }

  static String _fmt(DateTime d) =>
      '${d.year}/${d.month.toString().padLeft(2, '0')}/${d.day.toString().padLeft(2, '0')}';
}

/// Arabic count of recitations: «تسميع واحد»، «تسميعان»، «3 تسميعات»، «11 تسميعاً».
String recitationsCountAr(int n) {
  if (n == 0) return 'لا تسميع';
  if (n == 1) return 'تسميع واحد';
  if (n == 2) return 'تسميعان';
  final mod100 = n % 100;
  if (mod100 >= 3 && mod100 <= 10) return '$n تسميعات';
  return '$n تسميعاً';
}

/// Reads a student's record across every course: two reads of the same
/// endpoint in parallel — the active course, and every course (`termId=0`).
extension RecitationTimelineLoader on RecitationApi {
  Future<StudentRecitationTimeline> getStudentTimeline(
    String studentId, {
    Iterable<Term>? courses,
  }) async {
    Future<StudentRecitationsEnvelope?> everyCourse() async {
      try {
        return await getStudentHistoryWithSession(studentId, termId: 0);
      } catch (_) {
        return null; // degrade to the current course only
      }
    }

    final allFuture = everyCourse();
    final current = await getStudentHistoryWithSession(studentId);
    final all = await allFuture;
    return StudentRecitationTimeline.build(
      current: current,
      all: all,
      courses: {for (final t in courses ?? const <Term>[]) t.id: t},
    );
  }
}
