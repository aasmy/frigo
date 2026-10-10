import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:pantry_ai/core/config/app_config.dart';
import 'package:pantry_ai/core/services/ads/ads_config.dart';
import 'package:pantry_ai/core/providers/service_providers.dart';
import 'package:pantry_ai/core/services/ai/ai_service.dart';
import 'package:pantry_ai/core/services/ai/mock_ai_service.dart';
import 'package:pantry_ai/core/services/local_store.dart';
import 'package:pantry_ai/core/theme/app_theme.dart';
import 'package:pantry_ai/features/inventory/kitchen_screen.dart';
import 'package:pantry_ai/features/home/home_screen.dart';

Future<Widget> _host(Widget child) async {
  AppConfig.networkImagesEnabled = false;
  AppConfig.notificationsEnabled = false;
  AdsConfig.enabled = false;
  AppConfig.aiEnabled = false;
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  return ProviderScope(
    overrides: [
      localStoreProvider.overrideWithValue(LocalStore(prefs)),
      aiServiceProvider.overrideWithValue(
        MockAiService(latency: Duration.zero) as AiService,
      ),
    ],
    child: MaterialApp(theme: AppTheme.light(), home: child),
  );
}

void main() {
  testWidgets('Home screen renders with demo data', (tester) async {
    await tester.pumpWidget(await _host(const HomeScreen()));
    await tester.pumpAndSettle();
    expect(find.textContaining('Use soon'), findsWidgets);
    expect(find.textContaining('What to cook tonight?'), findsOneWidget);
  });

  testWidgets('Kitchen screen lists seeded items', (tester) async {
    await tester.pumpWidget(await _host(const KitchenScreen()));
    await tester.pumpAndSettle();
    expect(find.text('My Kitchen'), findsOneWidget);
    expect(find.text('Chicken Breast'), findsWidgets);
  });
}
