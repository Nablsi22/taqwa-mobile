enum UserRole {
  admin('ADMIN'),
  instructor('INSTRUCTOR'),
  student('STUDENT'),

  /// Course director: read-only oversight of the instructors.
  /// Has its own screens and its own server routes (/supervisor).
  supervisor('SUPERVISOR');

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
      case UserRole.supervisor:
        return 'مدير الدورة';
    }
  }
}