import 'package:dio/dio.dart';
import '../../../../core/network/api_client.dart';

/// Announcement API client.
///
/// Uses [ApiClient.dio] directly for all HTTP calls — consistent with
/// [QuranApi] and [PointsApi] patterns used elsewhere in the project.
class AnnouncementApi {
  final ApiClient _client;

  AnnouncementApi(this._client);

  // ── GET all announcements (auto-filtered by backend) ──────────────────────
  Future<List<Map<String, dynamic>>> getAll() async {
    try {
      final response =
          await _client.dio.get('/announcements');
      final data = response.data;

      // Backend returns a direct array from Prisma findMany
      if (data is List) {
        return data
            .map((e) => Map<String, dynamic>.from(e as Map))
            .toList();
      }

      return [];
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  // ── GET single announcement ───────────────────────────────────────────────
  Future<Map<String, dynamic>> getById(String id) async {
    try {
      final response =
          await _client.dio.get('/announcements/$id');
      return Map<String, dynamic>.from(response.data as Map);
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  // ── CREATE announcement ───────────────────────────────────────────────────
  Future<Map<String, dynamic>> create({
    required String title,
    required String body,
    bool pinned = false,
    String? expiresAt,
  }) async {
    try {
      final data = <String, dynamic>{
        'title': title,
        'body': body,
        'pinned': pinned,
      };
      if (expiresAt != null) data['expiresAt'] = expiresAt;

      final response = await _client.dio.post(
        '/announcements',
        data: data,
      );
      return Map<String, dynamic>.from(response.data as Map);
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  // ── UPDATE announcement ───────────────────────────────────────────────────
  Future<Map<String, dynamic>> update(
    String id, {
    String? title,
    String? body,
    bool? pinned,
    String? expiresAt,
  }) async {
    try {
      final data = <String, dynamic>{};
      if (title != null) data['title'] = title;
      if (body != null) data['body'] = body;
      if (pinned != null) data['pinned'] = pinned;
      if (expiresAt != null) data['expiresAt'] = expiresAt;

      final response = await _client.dio.put(
        '/announcements/$id',
        data: data,
      );
      return Map<String, dynamic>.from(response.data as Map);
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  // ── TOGGLE PIN (admin only) ───────────────────────────────────────────────
  Future<void> togglePin(String id) async {
    try {
      await _client.dio.patch('/announcements/$id/pin');
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  // ── DELETE announcement ───────────────────────────────────────────────────
  Future<void> delete(String id) async {
    try {
      await _client.dio.delete('/announcements/$id');
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  // ── GET stats (admin only) ────────────────────────────────────────────────
  Future<Map<String, dynamic>> getStats() async {
    try {
      final response =
          await _client.dio.get('/announcements/stats');
      return Map<String, dynamic>.from(response.data as Map);
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  // ── Error handler ─────────────────────────────────────────────────────────
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
          return 'غير مصرح';
        case 403:
          return 'لا تملك صلاحية لهذا الإجراء';
        case 404:
          return 'الإعلان غير موجود';
        default:
          return 'حدث خطأ في الخادم';
      }
    }
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.receiveTimeout:
        return 'انتهت مهلة الاتصال';
      case DioExceptionType.connectionError:
        return 'لا يمكن الاتصال بالخادم';
      default:
        return 'حدث خطأ غير متوقع';
    }
  }
}
