import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:alarm/alarm.dart';
import 'screens/home_screen.dart';
import 'screens/ringing_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Enforce portrait mode for the alarm clock
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
  ]);
  
  // Initialize the alarm manager
  await Alarm.init();

  runApp(const ChessAlarmApp());
}

class ChessAlarmApp extends StatefulWidget {
  const ChessAlarmApp({Key? key}) : super(key: key);

  @override
  State<ChessAlarmApp> createState() => _ChessAlarmAppState();
}

class _ChessAlarmAppState extends State<ChessAlarmApp> {
  static final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
  StreamSubscription? _ringSubscription;

  @override
  void initState() {
    super.initState();
    // Listen to the alarm ring stream. When an alarm fires, push the puzzle screen!
    _ringSubscription = Alarm.ringing.listen((alarmSet) {
      if (alarmSet.alarms.isNotEmpty) {
        navigateToRingScreen(alarmSet.alarms.first);
      }
    });
  }

  void navigateToRingScreen(AlarmSettings alarmSettings) {
    navigatorKey.currentState?.push(
      MaterialPageRoute(
        builder: (context) => RingingScreen(alarmSettings: alarmSettings),
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
    return MaterialApp(
      navigatorKey: navigatorKey,
      title: 'Chess Alarm',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF0F0F13), // Deep premium dark mode
        fontFamily: 'Inter', // Sleek modern typography
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.transparent,
          elevation: 0,
          centerTitle: true,
          titleTextStyle: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w800,
            color: Colors.white,
            letterSpacing: 1.2,
          ),
        ),
        floatingActionButtonTheme: FloatingActionButtonThemeData(
          backgroundColor: Colors.greenAccent.shade400,
          foregroundColor: Colors.black,
          elevation: 10,
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.greenAccent.shade400,
            foregroundColor: Colors.black,
            elevation: 8,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            padding: const EdgeInsets.symmetric(vertical: 16),
            textStyle: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.1,
            ),
          ),
        ),
        colorScheme: ColorScheme.dark(
          primary: Colors.greenAccent.shade400,
          secondary: Colors.tealAccent,
          surface: const Color(0xFF1C1C23),
        ),
      ),
      home: const HomeScreen(),
    );
  }
}
