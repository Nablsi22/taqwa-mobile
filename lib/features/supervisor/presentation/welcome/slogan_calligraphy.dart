import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import 'slogan_calligraphy_data.dart';

/// «إلهي أنت مقصودي ورضاك مطلوبي» drawn as a calligrapher writes it.
///
/// Every glyph is a real outline of Aref Ruqaa (see
/// `slogan_calligraphy_data.dart`). As [progress] goes from 0 to 1 the pen
/// traces each letter's outline, right to left and line by line, and the
/// ink fills in behind it; a small glowing nib rides the stroke being drawn.
/// [shine] (0 → 1) sweeps one band of light across the finished words.
///
/// At `progress: 1` it is simply the finished calligraphy, so the same widget
/// serves as a static ornament.
class SloganCalligraphy extends StatelessWidget {
  const SloganCalligraphy({
    super.key,
    this.progress = 1,
    this.shine = 0,
    this.color = const Color(0xFFD4AC0D),
    this.highlight = const Color(0xFFFFF1B8),
    this.showNib = true,
  });

  final double progress;
  final double shine;
  final Color color;
  final Color highlight;
  final bool showNib;

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: kSloganWidth / kSloganHeight,
      child: CustomPaint(
        painter: _CalligraphyPainter(
          glyphs: _SloganGlyphs.instance,
          progress: progress.clamp(0.0, 1.0),
          shine: shine.clamp(0.0, 1.0),
          color: color,
          highlight: highlight,
          showNib: showNib,
        ),
      ),
    );
  }
}

/// The parsed outlines and the timing of each glyph, built once per run.
class _SloganGlyphs {
  _SloganGlyphs._(this.glyphs);

  static final _SloganGlyphs instance = _SloganGlyphs._build();

  final List<_Glyph> glyphs;

  factory _SloganGlyphs._build() {
    final parsed = <_Glyph>[];
    for (final (line, data) in kSloganGlyphs) {
      final path = parseSvgPathData(data);
      final contours = path.computeMetrics().toList(growable: false);
      final length = contours.fold<double>(0, (t, m) => t + m.length);
      parsed.add(_Glyph(line: line, path: path, contours: contours, length: length));
    }

    // Pace: each glyph gets time in proportion to how much ink it takes, and
    // starts before the previous one ends, so the hand keeps moving. A short
    // breath separates the two lines.
    const writing = 0.86; // the rest of the timeline is the last ink settling
    const lineBreath = 0.05;
    const overlap = 1.7;
    final total = parsed.fold<double>(0, (t, g) => t + g.length);
    final budget = writing - lineBreath;
    var cursor = 0.0;
    var previousLine = parsed.isEmpty ? 0 : parsed.first.line;
    for (final g in parsed) {
      if (g.line != previousLine) {
        cursor += lineBreath;
        previousLine = g.line;
      }
      final share = total == 0 ? 0.0 : g.length / total * budget;
      g.start = cursor;
      g.duration = math.max(0.035, share * overlap);
      cursor += share;
    }
    return _SloganGlyphs._(parsed);
  }
}

class _Glyph {
  _Glyph({
    required this.line,
    required this.path,
    required this.contours,
    required this.length,
  });

  final int line;
  final Path path;
  final List<ui.PathMetric> contours;
  final double length;

  /// Normalised start of this glyph's stroke and how long it takes.
  double start = 0;
  double duration = 0;

  /// 0 → 1: how much of the outline the pen has traced.
  double traceAt(double t) => ((t - start) / duration).clamp(0.0, 1.0);

  /// 0 → 1: how much the ink has filled in (it follows the pen).
  double inkAt(double t) =>
      ((t - (start + duration * 0.55)) / (duration * 0.6 + 0.06)).clamp(0.0, 1.0);
}

class _CalligraphyPainter extends CustomPainter {
  _CalligraphyPainter({
    required this.glyphs,
    required this.progress,
    required this.shine,
    required this.color,
    required this.highlight,
    required this.showNib,
  });

