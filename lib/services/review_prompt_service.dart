import 'package:in_app_review/in_app_review.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Prompts the user for an App Store review at a positive moment (a streak
/// milestone) instead of on first launch or randomly, since a rating asked
/// right after a good outcome is far more likely to be a good rating.
///
/// iOS itself caps [InAppReview.requestReview] to at most 3 prompts per
/// 365 days regardless of how often this is called, but we still track our
/// own state so we don't even attempt it more than once per milestone.
class ReviewPromptService {
  static const String _lastPromptedStreakKey = 'review_prompt_last_streak';
  static const List<int> _milestones = [3, 7, 14, 30, 60, 100];

  static Future<void> maybeRequestReview(int currentStreak) async {
    if (!_milestones.contains(currentStreak)) return;

    final prefs = await SharedPreferences.getInstance();
    final lastPromptedStreak = prefs.getInt(_lastPromptedStreakKey) ?? 0;
    if (currentStreak <= lastPromptedStreak) return;

    final inAppReview = InAppReview.instance;
    if (!await inAppReview.isAvailable()) return;

    await prefs.setInt(_lastPromptedStreakKey, currentStreak);
    await inAppReview.requestReview();
  }
}
