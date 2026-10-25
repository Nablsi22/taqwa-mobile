import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/theme/taqwa_colors.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/widgets/points_display.dart';
import '../../../../core/extensions/points_formatting.dart';
import '../../../points/data/points_api.dart';
import '../../../recitation/data/recitation_api.dart';
import '../../../recitation/data/recitation_timeline.dart';
import '../../../recitation/presentation/widgets/course_section_header.dart';
import '../../../terms/presentation/providers/term_provider.dart';
import '../../../terms/presentation/widgets/term_selector.dart';
import '../../../attendance_stats/presentation/widgets/student_attendance_view.dart';
import 'add_recitation_screen.dart';
import '../../../points/presentation/widgets/award_points_modal.dart';

class InstructorStudentDetailScreen extends StatefulWidget {
  final String studentId;
  final String studentName;

  /// Tab to open on — e.g. [attendanceTab] from an absentee.
  final int initialTab;

  /// Index of «الحضور» among the tabs.
  static const int attendanceTab = 1;

  /// Index of «التسميع» among the tabs.
  static const int recitationTab = 2;

  /// The course director's view: the same page, with nothing to add or
  /// change — no «تسميع جديد», no «إضافة نقاط».
  final bool readOnly;

  /// Adds a «؟» to the app bar that explains this page — the course
  /// director's screens pass their plain-language help here.
  final VoidCallback? onHelp;

  const InstructorStudentDetailScreen({
    super.key,
    required this.studentId,
    required this.studentName,
    this.initialTab = 0,
    this.readOnly = false,
    this.onHelp,
  });

  @override
  State<InstructorStudentDetailScreen> createState() =>
      _InstructorStudentDetailScreenState();
}

