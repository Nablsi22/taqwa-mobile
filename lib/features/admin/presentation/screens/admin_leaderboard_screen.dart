import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/theme/taqwa_colors.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/widgets/points_display.dart';
import '../../../../core/extensions/points_formatting.dart';
import '../../../terms/presentation/providers/term_provider.dart';
import '../../../terms/presentation/widgets/term_selector.dart';
import 'admin_student_detail_screen.dart';

class AdminLeaderboardScreen extends StatefulWidget {
  const AdminLeaderboardScreen({super.key});

  @override
  State<AdminLeaderboardScreen> createState() =>
      _AdminLeaderboardScreenState();
}

class _AdminLeaderboardScreenState extends State<AdminLeaderboardScreen> {
  List<Map<String, dynamic>> _students = [];
  List<Map<String, dynamic>> _filteredStudents = [];
  bool _isLoading = true;
  final _searchController = TextEditingController();
  bool _showSearch = false;

  @override
  void initState() {
    super.initState();
    _loadLeaderboard();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    final query = _searchController.text.trim().toLowerCase();
    setState(() {
      if (query.isEmpty) {
        _filteredStudents = List.from(_students);
      } else {
        _filteredStudents = _students.where((s) {
          final name = (s['fullName'] ?? '').toString().toLowerCase();
          final instructor =
              (s['instructorName'] ?? '').toString().toLowerCase();
          return name.contains(query) || instructor.contains(query);
        }).toList();
      }
    });
  }

  /// Prisma's Decimal columns can arrive as int, double, or String.
  /// Coerce defensively so every caller sees a consistent [num].
  num _toNum(dynamic v) {
    if (v == null) return 0;
    if (v is num) return v;
    return num.tryParse(v.toString()) ?? 0;
  }

