import 'package:flutter/material.dart';
import '../../../../core/theme/taqwa_colors.dart';
import '../../../../core/utils/meeting_days.dart';
import '../../../attendance_stats/data/attendance_stats_models.dart';
import '../../../attendance_stats/presentation/attendance_ui.dart';

/// The instructor's last session at a glance: who came, who was absent and
/// how often each absentee has been absent this course, and whether anything
/// is still left to record.
///
/// The session is the course's last required day with records — on a
/// Tuesday in winter that is the Saturday before. Purely presentational: the
/// dashboard loads [day] and handles the callbacks.
class LastSessionCard extends StatelessWidget {
  const LastSessionCard({
    super.key,
    required this.day,
    required this.instructorId,
    required this.canRecord,
    required this.onRecord,
    required this.onOpenStudent,
    required this.onOpenStats,
    this.error,
    this.onRetry,
  });

  /// null while loading (with no [error]).
  final AttendanceDay? day;
  final String? instructorId;

  /// False while browsing an archived course: nothing is recorded from here.
  final bool canRecord;

  /// Opens the attendance sheet on the given day (YYYY-MM-DD), or on the
  /// default day when null.
  final void Function(String? date) onRecord;
  final void Function(RosterEntry student) onOpenStudent;
  final VoidCallback onOpenStats;

  final String? error;
  final VoidCallback? onRetry;

  static const _maxAbsenteesShown = 8;

