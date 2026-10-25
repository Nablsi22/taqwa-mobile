import '../../../core/utils/meeting_days.dart';

// ═══════════════════════════════════════════════════════════════════════════
// Read models for GET /substitute/* — «حلقات أخرى».
//
// Coerced defensively like the attendance-stats models: a field an older
// server does not send yields a neutral value instead of throwing.
//
// What the mosque agreed, and what these models therefore carry:
//   • a substitute picks another حلقة and sees names only — no points, no
//     progress, no contact details;
//   • the student stays in his own حلقة, so nothing here reassigns anybody;
//   • «استلمت هالحلقة اليوم» is a note about one day, so the 9 pm reminder
//     asks the substitute and not only the absent teacher;
//   • several substitutes can share one حلقة on one day.
// ═══════════════════════════════════════════════════════════════════════════

int _int(dynamic v) {
  if (v is int) return v;
  if (v is num) return v.toInt();
  if (v is String) return int.tryParse(v) ?? 0;
  return 0;
}

bool _bool(dynamic v) {
  if (v is bool) return v;
  if (v is num) return v != 0;
  if (v is String) return v == 'true' || v == '1';
  return false;
}

String? _str(dynamic v) => v?.toString();

String _text(dynamic v, [String fallback = '']) =>
    v == null ? fallback : v.toString();

List<Map<String, dynamic>> _maps(dynamic v) => v is List
    ? v.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList()
    : const <Map<String, dynamic>>[];

/// An instructor who claimed a حلقة for the day.
class CoveringInstructor {
  const CoveringInstructor({required this.instructorId, required this.name});

  final String instructorId;
  final String name;

  factory CoveringInstructor.fromJson(Map<String, dynamic> j) =>
      CoveringInstructor(
        instructorId: _text(j['instructorId']),
        name: _text(j['instructorName'], 'أستاذ'),
      );
}

/// One row of the «حلقات أخرى» picker.
class OtherHalaqa {
  const OtherHalaqa({
    required this.instructorId,
    required this.instructorName,
    required this.students,
    required this.recorded,
    required this.unmarked,
    required this.notRecorded,
    required this.coveredByMe,
    required this.coveredBy,
  });

  final String instructorId;
  final String instructorName;
  final int students;

  /// Students of this حلقة already recorded on the day, by anyone.
  final int recorded;
  final int unmarked;

  /// Nothing recorded for the حلقة at all on the day.
  final bool notRecorded;

  /// This instructor already said «استلمت هالحلقة اليوم».
  final bool coveredByMe;

  /// Everyone who claimed it for the day, this instructor included.
  final List<CoveringInstructor> coveredBy;

  /// Everyone who claimed the day except [myInstructorId] — the names the
  /// card shows, since «أنت» is already said by [coveredByMe].
  List<CoveringInstructor> othersCovering(String? myInstructorId) => coveredBy
      .where((c) => c.instructorId != myInstructorId)
      .toList(growable: false);

  factory OtherHalaqa.fromJson(Map<String, dynamic> j) {
    final students = _int(j['students']);
    final recorded = _int(j['recorded']);
    return OtherHalaqa(
      instructorId: _text(j['instructorId']),
      instructorName: _text(j['instructorName'], 'أستاذ'),
      students: students,
      recorded: recorded,
      unmarked: j['unmarked'] == null ? students - recorded : _int(j['unmarked']),
      notRecorded: j['notRecorded'] == null
          ? recorded == 0
          : _bool(j['notRecorded']),
      coveredByMe: _bool(j['coveredByMe']),
      coveredBy: _maps(j['coveredBy'])
          .map(CoveringInstructor.fromJson)
          .toList(growable: false),
    );
  }
}

/// `GET /substitute/halaqas` — every حلقة but mine and «عزل».
class OtherHalaqasResult {
  const OtherHalaqasResult({
    required this.date,
    required this.dayKind,
    required this.halaqas,
  });

  final String date;
  final DayKind? dayKind;
  final List<OtherHalaqa> halaqas;

  factory OtherHalaqasResult.fromJson(Map<String, dynamic> j) =>
      OtherHalaqasResult(
        date: _text(j['date']),
        dayKind: dayKindFromServer(j['dayKind']),
        halaqas: _maps(j['halaqas'])
            .map(OtherHalaqa.fromJson)
            .toList(growable: false),
      );
}

/// A student as a substitute sees him: a name.
class RosterStudent {
  const RosterStudent({
    required this.studentId,
    required this.fullName,
    required this.fatherName,
  });

  final String studentId;
  final String fullName;
  final String fatherName;

  /// «أحمد محمد» — enough to call the roll without opening a file.
  String get displayName =>
      fatherName.isEmpty ? fullName : '$fullName $fatherName';

  factory RosterStudent.fromJson(Map<String, dynamic> j) => RosterStudent(
        studentId: _text(j['studentId']),
        fullName: _text(j['fullName'], 'طالب'),
        fatherName: _text(j['fatherName']),
      );

  /// The shape `MaqraaScreen` and the points screens already expect.
  Map<String, dynamic> toStudentMap() => {
        'studentId': studentId,
        'fullName': fullName,
        'fatherName': fatherName,
      };
}

/// `GET /substitute/roster` — one حلقة, names only.
class HalaqaRoster {
  const HalaqaRoster({
    required this.instructorId,
    required this.instructorName,
    required this.date,
    required this.dayKind,
    required this.coveredByMe,
    required this.students,
  });

  final String instructorId;
  final String instructorName;
  final String date;
  final DayKind? dayKind;
  final bool coveredByMe;
  final List<RosterStudent> students;

  factory HalaqaRoster.fromJson(Map<String, dynamic> j) => HalaqaRoster(
        instructorId: _text(j['instructorId']),
        instructorName: _text(j['instructorName'], 'أستاذ'),
        date: _text(j['date']),
        dayKind: dayKindFromServer(j['dayKind']),
        coveredByMe: _bool(j['coveredByMe']),
        students: _maps(j['students'])
            .map(RosterStudent.fromJson)
            .toList(growable: false),
      );
}

/// One «استلمت هالحلقة اليوم» note.
class Coverage {
  const Coverage({
    required this.halaqaInstructorId,
    required this.halaqaInstructorName,
    required this.coveringInstructorId,
    required this.coveringInstructorName,
    required this.date,
    this.note,
  });

  final String halaqaInstructorId;
  final String halaqaInstructorName;
  final String coveringInstructorId;
  final String coveringInstructorName;
  final String date;
  final String? note;

  factory Coverage.fromJson(Map<String, dynamic> j) => Coverage(
        halaqaInstructorId: _text(j['halaqaInstructorId']),
        halaqaInstructorName: _text(j['halaqaInstructorName'], 'أستاذ'),
        coveringInstructorId: _text(j['coveringInstructorId']),
        coveringInstructorName: _text(j['coveringInstructorName'], 'أستاذ'),
        date: _text(j['date']),
        note: _str(j['note']),
      );
}
