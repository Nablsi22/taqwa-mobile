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

// ─────────────────────────────────────────────────────────────────
// Defensive numeric coercion. Backend numbers can arrive as `num`
// (JSON number) or `String` — Prisma `Decimal` fields (e.g. points_log
// `amount`) serialize as strings. Never raw-cast these.
// ─────────────────────────────────────────────────────────────────
num _toNum(dynamic v) {
  if (v is num) return v;
  if (v is String) return num.tryParse(v) ?? 0;
  return 0;
}

int _toInt(dynamic v) {
  if (v is int) return v;
  if (v is num) return v.toInt();
  if (v is String) return int.tryParse(v) ?? (num.tryParse(v)?.toInt() ?? 0);
  return 0;
}

/// One row of `GET /recitations/hadith/rules` — a Nawawi-40 hadith and the
/// base points it awards. Mirrors backend `HadithPointsRule`.
class HadithRule {
  final int hadithNumber;
  final int basePoints;
  final String? title;

  const HadithRule({
    required this.hadithNumber,
    required this.basePoints,
    this.title,
  });

  factory HadithRule.fromJson(Map<String, dynamic> json) {
    return HadithRule(
      hadithNumber: _toInt(json['hadithNumber']),
      basePoints: _toInt(json['basePoints']),
      title: json['title'] as String?,
    );
  }
}

/// Result of `POST /recitations/hadith`. [data] is the inserted
/// `hadith_recitations` row; [pointsAwarded] is the snapshotted base points
/// (parsed defensively — may arrive as String or num).
class HadithRecitationResult {
  final Map<String, dynamic> data;
  final num pointsAwarded;
  final String? message;

  const HadithRecitationResult({
    required this.data,
    required this.pointsAwarded,
    this.message,
  });

  factory HadithRecitationResult.fromJson(Map<String, dynamic> json) {
    final rawData = json['data'];
    return HadithRecitationResult(
      data: rawData == null
          ? const {}
          : Map<String, dynamic>.from(rawData as Map),
      pointsAwarded: _toNum(json['pointsAwarded']),
      message: json['message'] as String?,
    );
  }
}

/// Nawawi-40 memorization map for one student, from
/// `GET /recitations/student/:id/hadith-progress`.
///
/// CUMULATIVE across terms — a hadith recorded in any term counts as
/// memorized forever (mirrors the backend's UNIQUE(student_id,
/// hadith_number) constraint, which is not term-scoped).
class HadithProgress {
  /// Hadith numbers (1–42) already recorded for this student, ascending.
  final Set<int> memorized;

  /// Convenience counters — [count] == memorized.length, [total] == 42.
  final int count;
  final int total;

  const HadithProgress({
    required this.memorized,
    required this.count,
    required this.total,
  });

  /// Empty progress — safe fallback when the fetch fails so the picker
  /// can still open (with no checkmarks) instead of blocking recording.
  const HadithProgress.empty()
      : memorized = const <int>{},
        count = 0,
        total = 42;

  bool isMemorized(int hadithNumber) => memorized.contains(hadithNumber);

  factory HadithProgress.fromJson(Map<String, dynamic> json) {
    final rawList = (json['memorized'] as List?) ?? const [];
    final memorized = rawList.map(_toInt).toSet();
    return HadithProgress(
      memorized: memorized,
      count: _toInt(json['count'] ?? memorized.length),
      total: _toInt(json['total'] ?? 42),
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

  // ─────────────────────────────────────────────────────────────
  // Nawawi 40 Hadith — record one recitation
  // ─────────────────────────────────────────────────────────────
  Future<HadithRecitationResult> recordHadithRecitation({
    required String studentId,
    required int hadithNumber,
  }) async {
    final response = await _client.post('/recitations/hadith', data: {
      'studentId': studentId,
      'hadithNumber': hadithNumber,
    });
    return HadithRecitationResult.fromJson(
      Map<String, dynamic>.from(response.data as Map),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // Nawawi 40 Hadith — memorization map (cumulative across terms)
  // ─────────────────────────────────────────────────────────────
  Future<HadithProgress> getStudentHadithProgress(String studentId) async {
    final response =
        await _client.get('/recitations/student/$studentId/hadith-progress');
    final raw = Map<String, dynamic>.from(response.data as Map);
    final data = raw['data'];
    if (data == null) return const HadithProgress.empty();
    return HadithProgress.fromJson(Map<String, dynamic>.from(data as Map));
  }

  // ─────────────────────────────────────────────────────────────
  // Nawawi 40 Hadith — the 42 point rules, ordered by hadith number
  // ─────────────────────────────────────────────────────────────
  Future<List<HadithRule>> getHadithRules() async {
    final response = await _client.get('/recitations/hadith/rules');
    final data = (response.data['data'] as List?) ?? const [];
    return data
        .map((e) => HadithRule.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList(growable: false);
  }
}