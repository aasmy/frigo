import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app.dart';
import 'core/providers/service_providers.dart';
import 'core/services/images/image_resolver.dart';
import 'core/services/images/ingredient_catalog.dart';
import 'core/services/ads/ads_service.dart';
import 'core/services/billing/billing_service.dart';
import 'core/services/local_store.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);

  final prefs = await SharedPreferences.getInstance();
  final store = LocalStore(prefs);

  // Deterministic images: load the bundled ingredient catalog and re-attach the
  // saved name -> URL map so an item never changes picture between launches.
  await IngredientCatalog.instance.load();
  ImageResolver.instance.attachStore(store);

  // Ads start up in the background: the consent form and SDK handshake must
  // never hold the first frame.
  unawaited(AdsService.instance.init());
  unawaited(BillingService.instance.init());

  runApp(
    ProviderScope(
      overrides: [
        localStoreProvider.overrideWithValue(store),
      ],
      child: const FrigoApp(),
    ),
  );
}
