class StudentModel {
  final String id;
  final String fullName;
  final String fatherName;
  final DateTime dateOfBirth;
  final String? school;
  final String? address;
  final String? phone1;
  final String? phone2;
  final String? grade;
  final String instructorId;

  /// Points are stored as `Decimal(7,3)` on the backend and may arrive
  /// as int, double, or String. Always held as `num` in the Flutter layer.
  final num totalPoints;

  final int attendanceCount;
  final int pointsLogCount;

  const StudentModel({
    required this.id,
    required this.fullName,
    required this.fatherName,
    required this.dateOfBirth,
    required this.instructorId,
    this.school,
    this.address,
    this.phone1,
    this.phone2,
    this.totalPoints = 0,
    this.attendanceCount = 0,
    this.pointsLogCount = 0,
    this.grade,
  });

  /// Safely coerces any JSON-parsed numeric value (int, double, String,
  /// or null) into a [num]. Returns 0 for null/invalid.
  static num _toNum(dynamic v) {
    if (v == null) return 0;
    if (v is num) return v;
    return num.tryParse(v.toString()) ?? 0;
  }

  /// Safely coerces any JSON-parsed numeric value into an [int].
  /// Handles cases where the backend sends decimals for integer fields.
  static int _toInt(dynamic v) {
    if (v == null) return 0;
    if (v is int) return v;
    if (v is num) return v.round();
    return int.tryParse(v.toString()) ?? num.tryParse(v.toString())?.round() ?? 0;
  }

  /// Defensive date parser — tolerates missing or invalid inputs.
  static DateTime _parseDate(dynamic v) {
    if (v is String && v.isNotEmpty) {
      final parsed = DateTime.tryParse(v);
      if (parsed != null) return parsed;
    }
    return DateTime(2010, 1, 1);
  }

  factory StudentModel.fromJson(Map<String, dynamic> json) {
    return StudentModel(
      id: json['id'] as String,
      fullName: json['fullName'] as String,
      fatherName: json['fatherName'] as String? ?? '',
      dateOfBirth: _parseDate(json['dateOfBirth']),
      instructorId: json['instructorId'] as String? ?? '',
      school: json['school'] as String?,
      address: json['address'] as String?,
      phone1: json['phone1'] as String?,
      phone2: json['phone2'] as String?,
      totalPoints: _toNum(json['totalPoints']),
      attendanceCount: _toInt(json['_count']?['attendance']),
      pointsLogCount: _toInt(json['_count']?['pointsLog']),
      grade: json['grade'] as String?,
    );
  }
}