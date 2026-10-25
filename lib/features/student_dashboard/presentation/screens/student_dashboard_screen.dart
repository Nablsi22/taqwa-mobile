import 'dart:convert';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/theme/taqwa_colors.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/constants/quran_metadata.dart';
import '../../../../core/widgets/points_display.dart';
import '../../../../core/extensions/points_formatting.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../auth/presentation/widgets/logout_dialog.dart';
import '../../../points/data/points_api.dart';
import '../../../recitation/data/recitation_api.dart';
import '../../../recitation/data/recitation_timeline.dart';
import '../../../recitation/presentation/widgets/course_section_header.dart';
import '../../../azkar/presentation/screens/azkar_home_screen.dart';
import '../../../announcement/presentation/screens/announcement_list_screen.dart';
import '../../../quran_reader/presentation/screens/quran_surah_list_screen.dart';
import 'leaderboard_screen.dart';
import '../../../../core/widgets/taqwa_slogan_banner.dart';

class StudentDashboardScreen extends StatefulWidget {
  const StudentDashboardScreen({super.key});

  @override
  State<StudentDashboardScreen> createState() => _StudentDashboardScreenState();
}

class _StudentDashboardScreenState extends State<StudentDashboardScreen>
    with SingleTickerProviderStateMixin {
  final _pointsApi = PointsApi(ApiClient.instance);
  final _recitationApi = RecitationApi(ApiClient.instance);

  bool _isLoading = true;
  String? _error;

  String _studentName = '';
  String? _studentId;
  // Points are stored as Decimal(7,3) on the backend and may arrive
  // as int, double, or String — keep them as `num` in the UI layer
  // and let PointsDisplay/.asPoints handle the formatting.
  num _totalPoints = 0;
  int _studentRank = 0;
  int _totalStudentsCount = 0;
  double _overallPercentage = 0;
  int _totalPagesMemorized = 0;
  int _completedSuras = 0;
  List<Map<String, dynamic>> _suraProgress = [];
  Map<String, dynamic> _homework = {};
  List<Map<String, dynamic>> _announcements = [];
  bool _hasNewAnnouncements = false;
  List<Map<String, dynamic>> _gifts = [];
  /// Every Quran recitation, all courses, current course first.
  List<Map<String, dynamic>> _recitationHistory = [];

  /// The same recitations split by course for «سجل التسميع».
  List<CourseSection> _recitationSections = const [];
  List<Map<String, dynamic>> _pointsLog = [];
  List<Map<String, dynamic>> _leaderboard = [];
  Map<String, int> _attendance = {'present': 0, 'late': 0, 'absent': 0};
  Map<int, double> _suraProgressMap = {};

  // ── Nawawi-40 memorization map (cumulative across terms). Additive:
  //    loaded alongside dashboard data; failure is non-fatal. ──
  HadithProgress _hadithProgress = const HadithProgress.empty();

  late AnimationController _pulseController;
  final ScrollController _giftsScrollController = ScrollController();
  int _currentGiftIndex = 0;

  void _startGiftsAutoScroll() {
    Future.doWhile(() async {
      await Future.delayed(const Duration(seconds: 3));
      if (!mounted || _gifts.isEmpty) return false;
      _currentGiftIndex = (_currentGiftIndex + 1) % _gifts.length;
      final offset = _currentGiftIndex * 138.0;
      if (_giftsScrollController.hasClients) {
        _giftsScrollController.animateTo(
          offset.clamp(0.0, _giftsScrollController.position.maxScrollExtent),
          duration: const Duration(milliseconds: 600),
          curve: Curves.easeInOut,
        );
      }
      return true;
    });
  }

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadAllData());
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) _startGiftsAutoScroll();
    });
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _giftsScrollController.dispose();
    super.dispose();
  }

  // ═══════════════════════════════════════════════════════
  // DATA LOADING
  // ═══════════════════════════════════════════════════════

  Future<void> _loadAllData() async {
    final authProvider = context.read<AuthProvider>();
    final user = authProvider.user;
    if (user == null || user.profile == null) {
      setState(() { _error = '\u0644\u0627 \u064a\u0645\u0643\u0646 \u062a\u062d\u0645\u064a\u0644 \u0627\u0644\u0628\u064a\u0627\u0646\u0627\u062a'; _isLoading = false; });
      return;
    }
    _studentId = user.profile!.id;
    _studentName = user.profile!.fullName ?? '\u0627\u0644\u0637\u0627\u0644\u0628';
    try {
      await Future.wait([
        _loadPoints(), _loadProgress(), _loadHomework(),
        _loadAnnouncements(), _loadGifts(), _loadRecitationHistory(),
        _loadLeaderboard(), _loadAttendance(), _loadHadithProgress(),
      ]);
      _buildSuraProgressMap();
      if ((_suraProgressMap.isEmpty || _totalPagesMemorized == 0) && _recitationHistory.isNotEmpty) {
        _calculateProgressFromHistory();
      }
      if (mounted) setState(() => _isLoading = false);
    } catch (e) {
      if (mounted) setState(() { _error = e.toString(); _isLoading = false; });
    }
  }

  /// Safely coerces any JSON-parsed numeric value (int, double, String)
  /// into a [num]. Prisma's Decimal columns serialize as String, so we
  /// must parse defensively here.
  num _toNum(dynamic v) {
    if (v == null) return 0;
    if (v is num) return v;
    return num.tryParse(v.toString()) ?? 0;
  }

  Future<void> _loadPoints() async {
    try {
      final res = await _pointsApi.getStudentPoints(_studentId!);
      final logData = res['data'] ?? [];
      if (logData is List) _pointsLog = logData.map((e) => Map<String, dynamic>.from(e)).toList();
      _totalPoints = _toNum(res['totalPoints']);
    } catch (_) {}
  }

  Future<void> _loadProgress() async {
    try {
      final res = await _recitationApi.getStudentProgress(_studentId!);
      _overallPercentage = (res['overallPercentage'] ?? 0).toDouble();
      _totalPagesMemorized = (res['totalPagesMemorized'] ?? 0).round();
      _completedSuras = (res['completedSuras'] ?? 0).round();
      final sp = res['suraProgress'];
      if (sp is List) _suraProgress = sp.map((e) => Map<String, dynamic>.from(e)).toList();
    } catch (_) {}
  }

  Future<void> _loadHomework() async {
    try { _homework = await _recitationApi.getStudentHomework(_studentId!); } catch (_) {}
  }

  Future<void> _loadAnnouncements() async {
    try {
      final res = await ApiClient.instance.get('/announcements');
      final data = res.data['data'] ?? res.data;
      if (data is List) {
        _announcements = data.map((e) => Map<String, dynamic>.from(e)).toList();
        final now = DateTime.now();
        _hasNewAnnouncements = _announcements.any((a) {
          try { return now.difference(DateTime.parse(a['publishedAt'] ?? a['createdAt'] ?? '')).inHours < 24; } catch (_) { return false; }
        });
      }
    } catch (_) {}
  }

  Future<void> _loadGifts() async {
    try {
      final res = await ApiClient.instance.get('/gifts');
      final data = res.data['data'] ?? res.data;
      if (data is List) _gifts = data.map((e) => Map<String, dynamic>.from(e)).toList();
    } catch (_) {}
  }

  // Every course, current first. A parent's account cannot list courses, so
  // each earlier course is captioned with its dates.
  Future<void> _loadRecitationHistory() async {
    try {
      final timeline = await _recitationApi.getStudentTimeline(_studentId!);
      _recitationSections = timeline.sections;
      _recitationHistory = timeline.allRecitations;
    } catch (_) {}
  }

  Future<void> _loadHadithProgress() async {
    try {
      _hadithProgress =
          await _recitationApi.getStudentHadithProgress(_studentId!);
    } catch (_) {
      _hadithProgress = const HadithProgress.empty();
    }
  }

  Future<void> _loadLeaderboard() async {
    try {
      _leaderboard = await _pointsApi.getLeaderboard(limit: 100);
      for (int i = 0; i < _leaderboard.length; i++) {
        if (_leaderboard[i]['id'] == _studentId || _leaderboard[i]['studentId'] == _studentId) { _studentRank = i + 1; break; }
      }
      _totalStudentsCount = _leaderboard.length;
    } catch (_) {}
  }

  Future<void> _loadAttendance() async {
    try {
      final res = await ApiClient.instance.dio.get('/attendance/student/$_studentId');
      if (res.data['summary'] != null) {
        _attendance = { 'present': res.data['summary']['present'] as int? ?? 0, 'late': res.data['summary']['late'] as int? ?? 0, 'absent': res.data['summary']['absent'] as int? ?? 0 };
      }
    } catch (_) {}
  }

  void _buildSuraProgressMap() {
    _suraProgressMap = {};
    for (final sp in _suraProgress) {
      final num = sp['surahNumber'] ?? sp['suraNumber'] ?? 0;
      final pct = (sp['percentage'] ?? 0).toDouble();
      if (num > 0) _suraProgressMap[num] = pct;
    }
  }

  void _calculateProgressFromHistory() {
    final suraPages = <int, double>{};
    for (final rec in _recitationHistory) {
      final rating = rec['rating'] ?? '';
      if (rating == 'VERY_GOOD' || rating == 'GOOD') {
        final sura = rec['surahNumber'] ?? 0;
        final pages = (rec['pagesRecited'] ?? 0).toDouble();
        if (rec['isCompleteSura'] == true && sura > 0 && sura <= 114) {
          suraPages[sura] = suraList[sura - 1].totalPages.toDouble();
        } else {
          suraPages[sura] = (suraPages[sura] ?? 0) + pages;
        }
      }
    }
    double totalPages = 0;
    _suraProgressMap = {};
    for (final entry in suraPages.entries) {
      if (entry.key > 0 && entry.key <= 114) {
        final maxPages = suraList[entry.key - 1].totalPages.toDouble();
        final capped = entry.value.clamp(0.0, maxPages);
        totalPages += capped;
        _suraProgressMap[entry.key] = (capped / maxPages * 100).clamp(0, 100);
      }
    }
    _totalPagesMemorized = totalPages.round();
    _overallPercentage = double.parse((_totalPagesMemorized / 604 * 100).toStringAsFixed(1));
    _completedSuras = suraPages.entries.where((e) => e.key > 0 && e.key <= 114 && e.value >= suraList[e.key - 1].totalPages).length;
  }

  // ═══════════════════════════════════════════════════════
  // DATE HELPERS
  // ═══════════════════════════════════════════════════════

  static const _dayNames = ['\u0627\u0644\u0627\u062b\u0646\u064a\u0646', '\u0627\u0644\u062b\u0644\u0627\u062b\u0627\u0621', '\u0627\u0644\u0623\u0631\u0628\u0639\u0627\u0621', '\u0627\u0644\u062e\u0645\u064a\u0633', '\u0627\u0644\u062c\u0645\u0639\u0629', '\u0627\u0644\u0633\u0628\u062a', '\u0627\u0644\u0623\u062d\u062f'];
  static const _monthNames = ['', '\u064a\u0646\u0627\u064a\u0631', '\u0641\u0628\u0631\u0627\u064a\u0631', '\u0645\u0627\u0631\u0633', '\u0623\u0628\u0631\u064a\u0644', '\u0645\u0627\u064a\u0648', '\u064a\u0648\u0646\u064a\u0648', '\u064a\u0648\u0644\u064a\u0648', '\u0623\u063a\u0633\u0637\u0633', '\u0633\u0628\u062a\u0645\u0628\u0631', '\u0623\u0643\u062a\u0648\u0628\u0631', '\u0646\u0648\u0641\u0645\u0628\u0631', '\u062f\u064a\u0633\u0645\u0628\u0631'];

  String _formatDate(String? dateStr) {
    if (dateStr == null || dateStr.isEmpty) return '';
    try {
      final date = DateTime.parse(dateStr);
      final now = DateTime.now();
      final diff = now.difference(date);
      if (diff.inDays == 0) return '\u0627\u0644\u064a\u0648\u0645';
      if (diff.inDays == 1) return '\u0623\u0645\u0633';
      if (diff.inDays < 7) return '${_dayNames[date.weekday - 1]}';
      return '${date.day} ${_monthNames[date.month]}';
    } catch (_) {
      return '';
    }
  }

  String _formatDateFull(String? dateStr) {
    if (dateStr == null || dateStr.isEmpty) return '';
    try {
      final date = DateTime.parse(dateStr);
      return '${_dayNames[date.weekday - 1]} ${date.day} ${_monthNames[date.month]}';
    } catch (_) {
      return '';
    }
  }

  // ═══════════════════════════════════════════════════════
  // BUILD
  // ═══════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFFF5F6FA),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator(color: TaqwaColors.domeBlue))
            : _error != null
                ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                    Text(_error!, style: const TextStyle(fontFamily: 'Cairo')),
                    const SizedBox(height: 12),
                    ElevatedButton(onPressed: () { setState(() { _isLoading = true; _error = null; }); _loadAllData(); },
                        child: const Text('\u0625\u0639\u0627\u062f\u0629 \u0627\u0644\u0645\u062d\u0627\u0648\u0644\u0629', style: TextStyle(fontFamily: 'Cairo'))),
                  ]))
                : RefreshIndicator(
                    color: TaqwaColors.domeBlue,
                    onRefresh: _loadAllData,
                    child: SingleChildScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        _buildHeader(),
                        const TaqwaSloganBanner(),
                        if (_homework['homework'] != null) _buildHomeworkCard(),
                        if (_announcements.isNotEmpty) _buildAnnouncementsSection(),
                        _buildQuickActions(),
                        _buildAttendanceSummary(),
                        _buildQuranMapCard(),
                        _buildHadithMapCard(),
                        if (_gifts.isNotEmpty) _buildGiftsSlider(),
                        _buildLeaderboardPreview(),
                        if (_recitationHistory.isNotEmpty) _buildRecitationSection(),
                        if (_pointsLog.isNotEmpty) _buildPointsSection(),
                        const SizedBox(height: 40),
                      ]),
                    ),
                  ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════
  // HEADER
  // ═══════════════════════════════════════════════════════

  Widget _buildHeader() {
    return Container(
      padding: EdgeInsets.fromLTRB(20, MediaQuery.of(context).padding.top + 12, 20, 20),
      decoration: const BoxDecoration(
        gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [TaqwaColors.domeBlue, Color(0xFF14395A)]),
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(28)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(mainAxisAlignment: MainAxisAlignment.end, children: [
          IconButton(tooltip: '\u062a\u0633\u062c\u064a\u0644 \u0627\u0644\u062e\u0631\u0648\u062c', onPressed: () => confirmLogout(context), icon: const Icon(Icons.logout_rounded, color: Colors.white70, size: 20), padding: EdgeInsets.zero, constraints: const BoxConstraints()),
          const SizedBox(width: 8),
          IconButton(onPressed: () { setState(() => _isLoading = true); _loadAllData(); }, icon: const Icon(Icons.refresh, color: Colors.white70, size: 20), padding: EdgeInsets.zero, constraints: const BoxConstraints()),
        ]),
        Text(_studentName, style: const TextStyle(fontFamily: 'Cairo', fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white), maxLines: 1, overflow: TextOverflow.ellipsis),
        const SizedBox(height: 12),
        IntrinsicHeight(child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          _pointsStatCard(_totalPoints, '\u0646\u0642\u0637\u0629', TaqwaColors.minaretGold),
          const SizedBox(width: 8),
          _statCard(Icons.leaderboard, _studentRank > 0 ? '#$_studentRank' : '-', '\u0645\u0646 $_totalStudentsCount', Colors.white),
          const SizedBox(width: 8),
          _statCard(Icons.menu_book, '$_totalPagesMemorized', '\u0635\u0641\u062d\u0629', TaqwaColors.islamicGreen),
        ])),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: Colors.white.withOpacity(0.1), borderRadius: BorderRadius.circular(14)),
          child: Column(children: [
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              const Text('\u0646\u0633\u0628\u0629 \u0627\u0644\u062d\u0641\u0638', style: TextStyle(fontFamily: 'Cairo', fontSize: 13, color: Colors.white70)),
              Flexible(child: Text('$_overallPercentage% \u2022 $_completedSuras \u0633\u0648\u0631\u0629', style: const TextStyle(fontFamily: 'Cairo', fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white), maxLines: 1, overflow: TextOverflow.ellipsis)),
            ]),
            const SizedBox(height: 8),
            ClipRRect(borderRadius: BorderRadius.circular(6), child: LinearProgressIndicator(value: _overallPercentage / 100, minHeight: 10, backgroundColor: Colors.white.withOpacity(0.15), valueColor: const AlwaysStoppedAnimation(TaqwaColors.islamicGreen))),
            const SizedBox(height: 4),
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Flexible(child: Text('$_totalPagesMemorized / $totalQuranPages \u0635\u0641\u062d\u0629', style: const TextStyle(fontFamily: 'Cairo', fontSize: 11, color: Colors.white54), maxLines: 1, overflow: TextOverflow.ellipsis)),
              Flexible(child: Text('$_completedSuras / $totalSuras \u0633\u0648\u0631\u0629', style: const TextStyle(fontFamily: 'Cairo', fontSize: 11, color: Colors.white54), maxLines: 1, overflow: TextOverflow.ellipsis)),
            ]),
          ]),
        ),
      ]),
    );
  }

  /// Header stat card dedicated to rendering the student's total points.
  /// Uses [PointsDisplay] to guarantee 2-decimal formatting, tabular
  /// figures, and proper LTR numeric direction inside the RTL header.
  Widget _pointsStatCard(num value, String label, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.1),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.emoji_events, color: color, size: 20),
            const SizedBox(height: 3),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: PointsDisplay(
                value: value,
                size: PointsDisplaySize.medium,
                color: color,
              ),
            ),
            Text(
              label,
              style: const TextStyle(
                fontFamily: 'Cairo',
                fontSize: 10,
                color: Colors.white54,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _statCard(IconData icon, String value, String label, Color color) {
    return Expanded(child: Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(color: Colors.white.withOpacity(0.1), borderRadius: BorderRadius.circular(14)),
      child: Column(mainAxisAlignment: MainAxisAlignment.center, mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, color: color, size: 20), const SizedBox(height: 3),
        FittedBox(fit: BoxFit.scaleDown, child: Text(value, style: TextStyle(fontFamily: 'Cairo', fontSize: 16, fontWeight: FontWeight.bold, color: color))),
        Text(label, style: const TextStyle(fontFamily: 'Cairo', fontSize: 10, color: Colors.white54), maxLines: 1, overflow: TextOverflow.ellipsis),
      ]),
    ));
  }

  // ═══════════════════════════════════════════════════════
  // HOMEWORK
  // ═══════════════════════════════════════════════════════

  Widget _buildHomeworkCard() {
    return Padding(padding: const EdgeInsets.fromLTRB(16, 16, 16, 0), child: Container(
      width: double.infinity, padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [TaqwaColors.minaretGold.withOpacity(0.12), TaqwaColors.minaretGold.withOpacity(0.04)]),
        borderRadius: BorderRadius.circular(16), border: Border.all(color: TaqwaColors.minaretGold.withOpacity(0.25)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(padding: const EdgeInsets.all(6), decoration: BoxDecoration(color: TaqwaColors.minaretGold.withOpacity(0.15), borderRadius: BorderRadius.circular(8)),
              child: const Icon(Icons.assignment, size: 18, color: TaqwaColors.minaretGold)),
          const SizedBox(width: 10),
          const Text('\u0627\u0644\u0648\u0627\u062c\u0628', style: TextStyle(fontFamily: 'Cairo', fontSize: 16, fontWeight: FontWeight.bold, color: TaqwaColors.domeBlue)),
        ]),
        const SizedBox(height: 10),
        Text('${_homework['homework']}', style: const TextStyle(fontFamily: 'Cairo', fontSize: 14, height: 1.5, color: Colors.black87)),
        if (_homework['suraName'] != null) ...[
          const SizedBox(height: 6),
          Row(children: [Icon(Icons.menu_book, size: 14, color: Colors.grey.shade500), const SizedBox(width: 4),
            Flexible(child: Text('${_homework['suraName']}', style: TextStyle(fontFamily: 'Cairo', fontSize: 12, color: Colors.grey.shade600), maxLines: 1, overflow: TextOverflow.ellipsis))]),
        ],
      ]),
    ));
  }

  // ═══════════════════════════════════════════════════════
  // ANNOUNCEMENTS
  // ═══════════════════════════════════════════════════════

  Widget _buildAnnouncementsSection() {
    final latest = _announcements.take(2).toList();
    return Padding(padding: const EdgeInsets.fromLTRB(16, 14, 16, 0), child: Column(children: [
      Row(children: [
        const Icon(Icons.campaign, size: 18, color: TaqwaColors.domeBlue), const SizedBox(width: 6),
        const Text('\u0627\u0644\u0625\u0639\u0644\u0627\u0646\u0627\u062a', style: TextStyle(fontFamily: 'Cairo', fontSize: 16, fontWeight: FontWeight.bold, color: TaqwaColors.domeBlue)),
        if (_hasNewAnnouncements) ...[const SizedBox(width: 6), Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2), decoration: BoxDecoration(color: Colors.red, borderRadius: BorderRadius.circular(4)),
            child: const Text('\u062c\u062f\u064a\u062f', style: TextStyle(fontFamily: 'Cairo', fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white)))],
        const Spacer(),
        TextButton(onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AnnouncementListScreen())),
            child: const Text('\u0627\u0644\u0643\u0644', style: TextStyle(fontFamily: 'Cairo', fontSize: 12))),
      ]),
      const SizedBox(height: 6),
      ...latest.map((a) {
        final title = a['title'] ?? ''; final body = a['body'] ?? '';
        bool isNew = false;
        try { isNew = DateTime.now().difference(DateTime.parse(a['publishedAt'] ?? a['createdAt'] ?? '')).inHours < 24; } catch (_) {}
        return Container(width: double.infinity, margin: const EdgeInsets.only(bottom: 6), padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: isNew ? TaqwaColors.skyBlue.withOpacity(0.06) : Colors.white, borderRadius: BorderRadius.circular(12),
              border: Border.all(color: isNew ? TaqwaColors.skyBlue.withOpacity(0.2) : Colors.grey.shade200)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: const TextStyle(fontFamily: 'Cairo', fontSize: 13, fontWeight: FontWeight.bold), maxLines: 1, overflow: TextOverflow.ellipsis),
            const SizedBox(height: 2),
            Text(body, style: TextStyle(fontFamily: 'Cairo', fontSize: 12, color: Colors.grey.shade700, height: 1.4), maxLines: 2, overflow: TextOverflow.ellipsis),
          ]));
      }),
    ]));
  }

  // ═══════════════════════════════════════════════════════
  // QUICK ACTIONS
  // ═══════════════════════════════════════════════════════

  Widget _buildQuickActions() {
    return Padding(padding: const EdgeInsets.fromLTRB(16, 14, 16, 0), child: Row(children: [
      _quickBtn(Icons.campaign, '\u0627\u0644\u0625\u0639\u0644\u0627\u0646\u0627\u062a', TaqwaColors.skyBlue, hasNotif: _hasNewAnnouncements, onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AnnouncementListScreen()))),
      const SizedBox(width: 10),
      _quickBtn(Icons.menu_book, '\u0627\u0644\u0642\u0631\u0622\u0646', TaqwaColors.domeBlue, onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const QuranSurahListScreen()))),
      const SizedBox(width: 10),
      _quickBtn(Icons.spa, '\u0627\u0644\u0623\u0630\u0643\u0627\u0631', TaqwaColors.islamicGreen, onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AzkarHomeScreen()))),
    ]));
  }

  Widget _quickBtn(IconData icon, String label, Color color, {bool hasNotif = false, required VoidCallback onTap}) {
    return Expanded(child: Material(color: color.withOpacity(0.08), borderRadius: BorderRadius.circular(14),
      child: InkWell(borderRadius: BorderRadius.circular(14), onTap: onTap,
        child: Padding(padding: const EdgeInsets.symmetric(vertical: 12), child: Column(mainAxisSize: MainAxisSize.min, children: [
          Stack(clipBehavior: Clip.none, children: [
            Icon(icon, color: color, size: 24),
            if (hasNotif) Positioned(top: -4, left: -4, child: Container(width: 10, height: 10, decoration: BoxDecoration(color: Colors.red, shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 1.5)))),
          ]),
          const SizedBox(height: 5),
          Text(label, style: TextStyle(fontFamily: 'Cairo', fontSize: 11, fontWeight: FontWeight.bold, color: color), maxLines: 1, overflow: TextOverflow.ellipsis),
        ])))));
  }

  // ═══════════════════════════════════════════════════════
  // ATTENDANCE
  // ═══════════════════════════════════════════════════════

  Widget _buildAttendanceSummary() {
    final total = _attendance['present']! + _attendance['late']! + _attendance['absent']!;
    if (total == 0) return const SizedBox.shrink();
    return Padding(padding: const EdgeInsets.fromLTRB(16, 14, 16, 0), child: Container(padding: const EdgeInsets.all(14), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
      child: Row(children: [
        const Icon(Icons.calendar_today, size: 16, color: TaqwaColors.domeBlue), const SizedBox(width: 8),
        const Text('\u0627\u0644\u062d\u0636\u0648\u0631', style: TextStyle(fontFamily: 'Cairo', fontSize: 14, fontWeight: FontWeight.bold, color: TaqwaColors.domeBlue)),
        const Spacer(),
        _attendBadge('${_attendance['present']}', '\u062d\u0627\u0636\u0631', TaqwaColors.islamicGreen), const SizedBox(width: 8),
        _attendBadge('${_attendance['late']}', '\u0645\u062a\u0623\u062e\u0631', TaqwaColors.minaretGold), const SizedBox(width: 8),
        _attendBadge('${_attendance['absent']}', '\u063a\u0627\u0626\u0628', Colors.red),
      ])));
  }

  Widget _attendBadge(String count, String label, Color color) {
    return Column(mainAxisSize: MainAxisSize.min, children: [
      Container(width: 30, height: 30, decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
        child: Center(child: FittedBox(fit: BoxFit.scaleDown, child: Padding(padding: const EdgeInsets.all(2),
            child: Text(count, style: TextStyle(fontFamily: 'Cairo', fontSize: 13, fontWeight: FontWeight.bold, color: color)))))),
      const SizedBox(height: 2),
      Text(label, style: TextStyle(fontFamily: 'Cairo', fontSize: 9, color: Colors.grey.shade500)),
    ]);
  }

  // ═══════════════════════════════════════════════════════
  // QURAN MAP — Compact card + bottom sheet
  // ═══════════════════════════════════════════════════════

  Widget _buildQuranMapCard() {
    final completedCount = _suraProgressMap.values.where((p) => p >= 100).length;
    final inProgressCount = _suraProgressMap.values.where((p) => p > 0 && p < 100).length;

    return Padding(padding: const EdgeInsets.fromLTRB(16, 14, 16, 0), child: Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: _showQuranMapSheet,
        child: Padding(padding: const EdgeInsets.all(16), child: Row(children: [
          Container(
            width: 48, height: 48,
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [TaqwaColors.islamicGreen, Color(0xFF27AE60)]),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(Icons.auto_stories, color: Colors.white, size: 24),
          ),
          const SizedBox(width: 14),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('\u062e\u0631\u064a\u0637\u0629 \u0627\u0644\u062d\u0641\u0638', style: TextStyle(fontFamily: 'Cairo', fontSize: 15, fontWeight: FontWeight.bold, color: TaqwaColors.domeBlue)),
            const SizedBox(height: 2),
           Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              _mapMiniStat('\u2705', '$completedCount \u0645\u0643\u062a\u0645\u0644\u0629'),
              _mapMiniStat('\u23F3', '$inProgressCount \u062c\u0632\u0626\u064a'),
              _mapMiniStat('\u25AB', '${114 - completedCount - inProgressCount} \u0645\u062a\u0628\u0642\u064a'),
            ],
           ),
          ])),
          Icon(Icons.chevron_left, color: Colors.grey.shade400, size: 24),
        ])),
      ),
    ));
  }

  Widget _mapMiniStat(String emoji, String label) {
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Text(emoji, style: const TextStyle(fontSize: 10)),
      const SizedBox(width: 3),
      Flexible(child: Text(label, style: TextStyle(fontFamily: 'Cairo', fontSize: 10, color: Colors.grey.shade600), maxLines: 1, overflow: TextOverflow.ellipsis)),
    ]);
  }

  void _showQuranMapSheet() {
    showModalBottomSheet(
      context: context, isScrollControlled: true, backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        height: MediaQuery.of(ctx).size.height * 0.85,
        decoration: const BoxDecoration(color: Color(0xFFF5F6FA), borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
        child: Directionality(textDirection: TextDirection.rtl, child: Column(children: [
          Container(margin: const EdgeInsets.only(top: 12), width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2))),
          Padding(padding: const EdgeInsets.all(16), child: Row(children: [
            const Icon(Icons.auto_stories, color: TaqwaColors.domeBlue, size: 22), const SizedBox(width: 8),
            const Text('\u062e\u0631\u064a\u0637\u0629 \u0627\u0644\u062d\u0641\u0638', style: TextStyle(fontFamily: 'Cairo', fontSize: 18, fontWeight: FontWeight.bold, color: TaqwaColors.domeBlue)),
            const Spacer(),
            Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3), decoration: BoxDecoration(color: TaqwaColors.islamicGreen.withOpacity(0.1), borderRadius: BorderRadius.circular(6)),
              child: Text('$_completedSuras / $totalSuras', style: const TextStyle(fontFamily: 'Cairo', fontSize: 12, fontWeight: FontWeight.bold, color: TaqwaColors.islamicGreen))),
          ])),
          // Legend
          Padding(padding: const EdgeInsets.symmetric(horizontal: 16), child: Row(children: [
            _legendDot(TaqwaColors.islamicGreen, '\u0645\u0643\u062a\u0645\u0644'), const SizedBox(width: 12),
            _legendDot(TaqwaColors.islamicGreen.withOpacity(0.3), '\u062c\u0632\u0626\u064a'), const SizedBox(width: 12),
            _legendDot(Colors.grey.shade200, '\u0644\u0645 \u064a\u0628\u062f\u0623'),
          ])),
          const SizedBox(height: 12),
          // Full 114 sura grid
          Expanded(child: SingleChildScrollView(padding: const EdgeInsets.symmetric(horizontal: 16), child: Wrap(
            spacing: 5, runSpacing: 5,
            children: List.generate(114, (index) {
              final sura = suraList[index];
              final pct = _suraProgressMap[sura.number] ?? 0;
              final isComplete = pct >= 100;
              final hasProgress = pct > 0 && pct < 100;
              Color bgColor; Color textColor;
              if (isComplete) { bgColor = TaqwaColors.islamicGreen; textColor = Colors.white; }
              else if (hasProgress) { bgColor = TaqwaColors.islamicGreen.withOpacity(0.15); textColor = TaqwaColors.islamicGreen; }
              else { bgColor = Colors.grey.shade100; textColor = Colors.grey.shade400; }
              return Container(
                width: 80, padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                decoration: BoxDecoration(color: bgColor, borderRadius: BorderRadius.circular(10),
                  border: hasProgress ? Border.all(color: TaqwaColors.islamicGreen.withOpacity(0.4)) : null),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Text(sura.nameAr, style: TextStyle(fontFamily: 'Cairo', fontSize: 11, fontWeight: FontWeight.bold, color: textColor), maxLines: 1, overflow: TextOverflow.ellipsis),
                  if (isComplete) Icon(Icons.check_circle, size: 14, color: textColor)
                  else if (hasProgress) Text('${pct.toStringAsFixed(0)}%', style: TextStyle(fontFamily: 'Cairo', fontSize: 9, color: textColor)),
                ]),
              );
            }),
          ))),
          const SizedBox(height: 16),
        ])),
      ),
    );
  }

  Widget _legendDot(Color color, String label) {
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Container(width: 12, height: 12, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(3))),
      const SizedBox(width: 4),
      Text(label, style: TextStyle(fontFamily: 'Cairo', fontSize: 10, color: Colors.grey.shade600)),
    ]);
  }
