import 'dart:io';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:haptic_feedback/haptic_feedback.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:permission_handler/permission_handler.dart';
import 'main_screen.dart';
import 'edit_alarm_screen.dart';
import '../services/analytics_service.dart';
import '../theme/design_tokens.dart';
import '../widgets/animated_pressable.dart';
import '../widgets/fade_slide_in.dart';
import '../widgets/breathing_icon.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({Key? key}) : super(key: key);

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  static const int _totalPages = 6;

  final PageController _pageController = PageController();
  int _currentPage = 0;

  String? _selectedStruggle;
  double _selectedSleepGoal = 8.0;
  DateTime _selectedWakeTime = DateTime(2024, 1, 1, 7, 0);
  bool _permissionsRequested = false;

  @override
  void initState() {
    super.initState();
    AnalyticsService.logEvent('onboarding_started');
  }

  // The struggle someone picks maps to the mission most likely to actually
  // fix it, so the first alarm this screen offers to create isn't a
  // generic default - it's already pointed at what they said they need.
  String _struggleToMission(String? struggle) {
    switch (struggle) {
      case 'sleep_through':
        return 'memory';
      case 'snooze':
        return 'shake';
      case 'groggy':
        return 'steps';
      default:
        return 'memory';
    }
  }

  Future<void> _completeOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('has_seen_onboarding', true);

    if (mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const MainScreen()),
      );
    }
  }

  Future<void> _requestPermissions() async {
    if (Platform.isIOS) {
      await [
        Permission.notification,
        Permission.criticalAlerts,
        Permission.activityRecognition,
      ].request();
    } else if (Platform.isAndroid) {
      await [
        Permission.notification,
        Permission.systemAlertWindow,
        Permission.ignoreBatteryOptimizations,
        Permission.activityRecognition,
      ].request();
    }
  }

  void _goToPage(int page) {
    Haptics.vibrate(HapticsType.selection);
    _pageController.animateToPage(page, duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
  }

  void _openAlarmCreation() async {
    AnalyticsService.logEvent('onboarding_create_alarm_tapped');
    final res = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => EditAlarmScreen(
          initialTime: _selectedWakeTime,
          initialMission: _struggleToMission(_selectedStruggle),
          initialSleepGoal: _selectedSleepGoal,
        ),
      ),
    );

    if (res != null) {
      AnalyticsService.logEvent('first_alarm_created');
    }
    // Whether they created one or backed out, onboarding is done either
    // way - forcing alarm creation to escape onboarding was the exact
    // friction point this screen used to have.
    _completeOnboarding();
  }

  void _skipAlarmCreation() {
    Haptics.vibrate(HapticsType.light);
    AnalyticsService.logEvent('onboarding_skipped_alarm');
    _completeOnboarding();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              child: Row(
                children: [
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(AppTokens.radiusSm),
                      child: TweenAnimationBuilder<double>(
                        tween: Tween(begin: 0, end: (_currentPage + 1) / _totalPages),
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeOut,
                        builder: (context, value, _) => LinearProgressIndicator(
                          value: value,
                          backgroundColor: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.1),
                          valueColor: const AlwaysStoppedAnimation<Color>(AppTokens.signal),
                          minHeight: 8,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            Expanded(
              child: PageView(
                controller: _pageController,
                physics: const NeverScrollableScrollPhysics(),
                onPageChanged: (index) {
                  setState(() => _currentPage = index);
                },
                children: [
                  _buildWelcome(),
                  _buildStruggle(),
                  _buildSleepGoal(),
                  _buildWakeTime(),
                  _buildPermissions(),
                  _buildFinalCTA(),
                ],
              ),
            ),

            Padding(
              padding: const EdgeInsets.all(24.0),
              child: _buildBottomArea(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomArea() {
    if (_currentPage == _totalPages - 1) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _openAlarmCreation,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTokens.signal,
                foregroundColor: Theme.of(context).colorScheme.surface,
                padding: const EdgeInsets.symmetric(vertical: 20),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTokens.radiusSm)),
              ),
              child: const Text(
                "CREATE MY FIRST ALARM",
                style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16, letterSpacing: 1.2),
              ),
            ),
          ),
          const SizedBox(height: 12),
          AnimatedPressable(
            onTap: _skipAlarmCreation,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(
                "I'll do this later",
                style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 15, fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ],
      );
    }

    final bool canContinue = switch (_currentPage) {
      1 => _selectedStruggle != null,
      _ => true,
    };

    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: canContinue
            ? () async {
                if (_currentPage == 1) {
                  final prefs = await SharedPreferences.getInstance();
                  await prefs.setString('onboarding_goal', _selectedStruggle!);
                  AnalyticsService.logEvent('onboarding_struggle_selected', {'struggle': _selectedStruggle});
                } else if (_currentPage == 3) {
                  AnalyticsService.logEvent('onboarding_wake_time_selected');
                } else if (_currentPage == 4 && !_permissionsRequested) {
                  _permissionsRequested = true;
                  await _requestPermissions();
                }
                if (mounted) _goToPage(_currentPage + 1);
              }
            : null,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppTokens.signal,
          foregroundColor: Theme.of(context).colorScheme.surface,
          disabledBackgroundColor: AppTokens.signal.withValues(alpha: 0.3),
          padding: const EdgeInsets.symmetric(vertical: 20),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTokens.radiusSm)),
        ),
        child: Text(
          _currentPage == 4 ? "ENABLE & CONTINUE" : "CONTINUE",
          style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16, letterSpacing: 1.2),
        ),
      ),
    );
  }

  Widget _buildWelcome() {
    return Padding(
      padding: const EdgeInsets.all(32.0),
      child: FadeSlideIn(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            BreathingIcon(
              icon: Icons.wb_sunny_rounded,
              size: 140,
              iconSize: 72,
              color: AppTokens.signal,
              backgroundColor: AppTokens.signal.withValues(alpha: 0.12),
            ),
            const SizedBox(height: 40),
            Text(
              "Welcome to Wakle",
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.w900,
                color: Theme.of(context).colorScheme.onSurface,
                height: 1.2,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              "A few quick questions so your mornings actually fit you — then we'll get your first alarm set up.",
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16, color: Theme.of(context).colorScheme.onSurfaceVariant, height: 1.5),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStruggle() {
    return Padding(
      padding: const EdgeInsets.all(32.0),
      child: FadeSlideIn(child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "What's your biggest struggle waking up?",
            style: TextStyle(
              fontSize: 30,
              fontWeight: FontWeight.w900,
              color: Theme.of(context).colorScheme.onSurface,
              height: 1.2,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            "We'll pick your first mission based on this.",
            style: TextStyle(fontSize: 16, color: Theme.of(context).colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: 40),
          _buildSelectionButton(Icons.bedtime, "I sleep right through my alarm", 'sleep_through', _selectedStruggle, (val) {
            Haptics.vibrate(HapticsType.selection);
            setState(() => _selectedStruggle = val);
          }),
          const SizedBox(height: 16),
          _buildSelectionButton(Icons.snooze, "I hit snooze way too many times", 'snooze', _selectedStruggle, (val) {
            Haptics.vibrate(HapticsType.selection);
            setState(() => _selectedStruggle = val);
          }),
          const SizedBox(height: 16),
          _buildSelectionButton(Icons.cloud, "I wake up but feel groggy all morning", 'groggy', _selectedStruggle, (val) {
            Haptics.vibrate(HapticsType.selection);
            setState(() => _selectedStruggle = val);
          }),
          const SizedBox(height: 16),
          _buildSelectionButton(Icons.track_changes, "Nothing specific, I just want consistency", 'consistency', _selectedStruggle, (val) {
            Haptics.vibrate(HapticsType.selection);
            setState(() => _selectedStruggle = val);
          }),
        ],
      )),
    );
  }

  Widget _buildSelectionButton(IconData icon, String label, String value, String? selectedValue, Function(String) onSelect) {
    bool isSelected = selectedValue == value;
    return AnimatedPressable(
      onTap: () => onSelect(value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 24),
        decoration: BoxDecoration(
          color: isSelected ? AppTokens.signal.withValues(alpha: 0.15) : Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
          border: Border.all(color: isSelected ? AppTokens.signal : Colors.transparent, width: 2),
          borderRadius: BorderRadius.circular(AppTokens.radiusSm),
        ),
        child: Row(
          children: [
            Icon(icon, size: 24, color: isSelected ? AppTokens.signal : Theme.of(context).colorScheme.onSurface),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: isSelected ? AppTokens.signal : Theme.of(context).colorScheme.onSurface,
                ),
              ),
            ),
            AnimatedScale(
              scale: isSelected ? 1.0 : 0.0,
              duration: const Duration(milliseconds: 200),
              child: const Icon(Icons.check_circle, color: AppTokens.signal, size: 22),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSleepGoal() {
    return Padding(
      padding: const EdgeInsets.all(32.0),
      child: FadeSlideIn(child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "How many hours of sleep do you want each night?",
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w900,
              color: Theme.of(context).colorScheme.onSurface,
              height: 1.2,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            "We'll use this to track your sleep goal.",
            style: TextStyle(fontSize: 16, color: Theme.of(context).colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: 40),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [6.0, 7.0, 8.0, 9.0].map((hours) {
              final isSelected = _selectedSleepGoal == hours;
              return AnimatedPressable(
                onTap: () {
                  Haptics.vibrate(HapticsType.selection);
                  setState(() => _selectedSleepGoal = hours);
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 76,
                  height: 76,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: isSelected ? AppTokens.signal : Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(AppTokens.radiusSm),
                    border: Border.all(color: isSelected ? AppTokens.signal : Colors.transparent, width: 2),
                  ),
                  child: Text(
                    '${hours.toInt()}h',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                      color: isSelected ? Theme.of(context).colorScheme.surface : Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      )),
    );
  }

  Widget _buildWakeTime() {
    return Padding(
      padding: const EdgeInsets.all(32.0),
      child: FadeSlideIn(child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "What time do you want to wake up?",
            style: TextStyle(
              fontSize: 30,
              fontWeight: FontWeight.w900,
              color: Theme.of(context).colorScheme.onSurface,
              height: 1.2,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            "We'll pre-fill your first alarm with this time.",
            style: TextStyle(fontSize: 16, color: Theme.of(context).colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: 24),
          Container(
            height: 200,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(AppTokens.radiusLg),
            ),
            child: CupertinoTheme(
              data: CupertinoThemeData(
                brightness: Brightness.dark,
                primaryColor: AppTokens.signal,
                textTheme: CupertinoTextThemeData(
                  dateTimePickerTextStyle: TextStyle(
                    color: Theme.of(context).colorScheme.onSurface,
                    fontSize: 32,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              child: CupertinoDatePicker(
                mode: CupertinoDatePickerMode.time,
                initialDateTime: _selectedWakeTime,
                onDateTimeChanged: (newTime) {
                  Haptics.vibrate(HapticsType.selection);
                  setState(() => _selectedWakeTime = newTime);
                },
              ),
            ),
          ),
        ],
      )),
    );
  }

  Widget _buildPermissions() {
    return Padding(
      padding: const EdgeInsets.all(32.0),
      child: FadeSlideIn(child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          BreathingIcon(
            icon: Icons.notifications_active_rounded,
            size: 100,
            iconSize: 52,
            color: AppTokens.signal,
            backgroundColor: AppTokens.signal.withValues(alpha: 0.12),
          ),
          const SizedBox(height: 32),
          Text(
            "One last thing",
            style: TextStyle(
              fontSize: 30,
              fontWeight: FontWeight.w900,
              color: Theme.of(context).colorScheme.onSurface,
              height: 1.2,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            "Wakle needs a few permissions to actually wake you up reliably:",
            style: TextStyle(fontSize: 16, color: Theme.of(context).colorScheme.onSurfaceVariant, height: 1.4),
          ),
          const SizedBox(height: 20),
          _buildPermissionRow(Icons.alarm, "Alarms & Notifications", "So your alarm fires on time, every time"),
          const SizedBox(height: 12),
          _buildPermissionRow(Icons.directions_walk, "Motion & Fitness", "For step-based and shake-based wake missions"),
        ],
      )),
    );
  }

  Widget _buildPermissionRow(IconData icon, String title, String subtitle) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 22, color: AppTokens.signal),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Theme.of(context).colorScheme.onSurface)),
              Text(subtitle, style: TextStyle(fontSize: 13, color: Theme.of(context).colorScheme.onSurfaceVariant)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildFinalCTA() {
    return Padding(
      padding: const EdgeInsets.all(32.0),
      child: FadeSlideIn(child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          BreathingIcon(
            icon: Icons.alarm_on_rounded,
            size: 140,
            iconSize: 72,
            color: AppTokens.signal,
            backgroundColor: AppTokens.signal.withValues(alpha: 0.12),
          ),
          const SizedBox(height: 40),
          Text(
            "You're all set",
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.w900,
              color: Theme.of(context).colorScheme.onSurface,
              height: 1.2,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            "Let's create your first alarm for ${TimeOfDay.fromDateTime(_selectedWakeTime).format(context)} — or skip and set one up whenever you're ready.",
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 16, color: Theme.of(context).colorScheme.onSurfaceVariant, height: 1.5),
          ),
        ],
      )),
    );
  }
}