  HalaqaDay? get _halaqa {
    final d = day;
    if (d == null || d.halaqas.isEmpty) return null;
    for (final h in d.halaqas) {
      if (h.instructorId == instructorId) return h;
    }
    return d.halaqas.first;
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 0),
      child: SoftCard(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
        child: _content(context),
      ),
    );
  }

  Widget _content(BuildContext context) {
    if (error != null) {
      return Row(
        children: [
          Expanded(child: QuietNote(text: error!, icon: Icons.cloud_off_rounded)),
          if (onRetry != null)
            IconButton(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded, color: TaqwaColors.domeBlue),
              tooltip: 'إعادة المحاولة',
            ),
        ],
      );
    }

    final d = day;
    if (d == null) {
      return const SizedBox(
        height: 72,
        child: Center(
          child: SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(strokeWidth: 2, color: TaqwaColors.domeBlue),
          ),
        ),
      );
    }

    final date = d.date;
    if (date == null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _header(context, null),
          const SizedBox(height: 12),
          QuietNote(text: d.message ?? 'لم تُسجَّل أي جلسة في هذه الدورة بعد'),
          if (canRecord) ...[
            const SizedBox(height: 12),
            _actionStrip(
              text: 'ابدأ بتسجيل حضور الحلقة',
              button: 'سجّل الحضور',
              color: TaqwaColors.domeBlue,
              icon: Icons.edit_calendar_rounded,
              onTap: () => onRecord(null),
            ),
          ],
        ],
      );
    }

    final h = _halaqa;
    if (h == null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _header(context, date),
          const SizedBox(height: 12),
          const QuietNote(text: 'لا يوجد طلاب في حلقتك لهذه الدورة'),
        ],
      );
    }

    final absentees = h.roster.where((r) => r.status == 'ABSENT').toList()
      ..sort((a, b) {
        final byStreak = b.absentStreak.compareTo(a.absentStreak);
        if (byStreak != 0) return byStreak;
        final byCount = b.absences.compareTo(a.absences);
        if (byCount != 0) return byCount;
        return a.fullName.compareTo(b.fullName);
      });
    final excused = h.roster.where((r) => r.status == 'EXCUSED').toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _header(context, date),
        const SizedBox(height: 14),
        _counts(h),
        if (h.notRecorded && canRecord) ...[
          const SizedBox(height: 14),
          _actionStrip(
            text: 'لم يُسجَّل حضور حلقتك في هذه الجلسة',
            button: 'سجّل الآن',
            color: AttendanceColors.absent,
            icon: Icons.edit_calendar_rounded,
            onTap: () => onRecord(date),
          ),
        ] else if (h.unmarked > 0 && canRecord) ...[
          const SizedBox(height: 14),
          _actionStrip(
            text: '${studentsAr(h.unmarked)} بلا تسجيل في هذه الجلسة',
            button: 'أكمل التسجيل',
            color: AttendanceColors.irregular,
            icon: Icons.playlist_add_check_rounded,
            onTap: () => onRecord(date),
          ),
        ],
        if (h.coveredBy.isNotEmpty) ...[
          const SizedBox(height: 12),
          QuietNote(
            text: 'سجّل بعض طلابك: ${h.coveredBy.join('، ')}',
            icon: Icons.handshake_outlined,
          ),
        ],
        if (!h.notRecorded) ...[
          const SizedBox(height: 14),
          Divider(height: 1, color: Colors.grey.shade200),
          const SizedBox(height: 12),
          if (absentees.isEmpty)
            Row(
              children: [
                const Icon(Icons.verified_rounded, size: 18, color: AttendanceColors.present),
                const SizedBox(width: 8),
                Text(
                  'لا يوجد غائبون في هذه الجلسة',
                  style: TextStyle(fontFamily: 'Cairo', fontSize: 13, color: Colors.grey.shade700),
                ),
              ],
            )
          else ...[
            Row(
              children: [
                const Text(
                  'الغائبون',
                  style: TextStyle(
                    fontFamily: 'Cairo',
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: AttendanceColors.ink,
                  ),
                ),
                const SizedBox(width: 8),
                TintPill(label: '${absentees.length}', color: AttendanceColors.absent, dense: true),
              ],
            ),
            const SizedBox(height: 4),
            for (final r in absentees.take(_maxAbsenteesShown)) _absenteeRow(r),
            if (absentees.length > _maxAbsenteesShown)
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: TextButton(
                  onPressed: onOpenStats,
                  child: Text(
                    'و${absentees.length - _maxAbsenteesShown} آخرون — عرض الكل',
                    style: const TextStyle(fontFamily: 'Cairo', fontSize: 12.5),
                  ),
                ),
              ),
          ],
          if (excused.isNotEmpty) ...[
            const SizedBox(height: 8),
            QuietNote(
              text: 'غائب بعذر: ${excused.map((r) => r.fullName).join('، ')}',
              icon: Icons.event_busy_rounded,
            ),
          ],
        ],
      ],
    );
  }

  Widget _header(BuildContext context, String? date) {
    final isToday = date != null && date == isoDay(DateTime.now());
    return Row(
      children: [
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: TaqwaColors.domeBlue.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(Icons.event_note_rounded, color: TaqwaColors.domeBlue, size: 20),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                isToday ? 'جلسة اليوم' : 'آخر جلسة',
                style: TextStyle(fontFamily: 'Cairo', fontSize: 11.5, color: Colors.grey.shade600),
              ),
              Text(
                date == null ? '—' : dayLabel(date),
                style: const TextStyle(
                  fontFamily: 'Cairo',
                  fontSize: 15.5,
                  fontWeight: FontWeight.bold,
                  color: AttendanceColors.ink,
                ),
              ),
            ],
          ),
        ),
        TextButton.icon(
          onPressed: onOpenStats,
          style: TextButton.styleFrom(
            foregroundColor: TaqwaColors.domeBlue,
            padding: const EdgeInsets.symmetric(horizontal: 10),
          ),
          icon: const Icon(Icons.insights_rounded, size: 18),
          label: const Text(
            'إحصائيات الحلقة',
            style: TextStyle(fontFamily: 'Cairo', fontSize: 12.5, fontWeight: FontWeight.w600),
          ),
        ),
      ],
    );
  }

  Widget _counts(HalaqaDay h) {
    final tiles = <Widget>[
      CountTile(count: h.present, label: 'حاضر', color: AttendanceColors.present),
      CountTile(count: h.lateCount, label: 'متأخر', color: AttendanceColors.lateArrival),
      CountTile(count: h.absent, label: 'غائب', color: AttendanceColors.absent),
      if (h.excused > 0) CountTile(count: h.excused, label: 'بعذر', color: AttendanceColors.excused),
      if (h.unmarked > 0) CountTile(count: h.unmarked, label: 'لم يُسجَّل', color: AttendanceColors.unmarked),
    ];
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF7F8FB),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [for (final t in tiles) Expanded(child: t)],
      ),
    );
  }

  Widget _actionStrip({
    required String text,
    required String button,
    required Color color,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return Container(
      padding: const EdgeInsetsDirectional.fromSTEB(12, 6, 6, 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontFamily: 'Cairo',
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: color,
                height: 1.5,
              ),
            ),
          ),
          const SizedBox(width: 6),
          FilledButton(
            onPressed: onTap,
            style: FilledButton.styleFrom(
              backgroundColor: color,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              minimumSize: const Size(0, 36),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: Text(
              button,
              style: const TextStyle(fontFamily: 'Cairo', fontSize: 12.5, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  Widget _absenteeRow(RosterEntry r) {
    final streak = r.absentStreak;
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: () => onOpenStudent(r),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            CircleAvatar(
              radius: 15,
              backgroundColor: AttendanceColors.absent.withValues(alpha: 0.1),
              child: Text(
                r.fullName.isNotEmpty ? r.fullName[0] : '?',
                style: const TextStyle(
                  fontFamily: 'Cairo',
                  fontSize: 12.5,
                  fontWeight: FontWeight.bold,
                  color: AttendanceColors.absent,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    r.fullName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontFamily: 'Cairo',
                      fontSize: 13.5,
                      fontWeight: FontWeight.w600,
                      color: AttendanceColors.ink,
                    ),
                  ),
                  if (r.absences > 0)
                    Text(
                      'غاب ${timesAr(r.absences)} هذه الدورة',
                      style: TextStyle(fontFamily: 'Cairo', fontSize: 11.5, color: Colors.grey.shade600),
                    ),
                ],
              ),
            ),
            if (streak >= 2) ...[
              const SizedBox(width: 6),
              TintPill(
                label: consecutiveAr(streak),
                color: AttendanceColors.absent,
                icon: Icons.phone_in_talk_rounded,
                dense: true,
              ),
            ],
            const SizedBox(width: 4),
            Icon(Icons.chevron_left_rounded, size: 18, color: Colors.grey.shade400),
          ],
        ),
      ),
    );
  }
}
