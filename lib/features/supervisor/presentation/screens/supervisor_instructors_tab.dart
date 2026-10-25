import 'package:flutter/material.dart';
import '../../../../core/theme/taqwa_colors.dart';
import '../../../attendance_stats/presentation/attendance_ui.dart';
import '../../data/supervisor_api.dart';
import '../../data/supervisor_models.dart';
import '../supervisor_ui.dart';
import '../help/supervisor_help.dart';
import 'supervisor_instructor_screen.dart';

/// «الأساتذة» — the screen the director opens on.
///
/// Every حلقة with its last four required sessions as a strip of coloured
/// boxes, in the order the server sends: worst first. The order IS the
/// oversight — whoever needs following up is at the top, and the director
/// never sorts, filters or searches. The disciplined ones are still listed,
/// at the bottom, because recognising them is part of holding the others to
/// account.
class SupervisorInstructorsTab extends StatefulWidget {
  const SupervisorInstructorsTab({super.key, required this.api});

  final SupervisorApi api;

  @override
  State<SupervisorInstructorsTab> createState() => _SupervisorInstructorsTabState();
}

class _SupervisorInstructorsTabState extends State<SupervisorInstructorsTab> {
  bool _loading = true;
  bool _unavailable = false;
  String? _error;
  DisciplineResult? _result;

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
      final res = await widget.api.getInstructors();
      if (!mounted) return;
      setState(() {
        _result = res;
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

  void _open(InstructorDiscipline d) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => SupervisorInstructorScreen(
          api: widget.api,
          instructorId: d.instructorId,
          instructorName: d.instructorName,
          studentsCount: d.students,
        ),
      ),
    );
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
        subtitle: 'التطبيق جاهز، ولم يُحدَّث الخادم بعد.',
      );
    }
    if (_error != null && _result == null) {
      return SupervisorState(
        icon: Icons.error_outline_rounded,
        title: _error!,
        onRetry: _load,
      );
    }

    final r = _result!;
    if (r.instructors.isEmpty) {
      return SupervisorState(
        icon: Icons.groups_2_outlined,
        title: r.days.isEmpty ? 'لا توجد جلسات إلزامية في الدورة حتى الآن' : 'لا توجد حلقات فيها طلاب',
        subtitle: r.course?.nameAr,
        onRetry: _load,
      );
    }

    final bad = r.instructors.where((d) => d.level == DisciplineLevel.bad).toList();
    final slipping = r.instructors.where((d) => d.level == DisciplineLevel.slipping).toList();
    final good = r.instructors.where((d) => d.level == DisciplineLevel.good).toList();

    return ListView(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 24),
      children: [
        _Header(result: r),
        if (bad.isNotEmpty) ...[
          SectionTitle('يحتاجون إلى متابعة', color: DisciplineColors.missed, count: bad.length, help: HelpTopic.needFollowUp),
          for (final d in bad) _InstructorCard(d: d, onTap: () => _open(d)),
        ],
        if (slipping.isNotEmpty) ...[
          SectionTitle('يتأخرون أحياناً', color: DisciplineColors.dayLate, count: slipping.length, help: HelpTopic.slipping),
          for (final d in slipping) _InstructorCard(d: d, onTap: () => _open(d)),
        ],
        if (good.isNotEmpty) ...[
          SectionTitle('منضبطون', color: DisciplineColors.onTime, count: good.length, help: HelpTopic.disciplined),
          for (final d in good) _InstructorCard(d: d, onTap: () => _open(d)),
        ],
      ],
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.result});

  final DisciplineResult result;

  @override
  Widget build(BuildContext context) {
    final s = result.summary;
    final last = result.lastSession;
    return SoftCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  result.course?.nameAr ?? 'تسجيل الأساتذة للحضور',
                  style: TextStyle(fontFamily: 'Cairo', fontSize: 12, color: Colors.grey.shade600),
                ),
              ),
              const HelpChip(HelpTopic.instructors),
            ],
          ),
          const SizedBox(height: 4),
          if (last != null) ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(
                  '${s.notRecorded}',
                  style: TextStyle(
                    fontFamily: 'Cairo',
                    fontSize: 30,
                    fontWeight: FontWeight.bold,
                    height: 1.1,
                    color: s.notRecorded == 0 ? DisciplineColors.onTime : DisciplineColors.missed,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    s.notRecorded == 0
                        ? 'كل الحلقات سجّلت آخر جلسة (${dayLabel(last)})'
                        : 'من ${s.halaqas} لم يسجّلوا آخر جلسة (${dayLabel(last)})',
                    style: const TextStyle(
                      fontFamily: 'Cairo',
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: AttendanceColors.ink,
                      height: 1.5,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              [
                if (s.sameDay > 0) '${s.sameDay} سجّلوا في اليوم نفسه',
                if (s.late > 0) '${s.late} سجّلوا متأخرين',
                if (s.covered > 0) '${s.covered} استلمها نائب',
                if (s.neverRecorded > 0) '${s.neverRecorded} لم يسجّلوا أي جلسة من الجلسات الأربع',
              ].join(' · '),
              style: TextStyle(fontFamily: 'Cairo', fontSize: 12, color: Colors.grey.shade700, height: 1.7),
            ),
          ],
          const SizedBox(height: 12),
          const DisciplineLegend(),
        ],
      ),
    );
  }
}

