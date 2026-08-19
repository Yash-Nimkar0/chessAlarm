import 'package:flutter/material.dart';
import '../services/theme_service.dart';
import '../services/preferences_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import '../widgets/platform_theme.dart';
import '../widgets/fade_slide_in.dart';
import '../theme/design_tokens.dart';
import '../services/elo_service.dart';
import '../services/invite_service.dart';
import '../services/wallpaper_service.dart';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';

class SettingScreen extends StatefulWidget {
  const SettingScreen({Key? key}) : super(key: key);

  @override
  State<SettingScreen> createState() => _SettingScreenState();
}

class _SettingScreenState extends State<SettingScreen> {
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
    final name = await PreferencesService.getDisplayName();
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
    // Was a hardcoded stub — Settings always showed "0 day streak"
    // regardless of the real value, disagreeing with the Report tab
    // (which does call EloService.getStats() correctly) at the same time.
    final stats = await EloService.getStats();
    if (mounted) {
      setState(() {
        _stats = stats;
      });
    }
  }

  Future<void> _pickWallpaperImage() async {
    final result = await FilePicker.pickFiles(type: FileType.image, withData: false);
    final pickedPath = result?.files.single.path;
    if (pickedPath == null) return;

    final docsDir = await getApplicationDocumentsDirectory();
    final wallpapersDir = Directory('${docsDir.path}/wallpapers');
    if (!await wallpapersDir.exists()) {
      await wallpapersDir.create(recursive: true);
    }
    final ext = pickedPath.contains('.') ? pickedPath.split('.').last : 'jpg';
    final destPath = '${wallpapersDir.path}/background.$ext';
    await File(pickedPath).copy(destPath);

    await WallpaperService().setWallpaper(destPath);
  }

  void _showWallpaperPicker() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (sheetContext, setSheetState) {
            final hasWallpaper = WallpaperService().wallpaperPath != null;
            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Background', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Theme.of(sheetContext).colorScheme.onSurface)),
                    const SizedBox(height: 4),
                    Text(
                      'Choose a photo to show behind every screen.',
                      style: TextStyle(color: Theme.of(sheetContext).colorScheme.onSurfaceVariant, fontSize: 13),
                    ),
                    const SizedBox(height: 20),
                    if (hasWallpaper) ...[
                      ClipRRect(
                        borderRadius: BorderRadius.circular(AppTokens.radiusLg),
                        child: Image.file(File(WallpaperService().wallpaperPath!), height: 140, width: double.infinity, fit: BoxFit.cover),
                      ),
                      const SizedBox(height: 16),
                      Text('Dim amount', style: TextStyle(color: Theme.of(sheetContext).colorScheme.onSurface, fontWeight: FontWeight.w600)),
                      Slider(
                        value: WallpaperService().dimAmount,
                        min: 0.0,
                        max: 0.9,
                        activeColor: AppTokens.signal,
                        onChanged: (val) {
                          WallpaperService().setDimAmount(val);
                          setSheetState(() {});
                        },
                      ),
                      const SizedBox(height: 8),
                    ],
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: () async {
                          await _pickWallpaperImage();
                          setSheetState(() {});
                        },
                        icon: const Icon(Icons.photo_library_outlined),
                        label: Text(hasWallpaper ? 'Choose a Different Photo' : 'Choose Photo'),
                      ),
                    ),
                    if (hasWallpaper) ...[
                      const SizedBox(height: 8),
                      SizedBox(
                        width: double.infinity,
                        child: TextButton(
                          onPressed: () async {
                            await WallpaperService().setWallpaper(null);
                            setSheetState(() {});
                          },
                          child: Text('Remove Background', style: TextStyle(color: Theme.of(sheetContext).colorScheme.error)),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  /// One or two initials from a display name, for the profile avatar —
  /// replaces a flat generic person-icon placeholder with something that
  /// actually reflects the user, matching how most modern apps render a
  /// profile picture before a real photo is set.
  String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return (parts.first.substring(0, 1) + parts.last.substring(0, 1)).toUpperCase();
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
              FadeSlideIn(child: Row(
                children: [
                  Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [AppTokens.signal, AppTokens.dawnEnd],
                      ),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      _initials(_userName),
                      style: const TextStyle(color: AppTokens.nightBg, fontSize: 22, fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(_userName, style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontSize: 20, fontWeight: FontWeight.bold)),
                      Row(
                        children: [
                          const Icon(Icons.local_fire_department, color: AppTokens.signal, size: 16),
                          const SizedBox(width: 4),
                          Text('$currentStreak day streak', style: const TextStyle(color: AppTokens.signal)),
                          const SizedBox(width: 12),
                          Icon(Icons.emoji_events, color: Theme.of(context).colorScheme.onSurfaceVariant, size: 16),
                          const SizedBox(width: 4),
                          Text('$morningsWon won', style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
                        ],
                      ),
                    ],
                  ),
                ],
              )),

              const SizedBox(height: 32),
              Text('Profile', style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 16),
              FadeSlideIn(delay: const Duration(milliseconds: 60), child: _buildSection(colorScheme, [
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
                ListTile(
                  leading: Icon(Icons.ios_share, color: Theme.of(context).colorScheme.onSurface),
                  title: Text('Invite Friends', style: TextStyle(color: Theme.of(context).colorScheme.onSurface)),
                  trailing: Icon(Icons.chevron_right, color: Theme.of(context).colorScheme.onSurfaceVariant),
                  onTap: () => InviteService.shareInvite(currentStreak: _stats['currentStreak']),
                ),
                Divider(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.12), height: 1),
                _buildListTile(Icons.workspace_premium, 'Wakle Pro', 'Upgrade', color: AppTokens.signal),
              ])),
              const SizedBox(height: 32),
              Text('Sleep Settings', style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 16),
              FadeSlideIn(delay: const Duration(milliseconds: 120), child: _buildSection(colorScheme, [
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
              ])),

              const SizedBox(height: 32),
              Text('Appearance', style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 16),
              FadeSlideIn(delay: const Duration(milliseconds: 180), child: _buildSection(colorScheme, [
                ListTile(
                  leading: Icon(
                    ThemeService().themeMode == ThemeMode.light
                        ? Icons.light_mode
                        : (ThemeService().themeMode == ThemeMode.dark ? Icons.dark_mode : Icons.brightness_auto),
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                  title: Text('Theme', style: TextStyle(color: Theme.of(context).colorScheme.onSurface)),
                  trailing: Text(ThemeService().themeMode == ThemeMode.light ? 'Light' : (ThemeService().themeMode == ThemeMode.dark ? 'Dark' : 'System'), style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
                  onTap: () {
                     showModalBottomSheet(
                      context: context,
                      builder: (context) => Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const ListTile(title: Text("App Theme")),
                          ListTile(
                            title: const Text("System"),
                            trailing: ThemeService().themeMode == ThemeMode.system ? const Icon(Icons.check, color: AppTokens.signal) : null,
                            onTap: () {
                              ThemeService().setThemeMode(ThemeMode.system);
                              setState((){});
                              Navigator.pop(context);
                            },
                          ),
                          ListTile(
                            title: const Text("Dark"),
                            trailing: ThemeService().themeMode == ThemeMode.dark ? const Icon(Icons.check, color: AppTokens.signal) : null,
                            onTap: () {
                              ThemeService().setThemeMode(ThemeMode.dark);
                              setState((){});
                              Navigator.pop(context);
                            },
                          ),
                          ListTile(
                            title: const Text("Light"),
                            trailing: ThemeService().themeMode == ThemeMode.light ? const Icon(Icons.check, color: AppTokens.signal) : null,
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
                ListenableBuilder(
                  listenable: WallpaperService(),
                  builder: (context, _) => ListTile(
                    leading: Icon(Icons.wallpaper, color: Theme.of(context).colorScheme.onSurface),
                    title: Text('Background', style: TextStyle(color: Theme.of(context).colorScheme.onSurface)),
                    trailing: Text(
                      WallpaperService().wallpaperPath != null ? 'Custom' : 'Default',
                      style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
                    ),
                    onTap: _showWallpaperPicker,
                  ),
                ),

              ])),

              const SizedBox(height: 32),
              Text('Support', style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 16),
              FadeSlideIn(delay: const Duration(milliseconds: 240), child: _buildSection(colorScheme, [
                ListTile(
                  leading: Icon(Icons.feedback, color: Theme.of(context).colorScheme.onSurface),
                  title: Text('Send Feedback', style: TextStyle(color: Theme.of(context).colorScheme.onSurface)),
                  trailing: Icon(Icons.chevron_right, color: Theme.of(context).colorScheme.onSurfaceVariant),
                  onTap: _openFeedback,
                ),
              ])),

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
