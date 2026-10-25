import 'package:flutter/material.dart';
import '../../../../core/theme/taqwa_colors.dart';
import '../../../../core/utils/meeting_days.dart';
import '../../../attendance_stats/presentation/attendance_ui.dart';
import '../../data/supervisor_api.dart';
import '../../data/supervisor_models.dart';
import '../supervisor_ui.dart';
import 'supervisor_halaqa_screen.dart';

/// «الجلسة» — one meeting day across every حلقة.
///
/// The arrows step through the course's own meeting days only — Saturday
/// and Thursday in winter, Saturday, Monday and Wednesday in summer — read
/// from the course itself, so a new course schedule needs no app change.
///
/// Unrecorded حلقات come first: on a day where six of ten did not record,
/// that is the story of the day. Attendance numbers are shown only for the
/// حلقات that recorded, so a أستاذ who did not record never reads as "nobody
/// came".
///
/// On an optional day nobody is ever counted absent, so absences are not
/// shown at all — only who came.
class SupervisorDayTab extends StatefulWidget {
  const SupervisorDayTab({super.key, required this.api});

  final SupervisorApi api;

  @override
  State<SupervisorDayTab> createState() => _SupervisorDayTabState();
}

class _SupervisorDayTabState extends State<SupervisorDayTab> {
  bool _loading = true;
  bool _unavailable = false;
  String? _error;
  SupervisedDay? _day;

  /// null → let the server pick the last required session with records.
  String? _date;

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
      final d = await widget.api.getDay(date: _date);
      if (!mounted) return;
      setState(() {
        _day = d;
        _date = d.date ?? _date;
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

  // ── Stepping through meeting days ──────────────────────────────────────

  static DateTime? _parse(String? iso) {
    if (iso == null || iso.length < 10) return null;
    final p = iso.substring(0, 10).split('-');
    if (p.length != 3) return null;
    final y = int.tryParse(p[0]), m = int.tryParse(p[1]), d = int.tryParse(p[2]);
    if (y == null || m == null || d == null) return null;
    return DateTime.utc(y, m, d);
  }

  DateTime get _today {
    final now = DateTime.now();
    return DateTime.utc(now.year, now.month, now.day);
  }

  MeetingDays get _meetingDays => _day?.course?.meetingDays ?? const MeetingDays();

  DateTime? get _first => _parse(_day?.course?.startDate);

  DateTime get _lastAllowed {
    final end = _parse(_day?.course?.endDate);
    return end != null && end.isBefore(_today) ? end : _today;
  }

  bool _isMeeting(DateTime d) =>
      !_meetingDays.isConfigured || _meetingDays.isMeetingDay(d);

  /// The previous (dir = -1) or next (dir = 1) meeting day, inside the course
  /// and never in the future. null when there is none.
  String? _step(int dir) {
    final from = _parse(_date);
    if (from == null) return null;
    final first = _first;
    var d = from;
    for (var i = 0; i < 31; i++) {
      d = d.add(Duration(days: dir));
      if (first != null && d.isBefore(first)) return null;
      if (d.isAfter(_lastAllowed)) return null;
      if (_isMeeting(d)) return isoDay(d);
    }
    return null;
  }

  void _go(String? date) {
    if (date == null) return;
    setState(() => _date = date);
    _load();
  }

  Future<void> _pick() async {
    final current = _parse(_date);
    final first = _first;
    if (current == null || first == null) return;
    final last = _lastAllowed;
    final initial = current.isAfter(last) ? last : current;
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: first.isAfter(initial) ? initial : first,
      lastDate: last.isBefore(initial) ? initial : last,
      // Only the course's meeting days can be chosen. The current day is
      // always allowed, so the picker never opens on a forbidden day.
      selectableDayPredicate: (d) => _isMeeting(d) || isoDay(d) == isoDay(initial),
      helpText: 'اختر يوم دوام',
      cancelText: 'إلغاء',
      confirmText: 'عرض',
    );
    if (picked != null) _go(isoDay(picked));
  }

  // ── Build ──────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      color: TaqwaColors.domeBlue,
      onRefresh: _load,
      child: _body(),
    );
  }

  Widget _body() {
    if (_loading && _day == null) {
      return const Center(child: CircularProgressIndicator(color: TaqwaColors.domeBlue));
    }
    if (_unavailable) {
      return const SupervisorState(
        icon: Icons.cloud_off_rounded,
        title: 'لوحة مدير الدورة تظهر بعد تحديث الخادم',
      );
    }
    if (_error != null && _day == null) {
      return SupervisorState(icon: Icons.error_outline_rounded, title: _error!, onRetry: _load);
    }

    final day = _day!;
    if (day.date == null) {
      return SupervisorState(
        icon: Icons.event_busy_rounded,
        title: day.message ?? 'لا توجد جلسة مسجّلة في هذه الدورة بعد',
        onRetry: _load,
      );
    }

    final optional = day.kind == DayKind.optional || day.kind == DayKind.extra;
    final notRecorded = day.halaqas.where((h) => !h.recorded).toList();
    final recorded = day.halaqas.where((h) => h.recorded).toList();

    return ListView(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 24),
      children: [
        _DayNav(
          date: day.date!,
          kind: day.kind,
          loading: _loading,
          onPrev: _step(-1) == null ? null : () => _go(_step(-1)),
          onNext: _step(1) == null ? null : () => _go(_step(1)),
          onPick: _pick,
        ),
        const SizedBox(height: 12),
        _DaySummary(recorded: recorded, notRecorded: notRecorded, optional: optional),
        if (notRecorded.isNotEmpty) ...[
          SectionTitle(
            optional ? 'ما سجّلت · يوم اختياري، ما بينحسب عليهم' : 'ما سجّلت',
            color: optional ? null : DisciplineColors.missed,
            count: notRecorded.length,
          ),
          for (final h in notRecorded)
            _HalaqaCard(h: h, date: day.date!, kind: day.kind, optional: optional),
        ],
        if (recorded.isNotEmpty) ...[
          SectionTitle('سجّلت', count: recorded.length),
          for (final h in recorded)
            _HalaqaCard(h: h, date: day.date!, kind: day.kind, optional: optional),
        ],
      ],
    );
  }
}

