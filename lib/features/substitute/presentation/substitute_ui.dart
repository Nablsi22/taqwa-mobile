import 'package:flutter/material.dart';

// ═══════════════════════════════════════════════════════════════════════════
// The look of «تسجيل بالنيابة».
//
// Recording somebody else's حلقة must never be mistaken for recording your
// own, so this mode has its own colour and always carries a banner naming
// the instructor it belongs to. The signal has to survive a glance at a
// phone held in one hand in a crowded mosque:
//
//   • own حلقة   TaqwaColors.domeBlue — a cool navy
//   • by proxy   deep violet below — a different hue, not a shade of navy
//
// Violet is also the «غائب بعذر» pill colour, but at a very different
// weight: that is a small light amethyst chip inside a card, this is the
// whole header. Nothing else in the app uses a dark violet surface.
//
// The status colours inside the sheet (present / late / absent / excused)
// are deliberately left alone: an instructor must read a status the same way
// in both screens.
// ═══════════════════════════════════════════════════════════════════════════

class SubstituteColors {
  SubstituteColors._();

  /// App bar and header of every by-proxy screen.
  static const Color header = Color(0xFF4A235A);

  /// Buttons and accents on that header.
  static const Color accent = Color(0xFF6C3483);

  /// Page background — a violet so pale it only tints the white.
  static const Color surface = Color(0xFFF6F2F9);

  /// Soft fill for a claimed («استلمتها») card.
  static const Color claimedFill = Color(0xFFEDE3F3);

  /// The same identity on a dark surface — the «حلقات أخرى» icon sits on
  /// the navy dashboard header, where [header] itself would disappear.
  static const Color onDark = Color(0xFFD7BDE2);
}

/// «تسجيل بالنيابة عن أ. فلان» — the banner that rides along at the top of
/// every by-proxy screen. [onSurface] places it on a light page rather than
/// on the violet header.
class SubstituteBanner extends StatelessWidget {
  const SubstituteBanner({
    super.key,
    required this.instructorName,
    this.subtitle,
    this.onSurface = false,
  });

  final String instructorName;
  final String? subtitle;
  final bool onSurface;

  @override
  Widget build(BuildContext context) {
    final fg = onSurface ? SubstituteColors.header : Colors.white;
    final bg = onSurface
        ? SubstituteColors.claimedFill
        : Colors.white.withValues(alpha: 0.16);
    final border = onSurface
        ? SubstituteColors.accent.withValues(alpha: 0.35)
        : Colors.white.withValues(alpha: 0.35);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: border),
      ),
      child: Row(
        children: [
          Icon(Icons.swap_horiz_rounded, size: 20, color: fg),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'تسجيل بالنيابة عن أ. $instructorName',
                  style: TextStyle(
                    fontFamily: 'Cairo',
                    fontSize: 13.5,
                    fontWeight: FontWeight.bold,
                    color: fg,
                    height: 1.5,
                  ),
                ),
                if (subtitle != null)
                  Text(
                    subtitle!,
                    style: TextStyle(
                      fontFamily: 'Cairo',
                      fontSize: 11.5,
                      color: fg.withValues(alpha: 0.85),
                      height: 1.5,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// What a by-proxy screen needs to know to render itself as by-proxy.
/// Absent (null) → the instructor's own حلقة, unchanged in every way.
@immutable
class SubstituteMode {
  const SubstituteMode({
    required this.halaqaInstructorId,
    required this.instructorName,
    this.date,
    this.sharedWith = const [],
  });

  /// The حلقة being recorded — the instructor its students belong to.
  final String halaqaInstructorId;

  /// Shown in the banner: «تسجيل بالنيابة عن أ. فلان».
  final String instructorName;

  /// The day being recorded (YYYY-MM-DD) — the key of «طلابي اليوم»
  /// (`SubstituteGroups`). Absent → that choice is not offered.
  final String? date;

  /// The other teachers who also said «استلمتُ هذه الحلقة اليوم»: the
  /// absent teacher's students are shared out between them. Empty → this
  /// substitute is the only one.
  final List<String> sharedWith;

  bool get isShared => sharedWith.isNotEmpty;

  /// «أ. فلان» · «أ. فلان و أ. فلان» · «أ. فلان و 2 آخرين».
  String get sharedWithAr {
    if (sharedWith.isEmpty) return '';
    if (sharedWith.length == 1) return 'أ. ${sharedWith.first}';
    if (sharedWith.length == 2) {
      return 'أ. ${sharedWith[0]} وأ. ${sharedWith[1]}';
    }
    return 'أ. ${sharedWith.first} و${sharedWith.length - 1} آخرين';
  }
}

/// «طلابك منها اليوم» — a one-line strip that says which of the حلقة's
/// students this substitute is recording, with the way to change it.
///
/// [onDark] places it on the violet header rather than on a white card.
class SubstituteGroupStrip extends StatelessWidget {
  const SubstituteGroupStrip({
    super.key,
    required this.mine,
    required this.total,
    required this.onChoose,
    this.mode,
    this.onDark = false,
  });

  /// Students chosen; null → the whole حلقة.
  final int? mine;
  final int total;
  final VoidCallback? onChoose;

  /// Supplies who else covers today, for the «موزّعة» wording.
  final SubstituteMode? mode;
  final bool onDark;

  @override
  Widget build(BuildContext context) {
    final shared = mode?.isShared ?? false;
    final warn = shared && mine == null;
    final fg = onDark ? Colors.white : SubstituteColors.header;

    final String text;
    if (mine != null) {
      text = 'طلابك منها اليوم: $mine من $total';
    } else if (warn) {
      text = 'موزّعة اليوم مع ${mode!.sharedWithAr} — حدّد طلابك منها';
    } else {
      text = 'معك الحلقة كاملة · إن توزّع طلابها فحدّد طلابك';
    }

    return Container(
      padding: const EdgeInsetsDirectional.fromSTEB(12, 4, 4, 4),
      decoration: BoxDecoration(
        color: onDark
            ? Colors.white.withValues(alpha: warn ? 0.20 : 0.12)
            : (warn ? const Color(0xFFFFF6E5) : SubstituteColors.surface),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: onDark
              ? Colors.white.withValues(alpha: 0.28)
              : (warn
                  ? const Color(0xFFE59866).withValues(alpha: 0.6)
                  : SubstituteColors.accent.withValues(alpha: 0.22)),
        ),
      ),
      child: Row(
        children: [
          Icon(
            warn ? Icons.call_split_rounded : Icons.groups_2_outlined,
            size: 18,
            color: warn && !onDark ? const Color(0xFFB9770E) : fg,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontFamily: 'Cairo',
                fontSize: 12,
                fontWeight: FontWeight.w600,
                height: 1.5,
                color: warn && !onDark ? const Color(0xFF7E5109) : fg,
              ),
            ),
          ),
          TextButton(
            onPressed: onChoose,
            style: TextButton.styleFrom(
              foregroundColor: fg,
              padding: const EdgeInsets.symmetric(horizontal: 10),
              minimumSize: const Size(0, 34),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: Text(
              mine == null ? 'تحديد طلابي' : 'تعديل',
              style: const TextStyle(
                fontFamily: 'Cairo',
                fontSize: 12.5,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
