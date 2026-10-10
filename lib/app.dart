import 'package:flutter/material.dart';

import 'core/routing/app_router.dart';
import 'core/services/notifications/notification_scheduler.dart';
import 'core/theme/app_theme.dart';

class FrigoApp extends StatelessWidget {
  const FrigoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Frigo',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      scrollBehavior: const _SmoothScroll(),
      routerConfig: appRouter,
      builder: (context, child) =>
          NotificationSync(child: child ?? const SizedBox.shrink()),
    );
  }
}

/// Gentle overscroll on every platform + no stretch/glow, for a quieter feel.
class _SmoothScroll extends MaterialScrollBehavior {
  const _SmoothScroll();

  @override
  Widget buildOverscrollIndicator(
          BuildContext context, Widget child, ScrollableDetails details) =>
      child;

  @override
  ScrollPhysics getScrollPhysics(BuildContext context) =>
      const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics());
}
