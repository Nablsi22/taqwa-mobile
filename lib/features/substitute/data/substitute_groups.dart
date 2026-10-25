import 'dart:convert';

import '../../../core/storage/secure_storage_service.dart';

/// «طلابي من هذه الحلقة اليوم» — which of an absent teacher's students
/// came to *this* substitute.
///
/// An absent teacher's students are often shared out: some sit with one
/// teacher, some with another. Each substitute picks the ones in front of
/// him, and from then on the attendance sheet and the student list of that
/// حلقة show those students first, and the bulk buttons («الكل حاضر»…)
/// touch only them — never a student another teacher is recording.
///
/// Kept on this phone only, for one day: tomorrow the groups start empty
/// again. Nothing is sent to the server, so this works with any server
/// version and changes nothing for anyone else.
class SubstituteGroups {
  SubstituteGroups._();

  static const _key = 'substitute_groups_v1';

  static final SecureStorageService _storage = SecureStorageService();

  /// The students this substitute has from [halaqaInstructorId] on [date],
  /// or null when he has not chosen — the whole حلقة.
  static Future<Set<String>?> read(String halaqaInstructorId, String date) async {
    final all = await _readDay(date);
    final ids = all[halaqaInstructorId];
    return ids == null || ids.isEmpty ? null : ids;
  }

  /// Every group chosen on [date], keyed by the absent teacher's id.
  static Future<Map<String, Set<String>>> readAll(String date) => _readDay(date);

  /// Saves the choice. Null or empty → back to the whole حلقة.
  static Future<void> write(
    String halaqaInstructorId,
    String date,
    Set<String>? studentIds,
  ) async {
    final all = await _readDay(date);
    if (studentIds == null || studentIds.isEmpty) {
      all.remove(halaqaInstructorId);
    } else {
      all[halaqaInstructorId] = studentIds;
    }
    if (all.isEmpty) {
      await _storage.deleteSetting(_key);
      return;
    }
    await _storage.writeSetting(
      _key,
      jsonEncode({
        'date': date,
        'groups': {
          for (final e in all.entries) e.key: e.value.toList(growable: false),
        },
      }),
    );
  }

  /// The stored groups if they belong to [date]; an earlier day's are
  /// simply ignored (and replaced on the next write).
  static Future<Map<String, Set<String>>> _readDay(String date) async {
    final raw = await _storage.readSetting(_key);
    if (raw == null || raw.isEmpty) return {};
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map || decoded['date'] != date) return {};
      final groups = decoded['groups'];
      if (groups is! Map) return {};
      return {
        for (final e in groups.entries)
          if (e.value is List)
            e.key.toString(): (e.value as List).map((v) => v.toString()).toSet(),
      };
    } catch (_) {
      return {};
    }
  }
}
