import 'package:flutter/material.dart';
import '../../../../core/theme/taqwa_colors.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/constants/quran_metadata.dart';
import '../../../../core/widgets/points_display.dart';
import '../../../../core/extensions/points_formatting.dart';
import '../../../points/data/points_api.dart';
import '../../../recitation/data/recitation_api.dart';
import 'add_recitation_screen.dart';
import '../../../points/presentation/widgets/award_points_modal.dart';

class InstructorStudentDetailScreen extends StatefulWidget {
  final String studentId;
  final String studentName;

  const InstructorStudentDetailScreen({
    super.key,
    required this.studentId,
    required this.studentName,
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
  List<Map<String, dynamic>> _recitationHistory = [];
  Map<String, dynamic>? _lastRecitation; // D2
  Map<String, dynamic> _progress = {};
  Map<String, dynamic> _homework = {};
  double _totalPoints = 0;
  int _studentRank = 0;
  int _totalStudentsCount = 0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

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
    final res = await ApiClient.instance.get('/students/${widget.studentId}');
    _studentInfo = res.data['data'] ?? res.data;
  }

  Future<void> _loadPoints() async {
    try {
      final res = await _pointsApi.getStudentPoints(widget.studentId);
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

  // D2 — single round-trip envelope: history list + last-session detail
  Future<void> _loadRecitationHistory() async {
    final envelope =
        await _recitationApi.getStudentHistoryWithSession(widget.studentId);
    _recitationHistory = envelope.history;
    _lastRecitation = envelope.lastRecitation;
  }

  Future<void> _loadProgress() async {
    _progress = await _recitationApi.getStudentProgress(widget.studentId);
  }

  Future<void> _loadHomework() async {
    _homework = await _recitationApi.getStudentHomework(widget.studentId);
  }

  Future<void> _loadRank() async {
    try {
      final leaderboard = await _pointsApi.getLeaderboard(limit: 100);
      for (int i = 0; i < leaderboard.length; i++) {
        if (leaderboard[i]['id'] == widget.studentId ||
            leaderboard[i]['studentId'] == widget.studentId) {
          _studentRank = i + 1;
          break;
        }
      }
      _totalStudentsCount = leaderboard.length;
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
                              Tab(text: 'التسميع'),
                              Tab(text: 'النقاط'),
                              Tab(text: 'الحفظ'),
                            ],
                          ),
                        ),
                      ),
                    ],
                    body: TabBarView(
                      controller: _tabController,
                      children: [
                        _buildInfoTab(),
                        _buildRecitationTab(),
                        _buildPointsTab(),
                        _buildProgressTab(),
                      ],
                    ),
                  ),
        floatingActionButton: AnimatedBuilder(
          animation: _tabController,
          builder: (context, _) {
            final isPointsTab = _tabController.index == 2;

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

  Widget _buildRecitationTab() {
    if (_recitationHistory.isEmpty && _lastRecitation == null) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.menu_book, size: 48, color: Colors.grey),
            SizedBox(height: 8),
            Text('لا يوجد تسميع بعد',
                style: TextStyle(fontFamily: 'Cairo', color: Colors.grey)),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      // +1 leading slot for the "آخر تسميع" panel.
      itemCount: _recitationHistory.length + 1,
      itemBuilder: (context, index) {
        if (index == 0) {
          return _buildLastRecitationCard();
        }
        final rec = _recitationHistory[index - 1];
        final suraName =
            rec['suraName'] ?? getSuraName(rec['surahNumber'] ?? 1);
        final rating = rec['rating'] ?? '';
        final pagesCalculatedRaw = rec['pagesCalculated'];
        final pages = pagesCalculatedRaw != null
            ? double.tryParse(pagesCalculatedRaw.toString()) ?? 0
            : (rec['pagesRecited'] ?? 0).toDouble();
        final date = rec['date'] ?? rec['createdAt'] ?? '';
        final homework = rec['homework'];
        final isComplete = rec['isCompleteSura'] == true;
        final meta = _ratingMeta(rating);

        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14)),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    if (rating != 'DID_NOT_MEMORIZE')
                      Flexible(
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: TaqwaColors.domeBlue
                                .withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            suraName,
                            style: const TextStyle(
                              fontFamily: 'Cairo',
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: TaqwaColors.domeBlue,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                    if (rating != 'DID_NOT_MEMORIZE')
                      const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: meta.color.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(meta.icon, size: 14, color: meta.color),
                          const SizedBox(width: 4),
                          Text(
                            meta.label,
                            style: TextStyle(
                              fontFamily: 'Cairo',
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: meta.color,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 12,
                  runSpacing: 4,
                  children: [
                    if (pages > 0 && rating != 'DID_NOT_MEMORIZE')
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.description,
                              size: 14, color: Colors.grey.shade400),
                          const SizedBox(width: 4),
                          Text(
                            isComplete
                                ? 'كاملة (${_formatPagesDecimal(pages)} ص)'
                                : '${_formatPagesDecimal(pages)} صفحة',
                            style: TextStyle(
                              fontFamily: 'Cairo',
                              fontSize: 11,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.calendar_today,
                            size: 14, color: Colors.grey.shade400),
                        const SizedBox(width: 4),
                        Text(
                          _formatDate(date),
                          style: TextStyle(
                            fontFamily: 'Cairo',
                            fontSize: 11,
                            color: Colors.grey.shade500,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                if (homework != null && homework.toString().isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: TaqwaColors.minaretGold.withValues(alpha: 0.06),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.assignment,
                            size: 14, color: TaqwaColors.minaretGold),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            homework.toString(),
                            style: TextStyle(
                              fontFamily: 'Cairo',
                              fontSize: 12,
                              color: Colors.amber.shade900,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
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