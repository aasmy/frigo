/// One LLM behind one interface, so the app can move between providers
/// (hosted API, open model, or none at all) without touching feature code.
abstract interface class LlmClient {
  /// Human-readable provider name, shown in Profile.
  String get name;

  /// Whether this client can also read an image. Receipt scanning falls back
  /// to OCR text alone when it cannot.
  bool get supportsVision;

  /// Conversational reply as plain text. [history] is a list of
  /// `{'role': 'user'|'model', 'text': ...}` turns, oldest first.
  Future<String> generateText({
    required String prompt,
    String? systemInstruction,
    List<Map<String, String>> history,
    Duration? timeout,
  });

  /// A JSON value (object or list) parsed from the model's reply.
  Future<Object> generateJson({
    required String prompt,
    List<int>? imageBytes,
    String imageMime,
    Duration? timeout,
  });
}

/// Raised for transport / quota / shape problems. Callers fall back offline.
class LlmException implements Exception {
  const LlmException(this.message);
  final String message;
  @override
  String toString() => 'LlmException: $message';
}

/// Which backend powers the AI features.
enum AiProvider {
  /// Google Gemini. Best receipt accuracy — the only one here that reads the
  /// photo itself rather than just the OCR text.
  gemini,

  /// Hugging Face Inference Providers — any open model, OpenAI-compatible.
  huggingFace,

  /// No LLM at all: the bundled offline pipeline does everything.
  offline;

  String get label => switch (this) {
        AiProvider.gemini => 'Google Gemini',
        AiProvider.huggingFace => 'Hugging Face',
        AiProvider.offline => 'On-device only',
      };

  String get blurb => switch (this) {
        AiProvider.gemini =>
          'Best receipt accuracy. Reads the photo as well as the text.',
        AiProvider.huggingFace =>
          'Open models (Llama, Qwen, Mistral). Text only — Frigo reads the '
              'photo with on-device OCR first.',
        AiProvider.offline =>
          'No network, no key, no cost. Uses the built-in receipt parser and '
              'food knowledge base.',
      };

  static AiProvider fromName(String? v) => AiProvider.values.firstWhere(
        (p) => p.name == v,
        orElse: () => AiProvider.gemini,
      );
}
