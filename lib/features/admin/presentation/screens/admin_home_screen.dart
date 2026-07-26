import 'package:flutter/material.dart';
import '../../../../core/theme/taqwa_colors.dart';
import '../../../../core/network/api_client.dart';
import '../../../announcement/presentation/screens/announcement_list_screen.dart';
import '../../../gifts/presentation/screens/admin_gifts_screen.dart';
import '../../../point_rules/presentation/screens/admin_point_rules_screen.dart';
import '../../../azkar/presentation/screens/azkar_home_screen.dart';
import '../../../quran_reader/presentation/screens/quran_surah_list_screen.dart';
import 'admin_students_by_instructor_screen.dart';
import 'admin_instructor_attendance_screen.dart';
import 'admin_leaderboard_screen.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import 'package:provider/provider.dart';
import '../../../students/presentation/screens/add_student_screen.dart';
import '../../../instructor/presentation/screens/add_edit_instructor_screen.dart';
import 'admin_manage_students_screen.dart';
import 'admin_manage_instructors_screen.dart';
import '../../../../core/widgets/taqwa_slogan_banner.dart';
import 'admin_credentials_screen.dart';

class AdminHomeScreen extends StatefulWidget {
  const AdminHomeScreen({super.key});

  @override
  State<AdminHomeScreen> createState() => _AdminHomeScreenState();
}

