import 'package:flutter/foundation.dart';
import '../../../../core/utils/meeting_days.dart';
import '../../data/models/attendance_sheet_model.dart';
import '../../data/repositories/attendance_repository.dart';

/// Attendance sheet for one حلقة on one day.
///
/// Statuses on screen are PRESENT, LATE, ABSENT and EXCUSED («غائب بعذر»).
/// EXCUSED is not a server status: it is sent as ABSENT with `excused: true`.
/// Nothing is ever recorded automatically — a student nobody tapped stays
/// unrecorded and is not sent.
class AttendanceProvider extends ChangeNotifier {
  final AttendanceRepository _repository;
  final String? instructorId;

  AttendanceSheetModel? _sheet;
  bool _isLoading = false;
  bool _isSaving = false;
  String? _error;
  String _selectedDate = '';

  // Local state: tracks status changes before saving
  final Map<String, String> _localStatuses = {};

  /// «طلابي اليوم» — when a substitute shares an absent teacher's حلقة with
  /// others, the students sitting with him. The bulk actions and the
  /// counters then cover only them. Null → every student of the sheet.
  Set<String>? _scope;

  /// [initialDate] (YYYY-MM-DD) opens the sheet on a given day — the last
  /// meeting day, typically. Omitted → today, as before.
  AttendanceProvider({
    required AttendanceRepository repository,
    this.instructorId,
    String? initialDate,
  }) : _repository = repository {
    _selectedDate = initialDate ?? isoDay(DateTime.now());
  }

  // ── Getters ───────────────────────────────────────────
  AttendanceSheetModel? get sheet => _sheet;
  bool get isLoading => _isLoading;
  bool get isSaving => _isSaving;
  String? get error => _error;
  String get selectedDate => _selectedDate;
  bool get hasUnsavedChanges => _localStatuses.isNotEmpty;

  Set<String>? get scope => _scope;

  /// The students the bulk actions and counters cover: [scope], or all.
  List<StudentAttendanceEntry> get scopedStudents {
    final s = _sheet;
    if (s == null) return const [];
    final scope = _scope;
    if (scope == null) return s.students;
    return s.students
        .where((st) => scope.contains(st.studentId))
        .toList(growable: false);
  }

  /// Null or empty → the whole sheet again. Unsaved choices are kept.
  void setScope(Set<String>? studentIds) {
    _scope = (studentIds == null || studentIds.isEmpty) ? null : {...studentIds};
    notifyListeners();
  }

  /// «غائب بعذر» is offered only when the server understands it.
  bool get supportsExcused => _sheet?.supportsExcused ?? false;

  DayKind? get dayKind => _sheet?.dayKind;

  /// Students with no status at all, saved or pending — within [scope].
  int get unmarkedCount =>
      scopedStudents.where((st) => getStatus(st.studentId) == null).length;

  StudentAttendanceEntry? _entry(String studentId) =>
      _sheet?.students.where((s) => s.studentId == studentId).firstOrNull;

  String? getStatus(String studentId) {
    return _localStatuses[studentId] ?? _entry(studentId)?.effectiveStatus;
  }

  // ── Load Sheet ────────────────────────────────────────
  Future<void> loadSheet() async {
    _isLoading = true;
    _error = null;
    _localStatuses.clear();
    notifyListeners();

    try {
      final AttendanceSheetModel result = await _repository.getSheet(
        _selectedDate,
        instructorId: instructorId,
      );
      _sheet = result;
    } catch (e) {
      _error = e.toString();
    }

    _isLoading = false;
    notifyListeners();
  }

  // ── Change Date ───────────────────────────────────────
  Future<void> changeDate(String date) async {
    _selectedDate = date;
    await loadSheet();
  }

  // ── Set Status Locally ────────────────────────────────
  void setStatus(String studentId, String status) {
    if (status == 'EXCUSED' && !supportsExcused) return;
    _localStatuses[studentId] = status;
    notifyListeners();
  }

  /// Status as persisted on the server, ignoring unsaved local edits.
  /// Lets the screen tell a pending choice from a saved one.
  String? savedStatusOf(String studentId) => _entry(studentId)?.effectiveStatus;

  /// Drop an unsaved local choice. Nothing is sent anywhere.
  void clearStatus(String studentId) {
    _localStatuses.remove(studentId);
    notifyListeners();
  }

  /// Delete a saved record and its points, then reload so the counters
  /// and the server agree. Returns false and sets [error] on failure.
  Future<bool> unmarkSaved(String studentId) async {
    _isSaving = true;
    _error = null;
    notifyListeners();

    try {
      await _repository.unmarkAttendance(
        date: _selectedDate,
        studentIds: [studentId],
      );
      _localStatuses.remove(studentId);
      await loadSheet();
      _isSaving = false;
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      _isSaving = false;
      notifyListeners();
      return false;
    }
  }

  // ── Mark All with a Status ────────────────────────────
  void markAll(String status) {
    if (_sheet == null) return;
    for (final student in scopedStudents) {
      _localStatuses[student.studentId] = status;
    }
    notifyListeners();
  }

  /// Give [status] only to students who have none yet — e.g. «الباقي غائب»
  /// after tapping the ones who came. Nobody already marked is touched.
  void markRemaining(String status) {
    if (_sheet == null) return;
    for (final student in scopedStudents) {
      if (getStatus(student.studentId) == null) {
        _localStatuses[student.studentId] = status;
      }
    }
    notifyListeners();
  }

  // ── Save Attendance ───────────────────────────────────
  Future<bool> saveAttendance() async {
    if (_sheet == null) return false;

    _isSaving = true;
    _error = null;
    notifyListeners();

    try {
      final entries = <Map<String, dynamic>>[];

      // Only what changed is sent. Re-sending a saved status would change
      // nothing on the student, but the server stamps every row it receives
      // with the sender as recorder — so a teacher fixing one name would
      // take over marks a substitute (or an admin) made, and two substitutes
      // sharing a حلقة would overwrite each other's names.
      for (final student in _sheet!.students) {
        final status = _localStatuses[student.studentId];
        if (status == null || status == student.effectiveStatus) continue;

        final entry = <String, dynamic>{
          'studentId': student.studentId,
          'status': status == 'EXCUSED' ? 'ABSENT' : status,
        };
        // `excused` is sent only when it changes something, so a sheet that
        // never touches an excuse stays valid on a server without the field.
        if (status == 'EXCUSED') {
          entry['excused'] = true;
        } else if (status == 'ABSENT' && student.effectiveStatus == 'EXCUSED') {
          entry['excused'] = false;
        }
        entries.add(entry);
      }

      if (entries.isEmpty) {
        // Every choice matches what is already saved: nothing to send.
        if (_localStatuses.isNotEmpty) {
          _localStatuses.clear();
          _isSaving = false;
          notifyListeners();
          return true;
        }
        _error = 'لم يتم تحديد حالة أي طالب';
        _isSaving = false;
        notifyListeners();
        return false;
      }

      await _repository.markAttendance(
        date: _selectedDate,
        entries: entries,
      );

      _localStatuses.clear();
      await loadSheet();

      _isSaving = false;
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      _isSaving = false;
      notifyListeners();
      return false;
    }
  }
}
