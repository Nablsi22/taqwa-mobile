import 'package:flutter/foundation.dart';
import '../../data/models/student_model.dart';
import '../../data/repositories/student_repository.dart';

class StudentProvider extends ChangeNotifier {
  final StudentRepository _repository;

  List<StudentModel> _students = [];
  bool _isLoading = false;
  String? _error;
  int _totalStudents = 0;
  int _currentPage = 1;
  String _searchQuery = '';

  StudentProvider({required StudentRepository repository})
      : _repository = repository;

  // ── Getters ───────────────────────────────────────────────
  List<StudentModel> get students => _students;
  bool get isLoading => _isLoading;
  String? get error => _error;
  int get totalStudents => _totalStudents;

  // ── Load Students ─────────────────────────────────────────
  Future<void> loadStudents({bool refresh = false}) async {
    if (refresh) _currentPage = 1;

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final result = await _repository.getStudents(
        search: _searchQuery.isNotEmpty ? _searchQuery : null,
        page: _currentPage,
      );
      if (refresh || _currentPage == 1) {
        _students = result.students;
      } else {
        _students.addAll(result.students);
      }
      _totalStudents = result.total;
    } catch (e) {
      _error = e.toString();
    }

    _isLoading = false;
    notifyListeners();
  }

  // ── Search ────────────────────────────────────────────────
  Future<void> search(String query) async {
    _searchQuery = query;
    _currentPage = 1;
    await loadStudents(refresh: true);
  }

  // ── Load More (Pagination) ────────────────────────────────
  Future<void> loadMore() async {
    if (_students.length >= _totalStudents) return;
    _currentPage++;
    await loadStudents();
  }

  // ── Create Student ────────────────────────────────────────
  Future<bool> createStudent(Map<String, dynamic> data) async {
    try {
      await _repository.createStudent(data);
      await loadStudents(refresh: true);
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  // ── Update Student ────────────────────────────────────────
  Future<bool> updateStudent(String id, Map<String, dynamic> data) async {
    try {
      await _repository.updateStudent(id, data);
      await loadStudents(refresh: true);
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  // ── Delete Student ────────────────────────────────────────
  Future<bool> deleteStudent(String id) async {
    try {
      await _repository.deleteStudent(id);
      _students.removeWhere((s) => s.id == id);
      _totalStudents--;
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }
}