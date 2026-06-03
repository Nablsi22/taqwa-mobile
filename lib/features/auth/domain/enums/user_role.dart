enum UserRole {
  admin('ADMIN'),
  instructor('INSTRUCTOR'),
  student('STUDENT');

  final String value;
  const UserRole(this.value);

  static UserRole fromString(String role) {
    return UserRole.values.firstWhere(
      (e) => e.value == role.toUpperCase(),
      orElse: () => UserRole.student,
    );
  }

  // Arabic display names
  String get displayNameAr {
    switch (this) {
      case UserRole.admin:
        return 'مدير';
      case UserRole.instructor:
        return 'معلم';
      case UserRole.student:
        return 'طالب';
    }
  }
}