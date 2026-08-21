import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import '../theme/design_tokens.dart';
import '../services/wallpaper_service.dart';

class PlatformScaffold extends StatelessWidget {
  final Widget body;
  final Widget? floatingActionButton;
  final PreferredSizeWidget? appBar;
  final FloatingActionButtonLocation? floatingActionButtonLocation;
  final Widget? bottomNavigationBar;

  /// Wake-context screens (ringing, slide-to-stop) always use light text
  /// on a deliberately dark/night aesthetic regardless of the app's own
  /// light/dark theme choice — a "time to wake up" screen stays dark for
  /// eye comfort at typical wake hours even if you run the rest of the
  /// app in Light mode. The wallpaper scrim needs to match that same
  /// choice, not the app theme, or light-on-dark text would turn
  /// illegible the moment Light mode picks a light scrim.
  final bool forceDarkWallpaperScrim;

  /// Every existing screen that passes a `body` here relies on
  /// PlatformScaffold to inset it from the status bar/notch itself, so this
  /// defaults to true to keep them all unchanged. MainScreen is the one
  /// exception: it passes each tab's already-self-contained screen (each of
  /// which already wraps its own SafeArea internally) as `body`, so an
  /// extra SafeArea here just shrinks the box that screen has to work with
  /// — for a screen with a plain background that's invisible, but for one
  /// that wants a full-bleed background reaching the true top of the
  /// screen (the Morning tab), it left a gap of the app's flat background
  /// showing above it that no descendant could reclaim, since by the time
  /// it mounts the extra Padding has already shrunk its layout box.
  final bool applySafeArea;

  const PlatformScaffold({
    Key? key,
    required this.body,
    this.floatingActionButton,
    this.appBar,
    this.floatingActionButtonLocation,
    this.bottomNavigationBar,
    this.forceDarkWallpaperScrim = false,
    this.applySafeArea = true,
  }) : super(key: key);

  /// Renders the user's chosen background photo full-bleed behind
  /// everything, blurred and dimmed so text and cards stay legible over
  /// any photo. A single shared implementation here means every screen
  /// gets this for free through PlatformScaffold rather than needing its
  /// own wiring.
  ///
  /// The scrim color used to always be black regardless of theme — wrong
  /// for Light mode specifically, where the app's own text is dark: a
  /// black scrim darkens the photo but does nothing to guarantee contrast
  /// against dark text, and can make some regions worse. The scrim now
  /// matches the theme's own background tone (dark in dark mode, light in
  /// light mode) so the photo gets pushed toward the same luminance the
  /// theme's own text was designed to sit on, and a blur removes the
  /// high-frequency detail (edges, bright spots) that hurts legibility
  /// even under a flat color scrim — the same combination iOS itself uses
  /// for a custom photo wallpaper with text over it.
  Widget _backgroundLayer(BuildContext context) {
    return ListenableBuilder(
      listenable: WallpaperService(),
      builder: (context, _) {
        final path = WallpaperService().wallpaperPath;
        if (path == null) return const SizedBox.shrink();
        final isDark = forceDarkWallpaperScrim || Theme.of(context).brightness == Brightness.dark;
        final scrimColor = isDark ? AppTokens.nightBg : AppTokens.daylightBg;
        // Text legibility mostly comes from PlatformCard's own tinted blur
        // (and, on wake screens, an extra local gradient) — this scrim only
        // needs a light floor so the photo stays clearly visible at the
        // slider's minimum instead of looking barely-there.
        final effectiveDim = 0.12 + (WallpaperService().dimAmount * 0.7);
        return Positioned.fill(
          child: Stack(
            fit: StackFit.expand,
            children: [
              ImageFiltered(
                imageFilter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                child: Image.file(File(path), fit: BoxFit.cover),
              ),
              Container(color: scrimColor.withValues(alpha: effectiveDim)),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final insetBody = applySafeArea ? SafeArea(child: body) : body;
    if (Platform.isIOS) {
      return Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        extendBodyBehindAppBar: true,
        // Without this, `body` was sized to stop exactly where
        // `bottomNavigationBar` begins — so the tab bar's own frosted blur
        // had nothing real behind it to blur, just the plain scaffold
        // background, regardless of which tab's own colorful/dark content
        // was showing above it. That's why it always looked like a flat,
        // disconnected strip instead of a glass bar over the actual page.
        extendBody: bottomNavigationBar != null,
        appBar: appBar,
        floatingActionButton: floatingActionButton,
        floatingActionButtonLocation: floatingActionButtonLocation,
        // Scaffold gives `body` LOOSE constraints (minHeight: 0), not tight
        // ones — so a plain Stack (StackFit.loose, the default) sizes
        // itself to its biggest non-positioned child's own natural height,
        // not to the full available space. That child is `insetBody`,
        // which has no natural height opinion of its own to report back up
        // - the actual value that surfaced depended on incidental content
        // sizing several widgets down the tree. Confirmed live on Android:
        // this Stack measured ~30% shorter than the true screen height,
        // exposing the plain scaffold background below the Morning tab's
        // full-bleed sky background. `StackFit.expand` makes this Stack
        // simply fill whatever constraints Scaffold actually gave it.
        body: Stack(
          fit: StackFit.expand,
          children: [
            _backgroundLayer(context),
            insetBody,
          ],
        ),
        bottomNavigationBar: bottomNavigationBar,
      );
    } else {
      // Android / Default (Material)
      return Scaffold(
        appBar: appBar,
        floatingActionButton: floatingActionButton,
        floatingActionButtonLocation: floatingActionButtonLocation,
        extendBody: bottomNavigationBar != null,
        bottomNavigationBar: bottomNavigationBar,
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        // Scaffold gives `body` LOOSE constraints (minHeight: 0), not tight
        // ones — so a plain Stack (StackFit.loose, the default) sizes
        // itself to its biggest non-positioned child's own natural height,
        // not to the full available space. That child is `insetBody`,
        // which has no natural height opinion of its own to report back up
        // - the actual value that surfaced depended on incidental content
        // sizing several widgets down the tree. Confirmed live on Android:
        // this Stack measured ~30% shorter than the true screen height,
        // exposing the plain scaffold background below the Morning tab's
        // full-bleed sky background. `StackFit.expand` makes this Stack
        // simply fill whatever constraints Scaffold actually gave it.
        body: Stack(
          fit: StackFit.expand,
          children: [
            _backgroundLayer(context),
            insetBody,
          ],
        ),
      );
    }
  }
}

class PlatformCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry margin;
  final VoidCallback? onTap;

  const PlatformCard({
    Key? key,
    required this.child,
    this.padding = EdgeInsets.zero,
    this.margin = const EdgeInsets.all(4.0),
    this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (Platform.isIOS) {
      Widget cardContent = Container(
        margin: margin,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(AppTokens.radiusLg),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: Container(
              padding: padding,
              decoration: BoxDecoration(
                color: Theme.of(context).cardTheme.color ?? Colors.white.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(AppTokens.radiusLg),
                border: Border.all(
                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.1),
                  width: 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 10,
                    spreadRadius: 1,
                  )
                ],
              ),
              child: Material(
                type: MaterialType.transparency,
                child: child,
              ),
            ),
          ),
        ),
      );
      
      if (onTap != null) {
        return GestureDetector(
          onTap: onTap,
          behavior: HitTestBehavior.opaque,
          child: cardContent,
        );
      }
      return cardContent;
    } else {
      // Android / Default
      Widget cardContent = Card(
        margin: margin,
        color: Theme.of(context).cardTheme.color ?? Colors.white.withValues(alpha: 0.05),
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTokens.radiusLg),
          side: BorderSide(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.1), width: 1),
        ),
        child: Padding(
          padding: padding,
          child: child,
        ),
      );
      
      if (onTap != null) {
        return InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppTokens.radiusLg),
          child: cardContent,
        );
      }
      return cardContent;
    }
  }
}