class _InstructorStudentDetailScreenState
    extends State<InstructorStudentDetailScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _pointsApi = PointsApi(ApiClient.instance);
  final _recitationApi = RecitationApi(ApiClient.instance);

  bool _isLoading = true;
  String? _error;

  Map<String, dynamic> _studentInfo = {};
  List<Map<String, dynamic>> _pointsLog = [];
  /// Every course's recitations, the current course first.
  StudentRecitationTimeline _timeline = StudentRecitationTimeline.empty;
  Map<String, dynamic>? _lastRecitation; // D2
  Map<String, dynamic> _progress = {};
  Map<String, dynamic> _homework = {};
  double _totalPoints = 0;
  int _studentRank = 0;
  int _totalStudentsCount = 0;

  // ── Nawawi-40 memorization map (cumulative across terms). Additive:
  //    loaded alongside the existing data; failure is non-fatal (empty
  //    map → the tab renders all 42 as "not memorized"). ──
  HadithProgress _hadithProgress = const HadithProgress.empty();
  List<HadithRule> _hadithRules = const [];

  @override
  void initState() {
    super.initState();
    // 6 tabs: معلومات / الحضور / التسميع / النقاط / الحفظ / الأربعين
    const tabCount = 6;
    final initial = widget.initialTab;
    _tabController = TabController(
      length: tabCount,
      vsync: this,
      initialIndex: initial >= 0 && initial < tabCount ? initial : 0,
    );
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  /// Course whose figures this screen shows. Points and the mosque rank are
  /// read for this one course. The recitation tab, the memorisation map and
  /// the Nawawi progress span every course, because what a student has
  /// recited and memorised does not reset when a course ends; the recitation
  /// tab marks where each course begins.
  int? get _termId =>
      mounted ? context.read<TermProvider>().viewedTermIdParam : null;

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      await Future.wait([
        _loadStudentInfo(),
        _loadPoints(),
        _loadRecitationHistory(),
        _loadProgress(),
        _loadHomework(),
        _loadRank(),
        _loadHadith(),
      ]);
      setState(() => _isLoading = false);
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _loadStudentInfo() async {
    final termId = _termId;
    final res = await ApiClient.instance.get(
      '/students/${widget.studentId}',
      queryParameters: {if (termId != null) 'termId': termId},
    );
    _studentInfo = res.data['data'] ?? res.data;
  }

  Future<void> _loadPoints() async {
    try {
      final res = await _pointsApi.getStudentPoints(
        widget.studentId,
        termId: _termId,
      );
      final logData = res['data'] ?? [];
      if (logData is List) {
        _pointsLog =
            logData.map((e) => Map<String, dynamic>.from(e)).toList();
      }
      _totalPoints = (res['totalPoints'] ?? 0).toDouble();
    } catch (e) {
      debugPrint('Error loading points: $e');
    }
  }

  // Every course, current first. Course names come from the course list
  // when this account may read it (admin, teachers); otherwise each earlier
  // course is captioned with its dates.
  Future<void> _loadRecitationHistory() async {
    final timeline = await _recitationApi.getStudentTimeline(
      widget.studentId,
      courses: mounted ? context.read<TermProvider>().terms : null,
    );
    _timeline = timeline;
    _lastRecitation = timeline.lastRecitation;
  }

  Future<void> _loadProgress() async {
    _progress = await _recitationApi.getStudentProgress(widget.studentId);
  }

  Future<void> _loadHomework() async {
    _homework = await _recitationApi.getStudentHomework(widget.studentId);
  }

  // ── Nawawi-40: rules (42 titles/points) + this student's map. Both
  //    failures are swallowed so the rest of the screen still loads. ──
  Future<void> _loadHadith() async {
    try {
      final results = await Future.wait([
        _recitationApi.getHadithRules(),
        _recitationApi
            .getStudentHadithProgress(widget.studentId)
            .catchError((Object _) => const HadithProgress.empty()),
      ]);
      _hadithRules = results[0] as List<HadithRule>;
      _hadithProgress = results[1] as HadithProgress;
    } catch (_) {
      _hadithRules = const [];
      _hadithProgress = const HadithProgress.empty();
    }
  }

  Future<void> _loadRank() async {
    try {
      // One request, two integers. The previous implementation pulled
      // the top 100 and used the list length as the denominator, which
      // both understated the field and lost anyone ranked below 100th.
      final rank = await _pointsApi.getStudentRank(
        widget.studentId,
        termId: _termId,
      );
      _studentRank = (rank['rank'] as num?)?.toInt() ?? 0;
      _totalStudentsCount = (rank['total'] as num?)?.toInt() ?? 0;
    } catch (_) {}
  }

  void _navigateToAddRecitation() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AddRecitationScreen(
          studentId: widget.studentId,
          studentName: widget.studentName,
        ),
      ),
    );
    if (result == true) _loadData();
  }

  Future<void> _openAwardPointsModal() async {
    final awarded = await AwardPointsModal.show(
      context: context,
      studentId: widget.studentId,
      studentName: widget.studentName,
    );
    if (awarded == true) {
      await _loadPoints();
      if (mounted) setState(() {});
    }
  }

  Color _sourceColor(String sourceType) {
    switch (sourceType) {
      case 'RECITATION':
        return TaqwaColors.skyBlue;
      case 'ATTENDANCE':
        return TaqwaColors.islamicGreen;
      case 'MANUAL':
      default:
        return TaqwaColors.minaretGold;
    }
  }

  IconData _sourceIcon(String sourceType) {
    switch (sourceType) {
      case 'RECITATION':
        return Icons.menu_book_rounded;
      case 'ATTENDANCE':
        return Icons.event_available_rounded;
      case 'MANUAL':
      default:
        return Icons.star_rounded;
    }
  }

  // ─────────────────────────────────────────────────────────────────
  // D2 — rating helpers (shared between panel + history list)
  // ─────────────────────────────────────────────────────────────────
  ({Color color, String label, IconData icon}) _ratingMeta(String rating) {
    switch (rating) {
      case 'VERY_GOOD':
        return (
          color: const Color(0xFF1E8449),
          label: 'جيد جداً',
          icon: Icons.star,
        );
      case 'GOOD':
        return (
          color: const Color(0xFF2E86C1),
          label: 'جيد',
          icon: Icons.thumb_up,
        );
      case 'REPEAT':
        return (
          color: const Color(0xFFD4AC0D),
          label: 'إعادة',
          icon: Icons.replay,
        );
      case 'DID_NOT_MEMORIZE':
        return (
          color: const Color(0xFFE74C3C),
          label: 'لم يحفظ',
          icon: Icons.cancel_outlined,
        );
      case 'MAQRAA':
        return (
          color: const Color(0xFFD4AC0D),
          label: 'مقرأة',
          icon: Icons.groups,
        );
      default:
        return (
          color: Colors.grey,
          label: rating,
          icon: Icons.help_outline,
        );
    }
  }

  @override
  Widget build(BuildContext context) {
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
                            onPressed: _loadData,
                            child: const Text('إعادة المحاولة',
                                style: TextStyle(fontFamily: 'Cairo'))),
                      ],
                    ),
                  )
                : NestedScrollView(
                    headerSliverBuilder: (context, _) => [
                      _buildSliverAppBar(),
                      SliverPersistentHeader(
                        pinned: true,
                        delegate: _TabBarDelegate(
                          TabBar(
                            controller: _tabController,
                            isScrollable: true,
                            labelColor: TaqwaColors.domeBlue,
                            unselectedLabelColor: Colors.grey.shade400,
                            indicatorColor: TaqwaColors.domeBlue,
                            labelStyle: const TextStyle(
                              fontFamily: 'Cairo',
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                            unselectedLabelStyle: const TextStyle(
                              fontFamily: 'Cairo',
                              fontSize: 12,
                            ),
                            tabs: const [
                              Tab(text: 'معلومات'),
                              Tab(text: 'الحضور'),
                              Tab(text: 'التسميع'),
                              Tab(text: 'النقاط'),
                              Tab(text: 'الحفظ'),
                              Tab(text: 'الأربعين'),
                            ],
                          ),
                        ),
                      ),
                    ],
                    body: TabBarView(
                      controller: _tabController,
                      children: [
                        _buildInfoTab(),
                        StudentAttendanceView(
                          studentId: widget.studentId,
                          studentName: widget.studentName,
                          termId: _termId,
                          phone: _studentInfo['phone1']?.toString(),
                        ),
                        _buildRecitationTab(),
                        _buildPointsTab(),
                        _buildProgressTab(),
                        _buildHadithTab(),
                      ],
                    ),
                  ),
        floatingActionButton: AnimatedBuilder(
          animation: _tabController,
          builder: (context, _) {
            if (widget.readOnly) return const SizedBox.shrink();
            final index = _tabController.index;
            final isPointsTab = index == 3;
            final isHadithTab = index == 5;

            // No FAB on the attendance view or the Nawawi map — both are
            // read-only overviews.
            if (index == InstructorStudentDetailScreen.attendanceTab ||
                isHadithTab) {
              return const SizedBox.shrink();
            }

            if (isPointsTab) {
              return FloatingActionButton.extended(
                key: const ValueKey('fab_points'),
                onPressed: _openAwardPointsModal,
                backgroundColor: TaqwaColors.minaretGold,
                foregroundColor: Colors.white,
                icon: const Icon(Icons.star_rounded, size: 20),
                label: const Text(
                  'إضافة نقاط',
                  style: TextStyle(
                      fontFamily: 'Cairo', fontWeight: FontWeight.bold),
                ),
              );
            }

            return FloatingActionButton.extended(
              key: const ValueKey('fab_recitation'),
              onPressed: _navigateToAddRecitation,
              backgroundColor: TaqwaColors.islamicGreen,
              foregroundColor: Colors.white,
              icon: const Icon(Icons.add, size: 20),
              label: const Text(
                'تسميع جديد',
                style: TextStyle(
                    fontFamily: 'Cairo', fontWeight: FontWeight.bold),
              ),
            );
          },
        ),
      ),
    );
  }

  SliverAppBar _buildSliverAppBar() {
    final overallPct = _progress['overallPercentage'] ?? 0;
    final totalPages = _progress['totalPagesMemorized'] ?? 0;

    return SliverAppBar(
      expandedHeight: _homework['homework'] != null ? 300 : 240,
      pinned: true,
      backgroundColor: TaqwaColors.domeBlue,
      foregroundColor: Colors.white,
      actions: [
        TermSelectorAction(onChanged: _loadData),
        if (widget.onHelp != null)
          IconButton(
            tooltip: 'شرح هذه الصفحة',
            icon: const Icon(Icons.help_outline_rounded),
            onPressed: widget.onHelp,
          ),
      ],
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [TaqwaColors.domeBlue, Color(0xFF14395A)],
            ),
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 56, 20, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.studentName,
                    style: const TextStyle(
                      fontFamily: 'Cairo',
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: [
                      _statChip(
                          Icons.emoji_events,
                          _formatPoints(_totalPoints),
                          TaqwaColors.minaretGold),
                      if (_studentRank > 0)
                        _statChip(Icons.leaderboard,
                            '#$_studentRank/\u200F$_totalStudentsCount',
                            Colors.white),
                      _statChip(Icons.description, '$totalPages ص',
                          Colors.white70),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(6),
                          child: LinearProgressIndicator(
                            value: (overallPct as num).toDouble() / 100,
                            minHeight: 8,
                            backgroundColor:
                                Colors.white.withValues(alpha: 0.15),
                            valueColor: const AlwaysStoppedAnimation(
                                TaqwaColors.islamicGreen),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        '$overallPct%',
                        style: const TextStyle(
                          fontFamily: 'Cairo',
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                  if (_homework['homework'] != null) ...[
                    const SizedBox(height: 10),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: TaqwaColors.minaretGold
                              .withValues(alpha: 0.3),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(4),
                                decoration: BoxDecoration(
                                  color: TaqwaColors.minaretGold
                                      .withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: const Icon(Icons.assignment,
                                    size: 14,
                                    color: TaqwaColors.minaretGold),
                              ),
                              const SizedBox(width: 8),
                              const Text(
                                'الواجب الحالي',
                                style: TextStyle(
                                  fontFamily: 'Cairo',
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: TaqwaColors.minaretGold,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${_homework['homework']}',
                            style: const TextStyle(
                              fontFamily: 'Cairo',
                              fontSize: 12,
                              color: Colors.white,
                              height: 1.4,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _statChip(IconData icon, String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(
            text,
            style: TextStyle(
              fontFamily: 'Cairo',
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoTab() {
    String ageText = '-';
    final dob = _studentInfo['dateOfBirth'];
    if (dob != null && dob.toString().isNotEmpty) {
      try {
        final birthDate = DateTime.parse(dob.toString());
        final now = DateTime.now();
        int age = now.year - birthDate.year;
        if (now.month < birthDate.month ||
            (now.month == birthDate.month && now.day < birthDate.day)) {
          age--;
        }
        ageText = '$age سنة';
      } catch (_) {}
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _infoTile('الاسم الكامل', _studentInfo['fullName'] ?? '-',
            Icons.person),
        _infoTile('اسم الأب', _studentInfo['fatherName'] ?? '-',
            Icons.person_outline),
        _infoTile('العمر', ageText, Icons.cake),
        _infoTile('الصف', _studentInfo['grade'] ?? '-', Icons.class_),
        _infoTile('المدرسة', _studentInfo['school'] ?? '-', Icons.school),
        _infoTile(
            'العنوان', _studentInfo['address'] ?? '-', Icons.location_on),
        _infoTile('هاتف 1', _studentInfo['phone1'] ?? '-', Icons.phone),
        _infoTile(
            'هاتف 2', _studentInfo['phone2'] ?? '-', Icons.phone_android),
      ],
    );
  }

  Widget _infoTile(String label, String value, IconData icon) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: TaqwaColors.domeBlue.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: TaqwaColors.domeBlue, size: 20),
        ),
        title: Text(label,
            style: TextStyle(
                fontFamily: 'Cairo',
                fontSize: 11,
                color: Colors.grey.shade500)),
        subtitle: Text(value,
            style: const TextStyle(
                fontFamily: 'Cairo',
                fontSize: 14,
                fontWeight: FontWeight.w600),
            maxLines: 2,
            overflow: TextOverflow.ellipsis),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────
  // Nawawi-40 memorization map — read-only grid of the 42 ahadith.
  // Memorized entries (cumulative across terms) show islamicGreen with a
  // check; the rest are muted. Header shows «محفوظ N من 42».
  // ─────────────────────────────────────────────────────────────────
  Widget _buildHadithTab() {
    // Ordered 1..42 regardless of whether rules loaded (fallback to plain
    // numbers so the grid always renders the full set).
    final int total =
        _hadithProgress.total > 0 ? _hadithProgress.total : 42;

    String? titleFor(int n) {
      for (final r in _hadithRules) {
        if (r.hadithNumber == n) return r.title;
      }
      return null;
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Summary header
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                TaqwaColors.islamicGreen.withValues(alpha: 0.12),
                TaqwaColors.islamicGreen.withValues(alpha: 0.04),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
                color: TaqwaColors.islamicGreen.withValues(alpha: 0.25)),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                    color: TaqwaColors.islamicGreen,
                    borderRadius: BorderRadius.circular(12)),
                child: const Icon(Icons.auto_stories_rounded,
                    color: Colors.white, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('خريطة الأربعين النووية',
                        style: TextStyle(
                            fontFamily: 'Cairo',
                            fontSize: 13,
                            color: Colors.grey.shade700)),
                    const SizedBox(height: 4),
                    Text('محفوظ ${_hadithProgress.count} من $total',
                        style: const TextStyle(
                            fontFamily: 'Cairo',
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: TaqwaColors.islamicGreen)),
                  ],
                ),
              ),
              SizedBox(
                width: 54,
                height: 54,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    SizedBox(
                      width: 54,
                      height: 54,
                      child: CircularProgressIndicator(
                        value: total == 0
                            ? 0
                            : _hadithProgress.count / total,
                        strokeWidth: 5,
                        backgroundColor:
                            TaqwaColors.islamicGreen.withValues(alpha: 0.15),
                        valueColor: const AlwaysStoppedAnimation(
                            TaqwaColors.islamicGreen),
                      ),
                    ),
                    Text(
                      total == 0
                          ? '0%'
                          : '${((_hadithProgress.count / total) * 100).round()}%',
                      style: const TextStyle(
                          fontFamily: 'Cairo',
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: TaqwaColors.islamicGreen),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // 42-hadith grid
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: List.generate(total, (i) {
            final n = i + 1;
            final memorized = _hadithProgress.isMemorized(n);
            final title = titleFor(n);
            return Container(
              width: 80,
              padding:
                  const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
              decoration: BoxDecoration(
                color: memorized
                    ? TaqwaColors.islamicGreen
                    : Colors.grey.shade100,
                borderRadius: BorderRadius.circular(12),
                border: memorized
                    ? null
                    : Border.all(color: Colors.grey.shade200),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('$n',
                      style: TextStyle(
                          fontFamily: 'Cairo',
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: memorized
                              ? Colors.white
                              : Colors.grey.shade500)),
                  const SizedBox(height: 2),
                  if (memorized)
                    const Icon(Icons.check_circle,
                        size: 14, color: Colors.white)
                  else
                    Icon(Icons.circle_outlined,
                        size: 14, color: Colors.grey.shade400),
                  if (title != null && title.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(title,
                        style: TextStyle(
                            fontFamily: 'Cairo',
                            fontSize: 8.5,
                            color: memorized
                                ? Colors.white70
                                : Colors.grey.shade500),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                  ],
                ],
              ),
            );
          }),
        ),
        const SizedBox(height: 16),

        // Legend
        Row(
          children: [
            _hadithLegendDot(TaqwaColors.islamicGreen, 'محفوظ'),
            const SizedBox(width: 16),
            _hadithLegendDot(Colors.grey.shade200, 'غير محفوظ'),
          ],
        ),
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _hadithLegendDot(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
            width: 14,
            height: 14,
            decoration: BoxDecoration(
                color: color, borderRadius: BorderRadius.circular(4))),
        const SizedBox(width: 6),
        Text(label,
            style: TextStyle(
                fontFamily: 'Cairo',
                fontSize: 12,
                color: Colors.grey.shade600)),
      ],
    );
  }

  // ─────────────────────────────────────────────────────────────────
  // D2 — "آخر تسميع" panel rendered above the history list
  // ─────────────────────────────────────────────────────────────────
  Widget _buildLastRecitationCard() {
    final last = _lastRecitation;
    if (last == null) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(0, 0, 0, 12),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.grey.shade100,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: Row(
            children: [
              Icon(Icons.history, size: 18, color: Colors.grey.shade400),
              const SizedBox(width: 8),
              Text(
                'لا يوجد تسميع سابق',
                style: TextStyle(
                  fontFamily: 'Cairo',
                  fontSize: 13,
                  color: Colors.grey.shade500,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
          ),
        ),
      );
    }

    final segments = (last['segments'] as List?) ?? const [];
    final overallRating = last['overallRating'] as String?;
    final totalAyat = (last['totalAyat'] as num?)?.toInt() ?? 0;
    final totalPages = (last['totalPages'] as num?)?.toDouble() ?? 0;
    final dateStr = (last['date'] as String?) ?? (last['recitedAt'] as String?);
    final formattedDate = dateStr == null ? '' : _formatDate(dateStr);

    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 0, 0, 14),
      child: Card(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(
              color: TaqwaColors.minaretGold.withValues(alpha: 0.35)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: TaqwaColors.minaretGold.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.history,
                        size: 16, color: TaqwaColors.minaretGold),
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'آخر تسميع',
                    style: TextStyle(
                      fontFamily: 'Cairo',
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: TaqwaColors.domeBlue,
                    ),
                  ),
                  const Spacer(),
                  if (formattedDate.isNotEmpty)
                    Text(
                      formattedDate,
                      style: TextStyle(
                        fontFamily: 'Cairo',
                        fontSize: 11,
                        color: Colors.grey.shade600,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              const Divider(height: 1),
              const SizedBox(height: 10),

              // Segment rows
              ...segments.map((raw) {
                final seg = Map<String, dynamic>.from(raw as Map);
                return _buildLastRecitationSegmentRow(seg);
              }),

              const SizedBox(height: 8),
              const Divider(height: 1),
              const SizedBox(height: 10),

              // Footer — totals + overall rating
              Row(
                children: [
                  Icon(Icons.menu_book,
                      size: 14, color: Colors.grey.shade500),
                  const SizedBox(width: 4),
                  Text(
                    'المجموع: $totalAyat آية • ${_formatPagesDecimal(totalPages)} صفحة',
                    style: TextStyle(
                      fontFamily: 'Cairo',
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey.shade700,
                    ),
                  ),
                  const Spacer(),
                  if (overallRating != null)
                    _ratingChip(overallRating)
                  else
                    _mixedRatingChip(),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLastRecitationSegmentRow(Map<String, dynamic> seg) {
    final kind = (seg['kind'] as String?) ?? 'FULL_SURA';
    final surahNameAr = (seg['surahNameAr'] as String?) ?? '';
    final ayaCount = (seg['ayaCount'] as num?)?.toInt() ?? 0;
    final rating = (seg['rating'] as String?) ?? '';
    final fromAya = (seg['fromAya'] as num?)?.toInt();
    final toAya = (seg['toAya'] as num?)?.toInt();

    String rangeText;
    if (kind == 'AYA_RANGE' && fromAya != null && toAya != null) {
      rangeText = 'من آية $fromAya إلى آية $toAya';
    } else if (kind == 'MULTI_SURA') {
      rangeText = 'سور كاملة';
    } else {
      rangeText = 'كاملة';
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: TaqwaColors.domeBlue.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              surahNameAr,
              style: const TextStyle(
                fontFamily: 'Cairo',
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: TaqwaColors.domeBlue,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  rangeText,
                  style: TextStyle(
                    fontFamily: 'Cairo',
                    fontSize: 12,
                    color: Colors.grey.shade700,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  '$ayaCount آية',
                  style: TextStyle(
                    fontFamily: 'Cairo',
                    fontSize: 11,
                    color: Colors.grey.shade500,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 6),
          _ratingChip(rating),
        ],
      ),
    );
  }

  Widget _ratingChip(String rating) {
    final meta = _ratingMeta(rating);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: meta.color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(meta.icon, size: 12, color: meta.color),
          const SizedBox(width: 4),
          Text(
            meta.label,
            style: TextStyle(
              fontFamily: 'Cairo',
              fontSize: 10.5,
              fontWeight: FontWeight.bold,
              color: meta.color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _mixedRatingChip() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.grey.shade200,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.tune, size: 12, color: Colors.grey.shade700),
          const SizedBox(width: 4),
          Text(
            'تقييمات متعددة',
            style: TextStyle(
              fontFamily: 'Cairo',
              fontSize: 10.5,
              fontWeight: FontWeight.bold,
              color: Colors.grey.shade700,
            ),
          ),
        ],
      ),
    );
  }

  // Day key in ISO form so string sort equals chronological sort.
  String _dayKeyOf(dynamic raw) {
    final d = DateTime.tryParse(raw?.toString() ?? '');
    if (d == null) return '';
    final m = d.month.toString().padLeft(2, '0');
    final day = d.day.toString().padLeft(2, '0');
    return '${d.year}-$m-$day';
  }

  String _dayLabel(String key) {
    final d = DateTime.tryParse(key);
    if (d == null) return key;
    final now = DateTime.now();
    final diff = DateTime(now.year, now.month, now.day)
        .difference(DateTime(d.year, d.month, d.day))
        .inDays;
    if (diff == 0) return 'اليوم';
    if (diff == 1) return 'أمس';
    return _formatDate(key);
  }

  double _pagesOf(Map<String, dynamic> rec) {
    final raw = rec['pagesCalculated'];
    if (raw != null) return double.tryParse(raw.toString()) ?? 0;
    return ((rec['pagesRecited'] as num?) ?? 0).toDouble();
  }

  double _pointsOf(Map<String, dynamic> e) =>
      (e['pointsAwarded'] as num?)?.toDouble() ?? 0;

  // One band per course (current first), then that course's entries grouped
  // by day. Flattened into render rows so the list stays a single
  // ListView.builder rather than nested scrollables.
  List<_TimelineRow> _buildTimelineRows() {
    final rows = <_TimelineRow>[];
    if (_timeline.isEmpty) return rows;
    for (final section in _timeline.sections) {
      // An earlier course with nothing in it is not worth a band.
      if (section.isEmpty && !section.isCurrent) continue;
      rows.add(_TimelineRow.course(section));
      if (section.isEmpty) {
        rows.add(const _TimelineRow._(type: 'emptyCourse'));
        continue;
      }
      rows.addAll(_dayRows(section.recitations, section.hadith));
    }
    return rows;
  }

  // Groups one course's Quran and hadith entries by day, newest day first.
  List<_TimelineRow> _dayRows(
    List<Map<String, dynamic>> recitations,
    List<Map<String, dynamic>> hadith,
  ) {
    final byDay = <String, List<_TimelineEntry>>{};

    for (final rec in recitations) {
      final key = _dayKeyOf(rec['date'] ?? rec['createdAt']);
      (byDay[key] ??= []).add(_TimelineEntry(isHadith: false, data: rec));
    }
    for (final h in hadith) {
      final key = _dayKeyOf(h['createdAt']);
      (byDay[key] ??= []).add(_TimelineEntry(isHadith: true, data: h));
    }

    final keys = byDay.keys.toList()..sort((a, b) => b.compareTo(a));
    final rows = <_TimelineRow>[];

    for (final key in keys) {
      final entries = byDay[key]!;
      double pages = 0;
      double points = 0;
      String? homework;

      for (final e in entries) {
        points += _pointsOf(e.data);
        if (!e.isHadith) {
          pages += _pagesOf(e.data);
          final hw = e.data['homework'];
          if (hw != null && hw.toString().trim().isNotEmpty) {
            homework = hw.toString();
          }
        }
      }

      rows.add(_TimelineRow.day(key, entries.length, pages, points));
      for (final e in entries) {
        rows.add(_TimelineRow.entry(e));
      }
      if (homework != null) rows.add(_TimelineRow.homework(homework));
    }
    return rows;
  }

  Widget _buildRecitationTab() {
    final rows = _buildTimelineRows();

    if (rows.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.menu_book, size: 48, color: Colors.grey.shade300),
            const SizedBox(height: 8),
            Text('لا يوجد تسميع بعد',
                style: TextStyle(fontFamily: 'Cairo', color: Colors.grey.shade500)),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      itemCount: rows.length,
      itemBuilder: (context, index) {
        final row = rows[index];
        if (row.type == 'course') {
          return CourseSectionHeader(section: row.section!, isFirst: index == 0);
        }
        if (row.type == 'emptyCourse') return const EmptyCourseNote();
        if (row.type == 'day') return _buildDayHeader(row);
        if (row.type == 'homework') return _buildHomeworkNote(row.homework!);
        return row.entry!.isHadith
            ? _buildHadithEntryCard(row.entry!.data)
            : _buildQuranEntryCard(row.entry!.data);
      },
    );
  }

  Widget _buildDayHeader(_TimelineRow row) {
    final chips = <Widget>[
      _dayChip(
        row.count == 1
            ? 'مقطع واحد'
            : '${row.count} مقاطع',
        Colors.grey.shade100,
        Colors.grey.shade700,
      ),
    ];
    if (row.pages > 0) {
      chips.add(_dayChip(
        _formatPagesDecimal(row.pages) + ' صفحة',
        Colors.grey.shade100,
        Colors.grey.shade700,
      ));
    }
    chips.add(_dayChip(
      row.points > 0
          ? '+' + row.points.toStringAsFixed(2)
          : 'بلا نقاط',
      row.points > 0
          ? TaqwaColors.minaretGold.withValues(alpha: 0.14)
          : Colors.grey.shade100,
      row.points > 0 ? const Color(0xFF854F0B) : Colors.grey.shade600,
    ));

    return Padding(
      padding: const EdgeInsets.only(top: 14, bottom: 8),
      child: Row(
        children: [
          Text(
            _dayLabel(row.dayKey!),
            style: const TextStyle(
              fontFamily: 'Cairo',
              fontSize: 13.5,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1A1A2E),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(child: Container(height: 1, color: Colors.grey.shade200)),
          const SizedBox(width: 8),
          Wrap(spacing: 5, children: chips),
        ],
      ),
    );
  }

  Widget _dayChip(String label, Color bg, Color fg) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        textDirection: TextDirection.rtl,
        style: TextStyle(
          fontFamily: 'Cairo',
          fontSize: 10.5,
          fontWeight: FontWeight.w600,
          color: fg,
        ),
      ),
    );
  }

  // Placeholder ranges are stored for DID_NOT_MEMORIZE rows (sura 1,
  // ayah 1 to 1). Rendering that would invent a detail the instructor
  // never entered, so the range is suppressed for them.
  String _entryTitle(Map<String, dynamic> rec) {
    final rating = rec['rating']?.toString() ?? '';
    final sura = rec['suraName']?.toString() ?? '';
    if (rating == 'DID_NOT_MEMORIZE') return _ratingMeta(rating).label;
    if (rec['isCompleteSura'] == true) return sura + ' · كاملة';
    final s = rec['startAya'];
    final e = rec['endAya'];
    if (s != null && e != null) {
      return sura + ' · ' + s.toString() + ' – ' + e.toString();
    }
    return sura;
  }

  Widget _buildQuranEntryCard(Map<String, dynamic> rec) {
    final rating = rec['rating']?.toString() ?? '';
    final meta = _ratingMeta(rating);
    final pages = _pagesOf(rec);
    final points = _pointsOf(rec);
    final ayaCount = (rec['ayaCount'] as num?)?.toInt() ?? 0;
    final isNoMemo = rating == 'DID_NOT_MEMORIZE';

    final facts = <String>[];
    if (ayaCount > 0 && !isNoMemo) facts.add('$ayaCount آية');
    if (pages > 0 && !isNoMemo) {
      facts.add(_formatPagesDecimal(pages) + ' صفحة');
    }
    if (points != 0) {
      facts.add('+' + points.toStringAsFixed(2) + ' نقطة');
    }

    return _entryShell(
      edge: isNoMemo ? Colors.grey.shade400 : TaqwaColors.skyBlue,
      title: _entryTitle(rec),
      badgeLabel: meta.label,
      badgeColor: meta.color,
      facts: facts,
      highlightLast: points != 0,
    );
  }

  Widget _buildHadithEntryCard(Map<String, dynamic> h) {
    final number = (h['hadithNumber'] as num?)?.toInt() ?? 0;
    final points = _pointsOf(h);
    final title = h['title']?.toString();

    final facts = <String>[];
    if (title != null && title.trim().isNotEmpty) facts.add(title);
    if (points != 0) {
      facts.add('+' + points.toStringAsFixed(2) + ' نقطة');
    }

    return _entryShell(
      edge: const Color(0xFF7F77DD),
      title: 'الحديث ' + number.toString(),
      badgeLabel: 'الأربعين',
      badgeColor: const Color(0xFF534AB7),
      facts: facts,
      highlightLast: points != 0,
      leading: Icons.auto_stories_outlined,
    );
  }

  // One shell for both kinds: identical geometry, different edge colour
  // and badge, so a day mixing Quran and hadith still scans as one list.
  Widget _entryShell({
    required Color edge,
    required String title,
    required String badgeLabel,
    required Color badgeColor,
    required List<String> facts,
    required bool highlightLast,
    IconData? leading,
  }) {
    final factWidgets = <Widget>[];
    for (var i = 0; i < facts.length; i++) {
      if (i > 0) {
        factWidgets.add(Container(
          width: 1,
          height: 9,
          margin: const EdgeInsets.symmetric(horizontal: 8),
          color: Colors.grey.shade300,
        ));
      }
      final isPoints = highlightLast && i == facts.length - 1;
      factWidgets.add(Flexible(
        child: Text(
          facts[i],
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontFamily: 'Cairo',
            fontSize: 11,
            fontWeight: isPoints ? FontWeight.w600 : FontWeight.normal,
            color: isPoints
                ? const Color(0xFF854F0B)
                : Colors.grey.shade600,
          ),
        ),
      ));
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 7),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: IntrinsicHeight(
        child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(width: 3, color: edge),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 11, 12, 11),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      if (leading != null) ...[
                        Icon(leading, size: 14, color: badgeColor),
                        const SizedBox(width: 5),
                      ],
                      Expanded(
                        child: Text(
                          title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontFamily: 'Cairo',
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF1A1A2E),
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 9, vertical: 3),
                        decoration: BoxDecoration(
                          color: badgeColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          badgeLabel,
                          style: TextStyle(
                            fontFamily: 'Cairo',
                            fontSize: 10.5,
                            fontWeight: FontWeight.w600,
                            color: badgeColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (factWidgets.isNotEmpty) ...[
                    const SizedBox(height: 5),
                    Row(children: factWidgets),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
      ),
    );
  }

  Widget _buildHomeworkNote(String text) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 4),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: TaqwaColors.minaretGold.withValues(alpha: 0.09),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.assignment_outlined,
              size: 14, color: Color(0xFF854F0B)),
          const SizedBox(width: 7),
          Expanded(
            child: Text(
              'الواجب: ' + text,
              style: const TextStyle(
                fontFamily: 'Cairo',
                fontSize: 12,
                height: 1.6,
                color: Color(0xFF633806),
              ),
            ),
          ),
        ],
      ),
    );
  }
  Widget _buildPointsTab() {
    return Column(
      children: [
        Container(
          margin: const EdgeInsets.all(16),
          padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 24),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topRight,
              end: Alignment.bottomLeft,
              colors: [TaqwaColors.domeBlue, Color(0xFF14395A)],
            ),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: TaqwaColors.minaretGold.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(Icons.emoji_events,
                    color: TaqwaColors.minaretGold, size: 26),
              ),
              const SizedBox(height: 10),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: PointsDisplay(
                  value: _totalPoints,
                  size: PointsDisplaySize.huge,
                  color: Colors.white,
                ),
              ),
              const Text(
                'نقطة',
                style: TextStyle(
                  fontFamily: 'Cairo',
                  fontSize: 14,
                  color: Colors.white70,
                ),
              ),
              if (_studentRank > 0) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'المرتبة #$_studentRank من $_totalStudentsCount',
                    style: const TextStyle(
                      fontFamily: 'Cairo',
                      fontSize: 12,
                      color: Colors.white70,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
        Expanded(
          child: _pointsLog.isEmpty
              ? const Center(
                  child: Text('لا يوجد سجل نقاط',
                      style:
                          TextStyle(fontFamily: 'Cairo', color: Colors.grey)),
                )
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: _pointsLog.length,
                  itemBuilder: (context, index) {
                    final log = _pointsLog[index];
                    final amount = (log['amount'] ?? 0).toDouble();
                    final isPositive = amount > 0;

                    final sourceType =
                        (log['sourceType'] as String?) ?? 'MANUAL';
                    final displayLabel =
                        (log['displayLabel'] as String?) ?? 'نقاط خاصة';
                    final description = _arabizeRating(
                        (log['description'] as String?)?.trim() ?? '');
                    final categoryName =
                        (log['categoryName'] as String?)?.trim() ?? '';
                    final title = description.isNotEmpty
                        ? description
                        : (categoryName.isNotEmpty ? categoryName : 'نقاط');

                    final sourceColor = _sourceColor(sourceType);
                    final sourceIcon = _sourceIcon(sourceType);
                    final createdAt = log['createdAt'] ?? '';

                    return Card(
                      margin: const EdgeInsets.only(bottom: 6),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 10),
                        child: Row(
                          children: [
                            Container(
                              width: 42,
                              height: 42,
                              decoration: BoxDecoration(
                                color: (isPositive
                                        ? Colors.green
                                        : Colors.red)
                                    .withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Center(
                                child: FittedBox(
                                  fit: BoxFit.scaleDown,
                                  child: Padding(
                                    padding: const EdgeInsets.all(2),
                                    child: Text(
                                      isPositive
                                          ? '+${_formatPoints(amount)}'
                                          : _formatPoints(amount),
                                      textDirection: TextDirection.ltr,
                                      style: TextStyle(
                                        fontFamily: 'Cairo',
                                        fontSize: 13,
                                        fontWeight: FontWeight.bold,
                                        fontFeatures: const [
                                          FontFeature.tabularFigures()
                                        ],
                                        color: isPositive
                                            ? Colors.green
                                            : Colors.red,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                children: [
                                  _buildSourcePill(displayLabel,
                                      sourceColor, sourceIcon),
                                  const SizedBox(height: 4),
                                  Text(
                                    title,
                                    style: const TextStyle(
                                        fontFamily: 'Cairo',
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    _formatDate(createdAt),
                                    style: TextStyle(
                                        fontFamily: 'Cairo',
                                        fontSize: 11,
                                        color: Colors.grey.shade500),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildSourcePill(String label, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.35), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontFamily: 'Cairo',
              fontSize: 10.5,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProgressTab() {
    final suraProgressList =
        (_progress['suraProgress'] as List?)?.cast<Map<String, dynamic>>() ??
            [];

    if (suraProgressList.isEmpty) {
      return const Center(
        child: Text('لا توجد بيانات حفظ بعد',
            style: TextStyle(fontFamily: 'Cairo', color: Colors.grey)),
      );
    }

    final juzMap = <int, List<Map<String, dynamic>>>{};
    for (final sp in suraProgressList) {
      final juz = sp['juz'] ?? 1;
      juzMap.putIfAbsent(juz, () => []).add(sp);
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: juzMap.length,
      itemBuilder: (context, index) {
        final juzNumber = juzMap.keys.elementAt(index);
        final suras = juzMap[juzNumber]!;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 12, vertical: 6),
              margin: const EdgeInsets.only(bottom: 8),
              decoration: BoxDecoration(
                color: TaqwaColors.minaretGold.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                'الجزء $juzNumber',
                style: const TextStyle(
                  fontFamily: 'Cairo',
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: TaqwaColors.minaretGold,
                ),
              ),
            ),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: suras.map((sp) {
                final percentage = sp['percentage'] ?? 0;
                final isComplete = sp['isComplete'] == true;
                final suraName = sp['suraName'] ?? '';

                Color bgColor;
                Color textColor;
                if (isComplete) {
                  bgColor = TaqwaColors.islamicGreen;
                  textColor = Colors.white;
                } else if (percentage > 0) {
                  bgColor = TaqwaColors.islamicGreen.withValues(alpha: 0.15);
                  textColor = TaqwaColors.islamicGreen;
                } else {
                  bgColor = Colors.grey.shade100;
                  textColor = Colors.grey.shade500;
                }

                return Container(
                  width: 78,
                  height: 52,
                  decoration: BoxDecoration(
                    color: bgColor,
                    borderRadius: BorderRadius.circular(10),
                    border: percentage > 0 && !isComplete
                        ? Border.all(
                            color: TaqwaColors.islamicGreen
                                .withValues(alpha: 0.3))
                        : null,
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        suraName,
                        style: TextStyle(
                          fontFamily: 'Cairo',
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: textColor,
                        ),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                      if (!isComplete && percentage > 0)
                        Text(
                          '$percentage%',
                          style: TextStyle(
                            fontFamily: 'Cairo',
                            fontSize: 9,
                            color: textColor,
                          ),
                        ),
                      if (isComplete)
                        Icon(Icons.check, size: 12, color: textColor),
                    ],
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 16),
          ],
        );
      },
    );
  }

  String _formatPoints(double value) => value.asPoints;

  String _formatPagesDecimal(double value) {
    if (value == value.truncateToDouble()) {
      return value.toInt().toString();
    }
    final s = value.toStringAsFixed(2);
    return s.replaceAll(RegExp(r'0+$'), '').replaceAll(RegExp(r'\.$'), '');
  }

  String _arabizeRating(String s) {
    return s
        .replaceAll('VERY_GOOD', 'جيد جداً')
        .replaceAll('GOOD', 'جيد')
        .replaceAll('REPEAT', 'إعادة')
        .replaceAll('DID_NOT_MEMORIZE', 'لم يحفظ')
        .replaceAll('MAQRAA', 'مقرأة');
  }

  String _formatDate(String dateStr) {
    try {
      final date = DateTime.parse(dateStr);
      final days = [
        'الاثنين',
        'الثلاثاء',
        'الأربعاء',
        'الخميس',
        'الجمعة',
        'السبت',
        'الأحد',
      ];
      final months = [
        '',
        'يناير',
        'فبراير',
        'مارس',
        'أبريل',
        'مايو',
        'يونيو',
        'يوليو',
        'أغسطس',
        'سبتمبر',
        'أكتوبر',
        'نوفمبر',
        'ديسمبر',
      ];
      return '${days[date.weekday - 1]} ${date.day} ${months[date.month]}';
    } catch (_) {
      return dateStr;
    }
  }
}

// One entry on the timeline. isHadith selects which card renders it;
// both kinds carry a plain map so no model class has to be kept in
// step with the backend response.
class _TimelineEntry {
  final bool isHadith;
  final Map<String, dynamic> data;
  const _TimelineEntry({required this.isHadith, required this.data});
}

// A flattened render row. Grouping produces headers, entries and an
// optional homework note per day; flattening keeps the whole tab in a
// single ListView.builder instead of nested scrollables.
class _TimelineRow {
  final String type;
  final String? dayKey;
  final int count;
  final double pages;
  final double points;
  final _TimelineEntry? entry;
  final String? homework;
  final CourseSection? section;

  const _TimelineRow._({
    required this.type,
    this.dayKey,
    this.count = 0,
    this.pages = 0,
    this.points = 0,
    this.entry,
    this.homework,
    this.section,
  });

  factory _TimelineRow.course(CourseSection section) =>
      _TimelineRow._(type: 'course', section: section);

  factory _TimelineRow.day(
    String key,
    int count,
    double pages,
    double points,
  ) =>
      _TimelineRow._(type: 'day', dayKey: key, count: count,
          pages: pages, points: points);

  factory _TimelineRow.entry(_TimelineEntry e) =>
      _TimelineRow._(type: 'entry', entry: e);

  factory _TimelineRow.homework(String text) =>
      _TimelineRow._(type: 'homework', homework: text);
}

class _TabBarDelegate extends SliverPersistentHeaderDelegate {
  final TabBar tabBar;
  _TabBarDelegate(this.tabBar);

  @override
  double get minExtent => tabBar.preferredSize.height;
  @override
  double get maxExtent => tabBar.preferredSize.height;

  @override
  Widget build(
      BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(color: Colors.white, child: tabBar);
  }

  @override
  bool shouldRebuild(covariant _TabBarDelegate oldDelegate) => false;
}