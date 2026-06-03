import 'package:dio/dio.dart';
import '../../../core/network/api_client.dart';
import 'instructor_model.dart';

class InstructorApi {
  final ApiClient _apiClient;

  InstructorApi(this._apiClient);

  Future<Map<String, dynamic>> getInstructors({
    String? search,
    int page = 1,
    int limit = 20,
  }) async {
    try {
      final queryParams = <String, dynamic>{
        'page': page,
        'limit': limit,
      };
      if (search != null && search.isNotEmpty) {
        queryParams['search'] = search;
      }

      final response = await _apiClient.dio.get(
        '/instructors',
        queryParameters: queryParams,
      );

      final data = response.data;
      final instructors = (data['data'] as List)
          .map((json) => InstructorModel.fromJson(json))
          .toList();

      return {
        'instructors': instructors,
        'meta': data['meta'],
      };
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<InstructorDetailModel> getInstructor(String id) async {
    try {
      final response = await _apiClient.dio.get('/instructors/$id');
      return InstructorDetailModel.fromJson(response.data);
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<Map<String, dynamic>> createInstructor({
    required String fullName,
    required String username,
    required String password,
    String? dateOfBirth,
    String? specialty,
    String? address,
    String? mobile,
  }) async {
    try {
      final body = <String, dynamic>{
        'fullName': fullName,
        'username': username,
        'password': password,
      };
      if (dateOfBirth != null && dateOfBirth.isNotEmpty) body['dateOfBirth'] = dateOfBirth;
      if (specialty != null && specialty.isNotEmpty) body['specialty'] = specialty;
      if (address != null && address.isNotEmpty) body['address'] = address;
      if (mobile != null && mobile.isNotEmpty) body['mobile'] = mobile;

      final response = await _apiClient.dio.post(
        '/instructors',
        data: body,
      );
      return response.data;
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<Map<String, dynamic>> updateInstructor(
    String id, {
    String? fullName,
    String? username,
    String? password,
    String? dateOfBirth ,
    String? specialty,
    String? address,
    String? mobile,
  }) async {
    try {
      final data = <String, dynamic>{};
      if (fullName != null) data['fullName'] = fullName;
      if (username != null) data['username'] = username;
      if (password != null && password.isNotEmpty) data['password'] = password;
      if (dateOfBirth != null) data['dateOfBirth'] = dateOfBirth;
      if (specialty != null) data['specialty'] = specialty;
      if (address != null) data['address'] = address;
      if (mobile != null) data['mobile'] = mobile;

      final response = await _apiClient.dio.put(
        '/instructors/$id',
        data: data,
      );
      return response.data;
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<Map<String, dynamic>> deleteInstructor(String id) async {
    try {
      final response = await _apiClient.dio.delete('/instructors/$id');
      return response.data;
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<Map<String, dynamic>> resetPassword(
    String id,
    String newPassword,
  ) async {
    try {
      final response = await _apiClient.dio.post(
        '/instructors/$id/reset-password',
        data: {'password': newPassword},
      );
      return response.data;
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  String _handleError(DioException e) {
    if (e.response != null) {
      final data = e.response!.data;
      if (data is Map && data.containsKey('message')) {
        final msg = data['message'];
        if (msg is List) return msg.join('\n');
        return msg.toString();
      }
      switch (e.response!.statusCode) {
        case 400:
          return 'بيانات غير صالحة';
        case 401:
          return 'غير مصرح بالوصول';
        case 403:
          return 'ليس لديك صلاحية لهذا الإجراء';
        case 404:
          return 'المعلم غير موجود';
        case 409:
          return 'اسم المستخدم مستخدم بالفعل';
        default:
          return 'حدث خطأ في الخادم';
      }
    }
    return 'خطأ في الاتصال بالخادم';
  }
}