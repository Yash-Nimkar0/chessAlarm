import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:alarm/alarm.dart';
import 'screens/home_screen.dart';
import 'screens/main_screen.dart';
import 'screens/ringing_screen.dart';
import 'screens/slide_to_stop_screen.dart';
import 'screens/onboarding_screen.dart';
import 'services/weather_service.dart';
import 'services/analytics_service.dart';
import 'services/elo_service.dart';
import 'services/sleep_service.dart';
import 'services/notification_service.dart';
import 'models/puzzles.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:dynamic_color/dynamic_color.dart';
import 'services/theme_service.dart';
import 'services/preferences_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
  ]);
  
  runApp(const ChessAlarmAppLoader());
}

class ChessAlarmAppLoader extends StatefulWidget {
  const ChessAlarmAppLoader({Key? key}) : super(key: key);

  @override
  State<ChessAlarmAppLoader> createState() => _ChessAlarmAppLoaderState();
}

class _ChessAlarmAppLoaderState extends State<ChessAlarmAppLoader> {
  late Future<bool> _initFuture;

  @override
  void initState() {
    super.initState();
    _initFuture = _initApp();
  }

  Future<bool> _initApp() async {
    // Timeout Alarm.init in case of audio session deadlocks on iOS
    try {
      // Restore Alarm.init() since we resolved the crash
      await Alarm.init().timeout(const Duration(seconds: 5));
      
      await NotificationService.initialize();
      await NotificationService.setupSleepReminders();
      await SleepService.cleanupOldClips();
      
      await AnalyticsService.init();
      await AnalyticsService.checkRetention();

      // Try to load puzzles early
      PuzzleService.getRandomPuzzle(1000);
    } catch (e) {
      debugPrint("Alarm init failed or timed out: $e");
    }

    // Pre-fetch weather in the background
    WeatherService.getCurrentWeather();

    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('has_seen_onboarding') ?? false;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: _initFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const MaterialApp(
            debugShowCheckedModeBanner: false,
            home: Scaffold(
              backgroundColor: Colors.black,
              body: Center(
                child: CircularProgressIndicator(color: Colors.greenAccent),
              ),
            ),
          );
        }
        
        final hasSeenOnboarding = snapshot.data ?? false;
        return ChessAlarmApp(hasSeenOnboarding: hasSeenOnboarding);
      },
    );
  }
}

class ChessAlarmApp extends StatefulWidget {
  final bool hasSeenOnboarding;
  const ChessAlarmApp({Key? key, required this.hasSeenOnboarding}) : super(key: key);

  @override
  State<ChessAlarmApp> createState() => _ChessAlarmAppState();
}

class _ChessAlarmAppState extends State<ChessAlarmApp> {
  static final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
  StreamSubscription? _ringSubscription;

  // Default seed color for fallback (A modern Google-esque Green)
  static const _defaultSeedColor = Color(0xFF00C853);

  @override
  void initState() {
    super.initState();
    _ringSubscription = Alarm.ringing.listen((alarmSet) {
      if (alarmSet.alarms.isNotEmpty) {
        navigateToRingScreen(alarmSet.alarms.first);
      }
    });
  }

  void navigateToRingScreen(AlarmSettings alarmSettings) {
    navigatorKey.currentState?.push(
      MaterialPageRoute(
        builder: (context) => SlideToStopScreen(alarmSettings: alarmSettings),
      ),
    );
  }

  @override
  void dispose() {
    _ringSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: ThemeService(),
      builder: (context, _) {
        return DynamicColorBuilder(
      builder: (ColorScheme? lightDynamic, ColorScheme? darkDynamic) {
        ColorScheme darkColorScheme;
        ColorScheme lightColorScheme;

        if (darkDynamic != null && lightDynamic != null) {
          darkColorScheme = darkDynamic.harmonized();
          lightColorScheme = lightDynamic.harmonized();
        } else {
          darkColorScheme = ColorScheme.fromSeed(
            seedColor: _defaultSeedColor,
            brightness: Brightness.dark,
          );
          lightColorScheme = ColorScheme.fromSeed(
            seedColor: _defaultSeedColor,
            brightness: Brightness.light,
          );
        }

        return MaterialApp(
          navigatorKey: navigatorKey,
          title: 'Chess Alarm',
          debugShowCheckedModeBanner: false,
          themeMode: ThemeService().themeMode,
          theme: ThemeData(
            useMaterial3: true,
            colorScheme: lightColorScheme,
            fontFamily: 'Inter',
            appBarTheme: const AppBarTheme(
              centerTitle: true,
              backgroundColor: Colors.transparent,
              elevation: 0,
              foregroundColor: Colors.black,
            ),
            cardTheme: CardThemeData(
              margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(28),
              ),
              elevation: 0,
              color: lightColorScheme.surfaceContainerHighest,
            ),
            filledButtonTheme: FilledButtonThemeData(
              style: FilledButton.styleFrom(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
              ),
            ),
          ),
          darkTheme: ThemeData(
            useMaterial3: true,
            colorScheme: darkColorScheme,
            fontFamily: 'Inter',
            appBarTheme: const AppBarTheme(
              centerTitle: true,
              backgroundColor: Colors.transparent,
              elevation: 0,
            ),
            cardTheme: CardThemeData(
              margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(28),
              ),
              elevation: 0,
              color: darkColorScheme.surfaceContainerHighest,
            ),
            filledButtonTheme: FilledButtonThemeData(
              style: FilledButton.styleFrom(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
              ),
            ),
          ),
          home: widget.hasSeenOnboarding ? const MainScreen() : const OnboardingScreen(),
        );
      },
    );
      }
    );
  }
}
