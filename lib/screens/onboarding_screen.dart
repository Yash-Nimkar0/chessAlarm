import 'dart:io';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:permission_handler/permission_handler.dart';
import 'home_screen.dart';
import 'edit_alarm_screen.dart';
import '../services/elo_service.dart';
import '../services/analytics_service.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({Key? key}) : super(key: key);

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;
  
  String? _selectedImprovement;
  int? _selectedElo;

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
        MaterialPageRoute(builder: (context) => const HomeScreen()),
      );
    }
  }

  Future<void> _requestPermissions() async {
    if (Platform.isIOS) {
      await [
        Permission.notification,
        Permission.criticalAlerts,
      ].request();
    } else if (Platform.isAndroid) {
      await [
        Permission.notification,
        Permission.systemAlertWindow,
        Permission.ignoreBatteryOptimizations,
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
          const SnackBar(
            content: Text('You must create your first alarm to continue.'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
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
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: (_currentPage + 1) / 3,
                        backgroundColor: Colors.white24,
                        valueColor: const AlwaysStoppedAnimation<Color>(Colors.greenAccent),
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
                  _buildSlide2(),
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
                      if (_selectedElo == null) {
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please select your level.')));
                        return;
                      }
                      await EloService.setElo(_selectedElo!);
                      AnalyticsService.logEvent('level_selected', {'elo': _selectedElo});
                      _pageController.nextPage(duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
                    } else if (_currentPage == 2) {
                      _openAlarmCreation();
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.greenAccent,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 20),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  child: Text(
                    _currentPage == 2 ? "CREATE FIRST ALARM" : "CONTINUE",
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
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "What do you want to improve?",
            style: TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.w900,
              color: Colors.white,
              height: 1.2,
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            "Train your mind every morning.",
            style: TextStyle(fontSize: 16, color: Colors.white70),
          ),
          const SizedBox(height: 40),
          
          _buildSelectionButton("♟", "Chess Skill", _selectedImprovement, (val) => setState(() => _selectedImprovement = val)),
          const SizedBox(height: 16),
          _buildSelectionButton("🧠", "Mental Sharpness", _selectedImprovement, (val) => setState(() => _selectedImprovement = val)),
          const SizedBox(height: 16),
          _buildSelectionButton("🔥", "Discipline", _selectedImprovement, (val) => setState(() => _selectedImprovement = val)),
          const SizedBox(height: 16),
          _buildSelectionButton("⚡", "Thinking Speed", _selectedImprovement, (val) => setState(() => _selectedImprovement = val)),
        ],
      ),
    );
  }
  
  Widget _buildSelectionButton(String icon, String label, String? selectedValue, Function(String) onSelect) {
    bool isSelected = selectedValue == label;
    return GestureDetector(
      onTap: () => onSelect(label),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 24),
        decoration: BoxDecoration(
          color: isSelected ? Colors.greenAccent.withOpacity(0.15) : Colors.white.withOpacity(0.05),
          border: Border.all(color: isSelected ? Colors.greenAccent : Colors.transparent, width: 2),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            Text(icon, style: const TextStyle(fontSize: 24)),
            const SizedBox(width: 16),
            Text(
              label,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: isSelected ? Colors.greenAccent : Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSlide2() {
    return Padding(
      padding: const EdgeInsets.all(32.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "What's your chess level?",
            style: TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.w900,
              color: Colors.white,
              height: 1.2,
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            "We'll calibrate your morning puzzles so they wake you up without frustrating you.",
            style: TextStyle(fontSize: 16, color: Colors.white70),
          ),
          const SizedBox(height: 40),
          
          _buildEloSelectionButton("New to Chess", 400),
          const SizedBox(height: 16),
          _buildEloSelectionButton("Casual Player", 1000),
          const SizedBox(height: 16),
          _buildEloSelectionButton("Experienced Player", 1800),
        ],
      ),
    );
  }
  
  Widget _buildEloSelectionButton(String label, int eloValue) {
    bool isSelected = _selectedElo == eloValue;
    return GestureDetector(
      onTap: () => setState(() => _selectedElo = eloValue),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 24),
        decoration: BoxDecoration(
          color: isSelected ? Colors.blueAccent.withOpacity(0.15) : Colors.white.withOpacity(0.05),
          border: Border.all(color: isSelected ? Colors.blueAccent : Colors.transparent, width: 2),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: isSelected ? Colors.blueAccent : Colors.white,
          ),
        ),
      ),
    );
  }

  Widget _buildSlide3() {
    return Padding(
      padding: const EdgeInsets.all(32.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const Icon(Icons.alarm_on_rounded, size: 100, color: Colors.amberAccent),
          const SizedBox(height: 40),
          const Text(
            "Start your first\nmorning challenge",
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.w900,
              color: Colors.white,
              height: 1.2,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            "You are committing to building a stronger mind.\nSet your wake up time.",
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 16, color: Colors.white.withOpacity(0.7), height: 1.5),
          ),
        ],
      ),
    );
  }
}