class _DayNav extends StatelessWidget {
  const _DayNav({
    required this.date,
    required this.kind,
    required this.loading,
    required this.onPrev,
    required this.onNext,
    required this.onPick,
  });

  final String date;
  final DayKind? kind;
  final bool loading;
  final VoidCallback? onPrev;
  final VoidCallback? onNext;
  final VoidCallback onPick;

  @override
  Widget build(BuildContext context) {
    final kindLabel = switch (kind) {
      DayKind.optional => 'يوم اختياري',
      DayKind.extra => 'مو من أيام الدوام',
      _ => 'يوم إلزامي',
    };
    return Container(
      decoration: BoxDecoration(
        color: TaqwaColors.domeBlue,
        borderRadius: BorderRadius.circular(16),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
      child: Row(
        children: [
          // RTL: the right arrow goes back in time, the left one forward.
          IconButton(
            onPressed: onPrev,
            icon: const Icon(Icons.chevron_right_rounded),
            color: Colors.white,
            disabledColor: Colors.white24,
            tooltip: 'يوم الدوام السابق',
          ),
          Expanded(
            child: InkWell(
              onTap: onPick,
              borderRadius: BorderRadius.circular(10),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          dayLabel(date),
                          style: const TextStyle(
                            fontFamily: 'Cairo',
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(width: 6),
                        if (loading)
                          const SizedBox(
                            width: 12,
                            height: 12,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white70),
                          )
                        else
                          const Icon(Icons.calendar_month_rounded, size: 16, color: Colors.white70),
                      ],
                    ),
                    Text(
                      kindLabel,
                      style: const TextStyle(fontFamily: 'Cairo', fontSize: 11, color: Colors.white70),
                    ),
                  ],
                ),
              ),
            ),
          ),
          IconButton(
            onPressed: onNext,
            icon: const Icon(Icons.chevron_left_rounded),
            color: Colors.white,
            disabledColor: Colors.white24,
            tooltip: 'يوم الدوام التالي',
          ),
        ],
      ),
    );
  }
}

class _DaySummary extends StatelessWidget {
  const _DaySummary({required this.recorded, required this.notRecorded, required this.optional});

  final List<SupervisedHalaqa> recorded;
  final List<SupervisedHalaqa> notRecorded;
  final bool optional;

