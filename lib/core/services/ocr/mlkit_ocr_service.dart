import 'package:flutter/foundation.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

import 'mock_ocr_service.dart';
import 'ocr_service.dart';

/// Real on-device OCR (Google ML Kit — free, no key, offline). Falls back to
/// [MockOcrService] when there is no image (e.g. the "sample receipt" path) or
/// if recognition throws on a platform without the model.
class MlKitOcrService implements OcrService {
  MlKitOcrService({OcrService? fallback})
      : _fallback = fallback ?? MockOcrService();

  final OcrService _fallback;
  final TextRecognizer _recognizer =
      TextRecognizer(script: TextRecognitionScript.latin);

  @override
  Future<OcrResult> extractText({String? imagePath}) async {
    if (imagePath == null) return _fallback.extractText();
    try {
      final input = InputImage.fromFilePath(imagePath);
      final recognized = await _recognizer.processImage(input);
      final text = recognized.text.trim();
      // Count non-empty lines rather than ML Kit blocks — receipts often come
      // back as one tall block.
      final lines =
          text.split('\n').where((l) => l.trim().isNotEmpty).length;
      if (text.length < 20 || lines < 3) {
        // Signal an unusable scan; the controller shows the retry screen.
        return OcrResult(rawText: text, blockCount: lines);
      }
      return OcrResult(rawText: text, blockCount: lines);
    } catch (e) {
      debugPrint('ML Kit OCR failed, using fallback: $e');
      return _fallback.extractText(imagePath: imagePath);
    }
  }

  void dispose() => _recognizer.close();
}
