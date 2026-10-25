import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/theme/taqwa_colors.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../data/supervisor_api.dart';
import 'supervisor_day_tab.dart';
import 'supervisor_instructors_tab.dart';
import 'supervisor_students_tab.dart';

/// ═════════════════════════════════════════════════════════════════════════
/// The course director's app («مدير الدورة»). Read-only from end to end.
///
/// Three flat screens behind a bottom bar that never goes away, so he always
/// knows where he is and never has to back out to reach anything:
///
///   الأساتذة   who records and how late — the reason this account exists,
///              so it is the screen he opens on
///   الجلسة     one meeting day across every حلقة, stepping through the
///              course's own meeting days
///   الطلاب     every student's standing over the last four weeks
///
/// The deepest anything goes is one detail screen (an أستاذ, or a حلقة on a
/// day). The tabs are kept alive, so switching never reloads or loses the
/// scroll position.
/// ═════════════════════════════════════════════════════════════════════════
class SupervisorHomeScreen extends StatefulWidget {
  /// [preview]: opened by an admin from his own home screen to see exactly
  /// what the director sees. It is then a pushed screen with a back arrow,
  /// and has no logout button — logging out there would log the admin out.
  const SupervisorHomeScreen({super.key, this.preview = false});

  final bool preview;

  @override
  State<SupervisorHomeScreen> createState() => _SupervisorHomeScreenState();
}

class _SupervisorHomeScreenState extends State<SupervisorHomeScreen> {
  final _api = SupervisorApi(ApiClient.instance);
  int _tab = 0;

  static const _titles = ['الأساتذة', 'الجلسة', 'الطلاب'];

  void _confirmLogout() {
    showDialog(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('تسجيل الخروج',
              style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold)),
          content: const Text('هل تريد تسجيل الخروج من التطبيق؟',
              style: TextStyle(fontFamily: 'Cairo')),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('إلغاء',
                  style: TextStyle(fontFamily: 'Cairo', color: Colors.grey)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: () {
                Navigator.pop(ctx);
                context.read<AuthProvider>().logout();
              },
              child: const Text('خروج',
                  style: TextStyle(fontFamily: 'Cairo', color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: TaqwaColors.background,
        appBar: AppBar(
          title: Text(
            _titles[_tab],
            style: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold),
          ),
          backgroundColor: TaqwaColors.domeBlue,
          foregroundColor: Colors.white,
          elevation: 0,
          actions: [
            Center(
              child: Container(
                margin: const EdgeInsetsDirectional.only(end: 4),
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.16),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  widget.preview ? 'معاينة' : 'قراءة فقط',
                  style: const TextStyle(fontFamily: 'Cairo', fontSize: 10.5, fontWeight: FontWeight.bold),
                ),
              ),
            ),
            if (!widget.preview)
              IconButton(
                icon: const Icon(Icons.logout_rounded),
                tooltip: 'تسجيل الخروج',
                onPressed: _confirmLogout,
              )
            else
              const SizedBox(width: 8),
          ],
        ),
        body: IndexedStack(
          index: _tab,
          children: [
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
