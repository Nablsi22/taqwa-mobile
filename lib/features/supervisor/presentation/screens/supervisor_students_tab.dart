import 'package:flutter/material.dart';
import '../../../../core/theme/taqwa_colors.dart';
import '../../../attendance_stats/data/attendance_stats_models.dart';
import '../../../attendance_stats/presentation/attendance_ui.dart';
import '../../data/supervisor_api.dart';
import '../supervisor_ui.dart';
import '../../../instructor_home/presentation/screens/instructor_student_detail_screen.dart';
import '../supervisor_navigation.dart';

/// «الطلاب» — every student's standing over the last four weeks.
///
/// Grouped by أستاذ inside each standing, because the أستاذ is the one who
/// acts on it. «بلا جلسات» is said plainly to be the حلقة's doing, not the
/// students': with no recorded session there is nothing to measure them by —
/// which is itself something the director holds the أستاذ to.
class SupervisorStudentsTab extends StatefulWidget {
  const SupervisorStudentsTab({super.key, required this.api});

  final SupervisorApi api;

  @override
  State<SupervisorStudentsTab> createState() => _SupervisorStudentsTabState();
}

class _SupervisorStudentsTabState extends State<SupervisorStudentsTab> {
  bool _loading = true;
  bool _unavailable = false;
  String? _error;
  StudentsStatsResult? _result;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final r = await widget.api.getStudents();
      if (!mounted) return;
      setState(() {
        _result = r;
        _loading = false;
      });
    } on SupervisorUnavailable {
      if (!mounted) return;
      setState(() {
        _unavailable = true;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      color: TaqwaColors.domeBlue,
      onRefresh: _load,
      child: _body(),
    );
  }

  Widget _body() {
    if (_loading && _result == null) {
      return const Center(child: CircularProgressIndicator(color: TaqwaColors.domeBlue));
    }
    if (_unavailable) {
      return const SupervisorState(
        icon: Icons.cloud_off_rounded,
        title: 'لوحة مدير الدورة تظهر بعد تحديث الخادم',
      );
    }
    if (_error != null && _result == null) {
      return SupervisorState(icon: Icons.error_outline_rounded, title: _error!, onRetry: _load);
    }

    final students = _result!.students;
    if (students.isEmpty) {
      return SupervisorState(icon: Icons.school_outlined, title: 'ما في طلاب بالدورة', onRetry: _load);
    }

    int count(AttendanceClass c) => students.where((s) => s.classification == c).length;

    // «ابن فلان» is decided across each whole حلقة, not per section: two
    // «محمد» of one أستاذ, one منقطع and one ثابت, must still be told apart.
    final byHalaqa = <String, List<StudentStats>>{};
    for (final s in students) {
      byHalaqa.putIfAbsent(s.instructorId, () => []).add(s);
    }
    final names = <String, ({String name, String? father})>{
      for (final group in byHalaqa.values)
        ...displayNames(group.map(
          (s) => (id: s.studentId, fullName: s.fullName, fatherName: s.fatherName),
        )),
    };
    final active = count(AttendanceClass.regular) + count(AttendanceClass.irregular);
    final needsCall = students.where((s) => s.needsCall).toList();

    return ListView(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 24),
      children: [
        SoftCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${studentsAr(students.length)} · خارجهم «عزل»',
                style: const TextStyle(
                  fontFamily: 'Cairo',
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: AttendanceColors.ink,
                ),
              ),
              Text(
                'آخر 4 أسابيع · «ثابت» = ما فوّت أكثر من جلسة إلزامية وحدة',
                style: TextStyle(fontFamily: 'Cairo', fontSize: 11.5, color: Colors.grey.shade600, height: 1.7),
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  CountTile(
                    count: count(AttendanceClass.regular),
                    label: 'ثابت',
                    color: AttendanceColors.present,
                  ),
                  CountTile(
                    count: count(AttendanceClass.irregular),
                    label: 'متذبذب',
                    color: AttendanceColors.irregular,
                  ),
                  CountTile(
                    count: count(AttendanceClass.inactive),
                    label: 'منقطع',
                    color: AttendanceColors.absent,
                  ),
                  CountTile(
                    count: count(AttendanceClass.noData),
                    label: 'بلا جلسات',
                    color: AttendanceColors.unmarked,
                  ),
                ],
              ),
              const SizedBox(height: 10),
              QuietNote(
                text: count(AttendanceClass.noData) == 0
                    ? '${studentsAr(active)} نشِط.'
                    : '${studentsAr(active)} نشِط. و${studentsAr(count(AttendanceClass.noData))} '
                        'ما منعرف عنهم شي لأن حلقاتهم ما بتسجّل.',
              ),
            ],
          ),
        ),
        if (needsCall.isNotEmpty) ...[
          SectionTitle('بدّهم اتصال', color: AttendanceColors.absent, count: needsCall.length),
          _ByInstructor(
            students: needsCall,
            names: names,
            color: AttendanceColors.absent,
            showStreak: true,
          ),
        ],
        for (final c in const [
          AttendanceClass.inactive,
          AttendanceClass.irregular,
          AttendanceClass.noData,
          AttendanceClass.regular,
        ])
          if (count(c) > 0) ...[
            SectionTitle(classStyle(c).label, color: classStyle(c).color, count: count(c)),
            _ByInstructor(
              students: students.where((s) => s.classification == c).toList(),
              names: names,
              color: classStyle(c).color,
            ),
          ],
      ],
    );
  }
}

