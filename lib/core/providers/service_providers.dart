import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/app_config.dart';
import '../config/secrets.dart';
import '../repositories/preferences_repository.dart';
import '../services/ai/ai_service.dart';
import '../services/ai/gemini_client.dart';
import '../services/ai/huggingface_client.dart';
import '../services/ai/llm_ai_service.dart';
import '../services/ai/llm_client.dart';
import '../services/ai/mock_ai_service.dart';
import '../services/local_store.dart';
import '../services/ocr/mlkit_ocr_service.dart';
import '../services/ocr/mock_ocr_service.dart';
import '../services/ocr/ocr_service.dart';

/// Overridden in `main()` once [SharedPreferences] has loaded.
final localStoreProvider = Provider<LocalStore>(
  (ref) => throw StateError('localStoreProvider must be overridden in main()'),
);

/// Real on-device OCR on mobile; canned sample text elsewhere (tests, web,
/// desktop) so the flow always works.
final ocrServiceProvider = Provider<OcrService>((ref) {
  if (!kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS)) {
    return MlKitOcrService();
  }
  return MockOcrService();
});

/// Whether a given provider has what it needs to run at all.
bool providerConfigured(AiProvider p) => switch (p) {
      AiProvider.gemini => Secrets.geminiApiKey.trim().isNotEmpty,
      AiProvider.huggingFace => Secrets.huggingFaceToken.trim().isNotEmpty,
      AiProvider.offline => true,
    };

/// The LLM behind the AI features, chosen in Profile.
///
/// `null` means "no LLM" — either the user picked on-device only, the chosen
/// provider has no credential, or AI is disabled for tests. Every caller
/// already has an offline path, so `null` is a supported state, not an error.
final llmClientProvider = Provider<LlmClient?>((ref) {
  if (!AppConfig.aiEnabled) return null;
  final choice = ref.watch(preferencesProvider.select((p) => p.aiProvider));
  if (!providerConfigured(choice)) return null;

  return switch (choice) {
    AiProvider.gemini => GeminiClient(Secrets.geminiApiKey.trim()),
    AiProvider.huggingFace =>
      HuggingFaceClient(Secrets.huggingFaceToken.trim()),
    AiProvider.offline => null,
  };
});

/// The four AI tasks. Always backed by the offline pipeline, with the selected
/// LLM layered on top when one is available.
final aiServiceProvider = Provider<AiService>((ref) {
  final offline = MockAiService();
  final client = ref.watch(llmClientProvider);
  if (client == null) return offline;
  return LlmAiService(client: client, fallback: offline);
});

/// True when the chat assistant can run — it is the one feature with no
/// offline equivalent, so it is hidden rather than degraded.
final assistantAvailableProvider = Provider<bool>(
  (ref) => ref.watch(llmClientProvider) != null,
);
