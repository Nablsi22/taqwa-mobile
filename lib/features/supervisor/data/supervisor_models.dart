import '../../../core/utils/meeting_days.dart';
import '../../attendance_stats/data/attendance_stats_models.dart';

// ═══════════════════════════════════════════════════════════════════════════
// Read models for GET /supervisor/* — the course director («مدير الدورة»).
//
// The account exists for one purpose, in Anas's words: oversight of the
// أساتذة — that they record on the app, and that they do not record late.
// So the central model here is the recording discipline of each حلقة:
// whether each meeting day was recorded, and how many days after the session
// the first mark was saved (`attendance.created_at` against the session date,
// in Damascus time, computed on the server).
//
// Coerced defensively like the other attendance models: a field an older
// server does not send yields a neutral value instead of throwing.
// ═══════════════════════════════════════════════════════════════════════════

int _int(dynamic v) {
  if (v is int) return v;
  if (v is num) return v.toInt();
  if (v is String) return int.tryParse(v) ?? 0;
  return 0;
}

int? _intOrNull(dynamic v) {
  if (v == null) return null;
  if (v is int) return v;
  if (v is num) return v.toInt();
  if (v is String) return int.tryParse(v);
  return null;
}

double? _doubleOrNull(dynamic v) {
  if (v == null) return null;
  if (v is num) return v.toDouble();
  if (v is String) return double.tryParse(v);
  return null;
}

String? _str(dynamic v) => v?.toString();

String _text(dynamic v, [String fallback = '']) =>
    v == null ? fallback : v.toString();

Map<String, dynamic> _map(dynamic v) =>
    v is Map ? Map<String, dynamic>.from(v) : const <String, dynamic>{};

List<Map<String, dynamic>> _maps(dynamic v) => v is List
    ? v.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList()
    : const <Map<String, dynamic>>[];

/// How one meeting day of one حلقة went.
class SessionRecord {
  const SessionRecord({
    required this.date,
    required this.kind,
    required this.recorded,
    this.recordedAt,
    this.lagDays,
    this.markedByName,
    required this.byOther,
    required this.marks,
    required this.missed,
  });

  /// YYYY-MM-DD, the session day.
  final String date;
  final DayKind kind;
  final bool recorded;

  /// Local 'YYYY-MM-DDTHH:MM' of the first mark saved for that day.
  final String? recordedAt;

  /// 0 = same day, 1 = the next day, … null when never recorded.
  final int? lagDays;
  final String? markedByName;

  /// A substitute (or an admin) recorded it, not the حلقة's own أستاذ.
  final bool byOther;
  final int marks;

  /// A required day, nothing recorded, nobody covering — the only case the
  /// director holds the أستاذ to. Optional days are never missed.
  final bool missed;

  factory SessionRecord.fromJson(Map<String, dynamic> j) => SessionRecord(
        date: _text(j['date']),
        kind: dayKindFromServer(j['kind']) ?? DayKind.mandatory,
        recorded: j['recorded'] == true,
        recordedAt: _str(j['recordedAt']),
        lagDays: _intOrNull(j['lagDays']),
        markedByName: _str(j['markedByName']),
        byOther: j['byOther'] == true,
        marks: _int(j['marks']),
        missed: j['missed'] == true,
      );
}

/// The last time an أستاذ recorded anything.
class LastRecorded {
  const LastRecorded({required this.date, this.recordedAt, this.lagDays});

  final String date;
  final String? recordedAt;
  final int? lagDays;

  static LastRecorded? fromJson(dynamic raw) {
    final j = _map(raw);
    if (j.isEmpty) return null;
    return LastRecorded(
      date: _text(j['date']),
      recordedAt: _str(j['recordedAt']),
      lagDays: _intOrNull(j['lagDays']),
    );
  }
}

/// One أستاذ's recording discipline.
class InstructorDiscipline {
  const InstructorDiscipline({
    required this.instructorId,
    required this.instructorName,
    required this.students,
    required this.sessions,
    required this.requiredCount,
    required this.recordedCount,
    required this.missedCount,
    required this.coveredCount,
    required this.sameDayCount,
    required this.lateCount,
    this.avgLagDays,
    this.lastRecorded,
    required this.neverRecorded,
  });

  final String instructorId;
  final String instructorName;
  final int students;

  /// Oldest first on the main screen; newest first on the أستاذ's own page.
  final List<SessionRecord> sessions;
  final int requiredCount;
  final int recordedCount;
  final int missedCount;
  final int coveredCount;
  final int sameDayCount;
  final int lateCount;

