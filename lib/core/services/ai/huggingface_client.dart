import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../config/app_config.dart';
import 'llm_client.dart';

/// Hugging Face Inference Providers, through the OpenAI-compatible router.
///
/// One endpoint fronts every partner provider, so moving between Llama, Qwen
/// and Mistral is a string change. Free accounts get a small monthly credit
/// allowance — see the README for what that actually buys in practice.
class HuggingFaceClient implements LlmClient {
  HuggingFaceClient(
    this.apiKey, {
    this.model = AppConfig.huggingFaceModel,
    http.Client? httpClient,
  }) : _http = httpClient ?? http.Client();

  final String apiKey;
  final String model;
  final http.Client _http;

  static final _endpoint =
      Uri.parse('https://router.huggingface.co/v1/chat/completions');

  @override
  String get name => 'Hugging Face / $model';

  /// The open text models on the router take no image here, so receipt
  /// scanning leans on on-device OCR — which is the fast path anyway.
  @override
  bool get supportsVision => false;

  @override
  Future<String> generateText({
    required String prompt,
    String? systemInstruction,
    List<Map<String, String>> history = const [],
    Duration? timeout,
  }) {
    return _chat(
      [
        if (systemInstruction != null)
          {'role': 'system', 'content': systemInstruction},
        for (final h in history)
          {
            'role': h['role'] == 'model' ? 'assistant' : 'user',
            'content': h['text'] ?? '',
          },
        {'role': 'user', 'content': prompt},
      ],
      timeout: timeout,
    );
  }

  @override
  Future<Object> generateJson({
    required String prompt,
    List<int>? imageBytes,
    String imageMime = 'image/jpeg',
    Duration? timeout,
  }) async {
    // imageBytes is ignored on purpose — see [supportsVision].
    final raw = await _chat(
      [
        {
          'role': 'system',
          'content': 'You reply with a single valid JSON value and nothing '
              'else: no prose, no markdown fence.',
        },
        {'role': 'user', 'content': prompt},
      ],
      timeout: timeout,
      jsonMode: true,
    );
    return decodeLooseJson(raw);
  }

  Future<String> _chat(
    List<Map<String, String>> messages, {
    Duration? timeout,
    bool jsonMode = false,
  }) async {
    late http.Response res;
    try {
      res = await _http
          .post(
            _endpoint,
            headers: {
              'Authorization': 'Bearer $apiKey',
              'Content-Type': 'application/json',
            },
            body: jsonEncode({
              'model': model,
              'messages': messages,
              'temperature': jsonMode ? 0.1 : 0.6,
              'max_tokens': 2048,
              if (jsonMode) 'response_format': {'type': 'json_object'},
            }),
          )
          .timeout(timeout ?? AppConfig.aiTimeout);
    } on TimeoutException {
      throw const LlmException('TimeoutException');
    } catch (e) {
      throw LlmException('$e');
    }

    if (res.statusCode == 402) {
      throw const LlmException(
          'HTTP 402 - monthly Hugging Face inference credits are used up.');
    }
    if (res.statusCode != 200) {
      throw LlmException('HTTP ${res.statusCode} ${_errorText(res.body)}');
    }

    final body = jsonDecode(res.body) as Map<String, dynamic>;
    final choices = body['choices'] as List?;
    if (choices == null || choices.isEmpty) {
      throw const LlmException('No choices returned.');
    }
    final msg = (choices.first as Map)['message'] as Map?;
    final content = msg?['content'] as String?;
    if (content == null || content.trim().isEmpty) {
      throw const LlmException('Empty reply.');
    }
    return content.trim();
  }

  static String _errorText(String body) {
    try {
      final m = jsonDecode(body);
      if (m is Map && m['error'] != null) {
        final e = m['error'];
        return e is Map ? '${e['message']}' : '$e';
      }
    } catch (_) {
      // fall through to the raw body
    }
    return body.length > 160 ? body.substring(0, 160) : body;
  }

  /// Open models still fence their JSON or add a sentence around it. Recover
  /// the value rather than failing a whole scan over a markdown wrapper.
  static Object decodeLooseJson(String raw) {
    var s = raw.trim();
    if (s.startsWith('```')) {
      s = s.replaceFirst(RegExp(r'^```[a-zA-Z]*\s*'), '');
      final end = s.lastIndexOf('```');
      if (end != -1) s = s.substring(0, end);
      s = s.trim();
    }
    if (!s.startsWith('{') && !s.startsWith('[')) {
      final start = s.indexOf(RegExp(r'[{\[]'));
      final endObj = s.lastIndexOf('}');
      final endArr = s.lastIndexOf(']');
      final end = endObj > endArr ? endObj : endArr;
      if (start == -1 || end <= start) {
        throw const LlmException('Reply was not JSON.');
      }
      s = s.substring(start, end + 1);
    }
    try {
      return jsonDecode(s) as Object;
    } catch (e) {
      throw LlmException('Bad JSON: $e');
    }
  }
}
