import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// Thin typed wrapper over [SharedPreferences] used as the offline cache.
///
/// Everything the app shows is readable from here without a network call;
/// a real build would additionally sync these collections to Supabase.
class LocalStore {
  LocalStore(this._prefs);

  final SharedPreferences _prefs;

  static const kInventory = 'inventory_items';
  static const kReceipts = 'receipts';
  static const kShopping = 'shopping_list_items';
  static const kPreferences = 'user_preferences';
  static const kRecipeHistory = 'recipes_history';
  static const kSeeded = 'demo_data_seeded';
  static const kImageCache = 'image_url_cache';
  static const kEntitlements = 'entitlements';

  bool get isSeeded => _prefs.getBool(kSeeded) ?? false;
  Future<void> markSeeded() => _prefs.setBool(kSeeded, true);

  List<Map<String, dynamic>> readList(String key) {
    final raw = _prefs.getString(key);
    if (raw == null || raw.isEmpty) return [];
    final decoded = jsonDecode(raw);
    if (decoded is! List) return [];
    return decoded.cast<Map<String, dynamic>>();
  }

  Future<void> writeList(String key, List<Map<String, dynamic>> value) =>
      _prefs.setString(key, jsonEncode(value));

  Map<String, dynamic>? readMap(String key) {
    final raw = _prefs.getString(key);
    if (raw == null || raw.isEmpty) return null;
    final decoded = jsonDecode(raw);
    return decoded is Map<String, dynamic> ? decoded : null;
  }

  Future<void> writeMap(String key, Map<String, dynamic> value) =>
      _prefs.setString(key, jsonEncode(value));

  Future<void> clearAll() async {
    await _prefs.remove(kInventory);
    await _prefs.remove(kReceipts);
    await _prefs.remove(kShopping);
    await _prefs.remove(kRecipeHistory);
  }
}
