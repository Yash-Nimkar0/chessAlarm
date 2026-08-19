import 'package:flutter/material.dart';
import '../theme/design_tokens.dart';
import '../widgets/platform_theme.dart';
import '../widgets/breathing_icon.dart';
import '../widgets/fade_slide_in.dart';

/// Tapping "Wakle Pro" in Settings used to do nothing at all - no onTap
/// handler, no screen, nothing - which reads as a broken button rather than
/// an unfinished one. There's no real subscription/IAP infrastructure wired
/// up yet, so rather than fake a purchase flow, this is an honest "here's
/// what's coming" screen instead of silence.
class WakleProScreen extends StatelessWidget {
  const WakleProScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return PlatformScaffold(
      appBar: AppBar(title: const Text('Wakle Pro')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const SizedBox(height: 24),
            const BreathingIcon(
              icon: Icons.workspace_premium,
              size: 120,
              iconSize: 60,
              color: AppTokens.signal,
              backgroundColor: Color(0x33FFB84D),
            ),
            const SizedBox(height: 32),
            Text(
              'Coming Soon',
              style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: colorScheme.onSurface),
            ),
            const SizedBox(height: 12),
            Text(
              "Wakle Pro isn't available yet - we're not going to charge you for something that doesn't exist. Here's what we're building:",
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 15, color: colorScheme.onSurfaceVariant, height: 1.5),
            ),
            const SizedBox(height: 32),
            FadeSlideIn(child: _buildFeatureRow(context, Icons.library_music, 'Premium sound pack', 'Extra alarm & ambient sounds')),
            const SizedBox(height: 16),
            FadeSlideIn(delay: const Duration(milliseconds: 60), child: _buildFeatureRow(context, Icons.insights, 'Deeper sleep insights', 'Longer history and trend analysis')),
            const SizedBox(height: 16),
            FadeSlideIn(delay: const Duration(milliseconds: 120), child: _buildFeatureRow(context, Icons.block, 'No ads, ever', 'The whole app stays ad-free either way')),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildFeatureRow(BuildContext context, IconData icon, String title, String subtitle) {
    final colorScheme = Theme.of(context).colorScheme;
    return PlatformCard(
      padding: const EdgeInsets.all(16.0),
      child: Row(
        children: [
          Icon(icon, color: AppTokens.signal, size: 24),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: TextStyle(fontWeight: FontWeight.w700, color: colorScheme.onSurface)),
                const SizedBox(height: 2),
                Text(subtitle, style: TextStyle(fontSize: 13, color: colorScheme.onSurfaceVariant)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
