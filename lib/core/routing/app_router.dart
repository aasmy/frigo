import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../features/app/scaffold_with_nav.dart';
import '../../features/app/splash_screen.dart';
import '../../features/home/home_screen.dart';
import '../../features/inventory/inventory_item_details_screen.dart';
import '../../features/inventory/kitchen_screen.dart';
import '../../features/inventory/manual_add_item_screen.dart';
import '../../features/onboarding/onboarding_screen.dart';
import '../../features/recipes/cook_update_screen.dart';
import '../../features/recipes/recipe_details_screen.dart';
import '../../features/recipes/recipes_screen.dart';
import '../../features/recipes/rescue_screen.dart';
import '../../features/receipts/receipt_details_screen.dart';
import '../../features/receipts/receipt_history_screen.dart';
import '../../features/scan/scan_screen.dart';
import '../../features/settings/preferences_screen.dart';
import '../../features/assistant/assistant_screen.dart';
import '../../features/settings/settings_screen.dart';
import '../../features/shopping/shopping_list_screen.dart';
import '../models/recipe.dart';
import 'route_names.dart';

final _rootKey = GlobalKey<NavigatorState>();
final _shellKey = GlobalKey<NavigatorState>();

/// Fade transition used for full-screen pushes so the app feels calm.
CustomTransitionPage<void> _fade(Widget child, GoRouterState state) {
  return CustomTransitionPage(
    key: state.pageKey,
    child: child,
    transitionsBuilder: (context, animation, _, child) =>
        FadeTransition(opacity: animation, child: child),
  );
}

final appRouter = GoRouter(
  navigatorKey: _rootKey,
  initialLocation: Routes.splash,
  routes: [
    GoRoute(path: Routes.splash, builder: (_, __) => const SplashScreen()),
    GoRoute(
        path: Routes.onboarding, builder: (_, __) => const OnboardingScreen()),

    // Full-screen flows above the shell.
    GoRoute(
      path: Routes.scan,
      parentNavigatorKey: _rootKey,
      pageBuilder: (context, state) => _fade(const ScanScreen(), state),
    ),
    GoRoute(
      path: Routes.manualAdd,
      parentNavigatorKey: _rootKey,
      builder: (_, __) => const ManualAddItemScreen(),
    ),
    GoRoute(
      path: Routes.itemDetailsPattern,
      parentNavigatorKey: _rootKey,
      builder: (_, state) =>
          InventoryItemDetailsScreen(itemId: state.pathParameters['id']!),
    ),
    GoRoute(
      path: Routes.recipeDetailsPattern,
      parentNavigatorKey: _rootKey,
      builder: (_, state) =>
          RecipeDetailsScreen(recipe: state.extra as Recipe?),
    ),
    GoRoute(
      path: Routes.cookUpdate,
      parentNavigatorKey: _rootKey,
      builder: (_, state) => CookUpdateScreen(recipe: state.extra as Recipe?),
    ),
    GoRoute(
      path: Routes.rescue,
      parentNavigatorKey: _rootKey,
      builder: (_, __) => const RescueScreen(),
    ),
    GoRoute(
      path: Routes.shoppingList,
      parentNavigatorKey: _rootKey,
      builder: (_, __) => const ShoppingListScreen(),
    ),
    GoRoute(
      path: Routes.assistant,
      parentNavigatorKey: _rootKey,
      builder: (_, __) => const AssistantScreen(),
    ),
    GoRoute(
      path: Routes.receiptHistory,
      parentNavigatorKey: _rootKey,
      builder: (_, __) => const ReceiptHistoryScreen(),
    ),
    GoRoute(
      path: Routes.receiptDetailsPattern,
      parentNavigatorKey: _rootKey,
      builder: (_, state) =>
          ReceiptDetailsScreen(receiptId: state.pathParameters['id']!),
    ),
    GoRoute(
      path: Routes.preferences,
      parentNavigatorKey: _rootKey,
      builder: (_, __) => const PreferencesScreen(),
    ),

    // Bottom-nav shell: Home / Kitchen / Recipes / Profile.
    StatefulShellRoute.indexedStack(
      builder: (context, state, navigationShell) =>
          ScaffoldWithNav(navigationShell: navigationShell),
      branches: [
        StatefulShellBranch(
          navigatorKey: _shellKey,
          routes: [
            GoRoute(path: Routes.home, builder: (_, __) => const HomeScreen()),
          ],
        ),
        StatefulShellBranch(routes: [
          GoRoute(path: Routes.kitchen, builder: (_, __) => const KitchenScreen()),
        ]),
        StatefulShellBranch(routes: [
          GoRoute(path: Routes.recipes, builder: (_, __) => const RecipesScreen()),
        ]),
        StatefulShellBranch(routes: [
          GoRoute(path: Routes.settings, builder: (_, __) => const SettingsScreen()),
        ]),
      ],
    ),
  ],
);
