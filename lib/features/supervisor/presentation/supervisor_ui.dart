import 'package:flutter/material.dart';
import '../../../core/utils/meeting_days.dart';
import '../../attendance_stats/data/attendance_stats_models.dart';
import '../../attendance_stats/presentation/attendance_ui.dart';
import '../../substitute/presentation/substitute_ui.dart';
import '../data/supervisor_models.dart';

// ═══════════════════════════════════════════════════════════════════════════
// Shared look of the course director's screens.
//
// Everything is in the app's existing language — TaqwaColors, the
// attendance status colours, SoftCard and TintPill — so the director reads
// the same colour for "absent" as every أستاذ does. The one thing new here is
// the vocabulary of recording discipline: on time, late by N days, never,
// or covered by somebody else.
// ═══════════════════════════════════════════════════════════════════════════

/// Colours of recording discipline. "Covered" borrows the by-proxy violet
/// from «حلقات أخرى», so a substitute is the same colour everywhere.
class DisciplineColors {
  DisciplineColors._();

  static const Color onTime = AttendanceColors.present;
  static const Color dayLate = AttendanceColors.irregular;
  static const Color veryLate = AttendanceColors.lateArrival;
  static const Color missed = AttendanceColors.absent;
  static const Color covered = SubstituteColors.header;
  static const Color notDue = Color(0xFFCBD4DD);
}

/// What one meeting day looks like in the strip.
@immutable
class SessionLook {
  const SessionLook(this.color, this.mark, this.label, {this.onDark = true});

  final Color color;

  /// The short text inside the box: ✓, +1, ✕, …
  final String mark;

  /// A full sentence for screen readers and the أستاذ's own page.
  final String label;

  /// White text on the box; false for the pale "not due" box.
  final bool onDark;
}

SessionLook sessionLook(SessionRecord s) {
  if (s.recorded && s.byOther) {
    final who = s.markedByName == null ? 'أستاذ آخر' : 'أ. ${s.markedByName}';
    return SessionLook(DisciplineColors.covered, 'نيابة', 'سجّلها $who بالنيابة');
  }
  if (s.recorded) {
    final lag = s.lagDays ?? 0;
    if (lag <= 0) return const SessionLook(DisciplineColors.onTime, '✓', 'سجّل بنفس اليوم');
    if (lag == 1) return SessionLook(DisciplineColors.dayLate, '+1', lagLabel(lag));
    return SessionLook(DisciplineColors.veryLate, '+$lag', lagLabel(lag));
  }
  if (s.kind != DayKind.mandatory) {
    return const SessionLook(DisciplineColors.notDue, '—', 'يوم اختياري · ما بينحسب', onDark: false);
  }
  return const SessionLook(DisciplineColors.missed, '✕', 'ما سجّل');
}

/// «سجّل بعد يوم» · «بعد يومين» · «بعد 3 أيام» · «بعد 11 يوماً»
String lagLabel(int? lag) {
  if (lag == null) return 'ما سجّل';
  if (lag <= 0) return 'سجّل بنفس اليوم';
  if (lag == 1) return 'سجّل بعد يوم';
  if (lag == 2) return 'سجّل بعد يومين';
  if (lag <= 10) return 'سجّل بعد $lag أيام';
  return 'سجّل بعد $lag يوماً';
}

/// The average lag in words: «بنفس اليوم بالعادة» · «يتأخر يوم وشي».
String avgLagLabel(double? avg) {
  if (avg == null) return 'ما في تسجيل';
  if (avg < 0.25) return 'بيسجّل بنفس اليوم';
  if (avg < 0.75) return 'بيتأخر أحياناً';
  if (avg < 1.25) return 'بيتأخر يوم بالمعدل';
  if (avg < 1.75) return 'بيتأخر يوم ونص بالمعدل';
  final days = avg.round();
  return days == 2 ? 'بيتأخر يومين بالمعدل' : 'بيتأخر $days أيام بالمعدل';
}

/// '2026-10-17T16:40' → «4:40 عصراً».
String clockAr(String? localStamp) {
  if (localStamp == null || localStamp.length < 16) return '';
  final h = int.tryParse(localStamp.substring(11, 13));
  final m = localStamp.substring(14, 16);
  if (h == null) return '';
  final String period;
  if (h < 5) {
    period = 'ليلاً';
  } else if (h < 12) {
    period = 'صباحاً';
  } else if (h < 14) {
    period = 'ظهراً';
  } else if (h < 17) {
    period = 'عصراً';
  } else if (h < 20) {
    period = 'مساءً';
  } else {
    period = 'ليلاً';
  }
  final h12 = h % 12 == 0 ? 12 : h % 12;
  return '$h12:$m $period';
}

/// When it was recorded, relative to the session: «نفس اليوم · 4:40 عصراً»,
/// or for a late one «الثلاثاء 13/10 · 9:40 مساءً».
String recordedWhen(String? localStamp, String sessionDate) {
  if (localStamp == null || localStamp.length < 10) return '';
  final day = localStamp.substring(0, 10);
  final clock = clockAr(localStamp);
  if (day == sessionDate) return 'نفس اليوم · $clock';
  return '${dayLabel(day)} · $clock';
}

