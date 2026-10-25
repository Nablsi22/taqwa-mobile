import 'package:dio/dio.dart';
import '../../../core/network/api_client.dart';

class PointsApi {
  final ApiClient _apiClient;

  PointsApi(this._apiClient);

  // ═══════════════════════════════════════════════════════════════
  // COURSE (دورة) SCOPING
  //
  // Every read below takes an optional [termId]:
  //   null → send nothing → the backend answers with the ACTIVE course
  //   0    → every course (full history)
  //   > 0  → that specific course
  //
  // Omitting it is what the app did before courses had a selector, so a
  // caller that has not been updated keeps behaving exactly as it did.
  // ═══════════════════════════════════════════════════════════════
  static Map<String, dynamic> _withTerm(
    Map<String, dynamic> params,
    int? termId,
  ) {
    if (termId == null) return params;
    return {...params, 'termId': termId};
  }

  // ═══════════════════════════════════════════════════════════════
  // RULES — read manual rules from the rules table (source of truth)
  // ═══════════════════════════════════════════════════════════════

  /// Fetch all manual (non-automatic) point rules. These are the
  /// rules the instructor can apply directly from the award modal.
  Future<List<Map<String, dynamic>>> getManualRules() async {
    try {
      final response = await _apiClient.dio.get('/point-rules/manual');
      final data = response.data['data'] as List? ?? [];
      return data.map((e) => Map<String, dynamic>.from(e)).toList();
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  // ═══════════════════════════════════════════════════════════════
  // CATEGORIES (legacy — kept for backward compat)
  // ═══════════════════════════════════════════════════════════════

  /// Get all active point categories
  Future<List<Map<String, dynamic>>> getCategories() async {
    try {
      final response = await _apiClient.dio.get('/points/categories');
      final data = response.data['data'] as List;
      return data.map((e) => Map<String, dynamic>.from(e)).toList();
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  // ═══════════════════════════════════════════════════════════════
  // AWARD POINTS
  // ═══════════════════════════════════════════════════════════════

  /// New unified manual award endpoint.
  ///
  /// Two mutually exclusive modes:
  ///   1. Pass [ruleId]            → rule-based award (amount locked)
  ///   2. Pass [amount] + [reason] → custom award (reason REQUIRED)
  Future<Map<String, dynamic>> awardManualPoints({
    required String studentId,
    String? ruleId,
    int? amount,
    String? reason,
  }) async {
    if (ruleId == null && (amount == null || reason == null || reason.trim().isEmpty)) {
      throw 'يجب اختيار قاعدة أو إدخال نقاط مخصصة مع السبب';
    }
    if (ruleId != null && (amount != null || (reason != null && reason.trim().isNotEmpty))) {
      throw 'لا يمكن إرسال قاعدة ونقاط مخصصة معاً';
    }

    try {
      final body = <String, dynamic>{'studentId': studentId};
      if (ruleId != null) {
        body['ruleId'] = ruleId;
      } else {
        body['amount'] = amount;
        body['reason'] = reason!.trim();
      }

      final response =
          await _apiClient.dio.post('/points/manual', data: body);
      return response.data;
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  /// LEGACY award endpoint — kept so older callers keep working.
  /// New code should use [awardManualPoints] instead.
  Future<Map<String, dynamic>> awardPoints({
    required String studentId,
    required String categoryId,
    required int amount,
    String? rating,
    String? description,
  }) async {
    try {
      final body = <String, dynamic>{
        'studentId': studentId,
        'categoryId': categoryId,
        'amount': amount,
      };
      if (rating != null) body['rating'] = rating;
      if (description != null && description.isNotEmpty) {
        body['description'] = description;
      }

      final response =
          await _apiClient.dio.post('/points/award', data: body);
      return response.data;
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  // ═══════════════════════════════════════════════════════════════
  // READ
  // ═══════════════════════════════════════════════════════════════

  /// Get points history for a student
  Future<Map<String, dynamic>> getStudentPoints(
    String studentId, {
    int page = 1,
    int limit = 30,
    int? termId,
  }) async {
    try {
      final response = await _apiClient.dio.get(
        '/points/student/$studentId',
        queryParameters:
            _withTerm({'page': page, 'limit': limit}, termId),
      );
      return response.data;
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  /// Rank card for one student: { rank, total, totalPoints }.
  ///
  /// Prefer this over scanning [getLeaderboard]: the server holds the
  /// single ranking implementation, the denominator is every active
  /// student rather than the page size, and a student outside the top
  /// N is still resolved.
  Future<Map<String, dynamic>> getStudentRank(
    String studentId, {
    int? termId,
  }) async {
    try {
      final response = await _apiClient.dio.get(
        '/points/student/$studentId/rank',
        queryParameters: _withTerm(const {}, termId),
      );
      return Map<String, dynamic>.from(response.data as Map);
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  /// Leaderboard for one course. Ranks are computed over that course's points
  /// alone, so a new course opens with everyone on zero.
  Future<List<Map<String, dynamic>>> getLeaderboard({
    int limit = 20,
    int? termId,
  }) async {
    try {
      final response = await _apiClient.dio.get(
        '/points/leaderboard',
        queryParameters: _withTerm({'limit': limit}, termId),
      );
      final data = response.data['data'] as List;
      return data.map((e) => Map<String, dynamic>.from(e)).toList();
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  /// Delete a points log entry
  Future<void> deleteLog(String logId) async {
    try {
      await _apiClient.dio.delete('/points/log/$logId');
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  /// Update a category's default value (admin only)
  Future<void> updateCategory(String id, {int? defaultValue}) async {
    final data = <String, dynamic>{};
    if (defaultValue != null) data['defaultValue'] = defaultValue;
    await _apiClient.dio.put('/points/categories/$id', data: data);
  }

  // ═══════════════════════════════════════════════════════════════
  // ERROR HANDLING
  // ═══════════════════════════════════════════════════════════════
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
        case 404:
          return 'غير موجود';
        default:
          return 'حدث خطأ في الخادم';
      }
    }
    return 'خطأ في الاتصال بالخادم';
  }
}
