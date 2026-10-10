/// Copy this file to `secrets.dart` and drop in your key.
///
/// `secrets.dart` is git-ignored. For a real production build the key belongs
/// on a server (a Supabase Edge Function that proxies Gemini), not in the app —
/// this is a convenience for local development only.
class Secrets {
  const Secrets._();

  /// Google Gemini API key (https://aistudio.google.com/apikey).
  /// Leave empty to run fully offline on the built-in mock pipeline.
  static const String geminiApiKey = '';

  /// Hugging Face access token (hf_...). Empty -> the Hugging Face provider is
  /// unavailable and Frigo falls back to the offline pipeline.
  static const String huggingFaceToken = '';
}
