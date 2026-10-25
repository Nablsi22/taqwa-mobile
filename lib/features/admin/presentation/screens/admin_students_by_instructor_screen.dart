import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/theme/taqwa_colors.dart';
import '../../../../core/network/api_client.dart';
import '../../../terms/presentation/providers/term_provider.dart';
import '../../../terms/presentation/widgets/term_selector.dart';
import 'admin_student_detail_screen.dart';

class AdminStudentsByInstructorScreen extends StatefulWidget {
  const AdminStudentsByInstructorScreen({super.key});

  @override
  State<AdminStudentsByInstructorScreen> createState() =>
      _AdminStudentsByInstructorScreenState();
}

class _AdminStudentsByInstructorScreenState
    extends State<AdminStudentsByInstructorScreen> {
  List<Map<String, dynamic>> _instructors = [];
  bool _isLoading = true;
  String? _selectedInstructorId;
  String? _selectedInstructorName;
  List<Map<String, dynamic>> _students = [];
  bool _isLoadingStudents = false;

  @override
  void initState() {
    super.initState();
    _loadInstructors();
  }

  Future<void> _loadInstructors() async {
    setState(() => _isLoading = true);
    try {
      final res = await ApiClient.instance.get('/instructors');
      final data = res.data['data'] as List? ?? res.data as List? ?? [];
      setState(() {
        _instructors = data.map((e) => Map<String, dynamic>.from(e)).toList();
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _loadStudents(String instructorId) async {
    setState(() => _isLoadingStudents = true);
    try {
      // ═══ SINGLE API CALL — backend already returns totalPoints ═══
      // Course-scoped: totalPoints here is this حلقة's standing in the
      // selected course, not a running lifetime total.
      final termId = context.read<TermProvider>().viewedTermIdParam;
      final res = await ApiClient.instance.get(
        '/students',
        queryParameters: {
          'instructorId': instructorId,
          if (termId != null) 'termId': termId,
        },
      );
      final data = res.data['data'] as List? ?? res.data as List? ?? [];
      setState(() {
        _students = data.map((e) => Map<String, dynamic>.from(e)).toList();
        _isLoadingStudents = false;
      });
    } catch (e) {
      setState(() => _isLoadingStudents = false);
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
          title: Text(
            _selectedInstructorName ?? 'الطلاب حسب المعلم',
            style: const TextStyle(fontFamily: 'Cairo', color: Colors.white),
          ),
          iconTheme: const IconThemeData(color: Colors.white),
          actions: [
            TermSelectorAction(onChanged: () {
              final id = _selectedInstructorId;
              if (id != null) _loadStudents(id);
            }),
          ],
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () {
              if (_selectedInstructorId != null) {
                setState(() {
                  _selectedInstructorId = null;
                  _selectedInstructorName = null;
                  _students = [];
                });
              } else {
                Navigator.pop(context);
              }
            },
          ),
        ),
        body: _isLoading
            ? const Center(
                child:
                    CircularProgressIndicator(color: TaqwaColors.domeBlue))
            : _selectedInstructorId == null
                ? _buildInstructorsList()
                : _buildStudentsList(),
      ),
    );
  }

  Widget _buildInstructorsList() {
    if (_instructors.isEmpty) {
      return const Center(
        child: Text('لا يوجد معلمون',
            style: TextStyle(fontFamily: 'Cairo', fontSize: 16)),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _instructors.length,
      itemBuilder: (context, index) {
        final inst = _instructors[index];
        final name = inst['fullName'] ?? '';
        final studentCount =
            inst['studentCount'] ?? inst['_count']?['students'] ?? 0;

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: TaqwaColors.domeBlue.withOpacity(0.08),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: () {
                setState(() {
                  _selectedInstructorId = inst['id'];
                  _selectedInstructorName = 'طلاب: $name';
                });
                _loadStudents(inst['id']);
              },
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            TaqwaColors.domeBlue,
                            TaqwaColors.domeBlue.withOpacity(0.7),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Icon(Icons.school,
                          color: Colors.white, size: 28),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(name,
                              style: const TextStyle(
                                  fontFamily: 'Cairo',
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF2C3E50))),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Icon(Icons.people,
                                  size: 16, color: Colors.grey.shade500),
                              const SizedBox(width: 4),
                              Text('$studentCount طالب',
                                  style: TextStyle(
                                      fontFamily: 'Cairo',
                                      fontSize: 13,
                                      color: Colors.grey.shade600)),
                            ],
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: TaqwaColors.domeBlue.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.arrow_forward_ios,
                          size: 16, color: TaqwaColors.domeBlue),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildStudentsList() {
    if (_isLoadingStudents) {
      return const Center(
        child: CircularProgressIndicator(color: TaqwaColors.domeBlue),
      );
    }

    if (_students.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.people_outline, size: 64, color: Colors.grey),
            SizedBox(height: 12),
            Text('لا يوجد طلاب لهذا المعلم',
                style: TextStyle(fontFamily: 'Cairo', fontSize: 16)),
          ],
        ),
      );
    }

    return RefreshIndicator(
      color: TaqwaColors.domeBlue,
      onRefresh: () => _loadStudents(_selectedInstructorId!),
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _students.length,
        itemBuilder: (context, index) => _buildStudentCard(_students[index]),
      ),
    );
  }

  Widget _buildStudentCard(Map<String, dynamic> student) {
    final name = student['fullName'] ?? '';
    final totalPoints = student['totalPoints'] ?? 0;
    final attendanceCount = student['_count']?['attendance'] ?? student['attendanceCount'] ?? 0;
    final pointsLogCount = student['_count']?['pointsLog'] ?? student['pointsLogCount'] ?? 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => AdminStudentDetailScreen(
                studentId: student['id'],
                studentName: name,
              ),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: TaqwaColors.skyBlue.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Center(
                        child: Text(
                          name.isNotEmpty ? name[0] : '?',
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
                      child: Text(name,
                          style: const TextStyle(
                              fontFamily: 'Cairo',
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF2C3E50))),
                    ),
                    Icon(Icons.arrow_forward_ios,
                        size: 14, color: Colors.grey.shade400),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    _buildMiniStat(Icons.star, '$totalPoints', 'نقطة',
                        TaqwaColors.minaretGold),
                    _buildMiniStat(Icons.check_circle, '$attendanceCount',
                        'حضور', TaqwaColors.islamicGreen),
                    _buildMiniStat(Icons.menu_book, '$pointsLogCount',
                        'سجل نقاط', TaqwaColors.skyBlue),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMiniStat(
      IconData icon, String value, String label, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        margin: const EdgeInsets.symmetric(horizontal: 3),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(height: 2),
            Text(value,
                style: TextStyle(
                    fontFamily: 'Cairo',
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: color)),
            Text(label,
                style: TextStyle(
                    fontFamily: 'Cairo',
                    fontSize: 10,
                    color: color.withOpacity(0.7))),
          ],
        ),
      ),
    );
  }
}
