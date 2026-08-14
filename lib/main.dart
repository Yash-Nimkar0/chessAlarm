import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:alarm/alarm.dart';
import 'screens/main_screen.dart';
import 'screens/slide_to_stop_screen.dart';
import 'screens/onboarding_screen.dart';
import 'services/weather_service.dart';
import 'services/analytics_service.dart';
import 'services/sleep_service.dart';
import 'services/notification_service.dart';

import 'package:shared_preferences/shared_preferences.dart';

import 'services/theme_service.dart';
import 'theme/design_tokens.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
  ]);
  
  runApp(const WakelyAppLoader());
}

class WakelyAppLoader extends StatefulWidget {
  const WakelyAppLoader({Key? key}) : super(key: key);

  @override
  State<WakelyAppLoader> createState() => _WakelyAppLoaderState();
}

class _WakelyAppLoaderState extends State<WakelyAppLoader> {
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
      await SleepService.recoverOrphanedSession();
      
      await AnalyticsService.init();
      await AnalyticsService.checkRetention();


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
        return WakelyApp(hasSeenOnboarding: hasSeenOnboarding);
      },
    );
  }
}

class WakelyApp extends StatefulWidget {
  final bool hasSeenOnboarding;
  const WakelyApp({Key? key, required this.hasSeenOnboarding}) : super(key: key);

  @override
  State<WakelyApp> createState() => _WakelyAppState();
}

class _WakelyAppState extends State<WakelyApp> {
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
        final darkColorScheme = ColorScheme.fromSeed(
          seedColor: AppTokens.signal,
          brightness: Brightness.dark,
          surface: AppTokens.nightBg,
          primary: AppTokens.signal,
        );
        final lightColorScheme = ColorScheme.fromSeed(
          // Deep pre-dawn indigo as primary in light mode — contrasts well against
          // the cream daylightBg (#FFF8EE). Amber signal stays as secondary accent.
          seedColor: AppTokens.dawnStart,
          brightness: Brightness.light,
          surface: AppTokens.daylightBg,
          primary: AppTokens.dawnStart,
          secondary: AppTokens.signal,
        );

        return MaterialApp(
          navigatorKey: navigatorKey,
          title: 'Wakely',
          debugShowCheckedModeBanner: false,
          themeMode: ThemeService().themeMode,
          theme: ThemeData(
            useMaterial3: true,
            colorScheme: lightColorScheme,
            scaffoldBackgroundColor: AppTokens.daylightBg,
            textTheme: AppTokens.textTheme(ThemeData.light().textTheme),
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
              color: Colors.black.withValues(alpha: 0.05),
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
            scaffoldBackgroundColor: AppTokens.nightBg,
            textTheme: AppTokens.textTheme(ThemeData.dark().textTheme),
            appBarTheme: const AppBarTheme(
              centerTitle: true,
              backgroundColor: Colors.transparent,
              elevation: 0,
              foregroundColor: Colors.white,
            ),
            cardTheme: CardThemeData(
              margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(28),
              ),
              elevation: 0,
              color: Colors.white.withValues(alpha: 0.05),
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
      }
    );
  }
}
