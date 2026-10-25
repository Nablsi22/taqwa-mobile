import '../../../core/utils/meeting_days.dart';

// ═══════════════════════════════════════════════════════════════════════════
// Read models for GET /attendance-stats/*.
//
// Every value is coerced defensively: a field the server does not send yet
// yields a neutral value instead of throwing, so a newer app never crashes
// against an older server.
//
// Rules behind the numbers (decided with the mosque, computed server-side):
//   • a session of a حلقة = a day on which any of its students was recorded;
//     a student is only measured against their own حلقة's sessions, from the
//     day they joined;
//   • only a REQUIRED day (winter Saturday) can be missed; an optional day
//     (winter Thursday) or a make-up day counts only for those who came;
//   • LATE counts as attended; «غائب بعذر» is neutral;
//   • ثابت = missed at most one required session in the last 4 weeks,
//     منقطع = attended nothing in the last 4 weeks.
// ═══════════════════════════════════════════════════════════════════════════

int _int(dynamic v) {
  if (v is int) return v;
  if (v is num) return v.toInt();
  if (v is String) return int.tryParse(v) ?? 0;
  return 0;
}

String? _str(dynamic v) => v?.toString();

String _text(dynamic v, [String fallback = '']) => v == null ? fallback : v.toString();

Map<String, dynamic> _map(dynamic v) =>
    v is Map ? Map<String, dynamic>.from(v) : const <String, dynamic>{};

List<Map<String, dynamic>> _maps(dynamic v) => v is List
    ? v.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList()
    : const <Map<String, dynamic>>[];

/// ثابت / متذبذب / منقطع / no data.
enum AttendanceClass { regular, irregular, inactive, noData }

AttendanceClass attendanceClassFrom(dynamic raw) {
  switch (raw) {
    case 'REGULAR':
      return AttendanceClass.regular;
    case 'IRREGULAR':
      return AttendanceClass.irregular;
    case 'INACTIVE':
      return AttendanceClass.inactive;
    default:
      return AttendanceClass.noData;
  }
}

/// A course as these endpoints describe it.
class CourseRef {
  const CourseRef({
    required this.id,
    required this.nameAr,
    required this.startDate,
    this.endDate,
    required this.isActive,
    required this.meetingDays,
  });

  final int id;
  final String nameAr;
  final String startDate;
  final String? endDate;
  final bool isActive;
  final MeetingDays meetingDays;

  static CourseRef? fromJson(dynamic raw) {
    final j = _map(raw);
    if (j.isEmpty) return null;
    return CourseRef(
      id: _int(j['id']),
      nameAr: _text(j['nameAr'], _text(j['name'])),
      startDate: _text(j['startDate']),
      endDate: _str(j['endDate']),
      isActive: j['isActive'] == true,
      meetingDays: MeetingDays.fromJson(j['meetingDays']),
    );
  }
}

/// Counts over the whole course.
class CourseCounts {
  const CourseCounts({
    this.sessions = 0,
    this.present = 0,
    this.lateCount = 0,
    this.absent = 0,
    this.excused = 0,
    this.unmarked = 0,
  });

  /// Required sessions of the student's حلقة since they joined, plus any
  /// optional/make-up session they attended. Excused sessions are left out.
  final int sessions;
  final int present;
  final int lateCount;

  /// Unexcused absences.
  final int absent;
  final int excused;

  /// Required sessions held by the حلقة where nothing was recorded for them.
  final int unmarked;

  int get attended => present + lateCount;

  factory CourseCounts.fromJson(dynamic raw) {
    final j = _map(raw);
    return CourseCounts(
      sessions: _int(j['sessions']),
      present: _int(j['present']),
      lateCount: _int(j['late']),
      absent: _int(j['absent']),
      excused: _int(j['excused']),
      unmarked: _int(j['unmarked']),
    );
  }
}

/// One student's attendance in one course.
class StudentStats {
  const StudentStats({
    required this.studentId,
    required this.fullName,
    required this.fatherName,
    required this.instructorId,
    required this.instructorName,
    this.school,
    this.grade,
    required this.joined,
    required this.course,
    required this.windowSessions,
    required this.windowAttended,
    required this.classification,
    required this.absentStreak,
    required this.needsCall,
    this.lastAttended,
  });

