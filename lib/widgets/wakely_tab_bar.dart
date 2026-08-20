import 'package:flutter/material.dart';
import 'package:haptic_feedback/haptic_feedback.dart';
import '../theme/design_tokens.dart';

/// The app's shared bottom navigation, replacing the stock
/// NavigationBar (Android) / BottomNavigationBar (iOS) split that used
/// to give the two platforms visibly different, generic-looking tab
/// bars. A single on-brand design now: a sliding amber pill tracks the
/// selected tab, icons swap between outlined/filled variants with a
/// small bounce, and labels weight up — the same "alive" feel as the
/// rest of the app's press interactions.
class WakelyTabBar extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;

  const WakelyTabBar({super.key, required this.currentIndex, required this.onTap});

  /// The bar's own content height, not counting the bottom safe-area inset
  /// SafeArea adds beneath it. Screens whose body now extends behind this
  /// bar (MainScreen's Scaffold uses extendBody so the bar's blur has real
  /// content to show through) need this to keep floating buttons/content
  /// clear of it — see home_screen.dart's FAB.
  static const double height = 62;

  static const List<_TabItem> _items = [
    _TabItem(Icons.alarm_outlined, Icons.alarm_rounded, 'Alarm'),
    _TabItem(Icons.nights_stay_outlined, Icons.nights_stay_rounded, 'Sleep'),
    _TabItem(Icons.wb_sunny_outlined, Icons.wb_sunny_rounded, 'Morning'),
    _TabItem(Icons.receipt_long_outlined, Icons.receipt_long_rounded, 'Report'),
    _TabItem(Icons.settings_outlined, Icons.settings_rounded, 'Setting'),
  ];

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = scheme.brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: scheme.onSurface.withValues(alpha: 0.08), width: 1)),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: height,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final itemWidth = constraints.maxWidth / _items.length;
              return Stack(
                children: [
                  AnimatedPositioned(
                    duration: const Duration(milliseconds: 380),
                    curve: Curves.easeOutCubic,
                    left: itemWidth * currentIndex,
                    top: 6,
                    bottom: 6,
                    width: itemWidth,
                    child: Center(
                      child: Container(
                        width: itemWidth - 20,
                        height: 46,
                        decoration: BoxDecoration(
                          color: AppTokens.signal.withValues(alpha: isDark ? 0.22 : 0.16),
                          borderRadius: BorderRadius.circular(18),
                        ),
                      ),
                    ),
                  ),
                  Row(
                    children: List.generate(_items.length, (i) {
                      final selected = i == currentIndex;
                      final item = _items[i];
                      return SizedBox(
                        width: itemWidth,
                        height: height,
                        child: Semantics(
                          button: true,
                          selected: selected,
                          label: '${item.label} Tab ${i + 1} of ${_items.length}',
                          child: Material(
                          type: MaterialType.transparency,
                          child: InkWell(
                            onTap: () {
                              if (!selected) {
                                Haptics.vibrate(HapticsType.selection);
                                onTap(i);
                              }
                            },
                            customBorder: const StadiumBorder(),
                            child: ExcludeSemantics(
                              child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                TweenAnimationBuilder<double>(
                                  tween: Tween(begin: 0.9, end: selected ? 1.08 : 0.92),
                                  duration: const Duration(milliseconds: 320),
                                  curve: Curves.easeOutBack,
                                  builder: (context, scale, child) => Transform.scale(scale: scale, child: child),
                                  child: AnimatedSwitcher(
                                    duration: const Duration(milliseconds: 180),
                                    transitionBuilder: (child, anim) => ScaleTransition(scale: anim, child: FadeTransition(opacity: anim, child: child)),
                                    child: Icon(
                                      selected ? item.filled : item.outline,
                                      key: ValueKey(selected),
                                      color: selected ? AppTokens.signal : scheme.onSurfaceVariant,
                                      size: 24,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 3),
                                AnimatedDefaultTextStyle(
                                  duration: const Duration(milliseconds: 220),
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                                    color: selected ? AppTokens.signal : scheme.onSurfaceVariant,
                                  ),
                                  child: Text(item.label),
                                ),
                              ],
                              ),
                            ),
                          ),
                        ),
                        ),
                      );
                    }),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _TabItem {
  final IconData outline;
  final IconData filled;
  final String label;
  const _TabItem(this.outline, this.filled, this.label);
}
