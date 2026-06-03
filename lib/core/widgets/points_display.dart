// lib/core/widgets/points_display.dart

import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:taqwa_mobile/core/extensions/points_formatting.dart';
import 'package:taqwa_mobile/core/theme/taqwa_colors.dart';

/// Size presets for [PointsDisplay].
enum PointsDisplaySize { small, medium, large, huge }

/// Unified design-system widget for rendering student/user points.
///
/// Handles five concerns in one place so every screen renders
/// points identically:
///
///  1. **2-decimal formatting** via [PointsFormatting.asPoints].
///  2. **Tabular figures** (`FontFeature.tabularFigures`) so numbers
///     align vertically in leaderboard / list UIs — this is an
///     Apple HIG / Material 3 best practice for numeric columns.
///     Ref: https://api.flutter.dev/flutter/dart-ui/FontFeature/FontFeature.tabularFigures.html
///  3. **LTR direction on the number itself** — inside an RTL layout,
///     a bare numeric Text defaults to RTL on some fonts, which can
///     flip the minus sign. Forcing LTR keeps "-3.50" rendering
///     correctly.
///  4. **Dynamic colors** — positive = islamicGreen (success),
///     negative = red (warning), zero = neutral gray.
///     Callers can override via the [color] parameter (e.g. to keep
///     a brand color like minaretGold on stat cards).
///  5. **Optional Arabic label** "نقطة" rendered in RTL alongside
///     the LTR number.
class PointsDisplay extends StatelessWidget {
  const PointsDisplay({
    super.key,
    required this.value,
    this.size = PointsDisplaySize.medium,
    this.showLabel = false,
    this.colorize = true,
    this.color,
    this.fontFamily = 'Cairo',
  });

  /// Raw numeric value. Accepts [num] so callers can pass either
  /// `int` or `double` without casting.
  final num value;

  /// Font-size preset.
  final PointsDisplaySize size;

  /// Whether to append "نقطة" after the number.
  final bool showLabel;

  /// Whether to color-code by sign. Disable on dark backgrounds
  /// where the parent already provides a fixed color.
  final bool colorize;

  /// Explicit color override. When provided, takes priority over
  /// both the sign-based automatic coloring and the [colorize] flag.
  /// Use this on stat cards to preserve brand colors like
  /// [TaqwaColors.minaretGold].
  final Color? color;

  /// Project font (defaults to the app-wide Cairo font).
  final String fontFamily;

  double get _fontSize => switch (size) {
        PointsDisplaySize.small => 13,
        PointsDisplaySize.medium => 16,
        PointsDisplaySize.large => 22,
        PointsDisplaySize.huge => 32,
      };

  FontWeight get _weight => switch (size) {
        PointsDisplaySize.small => FontWeight.w600,
        PointsDisplaySize.medium => FontWeight.w700,
        PointsDisplaySize.large => FontWeight.w800,
        PointsDisplaySize.huge => FontWeight.w900,
      };

  Color _resolveColor(BuildContext context) {
    // Explicit override always wins.
    if (color != null) return color!;
    if (!colorize) {
      return Theme.of(context).textTheme.bodyLarge?.color ??
          Colors.black87;
    }
    if (value > 0) return TaqwaColors.islamicGreen;
    if (value < 0) return const Color(0xFFB91C1C); // red-700
    return Colors.grey.shade600;
  }

  @override
  Widget build(BuildContext context) {
    final resolvedColor = _resolveColor(context);

    final numberText = Text(
      value.asPoints,
      textDirection: TextDirection.ltr,
      style: TextStyle(
        fontSize: _fontSize,
        fontWeight: _weight,
        color: resolvedColor,
        fontFamily: fontFamily,
        fontFeatures: const [FontFeature.tabularFigures()],
        height: 1.1,
      ),
    );

    if (!showLabel) return numberText;

    return Row(
      mainAxisSize: MainAxisSize.min,
      textDirection: TextDirection.rtl,
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        numberText,
        const SizedBox(width: 4),
        Text(
          'نقطة',
          style: TextStyle(
            fontSize: _fontSize * 0.72,
            fontWeight: FontWeight.w500,
            color: resolvedColor.withOpacity(0.75),
            fontFamily: fontFamily,
          ),
        ),
      ],
    );
  }
}