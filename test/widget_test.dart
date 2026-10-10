import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:pantry_ai/core/providers/service_providers.dart';
import 'package:pantry_ai/core/repositories/inventory_repository.dart';
import 'package:pantry_ai/core/services/local_store.dart';

void main() {
  test('demo inventory seeds on first run', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final container = ProviderContainer(
      overrides: [
        localStoreProvider.overrideWithValue(LocalStore(prefs)),
      ],
    );
    addTearDown(container.dispose);

    final items = container.read(inventoryProvider);
    expect(items, isNotEmpty);
    expect(items.any((i) => i.displayName == 'Chicken Breast'), isTrue);
  });

  testWidgets('MaterialApp builds', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [localStoreProvider.overrideWithValue(LocalStore(prefs))],
        child: const MaterialApp(home: Scaffold(body: Text('ok'))),
      ),
    );
    expect(find.text('ok'), findsOneWidget);
  });
}
