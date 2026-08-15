import 'package:flutter/material.dart';
import '../services/theme_service.dart';
import '../services/preferences_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import '../widgets/platform_theme.dart';
import '../theme/design_tokens.dart';

class SettingScreen extends StatefulWidget {
  const SettingScreen({Key? key}) : super(key: key);

  @override
  State<SettingScreen> createState() => _SettingScreenState();
}

class _SettingScreenState extends State<SettingScreen> {
  final bool _isSyncing = false;
  Map<String, dynamic> _stats = {};
  int _privacyMode = 2; // 0=Off, 1=Detect Only, 2=Save Moments
  String _bedtimeReminder = 'at_bedtime';
  String _userName = "Friend";

  @override
  void initState() {
    super.initState();
    _loadStats();
    _loadPrivacyMode();
    _loadBedtimeReminder();
    _loadName();
  }

  Future<void> _loadName() async {
    final name = await PreferencesService.getUserName();
    if (mounted) setState(() => _userName = name);
  }

  Future<void> _loadBedtimeReminder() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
       setState(() {
          _bedtimeReminder = prefs.getString('bedtime_reminder') ?? 'at_bedtime';
       });
    }
  }

  Future<void> _setBedtimeReminder(String mode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('bedtime_reminder', mode);
    setState(() => _bedtimeReminder = mode);
  }

  Future<void> _loadPrivacyMode() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
       setState(() {
          _privacyMode = prefs.getInt('privacy_mode') ?? 2;
       });
    }
  }

  Future<void> _setPrivacyMode(int mode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('privacy_mode', mode);
    setState(() => _privacyMode = mode);
  }

  Future<void> _loadStats() async {
    if (mounted) {
      setState(() {
        _stats = {'currentStreak': 0, 'morningsWon': 0};
      });
    }
  }



  void _openFeedback() async {
    final Uri emailLaunchUri = Uri(
      scheme: 'mailto',
      path: 'developer@wakely.com',
      query: 'subject=App Feedback&body=Tell us:%0A- What confused you?%0A- What would you add?%0A- What annoyed you?%0A',
    );
    try {
      if (!await launchUrl(emailLaunchUri)) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open email client.'), backgroundColor: Colors.red),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not open email client: $e'), backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    int currentStreak = _stats['currentStreak'] ?? 0;
    int morningsWon = _stats['morningsWon'] ?? 0;

    return PlatformScaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 16),
              Text('Settings', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.onSurface)),
              const SizedBox(height: 24),
              
              // Top Profile
              Row(
                children: [
                  CircleAvatar(
                    radius: 30,
                    backgroundColor: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.1),
                    child: Icon(Icons.person, color: Theme.of(context).colorScheme.onSurface, size: 30),
                  ),
                  const SizedBox(width: 16),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(_userName, style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontSize: 20, fontWeight: FontWeight.bold)),
                      Text('🔥 $currentStreak day streak', style: const TextStyle(color: Colors.orangeAccent)),
                    ],
                  ),
                ],
              ),
              
              const SizedBox(height: 32),
              Text('Profile', style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 16),
              _buildSection(colorScheme, [
                ListTile(
                  leading: Icon(Icons.person, color: Theme.of(context).colorScheme.onSurface),
                  title: Text('Display Name', style: TextStyle(color: Theme.of(context).colorScheme.onSurface)),
                  trailing: Icon(Icons.edit, color: Theme.of(context).colorScheme.onSurfaceVariant, size: 20),
                  onTap: () async {
                    String currentName = await PreferencesService.getUserName();
                    final controller = TextEditingController(text: currentName);
                    if (!mounted) return;
                    showDialog(
                      context: context,
                      builder: (context) => AlertDialog(
                        backgroundColor: Theme.of(context).colorScheme.surface,
                        title: const Text("Your Name"),
                        content: TextField(controller: controller, decoration: const InputDecoration(hintText: "Enter your name")),
                        actions: [
                          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
                          TextButton(
                            onPressed: () async {
                              await PreferencesService.setUserName(controller.text);
                              if (mounted) setState(() => _userName = controller.text);
                              Navigator.pop(context);
                            },
                            child: const Text("Save"),
                          ),
                        ],
                      ),
                    );
                  },
                ),
                Divider(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.12), height: 1),
                _buildListTile(Icons.workspace_premium, 'Wakely Pro', 'Upgrade', color: AppTokens.signal),
              ]),
              const SizedBox(height: 32),
              Text('Sleep Settings', style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 16),
              _buildSection(colorScheme, [
                ListTile(
                  leading: Icon(Icons.mic, color: Theme.of(context).colorScheme.onSurface),
                  title: Text('Sleep Sounds', style: TextStyle(color: Theme.of(context).colorScheme.onSurface)),
                  trailing: Text(
                    _privacyMode == 0 ? 'Off' : (_privacyMode == 1 ? 'Detect Only' : 'Save Moments'),
                    style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
                  ),
                  onTap: () {
                    showModalBottomSheet(
                      context: context,
                      builder: (context) => Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const ListTile(title: Text("Sleep Sound Capture")),

                          const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 16.0),
                            child: Text(
                              "Save interesting sounds from your night.\n\n✓ Short moments only\n✓ Stored on your device\n✓ Delete anytime",
                              style: TextStyle(color: Colors.grey, fontSize: 13, height: 1.5),
                            ),
                          ),
                          const SizedBox(height: 16),
                          ListTile(
                            title: const Text("Off"),
                            trailing: _privacyMode == 0 ? const Icon(Icons.check, color: Colors.greenAccent) : null,
                            onTap: () {
                              _setPrivacyMode(0);
                              Navigator.pop(context);
                            },
                          ),
                          ListTile(
                            title: const Text("Detect Only (No recordings)"),
                            trailing: _privacyMode == 1 ? const Icon(Icons.check, color: Colors.greenAccent) : null,
                            onTap: () {
                              _setPrivacyMode(1);
                              Navigator.pop(context);
                            },
                          ),
                          ListTile(
                            title: const Text("Save Moments (Short clips)"),
                            trailing: _privacyMode == 2 ? const Icon(Icons.check, color: Colors.greenAccent) : null,
                            onTap: () {
                              _setPrivacyMode(2);
                              Navigator.pop(context);
                            },
                          ),
                        ],
                      ),
                    );
                  },
                ),
                Divider(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.12), height: 1),
                ListTile(
                  leading: Icon(Icons.notifications_active, color: Theme.of(context).colorScheme.onSurface),
                  title: Text('Bedtime Reminders', style: TextStyle(color: Theme.of(context).colorScheme.onSurface)),
                  trailing: Text(
                    _bedtimeReminder == 'off' ? 'Off' : (_bedtimeReminder == 'at_bedtime' ? 'At bedtime' : (_bedtimeReminder == '15m' ? '15 min before' : '30 min before')),
                    style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
                  ),
                  onTap: () {
                    showModalBottomSheet(
                      context: context,
                      builder: (context) => Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const ListTile(title: Text("Bedtime Reminder")),
                          ListTile(
                            title: const Text("Off"),
                            trailing: _bedtimeReminder == 'off' ? const Icon(Icons.check, color: Colors.greenAccent) : null,
                            onTap: () {
                              _setBedtimeReminder('off');
                              Navigator.pop(context);
                            },
                          ),
                          ListTile(
                            title: const Text("At bedtime"),
                            trailing: _bedtimeReminder == 'at_bedtime' ? const Icon(Icons.check, color: Colors.greenAccent) : null,
                            onTap: () {
                              _setBedtimeReminder('at_bedtime');
                              Navigator.pop(context);
                            },
                          ),
                          ListTile(
                            title: const Text("15 min before"),
                            trailing: _bedtimeReminder == '15m' ? const Icon(Icons.check, color: Colors.greenAccent) : null,
                            onTap: () {
                              _setBedtimeReminder('15m');
                              Navigator.pop(context);
                            },
                          ),
                          ListTile(
                            title: const Text("30 min before"),
                            trailing: _bedtimeReminder == '30m' ? const Icon(Icons.check, color: Colors.greenAccent) : null,
                            onTap: () {
                              _setBedtimeReminder('30m');
                              Navigator.pop(context);
                            },
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ]),
              
              const SizedBox(height: 32),
              Text('Appearance', style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 16),
              _buildSection(colorScheme, [
                ListTile(
                  leading: Icon(Icons.dark_mode, color: Theme.of(context).colorScheme.onSurface),
                  title: Text('Theme', style: TextStyle(color: Theme.of(context).colorScheme.onSurface)),
                  trailing: Text(ThemeService().themeMode == ThemeMode.light ? 'Light' : 'Dark', style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
                  onTap: () {
                     showModalBottomSheet(
                      context: context,
                      builder: (context) => Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const ListTile(title: Text("App Theme")),
                          ListTile(
                            title: const Text("Dark"),
                            trailing: ThemeService().themeMode == ThemeMode.dark ? const Icon(Icons.check, color: Colors.greenAccent) : null,
                            onTap: () {
                              ThemeService().setThemeMode(ThemeMode.dark);
                              setState((){});
                              Navigator.pop(context);
                            },
                          ),
                          ListTile(
                            title: const Text("Light"),
                            trailing: ThemeService().themeMode == ThemeMode.light ? const Icon(Icons.check, color: Colors.greenAccent) : null,
                            onTap: () {
                              ThemeService().setThemeMode(ThemeMode.light);
                              setState((){});
                              Navigator.pop(context);
                            },
                          ),
                        ],
                      ),
                    );
                  },
                ),

              ]),
              
              const SizedBox(height: 32),
              Text('Data & Community', style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 16),
              _buildSection(colorScheme, [

                ListTile(
                  leading: Icon(Icons.chat_bubble_outline, color: Theme.of(context).colorScheme.onSurface),
                  title: Text('Help improve the app', style: TextStyle(color: Theme.of(context).colorScheme.onSurface)),
                  trailing: Icon(Icons.chevron_right, color: Theme.of(context).colorScheme.onSurfaceVariant),
                  onTap: _openFeedback,
                ),
              ]),
              
              const SizedBox(height: 48),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSection(ColorScheme colorScheme, List<Widget> children) {
    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(AppTokens.radiusLg),
      ),
      child: Material(
        type: MaterialType.transparency,
        child: Column(children: children),
      ),
    );
  }

  Widget _buildListTile(IconData icon, String title, String? trailingText, {Color? color, VoidCallback? onTap}) {
    return ListTile(
      leading: Icon(icon, color: color ?? Theme.of(context).colorScheme.onSurface),
      title: Text(title, style: TextStyle(color: Theme.of(context).colorScheme.onSurface)),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (trailingText != null)
            Text(trailingText, style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
          const SizedBox(width: 8),
          Icon(Icons.chevron_right, color: Theme.of(context).colorScheme.onSurfaceVariant),
        ],
      ),
      onTap: onTap, 
    );
  }
}
