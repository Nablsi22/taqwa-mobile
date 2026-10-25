import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/theme/taqwa_colors.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/utils/meeting_days.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../auth/presentation/widgets/logout_dialog.dart';
import '../../../attendance_stats/data/attendance_stats_api.dart';
import '../../../attendance_stats/data/attendance_stats_models.dart';
import '../../../recitation/data/recitation_api.dart';
import '../../../terms/presentation/providers/term_provider.dart';
import '../../../terms/presentation/widgets/term_selector.dart';
import '../../../attendance/data/repositories/attendance_repository.dart';
import '../../../attendance/presentation/providers/attendance_provider.dart';
import '../../../attendance/presentation/screens/attendance_screen.dart';
import '../../../substitute/presentation/screens/other_halaqas_screen.dart';
import '../../../substitute/presentation/substitute_ui.dart';
import '../widgets/last_session_card.dart';
import 'halaqa_attendance_screen.dart';
import 'instructor_student_detail_screen.dart';
import 'maqraa_screen.dart';
import 'instructor_points_screen.dart';
import '../../../azkar/presentation/screens/azkar_home_screen.dart';
import '../../../announcement/presentation/screens/announcement_list_screen.dart';
import '../../../quran_reader/presentation/screens/quran_surah_list_screen.dart';
import '../../../../core/widgets/taqwa_slogan_banner.dart';

class InstructorDashboardScreen extends StatefulWidget {
  const InstructorDashboardScreen({super.key});

  @override
  State<InstructorDashboardScreen> createState() =>
      _InstructorDashboardScreenState();
}

class _InstructorDashboardScreenState extends State<InstructorDashboardScreen> {
  final _recitationApi = RecitationApi(ApiClient.instance);
  final _statsApi = AttendanceStatsApi(ApiClient.instance);

  bool _isLoading = true;
  String? _error;
  String _instructorName = '';
  String? _instructorId;
  List<Map<String, dynamic>> _students = [];

  // Circle rank per studentId, computed from the points balance once per
  // load and then held constant, so changing the sort never renumbers
  // anybody.
  final Map<String, int> _circleRank = {};
  _RosterSort _sort = _RosterSort.points;

