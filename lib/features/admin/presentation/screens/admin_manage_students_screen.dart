import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../core/theme/taqwa_colors.dart';
import '../../../../core/network/api_client.dart';
import '../../../students/data/models/student_model.dart';
import '../../../students/presentation/screens/add_student_screen.dart';

// ═══════════════════════════════════════════════════════════════════════════
// FILTER MODEL
//
// Filtering runs entirely on the client. The screen already loaded every
// student in one `all=true` request, and every field the filters need —
// grade, instructorId, dateOfBirth, deletedAt, totalPagesRecited — travels
// with that payload. Round-tripping to the server on each chip tap would add
// latency without adding information.
// ═══════════════════════════════════════════════════════════════════════════

/// Lifecycle selection. Mirrors the backend's `?status=` parameter, but is
/// applied locally: the roster is fetched once with `status=all` and narrowed
/// here, so switching between active and deleted costs no network call.
enum StudentStatusFilter { active, inactive, all }

extension on StudentStatusFilter {
  String get label => switch (this) {
        StudentStatusFilter.active => 'النشطون',
        StudentStatusFilter.inactive => 'المحذوفون',
        StudentStatusFilter.all => 'الجميع',
      };
}

/// A half-open numeric range `[min, max)` with an Arabic label.
///
/// Both age and recited-pages filters are expressed this way. The upper bound
/// is exclusive so adjacent buckets tile the number line without overlap or
/// gaps — a student can never match two buckets, nor fall between them.
class FilterBucket {
  final String id;
  final String label;
  final num min;
  final num? max;

  const FilterBucket({
    required this.id,
    required this.label,
    required this.min,
    this.max,
  });

  bool contains(num value) =>
      value >= min && (max == null || value < max!);
}

/// Age brackets, chosen to match how the حلقات are actually grouped.
const List<FilterBucket> kAgeBuckets = [
  FilterBucket(id: 'age_lt10', label: 'أقل من 10 سنوات', min: 0, max: 10),
  FilterBucket(id: 'age_10_12', label: '10 – 12 سنة', min: 10, max: 13),
  FilterBucket(id: 'age_13_15', label: '13 – 15 سنة', min: 13, max: 16),
  FilterBucket(id: 'age_16up', label: '16 سنة فأكثر', min: 16),
];

/// Recited-volume brackets, in mushaf pages (one juz ≈ 20 pages).
///
/// The brackets are deliberately uneven. A production audit found 125 of 170
/// students below a single juz, so equal 1-juz steps would collapse three
/// quarters of the roster into one bucket and leave the filter useless.
const List<FilterBucket> kPagesBuckets = [
  FilterBucket(id: 'juz_lt1', label: 'أقل من جزء', min: 0, max: 20),
  FilterBucket(id: 'juz_1_2', label: 'جزء – جزءان', min: 20, max: 60),
  FilterBucket(id: 'juz_3_5', label: '3 – 5 أجزاء', min: 60, max: 120),
  FilterBucket(id: 'juz_6up', label: 'أكثر من 5 أجزاء', min: 120),
];

/// Pedagogical grade order, used only as a fallback.
///
/// The authoritative list comes from `GET /students/filters/options`, which
/// derives it from the data and returns it already ordered. This constant is
/// the safety net for when that request fails; it is duplicated knowledge and
/// should be deleted if the endpoint ever becomes a hard dependency.
const List<String> kGradeOrderFallback = [
  'الأول',
  'الثاني',
  'الثالث',
  'الرابع',
  'الخامس',
  'السادس',
  'السابع',
  'الثامن',
  'التاسع',
  'العاشر',
  'الحادي عشر',
  'الثاني عشر',
];

/// The complete filter selection. Immutable so that the bottom sheet can edit
/// a detached draft and the screen only rebuilds when the user confirms.
class StudentFilters {
  final String search;
  final String? grade;
  final String? instructorId;
  final StudentStatusFilter status;
  final FilterBucket? age;
  final FilterBucket? pages;

  const StudentFilters({
    this.search = '',
    this.grade,
    this.instructorId,
    this.status = StudentStatusFilter.active,
    this.age,
    this.pages,
  });

  /// `null` is a meaningful value for every nullable field here (it means "no
  /// constraint"), so each one needs an explicit clear flag rather than the
  /// usual `value ?? current` shorthand.
  StudentFilters copyWith({
    String? search,
    String? grade,
    bool clearGrade = false,
    String? instructorId,
    bool clearInstructor = false,
    StudentStatusFilter? status,
    FilterBucket? age,
    bool clearAge = false,
    FilterBucket? pages,
    bool clearPages = false,
  }) {
    return StudentFilters(
      search: search ?? this.search,
      grade: clearGrade ? null : (grade ?? this.grade),
      instructorId:
          clearInstructor ? null : (instructorId ?? this.instructorId),
      status: status ?? this.status,
      age: clearAge ? null : (age ?? this.age),
      pages: clearPages ? null : (pages ?? this.pages),
    );
  }

