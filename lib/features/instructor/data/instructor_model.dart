class InstructorModel {
  final String id;
  final String? userId;
  final String username;
  final String fullName;
  final DateTime? dateOfBirth;
  final String? specialty;
  final String? address;
  final String? mobile;
  final int studentCount;
  final DateTime createdAt;
  final DateTime? updatedAt;

  InstructorModel({
    required this.id,
    this.userId,
    required this.username,
    required this.fullName,
    this.dateOfBirth ,
    this.specialty,
    this.address,
    this.mobile,
    this.studentCount = 0,
    required this.createdAt,
    this.updatedAt,
  });

  factory InstructorModel.fromJson(Map<String, dynamic> json) {
    return InstructorModel(
      id: json['id'] as String,
      userId: json['userId'] as String?,
      username: json['username'] as String? ?? '',
      fullName: json['fullName'] as String,
      dateOfBirth : json['dateOfBirth '] as DateTime?,
      specialty: json['specialty'] as String?,
      address: json['address'] as String?,
      mobile: json['mobile'] as String?,
      studentCount: json['studentCount'] as int? ?? 0,
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: json['updatedAt'] != null
          ? DateTime.parse(json['updatedAt'] as String)
          : null,
    );
  }
}

class InstructorDetailModel extends InstructorModel {
  final List<InstructorStudentInfo> students;

  InstructorDetailModel({
    required super.id,
    super.userId,
    required super.username,
    required super.fullName,
    super.dateOfBirth ,
    super.specialty,
    super.address,
    super.mobile,
    super.studentCount = 0,
    required super.createdAt,
    super.updatedAt,
    required this.students,
  });

  factory InstructorDetailModel.fromJson(Map<String, dynamic> json) {
    return InstructorDetailModel(
      id: json['id'] as String,
      userId: json['userId'] as String?,
      username: json['username'] as String? ?? '',
      fullName: json['fullName'] as String,
      dateOfBirth : json['dateOfBirth '] as DateTime?,
      specialty: json['specialty'] as String?,
      address: json['address'] as String?,
      mobile: json['mobile'] as String?,
      studentCount: json['studentCount'] as int? ?? 0,
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: json['updatedAt'] != null
          ? DateTime.parse(json['updatedAt'] as String)
          : null,
      students: (json['students'] as List<dynamic>?)
              ?.map((s) => InstructorStudentInfo.fromJson(s))
              .toList() ??
          [],
    );
  }
}

class InstructorStudentInfo {
  final String id;
  final String fullName;
  final String? phone1;

  InstructorStudentInfo({
    required this.id,
    required this.fullName,
    this.phone1,
  });

  factory InstructorStudentInfo.fromJson(Map<String, dynamic> json) {
    return InstructorStudentInfo(
      id: json['id'] as String,
      fullName: json['fullName'] as String,
      phone1: json['phone1'] as String?,
    );
  }
}