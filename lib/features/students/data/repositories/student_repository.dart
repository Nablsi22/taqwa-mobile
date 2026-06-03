import 'package:dio/dio.dart';
import '../../../../core/constants/api_constants.dart';
import '../../../../core/network/api_client.dart';
import '../models/student_model.dart';

class StudentRepository {
  final ApiClient _apiClient;

  StudentRepository({required ApiClient apiClient}) : _apiClient = apiClient;

  Future<({List<StudentModel> students, int total})> getStudents({
    String? search,
    String? instructorId,
    int page = 1,
    int limit = 20,
  }) async {
    try {
      final queryParams = <String, dynamic>{
        'page': page.toString(),
        'limit': limit.toString(),
      };
      if (search != null && search.isNotEmpty) {
        queryParams['search'] = search;
      }
      if (instructorId != null) {
        queryParams['instructorId'] = instructorId;
      }

      final response = await _apiClient.get(
        ApiConstants.students,
        queryParameters: queryParams,
      );

      final data = response.data['data'] as List;
      final total = response.data['meta']['total'] as int;

      return (
        students: data.map((json) => StudentModel.fromJson(json)).toList(),
        total: total,
      );
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<StudentModel> getStudent(String id) async {
    try {
      final response = await _apiClient.get('${ApiConstants.students}/$id');
      return StudentModel.fromJson(response.data);
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<StudentModel> createStudent(Map<String, dynamic> data) async {
    try {
      final response = await _apiClient.post(
        ApiConstants.students,
        data: data,
      );
      return StudentModel.fromJson(response.data);
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<StudentModel> updateStudent(String id, Map<String, dynamic> data) async {
    try {
      final response = await _apiClient.put(
        '${ApiConstants.students}/$id',
        data: data,
      );
      return StudentModel.fromJson(response.data);
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<void> deleteStudent(String id) async {
    try {
      await _apiClient.delete('${ApiConstants.students}/$id');
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
        if (statusCode == 404) return 'الطالب غير موجود';
        if (statusCode == 400) return 'بيانات غير صحيحة';
        if (statusCode == 401) return 'غير مصرح';
        return 'حدث خطأ في الخادم';
      default:
        return 'حدث خطأ غير متوقع';
    }
  }
}