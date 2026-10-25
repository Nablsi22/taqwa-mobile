import 'package:flutter/material.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/theme/taqwa_colors.dart';
import '../../../attendance_stats/data/attendance_stats_api.dart';
import '../../../attendance_stats/data/attendance_stats_models.dart';
import '../../../attendance_stats/presentation/attendance_ui.dart';
import 'instructor_student_detail_screen.dart';

/// Attendance of the instructor's whole حلقة over the course: who is ثابت,
/// متذبذب or منقطع, who needs a call home, and how many sessions each one
/// attended. The server returns only the instructor's own students.
class HalaqaAttendanceScreen extends StatefulWidget {
  const HalaqaAttendanceScreen({super.key, this.termId});

  /// Course to show; null → the active course.
  final int? termId;

  @override
  State<HalaqaAttendanceScreen> createState() => _HalaqaAttendanceScreenState();
}

enum _Filter { all, regular, irregular, inactive, needsCall }

enum _Sort { mostAbsent, name, lastAttended }

class _HalaqaAttendanceScreenState extends State<HalaqaAttendanceScreen> {
  final _api = AttendanceStatsApi(ApiClient.instance);

  bool _loading = true;
  bool _unavailable = false;
  String? _error;
  StudentsStatsResult? _result;

  _Filter _filter = _Filter.all;
  _Sort _sort = _Sort.mostAbsent;

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
      final r = await _api.getStudents(termId: widget.termId);
      if (!mounted) return;
      setState(() {
        _result = r;
        _loading = false;
      });
    } on AttendanceStatsUnavailable {
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

  List<StudentStats> get _students => _result?.students ?? const [];

  int _count(_Filter f) => _students.where((s) => _matches(s, f)).length;

  bool _matches(StudentStats s, _Filter f) {
    switch (f) {
      case _Filter.all:
        return true;
      case _Filter.regular:
        return s.classification == AttendanceClass.regular;
      case _Filter.irregular:
        return s.classification == AttendanceClass.irregular;
      case _Filter.inactive:
        return s.classification == AttendanceClass.inactive;
      case _Filter.needsCall:
        return s.needsCall;
    }
  }

  List<StudentStats> get _visible {
    final list = _students.where((s) => _matches(s, _filter)).toList();
    switch (_sort) {
      case _Sort.mostAbsent:
        list.sort((a, b) {
          final byStreak = b.absentStreak.compareTo(a.absentStreak);
          if (byStreak != 0) return byStreak;
          final byAbsent = b.course.absent.compareTo(a.course.absent);
          if (byAbsent != 0) return byAbsent;
          return a.fullName.compareTo(b.fullName);
        });
        break;
      case _Sort.name:
        list.sort((a, b) => a.fullName.compareTo(b.fullName));
        break;
      case _Sort.lastAttended:
        // Longest away first; never attended leads.
        list.sort((a, b) {
          final x = a.lastAttended;
          final y = b.lastAttended;
          if (x == null && y == null) return a.fullName.compareTo(b.fullName);
          if (x == null) return -1;
          if (y == null) return 1;
          return x.compareTo(y);
        });
        break;
    }
    return list;
  }

  void _openStudent(StudentStats s) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => InstructorStudentDetailScreen(
          studentId: s.studentId,
          studentName: s.fullName,
          initialTab: InstructorStudentDetailScreen.attendanceTab,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFFF5F6FA),
        appBar: AppBar(
          title: const Text(
            'إحصائيات حضور الحلقة',
            style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold),
          ),
          backgroundColor: TaqwaColors.domeBlue,
          foregroundColor: Colors.white,
          elevation: 0,
        ),
        body: _body(),
      ),
    );
  }

  Widget _body() {
    if (_loading && _result == null) {
      return const Center(child: CircularProgressIndicator(color: TaqwaColors.domeBlue));
    }
    if (_unavailable) {
      return ListView(
        padding: const EdgeInsets.all(16),
        children: const [
          SoftCard(
            child: QuietNote(
              text: 'إحصائيات الحضور تظهر بعد تحديث الخادم.',
              icon: Icons.cloud_sync_outlined,
            ),
          ),
        ],
      );
    }
    if (_error != null && _result == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.error_outline, size: 56, color: Colors.red.shade300),
              const SizedBox(height: 12),
              Text(_error!, textAlign: TextAlign.center, style: const TextStyle(fontFamily: 'Cairo')),
              const SizedBox(height: 12),
              ElevatedButton.icon(
                onPressed: _load,
                icon: const Icon(Icons.refresh),
                label: const Text('إعادة المحاولة', style: TextStyle(fontFamily: 'Cairo')),
                style: ElevatedButton.styleFrom(
                  backgroundColor: TaqwaColors.domeBlue,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
        ),
      );
    }

    final visible = _visible;
    final needsCall = _count(_Filter.needsCall);

    return RefreshIndicator(
      color: TaqwaColors.domeBlue,
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          _summaryCard(),
          if (needsCall > 0) ...[
            const SizedBox(height: 12),
            _needsCallBanner(needsCall),
          ],
          const SizedBox(height: 16),
          _filterChips(),
          const SizedBox(height: 10),
          _sortRow(),
          const SizedBox(height: 6),
          if (visible.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 32),
              child: Center(
                child: Text(
                  _students.isEmpty ? 'لا يوجد طلاب في حلقتك' : 'لا يوجد طلاب في هذا التصنيف',
                  style: TextStyle(fontFamily: 'Cairo', color: Colors.grey.shade500),
                ),
              ),
            )
          else
            for (final s in visible) _studentRow(s),
        ],
      ),
    );
  }

  Widget _summaryCard() {
    final r = _result;
    final windowStart = r?.windowStart;
    final noData = _students.where((s) => s.classification == AttendanceClass.noData).length;
    return SoftCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.groups_rounded, color: TaqwaColors.domeBlue, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  r?.course?.nameAr ?? 'الدورة الحالية',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontFamily: 'Cairo',
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: AttendanceColors.ink,
                  ),
                ),
              ),
              TintPill(label: '${_students.length} طالب', color: TaqwaColors.domeBlue, dense: true),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: CountTile(
                  count: _count(_Filter.regular),
                  label: 'ثابت',
                  color: AttendanceColors.present,
                ),
              ),
              Expanded(
                child: CountTile(
                  count: _count(_Filter.irregular),
                  label: 'متذبذب',
                  color: AttendanceColors.irregular,
                ),
              ),
              Expanded(
                child: CountTile(
                  count: _count(_Filter.inactive),
                  label: 'منقطع',
                  color: AttendanceColors.absent,
                ),
              ),
              if (noData > 0)
                Expanded(
                  child: CountTile(count: noData, label: 'بلا بيانات', color: AttendanceColors.unmarked),
                ),
            ],
          ),
          const SizedBox(height: 12),
          QuietNote(
            text: windowStart == null
                ? 'ثابت: غاب جلسة واحدة على الأكثر في آخر 4 أسابيع · منقطع: لم يحضر أي جلسة فيها'
                : 'آخر 4 أسابيع (منذ ${shortDate(windowStart)}) — ثابت: غاب جلسة واحدة على الأكثر · '
                    'منقطع: لم يحضر أي جلسة',
          ),
        ],
      ),
    );
  }

  Widget _needsCallBanner(int n) {
    final selected = _filter == _Filter.needsCall;
    return Material(
      color: AttendanceColors.absent.withValues(alpha: 0.07),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => setState(() => _filter = selected ? _Filter.all : _Filter.needsCall),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AttendanceColors.absent.withValues(alpha: 0.25)),
          ),
          child: Row(
            children: [
              const Icon(Icons.phone_in_talk_rounded, color: AttendanceColors.absent, size: 22),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  n == 1
                      ? 'طالب واحد غاب جلستين متتاليتين أو أكثر — يُستحسن الاتصال بأهله'
                      : '${studentsAr(n)} غابوا جلستين متتاليتين أو أكثر — يُستحسن الاتصال بأهلهم',
                  style: const TextStyle(
                    fontFamily: 'Cairo',
                    fontSize: 12.5,
                    height: 1.6,
                    fontWeight: FontWeight.w600,
                    color: AttendanceColors.absent,
                  ),
                ),
              ),
              Icon(
                selected ? Icons.close_rounded : Icons.chevron_left_rounded,
                color: AttendanceColors.absent,
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _filterChips() {
    Widget chip(_Filter f, String label, Color color) {
      final selected = _filter == f;
      final n = _count(f);
      return Padding(
        padding: const EdgeInsetsDirectional.only(end: 6),
        child: ChoiceChip(
          selected: selected,
          onSelected: (_) => setState(() => _filter = f),
          showCheckmark: false,
          label: Text('$label ($n)'),
          labelStyle: TextStyle(
            fontFamily: 'Cairo',
            fontSize: 12,
            fontWeight: selected ? FontWeight.bold : FontWeight.normal,
            color: selected ? Colors.white : color,
          ),
          selectedColor: color,
          backgroundColor: color.withValues(alpha: 0.07),
          side: BorderSide(color: color.withValues(alpha: selected ? 0 : 0.25)),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          visualDensity: VisualDensity.compact,
        ),
      );
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          chip(_Filter.all, 'الكل', TaqwaColors.domeBlue),
          chip(_Filter.regular, 'ثابت', AttendanceColors.present),
          chip(_Filter.irregular, 'متذبذب', AttendanceColors.irregular),
          chip(_Filter.inactive, 'منقطع', AttendanceColors.absent),
          chip(_Filter.needsCall, 'يحتاج اتصال', AttendanceColors.absent),
        ],
      ),
    );
  }

  Widget _sortRow() {
    Widget option(_Sort s, String label) {
      final selected = _sort == s;
      return Padding(
        padding: const EdgeInsetsDirectional.only(end: 4),
        child: TextButton(
          onPressed: selected ? null : () => setState(() => _sort = s),
          style: TextButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            minimumSize: const Size(0, 32),
            disabledForegroundColor: TaqwaColors.domeBlue,
            foregroundColor: Colors.grey.shade600,
          ),
          child: Text(
            label,
            style: TextStyle(
              fontFamily: 'Cairo',
              fontSize: 12,
              fontWeight: selected ? FontWeight.bold : FontWeight.normal,
              decoration: selected ? TextDecoration.underline : TextDecoration.none,
            ),
          ),
        ),
      );
    }

    return Row(
      children: [
        Icon(Icons.sort_rounded, size: 16, color: Colors.grey.shade500),
        const SizedBox(width: 4),
        Expanded(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                option(_Sort.mostAbsent, 'الأكثر غياباً'),
                option(_Sort.name, 'الاسم'),
                option(_Sort.lastAttended, 'آخر حضور'),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _studentRow(StudentStats s) {
    final c = s.course;
    final style = classStyle(s.classification);
    final details = <String>[
      c.sessions == 0 ? 'لا جلسات محسوبة بعد' : 'حضر ${c.attended} من ${sessionsAr(c.sessions)}',
      if (c.absent > 0) 'غاب ${timesAr(c.absent)}',
      if (c.excused > 0) 'بعذر ${c.excused}',
    ];
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () => _openStudent(s),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 8, 12),
            child: Row(
              children: [
                Container(
                  width: 4,
                  height: 40,
                  decoration: BoxDecoration(
                    color: style.color,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              s.fullName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontFamily: 'Cairo',
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: AttendanceColors.ink,
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          ClassBadge(s.classification, dense: true),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(
                        details.join(' · '),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontFamily: 'Cairo', fontSize: 11.5, color: Colors.grey.shade600),
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              s.lastAttended == null ? 'لم يحضر بعد' : 'آخر حضور: ${dayLabel(s.lastAttended)}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(fontFamily: 'Cairo', fontSize: 11, color: Colors.grey.shade500),
                            ),
                          ),
                          if (s.needsCall)
                            TintPill(
                              label: 'غاب ${consecutiveAr(s.absentStreak)}',
                              color: AttendanceColors.absent,
                              icon: Icons.phone_in_talk_rounded,
                              dense: true,
                            ),
                        ],
                      ),
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
