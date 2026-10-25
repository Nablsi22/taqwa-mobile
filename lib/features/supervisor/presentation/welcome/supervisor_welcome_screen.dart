import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../core/widgets/system_nav_guard.dart';
import 'director_identity.dart';
import 'slogan_calligraphy.dart';

/// The course director's welcome, shown each time he signs in.
///
/// A calm, quiet page: deep night-blue, ivory text and a muted champagne
/// gold — no glare, no glow.
///
///   1. the mosque's emblem in a thin ring;
///   2. «أهلاً وسهلاً», a fine ornament, «فضيلة الشيخ», then his name in
///      Amiri (classical Naskh), each line easing in after the one before;
///   3. «إلهي أنت مقصودي ورضاك مطلوبي» written stroke by stroke in Ruqaa;
///   4. «تفضّلوا بالدخول».
///
/// About four seconds in all. A tap finishes it at once, a second tap
/// enters. With the system's "remove animations" setting on, it opens
/// finished.
class SupervisorWelcomeScreen extends StatefulWidget {
  const SupervisorWelcomeScreen({super.key});

  /// Shows the welcome over the current screen and completes when he enters.
  static Future<void> show(BuildContext context) {
    return Navigator.of(context).push(
      PageRouteBuilder<void>(
        opaque: true,
        fullscreenDialog: true,
        transitionDuration: const Duration(milliseconds: 350),
        reverseTransitionDuration: const Duration(milliseconds: 450),
        pageBuilder: (_, _, _) => const SupervisorWelcomeScreen(),
        transitionsBuilder: (_, animation, _, child) => FadeTransition(opacity: animation, child: child),
      ),
    );
  }

  @override
  State<SupervisorWelcomeScreen> createState() => _SupervisorWelcomeScreenState();
}

/// The page's palette: ivory on night-blue, with a muted champagne gold.
class _Palette {
  _Palette._();

  static const Color top = Color(0xFF18304A);
  static const Color middle = Color(0xFF12233A);
  static const Color bottom = Color(0xFF0C1624);
  static const Color ivory = Color(0xFFF4EEE3);
  static const Color champagne = Color(0xFFCDB988);
  static const Color champagneLight = Color(0xFFEFE3C3);
}

