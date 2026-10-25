import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../core/theme/taqwa_colors.dart';
import '../../../../core/utils/meeting_days.dart';
import '../../../attendance_stats/data/attendance_stats_models.dart';
import '../../../attendance_stats/presentation/attendance_ui.dart';
import '../../data/supervisor_api.dart';
import '../../data/supervisor_models.dart';
import '../help/supervisor_help.dart';
import '../help/supervisor_prefs.dart';
import '../supervisor_ui.dart';
import '../welcome/director_identity.dart';
import '../welcome/slogan_calligraphy.dart';

/// «الرئيسية» — the director's first screen: the whole course in four cards,
/// each one sentence and one number, each opening the screen with the detail.
///
///   1. which حلقات did not record the last session;
///   2. how many students came, out of the whole course;
///   3. which students need a call;
///   4. the guide.
///
/// The three reads are the same ones the other tabs make; each card stands
/// on its own, so one failed read never blanks the others.
class SupervisorOverviewTab extends StatefulWidget {
  const SupervisorOverviewTab({
    super.key,
    required this.api,
    required this.onOpenTab,
    required this.onOpenGuide,
    this.preview = false,
  });

  final SupervisorApi api;

  /// 1 الأساتذة · 2 الجلسة · 3 الطلاب.
  final ValueChanged<int> onOpenTab;
  final VoidCallback onOpenGuide;
  final bool preview;

  @override
  State<SupervisorOverviewTab> createState() => _SupervisorOverviewTabState();
}

class _SupervisorOverviewTabState extends State<SupervisorOverviewTab> {
  bool _loading = true;
  bool _unavailable = false;
  bool _showTip = false;
  DisciplineResult? _teachers;
  SupervisedDay? _day;
  StudentsStatsResult? _students;

  @override
  void initState() {
    super.initState();
    _load();
    SupervisorPrefs.helpTipDismissed().then((dismissed) {
      if (!dismissed && mounted) setState(() => _showTip = true);
    });
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    var unavailable = 0;
    Future<T?> guard<T>(Future<T> f) async {
      try {
        return await f;
      } on SupervisorUnavailable {
        unavailable++;
        return null;
      } catch (_) {
        return null;
      }
    }

    final results = await Future.wait<Object?>([
      guard(widget.api.getInstructors()),
      guard(widget.api.getDay()),
      guard(widget.api.getStudents()),
    ]);
    if (!mounted) return;
    setState(() {
      _teachers = results[0] as DisciplineResult? ?? _teachers;
      _day = results[1] as SupervisedDay? ?? _day;
      _students = results[2] as StudentsStatsResult? ?? _students;
      _unavailable = unavailable == 3;
      _loading = false;
    });
  }

