import 'dart:convert';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../domain/sound_model.dart';

/// Lets the user import their own audio file to use as an ambient/relax
/// sound. Deliberately scoped to the Sleep tab's ambient sounds, not the
/// alarm sound picker: AlarmKit's AlertConfiguration.AlertSound.named() on
/// iOS 26+ requires a sound file physically compiled into the app bundle
/// at build time — it cannot point at an arbitrary file picked at
/// runtime, so a "custom alarm sound" feature would either silently not
/// work on the actual native alert, or need a much larger dual-layer
/// redesign. Ambient sounds have no such restriction — they're only ever
/// played through Wakely's own AudioPlayer, which accepts any local file.
class CustomSoundService {
  static const String _prefsKey = 'wakely_custom_sounds';

  /// Lets the user pick an audio file and copies it into the app's own
  /// documents directory (the path a file_picker result hands back isn't
  /// guaranteed to remain valid after the picker closes, so it must be
  /// copied to a stable location Wakely owns before it can be trusted to
  /// still exist on the next app launch).
  static Future<SoundModel?> importSound() async {
    final result = await FilePicker.pickFiles(
      type: FileType.audio,
      withData: false,
    );
    final pickedPath = result?.files.single.path;
    if (pickedPath == null) return null;

    final pickedFile = File(pickedPath);
    final docsDir = await getApplicationDocumentsDirectory();
    final soundsDir = Directory('${docsDir.path}/custom_sounds');
    if (!await soundsDir.exists()) {
      await soundsDir.create(recursive: true);
    }

    final id = 'custom_${DateTime.now().millisecondsSinceEpoch}';
    final originalName = pickedPath.split('/').last;
    final ext = originalName.contains('.') ? originalName.split('.').last : 'mp3';
    final destPath = '${soundsDir.path}/$id.$ext';
    await pickedFile.copy(destPath);

    // Strip the extension and common separators for a friendlier display name.
    final displayName = originalName
        .replaceAll(RegExp(r'\.[^.]+$'), '')
        .replaceAll(RegExp(r'[_-]+'), ' ')
        .trim();

    final sound = SoundModel(
      id: id,
      name: displayName.isEmpty ? 'Custom Sound' : displayName,
      source: SoundSource.custom,
      path: destPath,
    );

    final all = await getCustomSounds();
    all.add(sound);
    await _save(all);
    return sound;
  }

  static Future<void> deleteCustomSound(String id) async {
    final all = await getCustomSounds();
    final sound = all.where((s) => s.id == id).firstOrNull;
    all.removeWhere((s) => s.id == id);
    await _save(all);
    if (sound != null) {
      final file = File(sound.path);
      if (await file.exists()) await file.delete();
    }
  }

  static Future<List<SoundModel>> getCustomSounds() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_prefsKey);
    if (raw == null) return [];
    final List<dynamic> list = jsonDecode(raw);
    return list.map((m) => SoundModel(
      id: m['id'],
      name: m['name'],
      source: SoundSource.custom,
      path: m['path'],
    )).toList();
  }

  static Future<void> _save(List<SoundModel> sounds) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = jsonEncode(sounds.map((s) => {
      'id': s.id,
      'name': s.name,
      'path': s.path,
    }).toList());
    await prefs.setString(_prefsKey, raw);
  }
}
