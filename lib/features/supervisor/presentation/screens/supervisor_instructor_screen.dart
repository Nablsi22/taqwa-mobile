import 'package:flutter/material.dart';
import '../../../../core/theme/taqwa_colors.dart';
import '../../../../core/utils/meeting_days.dart';
import '../../../attendance_stats/data/attendance_stats_models.dart';
import '../../../attendance_stats/presentation/attendance_ui.dart';
import '../../../instructor_home/presentation/screens/instructor_student_detail_screen.dart';
import '../../data/supervisor_api.dart';
import '../../data/supervisor_models.dart';
import '../supervisor_navigation.dart';
import '../supervisor_ui.dart';
import 'supervisor_halaqa_screen.dart';

/// One أستاذ, everything about his حلقة, read-only, in three tabs:
///
///   الحضور    the last session (who came, out of how many), his recording
///             record for every meeting day of the course, and his own
///             presence as the administration recorded it
///   الطلاب    his students as his own dashboard shows them — points gained
///             and deducted, memorisation, attendance — filtered by school
///             and grade; each opens the student's full page
///   التسميع   what his students recited, day by day: the passage, the
///             rating, the points
class SupervisorInstructorScreen extends StatelessWidget {
  const SupervisorInstructorScreen({
    super.key,
    required this.api,
    required this.instructorId,
    required this.instructorName,
    this.studentsCount = 0,
  });

  final SupervisorApi api;
  final String instructorId;
  final String instructorName;

  /// For «سمّع X من أصل N» before the roster has loaded; 0 when unknown.
  final int studentsCount;

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: DefaultTabController(
        length: 3,
        child: Scaffold(
          backgroundColor: TaqwaColors.background,
          appBar: AppBar(
            title: Text(
              'أ. $instructorName',
              style: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold),
            ),
            backgroundColor: TaqwaColors.domeBlue,
            foregroundColor: Colors.white,
            elevation: 0,
            bottom: const TabBar(
              indicatorColor: TaqwaColors.minaretGold,
              indicatorWeight: 3,
              labelColor: Colors.white,
              unselectedLabelColor: Colors.white70,
              labelStyle: TextStyle(fontFamily: 'Cairo', fontSize: 13.5, fontWeight: FontWeight.bold),
              unselectedLabelStyle: TextStyle(fontFamily: 'Cairo', fontSize: 13.5),
              tabs: [
                Tab(text: 'الحضور'),
                Tab(text: 'الطلاب'),
                Tab(text: 'التسميع'),
              ],
            ),
          ),
          body: TabBarView(
            children: [
              _AttendanceTab(api: api, instructorId: instructorId),
              _StudentsTab(api: api, instructorId: instructorId),
              _RecitationsTab(api: api, instructorId: instructorId, instructorName: instructorName, studentsCount: studentsCount),
            ],
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// الحضور
// ═══════════════════════════════════════════════════════════════════════════

class _AttendanceTab extends StatefulWidget {
  const _AttendanceTab({required this.api, required this.instructorId});

  final SupervisorApi api;
  final String instructorId;

  @override
  State<_AttendanceTab> createState() => _AttendanceTabState();
}

class _AttendanceTabState extends State<_AttendanceTab> with AutomaticKeepAliveClientMixin {
  bool _loading = true;
  String? _error;
  InstructorDetail? _detail;
  SupervisedDay? _lastDay;
  List<PresenceDay> _presence = const [];
  String? _opening;

  @override
  bool get wantKeepAlive => true;

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
      final results = await Future.wait<Object?>([
        widget.api.getInstructor(widget.instructorId),
        // The last session of the course; never fatal for this screen.
        widget.api.getDay().then<Object?>((d) => d).catchError((Object _) => null),
        widget.api.getPresence(widget.instructorId).then<Object?>((p) => p).catchError((Object _) => const <PresenceDay>[]),
      ]);
      if (!mounted) return;
      setState(() {
        _detail = results[0] as InstructorDetail;
        _lastDay = results[1] as SupervisedDay?;
        _presence = (results[2] as List<PresenceDay>?) ?? const [];
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

  SupervisedHalaqa? _halaqaOf(SupervisedDay? day) {
    if (day == null) return null;
    for (final h in day.halaqas) {
      if (h.instructorId == widget.instructorId) return h;
    }
    return null;
  }

  /// A meeting day of the record: load that day and open the حلقة on it.
  Future<void> _openDay(String date) async {
    if (_opening != null) return;
    setState(() => _opening = date);
    try {
      final day = await widget.api.getDay(date: date);
      if (!mounted) return;
      final h = _halaqaOf(day);
      if (h == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('ما في بيانات لهالحلقة بهاليوم', style: TextStyle(fontFamily: 'Cairo'))),
        );
      } else {
        await Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => SupervisorHalaqaScreen(halaqa: h, date: date, kind: day.kind)),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString(), style: const TextStyle(fontFamily: 'Cairo'))),
      );
    } finally {
      if (mounted) setState(() => _opening = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return RefreshIndicator(color: TaqwaColors.domeBlue, onRefresh: _load, child: _body());
  }

  Widget _body() {
    if (_loading && _detail == null) {
      return const Center(child: CircularProgressIndicator(color: TaqwaColors.domeBlue));
    }
    if (_error != null && _detail == null) {
      return SupervisorState(icon: Icons.error_outline_rounded, title: _error!, onRetry: _load);
    }
    final detail = _detail!;
    final d = detail.discipline;
    if (d == null) {
      return const SupervisorState(icon: Icons.groups_2_outlined, title: 'هالحلقة مو ضمن الدورة الحالية');
    }
    final presenceByDate = {for (final p in _presence) p.date: p};
    final lastDate = _lastDay?.date;
    final lastKind = _lastDay?.kind;
    final lastHalaqa = _halaqaOf(_lastDay);

    return ListView(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 24),
      children: [
        if (lastDate != null)
          _LastSessionCard(
            date: lastDate,
            kind: lastKind,
            halaqa: lastHalaqa,
            onOpen: lastHalaqa == null
                ? null
                : () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => SupervisorHalaqaScreen(halaqa: lastHalaqa, date: lastDate, kind: lastKind),
                      ),
                    ),
          ),
        const SizedBox(height: 12),
        _Summary(d: d),
        if (_presence.isNotEmpty) ...[
          const SectionTitle('حضور الأستاذ (من الإدارة)'),
          _PresenceCard(presence: _presence),
        ],
        const SectionTitle('سجل الأستاذ بأيام الدوام'),
        SoftCard(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
          child: Column(
            children: [
              for (var i = 0; i < d.sessions.length; i++)
                _SessionRow(
                  s: d.sessions[i],
                  last: i == d.sessions.length - 1,
                  presence: presenceByDate[d.sessions[i].date],
                  busy: _opening == d.sessions[i].date,
                  onTap: d.sessions[i].recorded ? () => _openDay(d.sessions[i].date) : null,
                ),
            ],
          ),
        ),
        SectionTitle('التزام طلابه بالحضور', count: detail.students.length),
        _Students(students: detail.students),
      ],
    );
  }
}