// ═══════════════════════════════════════════════════════
  // NAWAWI-40 MAP — compact card + bottom sheet (student view)
  //
  // Additive: mirrors _buildQuranMapCard's look. Cumulative across terms
  // (backed by getStudentHadithProgress). Read-only for the student.
  // ═══════════════════════════════════════════════════════

  Widget _buildHadithMapCard() {
    final count = _hadithProgress.count;
    final total = _hadithProgress.total > 0 ? _hadithProgress.total : 42;
    final remaining = total - count;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: _showHadithMapSheet,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                      colors: [TaqwaColors.islamicGreen, Color(0xFF27AE60)]),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(Icons.auto_stories_rounded,
                    color: Colors.white, size: 24),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('\u0627\u0644\u0623\u0631\u0628\u0639\u064a\u0646 \u0627\u0644\u0646\u0648\u0648\u064a\u0629',
                        style: TextStyle(
                            fontFamily: 'Cairo',
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: TaqwaColors.domeBlue)),
                    const SizedBox(height: 2),
                    Wrap(spacing: 8, runSpacing: 4, children: [
                      _mapMiniStat('\u2705', '$count \u0645\u062d\u0641\u0648\u0638'),
                      _mapMiniStat('\u25ab', '$remaining \u0645\u062a\u0628\u0642\u064a'),
                    ]),
                  ],
                ),
              ),
              Icon(Icons.chevron_left, color: Colors.grey.shade400, size: 24),
            ]),
          ),
        ),
      ),
    );
  }

  void _showHadithMapSheet() {
    final total = _hadithProgress.total > 0 ? _hadithProgress.total : 42;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        height: MediaQuery.of(ctx).size.height * 0.85,
        decoration: const BoxDecoration(
            color: Color(0xFFF5F6FA),
            borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
        child: Directionality(
          textDirection: TextDirection.rtl,
          child: Column(children: [
            Container(
                margin: const EdgeInsets.only(top: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2))),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(children: [
                const Icon(Icons.auto_stories_rounded,
                    color: TaqwaColors.domeBlue, size: 22),
                const SizedBox(width: 8),
                const Text('\u0627\u0644\u0623\u0631\u0628\u0639\u064a\u0646 \u0627\u0644\u0646\u0648\u0648\u064a\u0629',
                    style: TextStyle(
                        fontFamily: 'Cairo',
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: TaqwaColors.domeBlue)),
                const Spacer(),
                Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                        color:
                            TaqwaColors.islamicGreen.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(6)),
                    child: Text('${_hadithProgress.count} / $total',
                        style: const TextStyle(
                            fontFamily: 'Cairo',
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: TaqwaColors.islamicGreen))),
              ]),
            ),
            // Legend
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(children: [
                _legendDot(TaqwaColors.islamicGreen, '\u0645\u062d\u0641\u0648\u0638'),
                const SizedBox(width: 12),
                _legendDot(Colors.grey.shade200, '\u063a\u064a\u0631 \u0645\u062d\u0641\u0648\u0638'),
              ]),
            ),
            const SizedBox(height: 12),
            // 42-hadith grid
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Wrap(
                  spacing: 5,
                  runSpacing: 5,
                  children: List.generate(total, (index) {
                    final n = index + 1;
                    final memorized = _hadithProgress.isMemorized(n);
                    return Container(
                      width: 62,
                      padding: const EdgeInsets.symmetric(
                          vertical: 10, horizontal: 4),
                      decoration: BoxDecoration(
                        color: memorized
                            ? TaqwaColors.islamicGreen
                            : Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(10),
                        border: memorized
                            ? null
                            : Border.all(color: Colors.grey.shade200),
                      ),
                      child: Column(mainAxisSize: MainAxisSize.min, children: [
                        Text('$n',
                            style: TextStyle(
                                fontFamily: 'Cairo',
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: memorized
                                    ? Colors.white
                                    : Colors.grey.shade500)),
                        const SizedBox(height: 2),
                        Icon(
                            memorized
                                ? Icons.check_circle
                                : Icons.circle_outlined,
                            size: 13,
                            color: memorized
                                ? Colors.white
                                : Colors.grey.shade400),
                      ]),
                    );
                  }),
                ),
              ),
            ),
            const SizedBox(height: 16),
          ]),
        ),
      ),
    );
  }
  // ═══════════════════════════════════════════════════════
  // GIFTS SLIDER
  // ═══════════════════════════════════════════════════════

  Widget _buildGiftsSlider() {
    return Padding(padding: const EdgeInsets.only(top: 14), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Padding(padding: const EdgeInsets.symmetric(horizontal: 16), child: Row(children: [
        const Icon(Icons.card_giftcard, size: 18, color: TaqwaColors.domeBlue), const SizedBox(width: 6),
        const Text('\u0627\u0644\u0647\u062f\u0627\u064a\u0627', style: TextStyle(fontFamily: 'Cairo', fontSize: 16, fontWeight: FontWeight.bold, color: TaqwaColors.domeBlue)),
        const Spacer(),
        Flexible(child: Text('\u0631\u0635\u064a\u062f\u0643: ${_totalPoints.asPoints} \u0646\u0642\u0637\u0629', style: TextStyle(fontFamily: 'Cairo', fontSize: 12, color: Colors.grey.shade500), maxLines: 1, overflow: TextOverflow.ellipsis)),
      ])),
      const SizedBox(height: 10),
      SizedBox(height: 170, child: ListView.builder(
        controller: _giftsScrollController, scrollDirection: Axis.horizontal, padding: const EdgeInsets.symmetric(horizontal: 12), itemCount: _gifts.length,
        itemBuilder: (context, index) {
          final gift = _gifts[index]; final name = gift['name'] ?? ''; final cost = gift['pointsCost'] ?? 0; final imageData = gift['imageData']; final canAfford = _totalPoints >= cost;
          return Container(width: 130, margin: const EdgeInsets.symmetric(horizontal: 4),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: canAfford ? TaqwaColors.islamicGreen.withOpacity(0.3) : Colors.grey.shade200)),
            child: Column(children: [
              Expanded(child: ClipRRect(borderRadius: const BorderRadius.vertical(top: Radius.circular(13)), child: _buildGiftImage(imageData))),
              Padding(padding: const EdgeInsets.all(8), child: Column(mainAxisSize: MainAxisSize.min, children: [
                Text(name, style: const TextStyle(fontFamily: 'Cairo', fontSize: 12, fontWeight: FontWeight.bold), maxLines: 1, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 2),
                Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2), decoration: BoxDecoration(color: canAfford ? TaqwaColors.islamicGreen.withOpacity(0.1) : Colors.grey.shade100, borderRadius: BorderRadius.circular(6)),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.star, size: 12, color: canAfford ? TaqwaColors.islamicGreen : Colors.grey), const SizedBox(width: 2),
                    Text('$cost', style: TextStyle(fontFamily: 'Cairo', fontSize: 11, fontWeight: FontWeight.bold, color: canAfford ? TaqwaColors.islamicGreen : Colors.grey)),
                  ])),
              ])),
            ]));
        },
      )),
    ]));
  }

  Widget _buildGiftImage(dynamic imageData) {
    if (imageData == null || imageData.toString().isEmpty) return Container(color: Colors.grey.shade100, child: const Center(child: Icon(Icons.card_giftcard, size: 32, color: Colors.grey)));
    try {
      return Image.memory(base64Decode(imageData.toString().replaceFirst(RegExp(r'data:image/[^;]+;base64,'), '')), fit: BoxFit.cover, width: double.infinity,
          errorBuilder: (_, __, ___) => Container(color: Colors.grey.shade100, child: const Center(child: Icon(Icons.card_giftcard, size: 32, color: Colors.grey))));
    } catch (_) { return Container(color: Colors.grey.shade100, child: const Center(child: Icon(Icons.card_giftcard, size: 32, color: Colors.grey))); }
  }

  // ═══════════════════════════════════════════════════════
  // LEADERBOARD PREVIEW
  // ═══════════════════════════════════════════════════════

  Widget _buildLeaderboardPreview() {
    if (_leaderboard.isEmpty) return const SizedBox.shrink();
    final top5 = _leaderboard.take(5).toList();
    return Padding(padding: const EdgeInsets.fromLTRB(16, 14, 16, 0), child: Column(children: [
      Row(children: [
        const Icon(Icons.emoji_events, size: 18, color: TaqwaColors.minaretGold), const SizedBox(width: 6),
        const Text('\u062a\u0631\u062a\u064a\u0628 \u0627\u0644\u0637\u0644\u0627\u0628', style: TextStyle(fontFamily: 'Cairo', fontSize: 16, fontWeight: FontWeight.bold, color: TaqwaColors.domeBlue)),
        const Spacer(),
        TextButton(onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => LeaderboardScreen(leaderboard: _leaderboard, currentStudentId: _studentId))),
            child: const Text('\u0639\u0631\u0636 \u0627\u0644\u0643\u0644', style: TextStyle(fontFamily: 'Cairo', fontSize: 12))),
      ]),
      const SizedBox(height: 6),
      Container(decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
        child: Column(children: List.generate(top5.length, (i) {
          final s = top5[i]; final name = s['fullName'] ?? s['name'] ?? '\u0637\u0627\u0644\u0628'; final points = _toNum(s['totalPoints']);
          final isMe = s['id'] == _studentId || s['studentId'] == _studentId;
          return Container(padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(color: isMe ? TaqwaColors.domeBlue.withOpacity(0.06) : null,
                border: i < top5.length - 1 ? Border(bottom: BorderSide(color: Colors.grey.shade100)) : null),
            child: Row(children: [
              Container(width: 28, height: 28, decoration: BoxDecoration(color: i < 3 ? TaqwaColors.minaretGold.withOpacity(0.12) : Colors.grey.shade100, borderRadius: BorderRadius.circular(8)),
                child: Center(child: Text('${i + 1}', style: TextStyle(fontFamily: 'Cairo', fontSize: 12, fontWeight: FontWeight.bold, color: i < 3 ? TaqwaColors.minaretGold : Colors.grey.shade600)))),
              const SizedBox(width: 10),
              Expanded(child: Text(isMe ? '$name (\u0623\u0646\u062a)' : name, style: TextStyle(fontFamily: 'Cairo', fontSize: 13, fontWeight: isMe ? FontWeight.bold : FontWeight.w500, color: isMe ? TaqwaColors.domeBlue : Colors.black87), maxLines: 1, overflow: TextOverflow.ellipsis)),
              Row(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.star, size: 14, color: TaqwaColors.minaretGold),
                const SizedBox(width: 2),
                PointsDisplay(
                  value: points,
                  size: PointsDisplaySize.small,
                  color: TaqwaColors.minaretGold,
                ),
              ]),
            ]));
        }))),
    ]));
  }

  // ═══════════════════════════════════════════════════════
  // RECITATION (Last 3 + dates + Detail Sheet)
  // ═══════════════════════════════════════════════════════

  Widget _buildRecitationSection() {
    final latest = _recitationHistory.take(3).toList();
    return Padding(padding: const EdgeInsets.fromLTRB(16, 14, 16, 0), child: Column(children: [
      Row(children: [
        const Icon(Icons.history, size: 18, color: TaqwaColors.domeBlue), const SizedBox(width: 6),
        const Text('\u0622\u062e\u0631 \u0627\u0644\u062a\u0633\u0645\u064a\u0639', style: TextStyle(fontFamily: 'Cairo', fontSize: 16, fontWeight: FontWeight.bold, color: TaqwaColors.domeBlue)),
        const Spacer(),
        if (_recitationHistory.length > 3) TextButton(onPressed: _showRecitationSheet, child: const Text('\u0639\u0631\u0636 \u0627\u0644\u0643\u0644', style: TextStyle(fontFamily: 'Cairo', fontSize: 12))),
      ]),
      const SizedBox(height: 8),
      ...latest.map((rec) => _recitationRow(rec, showFullDate: false)),
    ]));
  }

  Widget _recitationRow(Map<String, dynamic> rec, {bool showFullDate = true}) {
    final suraName = rec['suraName'] ?? getSuraName(rec['surahNumber'] ?? 1);
    final rating = rec['rating'] ?? '';
    final pages = (rec['pagesRecited'] ?? 0).toDouble();
    final dateStr = rec['date'] ?? rec['createdAt'] ?? '';
    final dateLabel = showFullDate ? _formatDateFull(dateStr) : _formatDate(dateStr);

    Color rc; String rl;
    switch (rating) {
      case 'VERY_GOOD': rc = const Color(0xFF1E8449); rl = '\u062c\u064a\u062f \u062c\u062f\u0627\u064b'; break;
      case 'GOOD': rc = const Color(0xFF2E86C1); rl = '\u062c\u064a\u062f'; break;
      case 'REPEAT': rc = const Color(0xFFD4AC0D); rl = '\u0625\u0639\u0627\u062f\u0629'; break;
      case 'DID_NOT_MEMORIZE': rc = const Color(0xFFE74C3C); rl = '\u0644\u0645 \u064a\u062d\u0641\u0638'; break;
      case 'MAQRAA': rc = const Color(0xFFD4AC0D); rl = '\u0645\u0642\u0631\u0623\u0629'; break;
      default: rc = Colors.grey; rl = rating;
    }
    return Container(margin: const EdgeInsets.only(bottom: 6), padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          if (rating != 'DID_NOT_MEMORIZE') Flexible(child: Text(suraName, style: const TextStyle(fontFamily: 'Cairo', fontSize: 13, fontWeight: FontWeight.bold, color: TaqwaColors.domeBlue), maxLines: 1, overflow: TextOverflow.ellipsis)),
          if (pages > 0 && rating != 'DID_NOT_MEMORIZE') ...[const SizedBox(width: 6), Text('($pages \u0635)', style: TextStyle(fontFamily: 'Cairo', fontSize: 11, color: Colors.grey.shade500))],
          const Spacer(),
          Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3), decoration: BoxDecoration(color: rc.withOpacity(0.1), borderRadius: BorderRadius.circular(6)),
            child: Text(rl, style: TextStyle(fontFamily: 'Cairo', fontSize: 11, fontWeight: FontWeight.bold, color: rc))),
        ]),
        if (dateLabel.isNotEmpty) ...[
          const SizedBox(height: 4),
          Row(children: [
            Icon(Icons.schedule, size: 12, color: Colors.grey.shade400), const SizedBox(width: 4),
            Text(dateLabel, style: TextStyle(fontFamily: 'Cairo', fontSize: 10, color: Colors.grey.shade400)),
          ]),
        ],
      ]),
    );
  }

  void _showRecitationSheet() {
    showModalBottomSheet(context: context, isScrollControlled: true, backgroundColor: Colors.transparent,
      builder: (ctx) => Container(height: MediaQuery.of(ctx).size.height * 0.75,
        decoration: const BoxDecoration(color: Color(0xFFF5F6FA), borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
        child: Directionality(textDirection: TextDirection.rtl, child: Column(children: [
          Container(margin: const EdgeInsets.only(top: 12), width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2))),
          Padding(padding: const EdgeInsets.all(16), child: Row(children: [
            const Icon(Icons.history, color: TaqwaColors.domeBlue, size: 22), const SizedBox(width: 8),
            const Text('\u0633\u062c\u0644 \u0627\u0644\u062a\u0633\u0645\u064a\u0639', style: TextStyle(fontFamily: 'Cairo', fontSize: 18, fontWeight: FontWeight.bold, color: TaqwaColors.domeBlue)),
            const Spacer(), Text('${_recitationHistory.length}', style: TextStyle(fontFamily: 'Cairo', fontSize: 14, color: Colors.grey.shade500)),
          ])),
          Expanded(child: _buildRecitationSheetList()),
        ]))));
  }

  /// A band per course (current first), then that course's recitations.
  Widget _buildRecitationSheetList() {
    final rows = <Object?>[]; // CourseSection · recitation Map · null = empty course
    for (final section in _recitationSections) {
      if (section.recitations.isEmpty && !section.isCurrent) continue;
      rows.add(section);
      if (section.recitations.isEmpty) {
        rows.add(null);
      } else {
        rows.addAll(section.recitations);
      }
    }
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      itemCount: rows.length,
      itemBuilder: (_, i) {
        final row = rows[i];
        if (row is CourseSection) {
          return CourseSectionHeader(section: row, isFirst: i == 0, count: row.recitations.length);
        }
        if (row == null) return const EmptyCourseNote();
        return _recitationRow(row as Map<String, dynamic>, showFullDate: true);
      },
    );
  }

  // ═══════════════════════════════════════════════════════
  // POINTS LOG (Last 3 + dates + Detail Sheet)
  // ═══════════════════════════════════════════════════════

  Widget _buildPointsSection() {
    final latest = _pointsLog.take(3).toList();
    return Padding(padding: const EdgeInsets.fromLTRB(16, 14, 16, 0), child: Column(children: [
      Row(children: [
        const Icon(Icons.star, size: 18, color: TaqwaColors.minaretGold), const SizedBox(width: 6),
        const Text('\u0622\u062e\u0631 \u0627\u0644\u0646\u0642\u0627\u0637', style: TextStyle(fontFamily: 'Cairo', fontSize: 16, fontWeight: FontWeight.bold, color: TaqwaColors.domeBlue)),
        const Spacer(),
        if (_pointsLog.length > 3) TextButton(onPressed: _showPointsSheet, child: const Text('\u0639\u0631\u0636 \u0627\u0644\u0643\u0644', style: TextStyle(fontFamily: 'Cairo', fontSize: 12))),
      ]),
      const SizedBox(height: 8),
      ...latest.map((log) => _pointsRow(log, showFullDate: false)),
    ]));
  }

  Widget _pointsRow(Map<String, dynamic> log, {bool showFullDate = true}) {
    final amount = _toNum(log['amount']);
    final isPos = amount > 0;
    final desc = log['description'] ?? log['categoryName'] ?? '';
    final dateStr = log['createdAt'] ?? '';
    final dateLabel = showFullDate ? _formatDateFull(dateStr) : _formatDate(dateStr);

    // Formatted amount with sign; always 2 decimals + tabular figures.
    final amountText = '${isPos ? '+' : ''}${amount.asPoints}';

    return Container(margin: const EdgeInsets.only(bottom: 6), padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
      child: Row(children: [
        Container(
          width: 44, height: 36,
          decoration: BoxDecoration(
            color: (isPos ? Colors.green : Colors.red).withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Center(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                child: Text(
                  amountText,
                  textDirection: TextDirection.ltr,
                  style: TextStyle(
                    fontFamily: 'Cairo',
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    fontFeatures: const [FontFeature.tabularFigures()],
                    color: isPos ? Colors.green : Colors.red,
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(desc, style: const TextStyle(fontFamily: 'Cairo', fontSize: 13, fontWeight: FontWeight.w500), maxLines: 2, overflow: TextOverflow.ellipsis),
          if (dateLabel.isNotEmpty) ...[
            const SizedBox(height: 2),
            Row(children: [
              Icon(Icons.schedule, size: 11, color: Colors.grey.shade400), const SizedBox(width: 3),
              Text(dateLabel, style: TextStyle(fontFamily: 'Cairo', fontSize: 10, color: Colors.grey.shade400)),
            ]),
          ],
        ])),
      ]));
  }

  void _showPointsSheet() {
    showModalBottomSheet(context: context, isScrollControlled: true, backgroundColor: Colors.transparent,
      builder: (ctx) => Container(height: MediaQuery.of(ctx).size.height * 0.75,
        decoration: const BoxDecoration(color: Color(0xFFF5F6FA), borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
        child: Directionality(textDirection: TextDirection.rtl, child: Column(children: [
          Container(margin: const EdgeInsets.only(top: 12), width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2))),
          Padding(padding: const EdgeInsets.all(16), child: Row(children: [
            const Icon(Icons.star, color: TaqwaColors.minaretGold, size: 22), const SizedBox(width: 8),
            const Text('\u0633\u062c\u0644 \u0627\u0644\u0646\u0642\u0627\u0637', style: TextStyle(fontFamily: 'Cairo', fontSize: 18, fontWeight: FontWeight.bold, color: TaqwaColors.domeBlue)),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: TaqwaColors.minaretGold.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                textDirection: TextDirection.rtl,
                children: [
                  PointsDisplay(
                    value: _totalPoints,
                    size: PointsDisplaySize.small,
                    color: TaqwaColors.minaretGold,
                  ),
                  const SizedBox(width: 4),
                  const Text(
                    '\u0646\u0642\u0637\u0629',
                    style: TextStyle(
                      fontFamily: 'Cairo',
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: TaqwaColors.minaretGold,
                    ),
                  ),
                ],
              ),
            ),
          ])),
          Expanded(child: ListView.builder(padding: const EdgeInsets.symmetric(horizontal: 16), itemCount: _pointsLog.length,
              itemBuilder: (_, i) => _pointsRow(_pointsLog[i], showFullDate: true))),
        ]))));
  }
}