  Future<void> _loadLeaderboard() async {
    setState(() => _isLoading = true);
    try {
      // Ranks are per-course. `termId` absent = the active course, which is
      // what an admin who never touches the selector should see.
      final termId = context.read<TermProvider>().viewedTermIdParam;
      final res = await ApiClient.instance.get(
        '/points/leaderboard',
        queryParameters: {
          'limit': 100,
          if (termId != null) 'termId': termId,
        },
      );
      final data = res.data['data'] as List? ?? [];
      setState(() {
        _students = data.map((e) => Map<String, dynamic>.from(e)).toList();
        _filteredStudents = List.from(_students);
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Leaderboard error: $e');
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFFF5F6FA),
        body: NestedScrollView(
          headerSliverBuilder: (context, _) => [
            SliverAppBar(
              expandedHeight: _students.length >= 3 ? 290 : 100,
              pinned: true,
              backgroundColor: TaqwaColors.domeBlue,
              iconTheme: const IconThemeData(color: Colors.white),
              title: _showSearch
                  ? _buildSearchField()
                  : const Text('ترتيب الطلاب',
                      style:
                          TextStyle(fontFamily: 'Cairo', color: Colors.white)),
              actions: [
                IconButton(
                  icon: Icon(
                    _showSearch ? Icons.close : Icons.search,
                    color: Colors.white,
                  ),
                  onPressed: () {
                    setState(() {
                      _showSearch = !_showSearch;
                      if (!_showSearch) {
                        _searchController.clear();
                      }
                    });
                  },
                ),
                TermSelectorAction(onChanged: _loadLeaderboard),
              ],
              flexibleSpace: _students.length >= 3 && !_showSearch
                  ? FlexibleSpaceBar(
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
                            padding: const EdgeInsets.only(top: 60),
                            child: _buildPodium(),
                          ),
                        ),
                      ),
                    )
                  : null,
            ),
          ],
          body: _isLoading
              ? const Center(
                  child: CircularProgressIndicator(color: TaqwaColors.domeBlue))
              : _students.isEmpty
                  ? const Center(
                      child: Text('لا يوجد طلاب',
                          style: TextStyle(fontFamily: 'Cairo', fontSize: 16)))
                  : Column(
                      children: [
                        const TermContextBanner(
                          margin: EdgeInsets.fromLTRB(16, 12, 16, 0),
                        ),
                        if (_searchController.text.isNotEmpty)
                          Container(
                            padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
                            alignment: Alignment.centerRight,
                            child: Text(
                              'نتائج البحث: ${_filteredStudents.length} طالب',
                              style: TextStyle(
                                  fontFamily: 'Cairo',
                                  fontSize: 13,
                                  color: Colors.grey.shade600),
                            ),
                          ),
                        Expanded(
                          child: RefreshIndicator(
                            color: TaqwaColors.domeBlue,
                            onRefresh: _loadLeaderboard,
                            child: _filteredStudents.isEmpty
                                ? ListView(
                                    children: [
                                      const SizedBox(height: 80),
                                      Center(
                                        child: Column(
                                          children: [
                                            Icon(Icons.search_off_rounded,
                                                size: 56,
                                                color: Colors.grey.shade300),
                                            const SizedBox(height: 12),
                                            const Text(
                                                'لا توجد نتائج مطابقة',
                                                style: TextStyle(
                                                    fontFamily: 'Cairo',
                                                    fontSize: 15,
                                                    color: Colors.grey)),
                                          ],
                                        ),
                                      ),
                                    ],
                                  )
                                : ListView.builder(
                                    padding: const EdgeInsets.all(16),
                                    itemCount: _filteredStudents.length,
                                    itemBuilder: (context, index) {
                                      final student = _filteredStudents[index];
                                      final originalIndex =
                                          _students.indexOf(student);
                                      return _buildStudentRow(
                                          student, originalIndex + 1);
                                    },
                                  ),
                          ),
                        ),
                      ],
                    ),
        ),
      ),
    );
  }

  Widget _buildSearchField() {
    return TextField(
      controller: _searchController,
      autofocus: true,
      textDirection: TextDirection.rtl,
      style: const TextStyle(
          fontFamily: 'Cairo', fontSize: 15, color: Colors.white),
      decoration: InputDecoration(
        hintText: 'ابحث عن طالب...',
        hintStyle: TextStyle(
            fontFamily: 'Cairo',
            fontSize: 14,
            color: Colors.white.withOpacity(0.5)),
        border: InputBorder.none,
        prefixIcon: Icon(Icons.search,
            color: Colors.white.withOpacity(0.5), size: 20),
      ),
      cursorColor: TaqwaColors.minaretGold,
    );
  }

  Widget _buildPodium() {
    if (_students.length < 3) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(child: _buildPodiumItem(_students[1], 2, 90)),
          const SizedBox(width: 8),
          Expanded(child: _buildPodiumItem(_students[0], 1, 120)),
          const SizedBox(width: 8),
          Expanded(child: _buildPodiumItem(_students[2], 3, 70)),
        ],
      ),
    );
  }

  Widget _buildPodiumItem(Map<String, dynamic> student, int rank, double h) {
    final name = student['fullName'] ?? '';
    final points = _toNum(student['totalPoints']);
    final colors = [
      TaqwaColors.minaretGold,
      const Color(0xFFC0C0C0),
      const Color(0xFFCD7F32)
    ];
    final color = colors[rank - 1];
    final medals = ['🥇', '🥈', '🥉'];

    return GestureDetector(
      onTap: () => _navigateToDetail(student),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Text(medals[rank - 1], style: const TextStyle(fontSize: 28)),
          const SizedBox(height: 4),
          Text(name,
              style: const TextStyle(
                  fontFamily: 'Cairo',
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: Colors.white),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis),
          Row(
            mainAxisSize: MainAxisSize.min,
            textDirection: TextDirection.rtl,
            children: [
              PointsDisplay(
                value: points,
                size: PointsDisplaySize.small,
                color: color,
              ),
              const SizedBox(width: 3),
              Text('نقطة',
                  style: TextStyle(
                      fontFamily: 'Cairo',
                      fontSize: 11,
                      color: color,
                      fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 6),
          Container(
            height: h,
            decoration: BoxDecoration(
              color: color.withOpacity(0.25),
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(12)),
            ),
            child: Center(
              child: Text('$rank',
                  style: TextStyle(
                      fontFamily: 'Cairo',
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: color)),
            ),
          ),
        ],
      ),
    );
  }

  void _navigateToDetail(Map<String, dynamic> student) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AdminStudentDetailScreen(
          studentId: student['id'] ?? '',
          studentName: student['fullName'] ?? '',
        ),
      ),
    ).then((_) => _loadLeaderboard());
  }

  Widget _buildStudentRow(Map<String, dynamic> student, int rank) {
    final name = student['fullName'] ?? '';
    final points = _toNum(student['totalPoints']);
    final instructorName = student['instructorName'] ?? '';
    final isTop3 = rank <= 3;
    final rankColors = [
      TaqwaColors.minaretGold,
      const Color(0xFFC0C0C0),
      const Color(0xFFCD7F32)
    ];

    return GestureDetector(
      onTap: () => _navigateToDetail(student),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: isTop3
              ? Border.all(
                  color: rankColors[rank - 1].withOpacity(0.4), width: 1.5)
              : null,
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 8,
                offset: const Offset(0, 2))
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: isTop3
                    ? rankColors[rank - 1].withOpacity(0.15)
                    : TaqwaColors.domeBlue.withOpacity(0.08),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(
                child: Text('$rank',
                    style: TextStyle(
                        fontFamily: 'Cairo',
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: isTop3
                            ? rankColors[rank - 1]
                            : TaqwaColors.domeBlue)),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name,
                      style: const TextStyle(
                          fontFamily: 'Cairo',
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF2C3E50))),
                  if (instructorName.isNotEmpty)
                    Row(
                      children: [
                        Icon(Icons.school,
                            size: 13, color: Colors.grey.shade500),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text('المعلم: $instructorName',
                              style: TextStyle(
                                  fontFamily: 'Cairo',
                                  fontSize: 12,
                                  color: Colors.grey.shade600),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis),
                        ),
                      ],
                    ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: TaqwaColors.minaretGold.withOpacity(0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.star,
                      size: 16, color: TaqwaColors.minaretGold),
                  const SizedBox(width: 4),
                  PointsDisplay(
                    value: points,
                    size: PointsDisplaySize.small,
                    color: TaqwaColors.domeBlue,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 4),
            Icon(Icons.arrow_forward_ios,
                size: 14, color: Colors.grey.shade400),
          ],
        ),
      ),
    );
  }
}