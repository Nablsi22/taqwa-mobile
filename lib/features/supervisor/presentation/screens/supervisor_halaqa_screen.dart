import 'package:flutter/material.dart';
import '../../../../core/theme/taqwa_colors.dart';
import '../../../../core/utils/meeting_days.dart';
import '../../../attendance_stats/data/attendance_stats_models.dart';
import '../../../attendance_stats/presentation/attendance_ui.dart';
import '../../../instructor_home/presentation/screens/instructor_student_detail_screen.dart';
import '../../data/supervisor_models.dart';
import '../supervisor_navigation.dart';
import '../supervisor_ui.dart';

/// One حلقة on one day: every student by name with his status, and who
/// recorded it and when. Each name opens that student's page (read-only),
/// on his attendance calendar.
///
/// Names are the students' own; «ابن فلان» appears only under two students
/// of this حلقة who share a name.
///
/// Built from the day already loaded, so opening it costs no request.
class SupervisorHalaqaScreen extends StatelessWidget {
  const SupervisorHalaqaScreen({
    super.key,
    required this.halaqa,
    required this.date,
    required this.kind,
  });

  final SupervisedHalaqa halaqa;
  final String date;
  final DayKind? kind;

  bool get _optional => kind == DayKind.optional || kind == DayKind.extra;

  /// Absent first — they are why the director opens this — then late,
  /// excused, present, unmarked. Names alphabetical within each.
  static const _order = ['ABSENT', 'LATE', 'EXCUSED', 'PRESENT', 'UNMARKED'];

  @override
  Widget build(BuildContext context) {
    final h = halaqa;
    final names = displayNames(h.roster.map(
      (r) => (id: r.studentId, fullName: r.fullName, fatherName: r.fatherName),
    ));
    final roster = [...h.roster]
      ..sort((a, b) {
        final byStatus = _order.indexOf(a.status).compareTo(_order.indexOf(b.status));
        return byStatus != 0 ? byStatus : a.fullName.compareTo(b.fullName);
      });
    // On an optional day nobody is absent: list only who came.
    final shown = _optional
        ? roster.where((r) => r.status == 'PRESENT' || r.status == 'LATE').toList()
        : roster;

    final who = h.byOther
        ? 'سجّلها أ. ${h.markedByName ?? 'نائب'} بالنيابة'
        : 'سجّلها أ. ${h.instructorName}';
    final lag = h.lagDays ?? 0;
    final when = recordedWhen(h.recordedAt, date);

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: TaqwaColors.background,
        appBar: AppBar(
          title: Text(
            'حلقة أ. ${h.instructorName}',
            style: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold),
          ),
          backgroundColor: TaqwaColors.domeBlue,
          foregroundColor: Colors.white,
          elevation: 0,
        ),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 24),
          children: [
            SoftCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${dayLabel(date)} · ${_optional ? 'يوم اختياري' : 'يوم إلزامي'}',
                    style: const TextStyle(
                      fontFamily: 'Cairo',
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: AttendanceColors.ink,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    [
                      studentsAr(h.students),
                      'حضر ${h.present}',
                      if (h.lateCount > 0) 'تأخّر ${h.lateCount}',
                      if (!_optional && h.absent > 0) 'غاب ${h.absent}',
                      if (!_optional && h.excused > 0) 'بعذر ${h.excused}',
                    ].join(' · '),
                    style: TextStyle(fontFamily: 'Cairo', fontSize: 12, color: Colors.grey.shade700),
                  ),
                  const SizedBox(height: 10),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 9),
                    decoration: BoxDecoration(
                      color: h.byOther
                          ? DisciplineColors.covered.withValues(alpha: 0.08)
                          : TaqwaColors.background,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      lag > 0 && !h.byOther
                          ? '$who · ${lagLabel(lag)} · $when'
                          : '$who · $when',
                      style: TextStyle(
                        fontFamily: 'Cairo',
                        fontSize: 11.5,
                        height: 1.6,
                        color: h.byOther
                            ? DisciplineColors.covered
                            : lag > 0
                                ? DisciplineColors.veryLate
                                : Colors.grey.shade700,
                        fontWeight: h.byOther || lag > 0 ? FontWeight.w600 : FontWeight.normal,
                      ),
                    ),
                  ),
                  if (_optional) ...[
                    const SizedBox(height: 10),
                    const QuietNote(
                      icon: Icons.star_rounded,
                      text: 'يوم اختياري: منعرض اللي حضروا بس.',
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 12),
            SoftCard(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
              child: shown.isEmpty
                  ? const Padding(
                      padding: EdgeInsets.symmetric(vertical: 14),
                      child: QuietNote(text: 'ما حضر حدا'),
                    )
                  : Column(
                      children: [
                        for (var i = 0; i < shown.length; i++)
                          _Person(
                            entry: shown[i],
                            name: names[shown[i].studentId]?.name ?? shown[i].fullName,
                            father: names[shown[i].studentId]?.father,
                            last: i == shown.length - 1,
                            onTap: () => openStudentPage(
                              context,
                              studentId: shown[i].studentId,
                              name: shown[i].fullName,
                              tab: InstructorStudentDetailScreen.attendanceTab,
                            ),
                          ),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Person extends StatelessWidget {
  const _Person({
    required this.entry,
    required this.name,
    required this.father,
    required this.last,
    required this.onTap,
  });

  final RosterEntry entry;
  final String name;
  final String? father;
  final bool last;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final status = entry.status;
    final style = statusStyle(status);
    final streak = entry.absentStreak;
    final absences = entry.absences;

    String? note;
    var alarm = false;
    if (status == 'ABSENT' && streak >= 2) {
      note = 'غاب ${consecutiveAr(streak)}';
      alarm = true;
    } else if (status == 'ABSENT' && absences > 1) {
      note = 'غاب ${timesAr(absences)} بالدورة';
    } else if (status == 'EXCUSED') {
      note = 'بعذر · ما ينخصم منه';
    }
    final sub = [?father, ?note].join(' · ');

    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          border: last ? null : const Border(bottom: BorderSide(color: TaqwaColors.dividerColor)),
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 15,
              backgroundColor: style.color.withValues(alpha: 0.13),
              child: Text(
                name.isNotEmpty ? name.characters.first : '؟',
                style: TextStyle(
                  fontFamily: 'Cairo',
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: style.color,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: const TextStyle(
                      fontFamily: 'Cairo',
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: AttendanceColors.ink,
                    ),
                  ),
                  if (sub.isNotEmpty)
                    Text(
                      sub,
                      style: TextStyle(
                        fontFamily: 'Cairo',
                        fontSize: 11,
                        color: alarm ? AttendanceColors.absent : Colors.grey.shade600,
                        fontWeight: alarm ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                ],
              ),
            ),
            StatusPill(status, dense: true),
            const SizedBox(width: 4),
            Icon(Icons.chevron_left_rounded, size: 18, color: Colors.grey.shade400),
          ],
        ),
      ),
    );
  }
}
