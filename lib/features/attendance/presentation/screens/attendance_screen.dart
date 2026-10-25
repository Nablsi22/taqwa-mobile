import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/theme/taqwa_colors.dart';
import '../../../../core/utils/meeting_days.dart';
import '../../../attendance_stats/presentation/attendance_ui.dart';
import '../../../substitute/presentation/substitute_ui.dart';
import '../../data/models/attendance_sheet_model.dart';
import '../providers/attendance_provider.dart';

class AttendanceScreen extends StatefulWidget {
  /// The same sheet for an instructor's own حلقة and for a حلقة he is
  /// covering: one screen, because recording is the same act and must behave
  /// identically. [substitute] only changes how it looks and what it is
  /// called, so the two can never be confused — see [SubstituteMode].
  ///
  /// The provider decides whose sheet is loaded (its `instructorId`); this
  /// is the matching name and colour.
  const AttendanceScreen({super.key, this.substitute});

  final SubstituteMode? substitute;

  @override
  State<AttendanceScreen> createState() => _AttendanceScreenState();
}

class _AttendanceScreenState extends State<AttendanceScreen> {
  SubstituteMode? get _substitute => widget.substitute;
  bool get _byProxy => _substitute != null;

  /// Navy for your own حلقة, violet when recording for someone else.
  Color get _accent =>
      _byProxy ? SubstituteColors.header : TaqwaColors.domeBlue;

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
      provider.changeDate(isoDay(picked));
    }
  }

  Future<void> _save() async {
    final provider = context.read<AttendanceProvider>();
    final success = await provider.saveAttendance();
    if (!mounted) return;

    if (success) {
      // Absence is never recorded on its own, so say who is still open.
      final left = provider.unmarkedCount;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            left == 0 ? 'تم حفظ الحضور بنجاح' : 'تم الحفظ · بقي ${studentsAr(left)} بلا تسجيل',
            style: const TextStyle(fontFamily: 'Cairo'),
          ),
          backgroundColor: left == 0 ? Colors.green : AttendanceColors.irregular,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            provider.error ?? 'حدث خطأ أثناء الحفظ',
            style: const TextStyle(fontFamily: 'Cairo'),
          ),
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
        backgroundColor:
            _byProxy ? SubstituteColors.surface : const Color(0xFFF5F6FA),
        appBar: AppBar(
          title: Text(
            _byProxy ? 'حضور حلقة أ. ${_substitute!.instructorName}' : 'تسجيل الحضور',
            style: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold),
          ),
          backgroundColor: _accent,
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
              color: _accent,
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Consumer<AttendanceProvider>(
                builder: (context, provider, _) {
                  final note = dayKindNote(provider.dayKind);
                  final sheet = provider.sheet;
                  final unmarked = provider.unmarkedCount;
                  final noneMarked = sheet != null && unmarked == sheet.students.length;
                  return Column(
                    children: [
                      // Whose حلقة this is — said before the date, because it
                      // changes what every tap below means.
                      if (_byProxy) ...[
                        SubstituteBanner(
                          instructorName: _substitute!.instructorName,
                          subtitle: 'الطلاب يبقون في حلقتهم · يُحفظ باسمك كمسجِّل',
                        ),
                        const SizedBox(height: 12),
                      ],
                      // Date selector
                      GestureDetector(
                        onTap: _pickDate,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.calendar_today, color: Colors.white, size: 18),
                              const SizedBox(width: 10),
                              Flexible(
                                child: Text(
                                  _formatDateArabic(provider.selectedDate),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontFamily: 'Cairo',
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Icon(Icons.arrow_drop_down, color: Colors.white.withValues(alpha: 0.7)),
                            ],
                          ),
                        ),
                      ),
                      if (note != null) ...[
                        const SizedBox(height: 10),
                        _DayKindBanner(text: note),
                      ],
                      const SizedBox(height: 12),
                      // Quick mark buttons
                      Row(
                        children: [
                          _QuickButton(
                            label: 'الكل حاضر',
                            color: Colors.green,
                            icon: Icons.check_circle,
                            onTap: () => provider.markAll('PRESENT'),
                          ),
                          const SizedBox(width: 8),
                          _QuickButton(
                            label: 'الكل متأخر',
                            color: Colors.orange,
                            icon: Icons.access_time,
                            onTap: () => provider.markAll('LATE'),
                          ),
                          const SizedBox(width: 8),
                          // Only fills students nobody has marked yet, so the
                          // ones already tapped keep their status.
                          _QuickButton(
                            label: noneMarked ? 'الكل غائب' : 'الباقي غائب',
                            color: Colors.red,
                            icon: Icons.cancel,
                            onTap: unmarked == 0 ? null : () => provider.markRemaining('ABSENT'),
                          ),
                        ],
                      ),
                    ],
                  );
                },
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
                    return Center(
                      child: CircularProgressIndicator(color: _accent),
                    );
                  }

                  if (provider.error != null && provider.sheet == null) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.error_outline, size: 64, color: Colors.red.shade300),
                          const SizedBox(height: 16),
                          Text(
                            provider.error!,
                            style: const TextStyle(fontFamily: 'Cairo', fontSize: 16),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 16),
                          ElevatedButton.icon(
                            onPressed: () => provider.loadSheet(),
                            icon: const Icon(Icons.refresh),
                            label: const Text('إعادة المحاولة', style: TextStyle(fontFamily: 'Cairo')),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _accent,
                              foregroundColor: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    );
                  }

                  if (provider.sheet == null || provider.sheet!.students.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.people_outline, size: 80, color: Colors.grey.shade400),
                          const SizedBox(height: 16),
                          Text(
                            _byProxy
                                ? 'لا يوجد طلاب في هذه الحلقة'
                                : 'لا يوجد طلاب لهذا التاريخ',
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
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
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
    int present = 0, lateCount = 0, absent = 0, excused = 0, unmarked = 0;

    for (final student in sheet.students) {
      final status = provider.getStatus(student.studentId);
      switch (status) {
        case 'PRESENT':
          present++;
          break;
        case 'LATE':
          lateCount++;
          break;
        case 'ABSENT':
          absent++;
          break;
        case 'EXCUSED':
          excused++;
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
          _StatChip(label: 'حاضر', count: present, color: Colors.green),
          _StatChip(label: 'متأخر', count: lateCount, color: Colors.orange),
          _StatChip(label: 'غائب', count: absent, color: Colors.red),
          if (provider.supportsExcused)
            _StatChip(label: 'بعذر', count: excused, color: AttendanceColors.excused),
          _StatChip(label: 'غير محدد', count: unmarked, color: Colors.grey),
        ],
      ),
    );
  }

  Widget _buildStudentCard(
    StudentAttendanceEntry student,
    String? currentStatus,
    AttendanceProvider provider,
  ) {
    // Four buttons need a little less room each to leave the name space.
    final withExcused = provider.supportsExcused;
    final double buttonSize = withExcused ? 34 : 36;
    final double gap = withExcused ? 5 : 6;

    Widget button(String status, IconData icon) {
      return _StatusButton(
        icon: icon,
        color: _statusColor(status),
        isActive: currentStatus == status,
        size: buttonSize,
        onTap: () => _handleStatusTap(student, status, currentStatus, provider),
        tooltip: _statusLabel(status),
      );
    }

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
              radius: withExcused ? 19 : 22,
              backgroundColor: _statusColor(currentStatus).withValues(alpha: 0.15),
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
            SizedBox(width: withExcused ? 10 : 12),

            // Name
            Expanded(
              child: Text(
                student.fullName,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontFamily: 'Cairo',
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  height: 1.4,
                  color: AttendanceColors.ink,
                ),
              ),
            ),

            // Status buttons
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                button('PRESENT', Icons.check_circle),
                SizedBox(width: gap),
                button('LATE', Icons.access_time),
                SizedBox(width: gap),
                button('ABSENT', Icons.cancel),
                if (withExcused) ...[
                  SizedBox(width: gap),
                  button('EXCUSED', Icons.event_busy_rounded),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  // Tapping the active status clears it. An unsaved choice goes quietly;
  // a saved one asks first, because confirming deletes a server record
  // and the points that came with it.
  Future<void> _handleStatusTap(
    StudentAttendanceEntry student,
    String tapped,
    String? current,
    AttendanceProvider provider,
  ) async {
    if (current != tapped) {
      provider.setStatus(student.studentId, tapped);
      return;
    }

    final saved = provider.savedStatusOf(student.studentId);
    if (saved != tapped) {
      provider.clearStatus(student.studentId);
      return;
    }

    final ok = await _confirmUnmark(student, tapped, provider.dayKind);
    if (ok != true || !mounted) return;

    final done = await provider.unmarkSaved(student.studentId);
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          done ? 'تم إلغاء التحديد' : (provider.error ?? 'تعذّر إلغاء التحديد'),
          style: const TextStyle(fontFamily: 'Cairo'),
        ),
        backgroundColor: done ? Colors.green : Colors.red,
      ),
    );
  }

  Future<bool?> _confirmUnmark(
    StudentAttendanceEntry student,
    String status,
    DayKind? dayKind,
  ) {
    final color = _statusColor(status);
    final label = _statusLabel(status);
    final points = _statusPoints(status, dayKind);
    final initial = student.fullName.isNotEmpty ? student.fullName[0] : '?';

    return showDialog<bool>(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: Dialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 22, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: Colors.orange.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.backspace_outlined, size: 24, color: Colors.orange),
                ),
                const SizedBox(height: 14),
                const Text(
                  'إلغاء تحديد الحضور',
                  style: TextStyle(
                    fontFamily: 'Cairo',
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                    color: AttendanceColors.ink,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  points == null
                      ? 'سيُحذف السجل، ويعود الطالب إلى حالة غير محدد'
                      : 'سيُحذف السجل والنقاط المرتبطة به، ويعود الطالب إلى حالة غير محدد',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: 'Cairo',
                    fontSize: 13.5,
                    height: 1.8,
                    color: Colors.grey.shade600,
                  ),
                ),
                const SizedBox(height: 18),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF5F6FA),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 19,
                        backgroundColor: color.withValues(alpha: 0.15),
                        child: Text(
                          initial,
                          style: TextStyle(
                            fontFamily: 'Cairo',
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: color,
                          ),
                        ),
                      ),
                      const SizedBox(width: 11),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              student.fullName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontFamily: 'Cairo',
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: AttendanceColors.ink,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'الحالة المسجّلة حاليًا',
                              style: TextStyle(
                                fontFamily: 'Cairo',
                                fontSize: 11.5,
                                color: Colors.grey.shade500,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              label,
                              style: TextStyle(
                                fontFamily: 'Cairo',
                                fontSize: 12.5,
                                fontWeight: FontWeight.w600,
                                color: color,
                              ),
                            ),
                            if (points != null) ...[
                              const SizedBox(width: 6),
                              Text(
                                points,
                                textDirection: TextDirection.ltr,
                                style: TextStyle(
                                  fontFamily: 'Cairo',
                                  fontSize: 12.5,
                                  color: color.withValues(alpha: 0.75),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                SizedBox(
                  width: double.infinity,
                  height: 44,
                  child: ElevatedButton(
                    onPressed: () => Navigator.of(ctx).pop(true),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFA32D2D),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      'إلغاء التحديد',
                      style: TextStyle(
                        fontFamily: 'Cairo',
                        fontSize: 14.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                SizedBox(
                  width: double.infinity,
                  height: 44,
                  child: TextButton(
                    onPressed: () => Navigator.of(ctx).pop(false),
                    child: Text(
                      'تراجع',
                      style: TextStyle(
                        fontFamily: 'Cairo',
                        fontSize: 14.5,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _statusLabel(String status) => statusStyle(status).label;

  /// Points the saved record carries, or null when it carries none: an
  /// excused absence, or a late / absent mark on a day that deducts nobody.
  String? _statusPoints(String status, DayKind? dayKind) {
    final rewardOnly = dayKind == DayKind.optional || dayKind == DayKind.extra;
    switch (status) {
      case 'PRESENT':
        return '+3';
      case 'LATE':
        return rewardOnly ? null : '-2';
      case 'ABSENT':
        return rewardOnly ? null : '-5';
      default: // EXCUSED
        return null;
    }
  }

  Color _statusColor(String? status) {
    switch (status) {
      case 'PRESENT':
        return Colors.green;
      case 'LATE':
        return Colors.orange;
      case 'ABSENT':
        return Colors.red;
      case 'EXCUSED':
        return AttendanceColors.excused;
      default:
        return _accent;
    }
  }

  /// «السبت 17 أكتوبر 2026 · اليوم»
  String _formatDateArabic(String date) {
    final d = parseIsoDay(date);
    if (d == null) return date;
    final label = '${kWeekdaysAr[d.weekday - 1]} ${d.day} ${kMonthsAr[d.month - 1]} ${d.year}';
    return date == isoDay(DateTime.now()) ? '$label · اليوم' : label;
  }
}

// ── Day-kind notice (optional / make-up day) ──
class _DayKindBanner extends StatelessWidget {
  final String text;

  const _DayKindBanner({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: TaqwaColors.minaretGold.withValues(alpha: 0.22),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: TaqwaColors.minaretGold.withValues(alpha: 0.45)),
      ),
      child: Row(
        children: [
          const Icon(Icons.star_rounded, size: 17, color: Colors.white),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                fontFamily: 'Cairo',
                fontSize: 12.5,
                height: 1.5,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Quick Action Button ──
class _QuickButton extends StatelessWidget {
  final String label;
  final Color color;
  final IconData icon;
  final VoidCallback? onTap;

  const _QuickButton({
    required this.label,
    required this.color,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Opacity(
          opacity: enabled ? 1 : 0.45,
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, color: color, size: 16),
                const SizedBox(width: 4),
                Flexible(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: 'Cairo',
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: color,
                    ),
                  ),
                ),
              ],
            ),
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
  final double size;

  const _StatusButton({
    required this.icon,
    required this.color,
    required this.isActive,
    required this.onTap,
    required this.tooltip,
    this.size = 36,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: isActive ? color.withValues(alpha: 0.15) : Colors.grey.shade100,
            borderRadius: BorderRadius.circular(10),
            border: isActive ? Border.all(color: color, width: 2) : Border.all(color: Colors.grey.shade300),
          ),
          child: Icon(
            icon,
            size: size * 0.56,
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
