import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import '../features/sounds/domain/sound_model.dart';
import '../features/sounds/data/sound_repository.dart';
import '../widgets/platform_theme.dart';
import '../theme/design_tokens.dart';

class SoundPickerResult {
  final String soundId;
  final bool fadeIn;
  final int fadeDuration;
  SoundPickerResult(this.soundId, this.fadeIn, this.fadeDuration);
}

class SoundPickerScreen extends StatefulWidget {
  final String initialSoundId;
  final bool initialFadeIn;
  final int initialFadeDuration;

  const SoundPickerScreen({
    Key? key,
    required this.initialSoundId,
    required this.initialFadeIn,
    required this.initialFadeDuration,
  }) : super(key: key);

  @override
  State<SoundPickerScreen> createState() => _SoundPickerScreenState();
}

class _SoundPickerScreenState extends State<SoundPickerScreen> {
  late String _selectedSoundId;
  late bool _fadeIn;
  late int _fadeDuration;
  final AudioPlayer _audioPlayer = AudioPlayer();
  String? _currentlyPlayingId;
  
  late List<SoundModel> _sounds;

  @override
  void initState() {
    super.initState();
    _selectedSoundId = widget.initialSoundId;
    _fadeIn = widget.initialFadeIn;
    _fadeDuration = widget.initialFadeDuration;
    if (_fadeDuration == 0) _fadeDuration = 30; // Migrating 'Off' from duration 0
    _sounds = SoundRepository.instance.getAvailableSounds();
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }

  void _togglePlay(SoundModel sound) async {
    if (_currentlyPlayingId == sound.id) {
      await _audioPlayer.stop();
      setState(() => _currentlyPlayingId = null);
    } else {
      await _audioPlayer.stop();
      await _audioPlayer.play(AssetSource(sound.path.replaceFirst('assets/', '')));
      setState(() => _currentlyPlayingId = sound.id);
    }
  }

  void _selectSound(SoundModel sound) {
    setState(() {
      _selectedSoundId = sound.id;
    });
    // Autoplay when selected
    _togglePlay(sound);
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    
    // Group sounds by category
    final Map<String, List<SoundModel>> grouped = {};
    for (var s in _sounds) {
      final cat = s.category ?? 'Other';
      grouped.putIfAbsent(cat, () => []).add(s);
    }

    return PlatformScaffold(
      appBar: AppBar(
        title: const Text('Alarm Sound'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            Navigator.pop(context, SoundPickerResult(_selectedSoundId, _fadeIn, _fadeDuration));
          },
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              itemCount: grouped.keys.length,
              itemBuilder: (context, index) {
                final category = grouped.keys.elementAt(index);
                final categorySounds = grouped[category]!;
                
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 24, 20, 8),
                      child: Text(
                        category.toUpperCase(),
                        style: TextStyle(
                          color: colorScheme.onSurfaceVariant,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.2,
                        ),
                      ),
                    ),
                    PlatformCard(
                      margin: const EdgeInsets.symmetric(horizontal: 16),
                      child: Column(
                        children: categorySounds.map((sound) {
                          final isSelected = _selectedSoundId == sound.id;
                          final isPlaying = _currentlyPlayingId == sound.id;
                          return Material(
                            color: Colors.transparent,
                            child: ListTile(
                              leading: IconButton(
                                icon: Icon(
                                  isPlaying ? Icons.stop_circle : Icons.play_circle_fill,
                                  color: isPlaying ? AppTokens.signal : colorScheme.onSurfaceVariant,
                                  size: 32,
                                ),
                                onPressed: () => _togglePlay(sound),
                              ),
                              title: Text(
                                sound.name,
                                style: TextStyle(
                                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                  color: isSelected ? AppTokens.signal : colorScheme.onSurface,
                                ),
                              ),
                              trailing: isSelected 
                                  ? const Icon(Icons.check, color: AppTokens.signal)
                                  : null,
                              onTap: () => _selectSound(sound),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
          
          // Fade duration selector
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: colorScheme.surface,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 10,
                  offset: const Offset(0, -5),
                )
              ]
            ),
            child: SafeArea(
              top: false,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SwitchListTile(
                    title: Text('Fade in', style: TextStyle(fontWeight: FontWeight.bold, color: colorScheme.onSurface)),
                    contentPadding: EdgeInsets.zero,
                    value: _fadeIn,
                    onChanged: (val) {
                      setState(() => _fadeIn = val);
                    },
                    activeTrackColor: AppTokens.signal,
                  ),
                  const SizedBox(height: 8),
                  Opacity(
                    opacity: _fadeIn ? 1.0 : 0.5,
                    child: IgnorePointer(
                      ignoring: !_fadeIn,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Duration', style: TextStyle(fontWeight: FontWeight.bold, color: colorScheme.onSurface)),
                          const SizedBox(height: 12),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [15, 30, 60].map((duration) {
                              final isSelected = _fadeDuration == duration;
                              return ChoiceChip(
                                label: Text('${duration}s'),
                                selected: isSelected,
                                onSelected: (selected) {
                                  if (selected) setState(() => _fadeDuration = duration);
                                },
                                selectedColor: AppTokens.signal.withValues(alpha: 0.2),
                                labelStyle: TextStyle(
                                  color: isSelected ? AppTokens.signalDeep : colorScheme.onSurface,
                                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                ),
                              );
                            }).toList(),
                          ),
                        ],
                      ),
                    ),
                  )
                ],
              ),
            ),
          )
        ],
      ),
    );
  }
}
