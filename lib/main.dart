import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:alarm/alarm.dart';
import 'screens/main_screen.dart';
import 'screens/slide_to_stop_screen.dart';
import 'screens/ringing_screen.dart';
import 'screens/onboarding_screen.dart';
import 'services/analytics_service.dart';
import 'services/sleep_service.dart';
import 'services/notification_service.dart';

import 'package:shared_preferences/shared_preferences.dart';

import 'services/theme_service.dart';
import 'theme/design_tokens.dart';
import 'widgets/splash_screen.dart';
import 'services/wallpaper_service.dart';

import 'features/alarms/data/alarm_migration.dart';
import 'features/alarms/data/alarm_repository.dart';
import 'features/alarms/data/alarm_scheduler.dart';
import 'features/alarms/application/alarm_controller.dart';
import 'features/alarms/application/wake_session_controller.dart';

import 'package:sentry_flutter/sentry_flutter.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
  ]);
  
  await SentryFlutter.init(
    (options) {
      options.dsn = const String.fromEnvironment('SENTRY_DSN', defaultValue: '');
      options.tracesSampleRate = 1.0;
    },
    appRunner: () => runApp(const WakelyAppLoader()),
  );
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
    // ThemeService().init() was never called anywhere in the app — the
    // persisted theme mode (light/dark/system) and board theme were saved
    // correctly whenever changed, but never actually loaded back on a
    // fresh cold start, which always used the hardcoded ThemeMode.dark
    // default instead regardless of what was saved. Confirmed live:
    // switching to Light mode, then fully restarting the app, silently
    // reverted to Dark every time.
    await ThemeService().init();
    await WallpaperService().init();

    // Timeout Alarm.init in case of audio session deadlocks on iOS
    try {
      // Restore Alarm.init() since we resolved the crash
      await Alarm.init().timeout(const Duration(seconds: 5));
      
      // Initialize AlarmController which sets up the correct PlatformScheduler and native event listeners
      await AlarmController.instance.init();
      
      await NotificationService.initialize();
      await NotificationService.setupSleepReminders();
      await SleepService.cleanupOldClips();
      await SleepService.recoverOrphanedSession();
      
      await AnalyticsService.init();
      await AnalyticsService.checkRetention();


    } catch (e) {
      debugPrint("Alarm init failed or timed out: $e");
    }

    // Run alarm migration if necessary
    await AlarmMigration.migrateIfNeeded(AlarmRepository(), AlarmScheduler());

    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('has_seen_onboarding') ?? false;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: _initFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SplashScreen();
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

  @override
  void initState() {
    super.initState();
    _ringSubscription = Alarm.ringing.listen((alarmSet) {
      if (alarmSet.alarms.isNotEmpty) {
        navigateToRingScreen(alarmSet.alarms.first);
      }
    });

    // Listen for state changes instead of flaky ephemeral events
    WakeSessionController.instance.addListener(_onWakeSessionChanged);
    
    // Check if we booted up with an active session already queued
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _onWakeSessionChanged();
    });
  }

  bool _isShowingWakeUI = false;

  void _onWakeSessionChanged() {
    final session = WakeSessionController.instance;
    final nav = navigatorKey.currentState;
    
    if (nav == null) return;

    if (session.isActive && !_isShowingWakeUI && session.activeAlarm != null) {
      _isShowingWakeUI = true;
      nav.push(
        MaterialPageRoute(
          builder: (context) => RingingScreen(alarmSettings: session.activeAlarm!.toAlarmSettings()),
        ),
      ).then((_) {
        _isShowingWakeUI = false;
      });
    } else if (!session.isActive && _isShowingWakeUI) {
      // If the session was closed programmatically (e.g. stopped externally)
      // we might want to pop, but typically RingingScreen handles its own pop.
    }
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
    WakeSessionController.instance.removeListener(_onWakeSessionChanged);
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
          surface: AppTokens.nightSurface,
          primary: AppTokens.signal,
        ).copyWith(
          secondary: AppTokens.signal.withValues(alpha: 0.8), // Slightly muted amber
          tertiary: const Color(0xFF9E9E9E), // True neutral gray (grey.shade500)
          surfaceContainerHighest: const Color(0xFF2B2A33), // Neutral dark gray derived from nightSurface
          surfaceContainerHigh: const Color(0xFF222129),
          secondaryContainer: const Color(0xFF332B1A), // Dark surface with amber tint
          tertiaryContainer: const Color(0xFF26252C), // Slightly lighter neutral surface
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
                borderRadius: BorderRadius.circular(AppTokens.radiusLg),
              ),
              elevation: 0,
              color: Colors.black.withValues(alpha: 0.05),
            ),
            elevatedButtonTheme: ElevatedButtonThemeData(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTokens.signal.withValues(alpha: 0.15),
                foregroundColor: AppTokens.signalDeep,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppTokens.radiusLg),
                  side: BorderSide(color: AppTokens.signal.withValues(alpha: 0.3), width: 1),
                ),
                padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
              ),
            ),
            filledButtonTheme: FilledButtonThemeData(
              style: FilledButton.styleFrom(
                backgroundColor: AppTokens.signal.withValues(alpha: 0.15),
                foregroundColor: AppTokens.signalDeep,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppTokens.radiusLg),
                  side: BorderSide(color: AppTokens.signal.withValues(alpha: 0.3), width: 1),
                ),
                padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
              ),
            ),
            // Without these, FloatingActionButton and Switch fall back to
            // Material 3's default of colorScheme.primary — which is
            // deliberately the dawnStart purple in light mode, not amber.
            // Every other interactive element (buttons above, dark mode's
            // whole theme) is explicitly amber, so a purple FAB and switch
            // thumb read as a jarring, unrelated second accent color rather
            // than a deliberate choice. Dark mode doesn't need this
            // override — its colorScheme.primary already IS AppTokens.signal.
            floatingActionButtonTheme: FloatingActionButtonThemeData(
              backgroundColor: AppTokens.signal,
              foregroundColor: AppTokens.signalDeep,
            ),
            switchTheme: SwitchThemeData(
              thumbColor: WidgetStateProperty.resolveWith((states) =>
                  states.contains(WidgetState.selected) ? AppTokens.signal : null),
              trackColor: WidgetStateProperty.resolveWith((states) =>
                  states.contains(WidgetState.selected) ? AppTokens.signal.withValues(alpha: 0.4) : null),
            ),
          ),
          darkTheme: ThemeData(
            useMaterial3: true,
            colorScheme: darkColorScheme,
            scaffoldBackgroundColor: AppTokens.nightSurface,
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
                borderRadius: BorderRadius.circular(AppTokens.radiusLg),
              ),
              elevation: 0,
              color: Colors.white.withValues(alpha: 0.05),
            ),
            elevatedButtonTheme: ElevatedButtonThemeData(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTokens.signal,
                foregroundColor: AppTokens.nightSurface,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppTokens.radiusLg),
                ),
                padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
              ),
            ),
            filledButtonTheme: FilledButtonThemeData(
              style: FilledButton.styleFrom(
                backgroundColor: AppTokens.signal,
                foregroundColor: AppTokens.nightSurface,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppTokens.radiusLg),
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
