import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../../config/app_config.dart';
import '../local_store.dart';
import 'ingredient_catalog.dart';

/// Resolves a *correct* photo URL for a food name — or nothing at all.
///
/// Three properties matter here, in order:
///  1. **Right** — a source only wins if it demonstrably names the same food.
///  2. **Stable** — the same name always resolves to the same URL, and results
///     are persisted, so an item never changes picture between launches.
///  3. **Consistent** — the primary source is one curated ingredient catalog,
///     so the app doesn't mix photographic styles at random.
///
/// When nothing qualifies we return `null` and the UI shows a category icon.
class ImageResolver {
  ImageResolver._();
  static final ImageResolver instance = ImageResolver._();

  final Map<String, String?> _memory = {};
  final Map<String, Future<String?>> _inFlight = {};
  final _http = http.Client();
  LocalStore? _store;
  bool _diskLoaded = false;

  /// Called once from `main()` so resolutions survive restarts.
  void attachStore(LocalStore store) {
    _store = store;
    if (_diskLoaded) return;
    _diskLoaded = true;
    final saved = store.readMap(LocalStore.kImageCache);
    if (saved != null) {
      saved.forEach((k, v) => _memory[k] = v is String ? v : null);
    }
  }

  static const _ua = 'Frigo/1.0 (kitchen inventory app)';
  static const _wikiHeaders = {'User-Agent': _ua, 'Accept': 'application/json'};

  /// Instant, offline answer from the bundled catalog — used for first paint.
  String? quick(String rawName) {
    if (!AppConfig.networkImagesEnabled) return null;
    final key = _key(rawName);
    if (_memory.containsKey(key)) return _memory[key];
    return IngredientCatalog.instance.imageUrl(rawName);
  }

  Future<String?> resolve(String rawName) {
    if (!AppConfig.networkImagesEnabled) return Future.value(null);
    final key = _key(rawName);
    if (key.isEmpty) return Future.value(null);
    if (_memory.containsKey(key)) return Future.value(_memory[key]);
    // Collapse concurrent look-ups of the same name into one request.
    return _inFlight.putIfAbsent(key, () async {
      try {
        final url = await _resolveUncached(rawName);
        _remember(key, url);
        return url;
      } finally {
        _inFlight.remove(key);
      }
    });
  }

  Future<String?> _resolveUncached(String rawName) async {
    // 1. Curated catalog — deterministic, consistent style, always renders.
    await IngredientCatalog.instance.load();
    final catalog = IngredientCatalog.instance.imageUrl(rawName);
    if (catalog != null) return catalog;

    // 2. Wikipedia's own page for this exact food (never a search guess).
    final words = _significantWords(rawName);
    if (words.isEmpty) return null;
    final hit = await _wikipediaSummary(words.join(' '));
    if (hit != null && hit.image != null && _namesTheFood(hit, words)) {
      return hit.image;
    }
    return null;
  }

  void _remember(String key, String? url) {
    _memory[key] = url;
    final store = _store;
    if (store == null) return;
    // Only persist positives — a miss may resolve later as the catalog grows.
    if (url == null) return;
    store.writeMap(
      LocalStore.kImageCache,
      {for (final e in _memory.entries) if (e.value != null) e.key: e.value!},
    );
  }

  /// Best-effort prefetch, used by the inventory image backfill.
  Future<void> warm(Iterable<String> names) async {
    for (final n in names) {
      try {
        await resolve(n);
      } catch (e) {
        debugPrint('image warm failed for $n: $e');
      }
    }
  }

  // --- helpers ---------------------------------------------------------------
  String _key(String s) => s.trim().toLowerCase();

  static const _descriptors = {
    'organic', 'fresh', 'large', 'small', 'mini', 'baby', 'boneless',
    'skinless', 'sliced', 'shredded', 'whole', 'half', 'family', 'value',
    'pack', 'raw', 'free', 'range', 'extra', 'lean', 'light', 'low',
    'reduced', 'unsalted', 'salted', 'premium', 'natural', 'classic',
    'original', 'brand', 'style', 'bicolor', 'bicolour', 'heirloom', 'hass',
    'roma', 'gala', 'fuji', 'russet', 'yukon', 'beefsteak', 'jumbo',
    'seedless', 'english', 'sweet', 'red', 'green', 'yellow', 'white',
    'purple', 'golden', 'dark', 'hot', 'mild', 'the', 'and', 'with', 'of',
  };

  List<String> _significantWords(String name) => name
      .toLowerCase()
      .replaceAll(RegExp(r'^\d+%\s*'), '')
      .replaceAll(RegExp(r"[^a-z'\s]"), ' ')
      .split(RegExp(r'\s+'))
      .where((w) => w.length >= 3 && !_descriptors.contains(w))
      .toList();

  /// The article must actually be about this food: its title or summary has to
  /// contain the query's head noun.
  bool _namesTheFood(_Hit hit, List<String> words) {
    final hay = '${hit.title} ${hit.extract}'.toLowerCase();
    return hay.contains(words.last) || words.any(hit.title.toLowerCase().contains);
  }

  Future<_Hit?> _wikipediaSummary(String name) async {
    final title = Uri.encodeComponent(name.replaceAll(' ', '_'));
    try {
      final res = await _http
          .get(
            Uri.parse('https://en.wikipedia.org/api/rest_v1/page/summary/$title'),
            headers: _wikiHeaders,
          )
          .timeout(const Duration(seconds: 5));
      if (res.statusCode != 200) return null;
      final b = jsonDecode(res.body) as Map<String, dynamic>;
      if ((b['type'] as String?) == 'disambiguation') return null;
      final src = (b['thumbnail'] as Map?)?['source'] as String?;
      return _Hit(
        title: b['title'] as String? ?? '',
        extract: b['extract'] as String? ?? '',
        image: (src == null || src.isEmpty) ? null : src.split('?').first,
      );
    } catch (_) {
      return null;
    }
  }
}

class _Hit {
  const _Hit({required this.title, required this.extract, required this.image});
  final String title;
  final String extract;
  final String? image;
}