  // Last session card. Loaded beside the roster and never fatal: on a server
  // without attendance statistics the card is simply not shown.
  AttendanceDay? _lastSession;
  String? _lastSessionError;
  bool _lastSessionUnavailable = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadDashboard());
  }

  Future<void> _loadDashboard() async {
    final authProvider = context.read<AuthProvider>();
    final user = authProvider.user;

    if (user == null || user.profile == null) {
      setState(() {
        _error = 'لا يمكن تحميل البيانات';
        _isLoading = false;
      });
      return;
    }

    _instructorId = user.profile!.id;
    _instructorName = user.profile!.fullName ?? 'المعلم';

    // Runs alongside the roster and never holds it up; it handles its own
    // failures. Awaited at the end so pull-to-refresh waits for both.
    final lastSession = _loadLastSession();

    try {
      // Roster points and mosque rank are course-scoped: a new course opens
      // with every student on 0 rather than carrying last term's totals.
      final overview = await _recitationApi.getInstructorOverview(
        termId: context.read<TermProvider>().viewedTermIdParam,
      );
      if (!mounted) return;
      setState(() {
        _students = overview;
        _recomputeCircleRanks();
        _applySort();
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
    await lastSession;
  }

  Future<void> _loadLastSession() async {
    if (_lastSessionUnavailable) return;
    final termId = context.read<TermProvider>().viewedTermIdParam;
    // Switched course: never leave the previous course's session on screen.
    final shownCourse = _lastSession?.course?.id;
    if (shownCourse != null && termId != null && shownCourse != termId) {
      setState(() => _lastSession = null);
    }
    try {
      final day = await _statsApi.getDay(termId: termId);
      if (!mounted) return;
      setState(() {
        _lastSession = day;
        _lastSessionError = null;
      });
    } on AttendanceStatsUnavailable {
      if (!mounted) return;
      setState(() => _lastSessionUnavailable = true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _lastSessionError = e.toString());
    }
  }

  // Defensive readers: an older backend that predates these fields
  // yields a neutral value instead of throwing.
  double _balanceOf(Map<String, dynamic> s) =>
      (s['pointsBalance'] as num?)?.toDouble() ?? 0;

  int? _mosqueRankOf(Map<String, dynamic> s) =>
      (s['mosqueRank'] as num?)?.toInt();

  double _percentOf(Map<String, dynamic> s) =>
      (s['overallPercentage'] as num?)?.toDouble() ?? 0;

  DateTime? _lastAttendanceOf(Map<String, dynamic> s) {
    final raw = s['lastAttendanceDate'];
    if (raw == null) return null;
    return DateTime.tryParse(raw.toString());
  }

  // Standard competition ranking (1, 2, 2, 4): equal balances share a
  // position, matching the mosque rank the server computes.
  void _recomputeCircleRanks() {
    _circleRank.clear();
    final ordered = [..._students]
      ..sort((a, b) => _balanceOf(b).compareTo(_balanceOf(a)));

    double? previous;
    int current = 0;
    for (var i = 0; i < ordered.length; i++) {
      final balance = _balanceOf(ordered[i]);
      if (previous == null || balance != previous) {
        current = i + 1;
        previous = balance;
      }
      final id = ordered[i]['studentId'] as String?;
      if (id != null) _circleRank[id] = current;
    }
  }

  void _applySort() {
    switch (_sort) {
      case _RosterSort.points:
        _students.sort((a, b) => _balanceOf(b).compareTo(_balanceOf(a)));
        break;
      case _RosterSort.name:
        _students.sort((a, b) =>
            (a['fullName'] as String? ?? '')
                .compareTo(b['fullName'] as String? ?? ''));
        break;
      case _RosterSort.memorisation:
        _students.sort((a, b) => _percentOf(b).compareTo(_percentOf(a)));
        break;
      case _RosterSort.attendance:
        // Oldest first: the instructor is looking for who stopped
        // coming. Students with no attendance at all lead the list.
        _students.sort((a, b) {
          final x = _lastAttendanceOf(a);
          final y = _lastAttendanceOf(b);
          if (x == null && y == null) return 0;
          if (x == null) return -1;
          if (y == null) return 1;
          return x.compareTo(y);
        });
        break;
    }
  }

  String _attendanceLabel(Map<String, dynamic> s) {
    final date = _lastAttendanceOf(s);
    if (date == null) return 'لا حضور';
    final now = DateTime.now();
    final days = DateTime(now.year, now.month, now.day)
        .difference(DateTime(date.year, date.month, date.day))
        .inDays;
    if (days <= 0) return 'اليوم';
    if (days == 1) return 'أمس';
    return 'منذ $days يوم';
  }

  void _navigateToStudentDetail(Map<String, dynamic> student) {
    _openStudent(
      student['studentId'] as String,
      student['fullName'] as String? ?? 'طالب',
    );
  }

  void _openStudent(String studentId, String studentName, {int initialTab = 0}) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => InstructorStudentDetailScreen(
          studentId: studentId,
          studentName: studentName,
          initialTab: initialTab,
        ),
      ),
    ).then((_) => _loadDashboard());
  }

  void _navigateToHalaqaStats() {
    final termId = context.read<TermProvider>().viewedTermIdParam;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => HalaqaAttendanceScreen(termId: termId),
      ),
    );
  }

  /// Opens the sheet on [date], or — from the «الحضور» button — on the
  /// course's last meeting day: today on a meeting day, otherwise e.g. the
  /// Saturday before, so a late entry is never saved under the wrong day.
  void _navigateToAttendance({String? date}) {
    if (_instructorId == null) return;
    final active = context.read<TermProvider>().activeTerm;
    final initialDate = date ??
        (active == null ? null : isoDay(active.meetingDays.defaultAttendanceDay(DateTime.now())));
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChangeNotifierProvider(
          create: (_) => AttendanceProvider(
            repository: AttendanceRepository(apiClient: ApiClient.instance),
            instructorId: _instructorId,
            initialDate: initialDate,
          ),
          child: const AttendanceScreen(),
        ),
      ),
    ).then((_) => _loadDashboard());
  }

  /// «حلقات أخرى» — recording for a حلقة that is not mine. Deliberately its
  /// own entry, in its own colour: the mosque asked that covering for
  /// another أستاذ never share a screen with recording my own حلقة.
  ///
  /// It opens on the same day my own sheet would open on (the course's last
  /// meeting day), so a Saturday session recorded on Sunday is not saved
  /// under Sunday for the حلقة I covered either.
  void _navigateToOtherHalaqas() {
    final terms = context.read<TermProvider>();
    final active = terms.activeTerm;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => OtherHalaqasScreen(
          myInstructorId: _instructorId,
          date: active == null
              ? null
              : isoDay(active.meetingDays.defaultAttendanceDay(DateTime.now())),
          termId: terms.viewedTermIdParam,
        ),
      ),
    ).then((_) => _loadDashboard());
  }

  void _navigateToMaqraa() {
    if (_students.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('لا يوجد طلاب لبدء المقرأة',
              style: TextStyle(fontFamily: 'Cairo'),
              textDirection: TextDirection.rtl),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => MaqraaScreen(
          students: _students,
          instructorId: _instructorId!,
        ),
      ),
    ).then((_) => _loadDashboard());
  }

  void _navigateToPoints() {
    if (_students.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('لا يوجد طلاب لإدارة النقاط',
              style: TextStyle(fontFamily: 'Cairo'),
              textDirection: TextDirection.rtl),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => InstructorPointsScreen(students: _students),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Browsing an archived course: nothing is recorded from the session card.
    final viewingArchive =
        context.select<TermProvider, bool>((t) => t.isViewingArchive);
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFFF5F6FA),
        body: _isLoading
            ? const Center(
                child:
                    CircularProgressIndicator(color: TaqwaColors.domeBlue))
            : _error != null
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(_error!,
                            style: const TextStyle(fontFamily: 'Cairo')),
                        const SizedBox(height: 12),
                        ElevatedButton(
                            onPressed: _loadDashboard,
                            child: const Text('إعادة المحاولة',
                                style: TextStyle(fontFamily: 'Cairo'))),
                      ],
                    ),
                  )
                : RefreshIndicator(
                    color: TaqwaColors.domeBlue,
                    onRefresh: _loadDashboard,
                    child: CustomScrollView(
                      slivers: [
                        const SliverToBoxAdapter(child: TaqwaSloganBanner()),
                        SliverToBoxAdapter(
                          child: Container(
                            padding: EdgeInsets.fromLTRB(
                              20,
                              MediaQuery.of(context).padding.top + 20,
                              20,
                              20,
                            ),
                            decoration: const BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  TaqwaColors.domeBlue,
                                  Color(0xFF14395A),
                                ],
                              ),
                              borderRadius: BorderRadius.vertical(
                                bottom: Radius.circular(28),
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.end,
                                  children: [
                                    TermSelectorAction(
                                        onChanged: _loadDashboard),
                                    const Spacer(),
                                    IconButton(
                                      tooltip: 'تسجيل الخروج',
                                      onPressed: () => confirmLogout(context),
                                      icon: const Icon(Icons.logout_rounded,
                                          color: Colors.white70, size: 22),
                                      padding: EdgeInsets.zero,
                                      constraints: const BoxConstraints(),
                                    ),
                                    const SizedBox(width: 8),
                                    IconButton(
                                      onPressed: _loadDashboard,
                                      icon: const Icon(Icons.refresh,
                                          color: Colors.white70, size: 22),
                                      padding: EdgeInsets.zero,
                                      constraints: const BoxConstraints(),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'أهلاً، $_instructorName',
                                  style: const TextStyle(
                                    fontFamily: 'Cairo',
                                    fontSize: 22,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '${_students.length} طالب في حلقتك',
                                  style: const TextStyle(
                                    fontFamily: 'Cairo',
                                    fontSize: 14,
                                    color: Colors.white70,
                                  ),
                                ),
                                const SizedBox(height: 14),
                                Row(
                                  children: [
                                    _actionButton(
                                      icon: Icons.check_circle_outline,
                                      label: 'الحضور',
                                      color: TaqwaColors.islamicGreen,
                                      onTap: () => _navigateToAttendance(),
                                    ),
                                    const SizedBox(width: 10),
                                    _actionButton(
                                      icon: Icons.groups,
                                      label: 'مقرأة',
                                      color: TaqwaColors.minaretGold,
                                      onTap: _navigateToMaqraa,
                                    ),
                                    const SizedBox(width: 10),
                                    _actionButton(
                                      icon: Icons.star,
                                      label: 'النقاط',
                                      color: const Color(0xFFE67E22),
                                      onTap: _navigateToPoints,
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    _actionButton(
                                      icon: Icons.campaign,
                                      label: 'الإعلانات',
                                      color: Colors.white,
                                      onTap: () {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (_) =>
                                                const AnnouncementListScreen(),
                                          ),
                                        );
                                      },
                                    ),
                                    const SizedBox(width: 10),
                                    _actionButton(
                                      icon: Icons.menu_book,
                                      label: 'القرآن',
                                      color: Colors.white,
                                      onTap: () {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (_) =>
                                                const QuranSurahListScreen(),
                                          ),
                                        );
                                      },
                                    ),
                                    const SizedBox(width: 10),
                                    _actionButton(
                                      icon: Icons.spa,
                                      label: 'الأذكار',
                                      color: Colors.white,
                                      onTap: () {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (_) =>
                                                const AzkarHomeScreen(),
                                          ),
                                        );
                                      },
                                    ),
                                  ],
                                ),
                                // Covering for another أستاذ: never recorded
                                // from the buttons above, and never while
                                // browsing an archived course.
                                if (!viewingArchive) ...[
                                  const SizedBox(height: 8),
                                  Row(
                                    children: [
                                      _actionButton(
                                        icon: Icons.swap_horiz_rounded,
                                        label: 'حلقات أخرى',
                                        color: SubstituteColors.onDark,
                                        onTap: _navigateToOtherHalaqas,
                                      ),
                                      const SizedBox(width: 10),
                                      // Keeps the button one third wide, so
                                      // it lines up with the rows above.
                                      const Spacer(flex: 2),
                                    ],
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                        if (!_lastSessionUnavailable)
                          SliverToBoxAdapter(
                            child: LastSessionCard(
                              day: _lastSession,
                              instructorId: _instructorId,
                              canRecord: !viewingArchive,
                              onRecord: (date) =>
                                  _navigateToAttendance(date: date),
                              onOpenStudent: (r) => _openStudent(
                                r.studentId,
                                r.fullName,
                                initialTab:
                                    InstructorStudentDetailScreen.attendanceTab,
                              ),
                              onOpenStats: _navigateToHalaqaStats,
                              error: _lastSession == null
                                  ? _lastSessionError
                                  : null,
                              onRetry: _loadLastSession,
                            ),
                          ),
                        SliverToBoxAdapter(
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
                            child: Row(
                              children: [
                                const Text(
                                  'الطلاب',
                                  style: TextStyle(
                                    fontFamily: 'Cairo',
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: TaqwaColors.domeBlue,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: TaqwaColors.domeBlue
                                        .withValues(alpha: 0.08),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    '${_students.length}',
                                    style: const TextStyle(
                                      fontFamily: 'Cairo',
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: TaqwaColors.domeBlue,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        SliverToBoxAdapter(child: _buildSortBar()),
                        _students.isEmpty
                            ? const SliverFillRemaining(
                                child: Center(
                                  child: Text('لا يوجد طلاب بعد',
                                      style: TextStyle(
                                          fontFamily: 'Cairo',
                                          color: Colors.grey)),
                                ),
                              )
                            : SliverList(
                                delegate: SliverChildBuilderDelegate(
                                  (context, index) {
                                    final student = _students[index];
                                    return _buildStudentCard(student, index);
                                  },
                                  childCount: _students.length,
                                ),
                              ),
                        const SliverToBoxAdapter(
                            child: SizedBox(height: 80)),
                      ],
                    ),
                  ),
      ),
    );
  }

  Widget _buildSortBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      child: Row(
        children: [
          Icon(Icons.sort, size: 15, color: Colors.grey.shade500),
          const SizedBox(width: 6),
          Text(
            'فرز حسب',
            style: TextStyle(
              fontFamily: 'Cairo',
              fontSize: 11,
              color: Colors.grey.shade500,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _sortChip(_RosterSort.points, 'النقاط'),
                  _sortChip(_RosterSort.name, 'الاسم'),
                  _sortChip(_RosterSort.memorisation, 'الحفظ'),
                  _sortChip(_RosterSort.attendance, 'آخر حضور'),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sortChip(_RosterSort value, String label) {
    final selected = _sort == value;
    return Padding(
      padding: const EdgeInsets.only(left: 6),
      child: Material(
        color: selected
            ? TaqwaColors.domeBlue
            : TaqwaColors.domeBlue.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () {
            if (selected) return;
            setState(() {
              _sort = value;
              _applySort();
            });
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(
                horizontal: 13, vertical: 7),
            child: Text(
              label,
              style: TextStyle(
                fontFamily: 'Cairo',
                fontSize: 11.5,
                fontWeight:
                    selected ? FontWeight.bold : FontWeight.normal,
                color: selected ? Colors.white : TaqwaColors.domeBlue,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _actionButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: Material(
        color: Colors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, color: color, size: 24),
                const SizedBox(height: 3),
                Text(
                  label,
                  style: const TextStyle(
                    fontFamily: 'Cairo',
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────
  // D2 — compact "آخر تسميع" line
  //
  // Reads `lastRecitation` (added by the backend in this deliverable)
  // and renders one of the four shapes mandated by the spec. Kept as
  // a pure function so the rendering logic is straightforward to test
  // and easy to keep stable.
  // ─────────────────────────────────────────────────────────────────
  String _formatLastRecitationLine(Map<String, dynamic>? last) {
    if (last == null) return 'لا يوجد تسميع سابق';

    final segments = (last['segments'] as List?) ?? const [];
    if (segments.isEmpty) return 'لا يوجد تسميع سابق';

    final totalAyat = (last['totalAyat'] as num?)?.toInt() ?? 0;

    if (segments.length > 1) {
      return 'آخر تسميع: ${segments.length} مقاطع • $totalAyat آية';
    }

    final seg = Map<String, dynamic>.from(segments.first as Map);
    final kind = (seg['kind'] as String?) ?? 'FULL_SURA';
    final surahNameAr = (seg['surahNameAr'] as String?) ?? '';
    final ayaCount = (seg['ayaCount'] as num?)?.toInt() ?? totalAyat;

    if (kind == 'AYA_RANGE') {
      final fromAya = (seg['fromAya'] as num?)?.toInt();
      final toAya = (seg['toAya'] as num?)?.toInt();
      if (fromAya != null && toAya != null) {
        return 'آخر تسميع: $surahNameAr $fromAya–$toAya • $ayaCount آية';
      }
    }

    // FULL_SURA or MULTI_SURA — surahNameAr already carries the joined
    // sura names for the multi-sura legacy case.
    return 'آخر تسميع: $surahNameAr • $ayaCount آية';
  }

  Widget _buildStudentCard(Map<String, dynamic> student, int index) {
    final name = student['fullName'] ?? 'طالب';
    final studentId = student['studentId'] as String? ?? '';
    final rank = _circleRank[studentId] ?? (index + 1);
    final mosqueRank = _mosqueRankOf(student);
    final balance = _balanceOf(student);
    final attendanceLabel = _attendanceLabel(student);
    final totalPages = student['totalPagesMemorized'] ?? 0;
    final pct = student['overallPercentage'] ?? 0;
    final lastRating = student['lastRating'] ?? '';
    final homework = student['homework'];
    final lastRecitation = student['lastRecitation'] is Map
        ? Map<String, dynamic>.from(student['lastRecitation'] as Map)
        : null;
    final lastRecitationLine = _formatLastRecitationLine(lastRecitation);
    final hasLastRecitation = lastRecitation != null;

    Color ratingColor = Colors.grey;
    String ratingLabel = '';
    if (lastRating == 'VERY_GOOD') {
      ratingColor = const Color(0xFF1E8449);
      ratingLabel = 'جيد جداً';
    } else if (lastRating == 'GOOD') {
      ratingColor = const Color(0xFF2E86C1);
      ratingLabel = 'جيد';
    } else if (lastRating == 'REPEAT') {
      ratingColor = const Color(0xFFD4AC0D);
      ratingLabel = 'إعادة';
    } else if (lastRating == 'DID_NOT_MEMORIZE') {
      ratingColor = const Color(0xFFE74C3C);
      ratingLabel = 'لم يحفظ';
    } else if (lastRating == 'MAQRAA') {
      ratingColor = const Color(0xFFD4AC0D);
      ratingLabel = 'مقرأة';
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 3),
      child: Card(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        elevation: 0,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => _navigateToStudentDetail(student),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: rank <= 3
                        ? TaqwaColors.minaretGold.withValues(alpha: 0.12)
                        : Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Center(
                    child: Text(
                      '$rank',
                      style: TextStyle(
                        fontFamily: 'Cairo',
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: rank <= 3
                            ? TaqwaColors.minaretGold
                            : Colors.grey.shade600,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: const TextStyle(
                          fontFamily: 'Cairo',
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '$totalPages صفحة ($pct%)',
                        style: TextStyle(
                          fontFamily: 'Cairo',
                          fontSize: 11,
                          color: Colors.grey.shade500,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      const SizedBox(height: 3),
                      Row(
                        children: [
                          const Icon(Icons.star_rounded,
                              size: 12, color: TaqwaColors.minaretGold),
                          const SizedBox(width: 3),
                          Text(
                            '${balance.toStringAsFixed(2)} نقطة',
                            textDirection: TextDirection.ltr,
                            style: const TextStyle(
                              fontFamily: 'Cairo',
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: TaqwaColors.domeBlue,
                            ),
                          ),
                          if (mosqueRank != null) ...[
                            const SizedBox(width: 8),
                            Container(
                              width: 1,
                              height: 10,
                              color: Colors.grey.shade300,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              '#$mosqueRank في الجامع',
                              style: TextStyle(
                                fontFamily: 'Cairo',
                                fontSize: 11,
                                color: Colors.grey.shade600,
                              ),
                            ),
                          ],
                          const SizedBox(width: 8),
                          Container(
                            width: 1,
                            height: 10,
                            color: Colors.grey.shade300,
                          ),
                          const SizedBox(width: 8),
                          Flexible(
                            child: Text(
                              attendanceLabel,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontFamily: 'Cairo',
                                fontSize: 11,
                                color: Colors.grey.shade500,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      // D2 compact line - gray-muted when no prior recitation
                      Text(
                        lastRecitationLine,
                        style: TextStyle(
                          fontFamily: 'Cairo',
                          fontSize: 11,
                          color: hasLastRecitation
                              ? Colors.grey.shade700
                              : Colors.grey.shade400,
                          fontStyle: hasLastRecitation
                              ? FontStyle.normal
                              : FontStyle.italic,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (homework != null &&
                          homework.toString().isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            const Icon(Icons.assignment,
                                size: 12, color: TaqwaColors.minaretGold),
                            const SizedBox(width: 4),
                            Flexible(
                              child: Text(
                                homework.toString(),
                                style: TextStyle(
                                  fontFamily: 'Cairo',
                                  fontSize: 10,
                                  color: Colors.amber.shade800,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 4),
                if (ratingLabel.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: ratingColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      ratingLabel,
                      style: TextStyle(
                        fontFamily: 'Cairo',
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: ratingColor,
                      ),
                    ),
                  ),
                const SizedBox(width: 4),
                Icon(Icons.chevron_left,
                    color: Colors.grey.shade300, size: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

enum _RosterSort { points, name, memorisation, attendance }