class _SupervisorWelcomeScreenState extends State<SupervisorWelcomeScreen> with TickerProviderStateMixin {
  late final AnimationController _greeting = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1300),
  );
  late final AnimationController _writing = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2600),
  );
  late final AnimationController _shine = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  );

  bool _finished = false;
  bool _started = false;

  @override
  void initState() {
    super.initState();
    SystemNavGuard.useDark(_Palette.bottom);
    // The pen starts while the name is still settling, so the page never
    // pauses.
    _greeting.addListener(() {
      if (_greeting.value >= 0.75 && !_writing.isAnimating && _writing.value == 0 && !_finished) {
        _writing.forward();
      }
    });
    _writing.addStatusListener((s) {
      if (s == AnimationStatus.completed && !_finished) {
        _shine.forward();
        if (mounted) setState(() => _finished = true);
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    if (MediaQuery.of(context).disableAnimations) {
      _skipToEnd(rebuild: false); // build() follows anyway
    } else {
      _greeting.forward();
    }
  }

  @override
  void dispose() {
    SystemNavGuard.release();
    _greeting.dispose();
    _writing.dispose();
    _shine.dispose();
    super.dispose();
  }

  /// Jumps to the finished picture. [_finished] is set first, so the
  /// listeners above see the jump as already handled.
  void _skipToEnd({bool rebuild = true}) {
    _finished = true;
    _greeting.value = 1;
    _writing.value = 1;
    _shine.value = 1;
    if (rebuild) setState(() {});
  }

  void _onTap() {
    if (_finished) {
      Navigator.of(context).maybePop();
    } else {
      _skipToEnd();
    }
  }

  /// The greeting's progress between [from] and [to], eased.
  double _phase(double from, double to) {
    final t = ((_greeting.value - from) / (to - from)).clamp(0.0, 1.0);
    return Curves.easeOutCubic.transform(t);
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: _Palette.bottom,
        body: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: _onTap,
          child: Stack(
            fit: StackFit.expand,
            children: [
              const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: Alignment(0, -0.16),
                    radius: 1.25,
                    colors: [_Palette.top, _Palette.middle, _Palette.bottom],
                    stops: [0.0, 0.45, 1.0],
                  ),
                ),
              ),
              // A barely-there lattice of eight-pointed stars.
              AnimatedBuilder(
                animation: _greeting,
                builder: (_, _) => CustomPaint(
                  painter: _StarLatticePainter(opacity: 0.03 * _phase(0.0, 0.4)),
                ),
              ),
              SafeArea(
                child: AnimatedBuilder(
                  animation: Listenable.merge([_greeting, _writing, _shine]),
                  builder: (context, _) => _content(context),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _content(BuildContext context) {
    final emblem = _phase(0.0, 0.35);
    final hello = _phase(0.12, 0.45);
    final ornament = _phase(0.3, 0.65);
    final title = _phase(0.38, 0.72);
    final name = _phase(0.5, 1.0);

    // Short phones get smaller type; the calligraphy is the one flexible
    // piece, so nothing can overflow however little room there is.
    final compact = MediaQuery.sizeOf(context).height < 700;
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Spacer(flex: 3),
        // ── The mosque's emblem ──────────────────────────────────────────
        _ease(
          emblem,
          rise: 0,
          scaleFrom: 0.9,
          child: Container(
            width: compact ? 58 : 66,
            height: compact ? 58 : 66,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withValues(alpha: 0.035),
              border: Border.all(color: _Palette.champagne.withValues(alpha: 0.45)),
            ),
            child: Image.asset(
              'assets/images/mosque_logo.png',
              fit: BoxFit.contain,
              errorBuilder: (_, _, _) => const Icon(Icons.mosque_rounded, size: 30, color: _Palette.champagne),
            ),
          ),
        ),
        SizedBox(height: compact ? 22 : 30),
        // ── «أهلاً وسهلاً» ───────────────────────────────────────────────
        _ease(
          hello,
          child: Text(
            'أهلاً وسهلاً',
            style: TextStyle(
              fontFamily: 'Cairo',
              fontSize: compact ? 15 : 16,
              fontWeight: FontWeight.w400,
              color: _Palette.ivory.withValues(alpha: 0.72),
            ),
          ),
        ),
        SizedBox(height: compact ? 10 : 12),
        _Ornament(progress: ornament),
        SizedBox(height: compact ? 8 : 10),
        // ── «فضيلة الشيخ» ────────────────────────────────────────────────
        _ease(
          title,
          child: Text(
            kDirectorTitle,
            style: TextStyle(
              fontFamily: 'Cairo',
              fontSize: compact ? 13 : 14,
              fontWeight: FontWeight.w600,
              color: _Palette.champagne,
            ),
          ),
        ),
        // ── His name ─────────────────────────────────────────────────────
        _ease(
          name,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                kDirectorName,
                style: TextStyle(
                  fontFamily: 'Amiri',
                  fontSize: compact ? 28 : 31,
                  fontWeight: FontWeight.w700,
                  height: 1.5,
                  color: _Palette.ivory,
                ),
              ),
            ),
          ),
        ),
        SizedBox(height: compact ? 20 : 32),
        // ── The slogan, written stroke by stroke ─────────────────────────
        Flexible(
          flex: 4,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 26),
            child: Semantics(
              label: 'إلهي أنت مقصودي ورضاك مطلوبي',
              child: ExcludeSemantics(
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    // A faint warmth behind the words while they are written.
                    Positioned.fill(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: RadialGradient(
                            colors: [
                              _Palette.champagne.withValues(alpha: 0.07 * _writing.value),
                              _Palette.champagne.withValues(alpha: 0.0),
                            ],
                          ),
                        ),
                      ),
                    ),
                    SloganCalligraphy(
                      progress: _writing.value,
                      shine: _shine.value,
                      color: _Palette.champagne,
                      highlight: _Palette.champagneLight,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        const Spacer(flex: 3),
        // ── Enter, or the hint to skip ───────────────────────────────────
        SizedBox(
          height: 84,
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 400),
            switchInCurve: Curves.easeOutCubic,
            child: _finished
                ? _EnterButton(onPressed: () => Navigator.of(context).maybePop())
                : Padding(
                    key: const ValueKey('hint'),
                    padding: const EdgeInsets.only(top: 36),
                    child: Text(
                      'المس الشاشة للتخطّي',
                      style: TextStyle(
                        fontFamily: 'Cairo',
                        fontSize: 12,
                        color: _Palette.ivory.withValues(alpha: 0.3),
                      ),
                    ),
                  ),
          ),
        ),
        const SizedBox(height: 18),
      ],
    );
  }

  /// Fades [child] in while it rises a few pixels (and, optionally, grows
  /// from [scaleFrom]).
  Widget _ease(double t, {required Widget child, double rise = 10, double scaleFrom = 1}) {
    return Opacity(
      opacity: t.clamp(0.0, 1.0),
      child: Transform.translate(
        offset: Offset(0, rise * (1 - t)),
        child: scaleFrom == 1 ? child : Transform.scale(scale: scaleFrom + (1 - scaleFrom) * t, child: child),
      ),
    );
  }
}

