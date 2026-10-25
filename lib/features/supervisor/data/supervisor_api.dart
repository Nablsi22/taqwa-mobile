import 'package:dio/dio.dart';
import '../../../core/network/api_client.dart';
import '../../attendance_stats/data/attendance_stats_models.dart';
import 'supervisor_models.dart';

/// The server predates `/supervisor` (404 "Cannot GET"). The director's
/// screens then say so in one calm line instead of showing an error.
class SupervisorUnavailable implements Exception {
  const SupervisorUnavailable();

  @override
  String toString() => 'لوحة مدير الدورة تظهر بعد تحديث الخادم';
}

class SupervisorError implements Exception {
  const SupervisorError(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  @override
  String toString() => message;
}

/// The course director's read-only routes (`/supervisor/*`).
///
/// Nothing here writes: the director's role cannot change anything on the
/// server, and this client offers him no way to try.
///
/// [termId] null → the active course, which is what the director looks at.
class SupervisorApi {
  SupervisorApi(this._client);

  final ApiClient _client;

  /// Every حلقة with its recording over the last [sessions] required days,
  /// worst first.
  Future<DisciplineResult> getInstructors({int? termId, int sessions = 4}) async {
    final body = await _get('/supervisor/instructors', {
      'termId': ?termId,
      'sessions': sessions,
    });
    return DisciplineResult.fromJson(body);
  }

  /// One أستاذ: every meeting day of the course, and his students.
  Future<InstructorDetail> getInstructor(String instructorId, {int? termId}) async {
    final body = await _get('/supervisor/instructor/$instructorId', {
      'termId': ?termId,
    });
    return InstructorDetail.fromJson(body);
  }

  /// One meeting day across every حلقة. Without [date] the server picks the
  /// last required session that has records.
  Future<SupervisedDay> getDay({String? date, int? termId}) async {
    final body = await _get('/supervisor/day', {
      'date': ?date,
      'termId': ?termId,
    });
    return SupervisedDay.fromJson(body);
  }

  /// Every student of the course with his classification.
  Future<StudentsStatsResult> getStudents({int? termId}) async {
    final body = await _get('/supervisor/students', {'termId': ?termId});
    return StudentsStatsResult.fromJson(body);
  }

  /// One أستاذ's students as his own dashboard shows them, with points
  /// gained and deducted, school and grade.
  Future<RosterResult> getRoster(String instructorId, {int? termId}) async {
    final body = await _get('/supervisor/instructor/$instructorId/roster', {
      'termId': ?termId,
    });
    return RosterResult.fromJson(body);
  }

  /// What his students recited from [from] to [to] (YYYY-MM-DD). Without
  /// dates: the course's last session day.
  Future<RecitationsResult> getRecitations(
    String instructorId, {
    String? from,
    String? to,
    int? termId,
  }) async {
    final body = await _get('/supervisor/instructor/$instructorId/recitations', {
      'from': ?from,
      'to': ?to,
      'termId': ?termId,
    });
    return RecitationsResult.fromJson(body);
  }

  /// The أستاذ's own presence, as the administration recorded it.
  Future<List<PresenceDay>> getPresence(String instructorId, {int? termId}) async {
    final body = await _get('/supervisor/instructor/$instructorId/presence', {
      'termId': ?termId,
    });
    final data = body['data'];
    return data is List
        ? data.whereType<Map>().map((e) => PresenceDay.fromJson(Map<String, dynamic>.from(e))).toList()
        : const [];
  }

  // ── Director accounts: the admin's side (the server refuses anyone else) ──

  Future<List<SupervisorAccount>> listAccounts() async {
    final body = await _get('/supervisor/accounts', const {});
    final data = body['data'];
    return data is List
        ? data.whereType<Map>().map((e) => SupervisorAccount.fromJson(Map<String, dynamic>.from(e))).toList()
        : const [];
  }

  Future<SupervisorAccount> createAccount({required String username, required String password}) async {
    final body = await _write(() => _client.post('/supervisor/accounts', data: {
          'username': username,
          'password': password,
        }));
    return SupervisorAccount.fromJson(Map<String, dynamic>.from(body['data'] as Map));
  }

  Future<void> setPassword(String accountId, String password) async {
    await _write(() => _client.patch('/supervisor/accounts/$accountId/password', data: {'password': password}));
  }

  Future<void> setActive(String accountId, bool isActive) async {
    await _write(() => _client.patch('/supervisor/accounts/$accountId/active', data: {'isActive': isActive}));
  }

  Future<Map<String, dynamic>> _write(Future<Response> Function() send) async {
    try {
      final res = await send();
      final data = res.data;
      return data is Map ? Map<String, dynamic>.from(data) : const <String, dynamic>{};
    } on DioException catch (e) {
      throw _map(e);
    }
  }

  Future<Map<String, dynamic>> _get(String path, Map<String, dynamic> query) async {
    try {
      final res = await _client.get(path, queryParameters: query);
      final data = res.data;
      if (data is Map) return Map<String, dynamic>.from(data);
      throw const SupervisorError('استجابة غير متوقعة من الخادم');
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
    if (status == 404 && (serverMessage == null || serverMessage.startsWith('Cannot '))) {
      return const SupervisorUnavailable();
    }
    if (status == 403) {
      return const SupervisorError('هذا الحساب لا يملك صلاحية لوحة مدير الدورة', statusCode: 403);
    }
    if (status == 401) {
      return const SupervisorError('انتهت الجلسة، سجّل الدخول من جديد', statusCode: 401);
    }
    if (serverMessage != null && serverMessage.isNotEmpty) {
      return SupervisorError(serverMessage, statusCode: status);
    }
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.receiveTimeout:
        return const SupervisorError('انتهت مهلة الاتصال');
      case DioExceptionType.connectionError:
        return const SupervisorError('لا يمكن الاتصال بالخادم');
      default:
        return SupervisorError('حدث خطأ في الخادم', statusCode: status);
    }
  }
}