/// «آخر جلسة · السبت 24/10 — حضر 14 من أصل 17»
class _LastSessionCard extends StatelessWidget {
  const _LastSessionCard({required this.date, required this.kind, required this.halaqa, required this.onOpen});

  final String date;
  final DayKind? kind;
  final SupervisedHalaqa? halaqa;
  final VoidCallback? onOpen;

  @override
  Widget build(BuildContext context) {
    final h = halaqa;
    final optional = kind == DayKind.optional || kind == DayKind.extra;
    final isToday = date == isoDay(DateTime.now());
    return SoftCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${isToday ? 'جلسة اليوم' : 'آخر جلسة'} · ${dayLabel(date)}${optional ? ' · اختياري' : ''}',
            style: TextStyle(fontFamily: 'Cairo', fontSize: 12, color: Colors.grey.shade600),
          ),
          const SizedBox(height: 6),
          if (h == null)
            const QuietNote(text: 'هالحلقة ما إلها طلاب بهالدورة')
          else if (!h.recorded)
            Row(
              children: [
                const Icon(Icons.error_outline_rounded, color: DisciplineColors.missed, size: 20),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'ما سجّل حضور هالجلسة لهلق · ${studentsAr(h.students)}',
                    style: const TextStyle(
                      fontFamily: 'Cairo',
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: DisciplineColors.missed,
                    ),
                  ),
                ),
              ],
            )
          else ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(
                  '${h.present + h.lateCount}',
                  style: const TextStyle(
                    fontFamily: 'Cairo',
                    fontSize: 30,
                    height: 1.1,
                    fontWeight: FontWeight.bold,
                    color: AttendanceColors.present,
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'حضروا من أصل ${studentsAr(h.students)}',
                    style: const TextStyle(
                      fontFamily: 'Cairo',
                      fontSize: 13.5,
                      fontWeight: FontWeight.bold,
                      color: AttendanceColors.ink,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                CountTile(count: h.present, label: 'حاضر', color: AttendanceColors.present),
                CountTile(count: h.lateCount, label: 'متأخر', color: AttendanceColors.lateArrival),
                if (!optional) CountTile(count: h.absent, label: 'غائب', color: AttendanceColors.absent),
                if (!optional && h.excused > 0) CountTile(count: h.excused, label: 'بعذر', color: AttendanceColors.excused),
                if (h.unmarked > 0) CountTile(count: h.unmarked, label: 'لم يُسجَّل', color: AttendanceColors.unmarked),
              ],
            ),
            if (!optional && h.absent > 0) ...[
              const SizedBox(height: 10),
              Text.rich(
                TextSpan(
                  children: [
                    const TextSpan(
                      text: 'الغائبون: ',
                      style: TextStyle(fontWeight: FontWeight.bold, color: AttendanceColors.absent),
                    ),
                    TextSpan(
                      text: joinNames(h.roster.where((r) => r.status == 'ABSENT').toList(), h.roster),
                      style: const TextStyle(color: AttendanceColors.ink),
                    ),
                  ],
                ),
                style: const TextStyle(fontFamily: 'Cairo', fontSize: 12.5, height: 1.8),
              ),
            ],
            const SizedBox(height: 4),
            Text(
              h.byOther
                  ? 'سجّلها أ. ${h.markedByName ?? 'نائب'} بالنيابة · ${recordedWhen(h.recordedAt, date)}'
                  : '${lagLabel(h.lagDays)} · ${recordedWhen(h.recordedAt, date)}',
              style: TextStyle(fontFamily: 'Cairo', fontSize: 11.5, color: Colors.grey.shade600, height: 1.7),
            ),
          ],
          if (onOpen != null) ...[
            const SizedBox(height: 6),
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: TextButton.icon(
                onPressed: onOpen,
                icon: const Icon(Icons.list_alt_rounded, size: 18),
                label: const Text('أسماء الحلقة كاملة', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.w600)),
                style: TextButton.styleFrom(foregroundColor: TaqwaColors.domeBlue, padding: EdgeInsets.zero),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// The أستاذ's own presence, from «حضور المعلمين».
class _PresenceCard extends StatelessWidget {
  const _PresenceCard({required this.presence});

  final List<PresenceDay> presence;

  @override
  Widget build(BuildContext context) {
    final absent = presence.where((p) => !p.present).toList();
    return SoftCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              CountTile(count: presence.length - absent.length, label: 'حضر', color: AttendanceColors.present),
              CountTile(count: absent.length, label: 'غاب', color: AttendanceColors.absent),
            ],
          ),
          if (absent.isNotEmpty) ...[
            const SizedBox(height: 10),
            for (final p in absent)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  '• ${dayLabel(p.date)}${p.notes == null ? '' : ' · ${p.notes}'}',
                  style: const TextStyle(fontFamily: 'Cairo', fontSize: 12.5, color: AttendanceColors.ink),
                ),
              ),
          ],
        ],
      ),
    );
  }
}

