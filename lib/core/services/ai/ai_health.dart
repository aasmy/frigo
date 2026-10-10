import 'package:flutter/foundation.dart';

enum AiTask { receipt, normalize, shelfLife, recipes, assistant }

extension AiTaskLabel on AiTask {
  String get label => switch (this) {
        AiTask.receipt => 'Receipt reading',
        AiTask.normalize => 'Item naming',
        AiTask.shelfLife => 'Freshness estimate',
        AiTask.recipes => 'Recipe ideas',
        AiTask.assistant => 'Assistant',
      };
}

/// Tracks whether the AI is actually working.
///
/// Every Gemini call falls back to the offline pipeline on failure, which is
/// great for reliability but means problems are invisible. This records them so
/// Profile can show real status and the scan flow can say "read offline".
class AiHealth extends ChangeNotifier {
  AiHealth._();
  static final AiHealth instance = AiHealth._();

  DateTime? lastSuccessAt;
  DateTime? lastFailureAt;
  AiTask? lastFailedTask;
  String? lastError;

  /// True when the most recent AI attempt fell back to the offline pipeline.
  bool get degraded =>
      lastFailureAt != null &&
      (lastSuccessAt == null || lastFailureAt!.isAfter(lastSuccessAt!));

  String? get statusDetail {
    if (lastError == null) return null;
    final t = lastFailedTask?.label ?? 'AI';
    return '$t fell back to offline — ${_short(lastError!)}';
  }

  void recordSuccess(AiTask task) {
    lastSuccessAt = DateTime.now();
    if (!degraded) {
      lastError = null;
      lastFailedTask = null;
    }
    notifyListeners();
  }

  void recordFailure(AiTask task, Object error) {
    lastFailureAt = DateTime.now();
    lastFailedTask = task;
    lastError = error.toString();
    debugPrint('AI ${task.name} failed: $error');
    notifyListeners();
  }

  /// Human-readable one-liner for the most recent failure.
  static String shortReason(String? e) =>
      e == null ? 'the AI was unreachable' : _short(e);

  static String _short(String e) {
    var s = e.replaceAll('GeminiException: ', '').trim();
    if (s.startsWith('TimeoutException')) return 'timed out';
    if (s.contains('HTTP 429')) return 'rate limited';
    if (s.contains('HTTP 4')) return 'rejected by the API';
    if (s.toLowerCase().contains('connection') ||
        s.toLowerCase().contains('socket')) {
      return 'no connection';
    }
    return s.length > 70 ? '${s.substring(0, 70)}…' : s;
  }
}