  @override
  Widget build(BuildContext context) {
    int sum(int Function(SupervisedHalaqa) f) => recorded.fold(0, (t, h) => t + f(h));
    final total = recorded.length + notRecorded.length;
    final waiting = notRecorded.fold(0, (t, h) => t + h.students);
    final allStudents = [...recorded, ...notRecorded].fold(0, (t, h) => t + h.students);
    final came = sum((h) => h.present + h.lateCount);

    return SoftCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            notRecorded.isEmpty
                ? 'كل الحلقات سجّلت ($total)'
                : '${recorded.length} حلقات سجّلت من $total',
            style: const TextStyle(
              fontFamily: 'Cairo',
              fontSize: 14.5,
              fontWeight: FontWeight.bold,
              color: AttendanceColors.ink,
            ),
          ),
          const SizedBox(height: 4),
          Text.rich(
            TextSpan(
              children: [
                TextSpan(
                  text: '$came',
                  style: const TextStyle(fontWeight: FontWeight.bold, color: AttendanceColors.present),
                ),
                TextSpan(text: ' حضروا من أصل ${studentsAr(allStudents)} بالدورة'),
              ],
            ),
            style: const TextStyle(fontFamily: 'Cairo', fontSize: 13, color: AttendanceColors.ink),
          ),
          if (notRecorded.isNotEmpty && !optional)
            Text(
              '${studentsAr(waiting)} بلا تسجيل · الأرقام تحت للحلقات اللي سجّلت بس',
              style: TextStyle(fontFamily: 'Cairo', fontSize: 11.5, color: Colors.grey.shade600, height: 1.7),
            ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              CountTile(count: sum((h) => h.present), label: 'حاضر', color: AttendanceColors.present),
              CountTile(count: sum((h) => h.lateCount), label: 'متأخر', color: AttendanceColors.lateArrival),
              if (!optional) ...[
                CountTile(count: sum((h) => h.absent), label: 'غائب', color: AttendanceColors.absent),
                CountTile(count: sum((h) => h.excused), label: 'بعذر', color: AttendanceColors.excused),
              ],
            ],
          ),
          if (optional) ...[
            const SizedBox(height: 10),
            const QuietNote(
              icon: Icons.star_rounded,
              text: 'يوم اختياري: ما في غياب بهاليوم، منعرض الحاضرين بس.',
            ),
          ],
        ],
      ),
    );
  }
}

class _HalaqaCard extends StatelessWidget {
  const _HalaqaCard({
    required this.h,
    required this.date,
    required this.kind,
    required this.optional,
  });

  final SupervisedHalaqa h;
  final String date;
  final DayKind? kind;
  final bool optional;

  @override
  Widget build(BuildContext context) {
    final absentees = h.roster.where((r) => r.status == 'ABSENT').toList();
    final edge = !h.recorded
        ? (optional ? DisciplineColors.notDue : DisciplineColors.missed)
        : h.byOther
            ? DisciplineColors.covered
            : (h.lagDays ?? 0) > 0
                ? DisciplineColors.veryLate
                : DisciplineColors.onTime;

    final String when;
    if (!h.recorded) {
      when = optional ? 'ما سجّل · يوم اختياري' : 'ما سجّل هالجلسة';
    } else if (h.byOther) {
      when = 'سجّلها أ. ${h.markedByName ?? 'نائب'} بالنيابة · ${recordedWhen(h.recordedAt, date)}';
    } else {
      final lag = h.lagDays ?? 0;
      when = lag <= 0
          ? 'سُجّلت ${recordedWhen(h.recordedAt, date)}'
          : '${lagLabel(lag)} · ${recordedWhen(h.recordedAt, date)}';
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: h.recorded
              ? () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => SupervisorHalaqaScreen(halaqa: h, date: date, kind: kind),
                    ),
                  )
              : null,
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
                        'أ. ${h.instructorName}',
                        style: const TextStyle(
                          fontFamily: 'Cairo',
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: AttendanceColors.ink,
                        ),
                      ),
                    ),
                    if (h.recorded) ...[
                      TintPill(label: 'حضر ${h.present + h.lateCount}', color: AttendanceColors.present, dense: true),
                      if (!optional && h.absent > 0) ...[
                        const SizedBox(width: 4),
                        TintPill(label: 'غاب ${h.absent}', color: AttendanceColors.absent, dense: true),
                      ],
                      const SizedBox(width: 2),
                      Icon(Icons.chevron_left_rounded, color: Colors.grey.shade400),
                    ] else
                      TintPill(label: studentsAr(h.students), color: AttendanceColors.unmarked, dense: true),
                  ],
                ),
                if (h.recorded && !optional) ...[
                  const SizedBox(height: 8),
                  Text.rich(
                    TextSpan(
                      children: absentees.isEmpty
                          ? [
                              const TextSpan(
                                text: 'ما غاب حدا',
                                style: TextStyle(color: AttendanceColors.present, fontWeight: FontWeight.bold),
                              ),
                            ]
                          : [
                              const TextSpan(
                                text: 'غابوا: ',
                                style: TextStyle(color: AttendanceColors.absent, fontWeight: FontWeight.bold),
                              ),
                              TextSpan(
                                text: joinNames(absentees, h.roster),
                                style: const TextStyle(color: AttendanceColors.ink),
                              ),
                            ],
                    ),
                    style: const TextStyle(fontFamily: 'Cairo', fontSize: 12, height: 1.8),
                  ),
                ],
                const SizedBox(height: 6),
                Text(
                  when,
                  style: TextStyle(
                    fontFamily: 'Cairo',
                    fontSize: 11.5,
                    height: 1.6,
                    color: !h.recorded && !optional
                        ? DisciplineColors.missed
                        : h.byOther
                            ? DisciplineColors.covered
                            : Colors.grey.shade700,
                    fontWeight: !h.recorded && !optional || h.byOther ? FontWeight.w600 : FontWeight.normal,
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
