import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'core/theme/taqwa_colors.dart';
import 'core/theme/taqwa_theme.dart';
import 'core/network/api_client.dart';
import 'core/storage/secure_storage_service.dart';
import 'features/auth/data/repositories/auth_repository.dart';
import 'features/auth/presentation/providers/auth_provider.dart';
import 'features/terms/presentation/providers/term_provider.dart';
import 'features/auth/presentation/screens/login_screen.dart';
import 'features/auth/domain/enums/user_role.dart';
import 'features/admin/presentation/screens/admin_home_screen.dart';
import 'features/student_dashboard/presentation/screens/student_dashboard_screen.dart';
import 'features/instructor_home/presentation/screens/instructor_dashboard_screen.dart';
import 'features/supervisor/presentation/screens/supervisor_home_screen.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'core/services/notification_service.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
    ),
  );

  final apiClient = ApiClient.instance;
  final storage = SecureStorageService();
  final authRepository = AuthRepository(
    apiClient: apiClient,
    storage: storage,
  );

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) => AuthProvider(authRepository: authRepository),
        ),
        // Courses (دورات) are app-wide: the leaderboard, a student's points
        // and the recording screens all have to agree on which course is on
        // screen and which one new records land in.
        ChangeNotifierProvider(create: (_) => TermProvider()),
      ],
      child: const TaqwaApp(),
    ),
  );
}

class TaqwaApp extends StatefulWidget {
  const TaqwaApp({super.key});

  @override
  State<TaqwaApp> createState() => _TaqwaAppState();
}

class _TaqwaAppState extends State<TaqwaApp> {
  bool _showSplash = true;

  // Held directly rather than looked up again in dispose(): reading a
  // provider off a defunct element throws, and this widget is torn down with
  // the app.
  AuthProvider? _auth;
  VoidCallback? _authListener;

  @override
  void initState() {
    super.initState();
    Future.microtask(() async {
      context.read<AuthProvider>().tryAutoLogin();
      await Future.delayed(const Duration(seconds: 4));
      if (mounted) setState(() => _showSplash = false);
    });
    _loadTermsWhenSignedIn();
  }

  // ═══════════════════════════════════════════════════════════════════
  // COURSES (دورات)
  //
  // The course list needs a token, so it is fetched once sign-in completes
  // and cleared on sign-out — otherwise the next user to sign in on the same
  // device would inherit the previous one's course selection.
  //
  // Only ADMIN and INSTRUCTOR fetch it: GET /terms is closed to students, and
  // their screens never need it — with no `termId` sent, the backend answers
  // with the active course, which is exactly what a student should see.
  // ═══════════════════════════════════════════════════════════════════
  void _loadTermsWhenSignedIn() {
    final auth = context.read<AuthProvider>();
    _auth = auth;

    void sync() {
      // Deferred: AuthProvider may notify mid-build, and TermProvider
      // notifying back from inside that frame would rebuild during layout.
      Future.microtask(() {
        if (!mounted) return;
        final terms = context.read<TermProvider>();
        final user = auth.user;
        if (!auth.isAuthenticated || user == null) {
          terms.reset();
          return;
        }
        if (user.role == UserRole.admin || user.role == UserRole.instructor) {
          terms.load();
        }
      });
    }

    _authListener = sync;
    auth.addListener(sync);
    sync();
  }

  @override
  void dispose() {
    final listener = _authListener;
    if (listener != null) _auth?.removeListener(listener);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      scaffoldMessengerKey: NotificationService.scaffoldKey,
      title: 'التقوى',
      debugShowCheckedModeBanner: false,
      theme: TaqwaTheme.light,
      locale: const Locale('ar'),
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('ar'),
        Locale('en'),
      ],
      home: Consumer<AuthProvider>(
        builder: (context, authProvider, _) {
          if (_showSplash ||
              authProvider.status == AuthStatus.initial ||
              authProvider.status == AuthStatus.loading) {
            return const _SplashScreen();
          }

          if (!authProvider.isAuthenticated) {
            return const LoginScreen();
          }

          switch (authProvider.user!.role) {
            case UserRole.admin:
              return const AdminHomeScreen();
            case UserRole.instructor:
              return const InstructorDashboardScreen();
            case UserRole.student:
              return const StudentDashboardScreen();
            case UserRole.supervisor:
              return const SupervisorHomeScreen();
          }
        },
      ),
    );
  }
}

class _SplashScreen extends StatefulWidget {
  const _SplashScreen();

  @override
  State<_SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<_SplashScreen>
    with TickerProviderStateMixin {
  late AnimationController _mosqueController;
  late AnimationController _textController;
  late AnimationController _shimmerController;

  late Animation<double> _mosqueFade;
  late Animation<double> _mosqueScale;
  late Animation<double> _textFade;
  late Animation<Offset> _textSlide;
  late Animation<double> _sloganFade;
  late Animation<double> _loaderFade;

  @override
  void initState() {
    super.initState();

    _mosqueController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _mosqueFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _mosqueController, curve: Curves.easeOut),
    );
    _mosqueScale = Tween<double>(begin: 0.7, end: 1.0).animate(
      CurvedAnimation(parent: _mosqueController, curve: Curves.easeOutBack),
    );