/// The names a substitute or the director sees: the student's own name, and
/// — only where two students of the same حلقة share it — «ابن فلان» under
/// both, so no name on a list is ever ambiguous. Anas asked for the
/// students' names without their fathers'; this keeps that everywhere a name
/// is unique.
Map<String, ({String name, String? father})> displayNames(
  Iterable<({String id, String fullName, String fatherName})> students,
) {
  final count = <String, int>{};
  for (final s in students) {
    final key = s.fullName.trim();
    count[key] = (count[key] ?? 0) + 1;
  }
  return {
    for (final s in students)
      s.id: (
        name: s.fullName.trim().isEmpty ? 'طالب' : s.fullName.trim(),
        father: (count[s.fullName.trim()] ?? 0) > 1 && s.fatherName.trim().isNotEmpty
            ? 'ابن ${s.fatherName.trim()}'
            : null,
      ),
  };
}

/// «زيد · عمر · بلال», with «ابن فلان» added only to a repeated name.
String joinNames(List<RosterEntry> people, List<RosterEntry> wholeHalaqa) {
  final names = displayNames(wholeHalaqa.map(
    (r) => (id: r.studentId, fullName: r.fullName, fatherName: r.fatherName),
  ));
  return people.map((r) {
    final n = names[r.studentId];
    if (n == null) return r.fullName;
    return n.father == null ? n.name : '${n.name} (${n.father})';
  }).join(' · ');
}

// ── Widgets ────────────────────────────────────────────────────────────────

/// The strip on the director's main screen: one box per required session,
/// oldest on the right (Arabic reading order) with its date under it, so the
/// direction is never in doubt.
class DisciplineStrip extends StatelessWidget {
  const DisciplineStrip({super.key, required this.sessions});

  final List<SessionRecord> sessions;

  @override
  Widget build(BuildContext context) {
    if (sessions.isEmpty) {
      return const QuietNote(text: 'ما في جلسات إلزامية بالدورة لهلق');
    }
    return Row(
      children: [
        for (var i = 0; i < sessions.length; i++) ...[
          if (i > 0) const SizedBox(width: 5),
          Expanded(child: _Box(session: sessions[i])),
        ],
      ],
    );
  }
}

class _Box extends StatelessWidget {
  const _Box({required this.session});

  final SessionRecord session;

  @override
  Widget build(BuildContext context) {
    final look = sessionLook(session);
    return Semantics(
      label: '${dayLabel(session.date)}: ${look.label}',
      child: ExcludeSemantics(
        child: Column(
          children: [
            Container(
              height: 26,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: look.color,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                look.mark,
                style: TextStyle(
                  fontFamily: 'Cairo',
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: look.onDark ? Colors.white : const Color(0xFF5D6D7E),
                ),
              ),
            ),
            const SizedBox(height: 3),
            Text(
              shortDate(session.date),
              style: TextStyle(
                fontFamily: 'Cairo',
                fontSize: 10,
                color: Colors.grey.shade600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The legend under the strip, shown once at the top of the main screen.
class DisciplineLegend extends StatelessWidget {
  const DisciplineLegend({super.key});

  @override
  Widget build(BuildContext context) {
    Widget item(Color c, String label) => Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 11,
              height: 11,
              decoration: BoxDecoration(color: c, borderRadius: BorderRadius.circular(3)),
            ),
            const SizedBox(width: 5),
            Text(
              label,
              style: TextStyle(fontFamily: 'Cairo', fontSize: 11, color: Colors.grey.shade700),
            ),
          ],
        );
    return Wrap(
      spacing: 12,
      runSpacing: 6,
      children: [
        item(DisciplineColors.onTime, 'نفس اليوم'),
        item(DisciplineColors.dayLate, 'بعد يوم'),
        item(DisciplineColors.veryLate, 'بعد يومين+'),
        item(DisciplineColors.missed, 'ما سجّل'),
        item(DisciplineColors.covered, 'بالنيابة'),
      ],
    );
  }
}

/// A coloured edge on a card, saying at a glance where the أستاذ stands.
Color levelColor(DisciplineLevel level) {
  switch (level) {
    case DisciplineLevel.bad:
      return DisciplineColors.missed;
    case DisciplineLevel.slipping:
      return DisciplineColors.dayLate;
    case DisciplineLevel.good:
      return DisciplineColors.onTime;
  }
}

/// A full-screen calm state: loading failed, old server, nothing yet.
class SupervisorState extends StatelessWidget {
  const SupervisorState({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.onRetry,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(28),
      children: [
        const SizedBox(height: 70),
        Icon(icon, size: 58, color: Colors.grey.shade400),
        const SizedBox(height: 14),
        Text(
          title,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontFamily: 'Cairo',
            fontSize: 15,
            fontWeight: FontWeight.bold,
            color: AttendanceColors.ink,
            height: 1.7,
          ),
        ),
        if (subtitle != null) ...[
          const SizedBox(height: 6),
          Text(
            subtitle!,
            textAlign: TextAlign.center,
            style: TextStyle(fontFamily: 'Cairo', fontSize: 12.5, color: Colors.grey.shade600, height: 1.7),
          ),
        ],
        if (onRetry != null) ...[
          const SizedBox(height: 18),
          Center(
            child: OutlinedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('إعادة المحاولة', style: TextStyle(fontFamily: 'Cairo')),
            ),
          ),
        ],
      ],
    );
  }
}

/// A section heading inside a screen.
class SectionTitle extends StatelessWidget {
  const SectionTitle(this.text, {super.key, this.color, this.count});

  final String text;
  final Color? color;
  final int? count;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 18, 4, 8),
      child: Text(
        count == null ? text : '$text · $count',
        style: TextStyle(
          fontFamily: 'Cairo',
          fontSize: 12.5,
          fontWeight: FontWeight.bold,
          color: color ?? Colors.grey.shade700,
        ),
      ),
    );
  }
}
