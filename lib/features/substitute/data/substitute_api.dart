import 'package:dio/dio.dart';
import '../../../core/network/api_client.dart';
import 'substitute_models.dart';

/// The server predates `/substitute` (the route answers 404 "Cannot GET").
/// «حلقات أخرى» then simply does not appear, exactly as the statistics
/// cards do not: an older server must never produce an error the instructor
/// has to make sense of.
class SubstituteUnavailable implements Exception {
  const SubstituteUnavailable();

  @override
  String toString() => 'التسجيل بالنيابة يظهر بعد تحديث الخادم';
}

/// Any other failure, with a message ready to show.
class SubstituteError implements Exception {
  const SubstituteError(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  @override
  String toString() => message;
}

/// «حلقات أخرى» — `/substitute/*`.
///
/// Recording itself does not go through here: the sheet and the mark routes
/// are the ordinary ones (`/attendance/sheet?instructorId=…`,
/// `/attendance/mark`), which already accept another حلقة's students and
/// already store the substitute as the recorder.
class SubstituteApi {
  SubstituteApi(this._client);

  final ApiClient _client;

  /// Every حلقة but the caller's own and «عزل», with the day's counters.
  /// [date] absent → today on the server, in Damascus time.
  Future<OtherHalaqasResult> getHalaqas({String? date}) async {
    final body = await _get('/substitute/halaqas', {'date': ?date});
    return OtherHalaqasResult.fromJson(body);
  }

  /// One حلقة's students — names only.
  Future<HalaqaRoster> getRoster(
    String instructorId, {
    String? date,
    int? termId,
  }) async {
    final body = await _get('/substitute/roster', {
      'instructorId': instructorId,
      'date': ?date,
      'termId': ?termId,
    });
    return HalaqaRoster.fromJson(body);
  }

  /// «استلمت هالحلقة اليوم». Claiming twice is the same fact — the server
  /// upserts — so the button never needs to guard against a double tap.
  Future<Coverage> claim(
    String halaqaInstructorId, {
    String? date,
    String? note,
  }) async {
    final body = await _post('/substitute/coverage', {
      'halaqaInstructorId': halaqaInstructorId,
      'date': ?date,
      'note': ?note,
    });
    final coverage = body['coverage'];
    if (coverage is Map) {
      return Coverage.fromJson(Map<String, dynamic>.from(coverage));
    }
    throw const SubstituteError('استجابة غير متوقعة من الخادم');
  }

  /// Undo the claim. The attendance already recorded is not touched —
  /// removing a mark is «إلغاء التسجيل» on the sheet itself.
  Future<void> release(String halaqaInstructorId, {String? date}) async {
    await _post('/substitute/coverage/release', {
      'halaqaInstructorId': halaqaInstructorId,
      'date': ?date,
    });
  }

  /// The day's claims: an instructor's own, or — for an admin — all of them.
  Future<List<Coverage>> getCoverage({String? date}) async {
    final body = await _get('/substitute/coverage', {'date': ?date});
    final data = body['data'];
    if (data is! List) return const [];
    return data
        .whereType<Map>()
        .map((e) => Coverage.fromJson(Map<String, dynamic>.from(e)))
        .toList(growable: false);
  }

  Future<Map<String, dynamic>> _get(
    String path,
    Map<String, dynamic> query,
  ) async {
    try {
      final res = await _client.get(path, queryParameters: query);
      return _asMap(res.data);
    } on DioException catch (e) {
      throw _map(e);
    }
  }

  Future<Map<String, dynamic>> _post(
    String path,
    Map<String, dynamic> body,
  ) async {
    try {
      final res = await _client.post(path, data: body);
      return _asMap(res.data);
    } on DioException catch (e) {
      throw _map(e);
    }
  }

  Map<String, dynamic> _asMap(dynamic data) {
    if (data is Map) return Map<String, dynamic>.from(data);
    throw const SubstituteError('استجابة غير متوقعة من الخادم');
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
    // An unknown route ("Cannot GET /api/v1/substitute/…") means an older
    // server, not a missing حلقة.
    if ((status == 404 || status == 405) &&
        (serverMessage == null || serverMessage.startsWith('Cannot '))) {
      return const SubstituteUnavailable();
    }
    if (serverMessage != null && serverMessage.isNotEmpty) {
      return SubstituteError(serverMessage, statusCode: status);
    }
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.receiveTimeout:
        return const SubstituteError('انتهت مهلة الاتصال');
      case DioExceptionType.connectionError:
        return const SubstituteError('لا يمكن الاتصال بالخادم');
      default:
        return SubstituteError('حدث خطأ في الخادم', statusCode: status);
    }
  }
}
