import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart' hide AudioEvent;
import 'package:intl/intl.dart';
import '../services/sleep_service.dart';
import '../theme/design_tokens.dart';
import 'animated_pressable.dart';

class AudioClipTile extends StatefulWidget {
  final AudioEvent event;
  final DateTime sessionStart;

  const AudioClipTile({Key? key, required this.event, required this.sessionStart}) : super(key: key);

  @override
  State<AudioClipTile> createState() => _AudioClipTileState();
}

class _AudioClipTileState extends State<AudioClipTile> {
  final AudioPlayer _player = AudioPlayer();
  bool _isPlaying = false;
  late bool _isSaved;

  @override
  void initState() {
    super.initState();
    _isSaved = widget.event.isSaved;
    _player.onPlayerStateChanged.listen((state) {
      if (mounted) {
        setState(() {
          _isPlaying = state == PlayerState.playing;
        });
      }
    });
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  void _togglePlay() async {
    if (_isPlaying) {
      await _player.pause();
    } else {
      await _player.play(DeviceFileSource(widget.event.file));
    }
  }

  void _toggleSave() async {
    await SleepService.toggleSavedState(widget.sessionStart, widget.event.file);
    if (mounted) {
      setState(() {
        _isSaved = !_isSaved;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_isSaved ? "Saved. Will not auto-delete." : "Unsaved."),
          backgroundColor: _isSaved ? Colors.green : Colors.orange,
        ),
      );
    }
  }

  Future<void> _deleteClip() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete Clip?'),
        content: const Text('This sleep audio clip will be permanently removed.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text('Delete', style: TextStyle(color: Theme.of(dialogContext).colorScheme.error)),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    await SleepService.deleteAudioEvent(widget.sessionStart, widget.event.file);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Clip deleted"),
          backgroundColor: Colors.redAccent,
        ),
      );
      // To properly remove from UI, we need a callback, or the parent just rebuilds
      // For now we just pop if needed, but a setState might not remove it from parent list.
      // Easiest is to force a re-fetch in the parent via Navigator pop/push or callback.
      // But we can also just hide it locally:
      setState(() {
         _isHidden = true;
      });
    }
  }

  bool _isHidden = false;

  @override
  Widget build(BuildContext context) {
    final timeStr = DateFormat('h:mm a').format(widget.event.time);

    return AnimatedSize(
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOut,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 200),
        opacity: _isHidden ? 0.0 : 1.0,
        child: _isHidden
            ? const SizedBox.shrink()
            : AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                margin: const EdgeInsets.symmetric(vertical: 8),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: _isPlaying
                      ? Colors.blueAccent.withValues(alpha: 0.12)
                      : Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(AppTokens.radiusSm),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('${widget.event.type} • $timeStr', style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 4),
                        Text('${widget.event.durationSeconds} seconds', style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 12)),
                      ],
                    ),
                    Row(
                      children: [
                        AnimatedPressable(
                          onTap: _toggleSave,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(_isSaved ? Icons.star : Icons.star_border, color: _isSaved ? Colors.amber : Theme.of(context).colorScheme.onSurfaceVariant, size: 20),
                                const SizedBox(width: 4),
                                Text('Keep', style: TextStyle(color: _isSaved ? Colors.amber : Theme.of(context).colorScheme.onSurfaceVariant)),
                              ],
                            ),
                          ),
                        ),
                        AnimatedPressable(
                          onTap: _deleteClip,
                          child: Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: Icon(Icons.delete_outline, color: Theme.of(context).colorScheme.onSurfaceVariant),
                          ),
                        ),
                        AnimatedPressable(
                          onTap: _togglePlay,
                          child: Padding(
                            padding: const EdgeInsets.all(4.0),
                            child: Icon(_isPlaying ? Icons.pause_circle_filled : Icons.play_circle_fill, color: Colors.blueAccent, size: 36),
                          ),
                        ),
                      ],
                    )
                  ],
                ),
              ),
      ),
    );
  }
}
