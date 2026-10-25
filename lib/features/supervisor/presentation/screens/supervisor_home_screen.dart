import 'package:flutter/material.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/theme/taqwa_colors.dart';
import '../../../auth/presentation/widgets/logout_dialog.dart';
import '../../data/supervisor_api.dart';
import '../help/supervisor_guide_screen.dart';
import '../help/supervisor_help.dart';
import '../help/supervisor_prefs.dart';
import '../help/supervisor_tour_screen.dart';
import '../welcome/supervisor_welcome_screen.dart';
import 'supervisor_day_tab.dart';
import 'supervisor_instructors_tab.dart';
import 'supervisor_overview_tab.dart';
import 'supervisor_students_tab.dart';

/// ═════════════════════════════════════════════════════════════════════════
/// The course director's app («مدير الدورة»). Read-only from end to end.
///
/// Four flat screens behind a bottom bar that never goes away, so he always
/// knows where he is and never has to back out to reach anything:
///
///   الرئيسية   the whole course in four cards — what needs attention, in
///              one sentence each, and the way to the detail
///   الأساتذة   who records and how late
///   الجلسة     one meeting day across every حلقة
///   الطلاب     every student's standing over the last four weeks
///
/// Every heading has a «شرح» chip, and «الدليل» in the app bar explains the
/// whole account. On sign-in he is greeted by name; the first time on a
/// phone, a short introduction follows.
///
/// The tabs are kept alive, so switching never reloads or loses the scroll
/// position.
/// ═════════════════════════════════════════════════════════════════════════
class SupervisorHomeScreen extends StatefulWidget {
  /// [preview]: opened by an admin from his own home screen to see exactly
  /// what the director sees. It is then a pushed screen with a back arrow,
  /// no logout button, and no automatic welcome (the guide can replay it).
  const SupervisorHomeScreen({super.key, this.preview = false});

  final bool preview;

  @override
  State<SupervisorHomeScreen> createState() => _SupervisorHomeScreenState();
}

class _SupervisorHomeScreenState extends State<SupervisorHomeScreen> {
  final _api = SupervisorApi(ApiClient.instance);
  int _tab = 0;

  static const _titles = ['الرئيسية', 'الأساتذة', 'الجلسة', 'الطلاب'];
  static const _tabHelp = [HelpTopic.overview, HelpTopic.instructors, HelpTopic.day, HelpTopic.students];

  @override
  void initState() {
    super.initState();
    if (!widget.preview) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _greet());
    }
  }

  /// The welcome on every sign-in; the introduction once per phone.
  Future<void> _greet() async {
    if (!mounted) return;
    await SupervisorWelcomeScreen.show(context);
    if (!mounted) return;
    if (!await SupervisorPrefs.tourSeen()) {
      if (!mounted) return;
      await SupervisorTourScreen.show(context);
      await SupervisorPrefs.markTourSeen();
    }
  }

  void _openGuide() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => SupervisorGuideScreen(
          onGoToTab: (i) => setState(() => _tab = i),
          onReplayWelcome: () => SupervisorWelcomeScreen.show(context),
          onReplayTour: () async {
            await SupervisorPrefs.resetIntroduction();
            if (!mounted) return;
            await SupervisorTourScreen.show(context);
            await SupervisorPrefs.markTourSeen();
          },
        ),
      ),
    );
  }

  void _confirmLogout() => confirmLogout(context);


  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: TaqwaColors.background,
        appBar: AppBar(
          title: Text(
            widget.preview ? 'معاينة · ${_titles[_tab]}' : _titles[_tab],
            style: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold),
          ),
          backgroundColor: TaqwaColors.domeBlue,
          foregroundColor: Colors.white,
          elevation: 0,
          actions: [
            HelpAppBarButton(_tabHelp[_tab]),
            Padding(
              padding: const EdgeInsetsDirectional.only(end: 4),
              child: TextButton.icon(
                onPressed: _openGuide,
                style: TextButton.styleFrom(foregroundColor: Colors.white),
                icon: const Icon(Icons.auto_stories_rounded, size: 20),
                label: const Text('الدليل', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold)),
              ),
            ),
            if (!widget.preview)
              IconButton(
                icon: const Icon(Icons.logout_rounded),
                tooltip: 'تسجيل الخروج',
                onPressed: _confirmLogout,
              ),
          ],
        ),
        body: IndexedStack(
          index: _tab,
          children: [
            SupervisorOverviewTab(
              api: _api,
              preview: widget.preview,
              onOpenTab: (i) => setState(() => _tab = i),
              onOpenGuide: _openGuide,
            ),
            SupervisorInstructorsTab(api: _api),
            SupervisorDayTab(api: _api),
            SupervisorStudentsTab(api: _api),
          ],
        ),
        bottomNavigationBar: NavigationBar(
          selectedIndex: _tab,
          onDestinationSelected: (i) => setState(() => _tab = i),
          backgroundColor: Colors.white,
          indicatorColor: TaqwaColors.lightBlue,
          labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.home_outlined),
              selectedIcon: Icon(Icons.home_rounded, color: TaqwaColors.domeBlue),
              label: 'الرئيسية',
            ),
            NavigationDestination(
              icon: Icon(Icons.groups_outlined),
              selectedIcon: Icon(Icons.groups_rounded, color: TaqwaColors.domeBlue),
              label: 'الأساتذة',
            ),
            NavigationDestination(
              icon: Icon(Icons.event_note_outlined),
              selectedIcon: Icon(Icons.event_note_rounded, color: TaqwaColors.domeBlue),
              label: 'الجلسة',
            ),
            NavigationDestination(
              icon: Icon(Icons.school_outlined),
              selectedIcon: Icon(Icons.school_rounded, color: TaqwaColors.domeBlue),
              label: 'الطلاب',
            ),
          ],
        ),
      ),
    );
  }
}
