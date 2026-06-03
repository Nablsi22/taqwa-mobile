import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/theme/taqwa_colors.dart';
import '../../data/models/student_model.dart';
import '../providers/student_provider.dart';
import 'add_student_screen.dart';
import 'package:taqwa_mobile/core/widgets/points_display.dart';

class StudentDetailScreen extends StatelessWidget {
  final StudentModel student;

  const StudentDetailScreen({super.key, required this.student});

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFFF5F7FA),
        body: CustomScrollView(
          slivers: [
            // ── Header ────────────────────────────────────
            SliverAppBar(
              expandedHeight: 200,
              pinned: true,
              backgroundColor: TaqwaColors.domeBlue,
              foregroundColor: Colors.white,
              flexibleSpace: FlexibleSpaceBar(
                background: Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        TaqwaColors.domeBlue,
                        Color(0xFF0D2137),
                      ],
                    ),
                  ),
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const SizedBox(height: 40),
                        CircleAvatar(
                          radius: 36,
                          backgroundColor: TaqwaColors.minaretGold,
                          child: Text(
                            student.fullName.isNotEmpty
                                ? student.fullName[0]
                                : '?',
                            style: const TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF0D2137),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          student.fullName,
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        if (student.school != null)
                          Text(
                            student.school!,
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.white.withOpacity(0.7),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
              actions: [
                IconButton(
                  icon: const Icon(Icons.edit_outlined),
                  tooltip: AppStrings.edit,
                  onPressed: () async {
                    final result = await Navigator.push<bool>(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ChangeNotifierProvider.value(
                          value: context.read<StudentProvider>(),
                          child: AddStudentScreen(student: student),
                        ),
                      ),
                    );
                    if (result == true && context.mounted) {
                      Navigator.pop(context, true);
                    }
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline),
                  tooltip: AppStrings.delete,
                  onPressed: () => _confirmDelete(context),
                ),
              ],
            ),

            // ── Stats Row ─────────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    _buildPointsStatCard(
                      points: student.totalPoints,
                      label: AppStrings.points,
                    ),
                    const SizedBox(width: 12),
                    _buildStatCard(
                      icon: Icons.check_circle_outline,
                      value: '${student.attendanceCount}',
                      label: AppStrings.attendance,
                      color: Colors.green,
                    ),
                  ],
                ),
              ),
            ),

            // ── Info Card ─────────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.04),
                        blurRadius: 10,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'المعلومات الشخصية',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF0D2137),
                        ),
                      ),
                      const SizedBox(height: 16),
                      _buildInfoRow(
                        Icons.person_outline,
                        AppStrings.fatherName,
                        student.fatherName,
                      ),
                      _buildInfoRow(
                        Icons.cake_outlined,
                        AppStrings.dateOfBirth,
                        '${student.dateOfBirth.year}/${student.dateOfBirth.month}/${student.dateOfBirth.day}',
                      ),
                      if (student.phone1 != null)
                        _buildInfoRow(
                          Icons.phone_outlined,
                          AppStrings.phoneStudent,
                          student.phone1!,
                        ),
                      if (student.phone2 != null)
                        _buildInfoRow(
                          Icons.phone_outlined,
                          AppStrings.phoneParent,
                          student.phone2!,
                        ),
                      if (student.address != null)
                        _buildInfoRow(
                          Icons.home_outlined,
                          AppStrings.homeAddress,
                          student.address!,
                        ),
                    ],
                  ),
                ),
              ),
            ),

            const SliverToBoxAdapter(child: SizedBox(height: 24)),
          ],
        ),
      ),
    );
  }

  /// Specialized stat card for point values.
  ///
  /// Delegates number rendering to [PointsDisplay] so we get
  /// consistent 2-decimal formatting, tabular figures, and proper
  /// LTR numeric direction inside the RTL layout. The gold brand
  /// color is passed explicitly via `color:`.
  Widget _buildPointsStatCard({
    required num points,
    required String label,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          children: [
            const Icon(
              Icons.stars_rounded,
              color: TaqwaColors.minaretGold,
              size: 28,
            ),
            const SizedBox(height: 8),
            PointsDisplay(
              value: points,
              size: PointsDisplaySize.large,
              color: TaqwaColors.minaretGold,
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey.shade600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard({
    required IconData icon,
    required String value,
    required String label,
    required Color color,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(height: 8),
            Text(
              value,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey.shade600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        children: [
          Icon(icon, size: 20, color: TaqwaColors.gray),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
              ),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _confirmDelete(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: const Text(AppStrings.delete),
          content: Text('هل تريد حذف ${student.fullName}؟'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text(AppStrings.cancel),
            ),
            TextButton(
              onPressed: () async {
                Navigator.pop(ctx);
                final success = await context
                    .read<StudentProvider>()
                    .deleteStudent(student.id);
                if (success && context.mounted) {
                  Navigator.pop(context, true);
                }
              },
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: const Text(AppStrings.delete),
            ),
          ],
        ),
      ),
    );
  }
}