class _Summary extends StatelessWidget {
  const _Summary({required this.d});

  final InstructorDiscipline d;

  @override
  Widget build(BuildContext context) {
    final color = levelColor(d.level);
    return SoftCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                '${d.recordedCount}',
                style: TextStyle(
                  fontFamily: 'Cairo',
                  fontSize: 30,
                  fontWeight: FontWeight.bold,
                  height: 1.1,
                  color: color,
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'من ${sessionsAr(d.requiredCount)} إلزامية سجّلها',
                  style: const TextStyle(
                    fontFamily: 'Cairo',
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: AttendanceColors.ink,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              if (d.missedCount > 0)
                TintPill(label: 'ما سجّل ${sessionsAr(d.missedCount)}', color: DisciplineColors.missed),
              if (d.sameDayCount > 0)
                TintPill(label: 'بنفس اليوم ${d.sameDayCount}', color: DisciplineColors.onTime),
              if (d.lateCount > 0)
                TintPill(label: 'متأخر ${d.lateCount}', color: DisciplineColors.veryLate),
              if (d.coveredCount > 0)
                TintPill(label: 'بالنيابة ${d.coveredCount}', color: DisciplineColors.covered),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            '${studentsAr(d.students)} · ${avgLagLabel(d.avgLagDays)}',
            style: TextStyle(fontFamily: 'Cairo', fontSize: 12, color: Colors.grey.shade700),
          ),
        ],
      ),
    );
  }
}

class _SessionRow extends StatelessWidget {
  const _SessionRow({required this.s, required this.last, this.presence, this.onTap, this.busy = false});

  final SessionRecord s;
  final bool last;

  /// The أستاذ's own presence that day, when the administration recorded it.
  final PresenceDay? presence;

