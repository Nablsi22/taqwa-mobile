import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/theme/taqwa_colors.dart';
import '../../data/models/attendance_sheet_model.dart';
import '../providers/attendance_provider.dart';

class AttendanceScreen extends StatefulWidget {
  const AttendanceScreen({super.key});

  @override
  State<AttendanceScreen> createState() => _AttendanceScreenState();
}

class _AttendanceScreenState extends State<AttendanceScreen> {
 @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = context.read<AttendanceProvider>();
      if (provider.sheet == null) {
        provider.loadSheet();
      }
    });
  }
  
  Future<void> _pickDate() async {
    final provider = context.read<AttendanceProvider>();
    final parts = provider.selectedDate.split('-');
    final current = DateTime(
      int.parse(parts[0]),
      int.parse(parts[1]),
      int.parse(parts[2]),
    );

    final picked = await showDatePicker(
      context: context,
      initialDate: current,
      firstDate: DateTime(2024),
      lastDate: DateTime.now(),
      helpText: 'اختر التاريخ',
      cancelText: 'إلغاء',
      confirmText: 'تأكيد',
    );

    if (picked != null) {
      final formatted =
          '${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}';
      provider.changeDate(formatted);
    }
  }

  Future<void> _save() async {
    final provider = context.read<AttendanceProvider>();
    final success = await provider.saveAttendance();
    if (!mounted) return;

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تم حفظ الحضور بنجاح'),
          backgroundColor: Colors.green,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(provider.error ?? 'حدث خطأ أثناء الحفظ'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFFF5F6FA),
        appBar: AppBar(
          title: const Text(
            'تسجيل الحضور',
            style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold),
          ),
          backgroundColor: TaqwaColors.domeBlue,
          foregroundColor: Colors.white,
          elevation: 0,
          actions: [
            Consumer<AttendanceProvider>(
              builder: (context, provider, _) {
                if (provider.isSaving) {
                  return const Padding(
                    padding: EdgeInsets.all(16),
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    ),
                  );
                }
                return IconButton(
                  icon: const Icon(Icons.save),
                  tooltip: 'حفظ الحضور',
                  onPressed: provider.hasUnsavedChanges ? _save : null,
                );
              },
            ),
          ],
        ),
        body: Column(
          children: [
            // Date picker + Quick actions bar
            Container(
              color: TaqwaColors.domeBlue,
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Column(
                children: [
                  // Date selector
                  Consumer<AttendanceProvider>(
                    builder: (context, provider, _) {
                      return GestureDetector(
                        onTap: _pickDate,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 12),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.calendar_today,
                                  color: Colors.white, size: 18),
                              const SizedBox(width: 10),
                              Text(
                                _formatDateArabic(provider.selectedDate),
                                style: const TextStyle(
                                  fontFamily: 'Cairo',
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Icon(Icons.arrow_drop_down,
                                  color: Colors.white.withOpacity(0.7)),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 12),
                  // Quick mark all buttons
                  Row(
                    children: [
                      _QuickButton(
                        label: 'الكل حاضر',
                        color: Colors.green,
                        icon: Icons.check_circle,
                        onTap: () => context
                            .read<AttendanceProvider>()
                            .markAll('PRESENT'),
                      ),
                      const SizedBox(width: 8),
                      _QuickButton(
                        label: 'الكل متأخر',
                        color: Colors.orange,
                        icon: Icons.access_time,
                        onTap: () => context
                            .read<AttendanceProvider>()
                            .markAll('LATE'),
                      ),
                      const SizedBox(width: 8),
                      _QuickButton(
                        label: 'الكل غائب',
                        color: Colors.red,
                        icon: Icons.cancel,
                        onTap: () => context
                            .read<AttendanceProvider>()
                            .markAll('ABSENT'),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Stats bar
            Consumer<AttendanceProvider>(
              builder: (context, provider, _) {
                if (provider.sheet == null) return const SizedBox();
                return _buildStatsBar(provider);
              },
            ),

            // Student list
            Expanded(
              child: Consumer<AttendanceProvider>(
                builder: (context, provider, _) {
                  if (provider.isLoading) {
                    return const Center(
                      child: CircularProgressIndicator(
                          color: TaqwaColors.domeBlue),
                    );
                  }

                  if (provider.error != null && provider.sheet == null) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.error_outline,
                              size: 64, color: Colors.red.shade300),
                          const SizedBox(height: 16),
                          Text(
                            provider.error!,
                            style: const TextStyle(
                                fontFamily: 'Cairo', fontSize: 16),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 16),
                          ElevatedButton.icon(
                            onPressed: () => provider.loadSheet(),
                            icon: const Icon(Icons.refresh),
                            label: const Text('إعادة المحاولة',
                                style: TextStyle(fontFamily: 'Cairo')),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: TaqwaColors.domeBlue,
                              foregroundColor: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    );
                  }

                  if (provider.sheet == null ||
                      provider.sheet!.students.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.people_outline,
                              size: 80, color: Colors.grey.shade400),
                          const SizedBox(height: 16),
                          Text(
                            'لا يوجد طلاب لهذا التاريخ',
                            style: TextStyle(
                              fontFamily: 'Cairo',
                              fontSize: 18,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                    );
                  }

                  return ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
                    itemCount: provider.sheet!.students.length,
                    itemBuilder: (context, index) {
                      final student = provider.sheet!.students[index];
                      final currentStatus = provider.getStatus(student.studentId);
                      return _buildStudentCard(student, currentStatus, provider);
                    },
                  );
                },
              ),
            ),
          ],
        ),

        // Save FAB
        floatingActionButton: Consumer<AttendanceProvider>(
          builder: (context, provider, _) {
            if (!provider.hasUnsavedChanges) return const SizedBox();
            return FloatingActionButton.extended(
              onPressed: provider.isSaving ? null : _save,
              backgroundColor: TaqwaColors.islamicGreen,
              icon: provider.isSaving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2),
                    )
                  : const Icon(Icons.save, color: Colors.white),
              label: Text(
                provider.isSaving ? 'جاري الحفظ...' : 'حفظ الحضور',
                style: const TextStyle(
                  fontFamily: 'Cairo',
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildStatsBar(AttendanceProvider provider) {
    final sheet = provider.sheet!;
    int present = 0, late = 0, absent = 0, unmarked = 0;

    for (final student in sheet.students) {
      final status = provider.getStatus(student.studentId);
      switch (status) {
        case 'PRESENT':
          present++;
          break;
        case 'LATE':
          late++;
          break;
        case 'ABSENT':
          absent++;
          break;
        default:
          unmarked++;
      }
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      color: Colors.white,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _StatChip(
              label: 'حاضر', count: present, color: Colors.green),
          _StatChip(
              label: 'متأخر', count: late, color: Colors.orange),
          _StatChip(
              label: 'غائب', count: absent, color: Colors.red),
          _StatChip(
              label: 'غير محدد', count: unmarked, color: Colors.grey),
        ],
      ),
    );
  }

  Widget _buildStudentCard(
    StudentAttendanceEntry student,
    String? currentStatus,
    AttendanceProvider provider,
  ) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      elevation: 2,
      shadowColor: Colors.black12,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            // Avatar
            CircleAvatar(
              radius: 22,
              backgroundColor: _statusColor(currentStatus).withOpacity(0.15),
              child: Text(
                student.fullName.isNotEmpty ? student.fullName[0] : '?',
                style: TextStyle(
                  fontFamily: 'Cairo',
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: _statusColor(currentStatus),
                ),
              ),
            ),
            const SizedBox(width: 12),

            // Name
            Expanded(
              child: Text(
                student.fullName,
                style: const TextStyle(
                  fontFamily: 'Cairo',
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF1A1A2E),
                ),
              ),
            ),

            // Status buttons
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _StatusButton(
                  icon: Icons.check_circle,
                  color: Colors.green,
                  isActive: currentStatus == 'PRESENT',
                  onTap: () =>
                      provider.setStatus(student.studentId, 'PRESENT'),
                  tooltip: 'حاضر',
                ),
                const SizedBox(width: 6),
                _StatusButton(
                  icon: Icons.access_time,
                  color: Colors.orange,
                  isActive: currentStatus == 'LATE',
                  onTap: () =>
                      provider.setStatus(student.studentId, 'LATE'),
                  tooltip: 'متأخر',
                ),
                const SizedBox(width: 6),
                _StatusButton(
                  icon: Icons.cancel,
                  color: Colors.red,
                  isActive: currentStatus == 'ABSENT',
                  onTap: () =>
                      provider.setStatus(student.studentId, 'ABSENT'),
                  tooltip: 'غائب',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Color _statusColor(String? status) {
    switch (status) {
      case 'PRESENT':
        return Colors.green;
      case 'LATE':
        return Colors.orange;
      case 'ABSENT':
        return Colors.red;
      default:
        return TaqwaColors.domeBlue;
    }
  }

  String _formatDateArabic(String date) {
    try {
      final parts = date.split('-');
      final months = [
        '', 'يناير', 'فبراير', 'مارس', 'أبريل', 'مايو', 'يونيو',
        'يوليو', 'أغسطس', 'سبتمبر', 'أكتوبر', 'نوفمبر', 'ديسمبر'
      ];
      final day = int.parse(parts[2]);
      final month = months[int.parse(parts[1])];
      final year = parts[0];
      return '$day $month $year';
    } catch (_) {
      return date;
    }
  }
}

// ── Quick Action Button ──
class _QuickButton extends StatelessWidget {
  final String label;
  final Color color;
  final IconData icon;
  final VoidCallback onTap;

  const _QuickButton({
    required this.label,
    required this.color,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.2),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: color, size: 16),
              const SizedBox(width: 4),
              Text(
                label,
                style: TextStyle(
                  fontFamily: 'Cairo',
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Status Toggle Button ──
class _StatusButton extends StatelessWidget {
  final IconData icon;
  final Color color;
  final bool isActive;
  final VoidCallback onTap;
  final String tooltip;

  const _StatusButton({
    required this.icon,
    required this.color,
    required this.isActive,
    required this.onTap,
    required this.tooltip,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: isActive ? color.withOpacity(0.15) : Colors.grey.shade100,
            borderRadius: BorderRadius.circular(10),
            border: isActive
                ? Border.all(color: color, width: 2)
                : Border.all(color: Colors.grey.shade300),
          ),
          child: Icon(
            icon,
            size: 20,
            color: isActive ? color : Colors.grey.shade400,
          ),
        ),
      ),
    );
  }
}

// ── Stat Chip ──
class _StatChip extends StatelessWidget {
  final String label;
  final int count;
  final Color color;

  const _StatChip({
    required this.label,
    required this.count,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          '$count',
          style: TextStyle(
            fontFamily: 'Cairo',
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontFamily: 'Cairo',
            fontSize: 11,
            color: color,
          ),
        ),
      ],
    );
  }
}