  final _SloganGlyphs glyphs;
  final double progress;
  final double shine;
  final Color color;
  final Color highlight;
  final bool showNib;

  @override
  void paint(Canvas canvas, Size size) {
    final scale = math.min(size.width / kSloganWidth, size.height / kSloganHeight);
    final dx = (size.width - kSloganWidth * scale) / 2;
    final dy = (size.height - kSloganHeight * scale) / 2;

    final ink = Paint()
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;
    if (shine > 0 && shine < 1) {
      // One band of light crossing right to left, in font units.
      final x = kSloganWidth * (1.25 - 1.5 * shine);
      ink.shader = ui.Gradient.linear(
        Offset(x + kSloganWidth * 0.12, 0),
        Offset(x - kSloganWidth * 0.12, kSloganHeight * 0.4),
        [color, highlight, color],
        const [0.0, 0.5, 1.0],
      );
    }
    final halo = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5.5 / scale
      ..strokeJoin = StrokeJoin.round
      ..color = color.withValues(alpha: 0.10);
    final pen = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5 / scale
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    Offset? nib;
    canvas.save();
    canvas.translate(dx, dy);
    canvas.scale(scale);
    for (final g in glyphs.glyphs) {
      final trace = g.traceAt(progress);
      if (trace <= 0) continue;
      final fill = g.inkAt(progress);

      if (fill > 0) {
        canvas.drawPath(g.path, halo..color = color.withValues(alpha: 0.10 * fill));
        if (ink.shader == null) ink.color = color.withValues(alpha: fill);
        canvas.drawPath(g.path, ink);
      }

      // The pen's line fades out as the ink takes over.
      final penAlpha = (1 - fill).clamp(0.0, 1.0);
      if (penAlpha > 0.02) {
        pen.color = Color.lerp(highlight, color, fill)!.withValues(alpha: penAlpha);
        if (trace >= 1) {
          canvas.drawPath(g.path, pen);
        } else {
          for (final m in g.contours) {
            canvas.drawPath(m.extractPath(0, m.length * trace), pen);
          }
        }
      }

      if (trace > 0 && trace < 1 && g.contours.isNotEmpty) {
        final longest = g.contours.reduce((a, b) => a.length >= b.length ? a : b);
        final at = longest.getTangentForOffset(longest.length * trace)?.position;
        if (at != null) nib = at;
      }
    }
    canvas.restore();

    // The nib is drawn in screen pixels so its glow has the same size at any
    // scale.
    if (showNib && nib != null) {
      final p = Offset(dx + nib.dx * scale, dy + nib.dy * scale);
      canvas.drawCircle(
        p,
        9,
        Paint()
          ..color = highlight.withValues(alpha: 0.45)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 7),
      );
      canvas.drawCircle(p, 2.4, Paint()..color = Colors.white);
    }
  }

  @override
  bool shouldRepaint(_CalligraphyPainter old) =>
      old.progress != progress ||
      old.shine != shine ||
      old.color != color ||
      old.highlight != highlight ||
      old.showNib != showNib;
}

/// Parses SVG path data made of absolute `M`, `L`, `Q`, `C` and `Z` commands —
/// the subset the generator writes. Anything else is ignored.
Path parseSvgPathData(String data) {
  final path = Path()..fillType = PathFillType.nonZero;
  final tokens = RegExp(r'[MLQCZ]|-?\d+(?:\.\d+)?').allMatches(data).map((m) => m.group(0)!).toList();
  var i = 0;
  double next() => double.parse(tokens[i++]);
  while (i < tokens.length) {
    final cmd = tokens[i++];
    switch (cmd) {
      case 'M':
        path.moveTo(next(), next());
      case 'L':
        path.lineTo(next(), next());
      case 'Q':
        path.quadraticBezierTo(next(), next(), next(), next());
      case 'C':
        path.cubicTo(next(), next(), next(), next(), next(), next());
      case 'Z':
        path.close();
      default:
        // A number where a command was expected: malformed; stop cleanly.
        return path;
    }
  }
  return path;
}
