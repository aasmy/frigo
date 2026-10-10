import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/config/app_config.dart';
import '../../../core/models/receipt.dart';
import '../../../core/models/receipt_item.dart';
import '../../../core/providers/service_providers.dart';
import '../../../core/repositories/inventory_repository.dart';
import '../../../core/repositories/entitlement_repository.dart';
import '../../../core/repositories/receipt_repository.dart';
import '../../../core/utils/haptics.dart';
import '../../../core/services/ai/ai_service.dart';
import '../../../core/services/ocr/ocr_service.dart';

enum ScanSource { camera, gallery, demo }

/// A purchased row that looks like something already in the kitchen.
class DuplicateWarning {
  const DuplicateWarning({required this.name, required this.existingSummary});
  final String name;
  final String existingSummary;
}

sealed class ScanState {
  const ScanState();
}

class ScanIdle extends ScanState {
  const ScanIdle();
}

class ScanProcessing extends ScanState {
  const ScanProcessing({required this.message, required this.progress});
  final String message;
  final double progress; // 0..1
}

class ScanReview extends ScanState {
  const ScanReview({required this.draft, required this.duplicates});
  final Receipt draft;
  final List<DuplicateWarning> duplicates;

  ScanReview copyWith({Receipt? draft}) =>
      ScanReview(draft: draft ?? this.draft, duplicates: duplicates);
}

/// The free AI allowance is spent. Not an error: the scan simply needs either
/// a rewarded ad or Pro, and the UI offers both.
class ScanQuotaExhausted extends ScanState {
  const ScanQuotaExhausted();
}

class ScanError extends ScanState {
  const ScanError({required this.message, this.canRetry = true});
  final String message;
  final bool canRetry;
}

class ScanComplete extends ScanState {
  const ScanComplete({required this.addedCount, required this.merchant});
  final int addedCount;
  final String merchant;
}

/// Drives Scan → Processing → Confirmation → Kitchen.
class ScanController extends Notifier<ScanState> {
  final _picker = ImagePicker();

  @override
  ScanState build() => const ScanIdle();

  Future<void> start(ScanSource source) async {
    // Checked before the camera opens, so the user is never asked to take a
    // photo we are then unable to read.
    if (!ref.read(entitlementProvider.notifier).consumeAiScan()) {
      state = const ScanQuotaExhausted();
      return;
    }

    String? imagePath;
    if (source != ScanSource.demo) {
      try {
        final picked = await _picker.pickImage(
          source: source == ScanSource.camera
              ? ImageSource.camera
              : ImageSource.gallery,
          maxWidth: AppConfig.receiptMaxDimension.toDouble(),
          maxHeight: AppConfig.receiptMaxDimension.toDouble(),
          imageQuality: AppConfig.receiptJpegQuality,
        );
        if (picked == null) {
          state = const ScanIdle();
          return;
        }
        imagePath = picked.path;
      } catch (e) {
        // No camera (e.g. simulator) — fall through with the mock pipeline so
        // the flow is always demoable.
        debugPrint('image_picker unavailable: $e');
      }
    }
    await _runPipeline(imagePath);
  }

  Future<void> retry() => _runPipeline(null);

  Future<void> _runPipeline(String? imagePath) async {
    final ocr = ref.read(ocrServiceProvider);
    final ai = ref.read(aiServiceProvider);

    try {
      state = const ScanProcessing(message: 'Uploading receipt…', progress: 0.15);
      await Future<void>.delayed(const Duration(milliseconds: 500));

      state = const ScanProcessing(message: 'Reading items…', progress: 0.4);
      final OcrResult ocrResult = await ocr.extractText(imagePath: imagePath);
      if (!ocrResult.looksUsable) {
        state = const ScanError(
          message: "We couldn't read enough of this receipt.",
        );
        return;
      }

      state = const ScanProcessing(
          message: 'Understanding groceries…', progress: 0.7);
      final draft = await ai.parseReceipt(
        ocrText: ocrResult.rawText,
        imagePath: imagePath,
      );

      state = const ScanProcessing(
          message: 'Organizing your kitchen…', progress: 0.92);
      await Future<void>.delayed(const Duration(milliseconds: 400));

      state = ScanReview(draft: draft, duplicates: _findDuplicates(draft));
    } on OcrException catch (e) {
      state = ScanError(message: e.message);
    } on AiException catch (e) {
      state = ScanError(message: e.message, canRetry: e.recoverable);
    } catch (e) {
      state = const ScanError(
        message: 'Something went wrong while reading the receipt.',
      );
    }
  }

  List<DuplicateWarning> _findDuplicates(Receipt draft) {
    final inventory = ref.read(inventoryProvider.notifier);
    final warnings = <DuplicateWarning>[];
    for (final item in draft.items.where((i) => i.isFood && i.included)) {
      final matches = inventory.matching(item.normalizedName);
      if (matches.isNotEmpty) {
        final summary = matches
            .map((m) => m.quantityLabel)
            .take(2)
            .join(' + ');
        warnings.add(DuplicateWarning(
          name: item.normalizedName,
          existingSummary: 'You already have $summary',
        ));
      }
    }
    return warnings;
  }

  // --- confirmation-screen editing --------------------------------------------
  void updateItem(ReceiptItem updated) {
    final s = state;
    if (s is! ScanReview) return;
    final items = s.draft.items
        .map((i) => i.id == updated.id ? updated : i)
        .toList();
    state = s.copyWith(draft: s.draft.copyWith(items: items));
  }

  void removeItem(String id) {
    final s = state;
    if (s is! ScanReview) return;
    final items = s.draft.items.where((i) => i.id != id).toList();
    state = s.copyWith(draft: s.draft.copyWith(items: items));
  }

  void setMerchant(String value) {
    final s = state;
    if (s is! ScanReview) return;
    state = s.copyWith(draft: s.draft.copyWith(merchant: value));
  }

  Future<void> confirm() async {
    final s = state;
    if (s is! ScanReview) return;
    final draft = s.draft;

    state = const ScanProcessing(
        message: 'Adding to your kitchen…', progress: 0.5);

    final added = await ref.read(inventoryProvider.notifier).addFromReceipt(draft);
    ref.read(receiptsProvider.notifier).save(draft);

    Haptics.success();
    state = ScanComplete(addedCount: added, merchant: draft.merchant);
  }

  void reset() => state = const ScanIdle();
}

final scanControllerProvider =
    NotifierProvider<ScanController, ScanState>(ScanController.new);
