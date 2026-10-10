import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/user_preferences.dart';
import '../providers/service_providers.dart';
import '../services/local_store.dart';

class PreferencesNotifier extends Notifier<UserPreferences> {
  late final LocalStore _store;

  @override
  UserPreferences build() {
    _store = ref.watch(localStoreProvider);
    final json = _store.readMap(LocalStore.kPreferences);
    return json == null ? const UserPreferences() : UserPreferences.fromJson(json);
  }

  void _persist(UserPreferences next) {
    state = next;
    _store.writeMap(LocalStore.kPreferences, next.toJson());
  }

  void update(UserPreferences Function(UserPreferences) mutate) =>
      _persist(mutate(state));

  void completeOnboarding() => _persist(state.copyWith(onboardingComplete: true));

  void setDisplayName(String? name) => _persist(state.copyWith(displayName: name));

  /// Wipe preferences back to defaults (keeps onboarding done so the user
  /// isn't bounced through the intro again).
  void reset() => _persist(const UserPreferences(onboardingComplete: true));
}

final preferencesProvider =
    NotifierProvider<PreferencesNotifier, UserPreferences>(PreferencesNotifier.new);
