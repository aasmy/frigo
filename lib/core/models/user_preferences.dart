import '../services/ai/llm_client.dart';

enum DietPreference {
  none,
  halal,
  vegetarian,
  vegan,
  pescatarian;

  String get label => switch (this) {
        DietPreference.none => 'No preference',
        DietPreference.halal => 'Halal',
        DietPreference.vegetarian => 'Vegetarian',
        DietPreference.vegan => 'Vegan',
        DietPreference.pescatarian => 'Pescatarian',
      };
}

enum MaxCookingTime {
  any,
  under15,
  under30,
  under45;

  String get label => switch (this) {
        MaxCookingTime.any => 'Any',
        MaxCookingTime.under15 => 'Under 15 min',
        MaxCookingTime.under30 => 'Under 30 min',
        MaxCookingTime.under45 => 'Under 45 min',
      };

  int? get minutes => switch (this) {
        MaxCookingTime.any => null,
        MaxCookingTime.under15 => 15,
        MaxCookingTime.under30 => 30,
        MaxCookingTime.under45 => 45,
      };
}

class UserPreferences {
  const UserPreferences({
    this.diet = DietPreference.none,
    this.maxCookingTime = MaxCookingTime.any,
    this.excludedIngredients = const [],
    this.expiryNotifications = true,
    this.dailyCookIdea = true,
    this.displayName,
    this.onboardingComplete = false,
    this.aiProvider = AiProvider.gemini,
  });

  final DietPreference diet;
  final MaxCookingTime maxCookingTime;
  final List<String> excludedIngredients;
  final bool expiryNotifications;
  final bool dailyCookIdea;
  final String? displayName;
  final bool onboardingComplete;

  /// Which backend powers the AI features. Switchable from Profile.
  final AiProvider aiProvider;

  UserPreferences copyWith({
    DietPreference? diet,
    MaxCookingTime? maxCookingTime,
    List<String>? excludedIngredients,
    bool? expiryNotifications,
    bool? dailyCookIdea,
    Object? displayName = _sentinel,
    bool? onboardingComplete,
    AiProvider? aiProvider,
  }) {
    return UserPreferences(
      diet: diet ?? this.diet,
      maxCookingTime: maxCookingTime ?? this.maxCookingTime,
      excludedIngredients: excludedIngredients ?? this.excludedIngredients,
      expiryNotifications: expiryNotifications ?? this.expiryNotifications,
      dailyCookIdea: dailyCookIdea ?? this.dailyCookIdea,
      displayName:
          displayName == _sentinel ? this.displayName : displayName as String?,
      onboardingComplete: onboardingComplete ?? this.onboardingComplete,
      aiProvider: aiProvider ?? this.aiProvider,
    );
  }

  Map<String, dynamic> toJson() => {
        'diet': diet.name,
        'max_cooking_time': maxCookingTime.name,
        'excluded_ingredients': excludedIngredients,
        'expiry_notifications': expiryNotifications,
        'daily_cook_idea': dailyCookIdea,
        'display_name': displayName,
        'onboarding_complete': onboardingComplete,
        'ai_provider': aiProvider.name,
      };

  factory UserPreferences.fromJson(Map<String, dynamic> json) => UserPreferences(
        diet: DietPreference.values.firstWhere(
          (e) => e.name == json['diet'],
          orElse: () => DietPreference.none,
        ),
        maxCookingTime: MaxCookingTime.values.firstWhere(
          (e) => e.name == json['max_cooking_time'],
          orElse: () => MaxCookingTime.any,
        ),
        excludedIngredients:
            (json['excluded_ingredients'] as List<dynamic>? ?? []).cast<String>(),
        expiryNotifications: json['expiry_notifications'] as bool? ?? true,
        dailyCookIdea: json['daily_cook_idea'] as bool? ?? true,
        displayName: json['display_name'] as String?,
        onboardingComplete: json['onboarding_complete'] as bool? ?? false,
        aiProvider: AiProvider.fromName(json['ai_provider'] as String?),
      );

  static const Object _sentinel = Object();
}
