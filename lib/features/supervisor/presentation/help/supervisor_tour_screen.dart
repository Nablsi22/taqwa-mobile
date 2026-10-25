import 'package:flutter/material.dart';

import '../../../../core/theme/taqwa_colors.dart';
import '../../../attendance_stats/presentation/attendance_ui.dart';
import '../supervisor_ui.dart';

/// The short introduction shown the first time the director opens his
/// account: five pages, one idea each, with a big picture, a title and two
/// or three lines. «التالي» moves on, «تخطّي» closes it, and the last page
/// says where the full guide is.
class SupervisorTourScreen extends StatefulWidget {
  const SupervisorTourScreen({super.key});

  static Future<void> show(BuildContext context) {
    return Navigator.of(context).push(
      PageRouteBuilder<void>(
        fullscreenDialog: true,
        transitionDuration: const Duration(milliseconds: 400),
        reverseTransitionDuration: const Duration(milliseconds: 350),
        pageBuilder: (_, _, _) => const SupervisorTourScreen(),
        transitionsBuilder: (_, animation, _, child) => FadeTransition(
          opacity: animation,
          child: SlideTransition(
            position: Tween(begin: const Offset(0, 0.04), end: Offset.zero)
                .chain(CurveTween(curve: Curves.easeOutCubic))
                .animate(animation),
            child: child,
          ),
        ),
      ),
    );
  }

  @override
  State<SupervisorTourScreen> createState() => _SupervisorTourScreenState();
}

class _TourPage {
  const _TourPage({
    required this.icon,
    required this.color,
    required this.title,
    required this.lines,
    this.illustration,
  });

  final IconData icon;
  final Color color;
  final String title;
  final List<String> lines;
  final Widget? illustration;
}

class _SupervisorTourScreenState extends State<SupervisorTourScreen> {
  final _controller = PageController();
  int _page = 0;

  static final _pages = <_TourPage>[
    const _TourPage(
      icon: Icons.visibility_rounded,
      color: TaqwaColors.domeBlue,
      title: 'حساب للاطلاع والمتابعة',
      lines: [
        'من هذا الحساب ترى كل ما يجري في الدورة: الأساتذة، والحضور، والتسميع، والنقاط.',
        'ولا يمكن تعديل أي شيء منه، فاضغط على ما تشاء بلا قلق.',
      ],
    ),
    const _TourPage(
      icon: Icons.home_rounded,
      color: TaqwaColors.islamicGreen,
      title: 'الرئيسية: الخلاصة في صفحة واحدة',
      lines: [
        'من لم يسجّل الحضور من الأساتذة، وكم طالباً حضر، ومن يحتاج من الطلاب إلى اتصال.',
        'اضغط على أي بطاقة لترى تفاصيلها.',
      ],
    ),
    _TourPage(
      icon: Icons.groups_rounded,
      color: AttendanceColors.lateArrival,
      title: 'الأساتذة: مربعات ملوّنة',
      lines: const [
        'لكل أستاذ أربعة مربعات لآخر أربع جلسات: الأخضر سجّل في يومها، والأحمر لم يسجّل.',
        'اضغط على اسم الأستاذ لترى حلقته وتسميع طلابه ونقاطهم.',
      ],
      illustration: const _StripExample(),
    ),
    const _TourPage(
      icon: Icons.event_note_rounded,
      color: TaqwaColors.skyBlue,
      title: 'الجلسة والطلاب',
      lines: [
        'الجلسة: يوم واحد لكل الحلقات معاً، من حضر ومن غاب في كل حلقة.',
        'الطلاب: من هو ثابت، ومن انقطع، ومن يحتاج إلى اتصال.',
      ],
    ),
    const _TourPage(
      icon: Icons.help_rounded,
      color: TaqwaColors.minaretGold,
      title: 'الشرح دائماً بجانبك',
      lines: [
        'بجانب كل عنوان زر «شرح»؛ اضغطه لترى شرحاً مبسّطاً لذلك القسم.',
        'وفي أعلى الصفحة زر «الدليل» فيه شرح مفصّل لكل ما يمكنك معرفته من هذا الحساب.',
      ],
    ),
  ];