  /// Mean lag over the days he recorded himself.
  final double? avgLagDays;
  final LastRecorded? lastRecorded;
  final bool neverRecorded;

  /// Where the card sits: needs following up, slipping, or fine.
  DisciplineLevel get level {
    if (neverRecorded || missedCount >= 2) return DisciplineLevel.bad;
    if (missedCount == 1 || lateCount > 0) return DisciplineLevel.slipping;
    return DisciplineLevel.good;
  }

  factory InstructorDiscipline.fromJson(Map<String, dynamic> j) =>
      InstructorDiscipline(
        instructorId: _text(j['instructorId']),
        instructorName: _text(j['instructorName'], 'أستاذ'),
        students: _int(j['students']),
        sessions: _maps(j['sessions'])
            .map(SessionRecord.fromJson)
            .toList(growable: false),
        requiredCount: _int(j['requiredCount']),
        recordedCount: _int(j['recordedCount']),
        missedCount: _int(j['missedCount']),
        coveredCount: _int(j['coveredCount']),
        sameDayCount: _int(j['sameDayCount']),
        lateCount: _int(j['lateCount']),
        avgLagDays: _doubleOrNull(j['avgLagDays']),
        lastRecorded: LastRecorded.fromJson(j['lastRecorded']),
        neverRecorded: j['neverRecorded'] == true,
      );
}

enum DisciplineLevel { bad, slipping, good }

/// The top of the main screen.
class DisciplineSummary {
  const DisciplineSummary({
    this.halaqas = 0,
    this.recorded = 0,
    this.notRecorded = 0,
    this.covered = 0,
    this.sameDay = 0,
    this.late = 0,
    this.neverRecorded = 0,
  });

  final int halaqas;
  final int recorded;
  final int notRecorded;
  final int covered;
  final int sameDay;
  final int late;
  final int neverRecorded;

  factory DisciplineSummary.fromJson(dynamic raw) {
    final j = _map(raw);
    return DisciplineSummary(
      halaqas: _int(j['halaqas']),
      recorded: _int(j['recorded']),
      notRecorded: _int(j['notRecorded']),
      covered: _int(j['covered']),
      sameDay: _int(j['sameDay']),
      late: _int(j['late']),
      neverRecorded: _int(j['neverRecorded']),
    );
  }
}

/// `GET /supervisor/instructors` — every حلقة, worst discipline first.
class DisciplineResult {
  const DisciplineResult({
    this.course,
    required this.days,
    this.lastSession,
    required this.summary,
    required this.instructors,
  });

  final CourseRef? course;

  /// The required days the strip covers, oldest first.
  final List<String> days;
  final String? lastSession;
  final DisciplineSummary summary;

  /// Already in the order to show: the server sorts worst first.
  final List<InstructorDiscipline> instructors;

  factory DisciplineResult.fromJson(Map<String, dynamic> j) => DisciplineResult(
        course: CourseRef.fromJson(j['course']),
        days: (j['days'] is List)
            ? (j['days'] as List).map((e) => e.toString()).toList(growable: false)
            : const [],
        lastSession: _str(j['lastSession']),
        summary: DisciplineSummary.fromJson(j['summary']),
        instructors: _maps(j['data'])
            .map(InstructorDiscipline.fromJson)
            .toList(growable: false),
      );
}

/// `GET /supervisor/instructor/:id` — his whole course, and his students.
class InstructorDetail {
  const InstructorDetail({
    this.course,
    this.discipline,
    required this.students,
  });

  final CourseRef? course;

  /// Sessions newest first. null when the حلقة is not in this course.
  final InstructorDiscipline? discipline;
  final List<StudentStats> students;

  factory InstructorDetail.fromJson(Map<String, dynamic> j) {
    final d = _map(j['discipline']);
    return InstructorDetail(
      course: CourseRef.fromJson(j['course']),
      discipline: d.isEmpty ? null : InstructorDiscipline.fromJson(d),
      students: _maps(j['students'])
          .map(StudentStats.fromJson)
          .toList(growable: false),
    );
  }
}

/// One حلقة on one day, with when it was recorded.
class SupervisedHalaqa {
  const SupervisedHalaqa({
    required this.instructorId,
    required this.instructorName,
    required this.students,
    required this.recorded,
    this.recordedAt,
    this.lagDays,
    this.markedByName,
    required this.byOther,
    required this.present,
    required this.lateCount,
    required this.absent,
    required this.excused,
    required this.unmarked,
    required this.coveredBy,
    required this.roster,
  });