  /// Opens the حلقة on that day (who came, who did not).
  final VoidCallback? onTap;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final look = sessionLook(s);
    final optional = s.kind != DayKind.mandatory;
    final String detail;
    if (s.recorded && s.byOther) {
      detail = '${look.label} · ${recordedWhen(s.recordedAt, s.date)}';
    } else if (s.recorded) {
      detail = '${recordedWhen(s.recordedAt, s.date)} · ${s.marks} طالب';
    } else if (optional) {
      detail = 'اختياري · ما بينحسب';
    } else {
      detail = '—';
    }
    final String pill;
    if (s.recorded && s.byOther) {
      pill = 'بالنيابة';
    } else if (s.recorded) {
      pill = (s.lagDays ?? 0) <= 0 ? 'بوقتها' : lagLabel(s.lagDays).replaceFirst('سجّل ', '');
    } else {
      pill = optional ? 'ما في' : 'ما سجّل';
    }
    final p = presence;

    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 11),
        decoration: BoxDecoration(
          border: last ? null : const Border(bottom: BorderSide(color: TaqwaColors.dividerColor)),
        ),
        child: Row(
          children: [
            SizedBox(
              width: 92,
              child: Text(
                dayLabel(s.date),
                style: TextStyle(
                  fontFamily: 'Cairo',
                  fontSize: 12.5,
                  fontWeight: FontWeight.bold,
                  color: optional ? Colors.grey.shade600 : AttendanceColors.ink,
                ),
              ),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    detail,
                    style: TextStyle(fontFamily: 'Cairo', fontSize: 11.5, color: Colors.grey.shade700, height: 1.5),
                  ),
                  if (p != null)
                    Text(
                      p.present ? 'الأستاذ حاضر (الإدارة)' : 'الأستاذ غائب (الإدارة)${p.notes == null ? '' : ' · ${p.notes}'}',
                      style: TextStyle(
                        fontFamily: 'Cairo',
                        fontSize: 11,
                        color: p.present ? AttendanceColors.present : AttendanceColors.absent,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 6),
            TintPill(
              label: pill,
              color: look.onDark ? look.color : AttendanceColors.unmarked,
              dense: true,
            ),
            if (onTap != null)
              busy
                  ? const Padding(
                      padding: EdgeInsetsDirectional.only(start: 6),
                      child: SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2)),
                    )
                  : Icon(Icons.chevron_left_rounded, size: 18, color: Colors.grey.shade400),
          ],
        ),
      ),
    );
  }
}

class _Students extends StatelessWidget {
  const _Students({required this.students});

  final List<StudentStats> students;

