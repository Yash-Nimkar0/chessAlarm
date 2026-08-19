import 'package:flutter/material.dart';
import 'package:haptic_feedback/haptic_feedback.dart';
import '../../models/mission_settings.dart';
import '../../services/preferences_service.dart';
import '../../models/default_quotes.dart';
import '../../theme/design_tokens.dart';

class TypingConfigScreen extends StatefulWidget {
  final MissionSettings initialSettings;

  const TypingConfigScreen({Key? key, required this.initialSettings}) : super(key: key);

  @override
  State<TypingConfigScreen> createState() => _TypingConfigScreenState();
}

class _TypingConfigScreenState extends State<TypingConfigScreen> {
  late int _rounds;
  final List<String> _defaultQuotes = DefaultQuotes.quotes;
  List<String> _customQuotes = [];
  Set<String> _enabledQuotes = {};

  final TextEditingController _addQuoteController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _rounds = widget.initialSettings.missionRounds;
    
    // Load enabled quotes from missionData
    final data = widget.initialSettings.missionData;
    if (data != null && data['enabled_quotes'] != null) {
      _enabledQuotes = Set<String>.from(data['enabled_quotes']);
    } else {
      _enabledQuotes = Set<String>.from(_defaultQuotes);
    }

    _loadCustomQuotes();
  }

  Future<void> _loadCustomQuotes() async {
    final custom = await PreferencesService.getCustomQuotes();
    setState(() {
      _customQuotes = custom;
      // If it's a new alarm without specific data, enable all custom quotes by default
      if (widget.initialSettings.missionData == null) {
        _enabledQuotes.addAll(_customQuotes);
      }
    });
  }

  Future<void> _saveCustomQuotes() async {
    await PreferencesService.setCustomQuotes(_customQuotes);
  }

  void _addCustomQuote() {
    String text = _addQuoteController.text.trim();
    if (text.isNotEmpty && !_defaultQuotes.contains(text) && !_customQuotes.contains(text)) {
      setState(() {
        _customQuotes.add(text);
        _enabledQuotes.add(text);
        _addQuoteController.clear();
      });
      _saveCustomQuotes();
    }
  }

  void _deleteCustomQuote(String quote) {
    setState(() {
      _customQuotes.remove(quote);
      _enabledQuotes.remove(quote);
    });
    _saveCustomQuotes();
  }

  void _onSave() {
    Haptics.vibrate(HapticsType.success);
    
    // Ensure at least one quote is enabled, otherwise fallback to defaults
    List<String> finalQuotes = _enabledQuotes.isEmpty ? List.from(_defaultQuotes) : _enabledQuotes.toList();
    
    final updatedData = Map<String, dynamic>.from(widget.initialSettings.missionData ?? {});
    updatedData['enabled_quotes'] = finalQuotes;

    final resultSettings = widget.initialSettings.copyWith(
      mission: 'typing',
      missionRounds: _rounds,
      missionData: updatedData,
    );
    Navigator.pop(context, resultSettings);
  }

  void _toggleAll(bool? value) {
    setState(() {
      if (value == true) {
        _enabledQuotes.addAll(_defaultQuotes);
        _enabledQuotes.addAll(_customQuotes);
      } else {
        _enabledQuotes.clear();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    bool allEnabled = _enabledQuotes.containsAll(_defaultQuotes) && _enabledQuotes.containsAll(_customQuotes);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Typing Mission Settings'),
        actions: [
          IconButton(
            icon: const Icon(Icons.check),
            color: Colors.greenAccent,
            onPressed: _onSave,
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Number of Phrases to Type: $_rounds', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  Slider(
                    value: _rounds.toDouble(),
                    min: 1,
                    max: 10,
                    divisions: 9,
                    label: '$_rounds',
                    activeColor: AppTokens.signal,
                    onChanged: (val) => setState(() => _rounds = val.toInt()),
                  ),
                ],
              ),
            ),
            const Divider(),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Select Phrases', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  TextButton(
                    onPressed: () => _toggleAll(!allEnabled),
                    child: Text(allEnabled ? 'Deselect All' : 'Select All'),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                children: [
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                    child: Text('Default Phrases', style: TextStyle(color: Colors.grey)),
                  ),
                  ..._defaultQuotes.map((q) => CheckboxListTile(
                    title: Text(q, style: const TextStyle(fontSize: 14)),
                    value: _enabledQuotes.contains(q),
                    activeColor: AppTokens.signal,
                    onChanged: (val) {
                      setState(() {
                        if (val == true) _enabledQuotes.add(q);
                        else _enabledQuotes.remove(q);
                      });
                    },
                  )).toList(),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                    child: Text('Custom Phrases', style: TextStyle(color: Colors.grey)),
                  ),
                  ..._customQuotes.map((q) => CheckboxListTile(
                    title: Text(q, style: const TextStyle(fontSize: 14)),
                    value: _enabledQuotes.contains(q),
                    activeColor: AppTokens.signal,
                    secondary: IconButton(
                      icon: const Icon(Icons.delete, color: Colors.redAccent, size: 20),
                      onPressed: () => _deleteCustomQuote(q),
                    ),
                    onChanged: (val) {
                      setState(() {
                        if (val == true) _enabledQuotes.add(q);
                        else _enabledQuotes.remove(q);
                      });
                    },
                  )).toList(),
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _addQuoteController,
                            decoration: const InputDecoration(
                              hintText: 'Add new phrase...',
                              border: OutlineInputBorder(),
                            ),
                            onSubmitted: (_) => _addCustomQuote(),
                          ),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton(
                          onPressed: _addCustomQuote,
                          child: const Text('Add'),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
