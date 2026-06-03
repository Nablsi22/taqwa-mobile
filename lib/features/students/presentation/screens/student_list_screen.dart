import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/theme/taqwa_colors.dart';
import '../../../../core/widgets/points_display.dart';
import '../providers/student_provider.dart';
import 'add_student_screen.dart';
import 'student_detail_screen.dart';

class StudentListScreen extends StatefulWidget {
  const StudentListScreen({super.key});

  @override
  State<StudentListScreen> createState() => _StudentListScreenState();
}

class _StudentListScreenState extends State<StudentListScreen> {
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<StudentProvider>().loadStudents(refresh: true);
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFFF5F7FA),
        appBar: AppBar(
          title: const Text(AppStrings.students),
          backgroundColor: TaqwaColors.domeBlue,
          foregroundColor: Colors.white,
          elevation: 0,
        ),
        body: Column(
          children: [
            // ── Search Bar ────────────────────────────────
            Container(
              color: TaqwaColors.domeBlue,
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: TextField(
                controller: _searchController,
                textDirection: TextDirection.rtl,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: AppStrings.search,
                  hintStyle: TextStyle(color: Colors.white.withOpacity(0.5)),
                  prefixIcon: const Icon(Icons.search, color: Colors.white70),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear, color: Colors.white70),
                          onPressed: () {
                            _searchController.clear();
                            context.read<StudentProvider>().search('');
                          },
                        )
                      : null,
                  filled: true,
                  fillColor: Colors.white.withOpacity(0.12),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                ),
                onChanged: (value) {
                  context.read<StudentProvider>().search(value);
                  setState(() {});
                },
              ),
            ),

            // ── Student Count ─────────────────────────────
            Consumer<StudentProvider>(
              builder: (context, provider, _) {
                return Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Text(
                        '${AppStrings.students} (${provider.totalStudents})',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF0D2137),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),

            // ── Student List ──────────────────────────────
            Expanded(
              child: Consumer<StudentProvider>(
                builder: (context, provider, _) {
                  if (provider.isLoading && provider.students.isEmpty) {
                    return const Center(
                      child: CircularProgressIndicator(
                        color: TaqwaColors.domeBlue,
                      ),
                    );
                  }

                  if (provider.error != null && provider.students.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.error_outline,
                            size: 48,
                            color: Colors.red,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            provider.error!,
                            style: const TextStyle(color: Colors.red),
                          ),
                          const SizedBox(height: 16),
                          ElevatedButton(
                            onPressed: () =>
                                provider.loadStudents(refresh: true),
                            child: const Text(AppStrings.retry),
                          ),
                        ],
                      ),
                    );
                  }

                  if (provider.students.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.people_outline,
                            size: 64,
                            color: Colors.grey.shade400,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            AppStrings.noData,
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                    );
                  }

                  return RefreshIndicator(
                    onRefresh: () => provider.loadStudents(refresh: true),
                    child: ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: provider.students.length,
                      itemBuilder: (context, index) {
                        final student = provider.students[index];
                        return Card(
                          margin: const EdgeInsets.only(bottom: 10),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          elevation: 1,
                          child: ListTile(
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 8,
                            ),
                            leading: CircleAvatar(
                              backgroundColor: TaqwaColors.domeBlue,
                              child: Text(
                                student.fullName.isNotEmpty
                                    ? student.fullName[0]
                                    : '?',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            title: Text(
                              student.fullName,
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 16,
                              ),
                            ),
                            subtitle: student.school != null
                                ? Text(
                                    student.school!,
                                    style: TextStyle(
                                      color: Colors.grey.shade600,
                                      fontSize: 13,
                                    ),
                                  )
                                : null,
                            trailing: _buildPointsBadge(student.totalPoints),
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => ChangeNotifierProvider.value(
                                    value: context.read<StudentProvider>(),
                                    child: StudentDetailScreen(student: student),
                                  ),
                                ),
                              );
                            },
                          ),
                        );
                      },
                    ),
                  );
                },
              ),
            ),
          ],
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () async {
            final result = await Navigator.push<bool>(
              context,
              MaterialPageRoute(
                builder: (_) => ChangeNotifierProvider.value(
                  value: context.read<StudentProvider>(),
                  child: const AddStudentScreen(),
                ),
              ),
            );
            if (result == true && mounted) {
              context.read<StudentProvider>().loadStudents(refresh: true);
            }
          },
          backgroundColor: TaqwaColors.minaretGold,
          foregroundColor: const Color(0xFF0D2137),
          icon: const Icon(Icons.person_add_rounded),
          label: const Text(
            AppStrings.addStudent,
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
        ),
      ),
    );
  }

  /// Gold pill-badge showing the student's current total points.
  ///
  /// Uses [PointsDisplay] to guarantee consistent 2-decimal formatting,
  /// tabular figures (so the badges line up nicely down the list),
  /// and proper LTR direction for the numeric portion inside the RTL layout.
  Widget _buildPointsBadge(num totalPoints) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: TaqwaColors.minaretGold.withOpacity(0.15),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        textDirection: TextDirection.rtl,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          PointsDisplay(
            value: totalPoints,
            size: PointsDisplaySize.small,
            color: TaqwaColors.minaretGold,
          ),
          const SizedBox(width: 4),
          const Text(
            AppStrings.points,
            style: TextStyle(
              color: TaqwaColors.minaretGold,
              fontWeight: FontWeight.bold,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }
}