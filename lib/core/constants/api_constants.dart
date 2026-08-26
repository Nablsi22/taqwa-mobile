class ApiConstants {
  ApiConstants._();

  // Use 'localhost' for web testing, your IP for mobile/APK testing
  static const String baseUrl = 'https://taqwa-backend-production.up.railway.app/api/v1'; 
  static const String login = '/auth/login';
  static const String refresh = '/auth/refresh';
  static const String me = '/auth/me';

  // Student endpoints
  static const String students = '/students';

  // Instructor endpoints
  static const String instructors = '/instructors';

  // Attendance endpoints
  static const String attendanceMark = '/attendance/mark';
  static const String attendanceSheet = '/attendance/sheet';
  static const String attendanceStats = '/attendance/stats';
  static const String attendanceUnmark = '/attendance/unmark';
  static String attendanceStudent(String id) => '/attendance/student/$id';

  // Timeouts
  static const Duration connectTimeout = Duration(seconds: 15);
  static const Duration receiveTimeout = Duration(seconds: 15);
}