  @override
  Widget build(BuildContext context) {
    if (students.isEmpty) {
      return const SoftCard(child: QuietNote(text: 'ما في طلاب بهالحلقة'));
    }
    final names = displayNames(students.map(
      (s) => (id: s.studentId, fullName: s.fullName, fatherName: s.fatherName),
    ));
    String name(StudentStats s) {
      final n = names[s.studentId];
      if (n == null) return s.fullName;
      return n.father == null ? n.name : '${n.name} (${n.father})';
    }

    final order = [
      AttendanceClass.inactive,
      AttendanceClass.irregular,
      AttendanceClass.regular,
      AttendanceClass.noData,
    ];
    return SoftCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final c in order)
            if (students.any((s) => s.classification == c)) ...[
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(
                        text: '${classStyle(c).label} (${students.where((s) => s.classification == c).length}): ',
                        style: TextStyle(fontWeight: FontWeight.bold, color: classStyle(c).color),
                      ),
                      TextSpan(
                        text: students.where((s) => s.classification == c).map(name).join(' · '),
                        style: const TextStyle(color: AttendanceColors.ink),
                      ),
                    ],
                  ),
                  style: const TextStyle(fontFamily: 'Cairo', fontSize: 12.5, height: 1.9),
                ),
              ),
            ],
          if (students.any((s) => s.needsCall))
            QuietNote(
              icon: Icons.phone_in_talk_rounded,
              text: 'بدّهم اتصال: ${students.where((s) => s.needsCall).map(name).join(' · ')}',
            ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// الطلاب
// ═══════════════════════════════════════════════════════════════════════════

enum _Sort { points, memorisation, attendance, name }

class _StudentsTab extends StatefulWidget {
  const _StudentsTab({required this.api, required this.instructorId});

  final SupervisorApi api;
  final String instructorId;

  @override
  State<_StudentsTab> createState() => _StudentsTabState();
}

class _StudentsTabState extends State<_StudentsTab> with AutomaticKeepAliveClientMixin {
  static const _all = '__all__';
  static const _none = '__none__';

  bool _loading = true;
  String? _error;
  List<RosterStudent> _roster = const [];
  Map<String, StudentStats> _attendance = const {};
  String _school = _all;
  String _grade = _all;
  _Sort _sort = _Sort.points;

  @override
  bool get wantKeepAlive => true;

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
      final results = await Future.wait<Object>([
        widget.api.getRoster(widget.instructorId),
        widget.api.getInstructor(widget.instructorId),
      ]);
      if (!mounted) return;
      final roster = results[0] as RosterResult;
      final detail = results[1] as InstructorDetail;
      setState(() {
        _roster = roster.students;
        _attendance = {for (final s in detail.students) s.studentId: s};
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

  String _schoolOf(RosterStudent s) => s.school ?? _attendance[s.studentId]?.school ?? '';
  String _gradeOf(RosterStudent s) => s.grade ?? _attendance[s.studentId]?.grade ?? '';

  List<String> _options(String Function(RosterStudent) of) {
    final set = <String>{};
    for (final s in _roster) {
      final v = of(s).trim();
      if (v.isNotEmpty) set.add(v);
    }
    return set.toList()..sort();
  }

  bool _matches(String value, String filter) {
    if (filter == _all) return true;
    if (filter == _none) return value.trim().isEmpty;
    return value.trim() == filter;
  }

  List<RosterStudent> get _visible {
    final list = _roster
        .where((s) => _matches(_schoolOf(s), _school) && _matches(_gradeOf(s), _grade))
        .toList();
    int attended(RosterStudent s) => _attendance[s.studentId]?.course.attended ?? 0;
    switch (_sort) {
      case _Sort.points:
        list.sort((a, b) => b.pointsBalance.compareTo(a.pointsBalance));
        break;
      case _Sort.memorisation:
        list.sort((a, b) => b.pagesMemorized.compareTo(a.pagesMemorized));
        break;
      case _Sort.attendance:
        list.sort((a, b) => attended(b).compareTo(attended(a)));
        break;
      case _Sort.name:
        list.sort((a, b) => a.fullName.compareTo(b.fullName));
        break;
    }
    return list;
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return RefreshIndicator(color: TaqwaColors.domeBlue, onRefresh: _load, child: _body());
  }

  Widget _body() {
    if (_loading && _roster.isEmpty) {
      return const Center(child: CircularProgressIndicator(color: TaqwaColors.domeBlue));
    }
    if (_error != null && _roster.isEmpty) {
      return SupervisorState(icon: Icons.error_outline_rounded, title: _error!, onRetry: _load);
    }
    if (_roster.isEmpty) {
      return const SupervisorState(icon: Icons.groups_2_outlined, title: 'ما في طلاب بهالحلقة');
    }

    final schools = _options(_schoolOf);
    final grades = _options(_gradeOf);
    final hasNoSchool = _roster.any((s) => _schoolOf(s).trim().isEmpty);
    final hasNoGrade = _roster.any((s) => _gradeOf(s).trim().isEmpty);
    final visible = _visible;
    final names = displayNames(_roster.map((s) => (id: s.studentId, fullName: s.fullName, fatherName: s.fatherName)));
    final gained = visible.fold<double>(0, (t, s) => t + s.pointsGained);
    final deducted = visible.fold<double>(0, (t, s) => t + s.pointsDeducted);

    return ListView(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 24),
      children: [
        SoftCard(
          padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: _Picker(
                      label: 'المدرسة',
                      value: _school,
                      options: [
                        (value: _all, label: 'كل المدارس'),
                        for (final s in schools) (value: s, label: s),
                        if (hasNoSchool) (value: _none, label: 'بدون مدرسة'),
                      ],
                      onChanged: (v) => setState(() => _school = v),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _Picker(
                      label: 'الصف',
                      value: _grade,
                      options: [
                        (value: _all, label: 'كل الصفوف'),
                        for (final g in grades) (value: g, label: g),
                        if (hasNoGrade) (value: _none, label: 'بدون صف'),
                      ],
                      onChanged: (v) => setState(() => _grade = v),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    for (final o in const [
                      (_Sort.points, 'النقاط'),
                      (_Sort.memorisation, 'الحفظ'),
                      (_Sort.attendance, 'الحضور'),
                      (_Sort.name, 'الاسم'),
                    ])
                      Padding(
                        padding: const EdgeInsetsDirectional.only(end: 6),
                        child: ChoiceChip(
                          label: Text(o.$2),
                          selected: _sort == o.$1,
                          showCheckmark: false,
                          onSelected: (_) => setState(() => _sort = o.$1),
                          labelStyle: TextStyle(
                            fontFamily: 'Cairo',
                            fontSize: 12,
                            fontWeight: _sort == o.$1 ? FontWeight.bold : FontWeight.normal,
                            color: _sort == o.$1 ? Colors.white : TaqwaColors.domeBlue,
                          ),
                          selectedColor: TaqwaColors.domeBlue,
                          backgroundColor: TaqwaColors.domeBlue.withValues(alpha: 0.07),
                          side: BorderSide.none,
                          visualDensity: VisualDensity.compact,
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '${studentsAr(visible.length)} · كسبوا +${numAr(gained)} · انخصم منهم ${numAr(deducted.abs())}',
                style: TextStyle(fontFamily: 'Cairo', fontSize: 12, color: Colors.grey.shade700),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        if (visible.isEmpty)
          const SoftCard(child: QuietNote(text: 'ما في طلاب بهالفلتر'))
        else
          for (var i = 0; i < visible.length; i++)
            _RosterCard(
              rank: _sort == _Sort.name ? null : i + 1,
              s: visible[i],
              name: names[visible[i].studentId],
              school: _schoolOf(visible[i]),
              grade: _gradeOf(visible[i]),
              attendance: _attendance[visible[i].studentId],
            ),
      ],
    );
  }
}

class _Picker extends StatelessWidget {
  const _Picker({required this.label, required this.value, required this.options, required this.onChanged});

  final String label;
  final String value;
  final List<({String value, String label})> options;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final current = options.any((o) => o.value == value) ? value : options.first.value;
    return DropdownButtonFormField<String>(
      // Rebuilt when the choices change, so a stale value never outlives them.
      key: ValueKey('$label|$current|${options.length}'),
      initialValue: current,
      isExpanded: true,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(fontFamily: 'Cairo', fontSize: 12),
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
      ),
      style: const TextStyle(fontFamily: 'Cairo', fontSize: 12.5, color: AttendanceColors.ink),
      items: [
        for (final o in options)
          DropdownMenuItem(value: o.value, child: Text(o.label, overflow: TextOverflow.ellipsis)),
      ],
      onChanged: (v) {
        if (v != null) onChanged(v);
      },
    );
  }
}

class _RosterCard extends StatelessWidget {
  const _RosterCard({
    required this.rank,
    required this.s,
    required this.name,
    required this.school,
    required this.grade,
    required this.attendance,
  });

  final int? rank;
  final RosterStudent s;
  final ({String name, String? father})? name;
  final String school;
  final String grade;
  final StudentStats? attendance;

  @override
  Widget build(BuildContext context) {
    final display = name == null ? s.fullName : name!.name;
    final where = [
      if (school.trim().isNotEmpty) school.trim(),
      if (grade.trim().isNotEmpty) grade.trim(),
      ?name?.father,
    ].join(' · ');
    final a = attendance;
    final rating = ratingLook(s.lastRating);

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () => openStudentPage(context, studentId: s.studentId, name: s.fullName),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 10, 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (rank != null)
                  Container(
                    width: 28,
                    height: 28,
                    margin: const EdgeInsetsDirectional.only(end: 10),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: rank! <= 3 ? TaqwaColors.minaretGold.withValues(alpha: 0.14) : TaqwaColors.background,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '$rank',
                      style: TextStyle(
                        fontFamily: 'Cairo',
                        fontSize: 12.5,
                        fontWeight: FontWeight.bold,
                        color: rank! <= 3 ? TaqwaColors.minaretGold : Colors.grey.shade600,
                      ),
                    ),
                  ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              display,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontFamily: 'Cairo',
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: AttendanceColors.ink,
                              ),
                            ),
                          ),
                          if (a != null) ClassBadge(a.classification, dense: true),
                        ],
                      ),
                      if (where.isNotEmpty)
                        Text(
                          where,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontFamily: 'Cairo', fontSize: 11, color: Colors.grey.shade600),
                        ),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          TintPill(label: '${numAr(s.pointsBalance)} نقطة', color: TaqwaColors.domeBlue, dense: true),
                          TintPill(label: '+${numAr(s.pointsGained)}', color: AttendanceColors.present, dense: true),
                          if (s.pointsDeducted != 0)
                            TintPill(label: '−${numAr(s.pointsDeducted.abs())}', color: AttendanceColors.absent, dense: true),
                          TintPill(
                            label: '${numAr(s.pagesMemorized)} صفحة (${numAr(s.percentage)}%)',
                            color: TaqwaColors.minaretGold,
                            dense: true,
                          ),
                          if (a != null)
                            TintPill(
                              label: a.course.sessions == 0
                                  ? 'ما في جلسات بعد'
                                  : 'حضر ${a.course.attended} من ${a.course.sessions}',
                              color: AttendanceColors.unmarked,
                              dense: true,
                            ),
                        ],
                      ),
                      if (s.lastSurahName != null) ...[
                        const SizedBox(height: 6),
                        Text(
                          [
                            'آخر تسميع: ${s.lastSurahName}',
                            ?rating?.label,
                            if (s.lastDate != null) shortDate(s.lastDate),
                          ].join(' · '),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontFamily: 'Cairo', fontSize: 11.5, color: Colors.grey.shade700),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 4),
                Icon(Icons.chevron_left_rounded, color: Colors.grey.shade400, size: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// التسميع
// ═══════════════════════════════════════════════════════════════════════════

class _RecitationsTab extends StatefulWidget {
  const _RecitationsTab({
    required this.api,
    required this.instructorId,
    required this.instructorName,
    required this.studentsCount,
  });

  final SupervisorApi api;
  final String instructorId;
  final String instructorName;
  final int studentsCount;

  @override
  State<_RecitationsTab> createState() => _RecitationsTabState();
}

class _RecitationsTabState extends State<_RecitationsTab> with AutomaticKeepAliveClientMixin {
  bool _loading = true;
  String? _error;
  RecitationsResult? _result;

  /// The day shown (null → the server's default: the last session day).
  String? _day;

  /// Whole last 30 days instead of one day.
  bool _month = false;

  @override
  bool get wantKeepAlive => true;

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
      final today = isoDay(DateTime.now());
      final RecitationsResult r;
      if (_month) {
        final start = isoDay(DateTime.now().subtract(const Duration(days: 29)));
        r = await widget.api.getRecitations(widget.instructorId, from: start, to: today);
      } else {
        r = await widget.api.getRecitations(widget.instructorId, from: _day, to: _day);
      }
      if (!mounted) return;
      setState(() {
        _result = r;
        if (!_month) _day = r.to;
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

  /// The previous / next meeting day of the course from [from].
  String? _step(String from, int dir) {
    final course = _result?.course;
    final days = course?.meetingDays;
    final d = parseIsoDay(from);
    if (d == null || days == null || !days.isConfigured) return null;
    final today = isoDay(DateTime.now());
    for (var i = 1; i <= 7; i++) {
      final next = d.add(Duration(days: dir * i));
      final iso = isoDay(next);
      if (dir > 0 && iso.compareTo(today) > 0) return null;
      if (course != null && iso.compareTo(course.startDate.length >= 10 ? course.startDate.substring(0, 10) : course.startDate) < 0) {
        return null;
      }
      if (days.isMeetingDay(next)) return iso;
    }
    return null;
  }

  Future<void> _pick() async {
    final current = parseIsoDay(_day) ?? DateTime.now();
    final course = _result?.course;
    final first = parseIsoDay(course?.startDate) ?? DateTime(2025);
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime(current.year, current.month, current.day),
      firstDate: DateTime(first.year, first.month, first.day),
      lastDate: DateTime.now(),
      helpText: 'اختر اليوم',
      cancelText: 'إلغاء',
      confirmText: 'تأكيد',
    );
    if (picked == null) return;
    setState(() {
      _month = false;
      _day = isoDay(picked);
    });
    _load();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return RefreshIndicator(color: TaqwaColors.domeBlue, onRefresh: _load, child: _body());
  }

  Widget _body() {
    if (_loading && _result == null) {
      return const Center(child: CircularProgressIndicator(color: TaqwaColors.domeBlue));
    }
    if (_error != null && _result == null) {
      return SupervisorState(icon: Icons.error_outline_rounded, title: _error!, onRetry: _load);
    }
    final r = _result!;
    final items = r.items;
    final students = items.map((i) => i.studentId).toSet().length;
    final prev = _month || _day == null ? null : _step(_day!, -1);
    final next = _month || _day == null ? null : _step(_day!, 1);

    // Grouped by day, newest first (the server already sorts).
    final byDay = <String, List<RecitationItem>>{};
    for (final i in items) {
      byDay.putIfAbsent(i.date, () => []).add(i);
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 24),
      children: [
        SoftCard(
          padding: const EdgeInsets.fromLTRB(6, 6, 6, 10),
          child: Column(
            children: [
              Row(
                children: [
                  IconButton(
                    onPressed: prev == null || _loading
                        ? null
                        : () {
                            setState(() => _day = prev);
                            _load();
                          },
                    icon: const Icon(Icons.chevron_right_rounded),
                    tooltip: 'يوم الدوام السابق',
                  ),
                  Expanded(
                    child: InkWell(
                      onTap: _pick,
                      borderRadius: BorderRadius.circular(10),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        child: Text(
                          _month ? 'آخر 30 يوم' : dayLabel(r.to),
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontFamily: 'Cairo',
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: TaqwaColors.domeBlue,
                          ),
                        ),
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: next == null || _loading
                        ? null
                        : () {
                            setState(() => _day = next);
                            _load();
                          },
                    icon: const Icon(Icons.chevron_left_rounded),
                    tooltip: 'يوم الدوام التالي',
                  ),
                ],
              ),
              Wrap(
                spacing: 8,
                alignment: WrapAlignment.center,
                children: [
                  ChoiceChip(
                    label: const Text('يوم'),
                    selected: !_month,
                    showCheckmark: false,
                    onSelected: (_) {
                      if (!_month) return;
                      setState(() => _month = false);
                      _load();
                    },
                    labelStyle: const TextStyle(fontFamily: 'Cairo', fontSize: 12),
                    visualDensity: VisualDensity.compact,
                  ),
                  ChoiceChip(
                    label: const Text('آخر 30 يوم'),
                    selected: _month,
                    showCheckmark: false,
                    onSelected: (_) {
                      if (_month) return;
                      setState(() => _month = true);
                      _load();
                    },
                    labelStyle: const TextStyle(fontFamily: 'Cairo', fontSize: 12),
                    visualDensity: VisualDensity.compact,
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                items.isEmpty
                    ? 'ما في تسميع مسجّل'
                    : widget.studentsCount > 0
                        ? 'سمّع $students من أصل ${studentsAr(widget.studentsCount)} · ${items.length} تسميع'
                        : '${studentsAr(students)} سمّعوا · ${items.length} تسميع',
                style: TextStyle(fontFamily: 'Cairo', fontSize: 12, color: Colors.grey.shade700),
              ),
              if (_loading) const Padding(padding: EdgeInsets.only(top: 6), child: LinearProgressIndicator(minHeight: 2)),
            ],
          ),
        ),
        for (final day in byDay.keys) ...[
          if (_month) SectionTitle(dayLabel(day), count: byDay[day]!.length),
          if (!_month) const SizedBox(height: 10),
          for (final i in byDay[day]!) _RecitationCard(item: i, instructorName: widget.instructorName),
        ],
      ],
    );
  }
}

class _RecitationCard extends StatelessWidget {
  const _RecitationCard({required this.item, required this.instructorName});

  final RecitationItem item;
  final String instructorName;

  @override
  Widget build(BuildContext context) {
    final i = item;
    final rating = ratingLook(i.rating);
    final String what;
    final String? range;
    if (i.isHadith) {
      what = 'الحديث ${i.hadithNumber ?? ''}${i.hadithTitle == null ? '' : ' · ${i.hadithTitle}'}';
      range = null;
    } else {
      what = i.suraNames.isEmpty ? 'تسميع' : 'سورة ${i.suraNames.join('، ')}';
      if (i.isCompleteSura) {
        range = 'سورة كاملة';
      } else if (i.startAya != null && i.endAya != null) {
        range = i.startSurah != null && i.endSurah != null && i.startSurah != i.endSurah
            ? 'من الآية ${i.startAya} إلى الآية ${i.endAya} (سور متعددة)'
            : 'من الآية ${i.startAya} إلى الآية ${i.endAya}';
      } else {
        range = null;
      }
    }
    final recorder = i.recordedBy;
    final showRecorder = recorder != null && recorder.isNotEmpty && recorder != instructorName;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () => openStudentPage(
            context,
            studentId: i.studentId,
            name: i.studentName,
            tab: InstructorStudentDetailScreen.recitationTab,
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 11, 12, 11),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        i.studentName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontFamily: 'Cairo',
                          fontSize: 13.5,
                          fontWeight: FontWeight.bold,
                          color: AttendanceColors.ink,
                        ),
                      ),
                    ),
                    if (rating != null) TintPill(label: rating.label, color: rating.color, dense: true),
                    if (i.isHadith) const TintPill(label: 'الأربعين', color: Color(0xFF8E44AD), dense: true),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  what,
                  style: const TextStyle(fontFamily: 'Cairo', fontSize: 13, color: TaqwaColors.domeBlue, fontWeight: FontWeight.w600),
                ),
                if (range != null)
                  Text(range, style: TextStyle(fontFamily: 'Cairo', fontSize: 12, color: Colors.grey.shade800)),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    if (!i.isHadith && i.pages > 0)
                      TintPill(label: '${numAr(i.pages)} صفحة', color: TaqwaColors.minaretGold, dense: true),
                    TintPill(
                      label: '${i.points >= 0 ? '+' : '−'}${numAr(i.points.abs())} نقطة',
                      color: i.points >= 0 ? AttendanceColors.present : AttendanceColors.absent,
                      dense: true,
                    ),
                    if (showRecorder)
                      TintPill(label: 'سجّله: $recorder', color: DisciplineColors.covered, dense: true),
                  ],
                ),
                if (i.homework != null) ...[
                  const SizedBox(height: 6),
                  Text(
                    'الواجب: ${i.homework}',
                    style: TextStyle(fontFamily: 'Cairo', fontSize: 11.5, color: Colors.amber.shade800),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
