import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'home_screen.dart';
import 'sleep_screen.dart';
import 'morning_screen.dart';
import 'report_screen.dart';
import 'setting_screen.dart';
import '../widgets/platform_theme.dart';

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
    final colorScheme = Theme.of(context).colorScheme;

    Widget bottomNavBar = NavigationBar(
      selectedIndex: _currentIndex,
      onDestinationSelected: (index) {
        setState(() {
          _currentIndex = index;
        });
      },
      destinations: const [
        NavigationDestination(icon: Icon(Icons.alarm), label: 'Alarm'),
        NavigationDestination(icon: Icon(Icons.nights_stay), label: 'Sleep'),
        NavigationDestination(icon: Icon(Icons.wb_sunny), label: 'Morning'),
        NavigationDestination(icon: Icon(Icons.receipt_long), label: 'Report'),
        NavigationDestination(icon: Icon(Icons.settings), label: 'Setting'),
      ],
    );

    if (Platform.isIOS) {
      bottomNavBar = ClipRRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            color: Colors.white.withOpacity(0.05),
            child: BottomNavigationBar(
              backgroundColor: Colors.transparent,
              elevation: 0,
              currentIndex: _currentIndex,
              selectedItemColor: Colors.white,
              unselectedItemColor: Colors.white54,
              onTap: (index) {
                setState(() {
                  _currentIndex = index;
                });
              },
              items: const [
                BottomNavigationBarItem(icon: Icon(Icons.alarm), label: 'Alarm'),
                BottomNavigationBarItem(icon: Icon(Icons.nights_stay), label: 'Sleep'),
                BottomNavigationBarItem(icon: Icon(Icons.wb_sunny), label: 'Morning'),
                BottomNavigationBarItem(icon: Icon(Icons.receipt_long), label: 'Report'),
                BottomNavigationBarItem(icon: Icon(Icons.settings), label: 'Setting'),
              ],
            ),
          ),
        ),
      );
    }

    // Wrap everything in one PlatformScaffold for the background.
    // The inner screens will just use standard transparent Scaffolds.
    return PlatformScaffold(
      body: _screens[_currentIndex],
      bottomNavigationBar: bottomNavBar,
    );
  }
}
