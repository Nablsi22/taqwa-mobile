import 'package:dio/dio.dart';
import '../../../../core/constants/api_constants.dart';
import '../../../../core/network/api_client.dart';
import '../models/attendance_sheet_model.dart';

class AttendanceRepository {
  final ApiClient _apiClient;

  AttendanceRepository({required ApiClient apiClient}) : _apiClient = apiClient;

  /// Get attendance sheet for a date (all students with status)
  Future<AttendanceSheetModel> getSheet(String date, {String? instructorId}) async {
    try {
      final params = <String, dynamic>{'date': date};
      if (instructorId != null) params['instructorId'] = instructorId;

      final response = await _apiClient.get(
        ApiConstants.attendanceSheet,
        queryParameters: params,
      );

      // Explicit cast to ensure correct type resolution
      final Map<String, dynamic> data = response.data is Map<String, dynamic>
          ? response.data as Map<String, dynamic>
          : Map<String, dynamic>.from(response.data as Map);

      return AttendanceSheetModel.fromJson(data);
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  /// Mark attendance for multiple students
  Future<void> markAttendance({
    required String date,
    required List<Map<String, dynamic>> entries,
  }) async {
    try {
      await _apiClient.post(
        ApiConstants.attendanceMark,
        data: {
          'date': date,
          'entries': entries,
        },
      );
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  /// Get stats for a date
  Future<Map<String, dynamic>> getStats(String date) async {
    try {
      final response = await _apiClient.get(
        ApiConstants.attendanceStats,
        queryParameters: {'date': date},
      );
      return response.data as Map<String, dynamic>;
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  String _handleError(DioException e) {
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.receiveTimeout:
        return 'انتهت مهلة الاتصال';
      case DioExceptionType.connectionError:
        return 'لا يمكن الاتصال بالخادم';
      case DioExceptionType.badResponse:
        final statusCode = e.response?.statusCode;
        if (statusCode == 400) return 'بيانات غير صحيحة';
        if (statusCode == 401) return 'غير مصرح';
        return 'حدث خطأ في الخادم';
      default:
        return 'حدث خطأ غير متوقع';
    }
  }
}
