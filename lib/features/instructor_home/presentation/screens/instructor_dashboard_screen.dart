import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/theme/taqwa_colors.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/constants/quran_metadata.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../recitation/data/recitation_api.dart';
import '../../../attendance/data/repositories/attendance_repository.dart';
import '../../../attendance/presentation/providers/attendance_provider.dart';
import '../../../attendance/presentation/screens/attendance_screen.dart';
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

  bool _isLoading = true;
  String? _error;
  String _instructorName = '';
  String? _instructorId;
  List<Map<String, dynamic>> _students = [];

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

    try {
      final overview = await _recitationApi.getInstructorOverview();
      setState(() {
        _students = overview;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  void _navigateToStudentDetail(Map<String, dynamic> student) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => InstructorStudentDetailScreen(
          studentId: student['studentId'] as String,
          studentName: student['fullName'] as String? ?? 'طالب',
        ),
      ),
    ).then((_) => _loadDashboard());
  }

  void _navigateToAttendance() {
    if (_instructorId == null) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChangeNotifierProvider(
          create: (_) => AttendanceProvider(
            repository: AttendanceRepository(apiClient: ApiClient.instance),
            instructorId: _instructorId,
          ),
          child: const AttendanceScreen(),
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
                                    IconButton(
                                      onPressed: () {
                                        context.read<AuthProvider>().logout();
                                      },
                                      icon: const Icon(Icons.logout,
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
                                      onTap: _navigateToAttendance,
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
                              ],
                            ),
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
                                    color:
                                        TaqwaColors.domeBlue.withOpacity(0.08),
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

  Widget _actionButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: Material(
        color: Colors.white.withOpacity(0.12),
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
                    color: index < 3
                        ? TaqwaColors.minaretGold.withOpacity(0.12)
                        : Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Center(
                    child: Text(
                      '${index + 1}',
                      style: TextStyle(
                        fontFamily: 'Cairo',
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: index < 3
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
                      // D2 compact line — gray-muted when no prior recitation
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
                      color: ratingColor.withOpacity(0.1),
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