class _InstructorCard extends StatelessWidget {
  const _InstructorCard({required this.d, required this.onTap});

  final InstructorDiscipline d;
  final VoidCallback onTap;

  String get _pill {
    if (d.neverRecorded) return 'لم يسجّل أي جلسة';
    if (d.missedCount == 0 && d.lateCount == 0) return '${d.recordedCount} من ${d.requiredCount} · في وقتها';
    return 'سجّل ${d.recordedCount} من ${d.requiredCount}';
  }

  String get _line {
    final last = d.lastRecorded;
    if (d.neverRecorded || last == null) {
      return '${studentsAr(d.students)} · لا تتوفر عنهم معلومات من الجلسات الأخيرة';
    }
    final when = recordedWhen(last.recordedAt, last.date);
    return 'آخر تسجيل: ${dayLabel(last.date)}${when.isEmpty ? '' : ' · سُجّلت $when'}';
  }

  @override
  Widget build(BuildContext context) {
    final edge = levelColor(d.level);
    final coveredLast = d.sessions.isNotEmpty && d.sessions.last.byOther;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              border: BorderDirectional(start: BorderSide(color: edge, width: 3)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'أ. ${d.instructorName}',
                        style: const TextStyle(
                          fontFamily: 'Cairo',
                          fontSize: 14.5,
                          fontWeight: FontWeight.bold,
                          color: AttendanceColors.ink,
                        ),
                      ),
                    ),
                    TintPill(label: _pill, color: edge),
                    const SizedBox(width: 4),
                    Icon(Icons.chevron_right_rounded, color: Colors.grey.shade400),
                  ],
                ),
                const SizedBox(height: 11),
                DisciplineStrip(sessions: d.sessions),
                const SizedBox(height: 10),
                Text(
                  _line,
                  style: TextStyle(
                    fontFamily: 'Cairo',
                    fontSize: 11.5,
                    color: d.neverRecorded ? DisciplineColors.missed : Colors.grey.shade700,
                    fontWeight: d.neverRecorded ? FontWeight.w600 : FontWeight.normal,
                    height: 1.6,
                  ),
                ),
                if (coveredLast)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      'آخر جلسة استلمها أ. ${d.sessions.last.markedByName ?? 'نائب'} — لا تُحتسب عليه',
                      style: const TextStyle(
                        fontFamily: 'Cairo',
                        fontSize: 11.5,
                        color: DisciplineColors.covered,
                        fontWeight: FontWeight.w600,
                        height: 1.6,
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
