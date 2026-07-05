import 'package:flutter/material.dart';
import '../services/theme_service.dart';
import '../services/preferences_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/puzzles.dart';
import '../widgets/platform_theme.dart';
import '../services/elo_service.dart';

class SettingScreen extends StatefulWidget {
  const SettingScreen({Key? key}) : super(key: key);

  @override
  State<SettingScreen> createState() => _SettingScreenState();
}

class _SettingScreenState extends State<SettingScreen> {
  bool _isSyncing = false;
  Map<String, dynamic> _stats = {};
  int _privacyMode = 2; // 0=Off, 1=Detect Only, 2=Save Moments
  String _bedtimeReminder = 'at_bedtime';
  String _userName = "Grandmaster";

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
    final stats = await EloService.getStats();
    if (mounted) {
      setState(() {
        _stats = stats;
      });
    }
  }

  void _syncPuzzles() async {
    setState(() => _isSyncing = true);
    final success = await PuzzleService.syncPuzzles();
    if (!mounted) return;
    setState(() => _isSyncing = false);
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(success ? 'Successfully downloaded new puzzles!' : 'Failed to sync puzzles.'),
        backgroundColor: success ? Colors.green : Colors.red,
      ),
    );
  }

  void _openFeedback() async {
    final Uri emailLaunchUri = Uri(
      scheme: 'mailto',
      path: 'developer@chessalarm.com',
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
    String rank = EloService.getLevel(morningsWon);

    return PlatformScaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 16),
              const Text('Settings', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.white)),
              const SizedBox(height: 24),
              
              // Top Profile
              Row(
                children: [
                  CircleAvatar(
                    radius: 30,
                    backgroundColor: Colors.white.withOpacity(0.1),
                    child: const Icon(Icons.person, color: Colors.white, size: 30),
                  ),
                  const SizedBox(width: 16),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('♞ $rank', style: const TextStyle(color: Colors.white54, fontWeight: FontWeight.bold)),
                      Text(_userName, style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                      Text('🔥 $currentStreak day streak', style: const TextStyle(color: Colors.orangeAccent)),
                    ],
                  ),
                ],
              ),
              
              const SizedBox(height: 32),
              const Text('Account & Premium', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 16),
              _buildSection(colorScheme, [
                ListTile(
                  leading: const Icon(Icons.person, color: Colors.white),
                  title: const Text('Profile Name', style: TextStyle(color: Colors.white)),
                  trailing: const Icon(Icons.edit, color: Colors.white54, size: 20),
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
                const Divider(color: Colors.white12, height: 1),
                _buildListTile(Icons.workspace_premium, 'Grandmaster Pro ♛', 'Upgrade', color: Colors.amberAccent),
              ]),
              
              const SizedBox(height: 32),
              const Text('Alarm Settings', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 16),
              _buildSection(colorScheme, [
                _buildListTile(Icons.tune, 'Difficulty Calibration', 'Casual', onTap: () {
                   ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Difficulty calibration coming soon!')));
                }),
                const Divider(color: Colors.white12, height: 1),
                _buildListTile(Icons.music_note, 'Alarm Sounds', null, onTap: () {
                   ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Custom alarm sounds coming soon!')));
                }),
                const Divider(color: Colors.white12, height: 1),
                _buildListTile(Icons.security, 'Grandmaster Wake Mode', 'Enabled', color: Colors.blueAccent, onTap: () {
                   ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Grandmaster Wake Mode cannot be disabled!')));
                }),
              ]),
              
              const SizedBox(height: 32),
              const Text('Sleep Settings', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 16),
              _buildSection(colorScheme, [
                ListTile(
                  leading: const Icon(Icons.mic, color: Colors.white),
                  title: const Text('Sleep Sounds', style: TextStyle(color: Colors.white)),
                  trailing: Text(
                    _privacyMode == 0 ? 'Off' : (_privacyMode == 1 ? 'Detect Only' : 'Save Moments'),
                    style: const TextStyle(color: Colors.white54),
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
                const Divider(color: Colors.white12, height: 1),
                ListTile(
                  leading: const Icon(Icons.notifications_active, color: Colors.white),
                  title: const Text('Bedtime Reminders', style: TextStyle(color: Colors.white)),
                  trailing: Text(
                    _bedtimeReminder == 'off' ? 'Off' : (_bedtimeReminder == 'at_bedtime' ? 'At bedtime' : (_bedtimeReminder == '15m' ? '15 min before' : '30 min before')),
                    style: const TextStyle(color: Colors.white54),
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
              const Text('Appearance', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 16),
              _buildSection(colorScheme, [
                ListTile(
                  leading: const Icon(Icons.dark_mode, color: Colors.white),
                  title: const Text('Theme', style: TextStyle(color: Colors.white)),
                  trailing: Text(ThemeService().themeMode == ThemeMode.light ? 'Light' : 'Dark', style: const TextStyle(color: Colors.white54)),
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
                const Divider(color: Colors.white12, height: 1),
                ListTile(
                  leading: const Icon(Icons.grid_4x4, color: Colors.white),
                  title: const Text('Board Style', style: TextStyle(color: Colors.white)),
                  trailing: Text(ThemeService().boardTheme, style: const TextStyle(color: Colors.white54)),
                  onTap: () {
                     showModalBottomSheet(
                      context: context,
                      builder: (context) => Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const ListTile(title: Text("Board Style")),
                          ...['blueGrey', 'brown', 'pink'].map((t) => ListTile(
                            title: Text(t),
                            trailing: ThemeService().boardTheme == t ? const Icon(Icons.check, color: Colors.greenAccent) : null,
                            onTap: () {
                              ThemeService().setBoardTheme(t);
                              setState((){});
                              Navigator.pop(context);
                            },
                          )).toList(),
                        ],
                      ),
                    );
                  },
                ),
              ]),
              
              const SizedBox(height: 32),
              const Text('Data & Community', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 16),
              _buildSection(colorScheme, [
                ListTile(
                  leading: const Icon(Icons.cloud_download, color: Colors.white),
                  title: const Text('Sync Puzzles from Internet', style: TextStyle(color: Colors.white)),
                  trailing: _isSyncing 
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.chevron_right, color: Colors.white54),
                  onTap: _isSyncing ? null : _syncPuzzles,
                ),
                const Divider(color: Colors.white12, height: 1),
                ListTile(
                  leading: const Icon(Icons.favorite, color: Colors.pinkAccent),
                  title: const Text('Help improve the app 🧠', style: TextStyle(color: Colors.white)),
                  trailing: const Icon(Icons.chevron_right, color: Colors.white54),
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
        color: colorScheme.surfaceContainerHighest.withOpacity(0.3),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(children: children),
    );
  }

  Widget _buildListTile(IconData icon, String title, String? trailingText, {Color? color, VoidCallback? onTap}) {
    return ListTile(
      leading: Icon(icon, color: color ?? Colors.white),
      title: Text(title, style: const TextStyle(color: Colors.white)),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (trailingText != null)
            Text(trailingText, style: const TextStyle(color: Colors.white54)),
          const SizedBox(width: 8),
          const Icon(Icons.chevron_right, color: Colors.white54),
        ],
      ),
      onTap: onTap, 
    );
  }
}
