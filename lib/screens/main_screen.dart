import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:haptic_feedback/haptic_feedback.dart';
import 'home_screen.dart';
import 'sleep_screen.dart';
import 'morning_screen.dart';
import 'report_screen.dart';
import 'setting_screen.dart';
import '../widgets/platform_theme.dart';
import '../widgets/wakely_tab_bar.dart';

class MainScreen extends StatefulWidget {
  final int initialIndex;

  const MainScreen({Key? key, this.initialIndex = 0}) : super(key: key);

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  late int _currentIndex;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
  }

  final List<Widget> _screens = [
    const HomeScreen(),
    const SleepScreen(),
    const MorningScreen(),
    const ReportScreen(),
    const SettingScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    Widget bottomNavBar = WakelyTabBar(
      currentIndex: _currentIndex,
      onTap: (index) {
        Haptics.vibrate(HapticsType.selection);
        setState(() => _currentIndex = index);
      },
      // Index 2 is the Morning tab - its sky gradient always uses light
      // text for the same reason its own hero content does, regardless of
      // the app's light/dark theme setting.
      forceLightContent: _currentIndex == 2,
    );

    if (Platform.isIOS) {
      // No tint at all now - any solid-color wash, even faint or in the
      // "right" direction, still reads as a separate sheet sitting on top
      // rather than nothing. Pure blur with zero color underneath it is
      // the only way for the bar to have literally no distinct color of
      // its own - it just shows whatever's actually behind it, blurred.
      bottomNavBar = ClipRRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: bottomNavBar,
        ),
      );
    } else {
      bottomNavBar = Container(
        color: Theme.of(context).colorScheme.surface,
        child: bottomNavBar,
      );
    }

    // Wrap everything in one PlatformScaffold for the background.
    // The inner screens will just use standard transparent Scaffolds.
    // applySafeArea: false — every tab screen below already wraps its own
    // content in its own SafeArea; an extra one here just shrank the box
    // each tab has to work with, which broke the Morning tab's full-bleed
    // background from ever reaching the true top of the screen.
    return PlatformScaffold(
      applySafeArea: false,
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 260),
        switchInCurve: Curves.easeOutCubic,
        switchOutCurve: Curves.easeIn,
        transitionBuilder: (child, animation) => FadeTransition(
          opacity: animation,
          child: SlideTransition(
            position: Tween<Offset>(begin: const Offset(0, 0.02), end: Offset.zero).animate(animation),
            child: child,
          ),
        ),
        child: KeyedSubtree(
          key: ValueKey(_currentIndex),
          child: _screens[_currentIndex],
        ),
      ),
      bottomNavigationBar: bottomNavBar,
    );
  }
}