  void _dismissTip() {
    setState(() => _showTip = false);
    SupervisorPrefs.dismissHelpTip();
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      color: TaqwaColors.domeBlue,
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 24),
        children: [
          _Greeting(course: _teachers?.course ?? _day?.course, preview: widget.preview),
          if (_showTip) ...[
            const SizedBox(height: 12),
            _HelpTip(onDismiss: _dismissTip),
          ],
          const SectionTitle('خلاصة الدورة', help: HelpTopic.overview),
          if (_unavailable)
            const SoftCard(
              child: QuietNote(
                icon: Icons.cloud_off_rounded,
                text: 'لوحة مدير الدورة تظهر بعد تحديث الخادم.',
              ),
            )
          else ...[
            _teachersCard(),
            _attendanceCard(),
            _studentsCard(),
          ],
          _GuideCard(onOpen: widget.onOpenGuide),
        ],
      ),
    );
  }

  // ── 1. Recording ───────────────────────────────────────────────────────

  Widget _teachersCard() {
    final r = _teachers;
    if (r == null) return _placeholder(Icons.groups_rounded, 'تسجيل الأساتذة للحضور', HelpTopic.instructors);
    final s = r.summary;
    final last = r.lastSession;
    final missing = last == null
        ? const <InstructorDiscipline>[]
        : r.instructors
            .where((d) => d.sessions.isNotEmpty && d.sessions.last.date == last && !d.sessions.last.recorded)
            .toList();
    final allDone = s.notRecorded == 0;
    return _StatCard(
      icon: Icons.groups_rounded,
      color: allDone ? DisciplineColors.onTime : DisciplineColors.missed,
      title: 'تسجيل الأساتذة للحضور',
      caption: last == null ? null : 'آخر جلسة إلزامية: ${dayLabel(last)}',
      big: allDone ? '✓' : '${s.notRecorded}',
      headline: last == null
          ? 'لا توجد جلسات إلزامية في الدورة حتى الآن'
          : allDone
              ? 'سجّلت جميع الحلقات (${s.halaqas}) حضور آخر جلسة'
              : 'من ${s.halaqas} حلقات لم تسجّل حضور آخر جلسة',
      detail: missing.isEmpty
          ? null
          : _Names(
              names: missing.map((d) => 'أ. ${d.instructorName}').toList(),
              color: DisciplineColors.missed,
            ),
      action: 'عرض الأساتذة',
      help: HelpTopic.instructors,
      onTap: () => widget.onOpenTab(1),
    );
  }

  // ── 2. Attendance of the latest session ────────────────────────────────

  Widget _attendanceCard() {
    final d = _day;
    if (d == null) return _placeholder(Icons.how_to_reg_rounded, 'حضور الطلاب', HelpTopic.day);
    if (d.date == null) {
      return _StatCard(
        icon: Icons.how_to_reg_rounded,
        color: TaqwaColors.skyBlue,
        title: 'حضور الطلاب',
        big: '—',
        headline: d.message ?? 'لا توجد جلسة مسجّلة في هذه الدورة بعد',
        action: 'عرض الجلسة',
        help: HelpTopic.day,
        onTap: () => widget.onOpenTab(2),
      );
    }
    final recorded = d.halaqas.where((h) => h.recorded).toList();
    final waiting = d.halaqas.length - recorded.length;
    int sum(int Function(SupervisedHalaqa) f) => recorded.fold(0, (t, h) => t + f(h));
    final all = d.halaqas.fold(0, (t, h) => t + h.students);
    final came = sum((h) => h.present + h.lateCount);
    final optional = d.kind == DayKind.optional || d.kind == DayKind.extra;
    return _StatCard(
      icon: Icons.how_to_reg_rounded,
      color: AttendanceColors.present,
      title: 'حضور الطلاب',
      caption: '${dayLabel(d.date)} · ${optional ? 'يوم اختياري' : 'يوم إلزامي'}',
      big: '$came',
      headline: 'حضروا من أصل ${studentsAr(all)} في الدورة',
      detail: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
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
          if (waiting > 0) ...[
            const SizedBox(height: 8),
            QuietNote(
              icon: Icons.hourglass_bottom_rounded,
              text: '${_halaqasAr(waiting)} لم تسجّل هذا اليوم بعد، فقد يزيد العدد.',
            ),
          ],
        ],
      ),
      action: 'عرض الجلسة',
      help: HelpTopic.day,
      onTap: () => widget.onOpenTab(2),
    );
  }

  // ── 3. Students who need a call ────────────────────────────────────────

  Widget _studentsCard() {
    final r = _students;
    if (r == null) return _placeholder(Icons.phone_in_talk_rounded, 'طلاب يحتاجون إلى اتصال', HelpTopic.needsCall);
    final students = r.students;
    int count(AttendanceClass c) => students.where((s) => s.classification == c).length;
    final needsCall = students.where((s) => s.needsCall).toList();
    final active = count(AttendanceClass.regular) + count(AttendanceClass.irregular);
    final none = needsCall.isEmpty;
    return _StatCard(
      icon: Icons.phone_in_talk_rounded,
      color: none ? AttendanceColors.present : AttendanceColors.absent,
      title: 'طلاب يحتاجون إلى اتصال',
      caption: 'غابوا جلستين إلزاميتين متتاليتين أو أكثر دون عذر',
      big: none ? '✓' : '${needsCall.length}',
      headline: none ? 'لا يوجد طالب يحتاج إلى اتصال الآن' : (needsCall.length == 1 ? 'طالب يحتاج إلى اتصال' : 'طلاب يحتاجون إلى اتصال'),
      detail: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!none)
            _Names(names: needsCall.map((s) => s.fullName).toList(), color: AttendanceColors.absent),
          if (!none) const SizedBox(height: 8),
          Text(
            'النشِطون: $active من ${students.length} · المنقطعون: ${count(AttendanceClass.inactive)}',
            style: TextStyle(fontFamily: 'Cairo', fontSize: 12.5, color: Colors.grey.shade700),
          ),
        ],
      ),
      action: 'عرض الطلاب',
      help: HelpTopic.needsCall,
      onTap: () => widget.onOpenTab(3),
    );
  }

  Widget _placeholder(IconData icon, String title, HelpTopic help) {
    return _StatCard(
      icon: icon,
      color: Colors.grey,
      title: title,
      big: '…',
      headline: _loading ? 'جارٍ التحميل…' : 'تعذّر التحميل — اسحب الصفحة إلى الأسفل لإعادة المحاولة',
      action: 'إعادة المحاولة',
      help: help,
      onTap: _load,
    );
  }
}

