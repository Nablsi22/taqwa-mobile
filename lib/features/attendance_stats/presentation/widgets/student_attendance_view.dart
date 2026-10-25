import 'package:flutter/material.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/theme/taqwa_colors.dart';
import '../../../../core/utils/meeting_days.dart';
import '../../data/attendance_stats_api.dart';
import '../../data/attendance_stats_models.dart';
import '../attendance_ui.dart';

/// A student's attendance: the course summary (ثابت / متذبذب / منقطع, how many
/// sessions attended), a call-the-family prompt after consecutive absences,
/// and a monthly calendar that lists only the meeting days — winter:
/// Saturdays and Thursdays — each with its status.
///
/// Self-contained: loads its own data, so it drops into any screen (the
/// instructor's student page today, the course director's tomorrow).
class StudentAttendanceView extends StatefulWidget {
  const StudentAttendanceView({
    super.key,
    required this.studentId,
    required this.studentName,
    this.termId,
    this.phone,
  });

  final String studentId;
  final String studentName;

  /// Course for the summary; null → the active course.
  final int? termId;

  /// Parent's phone, for the call / WhatsApp buttons. Optional.
  final String? phone;

  @override
  State<StudentAttendanceView> createState() => _StudentAttendanceViewState();
}

class _StudentAttendanceViewState extends State<StudentAttendanceView>
    with AutomaticKeepAliveClientMixin {
  final _api = AttendanceStatsApi(ApiClient.instance);

  bool _unavailable = false;

  StudentStatsResult? _summary;
  String? _summaryNote;
  bool _summaryLoading = true;

  late String _month;
  AttendanceCalendar? _calendar;
  String? _calendarError;
  bool _calendarLoading = true;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _month = monthOf(DateTime.now());
    _loadSummary();
    _loadCalendar();
  }

  @override
  void didUpdateWidget(covariant StudentAttendanceView oldWidget) {
    super.didUpdateWidget(oldWidget);
    // The page switched course (term selector): the summary follows it. The
    // calendar is by month and already spans every course.
    if (oldWidget.termId != widget.termId || oldWidget.studentId != widget.studentId) {
      _loadSummary();
      if (oldWidget.studentId != widget.studentId) _loadCalendar();
    }
  }

  Future<void> _loadSummary() async {
    setState(() {
      _summaryLoading = true;
      _summaryNote = null;
    });
    try {
      final s = await _api.getStudent(widget.studentId, termId: widget.termId);
      if (!mounted) return;
      setState(() {
        _summary = s;
        _summaryLoading = false;
      });
    } on AttendanceStatsUnavailable {
      if (!mounted) return;
      setState(() {
        _unavailable = true;
        _summaryLoading = false;
      });
    } on AttendanceStatsError catch (e) {
      if (!mounted) return;
      setState(() {
        _summary = null;
        // 404 here: the student is frozen («عزل») or no longer enrolled, so
        // the course figures do not cover him; the calendar still does.
        _summaryNote = e.isNotFound ? 'الطالب غير مشمول بإحصائيات الدورة الحالية' : e.message;
        _summaryLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _summaryNote = e.toString();
        _summaryLoading = false;
      });
    }
  }

  Future<void> _loadCalendar() async {
    setState(() {
      _calendarLoading = true;
      _calendarError = null;
    });
    final month = _month;
    try {
      final c = await _api.getCalendar(widget.studentId, month);
      if (!mounted || month != _month) return;
      setState(() {
        _calendar = c;
        _calendarLoading = false;
      });
    } on AttendanceStatsUnavailable {
      if (!mounted) return;
      setState(() {
        _unavailable = true;
        _calendarLoading = false;
      });
    } catch (e) {
      if (!mounted || month != _month) return;
      setState(() {
        _calendar = null;
        _calendarError = e.toString();
        _calendarLoading = false;
      });
    }
  }

  void _goMonth(int delta) {
    setState(() => _month = shiftMonth(_month, delta));
    _loadCalendar();
  }

  Future<void> _refresh() async {
    await Future.wait([_loadSummary(), _loadCalendar()]);
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    if (_unavailable) {
      return ListView(
        padding: const EdgeInsets.all(16),
        children: const [
          SoftCard(
            child: QuietNote(
              text: 'سجل الحضور التفصيلي والتقويم الشهري يظهران بعد تحديث الخادم.',
              icon: Icons.cloud_sync_outlined,
            ),
          ),
        ],
      );
    }

    final student = _summary?.student;
    return RefreshIndicator(
      color: TaqwaColors.domeBlue,
      onRefresh: _refresh,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
        children: [
          if (student != null && student.needsCall) ...[
            _buildCallCard(student),
            const SizedBox(height: 12),
          ],
          _buildSummary(),
          const SizedBox(height: 12),
          _buildCalendar(),
        ],
      ),
    );
  }

  // ── Call the family ────────────────────────────────────────────────

  Widget _buildCallCard(StudentStats s) {
    final trimmed = widget.phone?.trim();
    final String? phone = trimmed == null || trimmed.isEmpty ? null : trimmed;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AttendanceColors.absent.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AttendanceColors.absent.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.phone_in_talk_rounded, color: AttendanceColors.absent, size: 22),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      s.absentStreak == 2
                          ? 'غاب آخر جلستين متتاليتين'
                          : 'غاب آخر ${sessionsAr(s.absentStreak)} متتالية',
                      style: const TextStyle(
                        fontFamily: 'Cairo',
                        fontSize: 14.5,
                        fontWeight: FontWeight.bold,
                        color: AttendanceColors.absent,
                      ),
                    ),
                    Text(
                      'تواصل مع أهله واطمئن عليه',
                      style: TextStyle(fontFamily: 'Cairo', fontSize: 12, color: Colors.grey.shade700),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (phone != null) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _contactButton(
                    icon: Icons.call_rounded,
                    label: 'اتصال',
                    color: AttendanceColors.absent,
                    onTap: () => _contact(() => callPhone(phone)),
                  ),
                ),
                if (normalizeSyrianPhone(phone) != null) ...[
                  const SizedBox(width: 10),
                  Expanded(
                    child: _contactButton(
                      icon: Icons.chat_rounded,
                      label: 'واتساب',
                      color: const Color(0xFF128C7E),
                      onTap: () => _contact(() => whatsappCheckIn(phone, widget.studentName)),
                    ),
                  ),
                ],
              ],
            ),
          ] else ...[
            const SizedBox(height: 8),
            Text(
              'لا يوجد رقم هاتف مسجّل لهذا الطالب',
              style: TextStyle(fontFamily: 'Cairo', fontSize: 11.5, color: Colors.grey.shade600),
            ),
          ],
        ],
      ),
    );
  }

  Widget _contactButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Material(
      color: color,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: Colors.white, size: 18),
              const SizedBox(width: 6),
              Text(
                label,
                style: const TextStyle(
                  fontFamily: 'Cairo',
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _contact(Future<bool> Function() open) async {
    final ok = await open();
    if (!mounted || ok) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('تعذّر فتح التطبيق المطلوب', style: TextStyle(fontFamily: 'Cairo')),
        backgroundColor: Colors.red,
      ),
    );
  }

  // ── Course summary ─────────────────────────────────────────────────

  Widget _buildSummary() {
    if (_summaryLoading) {
      return const SoftCard(
        child: SizedBox(
          height: 120,
          child: Center(child: CircularProgressIndicator(color: TaqwaColors.domeBlue)),
        ),
      );
    }
    final result = _summary;
    if (result == null) {
      return SoftCard(child: QuietNote(text: _summaryNote ?? 'لا توجد بيانات حضور'));
    }

    final s = result.student;
    final c = s.course;
    final ratio = c.sessions > 0 ? (c.attended / c.sessions).clamp(0.0, 1.0) : 0.0;
    final cls = classStyle(s.classification);
    final courseName = result.course?.nameAr ?? 'الدورة الحالية';

    return SoftCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'الحضور في $courseName',
                  style: const TextStyle(
                    fontFamily: 'Cairo',
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: TaqwaColors.domeBlue,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              ClassBadge(s.classification),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${c.attended}',
                style: TextStyle(fontFamily: 'Cairo', fontSize: 30, fontWeight: FontWeight.bold, color: cls.color),
              ),
              Padding(
                padding: const EdgeInsets.only(bottom: 6, right: 6),
                child: Text(
                  'من ${sessionsAr(c.sessions)} حضرها',
                  style: TextStyle(fontFamily: 'Cairo', fontSize: 13, color: Colors.grey.shade700),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: ratio,
              minHeight: 7,
              backgroundColor: Colors.grey.shade200,
              valueColor: AlwaysStoppedAnimation<Color>(cls.color),
            ),
          ),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              CountTile(count: c.present, label: 'حاضر', color: AttendanceColors.present),
              CountTile(count: c.lateCount, label: 'متأخر', color: AttendanceColors.lateArrival),
              CountTile(count: c.absent, label: 'غائب', color: AttendanceColors.absent),
              if (c.excused > 0) CountTile(count: c.excused, label: 'بعذر', color: AttendanceColors.excused),
              if (c.unmarked > 0) CountTile(count: c.unmarked, label: 'لم يُسجَّل', color: AttendanceColors.unmarked),
            ],
          ),
          const Divider(height: 24),
          _summaryLine(
            Icons.date_range_rounded,
            s.windowSessions > 0
                ? 'آخر 4 أسابيع: حضر ${s.windowAttended} من ${sessionsAr(s.windowSessions)}'
                : 'آخر 4 أسابيع: لا جلسات مسجّلة لحلقته',
          ),
          const SizedBox(height: 4),
          _summaryLine(
            Icons.history_rounded,
            s.lastAttended != null ? 'آخر حضور: ${dayLabel(s.lastAttended)}' : 'لم يحضر أي جلسة في هذه الدورة بعد',
          ),
        ],
      ),
    );
  }

  Widget _summaryLine(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 15, color: Colors.grey.shade500),
        const SizedBox(width: 6),
        Expanded(
          child: Text(text, style: TextStyle(fontFamily: 'Cairo', fontSize: 12, color: Colors.grey.shade700)),
        ),
      ],
    );
  }

  // ── Monthly calendar ───────────────────────────────────────────────

  Widget _buildCalendar() {
    final isCurrentMonth = _month == monthOf(DateTime.now());
    return SoftCard(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              IconButton(
                tooltip: 'الشهر السابق',
                onPressed: _calendarLoading ? null : () => _goMonth(-1),
                // Icons mirror in RTL: chevron_left is drawn pointing right.
                icon: const Icon(Icons.chevron_left_rounded),
                color: TaqwaColors.domeBlue,
              ),
              Expanded(
                child: Text(
                  monthLabel(_month),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontFamily: 'Cairo',
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: TaqwaColors.domeBlue,
                  ),
                ),
              ),
              IconButton(
                tooltip: 'الشهر التالي',
                onPressed: _calendarLoading || isCurrentMonth ? null : () => _goMonth(1),
                icon: const Icon(Icons.chevron_right_rounded),
                color: TaqwaColors.domeBlue,
              ),
            ],
          ),
          if (_calendarLoading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 32),
              child: Center(child: CircularProgressIndicator(color: TaqwaColors.domeBlue)),
            )
          else if (_calendarError != null)
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                children: [
                  QuietNote(text: _calendarError!, icon: Icons.error_outline_rounded),
                  TextButton(
                    onPressed: _loadCalendar,
                    child: const Text('إعادة المحاولة', style: TextStyle(fontFamily: 'Cairo')),
                  ),
                ],
              ),
            )
          else if (_calendar != null)
            ..._buildMonth(_calendar!),
        ],
      ),
    );
  }

  List<Widget> _buildMonth(AttendanceCalendar cal) {
    final children = <Widget>[];
    final tally = <Widget>[
      if (cal.present > 0) TintPill(label: 'حاضر ${cal.present}', color: AttendanceColors.present, dense: true),
      if (cal.lateCount > 0)
        TintPill(label: 'متأخر ${cal.lateCount}', color: AttendanceColors.lateArrival, dense: true),
      if (cal.absent > 0) TintPill(label: 'غائب ${cal.absent}', color: AttendanceColors.absent, dense: true),
      if (cal.excused > 0) TintPill(label: 'بعذر ${cal.excused}', color: AttendanceColors.excused, dense: true),
      if (cal.unmarked > 0)
        TintPill(label: 'لم يُسجَّل ${cal.unmarked}', color: AttendanceColors.unmarked, dense: true),
    ];
    if (tally.isNotEmpty) {
      children.add(Padding(
        padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
        child: Wrap(spacing: 6, runSpacing: 6, alignment: WrapAlignment.center, children: tally),
      ));
    }

    if (cal.days.isEmpty) {
      children.add(const Padding(
        padding: EdgeInsets.all(16),
        child: QuietNote(text: 'لا توجد أيام دوام في هذا الشهر'),
      ));
      return children;
    }

    for (var i = 0; i < cal.days.length; i++) {
      if (i > 0) children.add(Divider(height: 1, indent: 12, endIndent: 12, color: Colors.grey.shade100));
      children.add(_dayRow(cal.days[i], cal.instructorName));
    }
    return children;
  }

  Widget _dayRow(CalendarDay day, String instructorName) {
    final d = parseIsoDay(day.date);
    final weekday = d != null ? kWeekdaysAr[d.weekday - 1] : '';
    final style = statusStyle(day.status);
    final kindTag = switch (day.kind) {
      DayKind.optional => 'اختياري',
      DayKind.extra => 'تعويض',
      DayKind.mandatory => null,
    };
    final marker = day.markedBy;
    final showMarker = marker != null && marker.isNotEmpty && marker != instructorName;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      child: Row(
        children: [
          Container(
            width: 44,
            padding: const EdgeInsets.symmetric(vertical: 4),
            decoration: BoxDecoration(
              color: style.faded ? Colors.grey.shade50 : style.color.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Column(
              children: [
                Text(
                  d != null ? '${d.day}' : '',
                  style: TextStyle(
                    fontFamily: 'Cairo',
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: style.faded ? Colors.grey.shade500 : style.color,
                    height: 1.2,
                  ),
                ),
                Text(
                  d != null ? '/${d.month}' : '',
                  style: TextStyle(fontFamily: 'Cairo', fontSize: 10, color: Colors.grey.shade500, height: 1.1),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      weekday,
                      style: TextStyle(
                        fontFamily: 'Cairo',
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: style.faded ? Colors.grey.shade500 : AttendanceColors.ink,
                      ),
                    ),
                    if (kindTag != null) ...[
                      const SizedBox(width: 6),
                      TintPill(label: kindTag, color: TaqwaColors.skyBlue, dense: true, faded: true),
                    ],
                  ],
                ),
                if (showMarker)
                  Text(
                    'سجّله: $marker',
                    style: TextStyle(fontFamily: 'Cairo', fontSize: 10.5, color: Colors.grey.shade500),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
          ),
          StatusPill(day.status),
        ],
      ),
    );
  }
}