  final String studentId;
  final String fullName;
  final String fatherName;
  final String instructorId;
  final String instructorName;
  final String? school;
  final String? grade;

  /// First day the student is measured from (YYYY-MM-DD).
  final String joined;
  final CourseCounts course;

  /// Sessions / attendance in the last 4 weeks — what ثابت and منقطع use.
  final int windowSessions;
  final int windowAttended;
  int get windowMissed => windowSessions - windowAttended;

  final AttendanceClass classification;

  /// Consecutive unexcused absences counted back from the latest session.
  final int absentStreak;

  /// Two consecutive absences or more: the instructor should call the family.
  final bool needsCall;
  final String? lastAttended;

  factory StudentStats.fromJson(Map<String, dynamic> j) {
    final window = _map(j['window']);
    return StudentStats(
      studentId: _text(j['studentId']),
      fullName: _text(j['fullName']),
      fatherName: _text(j['fatherName']),
      instructorId: _text(j['instructorId']),
      instructorName: _text(j['instructorName']),
      school: _str(j['school']),
      grade: _str(j['grade']),
      joined: _text(j['joined']),
      course: CourseCounts.fromJson(j['course']),
      windowSessions: _int(window['sessions']),
      windowAttended: _int(window['attended']),
      classification: attendanceClassFrom(j['classification']),
      absentStreak: _int(j['absentStreak']),
      needsCall: j['needsCall'] == true,
      lastAttended: _str(j['lastAttended']),
    );
  }
}

/// GET /attendance-stats/students
class StudentsStatsResult {
  const StudentsStatsResult({
    this.course,
    this.windowStart,
    this.measuredUntil,
    required this.students,
  });

  final CourseRef? course;
  final String? windowStart;
  final String? measuredUntil;
  final List<StudentStats> students;

  factory StudentsStatsResult.fromJson(Map<String, dynamic> j) {
    return StudentsStatsResult(
      course: CourseRef.fromJson(j['course']),
      windowStart: _str(j['windowStart']),
      measuredUntil: _str(j['measuredUntil']),
      students: _maps(j['data']).map(StudentStats.fromJson).toList(),
    );
  }
}

/// GET /attendance-stats/student/:id
class StudentStatsResult {
  const StudentStatsResult({this.course, this.windowStart, required this.student});

  final CourseRef? course;
  final String? windowStart;
  final StudentStats student;

  factory StudentStatsResult.fromJson(Map<String, dynamic> j) {
    return StudentStatsResult(
      course: CourseRef.fromJson(j['course']),
      windowStart: _str(j['windowStart']),
      student: StudentStats.fromJson(_map(j['data'])),
    );
  }
}

/// One student on one day. [status] is PRESENT, LATE, ABSENT, EXCUSED or
/// UNMARKED.
class RosterEntry {
  const RosterEntry({
    required this.studentId,
    required this.fullName,
    required this.fatherName,
    required this.status,
    this.markedBy,
    required this.byOther,
    required this.absences,
    required this.absentStreak,
  });

  final String studentId;
  final String fullName;
  final String fatherName;
  final String status;

  /// Who recorded it (instructor name, or the admin's username).
  final String? markedBy;

  /// Recorded by someone other than the حلقة's own instructor.
  final bool byOther;

  /// Unexcused absences in the whole course so far.
  final int absences;
  final int absentStreak;

  factory RosterEntry.fromJson(Map<String, dynamic> j) {
    return RosterEntry(
      studentId: _text(j['studentId']),
      fullName: _text(j['fullName']),
      fatherName: _text(j['fatherName']),
      status: _text(j['status'], 'UNMARKED'),
      markedBy: _str(j['markedBy']),
      byOther: j['byOther'] == true,
      absences: _int(j['absences']),
      absentStreak: _int(j['absentStreak']),
    );
  }
}

/// One حلقة on one day.
class HalaqaDay {
  const HalaqaDay({
    required this.instructorId,
    required this.instructorName,
    required this.students,
    required this.recorded,
    required this.present,
    required this.lateCount,
    required this.absent,
    required this.excused,
    required this.unmarked,
    required this.notRecorded,
    required this.coveredBy,
    required this.recordedByOthers,
    required this.roster,
  });