  /// Number of active constraints, excluding the search box — it has its own
  /// visible control and would make the badge misleading.
  int get activeCount {
    var count = 0;
    if (grade != null) count++;
    if (instructorId != null) count++;
    if (status != StudentStatusFilter.active) count++;
    if (age != null) count++;
    if (pages != null) count++;
    return count;
  }

  bool get isDefault => activeCount == 0 && search.isEmpty;
}

class AdminManageStudentsScreen extends StatefulWidget {
  const AdminManageStudentsScreen({super.key});

  @override
  State<AdminManageStudentsScreen> createState() =>
      _AdminManageStudentsScreenState();
}

class _AdminManageStudentsScreenState extends State<AdminManageStudentsScreen> {
  List<Map<String, dynamic>> _students = [];
  List<Map<String, dynamic>> _filtered = [];

  Map<String, String> _instructorNames = {};
  List<String> _availableGrades = [];
  List<({String id, String name, int count})> _availableInstructors = [];
  Map<String, int> _gradeCounts = {};

  StudentFilters _filters = const StudentFilters();
  bool _isLoading = true;

  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // ── Parsing helpers ──────────────────────────────────────────────────────

  /// Extract username from nested or flat response shape.
  String _getUsername(Map<String, dynamic> student) {
    return student['user']?['username'] as String? ??
        student['username'] as String? ??
        '';
  }

  /// Safely unwrap a paginated response ({ data: [...] }) or a raw list.
  List<dynamic> _unwrapList(dynamic responseData) {
    if (responseData is Map<String, dynamic>) {
      final inner = responseData['data'];
      if (inner is List) return inner;
    }
    if (responseData is List) return responseData;
    return const [];
  }

  /// `totalPagesRecited` and `totalPoints` originate from Prisma Decimal
  /// columns and can arrive as num or String depending on serialisation. A
  /// direct cast to double throws at runtime; this never does.
  double _toDouble(dynamic value) {
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0;
    return 0;
  }

  /// Age in whole years, or null when the birth date is missing or malformed.
  /// Computed from the calendar date rather than by dividing a duration, so it
  /// stays correct across leap years.
  int? _ageOf(Map<String, dynamic> student) {
    final raw = student['dateOfBirth'];
    if (raw == null) return null;

    final dob = DateTime.tryParse(raw.toString());
    if (dob == null) return null;

    final now = DateTime.now();
    var age = now.year - dob.year;
    final hasHadBirthdayThisYear = now.month > dob.month ||
        (now.month == dob.month && now.day >= dob.day);
    if (!hasHadBirthdayThisYear) age--;

    return age < 0 ? null : age;
  }

  bool _isDeleted(Map<String, dynamic> student) =>
      student['deletedAt'] != null;

  String _gradeOf(Map<String, dynamic> student) =>
      (student['grade'] ?? '').toString().trim();

  // ── Data loading ─────────────────────────────────────────────────────────

