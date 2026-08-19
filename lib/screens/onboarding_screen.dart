import 'dart:io';
import 'package:flutter/material.dart';
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
  final PageController _pageController = PageController();
  int _currentPage = 0;
  
  String? _selectedImprovement;

  @override
  void initState() {
    super.initState();
    AnalyticsService.logEvent('onboarding_started');
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
  
  void _openAlarmCreation() async {
    await _requestPermissions();
    
    if (mounted) {
      final res = await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => const EditAlarmScreen(),
        ),
      );
      
      if (res != null) {
        // User successfully created an alarm
        AnalyticsService.logEvent('first_alarm_created');
        _completeOnboarding();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('You must create your first alarm to continue.'),
            backgroundColor: Theme.of(context).colorScheme.errorContainer,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: SafeArea(
        child: Column(
          children: [
            // Progress Bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              child: Row(
                children: [
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(AppTokens.radiusSm),
                      child: LinearProgressIndicator(
                        value: (_currentPage + 1) / 3,
                        backgroundColor: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.1),
                        valueColor: const AlwaysStoppedAnimation<Color>(AppTokens.signal),
                        minHeight: 8,
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
                  _buildSlide1(),
                  _buildSlide3(),
                ],
              ),
            ),
            
            // Bottom Button
            Padding(
              padding: const EdgeInsets.all(24.0),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () async {
                    if (_currentPage == 0) {
                      if (_selectedImprovement == null) {
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please select a goal.')));
                        return;
                      }
                      final prefs = await SharedPreferences.getInstance();
                      await prefs.setString('onboarding_goal', _selectedImprovement!);
                      AnalyticsService.logEvent('identity_selected', {'goal': _selectedImprovement});
                      _pageController.nextPage(duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
                    } else if (_currentPage == 1) {
                      _openAlarmCreation();
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTokens.signal,
                    foregroundColor: Theme.of(context).colorScheme.surface,
                    padding: const EdgeInsets.symmetric(vertical: 20),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTokens.radiusSm)),
                  ),
                  child: Text(
                    _currentPage == 1 ? "CREATE FIRST ALARM" : "CONTINUE",
                    style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16, letterSpacing: 1.2),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSlide1() {
    return Padding(
      padding: const EdgeInsets.all(32.0),
      child: FadeSlideIn(child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "What do you want to improve?",
            style: TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.w900,
              color: Theme.of(context).colorScheme.onSurface,
              height: 1.2,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            "Train your mind every morning.",
            style: TextStyle(fontSize: 16, color: Theme.of(context).colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: 40),
          _buildSelectionButton(Icons.track_changes, "Consistency", _selectedImprovement, (val) => setState(() => _selectedImprovement = val)),
          const SizedBox(height: 16),
          _buildSelectionButton(Icons.psychology, "Mental Sharpness", _selectedImprovement, (val) => setState(() => _selectedImprovement = val)),
          const SizedBox(height: 16),
          _buildSelectionButton(Icons.local_fire_department, "Discipline", _selectedImprovement, (val) => setState(() => _selectedImprovement = val)),
          const SizedBox(height: 16),
          _buildSelectionButton(Icons.bolt, "Thinking Speed", _selectedImprovement, (val) => setState(() => _selectedImprovement = val)),
        ],
      )),
    );
  }
  
  Widget _buildSelectionButton(IconData icon, String label, String? selectedValue, Function(String) onSelect) {
    bool isSelected = selectedValue == label;
    return AnimatedPressable(
      onTap: () => onSelect(label),
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
            Text(
              label,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: isSelected ? AppTokens.signal : Theme.of(context).colorScheme.onSurface,
              ),
            ),
          ],
        ),
      ),
    );
  }


  Widget _buildSlide3() {
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
            "Start your first\nmorning challenge",
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
            "You are committing to building a stronger mind.\nSet your wake up time.",
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 16, color: Theme.of(context).colorScheme.onSurfaceVariant, height: 1.5),
          ),
        ],
      )),
    );
  }
}
