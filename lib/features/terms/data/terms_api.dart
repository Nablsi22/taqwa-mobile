import 'package:dio/dio.dart';
import '../../../core/network/api_client.dart';
import 'term_model.dart';

/// `/api/v1/terms` — courses (دورات).
///
/// Reads are open to ADMIN and INSTRUCTOR; every mutation is ADMIN-only and
/// enforced server-side, so a non-admin simply never sees the buttons.
class TermsApi {
  final ApiClient _client;
  TermsApi(this._client);

  /// Every course, active first then newest, each with its counters.
  Future<List<Term>> getTerms() async {
    try {
      final response = await _client.get('/terms');
      final data = (response.data['data'] as List?) ?? const [];
      return data
          .map((e) => Term.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList(growable: false);
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  /// The currently active course, or `null` when none is activated yet.
  /// A 404 here is a legitimate state, not a failure.
  Future<Term?> getActiveTerm() async {
    try {
      final response = await _client.get('/terms/active');
      final data = response.data['data'];
      if (data == null) return null;
      return Term.fromJson(Map<String, dynamic>.from(data as Map));
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) return null;
      throw _handleError(e);
    }
  }

  Future<Map<String, dynamic>> getTermStats(int termId) async {
    try {
      final response = await _client.get('/terms/$termId/stats');
      return Map<String, dynamic>.from(response.data['data'] as Map);
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  /// Create a course. [activateNow] closes the running course and starts this
  /// one — which does NOT delete or reset anything: past points stay where
  /// they are and the new course simply starts with none.
  Future<Term> createTerm({
    required String name,
    required String nameAr,
    required DateTime startDate,
    DateTime? endDate,
    bool activateNow = false,
  }) async {
    try {
      final response = await _client.post('/terms', data: {
        'name': name,
        'nameAr': nameAr,
        'startDate': _isoDate(startDate),
        if (endDate != null) 'endDate': _isoDate(endDate),
        'isActive': activateNow,
      });
      return Term.fromJson(
        Map<String, dynamic>.from(response.data['data'] as Map),
      );
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<Term> updateTerm(
    int termId, {
    String? nameAr,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    try {
      final response = await _client.patch('/terms/$termId', data: {
        if (nameAr != null) 'nameAr': nameAr,
        if (startDate != null) 'startDate': _isoDate(startDate),
        if (endDate != null) 'endDate': _isoDate(endDate),
      });
      return Term.fromJson(
        Map<String, dynamic>.from(response.data['data'] as Map),
      );
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  /// Make [termId] the active course. Atomic server-side: the previously
  /// active course is closed in the same transaction.
  Future<Term> activateTerm(int termId) async {
    try {
      final response = await _client.patch('/terms/$termId/activate');
      return Term.fromJson(
        Map<String, dynamic>.from(response.data['data'] as Map),
      );
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  static String _isoDate(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';

  String _handleError(DioException e) {
    final data = e.response?.data;
    if (data is Map && data['message'] != null) {
      final msg = data['message'];
      if (msg is List) return msg.join('\n');
      return msg.toString();
    }
    switch (e.response?.statusCode) {
      case 400:
        return 'بيانات غير صالحة';
      case 401:
      case 403:
        return 'غير مصرح بهذا الإجراء';
      case 404:
        return 'الدورة غير موجودة';
      case null:
        return 'خطأ في الاتصال بالخادم';
      default:
        return 'حدث خطأ في الخادم';
    }
  }
}