class _AdminHomeScreenState extends State<AdminHomeScreen> {
  int _totalStudents = 0;
  int _totalInstructors = 0;
  int _studentPresent = 0;
  int _studentAbsent = 0;
  int _instructorPresent = 0;
  int _instructorAbsent = 0;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadDashboardStats();
  }

  /// Extracts the roll size from a paginated API envelope.
  ///
  /// `/students` returns at most 50 rows per request by default, so counting
  /// the returned list reports 50 no matter how many students exist. The
  /// server already sends the true unpaginated figure in `meta.total`; this
  /// reads that, and only falls back to the page length for endpoints that
  /// return a bare list with no envelope.
  int _countFrom(dynamic body, List<dynamic> page) {
    if (body is Map) {
      final meta = body['meta'];
      if (meta is Map) {
        final total = meta['total'];
        if (total is num) return total.toInt();
        if (total is String) {
          final parsed = int.tryParse(total);
          if (parsed != null) return parsed;
        }
      }
    }
    return page.length;
  }

  /// Pulls the row list out of either an enveloped (`{ data: [...] }`) or a
  /// bare-list response without assuming which shape arrived.
  List<dynamic> _listFrom(dynamic body) {
    if (body is Map) return body['data'] as List? ?? const [];
    if (body is List) return body;
    return const [];
  }

  Future<void> _loadDashboardStats() async {
    setState(() => _isLoading = true);
    try {
      // ── Student & Instructor counts ──
      final studentsRes = await ApiClient.instance.get('/students');
      final studentsBody = studentsRes.data;
      final studentsList = _listFrom(studentsBody);
      _totalStudents = _countFrom(studentsBody, studentsList);

      final instructorsRes = await ApiClient.instance.get('/instructors');
      final instructorsBody = instructorsRes.data;
      final instructorsList = _listFrom(instructorsBody);
      _totalInstructors = _countFrom(instructorsBody, instructorsList);

      final today = DateTime.now().toIso8601String().split('T')[0];

      // ── Student attendance stats ──
      try {
        final statsRes =
            await ApiClient.instance.get('/attendance/stats?date=$today');
        _studentPresent = statsRes.data['present'] ?? 0;
        _studentAbsent = statsRes.data['absent'] ?? 0;
      } catch (_) {}

      // ── Instructor attendance stats ──
      try {
        final instSheetRes = await ApiClient.instance
            .get('/instructor-attendance/sheet?date=$today');
        final sheet = instSheetRes.data['sheet'] as List? ?? [];
        _instructorPresent = 0;
        _instructorAbsent = 0;
        for (final entry in sheet) {
          if (entry['present'] == true) {
            _instructorPresent++;
          } else if (entry['present'] == false) {
            _instructorAbsent++;
          }
        }
      } catch (_) {}
    } catch (_) {}
    if (mounted) setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFFF5F6FA),
        body: RefreshIndicator(
          color: TaqwaColors.domeBlue,
          onRefresh: _loadDashboardStats,
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              // ═══ APP BAR ═══
              const SliverToBoxAdapter(child: TaqwaSloganBanner()),
              SliverAppBar(
                expandedHeight: 160,
                floating: false,
                pinned: true,
                backgroundColor: TaqwaColors.domeBlue,
                automaticallyImplyLeading: false,
                flexibleSpace: FlexibleSpaceBar(
                  background: Container(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        colors: [TaqwaColors.domeBlue, Color(0xFF154360)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),
                    child: SafeArea(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                        child: Row(
                          children: [
                            Container(
                              width: 48,
                              height: 48,
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: const Icon(Icons.admin_panel_settings,
                                  color: Colors.white, size: 28),
                            ),
                            const SizedBox(width: 12),
                            Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Text(
                                //   _getGreeting(),
                                //   style: TextStyle(
                                //     fontFamily: 'Cairo',
                                //     fontSize: 13,
                                //     color: Colors.white.withOpacity(0.8),
                                //   ),

                                // ),
                                const Text(
                                  'لوحة تحكم المشرف',
                                  style: TextStyle(
                                    fontFamily: 'Cairo',
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                              ],
                            ),
                            const Spacer(),
                            IconButton(
                              icon: const Icon(Icons.logout,
                                  color: Colors.white70),
                              onPressed: () => _showLogoutDialog(context),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),

              // ═══ STATS CARDS (6 widgets in 2 rows) ═══
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
                  child: _isLoading
                      ? const Center(
                          child: Padding(
                            padding: EdgeInsets.all(20),
                            child: CircularProgressIndicator(
                                color: TaqwaColors.domeBlue),
                          ),
                        )
                      : Column(
                          children: [
                            // ── Row 1: Counts ──
                            Row(
                              children: [
                                _buildStatCard(Icons.people, 'الطلاب',
                                    '$_totalStudents', TaqwaColors.skyBlue),
                                const SizedBox(width: 10),
                                _buildStatCard(
                                    Icons.school,
                                    'المعلمون',
                                    '$_totalInstructors',
                                    TaqwaColors.islamicGreen),
                              ],
                            ),
                            const SizedBox(height: 10),
                            // ── Row 2: Student Attendance ──
                            Row(
                              children: [
                                _buildStatCard(
                                    Icons.check_circle_outline,
                                    'طلاب حاضرون',
                                    '$_studentPresent',
                                    const Color(0xFF27AE60)),
                                const SizedBox(width: 10),
                                _buildStatCard(
                                    Icons.highlight_off,
                                    'طلاب غائبون',
                                    '$_studentAbsent',
                                    Colors.red.shade600),
                              ],
                            ),
                            const SizedBox(height: 10),
                            // ── Row 3: Instructor Attendance ──
                            Row(
                              children: [
                                _buildStatCard(
                                    Icons.person_pin_circle,
                                    'معلمون حاضرون',
                                    '$_instructorPresent',
                                    const Color(0xFF2E86C1)),
                                const SizedBox(width: 10),
                                _buildStatCard(
                                    Icons.person_off,
                                    'معلمون غائبون',
                                    '$_instructorAbsent',
                                    const Color(0xFFE74C3C)),
                              ],
                            ),
                          ],
                        ),
                ),
              ),

              // ═══ إدارة المعلمين ═══
              _sectionHeader('إدارة المعلمين'),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Column(
                    children: [
                      _buildActionCard(
                        icon: Icons.manage_accounts,
                        title: 'إدارة المعلمين',
                        subtitle: 'عرض وتعديل بيانات المعلمين وكلمات المرور',
                        color: TaqwaColors.domeBlue,
                        onTap: () =>
                            _navigate(const AdminManageInstructorsScreen()),
                      ),
                      const SizedBox(height: 10),
                      _buildActionCard(
                        icon: Icons.assignment_turned_in,
                        title: 'حضور المعلمين',
                        subtitle: 'تسجيل وعرض حضور المعلمين',
                        color: const Color(0xFF8E44AD),
                        onTap: () =>
                            _navigate(const AdminInstructorAttendanceScreen()),
                      ),
                    ],
                  ),
                ),
              ),

              // ═══ متابعة الطلاب ═══
              _sectionHeader('متابعة الطلاب'),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Column(
                    children: [
                      _buildActionCard(
                        icon: Icons.people_alt,
                        title: 'إدارة الطلاب',
                        subtitle: 'عرض وتعديل بيانات الطلاب وكلمات المرور',
                        color: const Color(0xFF16A085),
                        onTap: () =>
                            _navigate(const AdminManageStudentsScreen()),
                      ),
                      const SizedBox(height: 10),
                      _buildActionCard(
                        icon: Icons.people_outline,
                        title: 'الطلاب حسب المعلم',
                        subtitle: 'عرض طلاب كل معلم مع الإحصائيات',
                        color: TaqwaColors.skyBlue,
                        onTap: () => _navigate(
                            const AdminStudentsByInstructorScreen()),
                      ),
                      const SizedBox(height: 10),
                      _buildActionCard(
                        icon: Icons.leaderboard,
                        title: 'ترتيب الطلاب',
                        subtitle: 'جميع الطلاب مرتبين حسب النقاط',
                        color: TaqwaColors.minaretGold,
                        onTap: () =>
                            _navigate(const AdminLeaderboardScreen()),
                      ),
                      const SizedBox(height: 10),
                      _buildActionCard(
                        icon: Icons.vpn_key_rounded,
                        title: 'بيانات دخول الطلاب',
                        subtitle: 'إدارة وإرسال بيانات الدخول لأولياء الأمور',
                        color: const Color(0xFF8E44AD),
                        onTap: () =>
                            _navigate(const AdminCredentialsScreen()),
                      ),
                    ],
                  ),
                ),
              ),

              // ═══ النقاط والهدايا ═══
              _sectionHeader('النقاط والهدايا'),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      Expanded(
                        child: _buildActionCard(
                          icon: Icons.rule,
                          title: 'قواعد النقاط',
                          subtitle: 'إضافة وخصم',
                          color: const Color(0xFFE67E22),
                          onTap: () =>
                              _navigate(const AdminPointRulesScreen()),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildActionCard(
                          icon: Icons.card_giftcard,
                          title: 'متجر الهدايا',
                          subtitle: 'إدارة الهدايا',
                          color: const Color(0xFFE74C3C),
                          onTap: () =>
                              _navigate(const AdminGiftsScreen()),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // ═══ القرآن والأذكار ═══
              _sectionHeader('القرآن والأذكار'),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      Expanded(
                        child: _buildActionCard(
                          icon: Icons.menu_book,
                          title: 'القرآن الكريم',
                          subtitle: 'تصفح المصحف',
                          color: const Color(0xFF1ABC9C),
                          onTap: () =>
                              _navigate(const QuranSurahListScreen()),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildActionCard(
                          icon: Icons.auto_awesome,
                          title: 'الأذكار',
                          subtitle: 'أذكار الصباح والمساء',
                          color: const Color(0xFF3498DB),
                          onTap: () =>
                              _navigate(const AzkarHomeScreen()),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // ═══ الإعلانات ═══
              _sectionHeader('التواصل'),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                  child: _buildActionCard(
                    icon: Icons.campaign,
                    title: 'الإعلانات',
                    subtitle: 'إرسال وإدارة الإعلانات',
                    color: const Color(0xFF2980B9),
                    onTap: () =>
                        _navigate(const AnnouncementListScreen()),
                  ),
                ),
              ),

              const SliverToBoxAdapter(child: SizedBox(height: 32)),
            ],
          ),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // HELPERS
  // ═══════════════════════════════════════════════════════════════

  void _navigate(Widget screen) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => screen));
  }

  // String _getGreeting() {
  //   final hour = DateTime.now().hour;
  //   if (hour < 12) return 'صباح الخير';
  //   if (hour < 17) return 'مساء الخير';
  //   return 'مساء النور';
  // }

  SliverToBoxAdapter _sectionHeader(String title) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
        child: Text(title,
            style: const TextStyle(
                fontFamily: 'Cairo',
                fontSize: 17,
                fontWeight: FontWeight.bold,
                color: TaqwaColors.domeBlue)),
      ),
    );
  }

  Widget _buildStatCard(
      IconData icon, String label, String value, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
                color: color.withOpacity(0.12),
                blurRadius: 10,
                offset: const Offset(0, 4)),
          ],
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 6),
            Text(value,
                style: TextStyle(
                    fontFamily: 'Cairo',
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: color)),
            Text(label,
                style: const TextStyle(
                    fontFamily: 'Cairo', fontSize: 11, color: Colors.grey),
                textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }

  Widget _buildActionCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                  color: color.withOpacity(0.1),
                  blurRadius: 12,
                  offset: const Offset(0, 4)),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: color, size: 26),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: const TextStyle(
                            fontFamily: 'Cairo',
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF2C3E50))),
                    Text(subtitle,
                        style: TextStyle(
                            fontFamily: 'Cairo',
                            fontSize: 12,
                            color: Colors.grey.shade500)),
                  ],
                ),
              ),
              Icon(Icons.arrow_forward_ios,
                  size: 16, color: Colors.grey.shade400),
            ],
          ),
        ),
      ),
    );
  }

  void _showLogoutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('تسجيل الخروج',
              style:
                  TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold)),
          content: const Text('هل تريد تسجيل الخروج من التطبيق؟',
              style: TextStyle(fontFamily: 'Cairo')),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('إلغاء',
                  style: TextStyle(fontFamily: 'Cairo', color: Colors.grey)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: () {
                Navigator.pop(ctx);
                context.read<AuthProvider>().logout();
              },
              child: const Text('خروج',
                  style: TextStyle(fontFamily: 'Cairo', color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }
}