  final String instructorId;
  final String instructorName;
  final int students;
  final int recorded;
  final int present;
  final int lateCount;
  final int absent;
  final int excused;
  final int unmarked;

  /// Nothing at all was recorded for this حلقة on the day.
  final bool notRecorded;

  /// Other instructors who recorded some of its students (a substitute).
  final List<String> coveredBy;
  final int recordedByOthers;
  final List<RosterEntry> roster;

  factory HalaqaDay.fromJson(Map<String, dynamic> j) {
    final covered = j['coveredBy'];
    return HalaqaDay(
      instructorId: _text(j['instructorId']),
      instructorName: _text(j['instructorName']),
      students: _int(j['students']),
      recorded: _int(j['recorded']),
      present: _int(j['present']),
      lateCount: _int(j['late']),
      absent: _int(j['absent']),
      excused: _int(j['excused']),
      unmarked: _int(j['unmarked']),
      notRecorded: j['notRecorded'] == true,
      coveredBy: covered is List ? covered.map((e) => e.toString()).toList() : const [],
      recordedByOthers: _int(j['recordedByOthers']),
      roster: _maps(j['roster']).map(RosterEntry.fromJson).toList(),
    );
  }
}

/// GET /attendance-stats/day
class AttendanceDay {
  const AttendanceDay({
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
  final List<HalaqaDay> halaqas;
  final String? message;

  factory AttendanceDay.fromJson(Map<String, dynamic> j) {
    return AttendanceDay(
      course: CourseRef.fromJson(j['course']),
      date: _str(j['date']),
      kind: dayKindFromServer(j['kind']),
      halaqas: _maps(j['halaqas']).map(HalaqaDay.fromJson).toList(),
      message: _str(j['message']),
    );
  }
}

/// One day of the monthly calendar. [status] is one of:
/// PRESENT, LATE, ABSENT, EXCUSED — recorded;
/// UNMARKED — a required session of the حلقة with nothing recorded for him;
/// NOT_ATTENDED — an optional session he did not come to (never a miss);
/// NO_SESSION — the حلقة recorded nobody that day;
/// UPCOMING — not yet; BEFORE_JOIN — before he joined.
class CalendarDay {
  const CalendarDay({
    required this.date,
    required this.weekday,
    required this.kind,
    required this.status,
    this.markedBy,
  });

  final String date;
  final int weekday;
  final DayKind kind;
  final String status;
  final String? markedBy;

  factory CalendarDay.fromJson(Map<String, dynamic> j) {
    return CalendarDay(
      date: _text(j['date']),
      weekday: _int(j['weekday']),
      kind: dayKindFromServer(j['kind']) ?? DayKind.extra,
      status: _text(j['status'], 'NO_SESSION'),
      markedBy: _str(j['markedBy']),
    );
  }
}

/// GET /attendance-stats/student/:id/calendar
class AttendanceCalendar {
  const AttendanceCalendar({
    required this.month,
    required this.instructorName,
    required this.days,
    required this.present,
    required this.lateCount,
    required this.absent,
    required this.excused,
    required this.unmarked,
    required this.optionalAttended,
  });

  /// YYYY-MM
  final String month;
  final String instructorName;
  final List<CalendarDay> days;
  final int present;
  final int lateCount;
  final int absent;
  final int excused;
  final int unmarked;
  final int optionalAttended;

  factory AttendanceCalendar.fromJson(Map<String, dynamic> j) {
    final counts = _map(j['counts']);
    final student = _map(j['student']);
    return AttendanceCalendar(
      month: _text(j['month']),
      instructorName: _text(student['instructorName']),
      days: _maps(j['days']).map(CalendarDay.fromJson).toList(),
      present: _int(counts['present']),
      lateCount: _int(counts['late']),
      absent: _int(counts['absent']),
      excused: _int(counts['excused']),
      unmarked: _int(counts['unmarked']),
      optionalAttended: _int(counts['optionalAttended']),
    );
  }
}