  final String instructorId;
  final String instructorName;
  final int students;
  final bool recorded;
  final String? recordedAt;
  final int? lagDays;
  final String? markedByName;
  final bool byOther;
  final int present;
  final int lateCount;
  final int absent;
  final int excused;
  final int unmarked;
  final List<String> coveredBy;
  final List<RosterEntry> roster;

  factory SupervisedHalaqa.fromJson(Map<String, dynamic> j) => SupervisedHalaqa(
        instructorId: _text(j['instructorId']),
        instructorName: _text(j['instructorName'], 'أستاذ'),
        students: _int(j['students']),
        recorded: j['recorded'] == true,
        recordedAt: _str(j['recordedAt']),
        lagDays: _intOrNull(j['lagDays']),
        markedByName: _str(j['markedByName']),
        byOther: j['byOther'] == true,
        present: _int(j['present']),
        lateCount: _int(j['late']),
        absent: _int(j['absent']),
        excused: _int(j['excused']),
        unmarked: _int(j['unmarked']),
        coveredBy: (j['coveredBy'] is List)
            ? (j['coveredBy'] as List).map((e) => e.toString()).toList(growable: false)
            : const [],
        roster: _maps(j['roster'])
            .map(RosterEntry.fromJson)
            .toList(growable: false),
      );
}

/// `GET /supervisor/day` — one meeting day across every حلقة.
class SupervisedDay {
  const SupervisedDay({
    this.course,
    this.date,
    this.kind,
    required this.halaqas,
    this.message,
  });

  final CourseRef? course;

  /// null when the course has no recorded session yet.
  final String? date;
  final DayKind? kind;

  /// Unrecorded first, then by name.
  final List<SupervisedHalaqa> halaqas;
  final String? message;

  factory SupervisedDay.fromJson(Map<String, dynamic> j) => SupervisedDay(
        course: CourseRef.fromJson(j['course']),
        date: _str(j['date']),
        kind: dayKindFromServer(j['kind']),
        halaqas: _maps(j['halaqas'])
            .map(SupervisedHalaqa.fromJson)
            .toList(growable: false),
        message: _str(j['message']),
      );
}

// ═══════════════════════════════════════════════════════════════════════════
// Inside one حلقة — what the أستاذ's own screens show, read-only.
// ═══════════════════════════════════════════════════════════════════════════

double _double(dynamic v) {
  if (v is num) return v.toDouble();
  if (v is String) return double.tryParse(v) ?? 0;
  return 0;
}

/// One student of the حلقة, as the أستاذ's dashboard shows him, plus the
/// points he gained and the points deducted from him in the course.
class RosterStudent {
  const RosterStudent({
    required this.studentId,
    required this.fullName,
    required this.fatherName,
    this.school,
    this.grade,
    required this.pagesMemorized,
    required this.percentage,
    required this.pointsBalance,
    required this.pointsGained,
    required this.pointsDeducted,
    this.mosqueRank,
    this.lastRating,
    this.lastSurahName,
    this.lastDate,
    this.homework,
    this.lastAttendanceDate,
  });

  final String studentId;
  final String fullName;
  final String fatherName;
  final String? school;
  final String? grade;
  final double pagesMemorized;
  final double percentage;
  final double pointsBalance;
  final double pointsGained;

  /// Negative or zero, as stored (−7 = one absence and one late).
  final double pointsDeducted;
  final int? mosqueRank;
  final String? lastRating;
  final String? lastSurahName;
  final String? lastDate;
  final String? homework;
  final String? lastAttendanceDate;

  factory RosterStudent.fromJson(Map<String, dynamic> j) => RosterStudent(
        studentId: _text(j['studentId']),
        fullName: _text(j['fullName'], 'طالب'),
        fatherName: _text(j['fatherName']),
        school: _blankToNull(j['school']),
        grade: _blankToNull(j['grade']),
        pagesMemorized: _double(j['totalPagesMemorized']),
        percentage: _double(j['overallPercentage']),
        pointsBalance: _double(j['pointsBalance']),
        pointsGained: _double(j['pointsGained']),
        pointsDeducted: _double(j['pointsDeducted']),
        mosqueRank: _intOrNull(j['mosqueRank']),
        lastRating: _str(j['lastRating']),
        lastSurahName: _str(j['lastSurahName']),
        lastDate: _str(j['lastDate']),
        homework: _blankToNull(j['homework']),
        lastAttendanceDate: _str(j['lastAttendanceDate']),
      );
}