/// Names grouped under their أستاذ: «أ. ياسر (9): كريم · أمجد · …».
class _ByInstructor extends StatelessWidget {
  const _ByInstructor({
    required this.students,
    required this.names,
    required this.color,
    this.showStreak = false,
  });

  final List<StudentStats> students;
  final Map<String, ({String name, String? father})> names;
  final Color color;
  final bool showStreak;

  @override
  Widget build(BuildContext context) {
    final groups = <String, List<StudentStats>>{};
    for (final s in students) {
      groups.putIfAbsent(s.instructorName, () => []).add(s);
    }
    final keys = groups.keys.toList()
      ..sort((a, b) => groups[b]!.length.compareTo(groups[a]!.length));

    return SoftCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var i = 0; i < keys.length; i++) ...[
            if (i > 0) const Divider(height: 18, color: TaqwaColors.dividerColor),
            _Group(
              instructor: keys[i],
              students: groups[keys[i]]!,
              names: names,
              color: color,
              showStreak: showStreak,
            ),
          ],
        ],
      ),
    );
  }
}

class _Group extends StatelessWidget {
  const _Group({
    required this.instructor,
    required this.students,
    required this.names,
    required this.color,
    required this.showStreak,
  });

  final String instructor;
  final List<StudentStats> students;
  final Map<String, ({String name, String? father})> names;
  final Color color;
  final bool showStreak;

  @override
  Widget build(BuildContext context) {
    String label(StudentStats s) {
      final n = names[s.studentId];
      final base = n == null ? s.fullName : (n.father == null ? n.name : '${n.name} (${n.father})');
      return showStreak && s.absentStreak >= 2 ? '$base (${consecutiveAr(s.absentStreak)})' : base;
    }

    // Each name opens that student's page (read-only) on his attendance.
    return Text.rich(
      TextSpan(
        children: [
          TextSpan(
            text: 'أ. $instructor (${students.length}): ',
            style: TextStyle(fontWeight: FontWeight.bold, color: color),
          ),
          for (var i = 0; i < students.length; i++) ...[
            if (i > 0) const TextSpan(text: ' · ', style: TextStyle(color: AttendanceColors.ink)),
            WidgetSpan(
              alignment: PlaceholderAlignment.baseline,
              baseline: TextBaseline.alphabetic,
              child: GestureDetector(
                onTap: () => openStudentPage(
                  context,
                  studentId: students[i].studentId,
                  name: students[i].fullName,
                  tab: InstructorStudentDetailScreen.attendanceTab,
                ),
                child: Text(
                  label(students[i]),
                  style: const TextStyle(
                    fontFamily: 'Cairo',
                    fontSize: 12.5,
                    height: 1.9,
                    color: AttendanceColors.ink,
                    decoration: TextDecoration.underline,
                    decorationColor: Color(0x33000000),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
      style: const TextStyle(fontFamily: 'Cairo', fontSize: 12.5, height: 1.9),
    );
  }
}
