/// Raw output of an OCR pass over a receipt image.
class OcrResult {
  const OcrResult({required this.rawText, this.blockCount = 0});

  final String rawText;
  final int blockCount;

  bool get looksUsable => rawText.trim().length > 20 && blockCount >= 3;
}

class OcrException implements Exception {
  const OcrException(this.message);
  final String message;
  @override
  String toString() => 'OcrException: $message';
}

/// Contract for turning a receipt image into raw text.
///
/// The mock implementation returns canned text. A real implementation would
/// call an on-device recognizer (ML Kit / Vision) or a server OCR endpoint —
/// the return type stays the same so nothing downstream changes.
abstract interface class OcrService {
  Future<OcrResult> extractText({String? imagePath});
}
