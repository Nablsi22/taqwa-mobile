import 'package:flutter/material.dart';
import '../../../../core/theme/taqwa_colors.dart';
import '../../../../core/network/api_client.dart';

class AdminInstructorAttendanceScreen extends StatefulWidget {
  const AdminInstructorAttendanceScreen({super.key});

  @override
  State<AdminInstructorAttendanceScreen> createState() =>
      _AdminInstructorAttendanceScreenState();
}

class _AdminInstructorAttendanceScreenState
    extends State<AdminInstructorAttendanceScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // ── Mark Attendance state ──
  String _selectedDate = DateTime.now().toIso8601String().split('T')[0];
  List<Map<String, dynamic>> _sheet = [];
  Map<String, bool?> _localStatus = {};
  bool _isLoadingSheet = true;
  bool _isSaving = false;

  // ── Stats state ──
  List<Map<String, dynamic>> _allStats = [];
  bool _isLoadingStats = true;

  // ── History state ──
  String? _selectedHistoryInstructorId;
  String? _selectedHistoryInstructorName;
  Map<String, dynamic> _history = {};
  bool _isLoadingHistory = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadSheet();
    _loadAllStats();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  // ═══════════════════════════════════════════════════════════════
  // COMPUTED COUNTERS
  // ═══════════════════════════════════════════════════════════════
  int get _totalInstructors => _sheet.length;

  int get _markedPresent =>
      _localStatus.values.where((v) => v == true).length;

  int get _markedAbsent =>
      _localStatus.values.where((v) => v == false).length;

  // ═══════════════════════════════════════════════════════════════
  // DATA LOADING
  // ═══════════════════════════════════════════════════════════════

  Future<void> _loadSheet() async {
    setState(() => _isLoadingSheet = true);
    try {
      final res = await ApiClient.instance
          .get('/instructor-attendance/sheet?date=$_selectedDate');
      debugPrint('Sheet response: ${res.data}');
      final resData = res.data;

      // Handle both response formats
      List<dynamic> data;
      if (resData is Map && resData.containsKey('sheet')) {
        data = resData['sheet'] as List? ?? [];
      } else if (resData is Map && resData.containsKey('data')) {
        data = resData['data'] as List? ?? [];
      } else if (resData is List) {
        data = resData;
      } else {
        data = [];
      }

      setState(() {
        _sheet = data.map((e) => Map<String, dynamic>.from(e)).toList();
        _localStatus = {};
        for (final item in _sheet) {
          if (item['present'] != null) {
            _localStatus[item['instructorId']] = item['present'] as bool;
          }
        }
        _isLoadingSheet = false;
      });
    } catch (e) {
      debugPrint('Load sheet error: $e');
      // Fallback: load instructors directly
      await _loadInstructorsFallback();
    }
  }

  /// Fallback: if the instructor-attendance endpoint doesn't work,
  /// load instructors from the main endpoint
  Future<void> _loadInstructorsFallback() async {
    try {
      final res = await ApiClient.instance.get('/instructors');
      debugPrint('Instructors fallback response: ${res.data}');
      final data = res.data['data'] as List? ?? res.data as List? ?? [];

      setState(() {
        _sheet = data.map((e) {
          final inst = Map<String, dynamic>.from(e);
          return {
            'instructorId': inst['id'] ?? '',
            'fullName': inst['fullName'] ?? '',
            'studentCount': inst['studentCount'] ??
                inst['_count']?['students'] ??
                0,
            'present': null,
          };
        }).toList();
        _localStatus = {};
        _isLoadingSheet = false;
      });
    } catch (e) {
      debugPrint('Instructors fallback error: $e');
      setState(() => _isLoadingSheet = false);
    }
  }

  Future<void> _saveAttendance() async {
    if (_localStatus.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('يرجى تحديد حالة معلم واحد على الأقل',
              style: TextStyle(fontFamily: 'Cairo')),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => _isSaving = true);
    try {
      final entries = _localStatus.entries
          .map((e) => {
                'instructorId': e.key,
                'present': e.value ?? true,
              })
          .toList();

      await ApiClient.instance
          .post('/instructor-attendance/mark-bulk', data: {
        'date': _selectedDate,
        'entries': entries,
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تم حفظ حضور المعلمين بنجاح',
                style: TextStyle(fontFamily: 'Cairo')),
            backgroundColor: TaqwaColors.islamicGreen,
          ),
        );
      }
      // Reload stats after saving
      _loadAllStats();
    } catch (e) {
      debugPrint('Save error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content:
                Text('خطأ: $e', style: const TextStyle(fontFamily: 'Cairo')),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
    if (mounted) setState(() => _isSaving = false);
  }

  Future<void> _loadAllStats() async {
    setState(() => _isLoadingStats = true);
    try {
      final res =
          await ApiClient.instance.get('/instructor-attendance/stats');
      debugPrint('Stats response: ${res.data}');

      final resData = res.data;
      List<dynamic> data;
      if (resData is Map && resData.containsKey('data')) {
        data = resData['data'] as List? ?? [];
      } else if (resData is List) {
        data = resData;
      } else {
        data = [];
      }

      setState(() {
        _allStats = data.map((e) => Map<String, dynamic>.from(e)).toList();
        _isLoadingStats = false;
      });
    } catch (e) {
      debugPrint('Stats error: $e');
      setState(() => _isLoadingStats = false);
    }
  }

  Future<void> _loadHistory(String instructorId) async {
    setState(() => _isLoadingHistory = true);
    try {
      final res = await ApiClient.instance
          .get('/instructor-attendance/history/$instructorId?limit=60');
      debugPrint('History response: ${res.data}');
      setState(() {
        _history = Map<String, dynamic>.from(res.data);
        _isLoadingHistory = false;
      });
    } catch (e) {
      debugPrint('History error: $e');
      setState(() => _isLoadingHistory = false);
    }
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.parse(_selectedDate),
      firstDate: DateTime(2024),
      lastDate: DateTime.now(),
      builder: (context, child) => Directionality(
        textDirection: TextDirection.rtl,
        child: Theme(
          data: ThemeData.light().copyWith(
            colorScheme: const ColorScheme.light(
              primary: TaqwaColors.domeBlue,
              onPrimary: Colors.white,
            ),
          ),
          child: child!,
        ),
      ),
    );
    if (picked != null) {
      _selectedDate = picked.toIso8601String().split('T')[0];
      _loadSheet();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFFF5F6FA),
        appBar: AppBar(
          backgroundColor: TaqwaColors.domeBlue,
          title: const Text('حضور المعلمين',
              style: TextStyle(fontFamily: 'Cairo', color: Colors.white)),
          iconTheme: const IconThemeData(color: Colors.white),
          bottom: TabBar(
            controller: _tabController,
            indicatorColor: TaqwaColors.minaretGold,
            indicatorWeight: 3,
            labelStyle: const TextStyle(
                fontFamily: 'Cairo',
                fontWeight: FontWeight.bold,
                fontSize: 14),
            unselectedLabelStyle:
                const TextStyle(fontFamily: 'Cairo', fontSize: 13),
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white60,
            tabs: const [
              Tab(text: 'تسجيل الحضور'),
              Tab(text: 'الإحصائيات'),
              Tab(text: 'السجل'),
            ],
          ),
        ),
        body: TabBarView(
          controller: _tabController,
          children: [
            _buildMarkTab(),
            _buildStatsTab(),
            _buildHistoryTab(),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // TAB 1: MARK ATTENDANCE
  // ═══════════════════════════════════════════════════════════════
  Widget _buildMarkTab() {
    return Column(
      children: [
        // ── Date picker bar ──
        Container(
          margin: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                color: TaqwaColors.domeBlue.withOpacity(0.08),
                blurRadius: 10,
              ),
            ],
          ),
          child: Row(
            children: [
              const Icon(Icons.calendar_today,
                  color: TaqwaColors.domeBlue, size: 20),
              const SizedBox(width: 10),
              Text(
                _selectedDate,
                style: const TextStyle(
                  fontFamily: 'Cairo',
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: TaqwaColors.domeBlue,
                ),
              ),
              const Spacer(),
              TextButton(
                onPressed: _pickDate,
                child: const Text('تغيير التاريخ',
                    style: TextStyle(fontFamily: 'Cairo')),
              ),
            ],
          ),
        ),

        // ── ATTENDANCE COUNTER ──
        if (!_isLoadingSheet && _sheet.isNotEmpty)
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  TaqwaColors.domeBlue,
                  TaqwaColors.domeBlue.withOpacity(0.85),
                ],
              ),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              children: [
                // Total
                _buildCounterItem(
                  icon: Icons.school,
                  label: 'الإجمالي',
                  value: '$_totalInstructors',
                  color: Colors.white,
                ),
                const SizedBox(width: 4),
                Container(width: 1, height: 36, color: Colors.white24),
                const SizedBox(width: 4),
                // Present
                _buildCounterItem(
                  icon: Icons.check_circle,
                  label: 'حاضر',
                  value: '$_markedPresent',
                  color: const Color(0xFF2ECC71),
                ),
                const SizedBox(width: 4),
                Container(width: 1, height: 36, color: Colors.white24),
                const SizedBox(width: 4),
                // Absent
                _buildCounterItem(
                  icon: Icons.cancel,
                  label: 'غائب',
                  value: '$_markedAbsent',
                  color: const Color(0xFFE74C3C),
                ),
                const SizedBox(width: 4),
                Container(width: 1, height: 36, color: Colors.white24),
                const SizedBox(width: 4),
                // Unmarked
                _buildCounterItem(
                  icon: Icons.help_outline,
                  label: 'بدون تحديد',
                  value: '${_totalInstructors - _markedPresent - _markedAbsent}',
                  color: Colors.amber,
                ),
              ],
            ),
          ),

        const SizedBox(height: 8),

        // ── Instructors list ──
        Expanded(
          child: _isLoadingSheet
              ? const Center(
                  child:
                      CircularProgressIndicator(color: TaqwaColors.domeBlue))
              : _sheet.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.school,
                              size: 64,
                              color: Colors.grey.shade300),
                          const SizedBox(height: 12),
                          const Text('لا يوجد معلمون',
                              style: TextStyle(
                                  fontFamily: 'Cairo',
                                  fontSize: 16,
                                  color: Colors.grey)),
                          const SizedBox(height: 8),
                          TextButton.icon(
                            icon: const Icon(Icons.refresh),
                            label: const Text('إعادة التحميل',
                                style: TextStyle(fontFamily: 'Cairo')),
                            onPressed: _loadSheet,
                          ),
                        ],
                      ),
                    )
                  : RefreshIndicator(
                      color: TaqwaColors.domeBlue,
                      onRefresh: _loadSheet,
                      child: ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: _sheet.length,
                        itemBuilder: (context, index) {
                          final item = _sheet[index];
                          final id = item['instructorId'] as String;
                          final name = item['fullName'] ?? '';
                          final count = item['studentCount'] ?? 0;
                          final isPresent = _localStatus[id];

                          return Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(14),
                              border: isPresent == true
                                  ? Border.all(
                                      color: TaqwaColors.islamicGreen
                                          .withOpacity(0.5),
                                      width: 1.5)
                                  : isPresent == false
                                      ? Border.all(
                                          color: Colors.red.withOpacity(0.5),
                                          width: 1.5)
                                      : Border.all(
                                          color: Colors.grey.shade200),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.03),
                                  blurRadius: 6,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Row(
                              children: [
                                // Avatar
                                Container(
                                  width: 46,
                                  height: 46,
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: isPresent == true
                                          ? [
                                              TaqwaColors.islamicGreen,
                                              TaqwaColors.islamicGreen
                                                  .withOpacity(0.7)
                                            ]
                                          : isPresent == false
                                              ? [
                                                  Colors.red,
                                                  Colors.red.withOpacity(0.7)
                                                ]
                                              : [
                                                  TaqwaColors.domeBlue,
                                                  TaqwaColors.domeBlue
                                                      .withOpacity(0.7)
                                                ],
                                    ),
                                    borderRadius: BorderRadius.circular(13),
                                  ),
                                  child: Center(
                                    child: Text(
                                      name.isNotEmpty ? name[0] : '?',
                                      style: const TextStyle(
                                        fontFamily: 'Cairo',
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                // Info
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(name,
                                          style: const TextStyle(
                                              fontFamily: 'Cairo',
                                              fontSize: 15,
                                              fontWeight: FontWeight.bold,
                                              color: Color(0xFF2C3E50))),
                                      Row(
                                        children: [
                                          Icon(Icons.people,
                                              size: 14,
                                              color: Colors.grey.shade500),
                                          const SizedBox(width: 4),
                                          Text('$count طالب',
                                              style: TextStyle(
                                                  fontFamily: 'Cairo',
                                                  fontSize: 12,
                                                  color:
                                                      Colors.grey.shade600)),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                                // Present / Absent toggle
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    _buildToggleBtn(
                                      label: 'حاضر',
                                      icon: Icons.check_circle,
                                      isSelected: isPresent == true,
                                      color: TaqwaColors.islamicGreen,
                                      onTap: () => setState(
                                          () => _localStatus[id] = true),
                                    ),
                                    const SizedBox(width: 8),
                                    _buildToggleBtn(
                                      label: 'غائب',
                                      icon: Icons.cancel,
                                      isSelected: isPresent == false,
                                      color: Colors.red,
                                      onTap: () => setState(
                                          () => _localStatus[id] = false),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
        ),

        // ── Save button ──
        Padding(
          padding: const EdgeInsets.all(16),
          child: SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton.icon(
              icon: _isSaving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2),
                    )
                  : const Icon(Icons.save),
              label: Text(
                _isSaving ? 'جاري الحفظ...' : 'حفظ الحضور',
                style: const TextStyle(
                    fontFamily: 'Cairo',
                    fontSize: 16,
                    fontWeight: FontWeight.bold),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: TaqwaColors.domeBlue,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
                elevation: 2,
              ),
              onPressed: _isSaving ? null : _saveAttendance,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCounterItem({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Expanded(
      child: Column(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 2),
          Text(
            value,
            style: TextStyle(
              fontFamily: 'Cairo',
              fontSize: 17,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(
            label,
            style: TextStyle(
              fontFamily: 'Cairo',
              fontSize: 10,
              color: Colors.white.withOpacity(0.7),
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildToggleBtn({
    required String label,
    required IconData icon,
    required bool isSelected,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? color : color.withOpacity(0.06),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? color : color.withOpacity(0.2),
            width: 1.5,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon,
                size: 16, color: isSelected ? Colors.white : color),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontFamily: 'Cairo',
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: isSelected ? Colors.white : color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // TAB 2: STATS
  // ═══════════════════════════════════════════════════════════════
  Widget _buildStatsTab() {
    if (_isLoadingStats) {
      return const Center(
          child: CircularProgressIndicator(color: TaqwaColors.domeBlue));
    }

    if (_allStats.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.bar_chart, size: 64, color: Colors.grey.shade300),
            const SizedBox(height: 12),
            const Text(
              'لا توجد إحصائيات بعد',
              style: TextStyle(
                  fontFamily: 'Cairo', fontSize: 16, color: Colors.grey),
            ),
            const SizedBox(height: 4),
            const Text(
              'سجّل حضور المعلمين أولاً من تبويب "تسجيل الحضور"',
              style: TextStyle(
                  fontFamily: 'Cairo', fontSize: 13, color: Colors.grey),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            TextButton.icon(
              icon: const Icon(Icons.refresh),
              label: const Text('تحديث',
                  style: TextStyle(fontFamily: 'Cairo')),
              onPressed: _loadAllStats,
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      color: TaqwaColors.domeBlue,
      onRefresh: _loadAllStats,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _allStats.length,
        itemBuilder: (context, index) {
          final s = _allStats[index];
          final name = s['fullName'] ?? '';
          final rate = s['rate'] ?? 0;
          final present = s['present'] ?? 0;
          final absent = s['absent'] ?? 0;
          final total = s['totalDays'] ?? 0;

          final rateColor = rate >= 80
              ? TaqwaColors.islamicGreen
              : rate >= 50
                  ? Colors.orange
                  : Colors.red;

          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.04),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: TaqwaColors.domeBlue.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.school,
                          color: TaqwaColors.domeBlue, size: 22),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(name,
                          style: const TextStyle(
                              fontFamily: 'Cairo',
                              fontSize: 15,
                              fontWeight: FontWeight.bold)),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 6),
                      decoration: BoxDecoration(
                        color: rateColor.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        '$rate%',
                        style: TextStyle(
                          fontFamily: 'Cairo',
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: rateColor,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                // Progress bar
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: (rate / 100.0).clamp(0.0, 1.0),
                    backgroundColor: Colors.grey.shade200,
                    valueColor: AlwaysStoppedAnimation(rateColor),
                    minHeight: 8,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    _buildStatChip(
                        'حاضر', '$present', TaqwaColors.islamicGreen),
                    const SizedBox(width: 8),
                    _buildStatChip('غائب', '$absent', Colors.red),
                    const SizedBox(width: 8),
                    _buildStatChip(
                        'إجمالي', '$total', TaqwaColors.domeBlue),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildStatChip(String label, String value, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              '$label: ',
              style: TextStyle(
                  fontFamily: 'Cairo',
                  fontSize: 12,
                  color: color.withOpacity(0.8)),
            ),
            Text(
              value,
              style: TextStyle(
                fontFamily: 'Cairo',
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // TAB 3: HISTORY (per instructor)
  // ═══════════════════════════════════════════════════════════════
  Widget _buildHistoryTab() {
    if (_selectedHistoryInstructorId == null) {
      return _buildHistoryInstructorPicker();
    }
    return _buildHistoryDetail();
  }

  Widget _buildHistoryInstructorPicker() {
    // Use _allStats if available, otherwise fall back to _sheet
    final instructors = _allStats.isNotEmpty
        ? _allStats
        : _sheet.map((s) => {
              'instructorId': s['instructorId'],
              'fullName': s['fullName'],
            }).toList();

    if (_isLoadingStats && _isLoadingSheet) {
      return const Center(
          child: CircularProgressIndicator(color: TaqwaColors.domeBlue));
    }

    if (instructors.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.history, size: 64, color: Colors.grey.shade300),
            const SizedBox(height: 12),
            const Text('لا يوجد بيانات',
                style: TextStyle(
                    fontFamily: 'Cairo', fontSize: 16, color: Colors.grey)),
            const SizedBox(height: 4),
            const Text('سجّل الحضور أولاً لعرض السجل هنا',
                style: TextStyle(
                    fontFamily: 'Cairo', fontSize: 13, color: Colors.grey)),
            const SizedBox(height: 16),
            TextButton.icon(
              icon: const Icon(Icons.refresh),
              label:
                  const Text('تحديث', style: TextStyle(fontFamily: 'Cairo')),
              onPressed: () {
                _loadAllStats();
                _loadSheet();
              },
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: instructors.length,
      itemBuilder: (context, index) {
        final s = instructors[index];
        final name = s['fullName'] ?? '';
        final id = s['instructorId'] ?? s['id'] ?? '';

        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          child: Material(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            elevation: 1,
            child: InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: () {
                setState(() {
                  _selectedHistoryInstructorId = id;
                  _selectedHistoryInstructorName = name;
                });
                _loadHistory(id);
              },
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: TaqwaColors.domeBlue.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Center(
                        child: Text(
                          name.isNotEmpty ? name[0] : '?',
                          style: const TextStyle(
                            fontFamily: 'Cairo',
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: TaqwaColors.domeBlue,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(name,
                          style: const TextStyle(
                              fontFamily: 'Cairo',
                              fontSize: 15,
                              fontWeight: FontWeight.bold)),
                    ),
                    const Icon(Icons.arrow_forward_ios,
                        size: 16, color: Colors.grey),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildHistoryDetail() {
    if (_isLoadingHistory) {
      return const Center(
          child: CircularProgressIndicator(color: TaqwaColors.domeBlue));
    }

    final summary = _history['summary'] as Map<String, dynamic>? ?? {};
    final records = (_history['data'] as List? ?? [])
        .map((e) => Map<String, dynamic>.from(e))
        .toList();

    return Column(
      children: [
        // Back + name header
        Container(
          margin: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: TaqwaColors.domeBlue.withOpacity(0.06),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            children: [
              GestureDetector(
                onTap: () => setState(() {
                  _selectedHistoryInstructorId = null;
                  _selectedHistoryInstructorName = null;
                  _history = {};
                }),
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: TaqwaColors.domeBlue.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.arrow_back,
                      size: 18, color: TaqwaColors.domeBlue),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  _selectedHistoryInstructorName ?? '',
                  style: const TextStyle(
                    fontFamily: 'Cairo',
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: TaqwaColors.domeBlue,
                  ),
                ),
              ),
              if (summary.isNotEmpty)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: TaqwaColors.islamicGreen.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    'نسبة الحضور: ${summary['rate'] ?? 0}%',
                    style: const TextStyle(
                      fontFamily: 'Cairo',
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: TaqwaColors.islamicGreen,
                    ),
                  ),
                ),
            ],
          ),
        ),

        // Summary row
        if (summary.isNotEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                _buildStatChip('حاضر', '${summary['present'] ?? 0}',
                    TaqwaColors.islamicGreen),
                const SizedBox(width: 8),
                _buildStatChip(
                    'غائب', '${summary['absent'] ?? 0}', Colors.red),
                const SizedBox(width: 8),
                _buildStatChip('إجمالي',
                    '${summary['totalDays'] ?? 0}', TaqwaColors.domeBlue),
              ],
            ),
          ),

        const SizedBox(height: 12),

        // Records list
        Expanded(
          child: records.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.event_note,
                          size: 48, color: Colors.grey.shade300),
                      const SizedBox(height: 8),
                      const Text('لا يوجد سجلات بعد',
                          style: TextStyle(
                              fontFamily: 'Cairo', color: Colors.grey)),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: records.length,
                  itemBuilder: (context, index) {
                    final r = records[index];
                    final present = r['present'] == true;
                    final date = _formatHistoryDate(r['date'] ?? '');

                    return Container(
                      margin: const EdgeInsets.only(bottom: 6),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border(
                          right: BorderSide(
                            color: present
                                ? TaqwaColors.islamicGreen
                                : Colors.red,
                            width: 4,
                          ),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            present ? Icons.check_circle : Icons.cancel,
                            color: present
                                ? TaqwaColors.islamicGreen
                                : Colors.red,
                            size: 24,
                          ),
                          const SizedBox(width: 12),
                          Text(
                            present ? 'حاضر' : 'غائب',
                            style: TextStyle(
                              fontFamily: 'Cairo',
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: present
                                  ? TaqwaColors.islamicGreen
                                  : Colors.red,
                            ),
                          ),
                          const Spacer(),
                          Text(
                            date,
                            style: TextStyle(
                              fontFamily: 'Cairo',
                              fontSize: 13,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  String _formatHistoryDate(String dateStr) {
    if (dateStr.isEmpty) return '';
    try {
      final date = DateTime.parse(dateStr);
      final now = DateTime.now();
      final diff = now.difference(date);

      if (diff.inDays == 0) return 'اليوم';
      if (diff.inDays == 1) return 'أمس';

      final weekDays = [
        'الإثنين',
        'الثلاثاء',
        'الأربعاء',
        'الخميس',
        'الجمعة',
        'السبت',
        'الأحد'
      ];
      if (diff.inDays < 7) return weekDays[date.weekday - 1];

      return '${date.day}/${date.month}/${date.year}';
    } catch (_) {
      return dateStr;
    }
  }
}
