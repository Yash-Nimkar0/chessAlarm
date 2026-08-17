import 'package:flutter/material.dart';
import '../../../widgets/platform_theme.dart';
import '../../../theme/design_tokens.dart';

class WakeTogetherSetupScreen extends StatefulWidget {
  final String friendName;
  const WakeTogetherSetupScreen({Key? key, required this.friendName}) : super(key: key);

  @override
  State<WakeTogetherSetupScreen> createState() => _WakeTogetherSetupScreenState();
}

class _WakeTogetherSetupScreenState extends State<WakeTogetherSetupScreen> {
  TimeOfDay _selectedTime = const TimeOfDay(hour: 7, minute: 0);
  bool _inviteSent = false;
  bool _inviteAccepted = false;
  
  final TextEditingController _giftController = TextEditingController();

  void _sendInvite() {
    setState(() => _inviteSent = true);
    // Simulate friend accepting after 2 seconds
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) setState(() => _inviteAccepted = true);
    });
  }

  @override
  void dispose() {
    _giftController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PlatformScaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => Navigator.pop(context)),
              const SizedBox(height: 16),
              Text('Wake with ${widget.friendName}', style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold)),
              const SizedBox(height: 32),
              
              Container(
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  title: const Text('Wake Time', style: TextStyle(fontWeight: FontWeight.bold)),
                  trailing: Text(_selectedTime.format(context), style: const TextStyle(fontSize: 24, color: AppTokens.signal)),
                  onTap: _inviteSent ? null : () async {
                    final time = await showTimePicker(context: context, initialTime: _selectedTime);
                    if (time != null) setState(() => _selectedTime = time);
                  },
                ),
              ),
              
              const SizedBox(height: 24),
              const Text('Morning Gift (Optional)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 8),
              const Text('Leave a message that unlocks after they complete their morning mission.', style: TextStyle(fontSize: 14, color: Colors.grey)),
              const SizedBox(height: 12),
              TextField(
                controller: _giftController,
                enabled: !_inviteSent,
                maxLines: 3,
                decoration: InputDecoration(
                  hintText: 'e.g. Good morning! Don\'t forget we have coffee at 9.',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),

              const Spacer(),
              
              if (!_inviteSent)
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: FilledButton(
                    onPressed: _sendInvite,
                    style: FilledButton.styleFrom(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
                    child: const Text('Send Invite', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  ),
                )
              else if (!_inviteAccepted)
                Column(
                  children: [
                    const Center(child: CircularProgressIndicator()),
                    const SizedBox(height: 16),
                    Text('Waiting for ${widget.friendName} to accept...', style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
                  ],
                )
              else
                Column(
                  children: [
                    const Icon(Icons.check_circle, color: Colors.green, size: 48),
                    const SizedBox(height: 16),
                    Text('${widget.friendName} accepted!', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: FilledButton(
                        onPressed: () {
                          // In a real app we'd save this to the controller
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Social Alarm Scheduled!')));
                        },
                        style: FilledButton.styleFrom(
                          backgroundColor: Colors.green,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))
                        ),
                        child: const Text('Done', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}
