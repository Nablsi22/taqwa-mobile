import '../../domain/enums/user_role.dart';

class UserModel {
  final String id;
  final String username;
  final UserRole role;
  final bool isActive;
  final UserProfile? profile;

  const UserModel({
    required this.id,
    required this.username,
    required this.role,
    this.isActive = true,
    this.profile,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'] as String,
      username: json['username'] as String,
      role: UserRole.fromString(json['role'] as String),
      isActive: json['isActive'] as bool? ?? true,
      profile: json['profile'] != null
          ? UserProfile.fromJson(json['profile'])
          : null,
    );
  }

  /// Get the student or instructor profile ID
  String? get profileId => profile?.id;

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'username': username,
      'role': role.value,
      'isActive': isActive,
    };
  }
}

class UserProfile {
  final String id;
  final String? fullName;
  final String? fatherName;
  final String? instructorId;
  final String? specialty;

  const UserProfile({
    required this.id,
    this.fullName,
    this.fatherName,
    this.instructorId,
    this.specialty,
  });

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      id: json['id'] as String,
      fullName: json['fullName'] as String?,
      fatherName: json['fatherName'] as String?,
      instructorId: json['instructorId'] as String?,
      specialty: json['specialty'] as String?,
    );
  }
}