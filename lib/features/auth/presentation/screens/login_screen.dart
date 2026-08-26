import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../../../core/constants/app_strings.dart';
import '../../../../core/theme/taqwa_colors.dart';
import '../providers/auth_provider.dart';

/// Login screen for the Taqwa app.
///
/// Design notes:
/// - The word "التقوى" appears exactly once, rendered via the logo asset.
///   No other text in this screen repeats it.
/// - Three background layers: animated brand gradient, drifting eight-point
///   star pattern, soft decorative orbs.
/// - Staggered entrance animation: logo → tagline → card → footer.
/// - Inline animated error banner + shake feedback on authentication failure.
/// - Full RTL layout, keyboard-aware, explicit focus flow between fields.
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with TickerProviderStateMixin {
  // ─── form state ───────────────────────────────────────────────
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _usernameFocus = FocusNode();
  final _passwordFocus = FocusNode();

  bool _isPasswordVisible = false;
  bool _isLoading = false;
  String? _errorBannerMessage;

  // ─── animation controllers ────────────────────────────────────
  late final AnimationController _bgController;
  late final AnimationController _entranceController;
  late final AnimationController _shakeController;

  late final Animation<double> _logoScale;
  late final Animation<double> _logoFade;
  late final Animation<double> _taglineFade;
  late final Animation<Offset> _cardSlide;
  late final Animation<double> _cardFade;
  late final Animation<double> _footerFade;

  @override
  void initState() {
    super.initState();

    // Slow continuous loop for the background gradient / pattern drift.
    _bgController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 24),
    )..repeat();

    // Staggered entrance: each element has its own interval inside this.
    _entranceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    );

    _logoScale = Tween<double>(begin: 0.6, end: 1.0).animate(
      CurvedAnimation(
        parent: _entranceController,
        curve: const Interval(0.0, 0.45, curve: Curves.easeOutBack),
      ),
    );
    _logoFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _entranceController,
        curve: const Interval(0.0, 0.40, curve: Curves.easeOut),
      ),
    );
    _taglineFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _entranceController,
        curve: const Interval(0.30, 0.60, curve: Curves.easeOut),
      ),
    );
    _cardSlide = Tween<Offset>(
      begin: const Offset(0, 0.25),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _entranceController,
        curve: const Interval(0.40, 0.85, curve: Curves.easeOutCubic),
      ),
    );
    _cardFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _entranceController,
        curve: const Interval(0.40, 0.85, curve: Curves.easeOut),
      ),
    );
    _footerFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _entranceController,
        curve: const Interval(0.75, 1.0, curve: Curves.easeOut),
      ),
    );

    // Replayable shake used on failed login.
    _shakeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 520),
    );

    // Typing anywhere clears the banner so the user isn't staring at an
    // error message that's no longer relevant.
    _usernameController.addListener(_maybeClearBanner);
    _passwordController.addListener(_maybeClearBanner);

    _entranceController.forward();
  }

  @override
  void dispose() {
    _bgController.dispose();
    _entranceController.dispose();
    _shakeController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    _usernameFocus.dispose();
    _passwordFocus.dispose();
    super.dispose();
  }

  // ══════════════════════════════════════════════════════════════════
  // ACTIONS
  // ══════════════════════════════════════════════════════════════════

  void _maybeClearBanner() {
    if (_errorBannerMessage != null) {
      setState(() => _errorBannerMessage = null);
    }
  }

  Future<void> _handleLogin() async {
    FocusScope.of(context).unfocus();
    if (_isLoading) return;
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorBannerMessage = null;
    });
    HapticFeedback.lightImpact();

    final authProvider = context.read<AuthProvider>();
    await authProvider.login(
      username: _usernameController.text.trim(),
      password: _passwordController.text,
    );

    if (!mounted) return;

    if (authProvider.errorMessage != null) {
      HapticFeedback.heavyImpact();
      setState(() {
        _isLoading = false;
        _errorBannerMessage = authProvider.errorMessage;
      });
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(authProvider.errorMessage!, style: const TextStyle(fontFamily: 'Cairo'), textDirection: TextDirection.rtl), backgroundColor: Colors.red, duration: const Duration(seconds: 4)));
      _shakeController.forward(from: 0);
    } else {
      setState(() => _isLoading = false);
      // Navigation is driven by the auth state listener at the app root.
    }
  }

  /// Damped sine wave used to shake the form card on failure.
  /// Max amplitude ~12px, decays to zero over the controller's duration.
  double _shakeOffset(double t) {
    if (t == 0) return 0;
    return math.sin(t * math.pi * 6) * 12 * (1 - t);
  }

  // ══════════════════════════════════════════════════════════════════
  // BUILD
  // ══════════════════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final screenHeight = media.size.height;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        resizeToAvoidBottomInset: true,
        body: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => FocusScope.of(context).unfocus(),
          child: Stack(
            children: [
              // Layer 1 — animated brand gradient
              Positioned.fill(child: _buildAnimatedBackground()),

              // Layer 2 — drifting geometric pattern
              Positioned.fill(
                child: CustomPaint(
                  painter: _IslamicPatternPainter(animation: _bgController),
                ),
              ),

              // Layer 3 — decorative orbs
              _buildDecorativeOrbs(),

              // Layer 4 — content
              SafeArea(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight: screenHeight -
                          media.padding.top -
                          media.padding.bottom,
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          SizedBox(height: screenHeight * 0.06),

                          // The ONLY place "التقوى" appears.
                          _buildLogoHero(),

                          const SizedBox(height: 18),

                          FadeTransition(
                            opacity: _taglineFade,
                            child: _buildTagline(),
                          ),

                          const SizedBox(height: 36),

                          _buildErrorBanner(),

                          FadeTransition(
                            opacity: _cardFade,
                            child: SlideTransition(
                              position: _cardSlide,
                              child: AnimatedBuilder(
                                animation: _shakeController,
                                builder: (context, child) {
                                  return Transform.translate(
                                    offset: Offset(
                                      _shakeOffset(_shakeController.value),
                                      0,
                                    ),
                                    child: child,
                                  );
                                },
                                child: _buildLoginCard(),
                              ),
                            ),
                          ),

                          const SizedBox(height: 32),

                          FadeTransition(
                            opacity: _footerFade,
                            child: _buildFooter(),
                          ),

                          const SizedBox(height: 24),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════
  // BACKGROUND LAYERS
  // ══════════════════════════════════════════════════════════════════

  Widget _buildAnimatedBackground() {
    return AnimatedBuilder(
      animation: _bgController,
      builder: (context, _) {
        final t = _bgController.value;
        return Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topRight,
              end: Alignment.bottomLeft,
              colors: const [
                Color(0xFF0A1828),
                Color(0xFF102B44),
                Color(0xFF1B4F72),
                Color(0xFF071524),
              ],
              stops: [
                0.0,
                0.32 + 0.06 * math.sin(t * 2 * math.pi),
                0.68 + 0.06 * math.cos(t * 2 * math.pi),
                1.0,
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildDecorativeOrbs() {
    return IgnorePointer(
      child: Stack(
        children: [
          Positioned(
            top: -100,
            left: -80,
            child: _orb(260, TaqwaColors.minaretGold.withValues(alpha: 0.14)),
          ),
          Positioned(
            bottom: -120,
            right: -100,
            child: _orb(320, TaqwaColors.skyBlue.withValues(alpha: 0.10)),
          ),
          Positioned(
            top: 220,
            right: -60,
            child: _orb(
              160,
              TaqwaColors.minaretGold.withValues(alpha: 0.05),
            ),
          ),
        ],
      ),
    );
  }

  Widget _orb(double size, Color color) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [color, color.withValues(alpha: 0)],
        ),
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════
  // LOGO HERO — the one and only place "التقوى" appears
  // ══════════════════════════════════════════════════════════════════

  Widget _buildLogoHero() {
    return FadeTransition(
      opacity: _logoFade,
      child: ScaleTransition(
        scale: _logoScale,
        child: AnimatedBuilder(
          animation: _bgController,
          builder: (context, child) {
            // Subtle gold glow that breathes with the background.
            final glow =
                0.28 + 0.14 * math.sin(_bgController.value * 2 * math.pi);
            return Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 24,
                vertical: 20,
              ),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(28),
                boxShadow: [
                  BoxShadow(
                    color: TaqwaColors.minaretGold.withValues(alpha: glow),
                    blurRadius: 60,
                    spreadRadius: 6,
                  ),
                  BoxShadow(
                    color: TaqwaColors.domeBlue.withValues(alpha: 0.35),
                    blurRadius: 40,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: child,
            );
          },
          child: SizedBox(
            height: 110,
            child: Image.asset(
              'assets/images/taqwa_text.png',
              fit: BoxFit.contain,
              filterQuality: FilterQuality.high,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTagline() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          width: 32,
          height: 1,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                TaqwaColors.minaretGold.withValues(alpha: 0),
                TaqwaColors.minaretGold.withValues(alpha: 0.6),
              ],
            ),
          ),
        ),
        const SizedBox(width: 12),
        Text(
          'إدارة حلقات التحفيظ',
          style: TextStyle(
            fontFamily: 'Cairo',
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: Colors.white.withValues(alpha: 0.82),
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(width: 12),
        Container(
          width: 32,
          height: 1,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                TaqwaColors.minaretGold.withValues(alpha: 0.6),
                TaqwaColors.minaretGold.withValues(alpha: 0),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ══════════════════════════════════════════════════════════════════
  // ERROR BANNER
  // ══════════════════════════════════════════════════════════════════

  Widget _buildErrorBanner() {
    final providerError = context.watch<AuthProvider>().errorMessage;
    final msg = _errorBannerMessage ?? providerError;
    return AnimatedSize(
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOutCubic,
      child: msg == null
          ? const SizedBox(width: double.infinity, height: 0)
          : Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: _ErrorBanner(
                message: msg,
                onDismiss: () =>
                    setState(() => _errorBannerMessage = null),
              ),
            ),
    );
  }

  // ══════════════════════════════════════════════════════════════════
  // LOGIN CARD
  // ══════════════════════════════════════════════════════════════════

  Widget _buildLoginCard() {
    return Container(
      padding: const EdgeInsets.fromLTRB(26, 28, 26, 28),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(26),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.24),
            blurRadius: 42,
            offset: const Offset(0, 18),
          ),
          BoxShadow(
            color: TaqwaColors.domeBlue.withValues(alpha: 0.12),
            blurRadius: 60,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildWelcomeHeader(),
            const SizedBox(height: 26),
            _ProfessionalTextField(
              controller: _usernameController,
              focusNode: _usernameFocus,
              hint: AppStrings.username,
              icon: Icons.person_rounded,
              enabled: !_isLoading,
              textInputAction: TextInputAction.next,
              onSubmit: (_) =>
                  FocusScope.of(context).requestFocus(_passwordFocus),
              validator: (v) => (v == null || v.trim().isEmpty)
                  ? AppStrings.usernameRequired
                  : null,
            ),
            const SizedBox(height: 16),
            _ProfessionalTextField(
              controller: _passwordController,
              focusNode: _passwordFocus,
              hint: AppStrings.password,
              icon: Icons.lock_rounded,
              enabled: !_isLoading,
              isPassword: true,
              isPasswordVisible: _isPasswordVisible,
              onTogglePassword: () =>
                  setState(() => _isPasswordVisible = !_isPasswordVisible),
              textInputAction: TextInputAction.done,
              onSubmit: (_) => _handleLogin(),
              validator: (v) => (v == null || v.isEmpty)
                  ? AppStrings.passwordRequired
                  : null,
            ),
            const SizedBox(height: 28),
            _buildLoginButton(),
          ],
        ),
      ),
    );
  }

  Widget _buildWelcomeHeader() {
    return Row(
      children: [
        Container(
          width: 4,
          height: 34,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [TaqwaColors.domeBlue, TaqwaColors.skyBlue],
            ),
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                AppStrings.welcomeBack,
                style: TextStyle(
                  fontFamily: 'Cairo',
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  color: TaqwaColors.nightSky,
                  height: 1.2,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                AppStrings.loginSubtitle,
                style: TextStyle(
                  fontFamily: 'Cairo',
                  fontSize: 13,
                  color: TaqwaColors.gray.withValues(alpha: 0.80),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildLoginButton() {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            begin: Alignment.centerRight,
            end: Alignment.centerLeft,
            colors: _isLoading
                ? [
                    TaqwaColors.domeBlue.withValues(alpha: 0.65),
                    TaqwaColors.skyBlue.withValues(alpha: 0.65),
                  ]
                : const [TaqwaColors.domeBlue, TaqwaColors.skyBlue],
          ),
          boxShadow: _isLoading
              ? []
              : [
                  BoxShadow(
                    color: TaqwaColors.domeBlue.withValues(alpha: 0.40),
                    blurRadius: 18,
                    offset: const Offset(0, 8),
                  ),
                ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: _isLoading ? null : _handleLogin,
            child: Center(
              child: _isLoading
                  ? Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2.4,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Text(
                          AppStrings.loggingIn,
                          style: const TextStyle(
                            fontFamily: 'Cairo',
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    )
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: const [
                        Text(
                          AppStrings.login,
                          style: TextStyle(
                            fontFamily: 'Cairo',
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                            letterSpacing: 1.2,
                          ),
                        ),
                        SizedBox(width: 10),
                        Icon(
                          Icons.arrow_back_rounded,
                          color: Colors.white,
                          size: 20,
                        ),
                      ],
                    ),
            ),
          ),
        ),
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════
  // FOOTER (minimal, no repeated text)
  // ══════════════════════════════════════════════════════════════════

  Widget _buildFooter() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          width: 24,
          height: 1,
          color: Colors.white.withValues(alpha: 0.18),
        ),
        const SizedBox(width: 10),
        Icon(
          Icons.auto_awesome_rounded,
          size: 12,
          color: TaqwaColors.minaretGold.withValues(alpha: 0.55),
        ),
        const SizedBox(width: 10),
        Container(
          width: 24,
          height: 1,
          color: Colors.white.withValues(alpha: 0.18),
        ),
      ],
    );
  }
}

// ════════════════════════════════════════════════════════════════════
// PROFESSIONAL TEXT FIELD
// Private widget: animated focus shadow, stateful styling per focus.
// ════════════════════════════════════════════════════════════════════

class _ProfessionalTextField extends StatefulWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final String hint;
  final IconData icon;
  final bool enabled;
  final bool isPassword;
  final bool isPasswordVisible;
  final VoidCallback? onTogglePassword;
  final TextInputAction textInputAction;
  final void Function(String)? onSubmit;
  final String? Function(String?)? validator;

  const _ProfessionalTextField({
    required this.controller,
    required this.focusNode,
    required this.hint,
    required this.icon,
    this.enabled = true,
    this.isPassword = false,
    this.isPasswordVisible = false,
    this.onTogglePassword,
    this.textInputAction = TextInputAction.next,
    this.onSubmit,
    this.validator,
  });

  @override
  State<_ProfessionalTextField> createState() =>
      _ProfessionalTextFieldState();
}

class _ProfessionalTextFieldState extends State<_ProfessionalTextField> {
  bool _focused = false;

  @override
  void initState() {
    super.initState();
    widget.focusNode.addListener(_onFocusChange);
  }

  @override
  void dispose() {
    widget.focusNode.removeListener(_onFocusChange);
    super.dispose();
  }

  void _onFocusChange() {
    if (!mounted) return;
    setState(() => _focused = widget.focusNode.hasFocus);
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOut,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: _focused
            ? [
                BoxShadow(
                  color: TaqwaColors.domeBlue.withValues(alpha: 0.18),
                  blurRadius: 18,
                  offset: const Offset(0, 4),
                ),
              ]
            : const [],
      ),
      child: TextFormField(
        controller: widget.controller,
        focusNode: widget.focusNode,
        enabled: widget.enabled,
        obscureText: widget.isPassword ? !widget.isPasswordVisible : false,
        textDirection: TextDirection.ltr,
        textAlign: TextAlign.right,
        textInputAction: widget.textInputAction,
        onFieldSubmitted: widget.onSubmit,
        validator: widget.validator,
        style: const TextStyle(
          fontFamily: 'Cairo',
          fontSize: 15,
          fontWeight: FontWeight.w600,
          color: TaqwaColors.nightSky,
        ),
        decoration: InputDecoration(
          hintText: widget.hint,
          hintStyle: TextStyle(
            fontFamily: 'Cairo',
            color: TaqwaColors.gray.withValues(alpha: 0.5),
            fontWeight: FontWeight.w400,
          ),
          prefixIcon: Icon(
            widget.icon,
            color: _focused
                ? TaqwaColors.domeBlue
                : TaqwaColors.domeBlue.withValues(alpha: 0.55),
            size: 22,
          ),
          suffixIcon: widget.isPassword
              ? IconButton(
                  icon: Icon(
                    widget.isPasswordVisible
                        ? Icons.visibility_off_rounded
                        : Icons.visibility_rounded,
                    color: TaqwaColors.gray.withValues(alpha: 0.55),
                    size: 20,
                  ),
                  onPressed: widget.onTogglePassword,
                )
              : null,
          filled: true,
          fillColor:
              _focused ? const Color(0xFFFAFBFD) : const Color(0xFFF5F7FA),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(
              color: Color(0xFFE8ECF0),
              width: 1,
            ),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(
              color: TaqwaColors.domeBlue,
              width: 1.6,
            ),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(
              color: TaqwaColors.alertRed,
              width: 1,
            ),
          ),
          focusedErrorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(
              color: TaqwaColors.alertRed,
              width: 1.6,
            ),
          ),
          errorStyle: const TextStyle(
            fontFamily: 'Cairo',
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════
// ERROR BANNER — inline, dismissible, appears above the form card
// ════════════════════════════════════════════════════════════════════

class _ErrorBanner extends StatelessWidget {
  final String message;
  final VoidCallback onDismiss;

  const _ErrorBanner({required this.message, required this.onDismiss});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFE9E9),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: TaqwaColors.alertRed.withValues(alpha: 0.38),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: TaqwaColors.alertRed.withValues(alpha: 0.18),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: TaqwaColors.alertRed.withValues(alpha: 0.15),
            ),
            child: const Icon(
              Icons.error_outline_rounded,
              color: TaqwaColors.alertRed,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              textDirection: TextDirection.rtl,
              style: const TextStyle(
                fontFamily: 'Cairo',
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: Color(0xFF8B1A1A),
                height: 1.4,
              ),
            ),
          ),
          IconButton(
            icon: Icon(
              Icons.close_rounded,
              color: TaqwaColors.alertRed.withValues(alpha: 0.75),
              size: 18,
            ),
            onPressed: onDismiss,
            splashRadius: 18,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(
              minWidth: 34,
              minHeight: 34,
            ),
          ),
        ],
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════
// ISLAMIC EIGHT-POINT STAR PATTERN (نجمة ثمانية)
// ════════════════════════════════════════════════════════════════════

class _IslamicPatternPainter extends CustomPainter {
  final Animation<double> animation;

  _IslamicPatternPainter({required this.animation})
      : super(repaint: animation);

  @override
  void paint(Canvas canvas, Size size) {
    final strokePaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.035)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8;

    final circlePaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.022)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.6;

    const double spacing = 64;
    final double driftX = (animation.value * spacing) % spacing;
    final double driftY = (animation.value * spacing * 0.6) % spacing;

    for (double x = -spacing + driftX;
        x < size.width + spacing;
        x += spacing) {
      for (double y = -spacing + driftY;
          y < size.height + spacing;
          y += spacing) {
        _drawEightStar(canvas, Offset(x, y), spacing * 0.32, strokePaint);
      }
    }

    for (double x = spacing / 2 + driftX;
        x < size.width + spacing;
        x += spacing) {
      for (double y = spacing / 2 + driftY;
          y < size.height + spacing;
          y += spacing) {
        canvas.drawCircle(Offset(x, y), spacing * 0.14, circlePaint);
      }
    }
  }

  /// Eight-pointed star = two squares rotated 45° and overlaid.
  void _drawEightStar(Canvas canvas, Offset c, double r, Paint paint) {
    void drawSquareAt(double angleOffset) {
      final path = Path();
      for (int i = 0; i < 4; i++) {
        final angle = (i * math.pi / 2) + angleOffset;
        final x = c.dx + r * math.cos(angle);
        final y = c.dy + r * math.sin(angle);
        if (i == 0) {
          path.moveTo(x, y);
        } else {
          path.lineTo(x, y);
        }
      }
      path.close();
      canvas.drawPath(path, paint);
    }

    drawSquareAt(-math.pi / 2);
    drawSquareAt(-math.pi / 2 + math.pi / 4);
  }

  @override
  bool shouldRepaint(covariant _IslamicPatternPainter oldDelegate) => true;
}