  Future<void> _loadData() async {
    setState(() => _isLoading = true);

    // Both requests start together. The options request is non-critical: if it
    // fails the roster still renders, with filter choices derived from the
    // students themselves. `catchError` is attached at creation so a failure
    // never surfaces as an unhandled async error while we await the other.
    final optionsFuture = ApiClient.instance
        .get('/students/filters/options')
        .then<Map<String, dynamic>>((res) =>
            res.data is Map ? Map<String, dynamic>.from(res.data) : {})
        .catchError((_) => <String, dynamic>{});

    // `status=all` fetches deleted students too, so the lifecycle filter works
    // without a second request. The default filter is still `active`, so what
    // the admin sees on open is unchanged.
    final studentsFuture = ApiClient.instance.get(
      '/students',
      queryParameters: {
        'all': 'true',
        'includePages': 'true',
        'status': 'all',
      },
    );

    try {
      final studentsRes = await studentsFuture;
      final options = await optionsFuture;

      _students = _unwrapList(studentsRes.data)
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();

      _applyFilterOptions(options);
      _applyFilters();
    } catch (e) {
      debugPrint('Load students error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('تعذر تحميل البيانات: $e',
                style: const TextStyle(fontFamily: 'Cairo')),
            backgroundColor: Colors.red,
          ),
        );
      }
    }

    if (mounted) setState(() => _isLoading = false);
  }

  /// Populate the filter choices, preferring the server's derived lists and
  /// falling back to values reconstructed from the loaded students.
  void _applyFilterOptions(Map<String, dynamic> options) {
    final grades = options['grades'];
    final instructors = options['instructors'];

    if (grades is List && grades.isNotEmpty) {
      _availableGrades = grades
          .whereType<Map>()
          .map((g) => (g['value'] ?? '').toString())
          .where((v) => v.isNotEmpty)
          .toList();

      _gradeCounts = {
        for (final g in grades.whereType<Map>())
          (g['value'] ?? '').toString():
              int.tryParse('${g['count'] ?? 0}') ?? 0,
      };
    } else {
      _rebuildGradesFromStudents();
    }

    if (instructors is List && instructors.isNotEmpty) {
      _availableInstructors = instructors
          .whereType<Map>()
          .map((i) => (
                id: (i['id'] ?? '').toString(),
                name: (i['fullName'] ?? '').toString(),
                count: int.tryParse('${i['count'] ?? 0}') ?? 0,
              ))
          .where((i) => i.id.isNotEmpty)
          .toList();
    } else {
      _rebuildInstructorsFromStudents();
    }

    _instructorNames = {
      for (final i in _availableInstructors) i.id: i.name,
    };

    // Students carry their instructor inline; fill any gaps the options list
    // missed so tiles never render a blank حلقة.
    for (final student in _students) {
      final id = (student['instructorId'] ?? '').toString();
      final name = (student['instructor']?['fullName'] ?? '').toString();
      if (id.isNotEmpty && name.isNotEmpty) {
        _instructorNames.putIfAbsent(id, () => name);
      }
    }
  }

  void _rebuildGradesFromStudents() {
    final counts = <String, int>{};
    for (final student in _students) {
      if (_isDeleted(student)) continue;
      final grade = _gradeOf(student);
      if (grade.isEmpty) continue;
      counts[grade] = (counts[grade] ?? 0) + 1;
    }

    final ordered = counts.keys.toList()
      ..sort((a, b) {
        final ia = kGradeOrderFallback.indexOf(a);
        final ib = kGradeOrderFallback.indexOf(b);
        final rankA = ia == -1 ? kGradeOrderFallback.length : ia;
        final rankB = ib == -1 ? kGradeOrderFallback.length : ib;
        return rankA != rankB ? rankA.compareTo(rankB) : a.compareTo(b);
      });

    _availableGrades = ordered;
    _gradeCounts = counts;
  }

  void _rebuildInstructorsFromStudents() {
    final names = <String, String>{};
    final counts = <String, int>{};

    for (final student in _students) {
      final id = (student['instructorId'] ?? '').toString();
      if (id.isEmpty) continue;
      final name = (student['instructor']?['fullName'] ?? '').toString();
      if (name.isNotEmpty) names[id] = name;
      if (!_isDeleted(student)) counts[id] = (counts[id] ?? 0) + 1;
    }

    _availableInstructors = names.entries
        .map((e) => (id: e.key, name: e.value, count: counts[e.key] ?? 0))
        .toList()
      ..sort((a, b) => a.name.compareTo(b.name));
  }

  // ── Filtering ────────────────────────────────────────────────────────────

  /// Single source of truth for the visible list. Every control — the search
  /// box, the sheet, the removable chips — mutates `_filters` and calls this,
  /// so the criteria can never drift out of sync with what is displayed.
  void _applyFilters() {
    final query = _filters.search.trim().toLowerCase();

    final result = _students.where((student) {
      final deleted = _isDeleted(student);
      switch (_filters.status) {
        case StudentStatusFilter.active:
          if (deleted) return false;
        case StudentStatusFilter.inactive:
          if (!deleted) return false;
        case StudentStatusFilter.all:
          break;
      }

      if (_filters.grade != null && _gradeOf(student) != _filters.grade) {
        return false;
      }

      if (_filters.instructorId != null &&
          (student['instructorId'] ?? '').toString() !=
              _filters.instructorId) {
        return false;
      }

      final ageBucket = _filters.age;
      if (ageBucket != null) {
        final age = _ageOf(student);
        // A student with no usable birth date cannot satisfy an age filter.
        // Excluding them is the honest result; including them would silently
        // widen the filter.
        if (age == null || !ageBucket.contains(age)) return false;
      }

      final pagesBucket = _filters.pages;
      if (pagesBucket != null &&
          !pagesBucket.contains(_toDouble(student['totalPagesRecited']))) {
        return false;
      }

      if (query.isNotEmpty) {
        final name = (student['fullName'] ?? '').toString().toLowerCase();
        final username = _getUsername(student).toLowerCase();
        if (!name.contains(query) && !username.contains(query)) return false;
      }

      return true;
    }).toList();

    setState(() => _filtered = result);
  }

  void _updateFilters(StudentFilters next) {
    _filters = next;
    _applyFilters();
  }

  void _clearAllFilters() {
    _searchController.clear();
    _updateFilters(const StudentFilters());
  }

  // ── Filter sheet ─────────────────────────────────────────────────────────

  Future<void> _openFilterSheet() async {
    // The sheet edits a detached copy; nothing reaches the list until the user
    // taps تطبيق, so a half-made selection never flickers behind the sheet.
    var draft = _filters;

    final applied = await showModalBottomSheet<StudentFilters>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: StatefulBuilder(
          builder: (ctx, setSheetState) {
            return Container(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(ctx).size.height * 0.85,
              ),
              decoration: const BoxDecoration(
                color: Color(0xFFF5F6FA),
                borderRadius:
                    BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildSheetHandle(),
                  _buildSheetHeader(
                    onReset: () => setSheetState(
                        () => draft = const StudentFilters()),
                    hasFilters: draft.activeCount > 0,
                  ),
                  Flexible(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildSheetSection(
                            title: 'الصف الدراسي',
                            icon: Icons.menu_book,
                            child: _buildGradeChips(
                              selected: draft.grade,
                              onSelect: (value) => setSheetState(() {
                                draft = value == null
                                    ? draft.copyWith(clearGrade: true)
                                    : draft.copyWith(grade: value);
                              }),
                            ),
                          ),
                          _buildSheetSection(
                            title: 'الحلقة',
                            icon: Icons.school,
                            child: _buildInstructorChips(
                              selected: draft.instructorId,
                              onSelect: (value) => setSheetState(() {
                                draft = value == null
                                    ? draft.copyWith(clearInstructor: true)
                                    : draft.copyWith(instructorId: value);
                              }),
                            ),
                          ),
                          _buildSheetSection(
                            title: 'الفئة العمرية',
                            icon: Icons.cake_outlined,
                            child: _buildBucketChips(
                              buckets: kAgeBuckets,
                              selected: draft.age,
                              onSelect: (bucket) => setSheetState(() {
                                draft = bucket == null
                                    ? draft.copyWith(clearAge: true)
                                    : draft.copyWith(age: bucket);
                              }),
                            ),
                          ),
                          _buildSheetSection(
                            title: 'الصفحات المسمّعة',
                            icon: Icons.auto_stories,
                            subtitle:
                                'مجموع ما سمّعه الطالب، وتكرار الصفحة يُحتسب في كل مرة',
                            child: _buildBucketChips(
                              buckets: kPagesBuckets,
                              selected: draft.pages,
                              onSelect: (bucket) => setSheetState(() {
                                draft = bucket == null
                                    ? draft.copyWith(clearPages: true)
                                    : draft.copyWith(pages: bucket);
                              }),
                            ),
                          ),
                          _buildSheetSection(
                            title: 'الحالة',
                            icon: Icons.how_to_reg,
                            child: _buildStatusChips(
                              selected: draft.status,
                              onSelect: (status) => setSheetState(
                                  () => draft = draft.copyWith(status: status)),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  _buildSheetFooter(
                    onApply: () => Navigator.pop(ctx, draft),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );

    if (applied != null) _updateFilters(applied);
  }

  Widget _buildSheetHandle() {
    return Container(
      width: 44,
      height: 4,
      margin: const EdgeInsets.only(top: 12, bottom: 4),
      decoration: BoxDecoration(
        color: TaqwaColors.lightGray,
        borderRadius: BorderRadius.circular(2),
      ),
    );
  }

  Widget _buildSheetHeader({
    required VoidCallback onReset,
    required bool hasFilters,
  }) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 8, 0),
      child: Row(
        children: [
          const Icon(Icons.tune, color: TaqwaColors.domeBlue, size: 20),
          const SizedBox(width: 8),
          const Expanded(
            child: Text(
              'تصفية الطلاب',
              style: TextStyle(
                fontFamily: 'Cairo',
                fontSize: 17,
                fontWeight: FontWeight.bold,
                color: TaqwaColors.domeBlue,
              ),
            ),
          ),
          if (hasFilters)
            TextButton.icon(
              onPressed: onReset,
              icon: const Icon(Icons.refresh, size: 16),
              label: const Text('إعادة تعيين',
                  style: TextStyle(fontFamily: 'Cairo', fontSize: 13)),
              style: TextButton.styleFrom(
                  foregroundColor: TaqwaColors.gray),
            ),
        ],
      ),
    );
  }

  Widget _buildSheetSection({
    required String title,
    required IconData icon,
    required Widget child,
    String? subtitle,
  }) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 17, color: TaqwaColors.skyBlue),
              const SizedBox(width: 7),
              Text(
                title,
                style: const TextStyle(
                  fontFamily: 'Cairo',
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF2C3E50),
                ),
              ),
            ],
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: TextStyle(
                fontFamily: 'Cairo',
                fontSize: 11,
                color: Colors.grey.shade600,
                height: 1.5,
              ),
            ),
          ],
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }

  Widget _buildChoiceChip({
    required String label,
    required bool selected,
    required VoidCallback onTap,
    String? trailingCount,
  }) {
    return Material(
      color: selected ? TaqwaColors.domeBlue : TaqwaColors.lightBlue,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Padding(
          padding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontFamily: 'Cairo',
                  fontSize: 12.5,
                  fontWeight:
                      selected ? FontWeight.bold : FontWeight.normal,
                  color: selected ? Colors.white : TaqwaColors.domeBlue,
                ),
              ),
              if (trailingCount != null) ...[
                const SizedBox(width: 6),
                Text(
                  trailingCount,
                  style: TextStyle(
                    fontFamily: 'Cairo',
                    fontSize: 11,
                    color: selected
                        ? Colors.white.withValues(alpha: 0.75)
                        : TaqwaColors.skyBlue,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGradeChips({
    required String? selected,
    required ValueChanged<String?> onSelect,
  }) {
    if (_availableGrades.isEmpty) {
      return _buildEmptyOptionsNote('لا توجد صفوف مسجّلة');
    }

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: _availableGrades.map((grade) {
        final isSelected = selected == grade;
        return _buildChoiceChip(
          label: grade,
          selected: isSelected,
          trailingCount: '${_gradeCounts[grade] ?? 0}',
          onTap: () => onSelect(isSelected ? null : grade),
        );
      }).toList(),
    );
  }

  Widget _buildInstructorChips({
    required String? selected,
    required ValueChanged<String?> onSelect,
  }) {
    if (_availableInstructors.isEmpty) {
      return _buildEmptyOptionsNote('لا توجد حلقات مسجّلة');
    }

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: _availableInstructors.map((instructor) {
        final isSelected = selected == instructor.id;
        return _buildChoiceChip(
          label: instructor.name,
          selected: isSelected,
          trailingCount: '${instructor.count}',
          onTap: () => onSelect(isSelected ? null : instructor.id),
        );
      }).toList(),
    );
  }

  Widget _buildBucketChips({
    required List<FilterBucket> buckets,
    required FilterBucket? selected,
    required ValueChanged<FilterBucket?> onSelect,
  }) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: buckets.map((bucket) {
        final isSelected = selected?.id == bucket.id;
        return _buildChoiceChip(
          label: bucket.label,
          selected: isSelected,
          onTap: () => onSelect(isSelected ? null : bucket),
        );
      }).toList(),
    );
  }

  Widget _buildStatusChips({
    required StudentStatusFilter selected,
    required ValueChanged<StudentStatusFilter> onSelect,
  }) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: StudentStatusFilter.values.map((status) {
        return _buildChoiceChip(
          label: status.label,
          selected: selected == status,
          onTap: () => onSelect(status),
        );
      }).toList(),
    );
  }

  Widget _buildEmptyOptionsNote(String message) {
    return Text(
      message,
      style: TextStyle(
        fontFamily: 'Cairo',
        fontSize: 12,
        color: Colors.grey.shade500,
      ),
    );
  }

  Widget _buildSheetFooter({required VoidCallback onApply}) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
        child: SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: TaqwaColors.domeBlue,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: onApply,
            child: const Text(
              'تطبيق',
              style: TextStyle(
                fontFamily: 'Cairo',
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ── Active filter chips ──────────────────────────────────────────────────

  /// Every active constraint gets a removable chip. Without this the admin can
  /// end up staring at a short list with no visible reason why — the sheet is
  /// closed and the criteria are invisible.
  Widget _buildActiveFilterChips() {
    final chips = <Widget>[];

    void addChip(String label, VoidCallback onRemove) {
      chips.add(
        Padding(
          padding: const EdgeInsets.only(left: 8),
          child: Material(
            color: TaqwaColors.domeBlue,
            borderRadius: BorderRadius.circular(18),
            child: InkWell(
              borderRadius: BorderRadius.circular(18),
              onTap: onRemove,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(10, 6, 8, 6),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      label,
                      style: const TextStyle(
                        fontFamily: 'Cairo',
                        fontSize: 12,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(width: 5),
                    const Icon(Icons.close,
                        size: 14, color: Colors.white70),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    }

    final grade = _filters.grade;
    if (grade != null) {
      addChip('الصف: $grade',
          () => _updateFilters(_filters.copyWith(clearGrade: true)));
    }

    final instructorId = _filters.instructorId;
    if (instructorId != null) {
      final name = _instructorNames[instructorId] ?? 'حلقة';
      addChip('الحلقة: $name',
          () => _updateFilters(_filters.copyWith(clearInstructor: true)));
    }

    final age = _filters.age;
    if (age != null) {
      addChip('العمر: ${age.label}',
          () => _updateFilters(_filters.copyWith(clearAge: true)));
    }

    final pages = _filters.pages;
    if (pages != null) {
      addChip('التسميع: ${pages.label}',
          () => _updateFilters(_filters.copyWith(clearPages: true)));
    }

    if (_filters.status != StudentStatusFilter.active) {
      addChip(
        'الحالة: ${_filters.status.label}',
        () => _updateFilters(
            _filters.copyWith(status: StudentStatusFilter.active)),
      );
    }

    if (chips.isEmpty) return const SizedBox.shrink();

    return Container(
      height: 42,
      margin: const EdgeInsets.only(bottom: 8),
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: [
          ...chips,
          Padding(
            padding: const EdgeInsets.only(left: 8),
            child: TextButton(
              onPressed: _clearAllFilters,
              style: TextButton.styleFrom(
                foregroundColor: TaqwaColors.alertRed,
                padding: const EdgeInsets.symmetric(horizontal: 10),
              ),
              child: const Text('مسح الكل',
                  style: TextStyle(fontFamily: 'Cairo', fontSize: 12)),
            ),
          ),
        ],
      ),
    );
  }

  // ── Student actions (unchanged behaviour) ────────────────────────────────

  Future<void> _resetPassword(Map<String, dynamic> student) async {
    final newPassController = TextEditingController(text: 'Taqwa@2026');
    final username = _getUsername(student);

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16)),
          title: const Text('إعادة تعيين كلمة المرور',
              style: TextStyle(
                  fontFamily: 'Cairo', fontWeight: FontWeight.bold)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'الطالب: ${student['fullName']}',
                style: const TextStyle(fontFamily: 'Cairo', fontSize: 14),
              ),
              if (username.isNotEmpty)
                Text(
                  'اسم المستخدم: $username',
                  style: TextStyle(
                      fontFamily: 'Cairo',
                      fontSize: 13,
                      color: Colors.grey.shade600),
                ),
              const SizedBox(height: 16),
              Directionality(
                textDirection: TextDirection.ltr,
                child: TextField(
                  controller: newPassController,
                  decoration: InputDecoration(
                    labelText: 'كلمة المرور الجديدة',
                    labelStyle: const TextStyle(fontFamily: 'Cairo'),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10)),
                    prefixIcon: const Icon(Icons.lock),
                  ),
                  style: const TextStyle(fontFamily: 'Cairo'),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('إلغاء',
                  style:
                      TextStyle(fontFamily: 'Cairo', color: Colors.grey)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: TaqwaColors.domeBlue,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('تغيير',
                  style: TextStyle(
                      fontFamily: 'Cairo', color: Colors.white)),
            ),
          ],
        ),
      ),
    );

    if (confirmed == true) {
      try {
        debugPrint('Resetting password for student ID: ${student['id']}');
        await ApiClient.instance.post(
          '/students/${student['id']}/reset-password',
          data: {'password': newPassController.text.trim()},
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('تم تغيير كلمة المرور بنجاح',
                  style: TextStyle(fontFamily: 'Cairo')),
              backgroundColor: TaqwaColors.islamicGreen,
            ),
          );
        }
      } catch (e) {
        debugPrint('Reset password error: $e');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('خطأ: $e',
                  style: const TextStyle(fontFamily: 'Cairo')),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  void _showCredentials(Map<String, dynamic> student) {
    final username = _getUsername(student);
    final instructorName =
        _instructorNames[student['instructorId']] ?? 'غير محدد';
    final grade = _gradeOf(student);
    final pages = _toDouble(student['totalPagesRecited']);

    showDialog(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              const Icon(Icons.person, color: TaqwaColors.domeBlue),
              const SizedBox(width: 8),
              Expanded(
                child: Text(student['fullName'] ?? '',
                    style: const TextStyle(
                        fontFamily: 'Cairo',
                        fontWeight: FontWeight.bold,
                        fontSize: 16)),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildCredentialRow(
                'اسم المستخدم',
                username.isNotEmpty ? username : 'غير متاح',
                Icons.account_circle,
                onCopy: username.isNotEmpty
                    ? () {
                        Clipboard.setData(ClipboardData(text: username));
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('تم النسخ',
                                style: TextStyle(fontFamily: 'Cairo')),
                            duration: Duration(seconds: 1),
                          ),
                        );
                      }
                    : null,
              ),
              const SizedBox(height: 12),
              _buildCredentialRow(
                'المعلم',
                instructorName,
                Icons.school,
              ),
              if (grade.isNotEmpty) ...[
                const SizedBox(height: 12),
                _buildCredentialRow('الصف الدراسي', grade, Icons.menu_book),
              ],
              const SizedBox(height: 12),
              _buildCredentialRow(
                'الصفحات المسمّعة',
                _formatPages(pages),
                Icons.auto_stories,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('إغلاق',
                  style: TextStyle(fontFamily: 'Cairo')),
            ),
            ElevatedButton.icon(
              icon: const Icon(Icons.lock_reset, size: 18),
              label: const Text('تغيير كلمة المرور',
                  style: TextStyle(fontFamily: 'Cairo')),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: () {
                Navigator.pop(ctx);
                _resetPassword(student);
              },
            ),
          ],
        ),
      ),
    );
  }

  /// Two decimals matches how recitation points are already described
  /// elsewhere in the app (e.g. "تسميع 2.00 صفحة").
  String _formatPages(double pages) => '${pages.toStringAsFixed(2)} صفحة';

  Widget _buildCredentialRow(
    String label,
    String value,
    IconData icon, {
    VoidCallback? onCopy,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: TaqwaColors.domeBlue.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Icon(icon, color: TaqwaColors.domeBlue, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: TextStyle(
                        fontFamily: 'Cairo',
                        fontSize: 11,
                        color: Colors.grey.shade600)),
                Text(value,
                    style: const TextStyle(
                        fontFamily: 'Cairo',
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: TaqwaColors.domeBlue)),
              ],
            ),
          ),
          if (onCopy != null)
            IconButton(
              icon: const Icon(Icons.copy,
                  size: 18, color: TaqwaColors.domeBlue),
              onPressed: onCopy,
            ),
        ],
      ),
    );
  }

  Future<void> _editStudent(Map<String, dynamic> raw) async {
    final model = StudentModel.fromJson(raw);
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => AddStudentScreen(student: model)),
    );
    if (result == true) _loadData();
  }

  Future<void> _deleteStudent(Map<String, dynamic> student) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16)),
          title: const Text('حذف الطالب',
              style: TextStyle(
                  fontFamily: 'Cairo', fontWeight: FontWeight.bold)),
          content: Text('هل أنت متأكد من حذف ${student['fullName']}؟',
              style: const TextStyle(fontFamily: 'Cairo')),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('إلغاء',
                  style: TextStyle(fontFamily: 'Cairo')),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10))),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('حذف',
                  style: TextStyle(
                      fontFamily: 'Cairo', color: Colors.white)),
            ),
          ],
        ),
      ),
    );
    if (confirmed == true) {
      try {
        await ApiClient.instance.delete('/students/${student['id']}');
        _loadData();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('$e'), backgroundColor: Colors.red),
          );
        }
      }
    }
  }

  // ── Build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final activeCount = _filters.activeCount;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFFF5F6FA),
        appBar: AppBar(
          backgroundColor: TaqwaColors.domeBlue,
          title: Text('إدارة الطلاب (${_filtered.length})',
              style: const TextStyle(
                  fontFamily: 'Cairo', color: Colors.white)),
          iconTheme: const IconThemeData(color: Colors.white),
          actions: [
            _buildFilterAction(activeCount),
            IconButton(
              icon: const Icon(Icons.person_add),
              tooltip: 'إضافة طالب',
              onPressed: () async {
                final result = await Navigator.push<bool>(
                  context,
                  MaterialPageRoute(
                      builder: (_) => const AddStudentScreen()),
                );
                if (result == true) _loadData();
              },
            ),
          ],
        ),
        body: Column(
          children: [
            _buildSearchBar(),
            _buildActiveFilterChips(),
            Expanded(child: _buildBody()),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterAction(int activeCount) {
    return Stack(
      alignment: Alignment.center,
      children: [
        IconButton(
          icon: const Icon(Icons.tune),
          tooltip: 'تصفية',
          onPressed: _isLoading ? null : _openFilterSheet,
        ),
        if (activeCount > 0)
          Positioned(
            top: 8,
            left: 8,
            child: Container(
              padding: const EdgeInsets.all(4),
              constraints:
                  const BoxConstraints(minWidth: 17, minHeight: 17),
              decoration: const BoxDecoration(
                color: TaqwaColors.minaretGold,
                shape: BoxShape.circle,
              ),
              child: Text(
                '$activeCount',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontFamily: 'Cairo',
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: TaqwaColors.nightSky,
                  height: 1,
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildSearchBar() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
          ),
        ],
      ),
      child: TextField(
        controller: _searchController,
        onChanged: (value) =>
            _updateFilters(_filters.copyWith(search: value)),
        decoration: InputDecoration(
          hintText: 'بحث بالاسم أو اسم المستخدم...',
          hintStyle: TextStyle(
              fontFamily: 'Cairo', color: Colors.grey.shade400),
          prefixIcon:
              const Icon(Icons.search, color: TaqwaColors.domeBlue),
          suffixIcon: _filters.search.isEmpty
              ? null
              : IconButton(
                  icon: const Icon(Icons.close, size: 18),
                  color: Colors.grey,
                  onPressed: () {
                    _searchController.clear();
                    _updateFilters(_filters.copyWith(search: ''));
                  },
                ),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
              horizontal: 16, vertical: 14),
        ),
        style: const TextStyle(fontFamily: 'Cairo'),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: TaqwaColors.domeBlue),
      );
    }

    if (_filtered.isEmpty) {
      return _buildEmptyState();
    }

    return RefreshIndicator(
      color: TaqwaColors.domeBlue,
      onRefresh: _loadData,
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: _filtered.length,
        itemBuilder: (context, index) => _buildStudentTile(_filtered[index]),
      ),
    );
  }

  /// The empty state distinguishes "no students exist" from "your filters
  /// excluded everyone" — and in the latter case offers the way out, so the
  /// admin never has to hunt for how to undo a selection.
  Widget _buildEmptyState() {
    final filtering = !_filters.isDefault;

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            filtering ? Icons.filter_alt_off : Icons.people_outline,
            size: 48,
            color: Colors.grey.shade400,
          ),
          const SizedBox(height: 12),
          Text(
            filtering ? 'لا يوجد طلاب مطابقون للتصفية' : 'لا يوجد طلاب',
            style: const TextStyle(
                fontFamily: 'Cairo', color: Colors.grey, fontSize: 14),
          ),
          if (filtering) ...[
            const SizedBox(height: 8),
            TextButton.icon(
              onPressed: _clearAllFilters,
              icon: const Icon(Icons.refresh, size: 16),
              label: const Text('مسح التصفية',
                  style: TextStyle(fontFamily: 'Cairo', fontSize: 13)),
              style: TextButton.styleFrom(
                  foregroundColor: TaqwaColors.domeBlue),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStudentTile(Map<String, dynamic> student) {
    final name = (student['fullName'] ?? '').toString();
    final username = _getUsername(student);
    final instructorName = _instructorNames[student['instructorId']] ?? '';
    final grade = _gradeOf(student);
    final pages = _toDouble(student['totalPagesRecited']);
    final deleted = _isDeleted(student);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () => _showCredentials(student),
          child: Opacity(
            // Deleted students only appear when explicitly requested, so they
            // are dimmed rather than hidden — visible, but never mistakable
            // for an active enrolment.
            opacity: deleted ? 0.55 : 1,
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: TaqwaColors.skyBlue.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Center(
                      child: Text(
                        name.isNotEmpty ? name[0] : '؟',
                        style: const TextStyle(
                          fontFamily: 'Cairo',
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: TaqwaColors.domeBlue,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                name,
                                style: const TextStyle(
                                    fontFamily: 'Cairo',
                                    fontSize: 15,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF2C3E50)),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (deleted) ...[
                              const SizedBox(width: 6),
                              _buildTag('محذوف', TaqwaColors.alertRed),
                            ],
                          ],
                        ),
                        const SizedBox(height: 3),
                        Row(
                          children: [
                            if (username.isNotEmpty) ...[
                              Icon(Icons.account_circle,
                                  size: 13, color: Colors.grey.shade500),
                              const SizedBox(width: 3),
                              Flexible(
                                child: Text(username,
                                    style: TextStyle(
                                        fontFamily: 'Cairo',
                                        fontSize: 12,
                                        color: Colors.grey.shade600),
                                    overflow: TextOverflow.ellipsis),
                              ),
                              const SizedBox(width: 10),
                            ],
                            if (instructorName.isNotEmpty) ...[
                              Icon(Icons.school,
                                  size: 13, color: Colors.grey.shade500),
                              const SizedBox(width: 3),
                              Flexible(
                                child: Text(instructorName,
                                    style: TextStyle(
                                        fontFamily: 'Cairo',
                                        fontSize: 12,
                                        color: Colors.grey.shade600),
                                    overflow: TextOverflow.ellipsis),
                              ),
                            ],
                          ],
                        ),
                        if (grade.isNotEmpty || pages > 0) ...[
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              if (grade.isNotEmpty)
                                _buildTag(grade, TaqwaColors.skyBlue),
                              if (grade.isNotEmpty && pages > 0)
                                const SizedBox(width: 6),
                              if (pages > 0)
                                _buildTag(_formatPages(pages),
                                    TaqwaColors.islamicGreen),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                  PopupMenuButton<String>(
                    icon:
                        Icon(Icons.more_vert, color: Colors.grey.shade500),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    onSelected: (action) {
                      switch (action) {
                        case 'edit':
                          _editStudent(student);
                        case 'credentials':
                          _showCredentials(student);
                        case 'reset':
                          _resetPassword(student);
                        case 'delete':
                          _deleteStudent(student);
                      }
                    },
                    itemBuilder: (_) => [
                      const PopupMenuItem(
                        value: 'edit',
                        child: Row(
                          children: [
                            Icon(Icons.edit,
                                size: 18, color: TaqwaColors.domeBlue),
                            SizedBox(width: 8),
                            Text('تعديل البيانات',
                                style: TextStyle(fontFamily: 'Cairo')),
                          ],
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'credentials',
                        child: Row(
                          children: [
                            Icon(Icons.key,
                                size: 18, color: Colors.orange),
                            SizedBox(width: 8),
                            Text('بيانات الدخول',
                                style: TextStyle(fontFamily: 'Cairo')),
                          ],
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'reset',
                        child: Row(
                          children: [
                            Icon(Icons.lock_reset,
                                size: 18, color: Colors.orange),
                            SizedBox(width: 8),
                            Text('تغيير كلمة المرور',
                                style: TextStyle(fontFamily: 'Cairo')),
                          ],
                        ),
                      ),
                      if (!deleted)
                        const PopupMenuItem(
                          value: 'delete',
                          child: Row(
                            children: [
                              Icon(Icons.delete,
                                  size: 18, color: Colors.red),
                              SizedBox(width: 8),
                              Text('حذف',
                                  style: TextStyle(
                                      fontFamily: 'Cairo',
                                      color: Colors.red)),
                            ],
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTag(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontFamily: 'Cairo',
          fontSize: 10.5,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }
}