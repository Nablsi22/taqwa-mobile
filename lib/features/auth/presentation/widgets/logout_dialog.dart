import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/theme/taqwa_colors.dart';
import '../providers/auth_provider.dart';

/// Asks before signing out, the same way on every screen that has a
/// sign-out button (admin, teacher, parent, course director).
///
/// A calm card over a softly blurred screen, in the app's own navy — no
/// alarm red: leaving is not a danger. The icon breathes gently while the
/// question is open. On «تسجيل الخروج» the card turns into «في أمان الله»
/// with a thin progress line, then closes and signs out.
Future<void> confirmLogout(BuildContext context) async {
  final auth = context.read<AuthProvider>();
  final confirmed = await showGeneralDialog<bool>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'إغلاق',
    barrierColor: const Color(0x660B1622),
    transitionDuration: const Duration(milliseconds: 260),
    pageBuilder: (_, _, _) => const _LogoutDialog(),
    transitionBuilder: (_, animation, _, child) {
      final curved = CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutCubic,
        reverseCurve: Curves.easeInCubic,
      );
      return BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 5 * animation.value, sigmaY: 5 * animation.value),
        child: FadeTransition(
          opacity: curved,
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.94, end: 1).animate(curved),
            child: child,
          ),
        ),
      );
    },
  );
  if (confirmed == true) await auth.logout();
}

class _LogoutDialog extends StatefulWidget {
  const _LogoutDialog();

  @override
  State<_LogoutDialog> createState() => _LogoutDialogState();
}

class _LogoutDialogState extends State<_LogoutDialog> with SingleTickerProviderStateMixin {
  late final AnimationController _breath = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1800),
  )..repeat(reverse: true);

  bool _leaving = false;

  @override
  void dispose() {
    _breath.dispose();
    super.dispose();
  }

  Future<void> _leave() async {
    setState(() => _leaving = true);
    _breath.stop();
    await Future<void>.delayed(const Duration(milliseconds: 900));
    if (mounted) Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_leaving,
      child: Directionality(
        textDirection: TextDirection.rtl,
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 28),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 360),
              child: Material(
                color: Colors.white,
                elevation: 0,
                borderRadius: BorderRadius.circular(24),
                shadowColor: Colors.transparent,
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF0B1622).withValues(alpha: 0.22),
                        blurRadius: 40,
                        offset: const Offset(0, 18),
                      ),
                    ],
                  ),
                  padding: const EdgeInsets.fromLTRB(22, 26, 22, 20),
                  child: AnimatedSize(
                    duration: const Duration(milliseconds: 260),
                    curve: Curves.easeOutCubic,
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 320),
                      switchInCurve: Curves.easeOutCubic,
                      switchOutCurve: Curves.easeInCubic,
                      transitionBuilder: (child, animation) => FadeTransition(
                        opacity: animation,
                        child: ScaleTransition(
                          scale: Tween<double>(begin: 0.96, end: 1).animate(animation),
                          child: child,
                        ),
                      ),
                      child: _leaving ? const _Farewell(key: ValueKey('bye')) : _question(),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _question() {
    return Column(
      key: const ValueKey('ask'),
      mainAxisSize: MainAxisSize.min,
      children: [
        AnimatedBuilder(
          animation: _breath,
          builder: (_, _) => _BreathingIcon(t: Curves.easeInOutSine.transform(_breath.value)),
        ),
        const SizedBox(height: 16),
        const Text(
          'تسجيل الخروج',
          style: TextStyle(
            fontFamily: 'Cairo',
            fontSize: 19,
            fontWeight: FontWeight.bold,
            color: Color(0xFF1A1A2E),
          ),
        ),
        const SizedBox(height: 6),
        const Text(
          'هل تريد تسجيل الخروج من حسابك؟\nيمكنك العودة في أي وقت باسم المستخدم وكلمة المرور.',
          textAlign: TextAlign.center,
          style: TextStyle(fontFamily: 'Cairo', fontSize: 14, height: 1.8, color: Color(0xFF5D6D7E)),
        ),
        const SizedBox(height: 22),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () => Navigator.of(context).pop(false),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF5D6D7E),
                  side: const BorderSide(color: TaqwaColors.lightGray),
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                child: const Text(
                  'إلغاء',
                  style: TextStyle(fontFamily: 'Cairo', fontSize: 15, fontWeight: FontWeight.w600),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: FilledButton(
                onPressed: _leave,
                style: FilledButton.styleFrom(
                  backgroundColor: TaqwaColors.domeBlue,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                child: const Text(
                  'تسجيل الخروج',
                  style: TextStyle(fontFamily: 'Cairo', fontSize: 15, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// The sign-out icon in a soft circle; a fine ring breathes out around it
/// and the arrow leans gently toward the door.
class _BreathingIcon extends StatelessWidget {
  const _BreathingIcon({required this.t});

  /// 0 → 1 → 0, eased.
  final double t;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 92,
      height: 92,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Transform.scale(
            scale: 1.0 + 0.10 * t,
            child: Container(
              width: 82,
              height: 82,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: TaqwaColors.domeBlue.withValues(alpha: 0.16 * (1 - t) + 0.04),
                  width: 1.5,
                ),
              ),
            ),
          ),
          Container(
            width: 68,
            height: 68,
            decoration: const BoxDecoration(color: TaqwaColors.lightBlue, shape: BoxShape.circle),
            child: Transform.translate(
              // Toward the reading end of the line: left in Arabic.
              offset: Offset(-2.5 * t, 0),
              child: const Icon(Icons.logout_rounded, color: TaqwaColors.domeBlue, size: 30),
            ),
          ),
        ],
      ),
    );
  }
}

/// «في أمان الله» while the session closes.
class _Farewell extends StatelessWidget {
  const _Farewell({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: 1),
          duration: const Duration(milliseconds: 450),
          curve: Curves.easeOutBack,
          builder: (_, v, child) => Transform.scale(scale: 0.6 + 0.4 * v, child: child),
          child: Container(
            width: 68,
            height: 68,
            decoration: const BoxDecoration(color: TaqwaColors.lightGreen, shape: BoxShape.circle),
            child: const Icon(Icons.check_rounded, color: TaqwaColors.islamicGreen, size: 34),
          ),
        ),
        const SizedBox(height: 14),
        const Text(
          'في أمان الله',
          style: TextStyle(
            fontFamily: 'Amiri',
            fontSize: 27,
            fontWeight: FontWeight.w700,
            color: Color(0xFF1A1A2E),
            height: 1.4,
          ),
        ),
        const SizedBox(height: 2),
        const Text(
          'جارٍ تسجيل الخروج…',
          style: TextStyle(fontFamily: 'Cairo', fontSize: 13.5, color: Color(0xFF5D6D7E)),
        ),
        const SizedBox(height: 16),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 30),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(2),
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: 1),
              duration: const Duration(milliseconds: 850),
              curve: Curves.easeInOut,
              builder: (_, v, _) => LinearProgressIndicator(
                value: math.max(0.04, v),
                minHeight: 3,
                color: TaqwaColors.domeBlue,
                backgroundColor: TaqwaColors.lightBlue,
              ),
            ),
          ),
        ),
        const SizedBox(height: 4),
      ],
    );
  }
}
