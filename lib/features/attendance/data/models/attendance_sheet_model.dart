class AttendanceSheetModel {
  final String date;
  final int totalStudents;
  final int markedCount;
  final int unmarkedCount;
  final List<StudentAttendanceEntry> students;

  const AttendanceSheetModel({
    required this.date,
    required this.totalStudents,
    required this.markedCount,
    required this.unmarkedCount,
    required this.students,
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
    );
  }
}

class StudentAttendanceEntry {
  final String studentId;
  final String fullName;
  final String? status; // PRESENT, LATE, ABSENT, or null
  final String? notes;
  final bool isMarked;

  const StudentAttendanceEntry({
    required this.studentId,
    required this.fullName,
    this.status,
    this.notes,
    required this.isMarked,
  });

  factory StudentAttendanceEntry.fromJson(Map<String, dynamic> json) {
    return StudentAttendanceEntry(
      studentId: json['studentId'] as String,
      fullName: json['fullName'] as String,
      status: json['status'] as String?,
      notes: json['notes'] as String?,
      isMarked: json['isMarked'] as bool,
    );
  }
}