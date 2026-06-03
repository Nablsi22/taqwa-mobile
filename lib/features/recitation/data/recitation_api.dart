import '../../../core/network/api_client.dart';

/// Response envelope for `GET /recitations/student/:id/history`.
///
/// Keeps the legacy [history] list (list of recitation rows) and the new
/// [lastRecitation] session object together so a single API round-trip
/// powers both the history tab and the "آخر تسميع" panel.
///
/// [lastRecitation] mirrors the backend shape exactly — see
/// `RecitationService.buildLastRecitationFor` — and is null when the
/// student has no recitations.
class StudentRecitationsEnvelope {
  final List<Map<String, dynamic>> history;
  final Map<String, dynamic>? lastRecitation;

  const StudentRecitationsEnvelope({
    required this.history,
    required this.lastRecitation,
  });

  factory StudentRecitationsEnvelope.fromJson(Map<String, dynamic> json) {
    final rawHistory = (json['data'] as List?) ?? const [];
    final rawLast = json['lastRecitation'];
    return StudentRecitationsEnvelope(
      history: rawHistory
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList(growable: false),
      lastRecitation:
          rawLast == null ? null : Map<String, dynamic>.from(rawLast as Map),
    );
  }
}

class RecitationApi {
  final ApiClient _client;
  RecitationApi(this._client);

  // ─────────────────────────────────────────────────────────────
  // Sura list (multi-select picker)
  // ─────────────────────────────────────────────────────────────
  Future<List<Map<String, dynamic>>> getSuraList() async {
    final response = await _client.get('/recitations/suras');
    final data = response.data['data'] as List;
    return data.cast<Map<String, dynamic>>();
  }

  // ─────────────────────────────────────────────────────────────
  // Create recitation — LEGACY multi-surah mode
  // ─────────────────────────────────────────────────────────────
  Future<Map<String, dynamic>> createRecitation({
    required String studentId,
    required List<int> surahNumbers,
    required double pagesRecited,
    required String rating,
    required String date,
    String? homework,
  }) async {
    final response = await _client.post('/recitations', data: {
      'studentId': studentId,
      'surahNumbers': surahNumbers,
      'pagesRecited': pagesRecited,
      'rating': rating,
      'date': date,
      if (homework != null && homework.isNotEmpty) 'homework': homework,
    });
    return response.data;
  }

  // ─────────────────────────────────────────────────────────────
  // Phase 2B: Create recitation with aya range (single surah)
  // ─────────────────────────────────────────────────────────────
  Future<Map<String, dynamic>> createAyaRangeRecitation({
    required String studentId,
    required int startSurah,
    required int startAya,
    required int endAya,
    required String rating,
    required String date,
    String? homework,
  }) async {
    final response = await _client.post('/recitations', data: {
      'studentId': studentId,
      'startSurah': startSurah,
      'startAya': startAya,
      'endSurah': startSurah,
      'endAya': endAya,
      'rating': rating,
      'date': date,
      if (homework != null && homework.isNotEmpty) 'homework': homework,
    });
    return response.data;
  }

  // ─────────────────────────────────────────────────────────────
  // Multi-segment batch session — PER-SEGMENT RATINGS
  // ─────────────────────────────────────────────────────────────
  Future<Map<String, dynamic>> createRecitationBatch({
    required String studentId,
    required String date,
    String? rating,
    String? homework,
    required List<Map<String, dynamic>> segments,
  }) async {
    final response = await _client.post('/recitations/batch', data: {
      'studentId': studentId,
      'date': date,
      if (rating != null) 'rating': rating,
      if (homework != null && homework.isNotEmpty) 'homework': homework,
      'segments': segments,
    });
    return Map<String, dynamic>.from(response.data as Map);
  }

  // ─────────────────────────────────────────────────────────────
  // Auto-suggest next aya
  // ─────────────────────────────────────────────────────────────
  Future<Map<String, dynamic>> getNextSuggestion(String studentId) async {
    final response =
        await _client.get('/recitations/student/$studentId/next-suggestion');
    return Map<String, dynamic>.from(response.data as Map);
  }

  // ─────────────────────────────────────────────────────────────
  // Bulk MAQRAA
  // ─────────────────────────────────────────────────────────────
  Future<Map<String, dynamic>> createBulkMaqraa({
    required List<String> studentIds,
    required int surahNumber,
    required String date,
    double pagesRecited = 0,
  }) async {
    final response = await _client.post('/recitations/maqraa', data: {
      'studentIds': studentIds,
      'surahNumber': surahNumber,
      'date': date,
      'pagesRecited': pagesRecited,
    });
    return response.data;
  }

  // ─────────────────────────────────────────────────────────────
  // Instructor overview — entries now include `lastRecitation`
  // (consumed by InstructorDashboardScreen). Existing fields
  // unchanged so this remains source-compatible with any other
  // callers that ignore the new field.
  // ─────────────────────────────────────────────────────────────
  Future<List<Map<String, dynamic>>> getInstructorOverview() async {
    final response = await _client.get('/recitations/overview');
    final data = response.data['data'] as List;
    return data.cast<Map<String, dynamic>>();
  }

  Future<Map<String, dynamic>> getStudentProgress(String studentId) async {
    final response =
        await _client.get('/recitations/student/$studentId/progress');
    return response.data;
  }

  // ─────────────────────────────────────────────────────────────
  // Recitation history — LEGACY method, returns the history array only.
  // Kept untouched for any existing caller. Prefer
  // [getStudentHistoryWithSession] for the instructor detail screen.
  // ─────────────────────────────────────────────────────────────
  Future<List<Map<String, dynamic>>> getStudentHistory(String studentId) async {
    final response =
        await _client.get('/recitations/student/$studentId/history');
    final data = response.data['data'] as List;
    return data.cast<Map<String, dynamic>>();
  }

  // ─────────────────────────────────────────────────────────────
  // D2 NEW — recitation history + last-session envelope, single round-trip.
  // ─────────────────────────────────────────────────────────────
  Future<StudentRecitationsEnvelope> getStudentHistoryWithSession(
    String studentId,
  ) async {
    final response =
        await _client.get('/recitations/student/$studentId/history');
    final raw = Map<String, dynamic>.from(response.data as Map);
    return StudentRecitationsEnvelope.fromJson(raw);
  }

  Future<Map<String, dynamic>> getStudentHomework(String studentId) async {
    final response =
        await _client.get('/recitations/student/$studentId/homework');
    return response.data;
  }
}