String? _blankToNull(dynamic v) {
  final s = v?.toString().trim();
  return s == null || s.isEmpty ? null : s;
}

/// `GET /supervisor/instructor/:id/roster`
class RosterResult {
  const RosterResult({this.course, required this.students});

  final CourseRef? course;
  final List<RosterStudent> students;

  factory RosterResult.fromJson(Map<String, dynamic> j) => RosterResult(
        course: CourseRef.fromJson(j['course']),
        students: _maps(j['data']).map(RosterStudent.fromJson).toList(growable: false),
      );
}

/// One thing a student recited: a passage of the Quran or a Nawawi hadith.
class RecitationItem {
  const RecitationItem({
    required this.isHadith,
    required this.id,
    required this.date,
    required this.studentId,
    required this.studentName,
    required this.fatherName,
    required this.suraNames,
    this.startSurah,
    this.startAya,
    this.endSurah,
    this.endAya,
    required this.isCompleteSura,
    required this.pages,
    this.rating,
    this.homework,
    required this.points,
    this.recordedBy,
    this.hadithNumber,
    this.hadithTitle,
  });

  final bool isHadith;
  final String id;
  final String date;
  final String studentId;
  final String studentName;
  final String fatherName;
  final List<String> suraNames;
  final int? startSurah;
  final int? startAya;
  final int? endSurah;
  final int? endAya;
  final bool isCompleteSura;
  final double pages;
  final String? rating;
  final String? homework;
  final double points;
  final String? recordedBy;
  final int? hadithNumber;
  final String? hadithTitle;

  factory RecitationItem.fromJson(Map<String, dynamic> j) => RecitationItem(
        isHadith: j['kind'] == 'HADITH',
        id: _text(j['id']),
        date: _text(j['date']),
        studentId: _text(j['studentId']),
        studentName: _text(j['studentName'], 'طالب'),
        fatherName: _text(j['fatherName']),
        suraNames: (j['suraNames'] is List)
            ? (j['suraNames'] as List).map((e) => e.toString()).toList(growable: false)
            : const [],
        startSurah: _intOrNull(j['startSurah']),
        startAya: _intOrNull(j['startAya']),
        endSurah: _intOrNull(j['endSurah']),
        endAya: _intOrNull(j['endAya']),
        isCompleteSura: j['isCompleteSura'] == true,
        pages: _double(j['pages']),
        rating: _str(j['rating']),
        homework: _blankToNull(j['homework']),
        points: _double(j['points']),
        recordedBy: _str(j['recordedBy']),
        hadithNumber: _intOrNull(j['hadithNumber']),
        hadithTitle: _str(j['hadithTitle']),
      );
}

/// `GET /supervisor/instructor/:id/recitations`
class RecitationsResult {
  const RecitationsResult({this.course, required this.from, required this.to, required this.items});

  final CourseRef? course;
  final String from;
  final String to;
  final List<RecitationItem> items;

  factory RecitationsResult.fromJson(Map<String, dynamic> j) => RecitationsResult(
        course: CourseRef.fromJson(j['course']),
        from: _text(j['from']),
        to: _text(j['to']),
        items: _maps(j['data']).map(RecitationItem.fromJson).toList(growable: false),
      );
}

/// The أستاذ's own presence on a day, as the administration recorded it.
class PresenceDay {
  const PresenceDay({required this.date, required this.present, this.notes});

  final String date;
  final bool present;
  final String? notes;

  factory PresenceDay.fromJson(Map<String, dynamic> j) => PresenceDay(
        date: _text(j['date']),
        present: j['present'] == true,
        notes: _blankToNull(j['notes']),
      );
}

/// A course director's login, as the admin manages it.
class SupervisorAccount {
  const SupervisorAccount({
    required this.id,
    required this.username,
    required this.isActive,
    this.lastLogin,
  });

  final String id;
  final String username;
  final bool isActive;
  final String? lastLogin;

  factory SupervisorAccount.fromJson(Map<String, dynamic> j) => SupervisorAccount(
        id: _text(j['id']),
        username: _text(j['username']),
        isActive: j['isActive'] == true,
        lastLogin: _str(j['lastLogin']),
      );
}
