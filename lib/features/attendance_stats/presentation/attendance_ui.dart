import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/theme/taqwa_colors.dart';
import '../../../core/utils/meeting_days.dart';
import '../data/attendance_stats_models.dart';

// ═══════════════════════════════════════════════════════════════════════════
// Shared look of attendance across the app: one colour and one word per
// status and per class, Arabic dates, and the call / WhatsApp actions.
// ═══════════════════════════════════════════════════════════════════════════

class AttendanceColors {
  AttendanceColors._();

  static const present = Color(0xFF1E8449);
  static const lateArrival = Color(0xFFE67E22);
  static const absent = Color(0xFFC0392B);
  static const excused = Color(0xFF8E44AD);
  static const unmarked = Color(0xFF7F8C8D);
  static const muted = Color(0xFFB0B7BF);
  static const irregular = Color(0xFFD68910);
  static const ink = Color(0xFF1A1A2E);
}

class StatusStyle {
  const StatusStyle(this.label, this.color, this.icon, {this.faded = false});

  final String label;
  final Color color;
  final IconData icon;

  /// Not an outcome (no session, upcoming, before joining) — drawn quietly.
  final bool faded;
}

StatusStyle statusStyle(String status) {
  switch (status) {
    case 'PRESENT':
      return const StatusStyle('حاضر', AttendanceColors.present, Icons.check_circle_rounded);
    case 'LATE':
      return const StatusStyle('متأخر', AttendanceColors.lateArrival, Icons.schedule_rounded);
    case 'ABSENT':
      return const StatusStyle('غائب', AttendanceColors.absent, Icons.cancel_rounded);
    case 'EXCUSED':
      return const StatusStyle('غائب بعذر', AttendanceColors.excused, Icons.event_busy_rounded);
    case 'UNMARKED':
      return const StatusStyle('لم يُسجَّل', AttendanceColors.unmarked, Icons.help_outline_rounded);
    case 'NOT_ATTENDED':
      return const StatusStyle('لم يحضر', AttendanceColors.muted, Icons.remove_circle_outline_rounded,
          faded: true);
    case 'UPCOMING':
      return const StatusStyle('قادم', AttendanceColors.muted, Icons.more_horiz_rounded, faded: true);
    case 'BEFORE_JOIN':
      return const StatusStyle('قبل انضمامه', AttendanceColors.muted, Icons.horizontal_rule_rounded,
          faded: true);
    default: // NO_SESSION
      return const StatusStyle('لا جلسة', AttendanceColors.muted, Icons.horizontal_rule_rounded,
          faded: true);
  }
}

class ClassStyle {
  const ClassStyle(this.label, this.color, this.icon);

  final String label;
  final Color color;
  final IconData icon;
}

ClassStyle classStyle(AttendanceClass c) {
  switch (c) {
    case AttendanceClass.regular:
      return const ClassStyle('ثابت', AttendanceColors.present, Icons.verified_rounded);
    case AttendanceClass.irregular:
      return const ClassStyle('متذبذب', AttendanceColors.irregular, Icons.trending_down_rounded);
    case AttendanceClass.inactive:
      return const ClassStyle('منقطع', AttendanceColors.absent, Icons.person_off_rounded);
    case AttendanceClass.noData:
      return const ClassStyle('بلا بيانات', AttendanceColors.unmarked, Icons.help_outline_rounded);
  }
}

// ── Dates ──────────────────────────────────────────────────────────────────

const List<String> kWeekdaysAr = [
  'الاثنين',
  'الثلاثاء',
  'الأربعاء',
  'الخميس',
  'الجمعة',
  'السبت',
  'الأحد',
];

const List<String> kMonthsAr = [
  'يناير',
  'فبراير',
  'مارس',
  'أبريل',
  'مايو',
  'يونيو',
  'يوليو',
  'أغسطس',
  'سبتمبر',
  'أكتوبر',
  'نوفمبر',
  'ديسمبر',
];

/// A YYYY-MM-DD calendar day. Parsed in UTC so no device time zone moves it.
DateTime? parseIsoDay(String? iso) {
  if (iso == null || iso.length < 10) return null;
  return DateTime.tryParse('${iso.substring(0, 10)}T00:00:00Z');
}

/// «السبت 17/10»
String dayLabel(String? iso) {
  final d = parseIsoDay(iso);
  if (d == null) return iso ?? '—';
  return '${kWeekdaysAr[d.weekday - 1]} ${d.day}/${d.month}';
}

/// «17/10»
String shortDate(String? iso) {
  final d = parseIsoDay(iso);
  if (d == null) return iso ?? '—';
  return '${d.day}/${d.month}';
}

/// YYYY-MM → «أكتوبر 2026»
String monthLabel(String month) {
  final parts = month.split('-');
  if (parts.length != 2) return month;
  final y = int.tryParse(parts[0]);
  final m = int.tryParse(parts[1]);
  if (y == null || m == null || m < 1 || m > 12) return month;
  return '${kMonthsAr[m - 1]} $y';
}

String monthOf(DateTime d) => '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}';

/// YYYY-MM shifted by [delta] months.
String shiftMonth(String month, int delta) {
  final parts = month.split('-');
  final y = int.tryParse(parts.isNotEmpty ? parts[0] : '') ?? DateTime.now().year;
  final m = int.tryParse(parts.length > 1 ? parts[1] : '') ?? DateTime.now().month;
  return monthOf(DateTime(y, m + delta));
}

/// «مرة واحدة» · «مرتين» · «3 مرات» · «11 مرة»
String timesAr(int n) {
  if (n == 1) return 'مرة واحدة';
  if (n == 2) return 'مرتين';
  if (n >= 3 && n <= 10) return '$n مرات';
  return '$n مرة';
}

