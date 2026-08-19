import 'dart:async';
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
  final String? initialSoundId;
  final bool initialFadeIn;
  final int initialFadeDuration;
  final void Function(SoundPickerResult) onChanged;

  const SoundPickerScreen({
    Key? key,
    this.initialSoundId,
    this.initialFadeIn = true,
    this.initialFadeDuration = 30,
    required this.onChanged,
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
  Timer? _fadeTimer;
  
  late List<SoundModel> _sounds;

  @override
  void initState() {
    super.initState();
    _sounds = SoundRepository.instance.getAvailableSounds();
    _selectedSoundId = widget.initialSoundId ?? _sounds.first.id;
    _fadeIn = widget.initialFadeIn;
    _fadeDuration = widget.initialFadeDuration;
    if (_fadeDuration == 0) _fadeDuration = 30; // Migrating 'Off' from duration 0
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }

  void _togglePlay(SoundModel sound) async {
    _fadeTimer?.cancel();
    
    if (_currentlyPlayingId == sound.id) {
      await _audioPlayer.stop();
      setState(() => _currentlyPlayingId = null);
    } else {
      await _audioPlayer.stop();
      
      if (_fadeIn) {
        await _audioPlayer.setVolume(0.0);
        await _audioPlayer.play(AssetSource(sound.path.replaceFirst('assets/', '')));
        
        final steps = _fadeDuration * 10; // 10 steps per second
        int currentStep = 0;
        
        _fadeTimer = Timer.periodic(const Duration(milliseconds: 100), (timer) {
          currentStep++;
          if (currentStep >= steps) {
            _audioPlayer.setVolume(1.0);
            timer.cancel();
          } else {
            // Linear ramp
            _audioPlayer.setVolume(currentStep / steps);
          }
        });
      } else {
        await _audioPlayer.setVolume(1.0);
        await _audioPlayer.play(AssetSource(sound.path.replaceFirst('assets/', '')));
      }
      
      setState(() => _currentlyPlayingId = sound.id);
    }
  }

  void _selectSound(SoundModel sound) {
    setState(() {
      _selectedSoundId = sound.id;
    });
    widget.onChanged(SoundPickerResult(_selectedSoundId, _fadeIn, _fadeDuration));
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
                          return AnimatedContainer(
                            duration: const Duration(milliseconds: 250),
                            decoration: BoxDecoration(
                              color: isPlaying ? AppTokens.signal.withValues(alpha: 0.10) : Colors.transparent,
                              borderRadius: BorderRadius.circular(AppTokens.radiusSm),
                            ),
                            child: Material(
                            color: Colors.transparent,
                            child: ListTile(
                              leading: IconButton(
                                icon: AnimatedSwitcher(
                                  duration: const Duration(milliseconds: 200),
                                  transitionBuilder: (child, animation) => ScaleTransition(scale: animation, child: child),
                                  child: Icon(
                                    isPlaying ? Icons.stop_circle : Icons.play_circle_fill,
                                    key: ValueKey(isPlaying),
                                    color: isPlaying ? AppTokens.signal : colorScheme.onSurfaceVariant,
                                    size: 32,
                                  ),
                                ),
                                onPressed: () => _selectSound(sound),
                              ),
                              title: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    sound.name,
                                    style: TextStyle(
                                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                      color: isSelected ? AppTokens.signal : colorScheme.onSurface,
                                    ),
                                  ),
                                  if (sound.durationSeconds != null)
                                    Text(
                                      '${sound.durationSeconds} sec',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
                                      ),
                                    ),
                                ],
                              ),
                              trailing: isSelected 
                                  ? const Icon(Icons.check, color: AppTokens.signal)
                                  : null,
                              onTap: () => _selectSound(sound),
                            ),
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
                    Material(
                      color: Colors.transparent,
                      child: SwitchListTile(
                        title: Text('Fade In', style: TextStyle(fontWeight: FontWeight.bold, color: colorScheme.onSurface)),
                        subtitle: Text('Volume ramps up over time', style: TextStyle(fontSize: 12, color: colorScheme.onSurfaceVariant)),
                        contentPadding: EdgeInsets.zero,
                        value: _fadeIn,
                        onChanged: (val) {
                          setState(() => _fadeIn = val);
                          widget.onChanged(SoundPickerResult(_selectedSoundId, _fadeIn, _fadeDuration));
                          if (_currentlyPlayingId != null) {
                            _togglePlay(_sounds.firstWhere((s) => s.id == _currentlyPlayingId));
                          }
                        },
                        activeTrackColor: AppTokens.signal,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Opacity(
                      opacity: _fadeIn ? 1.0 : 0.5,
                      child: IgnorePointer(
                        ignoring: !_fadeIn,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Fade Duration', style: TextStyle(fontWeight: FontWeight.bold, color: colorScheme.onSurface)),
                            const SizedBox(height: 12),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                              children: [15, 30, 60].map((duration) {
                                final isSelected = _fadeDuration == duration;
                                return ChoiceChip(
                                  label: Text('${duration}s'),
                                  selected: isSelected,
                                  onSelected: (selected) {
                                    if (selected) {
                                      setState(() => _fadeDuration = duration);
                                      widget.onChanged(SoundPickerResult(_selectedSoundId, _fadeIn, _fadeDuration));
                                      if (_currentlyPlayingId != null && _fadeIn) {
                                        _togglePlay(_sounds.firstWhere((s) => s.id == _currentlyPlayingId));
                                      }
                                    }
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
