import 'package:flutter/foundation.dart';
import '../../data/models/attendance_sheet_model.dart';
import '../../data/repositories/attendance_repository.dart';

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

  AttendanceProvider({
    required AttendanceRepository repository,
    this.instructorId,
  }) : _repository = repository {
    final now = DateTime.now();
    _selectedDate =
        '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }

  // ── Getters ───────────────────────────────────────────
  AttendanceSheetModel? get sheet => _sheet;
  bool get isLoading => _isLoading;
  bool get isSaving => _isSaving;
  String? get error => _error;
  String get selectedDate => _selectedDate;
  bool get hasUnsavedChanges => _localStatuses.isNotEmpty;

  String? getStatus(String studentId) {
    return _localStatuses[studentId] ??
        _sheet?.students
            .where((s) => s.studentId == studentId)
            .firstOrNull
            ?.status;
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
    _localStatuses[studentId] = status;
    notifyListeners();
  }

  // ── Mark All with a Status ────────────────────────────
  /// Status as persisted on the server, ignoring unsaved local edits.
  /// Lets the screen tell a pending choice from a saved one.
  String? savedStatusOf(String studentId) {
    return _sheet?.students
        .where((s) => s.studentId == studentId)
        .firstOrNull
        ?.status;
  }

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

  void markAll(String status) {
    if (_sheet == null) return;
    for (final student in _sheet!.students) {
      _localStatuses[student.studentId] = status;
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

      for (final student in _sheet!.students) {
        final status = _localStatuses[student.studentId] ?? student.status;
        if (status != null) {
          entries.add({
            'studentId': student.studentId,
            'status': status,
          });
        }
      }

      if (entries.isEmpty) {
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
