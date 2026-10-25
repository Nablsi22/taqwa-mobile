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

/// What the attendance screen needs to know to render itself as by-proxy.
/// Absent (null) → the instructor's own حلقة, unchanged in every way.
@immutable
class SubstituteMode {
  const SubstituteMode({
    required this.halaqaInstructorId,
    required this.instructorName,
  });

  /// The حلقة being recorded — the instructor its students belong to.
  final String halaqaInstructorId;

  /// Shown in the banner: «تسجيل بالنيابة عن أ. فلان».
  final String instructorName;
}