  bool get _last => _page == _pages.length - 1;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _next() {
    if (_last) {
      Navigator.of(context).maybePop();
    } else {
      _controller.nextPage(duration: const Duration(milliseconds: 380), curve: Curves.easeOutCubic);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: TaqwaColors.background,
        body: SafeArea(
          child: Column(
            children: [
              Align(
                alignment: AlignmentDirectional.centerEnd,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(8, 4, 8, 0),
                  child: AnimatedOpacity(
                    opacity: _last ? 0 : 1,
                    duration: const Duration(milliseconds: 200),
                    child: TextButton(
                      onPressed: _last ? null : () => Navigator.of(context).maybePop(),
                      child: Text(
                        'تخطّي',
                        style: TextStyle(fontFamily: 'Cairo', fontSize: 14, color: Colors.grey.shade600),
                      ),
                    ),
                  ),
                ),
              ),
              Expanded(
                child: PageView.builder(
                  controller: _controller,
                  itemCount: _pages.length,
                  onPageChanged: (i) => setState(() => _page = i),
                  itemBuilder: (_, i) => _PageBody(page: _pages[i]),
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  for (var i = 0; i < _pages.length; i++)
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 250),
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      width: i == _page ? 22 : 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: i == _page ? TaqwaColors.domeBlue : TaqwaColors.lightGray,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                ],
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 22, 24, 20),
                child: SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: _next,
                    style: FilledButton.styleFrom(
                      backgroundColor: _last ? TaqwaColors.islamicGreen : TaqwaColors.domeBlue,
                      padding: const EdgeInsets.symmetric(vertical: 15),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    child: Text(
                      _last ? 'ابدأ' : 'التالي',
                      style: const TextStyle(fontFamily: 'Cairo', fontSize: 16, fontWeight: FontWeight.bold),
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
}

class _PageBody extends StatelessWidget {
  const _PageBody({required this.page});

  final _TourPage page;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(28, 24, 28, 12),
      child: Column(
        children: [
          Container(
            width: 132,
            height: 132,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [page.color.withValues(alpha: 0.20), page.color.withValues(alpha: 0.05)],
              ),
            ),
            child: Center(
              child: Container(
                width: 84,
                height: 84,
                decoration: BoxDecoration(color: page.color, shape: BoxShape.circle),
                child: Icon(page.icon, color: Colors.white, size: 42),
              ),
            ),
          ),
          const SizedBox(height: 30),
          Text(
            page.title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontFamily: 'Cairo',
              fontSize: 21,
              fontWeight: FontWeight.bold,
              color: AttendanceColors.ink,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 14),
          for (final line in page.lines)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                line,
                textAlign: TextAlign.center,
                style: const TextStyle(fontFamily: 'Cairo', fontSize: 15, height: 1.8, color: Color(0xFF4A5A6A)),
              ),
            ),
          if (page.illustration != null) ...[
            const SizedBox(height: 16),
            page.illustration!,
          ],
        ],
      ),
    );
  }
}

/// A sample strip of four squares with their meanings, on the «الأساتذة» page.
class _StripExample extends StatelessWidget {
  const _StripExample();

  @override
  Widget build(BuildContext context) {
    Widget box(Color c, String mark, String caption) => Expanded(
          child: Column(
            children: [
              Container(
                height: 30,
                alignment: Alignment.center,
                decoration: BoxDecoration(color: c, borderRadius: BorderRadius.circular(7)),
                child: Text(
                  mark,
                  style: const TextStyle(
                    fontFamily: 'Cairo',
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                caption,
                textAlign: TextAlign.center,
                style: TextStyle(fontFamily: 'Cairo', fontSize: 11, color: Colors.grey.shade700, height: 1.4),
              ),
            ],
          ),
        );
    return SoftCard(
      child: Row(
        children: [
          box(DisciplineColors.onTime, '✓', 'في يومها'),
          const SizedBox(width: 6),
          box(DisciplineColors.dayLate, '+1', 'بعد يوم'),
          const SizedBox(width: 6),
          box(DisciplineColors.missed, '✕', 'لم يسجّل'),
          const SizedBox(width: 6),
          box(DisciplineColors.covered, 'نيابة', 'أستاذ آخر'),
        ],
      ),
    );
  }
}