/// A hairline, a small diamond, a hairline — drawn outward from the centre.
class _Ornament extends StatelessWidget {
  const _Ornament({required this.progress});

  final double progress;

  @override
  Widget build(BuildContext context) {
    final color = _Palette.champagne.withValues(alpha: 0.55);
    final line = Container(width: 44 * progress, height: 1, color: color);
    return Opacity(
      opacity: progress.clamp(0.0, 1.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          line,
          const SizedBox(width: 9),
          Transform.rotate(
            angle: math.pi / 4,
            child: Container(width: 5, height: 5, color: color),
          ),
          const SizedBox(width: 9),
          line,
        ],
      ),
    );
  }
}

class _EnterButton extends StatelessWidget {
  const _EnterButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Align(
      key: const ValueKey('enter'),
      alignment: Alignment.topCenter,
      child: Padding(
        padding: const EdgeInsets.only(top: 16),
        child: OutlinedButton(
          onPressed: onPressed,
          style: OutlinedButton.styleFrom(
            foregroundColor: _Palette.champagneLight,
            backgroundColor: _Palette.champagne.withValues(alpha: 0.10),
            side: BorderSide(color: _Palette.champagne.withValues(alpha: 0.6)),
            padding: const EdgeInsets.symmetric(horizontal: 34, vertical: 12),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
          ),
          child: const Text(
            'تفضّلوا بالدخول',
            style: TextStyle(fontFamily: 'Cairo', fontSize: 15, fontWeight: FontWeight.w600),
          ),
        ),
      ),
    );
  }
}

/// A faint, still lattice of eight-pointed stars (two squares, one turned
/// 45°) — texture, not decoration.
class _StarLatticePainter extends CustomPainter {
  _StarLatticePainter({required this.opacity});

  final double opacity;

  static Path? _lattice;
  static Size _latticeSize = Size.zero;

  static Path _latticeFor(Size size) {
    if (_lattice != null && _latticeSize == size) return _lattice!;
    const cell = 64.0;
    final path = Path();
    for (var y = cell / 2; y < size.height + cell; y += cell) {
      for (var x = cell / 2; x < size.width + cell; x += cell) {
        _addStar(path, Offset(x, y), cell * 0.36);
      }
    }
    _latticeSize = size;
    return _lattice = path;
  }

  static void _addStar(Path path, Offset c, double r) {
    for (final start in const [0.0, math.pi / 4]) {
      for (var i = 0; i < 4; i++) {
        final a = start + i * math.pi / 2;
        final p = c + Offset(math.cos(a), math.sin(a)) * r;
        if (i == 0) {
          path.moveTo(p.dx, p.dy);
        } else {
          path.lineTo(p.dx, p.dy);
        }
      }
      path.close();
    }
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (opacity <= 0) return;
    canvas.drawPath(
      _latticeFor(size),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.8
        ..color = _Palette.champagne.withValues(alpha: opacity),
    );
  }

  @override
  bool shouldRepaint(_StarLatticePainter old) => old.opacity != opacity;
}
