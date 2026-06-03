import 'package:dio/dio.dart';
import '../../../core/network/api_client.dart';

class QuranApi {
  final ApiClient _apiClient;

  QuranApi(this._apiClient);

  /// Add progress entry (supports didNotMemorize + homework)
  Future<Map<String, dynamic>> addProgress({
    required String studentId,
    int? surahNumber,
    int? pageNumber,
    int? juzNumber,
    String? rating,
    String? notes,
    bool didNotMemorize = false,
    String? homework,
  }) async {
    try {
      final body = <String, dynamic>{
        'studentId': studentId,
      };

      if (didNotMemorize) {
        body['didNotMemorize'] = true;
        if (homework != null && homework.isNotEmpty) {
          body['homework'] = homework;
        }
        if (notes != null && notes.isNotEmpty) body['notes'] = notes;
      } else {
        body['surahNumber'] = surahNumber ?? 1;
        body['pageNumber'] = pageNumber ?? 1;
        body['juzNumber'] = juzNumber ?? 1;
        if (rating != null) body['rating'] = rating;
        if (notes != null && notes.isNotEmpty) body['notes'] = notes;
      }

      final response = await _apiClient.dio.post(
        '/quran/progress',
        data: body,
      );
      return response.data;
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  /// Get student progress history
  Future<Map<String, dynamic>> getStudentProgress(
    String studentId, {
    int page = 1,
    int limit = 30,
  }) async {
    try {
      final response = await _apiClient.dio.get(
        '/quran/student/$studentId',
        queryParameters: {'page': page, 'limit': limit},
      );
      return response.data;
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  /// Get overview of all students progress
  Future<List<Map<String, dynamic>>> getOverview({
    String? instructorId,
  }) async {
    try {
      final params = <String, dynamic>{};
      if (instructorId != null) params['instructorId'] = instructorId;

      final response = await _apiClient.dio.get(
        '/quran/overview',
        queryParameters: params,
      );
      final data = response.data['data'] as List;
      return data.map((e) => Map<String, dynamic>.from(e)).toList();
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
        case 404:
          return 'غير موجود';
        default:
          return 'حدث خطأ في الخادم';
      }
    }
    return 'خطأ في الاتصال بالخادم';
  }
}