class PlatformButton extends StatelessWidget {
  final Widget child;
  final VoidCallback? onPressed;
  final bool isIcon;
  final Widget? icon;
  final Color? backgroundColor;

  const PlatformButton({
    Key? key,
    required this.child,
    this.onPressed,
    this.isIcon = false,
    this.icon,
    this.backgroundColor,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (Platform.isIOS) {
      return GestureDetector(
        onTap: onPressed,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(AppTokens.radiusLg),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
              decoration: BoxDecoration(
                color: backgroundColor != null 
                    ? backgroundColor!.withValues(alpha: 0.4)
                    : (onPressed != null 
                        ? AppTokens.signal.withValues(alpha: 0.15) 
                        : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.05)),
                borderRadius: BorderRadius.circular(AppTokens.radiusLg),
                border: Border.all(color: backgroundColor ?? AppTokens.signal.withValues(alpha: 0.2)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (isIcon && icon != null) ...[
                    icon!,
                    const SizedBox(width: 8),
                  ],
                  DefaultTextStyle(
                    style: AppTokens.body.copyWith(
                      color: onPressed != null ? Theme.of(context).colorScheme.onSurface : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                    ),
                    child: child,
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    } else {
      // Android / Default
      if (isIcon && icon != null) {
        return FilledButton.icon(
          onPressed: onPressed,
          icon: icon!,
          label: child,
          style: backgroundColor != null ? FilledButton.styleFrom(backgroundColor: backgroundColor) : null,
        );
      }
      return FilledButton(
        onPressed: onPressed,
        style: FilledButton.styleFrom(
          backgroundColor: backgroundColor ?? AppTokens.signal.withValues(alpha: 0.2),
          foregroundColor: Theme.of(context).colorScheme.onSurface,
        ),
        child: DefaultTextStyle(
          style: AppTokens.body.copyWith(fontWeight: FontWeight.w600, fontSize: 16),
          child: child,
        ),
      );
    }
  }
}
