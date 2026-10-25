import 'package:dio/dio.dart';
import '../../../core/network/api_client.dart';
import 'attendance_stats_models.dart';

/// The server predates `/attendance-stats` (the route answers 404 "Cannot
/// GET"). Screens show a short note instead of an error.
class AttendanceStatsUnavailable implements Exception {
  const AttendanceStatsUnavailable();

  @override
  String toString() => 'تظهر هذه الإحصائيات بعد تحديث الخادم';
}

/// Any other failure, with a message ready to show.
class AttendanceStatsError implements Exception {
  const AttendanceStatsError(this.message, {this.statusCode});

  final String message;
  final int? statusCode;
  bool get isNotFound => statusCode == 404;

  @override
  String toString() => message;
}

/// Read-only attendance statistics (`GET /attendance-stats/*`).
///
/// [termId] follows the app-wide convention: null → the active course.
/// Instructors only ever receive their own حلقة on the aggregate routes —
/// the server enforces that, whatever is asked here.
class AttendanceStatsApi {
  AttendanceStatsApi(this._client);

  final ApiClient _client;

  Future<StudentsStatsResult> getStudents({int? termId, String? instructorId}) async {
    final body = await _get('/attendance-stats/students', {
      'termId': ?termId,
      'instructorId': ?instructorId,
    });
    return StudentsStatsResult.fromJson(body);
  }

  /// One day for every visible حلقة. Without [date] the server picks the
  /// last required session that has records («آخر يوم دوام»).
  Future<AttendanceDay> getDay({String? date, int? termId, String? instructorId}) async {
    final body = await _get('/attendance-stats/day', {
      'date': ?date,
      'termId': ?termId,
      'instructorId': ?instructorId,
    });
    return AttendanceDay.fromJson(body);
  }

  Future<StudentStatsResult> getStudent(String studentId, {int? termId}) async {
    final body = await _get('/attendance-stats/student/$studentId', {
      'termId': ?termId,
    });
    return StudentStatsResult.fromJson(body);
  }

  /// [month] is YYYY-MM.
  Future<AttendanceCalendar> getCalendar(String studentId, String month) async {
    final body = await _get('/attendance-stats/student/$studentId/calendar', {
      'month': month,
    });
    return AttendanceCalendar.fromJson(body);
  }

  Future<Map<String, dynamic>> _get(String path, Map<String, dynamic> query) async {
    try {
      final res = await _client.get(path, queryParameters: query);
      final data = res.data;
      if (data is Map) return Map<String, dynamic>.from(data);
      throw const AttendanceStatsError('استجابة غير متوقعة من الخادم');
    } on DioException catch (e) {
      throw _map(e);
    }
  }

  Exception _map(DioException e) {
    final status = e.response?.statusCode;
    final data = e.response?.data;
    String? serverMessage;
    if (data is Map) {
      final m = data['message'];
      if (m is String) serverMessage = m;
      if (m is List && m.isNotEmpty) serverMessage = m.first.toString();
    }
    // An unknown route ("Cannot GET /api/v1/...") means an older server.
    if (status == 404 && (serverMessage == null || serverMessage.startsWith('Cannot '))) {
      return const AttendanceStatsUnavailable();
    }
    if (serverMessage != null && serverMessage.isNotEmpty) {
      return AttendanceStatsError(serverMessage, statusCode: status);
    }
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.receiveTimeout:
        return const AttendanceStatsError('انتهت مهلة الاتصال');
      case DioExceptionType.connectionError:
        return const AttendanceStatsError('لا يمكن الاتصال بالخادم');
      default:
        return AttendanceStatsError('حدث خطأ في الخادم', statusCode: status);
    }
  }
}