/// «حلقة واحدة» · «حلقتان» · «3 حلقات» · «11 حلقة».
String _halaqasAr(int n) {
  if (n == 1) return 'حلقة واحدة';
  if (n == 2) return 'حلقتان';
  if (n % 100 >= 3 && n % 100 <= 10) return '$n حلقات';
  return '$n حلقة';
}

class _Greeting extends StatelessWidget {
  const _Greeting({required this.course, required this.preview});

  static const _champagne = Color(0xFFCDB988);

  final CourseRef? course;
  final bool preview;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        gradient: const LinearGradient(
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
          // The welcome screen's night blue, so the two read as one.
          colors: [Color(0xFF18304A), Color(0xFF0E1C2E)],
        ),
        boxShadow: [
          BoxShadow(color: const Color(0xFF0C1624).withValues(alpha: 0.22), blurRadius: 18, offset: const Offset(0, 8)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'السلام عليكم ورحمة الله وبركاته',
            style: TextStyle(fontFamily: 'Cairo', fontSize: 12.5, color: const Color(0xFFF4EEE3).withValues(alpha: 0.72)),
          ),
          const SizedBox(height: 4),
          Text(
            kDirectorTitle,
            style: const TextStyle(fontFamily: 'Cairo', fontSize: 13, color: _champagne, fontWeight: FontWeight.w600),
          ),
          Text(
            kDirectorName,
            style: const TextStyle(fontFamily: 'Amiri', fontSize: 21, fontWeight: FontWeight.w700, color: Color(0xFFF4EEE3), height: 1.5),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              if (course != null) _chip(Icons.event_available_rounded, course!.nameAr),
              _chip(preview ? Icons.visibility_rounded : Icons.lock_outline_rounded, preview ? 'معاينة' : 'للاطلاع فقط'),
            ],
          ),
          const SizedBox(height: 12),
          Center(
            child: LayoutBuilder(
              builder: (context, box) => SizedBox(
                width: math.min(250, box.maxWidth),
                child: const SloganCalligraphy(showNib: false, color: _champagne, highlight: Color(0xFFEFE3C3)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _chip(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.22)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: Colors.white),
          const SizedBox(width: 4),
          Text(text, style: const TextStyle(fontFamily: 'Cairo', fontSize: 11.5, color: Colors.white, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

class _HelpTip extends StatelessWidget {
  const _HelpTip({required this.onDismiss});

  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 6),
      decoration: BoxDecoration(
        color: TaqwaColors.lightGold,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: TaqwaColors.minaretGold.withValues(alpha: 0.45)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.lightbulb_rounded, color: TaqwaColors.minaretGold),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'بجانب كل عنوان زر «شرح» يوضّح معناه بكلمات بسيطة، '
                  'وفي أعلى الشاشة زر «الدليل» فيه شرح مفصّل لكل ما يمكنك معرفته.',
                  style: TextStyle(fontFamily: 'Cairo', fontSize: 13, height: 1.8, color: Color(0xFF6E5A0A)),
                ),
              ),
            ],
          ),
          Align(
            alignment: AlignmentDirectional.centerEnd,
            child: TextButton(
              onPressed: onDismiss,
              child: const Text('فهمت', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }
}

/// One card of the home screen: what it is, one number, one sentence, and
/// where to go next. The whole card is the button.
class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.icon,
    required this.color,
    required this.title,
    this.caption,
    required this.big,
    required this.headline,
    this.detail,
    required this.action,
    required this.help,
    required this.onTap,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String? caption;
  final String big;
  final String headline;
  final Widget? detail;
  final String action;
  final HelpTopic help;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        clipBehavior: Clip.antiAlias,
        elevation: 0,
        child: InkWell(
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
            decoration: BoxDecoration(
              border: BorderDirectional(start: BorderSide(color: color, width: 4)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(color: color.withValues(alpha: 0.12), shape: BoxShape.circle),
                      child: Icon(icon, color: color, size: 21),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        title,
                        style: const TextStyle(
                          fontFamily: 'Cairo',
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: AttendanceColors.ink,
                        ),
                      ),
                    ),
                    HelpChip(help),
                  ],
                ),
                if (caption != null)
                  Padding(
                    padding: const EdgeInsetsDirectional.only(start: 48, top: 2),
                    child: Text(
                      caption!,
                      style: TextStyle(fontFamily: 'Cairo', fontSize: 12, color: Colors.grey.shade600),
                    ),
                  ),
                const SizedBox(height: 10),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Text(
                      big,
                      style: TextStyle(
                        fontFamily: 'Cairo',
                        fontSize: 34,
                        fontWeight: FontWeight.bold,
                        height: 1.1,
                        color: color,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        headline,
                        style: const TextStyle(
                          fontFamily: 'Cairo',
                          fontSize: 14.5,
                          fontWeight: FontWeight.bold,
                          height: 1.6,
                          color: AttendanceColors.ink,
                        ),
                      ),
                    ),
                  ],
                ),
                if (detail != null) ...[
                  const SizedBox(height: 10),
                  detail!,
                ],
                const SizedBox(height: 4),
                Align(
                  alignment: AlignmentDirectional.centerEnd,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          action,
                          style: const TextStyle(
                            fontFamily: 'Cairo',
                            fontSize: 13.5,
                            fontWeight: FontWeight.bold,
                            color: TaqwaColors.domeBlue,
                          ),
                        ),
                        const SizedBox(width: 4),
                        const Icon(Icons.arrow_forward_rounded, size: 18, color: TaqwaColors.domeBlue),
                      ],
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

