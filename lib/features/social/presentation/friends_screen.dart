import 'package:flutter/material.dart';
import '../../../widgets/platform_theme.dart';
import 'wake_together_setup_screen.dart';

class FriendsScreen extends StatelessWidget {
  const FriendsScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final friends = [
      {'name': 'Alex', 'status': 'Active 2h ago', 'icon': Icons.person},
      {'name': 'Jamie', 'status': 'Sleeping', 'icon': Icons.nights_stay},
      {'name': 'Taylor', 'status': 'Awake', 'icon': Icons.wb_sunny},
    ];

    return PlatformScaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Text('Friends', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.onSurface)),
            ),
            Expanded(
              child: ListView.builder(
                itemCount: friends.length,
                itemBuilder: (context, index) {
                  final friend = friends[index];
                  return ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    leading: CircleAvatar(
                      backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                      child: Icon(friend['icon'] as IconData, color: Theme.of(context).colorScheme.onPrimaryContainer),
                    ),
                    title: Text(friend['name'] as String, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    subtitle: Text(friend['status'] as String),
                    trailing: FilledButton.tonal(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => WakeTogetherSetupScreen(friendName: friend['name'] as String)),
                        );
                      },
                      child: const Text('Wake Together'),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
