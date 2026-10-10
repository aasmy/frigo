import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;

/// A verified vocabulary of 892 ingredient names, every one of which is known
/// to have a real photo on TheMealDB's CDN.
///
/// Matching is deliberately conservative and **deterministic**: a catalog entry
/// only wins when every one of its words also appears in the query, so we can
/// never swap in a concept the user didn't mention ("Salmon Fillet" will never
/// match "Anchovy Fillet"). The same name always yields the same image.
class IngredientCatalog {
  IngredientCatalog._();
  static final IngredientCatalog instance = IngredientCatalog._();

  static const _imageBase = 'https://www.themealdb.com/images/ingredients/';

  List<_Entry> _entries = const [];
  bool _loaded = false;

  /// Descriptors that never change *what* a food is.
  static const _stop = {
    'organic', 'fresh', 'large', 'small', 'mini', 'baby', 'boneless',
    'skinless', 'sliced', 'shredded', 'whole', 'half', 'family', 'value',
    'pack', 'raw', 'free', 'range', 'extra', 'lean', 'light', 'low',
    'reduced', 'unsalted', 'salted', 'premium', 'natural', 'classic',
    'original', 'brand', 'style', 'of', 'the', 'and', 'with', 'a', 'bicolor',
    'bicolour', 'heirloom', 'hass', 'roma', 'gala', 'fuji', 'russet', 'yukon',
    'beefsteak', 'jumbo', 'seedless', 'english', 'sweet', 'dark', 'hot',
    'mild', 'plain', 'pure', 'real', 'best', 'fine', 'thick', 'thin', 'bag',
    'box', 'jar', 'can', 'bottle', 'carton', 'tub', 'piece', 'pieces',
  };

  /// Regional / naming differences — both sides are normalised through this.
  static const _alias = {
    'aubergine': 'eggplant',
    'courgette': 'zucchini',
    'coriander': 'cilantro',
    'rocket': 'arugula',
    'yoghurt': 'yogurt',
    'maize': 'corn',
    'capsicum': 'pepper',
    'mince': 'ground',
    'prawn': 'shrimp',
    'garbanzo': 'chickpea',
  };

  /// Query-side widening: the catalog's word for a food the user says
  /// differently.
  static const _queryAlias = {
    'corn': 'sweetcorn',
    'shrimp': 'prawns',
    'eggplant': 'aubergine',
    'zucchini': 'courgette',
    'cilantro': 'coriander',
    'arugula': 'rocket',
  };

  Future<void> load() async {
    if (_loaded) return;
    try {
      final raw = await rootBundle.loadString('assets/data/ingredients.json');
      final names = (jsonDecode(raw) as List).cast<String>();
      _entries = [
        for (final n in names)
          if (_tokens(n).isNotEmpty) _Entry(n, _tokens(n).toSet()),
      ];
    } catch (_) {
      _entries = const [];
    }
    _loaded = true;
  }

  bool get isLoaded => _loaded;

  /// The catalog name that best (and safely) describes [query], or null.
  String? match(String query) {
    if (!_loaded || _entries.isEmpty) return null;
    final qt = _tokens(query);
    if (qt.isEmpty) return null;
    final qs = <String>{
      ...qt,
      for (final w in qt)
        if (_queryAlias.containsKey(w)) _queryAlias[w]!,
    };

    _Entry? best;
    for (final e in _entries) {
      if (!e.tokens.every(qs.contains)) continue; // catalog ⊆ query
      if (best == null ||
          e.tokens.length > best.tokens.length ||
          (e.tokens.length == best.tokens.length &&
              e.name.length < best.name.length)) {
        best = e;
      }
    }
    return best?.name;
  }

  /// A guaranteed-to-render image URL for [query], or null when unknown.
  String? imageUrl(String query) {
    final name = match(query);
    if (name == null) return null;
    return '$_imageBase${Uri.encodeComponent(name)}-Medium.png';
  }

  static String imageUrlForCatalogName(String name) =>
      '$_imageBase${Uri.encodeComponent(name)}-Medium.png';

  // --- normalisation --------------------------------------------------------
  static List<String> _tokens(String s) {
    final cleaned =
        s.toLowerCase().replaceAll('&', ' ').replaceAll(RegExp(r'[^a-z0-9%\s]'), ' ');
    final out = <String>[];
    for (final raw in cleaned.split(RegExp(r'\s+'))) {
      if (raw.isEmpty) continue;
      if (int.tryParse(raw) != null) continue;
      if (_stop.contains(raw)) continue;
      var w = _singular(raw);
      w = _alias[w] ?? w;
      if (_stop.contains(w) || w.length < 2) continue;
      out.add(w);
    }
    return out;
  }

  static String _singular(String w) {
    if (w.length > 3 && w.endsWith('ies')) return '${w.substring(0, w.length - 3)}y';
    if (w.length > 3 && w.endsWith('oes')) return w.substring(0, w.length - 2);
    if (w.length > 3 && w.endsWith('ses')) return w.substring(0, w.length - 2);
    if (w.length > 3 && w.endsWith('s') && !w.endsWith('ss')) {
      return w.substring(0, w.length - 1);
    }
    return w;
  }
}

class _Entry {
  const _Entry(this.name, this.tokens);
  final String name;
  final Set<String> tokens;
}
