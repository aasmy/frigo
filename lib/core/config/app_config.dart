/// Small runtime switches. Kept mutable so tests can turn off anything that
/// would otherwise hit the network.
class AppConfig {
  const AppConfig._();

  /// When false, image widgets skip network loads and show their illustrated
  /// fallback. Widget tests set this to false.
  static bool networkImagesEnabled = true;

  /// When false, the app never calls Gemini even if a key is present
  /// (widget tests set this to false).
  static bool aiEnabled = true;

  /// When false, nothing is handed to the OS scheduler (widget tests set this
  /// to false so no platform channel is touched).
  static bool notificationsEnabled = true;

  // ---- Free tier allowances -------------------------------------------------
  // Metered only where a use costs real money. Everything that costs Frigo
  // nothing - manual items, inventory size, TheMealDB recipes, freshness
  // tracking, reminders - stays unlimited on the free tier.

  /// AI receipt scans per calendar month on the free tier.
  static const int freeAiScansPerMonth = 10;

  /// Assistant replies per day on the free tier.
  static const int freeAssistantRepliesPerDay = 5;

  /// Extra scans granted for watching one rewarded ad.
  static const int rewardedScanBonus = 3;

  /// Store product identifiers. These must match the IDs created in Play
  /// Console and App Store Connect exactly.
  static const String proMonthlyId = 'frigo_pro_monthly';
  static const String proYearlyId = 'frigo_pro_yearly';
  static const Set<String> proProductIds = {proMonthlyId, proYearlyId};

  /// Gemini model used for every AI task. `flash` is fast + cheap + multimodal.
  static const String geminiModel = 'gemini-2.5-flash';

  /// Default open model on Hugging Face's OpenAI-compatible router. Any
  /// instruct model on the router works — this one is a good size/quality
  /// trade for structured extraction.
  static const String huggingFaceModel = 'Qwen/Qwen2.5-7B-Instruct';

  /// Text-only AI calls.
  static const Duration aiTimeout = Duration(seconds: 30);

  /// Multimodal calls (a receipt photo) — uploading + reading an image is much
  /// slower than text, and timing out here silently downgrades the whole scan
  /// to the offline parser.
  static const Duration aiVisionTimeout = Duration(seconds: 120);

  /// Longest edge a receipt photo is resized to before upload. Full-resolution
  /// phone photos are 3-5 MB, which is what actually blows the timeout.
  static const int receiptMaxDimension = 1600;
  static const int receiptJpegQuality = 72;
}

