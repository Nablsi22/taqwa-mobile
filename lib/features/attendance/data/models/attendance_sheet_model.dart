import '../../../../core/utils/meeting_days.dart';

class AttendanceSheetModel {
  final String date;
  final int totalStudents;
  final int markedCount;
  final int unmarkedCount;
  final List<StudentAttendanceEntry> students;

  /// Kind of day in the active course (null on an older server, or when no
  /// course is active): an optional or make-up day deducts nobody.
  final DayKind? dayKind;

  /// The server understands «غائب بعذر». An older one rejects the field, so
  /// the screen only offers it when this is true.
  final bool supportsExcused;

  const AttendanceSheetModel({
    required this.date,
    required this.totalStudents,
    required this.markedCount,
    required this.unmarkedCount,
    required this.students,
    this.dayKind,
    this.supportsExcused = false,
  });

  factory AttendanceSheetModel.fromJson(Map<String, dynamic> json) {
    return AttendanceSheetModel(
      date: json['date'] as String,
      totalStudents: json['totalStudents'] as int,
      markedCount: json['markedCount'] as int,
      unmarkedCount: json['unmarkedCount'] as int,
      students: (json['students'] as List)
          .map((e) => StudentAttendanceEntry.fromJson(e))
          .toList(),
      dayKind: dayKindFromServer(json['dayKind']),
      supportsExcused: json['supportsExcused'] == true,
    );
  }
}

class StudentAttendanceEntry {
  final String studentId;
  final String fullName;
  final String? status; // PRESENT, LATE, ABSENT, or null
  final bool excused; // «غائب بعذر» — only ever true with ABSENT
  final String? notes;
  final bool isMarked;

  const StudentAttendanceEntry({
    required this.studentId,
    required this.fullName,
    this.status,
    this.excused = false,
    this.notes,
    required this.isMarked,
  });

  /// The status the screen works with: ABSENT + excused reads as EXCUSED.
  String? get effectiveStatus => status == 'ABSENT' && excused ? 'EXCUSED' : status;

  factory StudentAttendanceEntry.fromJson(Map<String, dynamic> json) {
    return StudentAttendanceEntry(
      studentId: json['studentId'] as String,
      fullName: json['fullName'] as String,
      status: json['status'] as String?,
      excused: json['excused'] == true,
      notes: json['notes'] as String?,
      isMarked: json['isMarked'] as bool,
    );
  }
}
