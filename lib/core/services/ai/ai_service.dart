import '../../models/enums.dart';
import '../../models/receipt.dart';
import '../../models/recipe.dart';
import '../../models/shelf_life_estimate.dart';
import '../../models/user_preferences.dart';

/// Raised when an AI task fails or returns data that fails schema validation.
/// Callers should surface a friendly error and offer a manual fallback.
class AiException implements Exception {
  const AiException(this.message, {this.recoverable = true});
  final String message;
  final bool recoverable;
  @override
  String toString() => 'AiException: $message';
}

/// Result of AI Task B — normalizing one messy product name.
class NormalizationResult {
  const NormalizationResult({
    required this.normalizedName,
    required this.category,
    required this.unit,
    required this.confidence,
    this.brand,
  });

  final String normalizedName;
  final FoodCategory category;
  final String unit;
  final double confidence;
  final String? brand;
}

/// Structured input for AI Task D — recipe generation.
class RecipeRequestItem {
  const RecipeRequestItem({
    required this.name,
    required this.quantity,
    required this.unit,
    this.expiresInDays,
  });

  final String name;
  final double quantity;
  final String unit;
  final int? expiresInDays;

  Map<String, dynamic> toJson() => {
        'name': name,
        'quantity': quantity,
        'unit': unit,
        if (expiresInDays != null) 'expires_in_days': expiresInDays,
      };
}

/// The four AI responsibilities from the spec, behind one interface.
///
/// Every method returns validated, structured data — never free text. The
/// mock implementation fabricates plausible results; a server-backed
/// implementation would call Edge Functions that enforce JSON schemas and
/// keep API keys server-side.
abstract interface class AiService {
  /// AI Task A + B: parse OCR text into a structured, normalized receipt.
  Future<Receipt> parseReceipt({
    required String ocrText,
    String? imagePath,
  });

  /// AI Task B: normalize a single name (used by Manual Add).
  Future<NormalizationResult> normalizeName(String rawName);

  /// AI Task C: estimate shelf life for a product in a given storage location.
  Future<ShelfLifeEstimate> estimateShelfLife({
    required String productName,
    required FoodCategory category,
    required DateTime purchaseDate,
    required StorageLocation storage,
    bool opened = false,
  });

  /// AI Task D: generate 3–5 recipes from current inventory.
  Future<List<Recipe>> generateRecipes({
    required List<RecipeRequestItem> inventory,
    List<String> prioritiseNames = const [],
    DietPreference diet = DietPreference.none,
    int? maxMinutes,
    List<String> excludedIngredients = const [],
    List<String> avoidTitles = const [],
  });
}
