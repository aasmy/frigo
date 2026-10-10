import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../../config/app_config.dart';
import 'llm_client.dart';

class GeminiException implements Exception {
  const GeminiException(this.message);
  final String message;
  @override
  String toString() => 'GeminiException: $message';
}

/// Minimal REST wrapper around the Gemini `generateContent` endpoint.
///
/// Every call asks for `application/json` back and disables "thinking" so the
/// flash model responds quickly. Callers get the raw decoded JSON (a `Map` or
/// `List`) and are responsible for validating shape.
class GeminiClient implements LlmClient {
  GeminiClient(this.apiKey, {http.Client? httpClient})
      : _http = httpClient ?? http.Client();

  final String apiKey;
  final http.Client _http;

  @override
  String get name => 'Google Gemini / ${AppConfig.geminiModel}';

  /// Gemini reads the receipt photo directly, which the open text models
  /// on other providers cannot.
  @override
  bool get supportsVision => true;

  Uri get _endpoint => Uri.parse(
        'https://generativelanguage.googleapis.com/v1beta/models/'
        '${AppConfig.geminiModel}:generateContent?key=$apiKey',
      );

  /// Conversational reply (plain text). [history] is a list of
  /// `{'role': 'user'|'model', 'text': ...}` turns, oldest first.
  @override
  Future<String> generateText({
    required String prompt,
    String? systemInstruction,
    List<Map<String, String>> history = const [],
    Duration? timeout,
  }) async {
    final contents = <Map<String, dynamic>>[
      for (final h in history)
        {
          'role': h['role'] == 'model' ? 'model' : 'user',
          'parts': [
            {'text': h['text'] ?? ''}
          ],
        },
      {
        'role': 'user',
        'parts': [
          {'text': prompt}
        ],
      },
    ];

    final body = jsonEncode({
      'contents': contents,
      if (systemInstruction != null)
        'systemInstruction': {
          'parts': [
            {'text': systemInstruction}
          ]
        },
      'generationConfig': {
        'temperature': 0.6,
        'thinkingConfig': {'thinkingBudget': 0},
      },
    });

    late http.Response res;
    try {
      res = await _http
          .post(_endpoint,
              headers: {'Content-Type': 'application/json'}, body: body)
          .timeout(timeout ?? AppConfig.aiTimeout);
    } on SocketException {
      throw const GeminiException('No connection to Gemini.');
    } catch (e) {
      throw GeminiException('Request failed: $e');
    }
    if (res.statusCode != 200) {
      throw GeminiException('HTTP ${res.statusCode}: ${res.body}');
    }
    final text = _extractText(jsonDecode(res.body));
    if (text == null || text.trim().isEmpty) {
      throw const GeminiException('Empty response.');
    }
    return text.trim();
  }

  /// [imageBytes]/[imageMime] optionally attaches a photo (e.g. a receipt).
  @override
  Future<Object> generateJson({
    required String prompt,
    List<int>? imageBytes,
    String imageMime = 'image/jpeg',
    Duration? timeout,
  }) async {
    final parts = <Map<String, dynamic>>[
      {'text': prompt},
      if (imageBytes != null)
        {
          'inline_data': {
            'mime_type': imageMime,
            'data': base64Encode(imageBytes),
          }
        },
    ];

    final body = jsonEncode({
      'contents': [
        {'parts': parts}
      ],
      'generationConfig': {
        'responseMimeType': 'application/json',
        'temperature': 0.2,
        'thinkingConfig': {'thinkingBudget': 0},
      },
    });

    late http.Response res;
    try {
      res = await _http
          .post(_endpoint,
              headers: {'Content-Type': 'application/json'}, body: body)
          .timeout(timeout ?? AppConfig.aiTimeout);
    } on SocketException {
      throw const GeminiException('No connection to Gemini.');
    } catch (e) {
      throw GeminiException('Request failed: $e');
    }

    if (res.statusCode != 200) {
      throw GeminiException('HTTP ${res.statusCode}: ${res.body}');
    }

    final decoded = jsonDecode(res.body);
    final text = _extractText(decoded);
    if (text == null || text.trim().isEmpty) {
      throw const GeminiException('Empty response.');
    }
    try {
      return jsonDecode(text) as Object;
    } catch (_) {
      // The model sometimes wraps JSON in prose / fences — salvage it.
      final salvaged = _salvageJson(text);
      if (salvaged != null) return salvaged;
      throw GeminiException('Response was not JSON: $text');
    }
  }

  String? _extractText(dynamic decoded) {
    try {
      final parts = decoded['candidates'][0]['content']['parts'] as List;
      return parts
          .map((p) => (p as Map)['text'])
          .whereType<String>()
          .join();
    } catch (_) {
      return null;
    }
  }

  Object? _salvageJson(String text) {
    final start = text.indexOf(RegExp(r'[\[{]'));
    final end = text.lastIndexOf(RegExp(r'[\]}]'));
    if (start < 0 || end <= start) return null;
    try {
      return jsonDecode(text.substring(start, end + 1)) as Object;
    } catch (_) {
      return null;
    }
  }

  void dispose() => _http.close();
}
