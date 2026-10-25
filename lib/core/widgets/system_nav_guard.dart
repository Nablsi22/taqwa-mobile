import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';

/// Keeps the whole app clear of the phone's own navigation bar.
///
/// Since Android 15 every app is drawn edge to edge: the system's back, home
/// and recents buttons (or the gesture bar) are laid over the app, so the
/// last items of a list, a bottom button or a bottom sheet ended up under
/// them. Wrapping the app once, in `MaterialApp.builder`, lifts everything —
/// screens, dialogs, bottom sheets — above that bar, instead of patching
/// every list's padding one by one.
///
/// The strip behind the bar is painted white with dark buttons. A dark
/// full-screen page (the splash, the course director's welcome) calls
/// [useDark] with the colour of its own bottom edge while it is shown, and
/// [release] when it closes, so the strip matches it.
///
/// When the keyboard is open, `MediaQuery.padding.bottom` is already zero, so
/// no extra gap appears above the keyboard.
///
/// References
///   Edge-to-edge on Android 15   https://developer.android.com/develop/ui/views/layout/edge-to-edge
///   SafeArea                     https://api.flutter.dev/flutter/widgets/SafeArea-class.html
///   SystemUiOverlayStyle         https://api.flutter.dev/flutter/services/SystemUiOverlayStyle-class.html
class SystemNavGuard extends StatelessWidget {
  const SystemNavGuard({super.key, required this.child});

  final Widget child;

  static const Color lightStrip = Colors.white;
  static const Color darkStrip = Color(0xFF1B4F72);

  /// The dark pages currently shown, most recent last.
  static final ValueNotifier<List<Color>> _darkScreens = ValueNotifier<List<Color>>(const []);

  /// A dark full-screen page is now showing. Safe to call from `initState`.
  static void useDark([Color color = darkStrip]) => _change(() => [..._darkScreens.value, color]);

  /// That page has closed. Safe to call from `dispose`.
  static void release() => _change(() {
        final list = [..._darkScreens.value];
        if (list.isNotEmpty) list.removeLast();
        return list;
      });

  // Pages call these while the tree is being built or torn down, when an
  // ancestor may not be marked dirty; the change then waits for the end of
  // the frame.
  static void _change(List<Color> Function() next) {
    void apply() => _darkScreens.value = next();

    final phase = SchedulerBinding.instance.schedulerPhase;
    if (phase == SchedulerPhase.idle || phase == SchedulerPhase.postFrameCallbacks) {
      apply();
    } else {
      SchedulerBinding.instance.addPostFrameCallback((_) => apply());
    }
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<List<Color>>(
      valueListenable: _darkScreens,
      child: SafeArea(top: false, left: false, right: false, child: child),
      builder: (context, darkPages, safeChild) {
        final dark = darkPages.isNotEmpty;
        final strip = dark ? darkPages.last : lightStrip;
        // Found at the bottom edge of the screen, this region decides the
        // navigation bar's look; an app bar's region at the top keeps
        // deciding the status bar.
        return AnnotatedRegion<SystemUiOverlayStyle>(
          value: SystemUiOverlayStyle(
            systemNavigationBarColor: strip,
            systemNavigationBarDividerColor: strip,
            systemNavigationBarIconBrightness: dark ? Brightness.light : Brightness.dark,
            systemNavigationBarContrastEnforced: false,
          ),
          child: ColoredBox(color: strip, child: safeChild),
        );
      },
    );
  }
}
