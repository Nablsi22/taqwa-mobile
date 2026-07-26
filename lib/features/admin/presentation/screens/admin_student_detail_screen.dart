import 'package:flutter/material.dart';
import '../../../../core/theme/taqwa_colors.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/extensions/points_formatting.dart';

class AdminStudentDetailScreen extends StatefulWidget {
  final String studentId;
  final String studentName;

  const AdminStudentDetailScreen({
    super.key,
    required this.studentId,
    required this.studentName,
  });

  @override
  State<AdminStudentDetailScreen> createState() =>
      _AdminStudentDetailScreenState();
}

class _AdminStudentDetailScreenState extends State<AdminStudentDetailScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  Map<String, dynamic> _studentInfo = {};
  Map<String, dynamic> _stats = {};
  List<Map<String, dynamic>> _pointsLog = [];
  List<Map<String, dynamic>> _recitations = [];
  List<Map<String, dynamic>> _attendance = [];
  Map<String, dynamic> _attendanceSummary = {};

  /// Points are stored as `Decimal(7,3)` on the backend and may arrive as
  /// int, double, or String. Held as `num` so this layer never performs an
  /// implicit narrowing downcast on a value it does not control. Declaring
  /// this as `int` was the root cause of the blank points tab: assigning a
  /// fractional JSON number to it threw a runtime type error.
  num _totalPoints = 0;

  int _memorizedPages = 0;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadAllData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  // ═══════════════════════════════════════════════════════════════
  // DATA LOADING
  // ═══════════════════════════════════════════════════════════════
  Future<void> _loadAllData() async {
    setState(() => _isLoading = true);
    await Future.wait([
      _loadStudentInfo(),
      _loadStats(),
      _loadPointsLog(),
      _loadRecitations(),
      _loadAttendance(),
      _loadProgress(),
    ]);
    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _loadStudentInfo() async {
    try {
      final res =
          await ApiClient.instance.get('/students/${widget.studentId}');
      _studentInfo =
          Map<String, dynamic>.from(res.data is Map ? res.data : {});
    } catch (e) {
      debugPrint('StudentInfo error: $e');
    }
  }

  Future<void> _loadStats() async {
    try {
      final res = await ApiClient.instance
          .get('/students/${widget.studentId}/stats');
      _stats = Map<String, dynamic>.from(res.data is Map ? res.data : {});
    } catch (e) {
      debugPrint('Stats error: $e');
    }
  }

  /// Safely coerces any JSON-parsed numeric value (int, double, String)
  /// into a [num]. Mirrors the helpers already present in `StudentModel`
  /// and the student dashboard: every numeric value read from an API
  /// response passes through here, never straight into a typed field.
  num _toNum(dynamic v) {
    if (v == null) return 0;
    if (v is num) return v;
    return num.tryParse(v.toString()) ?? 0;
  }

  Future<void> _loadPointsLog() async {
    try {
      final res = await ApiClient.instance
          .get('/points/student/${widget.studentId}?limit=500');
      final data = res.data;
      if (data is! Map) return;

      // ORDER IS LOAD-BEARING. The log list is assigned before the header
      // total. The previous version read the total first, and a runtime
      // type error on that single scalar aborted the method before the
      // list was ever assigned, blanking the entire tab. Display state
      // must degrade field by field, never all at once.
      final rawList = data['data'];
      if (rawList is List) {
        _pointsLog = rawList
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
      }

      _totalPoints = _toNum(data['totalPoints']);
    } catch (e, stackTrace) {
      debugPrint('Points error: $e\n$stackTrace');
    }
  }

  Future<void> _loadRecitations() async {
    try {
      final res = await ApiClient.instance
          .get('/recitations/student/${widget.studentId}/history');
      final data = res.data;
      if (data is Map) {
        final list = data['data'] as List? ?? [];
        _recitations = list.map((e) => Map<String, dynamic>.from(e)).toList();
      } else if (data is List) {
        _recitations = data.map((e) => Map<String, dynamic>.from(e)).toList();
      }
    } catch (e) {
      debugPrint('Recitations error: $e');
    }
  }

  Future<void> _loadAttendance() async {
    try {
      final res = await ApiClient.instance
          .get('/attendance/student/${widget.studentId}');
      final data = res.data;
      if (data is Map) {
        _attendance = (data['data'] as List? ?? [])
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
        _attendanceSummary =
            Map<String, dynamic>.from(data['summary'] ?? {});
      }
    } catch (e) {
      debugPrint('Attendance error: $e');
    }
  }

  Future<void> _loadProgress() async {
    try {
      final res = await ApiClient.instance
          .get('/recitations/student/${widget.studentId}/progress');
      final data = res.data;
      if (data is Map) {
        final raw = data['totalPagesMemorized'];
        if (raw is num) _memorizedPages = raw.round();
      }
    } catch (e) {
      debugPrint('Progress error: $e');
    }
  }

  // ═══════════════════════════════════════════════════════════════
  // DELETE ACTIONS
  // ═══════════════════════════════════════════════════════════════
  Future<void> _deletePointLog(String logId, int index) async {
    final confirmed = await _showDeleteConfirmation(
      'حذف سجل النقاط',
      'هل أنت متأكد من حذف هذا السجل؟ سيتم تعديل رصيد النقاط.',
    );
    if (!confirmed) return;

    try {
      await ApiClient.instance.delete('/points/log/$logId');
      setState(() => _pointsLog.removeAt(index));
      await _loadPointsLog();
      await _loadStats();
      if (mounted) setState(() {});
      _showSuccessMessage('تم حذف سجل النقاط بنجاح');
    } catch (_) {
      _showErrorMessage('فشل حذف سجل النقاط');
    }
  }

  Future<void> _deleteRecitation(String recitationId, int index) async {
    final confirmed = await _showDeleteConfirmation(
      'حذف سجل التسميع',
      'هل أنت متأكد من حذف هذا التسميع؟ لن يتم التراجع عن هذا الإجراء.',
    );
    if (!confirmed) return;

    try {
      await ApiClient.instance.delete('/recitations/$recitationId');
      setState(() => _recitations.removeAt(index));
      await _loadStats();
      if (mounted) setState(() {});
      _showSuccessMessage('تم حذف سجل التسميع بنجاح');
    } catch (_) {
      _showErrorMessage('فشل حذف سجل التسميع');
    }
  }

  Future<bool> _showDeleteConfirmation(String title, String message) async {
    return await showDialog<bool>(
          context: context,
          builder: (ctx) => Directionality(
            textDirection: TextDirection.rtl,
            child: AlertDialog(
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
              title: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(Icons.delete_outline,
                        color: Colors.red.shade600),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(title,
                        style: const TextStyle(
                            fontFamily: 'Cairo',
                            fontSize: 16,
                            fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
              content: Text(message,
                  style: TextStyle(
                      fontFamily: 'Cairo',
                      fontSize: 14,
                      color: Colors.grey.shade700,
                      height: 1.5)),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text('إلغاء',
                      style:
                          TextStyle(fontFamily: 'Cairo', color: Colors.grey)),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                  child: const Text('حذف',
                      style:
                          TextStyle(fontFamily: 'Cairo', color: Colors.white)),
                ),
              ],
            ),
          ),
        ) ??
        false;
  }

  void _showSuccessMessage(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Row(
        children: [
          const Icon(Icons.check_circle, color: Colors.white, size: 20),
          const SizedBox(width: 8),
          Text(msg,
              textDirection: TextDirection.rtl,
              style: const TextStyle(fontFamily: 'Cairo')),
        ],
      ),
      backgroundColor: TaqwaColors.islamicGreen,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ));
  }

  void _showErrorMessage(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Row(
        children: [
          const Icon(Icons.error_outline, color: Colors.white, size: 20),
          const SizedBox(width: 8),
          Text(msg,
              textDirection: TextDirection.rtl,
              style: const TextStyle(fontFamily: 'Cairo')),
        ],
      ),
      backgroundColor: Colors.red.shade700,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ));
  }

  // ═══════════════════════════════════════════════════════════════
  // CALCULATED STATS
  // ═══════════════════════════════════════════════════════════════
  int _calcAttendanceRate() {
    final present = _attendanceSummary['present'] ?? 0;
    final late_ = _attendanceSummary['late'] ?? 0;
    final absent = _attendanceSummary['absent'] ?? 0;
    final total = present + late_ + absent;
    if (total == 0) return 0;
    return ((present + late_) / total * 100).round();
  }

  int _calcMemorizedPages() {
    if (_memorizedPages > 0) return _memorizedPages;
    final fromStats = _stats['totalPagesMemorized'];
    if (fromStats is num && fromStats != 0) return fromStats.round();
    return 0;
  }

  String _getGrade() => _studentInfo['grade']?.toString() ?? '';

  String _getInstructorName() {
    final inst = _studentInfo['instructor'];
    if (inst is Map) return inst['fullName']?.toString() ?? '';
    return '';
  }

  // ═══════════════════════════════════════════════════════════════
  // SOURCE TYPE → COLOR / LABEL HELPERS
  // ═══════════════════════════════════════════════════════════════
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

  // ═══════════════════════════════════════════════════════════════
  // BUILD
  // ═══════════════════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFFF5F6FA),
        body: _isLoading
            ? _buildLoadingState()
            : RefreshIndicator(
                color: TaqwaColors.domeBlue,
                onRefresh: _loadAllData,
                child: NestedScrollView(
                  headerSliverBuilder: (context, innerBoxIsScrolled) => [
                    SliverAppBar(
                      expandedHeight: 360,
                      pinned: true,
                      backgroundColor: TaqwaColors.domeBlue,
                      iconTheme: const IconThemeData(color: Colors.white),
                      title: innerBoxIsScrolled
                          ? Text(widget.studentName,
                              style: const TextStyle(
                                  fontFamily: 'Cairo', color: Colors.white))
                          : null,
                      flexibleSpace: FlexibleSpaceBar(
                        background: _buildHeaderContent(),
                      ),
                      bottom: PreferredSize(
                        preferredSize: const Size.fromHeight(52),
                        child: Container(
                          color: TaqwaColors.domeBlue,
                          child: TabBar(
                            controller: _tabController,
                            indicatorColor: TaqwaColors.minaretGold,
                            indicatorWeight: 3,
                            indicatorSize: TabBarIndicatorSize.tab,
                            labelStyle: const TextStyle(
                                fontFamily: 'Cairo',
                                fontWeight: FontWeight.bold,
                                fontSize: 13),
                            unselectedLabelStyle: const TextStyle(
                                fontFamily: 'Cairo', fontSize: 12),
                            labelColor: Colors.white,
                            unselectedLabelColor: Colors.white54,
                            tabs: [
                              Tab(
                                icon: const Icon(Icons.star_rounded, size: 18),
                                text: 'النقاط (${_pointsLog.length})',
                              ),
                              Tab(
                                icon: const Icon(Icons.menu_book_rounded,
                                    size: 18),
                                text: 'التسميع (${_recitations.length})',
                              ),
                              Tab(
                                icon: const Icon(
                                    Icons.calendar_today_rounded,
                                    size: 18),
                                text: 'الحضور (${_attendance.length})',
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                  body: TabBarView(
                    controller: _tabController,
                    children: [
                      _buildPointsTab(),
                      _buildRecitationsTab(),
                      _buildAttendanceTab(),
                    ],
                  ),
                ),
              ),
      ),
    );
  }

  Widget _buildLoadingState() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [TaqwaColors.domeBlue, Color(0xFF154360)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(color: TaqwaColors.minaretGold),
            SizedBox(height: 16),
            Text('جارِ تحميل بيانات الطالب...',
                style: TextStyle(
                    fontFamily: 'Cairo',
                    color: Colors.white70,
                    fontSize: 14)),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // HEADER
  // ═══════════════════════════════════════════════════════════════
  Widget _buildHeaderContent() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [TaqwaColors.domeBlue, Color(0xFF154360)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 56, 20, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                          color: TaqwaColors.minaretGold
                              .withValues(alpha: 0.5),
                          width: 2),
                    ),
                    child: const Icon(Icons.person_rounded,
                        color: Colors.white, size: 30),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.studentName,
                          style: const TextStyle(
                            fontFamily: 'Cairo',
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Wrap(
                          spacing: 6,
                          runSpacing: 4,
                          children: [
                            if (_getGrade().isNotEmpty)
                              _buildInfoChip(
                                  Icons.school_rounded, _getGrade()),
                            if (_getInstructorName().isNotEmpty)
                              _buildInfoChip(Icons.person_outline_rounded,
                                  _getInstructorName()),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  // `.asPoints` formats to 2 decimal places. Required now
                  // that `_totalPoints` is a `num`: raw interpolation of a
                  // Decimal(7,3) value would render as e.g. "196.561".
                  _buildHeaderStat('النقاط', _totalPoints.asPoints,
                      Icons.star_rounded, TaqwaColors.minaretGold),
                  const SizedBox(width: 6),
                  _buildHeaderStat(
                      'الحضور',
                      '${_calcAttendanceRate()}%',
                      Icons.check_circle_rounded,
                      const Color(0xFF27AE60)),
                  const SizedBox(width: 6),
                  _buildHeaderStat(
                      'التسميعات',
                      '${_recitations.length}',
                      Icons.menu_book_rounded,
                      TaqwaColors.skyBlue),
                  const SizedBox(width: 6),
                  _buildHeaderStat(
                      'الحفظ',
                      '${_calcMemorizedPages()} ص',
                      Icons.auto_stories_rounded,
                      const Color(0xFF8E44AD)),
                ],
              ),
              const SizedBox(height: 14),
              Wrap(
                alignment: WrapAlignment.center,
                spacing: 8,
                runSpacing: 6,
                children: [
                  _buildAttBadge(
                      'حاضر',
                      '${_attendanceSummary['present'] ?? 0}',
                      const Color(0xFF27AE60)),
                  _buildAttBadge('متأخر',
                      '${_attendanceSummary['late'] ?? 0}', Colors.orange),
                  _buildAttBadge('غائب',
                      '${_attendanceSummary['absent'] ?? 0}', Colors.red),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoChip(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white70, size: 13),
          const SizedBox(width: 4),
          Text(text,
              style: const TextStyle(
                  fontFamily: 'Cairo', fontSize: 11, color: Colors.white70),
              overflow: TextOverflow.ellipsis),
        ],
      ),
    );
  }

  Widget _buildHeaderStat(
      String label, String value, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(height: 4),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                value,
                maxLines: 1,
                style: const TextStyle(
                  fontFamily: 'Cairo',
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
            const SizedBox(height: 2),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                label,
                maxLines: 1,
                style: TextStyle(
                  fontFamily: 'Cairo',
                  fontSize: 10,
                  color: Colors.white.withValues(alpha: 0.7),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAttBadge(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('$label: ',
              style: TextStyle(
                  fontFamily: 'Cairo',
                  fontSize: 11,
                  color: Colors.white.withValues(alpha: 0.85))),
          Text(value,
              style: const TextStyle(
                  fontFamily: 'Cairo',
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: Colors.white)),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // POINTS TAB
  // ═══════════════════════════════════════════════════════════════
  Widget _buildPointsTab() {
    if (_pointsLog.isEmpty) {
      return _buildEmptyState(
        Icons.star_outline_rounded,
        'لا يوجد سجل نقاط',
        'لم يتم تسجيل أي نقاط لهذا الطالب بعد',
      );
    }

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
          alignment: Alignment.centerRight,
          child: Row(
            children: [
              Icon(Icons.swipe_rounded, size: 14, color: Colors.grey.shade400),
              const SizedBox(width: 4),
              Text('اسحب لليسار للحذف',
                  style: TextStyle(
                      fontFamily: 'Cairo',
                      fontSize: 11,
                      color: Colors.grey.shade400)),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
            itemCount: _pointsLog.length,
            itemBuilder: (context, index) {
              final entry = _pointsLog[index];
              final entryId = entry['id']?.toString() ?? '';

              // Coerced defensively: `amount` is a Decimal(7,3) column and
              // the comparison below must never run against a String.
              final amount = _toNum(entry['amount']);
              final isPositive = amount > 0;

              // ─── New backend fields ───
              final sourceType =
                  (entry['sourceType'] as String?) ?? 'MANUAL';
              final displayLabel =
                  (entry['displayLabel'] as String?) ?? 'نقاط خاصة';
              final description =
                  (entry['description'] as String?)?.trim() ?? '';
              final categoryNameAr =
                  (entry['categoryName'] as String?)?.trim() ?? '';

              // Title = description if present (always true for new logs);
              // legacy fallback to categoryNameAr only for very old rows
              // that somehow have an empty description.
              final title = description.isNotEmpty
                  ? description
                  : (categoryNameAr.isNotEmpty ? categoryNameAr : 'نقاط');

              final sourceColor = _sourceColor(sourceType);
              final sourceIcon = _sourceIcon(sourceType);
              final date = _formatDate(entry['createdAt'] ?? '');

              return Dismissible(
                key: Key('point_$entryId'),
                direction: DismissDirection.endToStart,
                confirmDismiss: (_) async {
                  if (entryId.isEmpty) return false;
                  await _deletePointLog(entryId, index);
                  return false;
                },
                background: Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  decoration: BoxDecoration(
                    color: Colors.red.shade600,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  alignment: Alignment.centerLeft,
                  padding: const EdgeInsets.only(left: 24),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.delete_outline, color: Colors.white),
                      SizedBox(width: 8),
                      Text('حذف',
                          style: TextStyle(
                              fontFamily: 'Cairo',
                              color: Colors.white,
                              fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
                child: Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [
                      BoxShadow(
                          color: Colors.black.withValues(alpha: 0.04),
                          blurRadius: 8,
                          offset: const Offset(0, 2)),
                    ],
                  ),
                  child: IntrinsicHeight(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Container(
                          width: 5,
                          decoration: BoxDecoration(
                            color: isPositive
                                ? TaqwaColors.islamicGreen
                                : Colors.red,
                            borderRadius: const BorderRadius.only(
                              topRight: Radius.circular(14),
                              bottomRight: Radius.circular(14),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          child: Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              color: (isPositive
                                      ? TaqwaColors.islamicGreen
                                      : Colors.red)
                                  .withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Center(
                              child: FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Padding(
                                  padding: const EdgeInsets.all(4),
                                  child: Text(
                                    '${isPositive ? '+' : ''}${amount.asPoints}',
                                    style: TextStyle(
                                      fontFamily: 'Cairo',
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: isPositive
                                          ? TaqwaColors.islamicGreen
                                          : Colors.red,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                _buildSourcePill(
                                    displayLabel, sourceColor, sourceIcon),
                                const SizedBox(height: 6),
                                Text(
                                  title,
                                  style: const TextStyle(
                                    fontFamily: 'Cairo',
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF2C3E50),
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                        ),
                        Padding(
                          padding:
                              const EdgeInsets.fromLTRB(8, 12, 8, 12),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(date,
                                  style: TextStyle(
                                      fontFamily: 'Cairo',
                                      fontSize: 11,
                                      color: Colors.grey.shade500)),
                              const SizedBox(height: 6),
                              InkWell(
                                onTap: entryId.isNotEmpty
                                    ? () => _deletePointLog(entryId, index)
                                    : null,
                                borderRadius: BorderRadius.circular(8),
                                child: Padding(
                                  padding: const EdgeInsets.all(4),
                                  child: Icon(Icons.delete_outline,
                                      size: 18,
                                      color: Colors.red.shade300),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  /// Colored pill that shows the source type ("نقاط خاصة" / "تسميع" / "حضور").
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

  // ═══════════════════════════════════════════════════════════════
  // RECITATIONS TAB
  // ═══════════════════════════════════════════════════════════════
  Widget _buildRecitationsTab() {
    if (_recitations.isEmpty) {
      return _buildEmptyState(
        Icons.menu_book_outlined,
        'لا يوجد سجل تسميع',
        'لم يتم تسجيل أي تسميعات لهذا الطالب بعد',
      );
    }

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
          alignment: Alignment.centerRight,
          child: Row(
            children: [
              Icon(Icons.swipe_rounded, size: 14, color: Colors.grey.shade400),
              const SizedBox(width: 4),
              Text('اسحب لليسار للحذف',
                  style: TextStyle(
                      fontFamily: 'Cairo',
                      fontSize: 11,
                      color: Colors.grey.shade400)),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
            itemCount: _recitations.length,
            itemBuilder: (context, index) {
              final r = _recitations[index];
              final recitationId = r['id']?.toString() ?? '';
              final suraName =
                  r['suraName'] ?? 'سورة ${r['surahNumber'] ?? ''}';
              final fromPage = r['fromPage'] ?? r['pageNumber'] ?? '';
              final toPage = r['toPage'] ?? '';
              final rating = r['rating'] ?? '';
              final type = r['type'] ?? 'RECITATION';
              final date = _formatDate(r['date'] ?? r['createdAt'] ?? '');
              final isMaqraa = type == 'MAQRAA';
              final homework = r['homework'] ?? '';
              final pagesRecited = r['pagesRecited'] ?? '';

              final ratingColor = _getRatingColor(rating);
              final ratingLabel = _getRatingLabel(rating);

              return Dismissible(
                key: Key('recitation_$recitationId'),
                direction: DismissDirection.endToStart,
                confirmDismiss: (_) async {
                  if (recitationId.isEmpty) return false;
                  await _deleteRecitation(recitationId, index);
                  return false;
                },
                background: Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  decoration: BoxDecoration(
                    color: Colors.red.shade600,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  alignment: Alignment.centerLeft,
                  padding: const EdgeInsets.only(left: 24),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.delete_outline, color: Colors.white),
                      SizedBox(width: 8),
                      Text('حذف',
                          style: TextStyle(
                              fontFamily: 'Cairo',
                              color: Colors.white,
                              fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
                child: Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: isMaqraa
                        ? Border.all(
                            color: TaqwaColors.minaretGold
                                .withValues(alpha: 0.4),
                            width: 1.5)
                        : null,
                    boxShadow: [
                      BoxShadow(
                          color: Colors.black.withValues(alpha: 0.04),
                          blurRadius: 8,
                          offset: const Offset(0, 2)),
                    ],
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: isMaqraa
                                ? TaqwaColors.minaretGold
                                    .withValues(alpha: 0.12)
                                : ratingColor.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            isMaqraa
                                ? Icons.groups_rounded
                                : Icons.menu_book_rounded,
                            color: isMaqraa
                                ? TaqwaColors.minaretGold
                                : ratingColor,
                            size: 22,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(suraName,
                                  style: const TextStyle(
                                      fontFamily: 'Cairo',
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      color: Color(0xFF2C3E50))),
                              const SizedBox(height: 4),
                              Wrap(
                                spacing: 8,
                                runSpacing: 4,
                                children: [
                                  _buildDetailChip(
                                    Icons.description_outlined,
                                    pagesRecited.toString().isNotEmpty
                                        ? '$pagesRecited صفحات'
                                        : (toPage.toString().isNotEmpty &&
                                                toPage != fromPage
                                            ? 'ص $fromPage - $toPage'
                                            : 'ص $fromPage'),
                                    Colors.grey.shade600,
                                  ),
                                  if (isMaqraa)
                                    _buildRatingBadge(
                                        'مقرأة', TaqwaColors.minaretGold)
                                  else if (ratingLabel.isNotEmpty)
                                    _buildRatingBadge(
                                        ratingLabel, ratingColor),
                                ],
                              ),
                              if (homework.toString().isNotEmpty) ...[
                                const SizedBox(height: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: TaqwaColors.skyBlue
                                        .withValues(alpha: 0.08),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.assignment_outlined,
                                          size: 13,
                                          color: TaqwaColors.skyBlue
                                              .withValues(alpha: 0.7)),
                                      const SizedBox(width: 4),
                                      Flexible(
                                        child: Text('واجب: $homework',
                                            style: TextStyle(
                                                fontFamily: 'Cairo',
                                                fontSize: 11,
                                                color: TaqwaColors.skyBlue
                                                    .withValues(alpha: 0.8)),
                                            maxLines: 1,
                                            overflow:
                                                TextOverflow.ellipsis),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(date,
                                style: TextStyle(
                                    fontFamily: 'Cairo',
                                    fontSize: 11,
                                    color: Colors.grey.shade500)),
                            const SizedBox(height: 8),
                            InkWell(
                              onTap: recitationId.isNotEmpty
                                  ? () =>
                                      _deleteRecitation(recitationId, index)
                                  : null,
                              borderRadius: BorderRadius.circular(8),
                              child: Padding(
                                padding: const EdgeInsets.all(4),
                                child: Icon(Icons.delete_outline,
                                    size: 18,
                                    color: Colors.red.shade300),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // ATTENDANCE TAB
  // ═══════════════════════════════════════════════════════════════
  Widget _buildAttendanceTab() {
    if (_attendance.isEmpty) {
      return _buildEmptyState(
        Icons.event_note_outlined,
        'لا يوجد سجل حضور',
        'لم يتم تسجيل أي حضور لهذا الطالب بعد',
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      itemCount: _attendance.length,
      itemBuilder: (context, index) {
        final a = _attendance[index];
        final status = a['status'] ?? '';
        final date = _formatDate(a['date'] ?? '');
        final fullDate = _formatFullDate(a['date'] ?? '');

        IconData icon;
        Color color;
        String label;
        switch (status) {
          case 'PRESENT':
            icon = Icons.check_circle_rounded;
            color = const Color(0xFF27AE60);
            label = 'حاضر';
            break;
          case 'LATE':
            icon = Icons.access_time_rounded;
            color = Colors.orange;
            label = 'متأخر';
            break;
          case 'ABSENT':
            icon = Icons.cancel_rounded;
            color = Colors.red;
            label = 'غائب';
            break;
          default:
            icon = Icons.help_outline;
            color = Colors.grey;
            label = status;
        }

        return Container(
          margin: const EdgeInsets.only(bottom: 6),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withValues(alpha: 0.03),
                  blurRadius: 6,
                  offset: const Offset(0, 2)),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 5,
                height: 56,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: const BorderRadius.only(
                    topRight: Radius.circular(12),
                    bottomRight: Radius.circular(12),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Icon(icon, color: color, size: 24),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label,
                        style: TextStyle(
                            fontFamily: 'Cairo',
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: color)),
                    Text(fullDate,
                        style: TextStyle(
                            fontFamily: 'Cairo',
                            fontSize: 11,
                            color: Colors.grey.shade500)),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(left: 14),
                child: Text(date,
                    style: TextStyle(
                        fontFamily: 'Cairo',
                        fontSize: 12,
                        color: Colors.grey.shade600)),
              ),
            ],
          ),
        );
      },
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // SHARED
  // ═══════════════════════════════════════════════════════════════
  Widget _buildDetailChip(IconData icon, String text, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: color),
        const SizedBox(width: 3),
        Text(text,
            style: TextStyle(
                fontFamily: 'Cairo', fontSize: 12, color: color)),
      ],
    );
  }

  Widget _buildRatingBadge(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(label,
          style: TextStyle(
              fontFamily: 'Cairo',
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: color)),
    );
  }

  Widget _buildEmptyState(IconData icon, String title, String subtitle) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 40, color: Colors.grey.shade300),
            ),
            const SizedBox(height: 16),
            Text(title,
                style: const TextStyle(
                    fontFamily: 'Cairo',
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey)),
            const SizedBox(height: 6),
            Text(subtitle,
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontFamily: 'Cairo',
                    fontSize: 13,
                    color: Colors.grey.shade500)),
          ],
        ),
      ),
    );
  }

  Color _getRatingColor(String rating) {
    switch (rating) {
      case 'VERY_GOOD':
        return TaqwaColors.islamicGreen;
      case 'GOOD':
        return TaqwaColors.skyBlue;
      case 'REPEAT':
        return Colors.orange;
      case 'DID_NOT_MEMORIZE':
        return Colors.red;
      case 'MAQRAA':
        return TaqwaColors.minaretGold;
      default:
        return Colors.grey;
    }
  }

  String _getRatingLabel(String rating) {
    switch (rating) {
      case 'VERY_GOOD':
        return 'جيد جداً';
      case 'GOOD':
        return 'جيد';
      case 'REPEAT':
        return 'إعادة';
      case 'DID_NOT_MEMORIZE':
        return 'لم يحفظ';
      case 'MAQRAA':
        return 'مقرأة';
      default:
        return rating;
    }
  }

  String _formatDate(String dateStr) {
    if (dateStr.isEmpty) return '';
    try {
      final date = DateTime.parse(dateStr);
      final now = DateTime.now();
      final diff = now.difference(date);
      if (diff.inDays == 0) return 'اليوم';
      if (diff.inDays == 1) return 'أمس';
      if (diff.inDays < 7) return 'منذ ${diff.inDays} أيام';
      if (diff.inDays < 30) {
        return 'منذ ${(diff.inDays / 7).floor()} أسابيع';
      }
      return '${date.day}/${date.month}/${date.year}';
    } catch (_) {
      return dateStr;
    }
  }

  String _formatFullDate(String dateStr) {
    if (dateStr.isEmpty) return '';
    try {
      final date = DateTime.parse(dateStr);
      const days = [
        'الأحد',
        'الإثنين',
        'الثلاثاء',
        'الأربعاء',
        'الخميس',
        'الجمعة',
        'السبت'
      ];
      final dayName = days[date.weekday % 7];
      return '$dayName ${date.day}/${date.month}/${date.year}';
    } catch (_) {
      return '';
    }
  }
}