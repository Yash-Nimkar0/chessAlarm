import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart' hide AudioEvent;
import 'package:intl/intl.dart';
import '../services/sleep_service.dart';

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

  void _deleteClip() async {
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
    if (_isHidden) return const SizedBox.shrink();
    final timeStr = DateFormat('h:mm a').format(widget.event.time);
    
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.3),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('${widget.event.type} • $timeStr', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Text('${widget.event.durationSeconds} seconds', style: const TextStyle(color: Colors.white54, fontSize: 12)),
            ],
          ),
          Row(
            children: [
              TextButton.icon(
                icon: Icon(_isSaved ? Icons.star : Icons.star_border, color: _isSaved ? Colors.amber : Colors.white54, size: 20),
                label: Text('Keep', style: TextStyle(color: _isSaved ? Colors.amber : Colors.white54)),
                onPressed: _toggleSave,
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline, color: Colors.white54),
                onPressed: _deleteClip,
              ),
              IconButton(
                icon: Icon(_isPlaying ? Icons.pause_circle_filled : Icons.play_circle_fill, color: Colors.blueAccent, size: 36),
                onPressed: _togglePlay,
              ),
            ],
          )
        ],
      ),
    );
  }
}