    _textController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );
    _textFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
          parent: _textController,
          curve: const Interval(0.0, 0.6, curve: Curves.easeOut)),
    );
    _textSlide = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(parent: _textController, curve: Curves.easeOutCubic),
    );
    _sloganFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
          parent: _textController,
          curve: const Interval(0.3, 0.8, curve: Curves.easeOut)),
    );
    _loaderFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
          parent: _textController,
          curve: const Interval(0.6, 1.0, curve: Curves.easeOut)),
    );

    _shimmerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat(reverse: true);

    _mosqueController.forward();
    Future.delayed(const Duration(milliseconds: 800), () {
      if (mounted) _textController.forward();
    });
  }

  @override
  void dispose() {
    _mosqueController.dispose();
    _textController.dispose();
    _shimmerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        body: Container(
          width: double.infinity,
          height: double.infinity,
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Color(0xFF0D1B2A),
                Color(0xFF1A1A2E),
                Color(0xFF16213E),
                Color(0xFF1B4F72),
              ],
              stops: [0.0, 0.3, 0.7, 1.0],
            ),
          ),
          child: SafeArea(
            child: Column(
              children: [
                const Spacer(flex: 2),

                // Mosque Logo with glow
                FadeTransition(
                  opacity: _mosqueFade,
                  child: ScaleTransition(
                    scale: _mosqueScale,
                    child: AnimatedBuilder(
                      animation: _shimmerController,
                      builder: (context, child) {
                        return Container(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFFD4AC0D).withOpacity(
                                    0.08 + _shimmerController.value * 0.12),
                                blurRadius:
                                    40 + _shimmerController.value * 20,
                                spreadRadius:
                                    5 + _shimmerController.value * 10,
                              ),
                            ],
                          ),
                          child: child,
                        );
                      },
                      child: Container(
                        width: 200,
                        height: 200,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white.withOpacity(0.06),
                          border: Border.all(
                            color: const Color(0xFFD4AC0D).withOpacity(0.3),
                            width: 2,
                          ),
                        ),
                        child: ClipOval(
                          child: Padding(
                            padding: const EdgeInsets.all(20),
                            child: Image.asset(
                              'assets/images/mosque_logo.png',
                              fit: BoxFit.contain,
                              errorBuilder: (_, __, ___) => const Icon(
                                Icons.mosque_rounded,
                                size: 80,
                                color: Color(0xFFD4AC0D),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 30),

                // جامع التقوى in gold
                SlideTransition(
                  position: _textSlide,
                  child: FadeTransition(
                    opacity: _textFade,
                    child: SizedBox(
                      width: 260,
                      child: Image.asset(
                        'assets/images/taqwa_text.png',
                        fit: BoxFit.contain,
                        color: const Color(0xFFD4AC0D),
                        colorBlendMode: BlendMode.srcIn,
                        errorBuilder: (_, __, ___) => const Text(
                          'جامع التقوى',
                          style: TextStyle(
                            fontFamily: 'ArefRuqaa',
                            fontSize: 36,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFFD4AC0D),
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 20),

                // Decorative divider
                FadeTransition(
                  opacity: _sloganFade,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                          width: 40,
                          height: 1,
                          color: const Color(0xFFD4AC0D).withOpacity(0.3)),
                      const SizedBox(width: 12),
                      Text('✦',
                          style: TextStyle(
                              fontSize: 12,
                              color: const Color(0xFFD4AC0D)
                                  .withOpacity(0.5))),
                      const SizedBox(width: 12),
                      Container(
                          width: 40,
                          height: 1,
                          color: const Color(0xFFD4AC0D).withOpacity(0.3)),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // Slogan
                FadeTransition(
                  opacity: _sloganFade,
                  child: Text(
                    'إلهي أنت مقصودي ورضاك مطلوبي',
                    style: TextStyle(
                      fontFamily: 'ArefRuqaa',
                      fontSize: 16,
                      color: Colors.white.withOpacity(0.45),
                      height: 1.8,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),

                const Spacer(flex: 2),

                // Loading indicator
                FadeTransition(
                  opacity: _loaderFade,
                  child: Column(
                    children: [
                      SizedBox(
                        width: 32,
                        height: 32,
                        child: CircularProgressIndicator(
                          color: const Color(0xFFD4AC0D),
                          backgroundColor:
                              const Color(0xFFD4AC0D).withOpacity(0.12),
                          strokeWidth: 2.5,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'جارِ التحميل...',
                        style: TextStyle(
                          fontFamily: 'Cairo',
                          fontSize: 12,
                          color: Colors.white.withOpacity(0.35),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
      ),
    );
  }
}