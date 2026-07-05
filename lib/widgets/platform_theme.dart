import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';

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

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    
    if (Platform.isIOS) {
      return Scaffold(
        extendBodyBehindAppBar: true,
        appBar: appBar,
        floatingActionButton: floatingActionButton,
        floatingActionButtonLocation: floatingActionButtonLocation,
        body: Stack(
          children: [
            // Use a dark mesh gradient image or safe soft gradient instead of extreme BackdropFilter blur
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: isDark 
                    ? const [Color(0xFF1E1E2C), Color(0xFF121212), Color(0xFF2B1B40)]
                    : const [Color(0xFFE8EAF6), Color(0xFFFFFFFF), Color(0xFFD1C4E9)],
                ),
              ),
            ),
            // Actual Body
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
        backgroundColor: Theme.of(context).colorScheme.surface,
        body: SafeArea(child: body),
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
          borderRadius: BorderRadius.circular(20),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: Container(
              padding: padding,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.08),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: Colors.white.withOpacity(0.15),
                  width: 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 10,
                    spreadRadius: 1,
                  )
                ],
              ),
              child: child,
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
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: padding,
          child: child,
        ),
      );
      
      if (onTap != null) {
        return InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
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
          borderRadius: BorderRadius.circular(20),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
              decoration: BoxDecoration(
                color: backgroundColor != null 
                    ? backgroundColor!.withOpacity(0.4)
                    : (onPressed != null 
                        ? Colors.white.withOpacity(0.15) 
                        : Colors.white.withOpacity(0.05)),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.white.withOpacity(0.2)),
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
                    style: TextStyle(
                      color: onPressed != null ? Colors.white : Colors.white54,
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
        child: child,
        style: backgroundColor != null ? FilledButton.styleFrom(backgroundColor: backgroundColor) : null,
      );
    }
  }
}