/// «جلسة واحدة» · «جلستين» · «3 جلسات» · «11 جلسة»
String sessionsAr(int n) {
  if (n == 1) return 'جلسة واحدة';
  if (n == 2) return 'جلستين';
  if (n >= 3 && n <= 10) return '$n جلسات';
  return '$n جلسة';
}

/// «مرتين متتاليتين» · «3 مرات متتالية» · «11 مرة متتالية»
String consecutiveAr(int n) {
  if (n == 1) return 'مرة واحدة';
  if (n == 2) return 'مرتين متتاليتين';
  if (n >= 3 && n <= 10) return '$n مرات متتالية';
  return '$n مرة متتالية';
}

/// «طالب واحد» · «طالبان» · «3 طلاب» · «11 طالباً»
String studentsAr(int n) {
  if (n == 1) return 'طالب واحد';
  if (n == 2) return 'طالبان';
  if (n >= 3 && n <= 10) return '$n طلاب';
  return '$n طالباً';
}

String? dayKindNote(DayKind? kind) {
  switch (kind) {
    case DayKind.optional:
      return 'يوم اختياري: يُكافأ الحاضر ولا يُخصم من الغائب';
    case DayKind.extra:
      return 'ليس من أيام الدوام: يُحتسب للحاضرين فقط ولا خصم على أحد';
    case DayKind.mandatory:
    case null:
      return null;
  }
}

// ── Small widgets ──────────────────────────────────────────────────────────

/// Rounded label in a soft tint of its colour.
class TintPill extends StatelessWidget {
  const TintPill({
    super.key,
    required this.label,
    required this.color,
    this.icon,
    this.faded = false,
    this.dense = false,
  });

  final String label;
  final Color color;
  final IconData? icon;
  final bool faded;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: dense ? 8 : 10, vertical: dense ? 3 : 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: faded ? 0.08 : 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: dense ? 12 : 14, color: color),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: TextStyle(
              fontFamily: 'Cairo',
              fontSize: dense ? 10.5 : 11.5,
              fontWeight: faded ? FontWeight.normal : FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class StatusPill extends StatelessWidget {
  const StatusPill(this.status, {super.key, this.dense = false});

  final String status;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final s = statusStyle(status);
    return TintPill(label: s.label, color: s.color, icon: s.icon, faded: s.faded, dense: dense);
  }
}

class ClassBadge extends StatelessWidget {
  const ClassBadge(this.value, {super.key, this.dense = false});

  final AttendanceClass value;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final s = classStyle(value);
    return TintPill(label: s.label, color: s.color, icon: s.icon, dense: dense);
  }
}

/// A number over a caption, coloured — used in summary rows.
class CountTile extends StatelessWidget {
  const CountTile({super.key, required this.count, required this.label, required this.color});

  final int count;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '$count',
          style: TextStyle(fontFamily: 'Cairo', fontSize: 19, fontWeight: FontWeight.bold, color: color),
        ),
        Text(
          label,
          style: TextStyle(fontFamily: 'Cairo', fontSize: 10.5, color: Colors.grey.shade600),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }
}

/// White card with the app's soft shadow.
class SoftCard extends StatelessWidget {
  const SoftCard({super.key, required this.child, this.padding = const EdgeInsets.all(16), this.margin});

  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry? margin;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: margin,
      padding: padding,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: TaqwaColors.domeBlue.withValues(alpha: 0.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: child,
    );
  }
}

/// A calm one-line notice (no data, needs a server update, …).
class QuietNote extends StatelessWidget {
  const QuietNote({super.key, required this.text, this.icon = Icons.info_outline_rounded});

  final String text;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18, color: Colors.grey.shade500),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: TextStyle(fontFamily: 'Cairo', fontSize: 12.5, color: Colors.grey.shade600, height: 1.6),
          ),
        ),
      ],
    );
  }
}

// ── Contacting the family ──────────────────────────────────────────────────

/// Syrian mobile number → international digits for wa.me (`9639…`), or
/// null when it is not recognisable. Same rules as the credentials screen.
String? normalizeSyrianPhone(String? raw) {
  if (raw == null) return null;
  final cleaned = raw.replaceAll(RegExp(r'[\s\-()]'), '');
  if (cleaned.isEmpty) return null;
  if (cleaned.startsWith('+963')) return cleaned.substring(1);
  if (cleaned.startsWith('00963')) return cleaned.substring(2);
  if (cleaned.startsWith('963')) return cleaned;
  if (cleaned.startsWith('09')) return '963${cleaned.substring(1)}';
  return null;
}

/// Opens the dialer. Returns false when no app could take it.
Future<bool> callPhone(String phone) async {
  final cleaned = phone.replaceAll(RegExp(r'[\s\-()]'), '');
  if (cleaned.isEmpty) return false;
  try {
    return await launchUrl(Uri(scheme: 'tel', path: cleaned), mode: LaunchMode.externalApplication);
  } catch (_) {
    return false;
  }
}

/// Opens WhatsApp with a kind, ready-to-send check-in about [studentName].
Future<bool> whatsappCheckIn(String phone, String studentName) async {
  final number = normalizeSyrianPhone(phone);
  if (number == null) return false;
  final message = 'السلام عليكم ورحمة الله وبركاته\n'
      'افتقدنا $studentName في حلقة جامع التقوى، ونرجو أن يكون بخير.\n'
      'إن كان هناك عذر أو ما يمكننا المساعدة فيه فنحن بالخدمة.';
  final uri = Uri.parse('https://wa.me/$number?text=${Uri.encodeComponent(message)}');
  try {
    return await launchUrl(uri, mode: LaunchMode.externalApplication);
  } catch (_) {
    return false;
  }
}
