import 'package:share_plus/share_plus.dart';
import 'analytics_service.dart';

/// Opens the platform share sheet with a message inviting a friend to try
/// the app. There's no backend, so this can't track referrals or attribute
/// installs back to the inviter - it's a pure word-of-mouth growth lever.
class InviteService {
  // Placeholder - the app isn't published yet, so there's no real App Store
  // ID. Replace with the real listing URL once Wakle is live.
  static const String _appStoreUrl = 'https://apps.apple.com/app/id0000000000';

  static Future<void> shareInvite({int? currentStreak}) async {
    final streakLine = (currentStreak != null && currentStreak > 0)
        ? "I'm on a $currentStreak day streak actually waking up on time. "
        : '';

    final result = await SharePlus.instance.share(
      ShareParams(
        text: "${streakLine}Wakle forces you to solve a puzzle before your alarm "
            'will stop - no more sleeping through it. Try it: $_appStoreUrl',
        subject: 'Wake up on time with Wakle',
      ),
    );

    AnalyticsService.logEvent('invite_share_sheet_result', {
      'status': result.status.name,
    });
  }
}
