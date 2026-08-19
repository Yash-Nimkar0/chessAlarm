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

  const PlatformScaffold({
    Key? key,
    required this.body,
    this.floatingActionButton,
    this.appBar,
    this.floatingActionButtonLocation,
    this.bottomNavigationBar,
  }) : super(key: key);

  /// Renders the user's chosen background photo full-bleed behind
  /// everything, dimmed by their chosen amount so text and cards (already
  /// semi-transparent/frosted) stay legible over any photo. A single
  /// shared implementation here means every screen gets this for free
  /// through PlatformScaffold rather than needing its own wiring.
  Widget _backgroundLayer() {
    return ListenableBuilder(
      listenable: WallpaperService(),
      builder: (context, _) {
        final path = WallpaperService().wallpaperPath;
        if (path == null) return const SizedBox.shrink();
        return Positioned.fill(
          child: Stack(
            fit: StackFit.expand,
            children: [
              Image.file(File(path), fit: BoxFit.cover),
              Container(color: Colors.black.withValues(alpha: WallpaperService().dimAmount)),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (Platform.isIOS) {
      return Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        extendBodyBehindAppBar: true,
        appBar: appBar,
        floatingActionButton: floatingActionButton,
        floatingActionButtonLocation: floatingActionButtonLocation,
        body: Stack(
          children: [
            _backgroundLayer(),
            SafeArea(child: body),
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
        bottomNavigationBar: bottomNavigationBar,
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        body: Stack(
          children: [
            _backgroundLayer(),
            SafeArea(child: body),
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
