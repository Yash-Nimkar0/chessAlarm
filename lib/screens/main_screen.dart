import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
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
      onTap: (index) => setState(() => _currentIndex = index),
    );

    if (Platform.isIOS) {
      bottomNavBar = ClipRRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.05),
            child: bottomNavBar,
          ),
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
    return PlatformScaffold(
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