/// Up to five names, then «و3 آخرون».
class _Names extends StatelessWidget {
  const _Names({required this.names, required this.color});

  final List<String> names;
  final Color color;

  static const _max = 5;

  @override
  Widget build(BuildContext context) {
    final shown = names.take(_max).toList();
    final rest = names.length - shown.length;
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        for (final n in shown)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(n, style: TextStyle(fontFamily: 'Cairo', fontSize: 12.5, fontWeight: FontWeight.w600, color: color)),
          ),
        if (rest > 0)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 3),
            child: Text(
              rest == 1 ? 'وواحد آخر' : (rest == 2 ? 'واثنان آخران' : 'و$rest آخرون'),
              style: TextStyle(fontFamily: 'Cairo', fontSize: 12.5, color: Colors.grey.shade600),
            ),
          ),
      ],
    );
  }
}

class _GuideCard extends StatelessWidget {
  const _GuideCard({required this.onOpen});

  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    return Material(
      borderRadius: BorderRadius.circular(20),
      clipBehavior: Clip.antiAlias,
      color: TaqwaColors.lightGold,
      child: InkWell(
        onTap: onOpen,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: const BoxDecoration(color: TaqwaColors.minaretGold, shape: BoxShape.circle),
                child: const Icon(Icons.auto_stories_rounded, color: Colors.white, size: 26),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'دليل الاستخدام',
                      style: TextStyle(fontFamily: 'Cairo', fontSize: 15.5, fontWeight: FontWeight.bold, color: AttendanceColors.ink),
                    ),
                    Text(
                      'شرح سهل ومفصّل لكل ما يمكنك معرفته من هذا الحساب، وأين تجده.',
                      style: TextStyle(fontFamily: 'Cairo', fontSize: 12.5, height: 1.7, color: Color(0xFF6E5A0A)),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded, color: Color(0xFF6E5A0A)),
            ],
          ),
        ),
      ),
    );
  }
}
