import 'receipt_item.dart';

/// A scanned receipt plus everything the pipeline extracted from it.
class Receipt {
  const Receipt({
    required this.id,
    required this.merchant,
    required this.purchaseDate,
    required this.items,
    required this.createdAt,
    this.currency = 'USD',
    this.imagePath,
    this.rawOcrText,
  });

  final String id;
  final String merchant;
  final DateTime purchaseDate;
  final String currency;
  final List<ReceiptItem> items;
  final DateTime createdAt;
  final String? imagePath;
  final String? rawOcrText;

  int get foodItemCount => items.where((i) => i.isFood).length;

  double? get total {
    final priced = items.where((i) => i.price != null);
    if (priced.isEmpty) return null;
    return priced.fold<double>(0, (sum, i) => sum + (i.price ?? 0));
  }

  Receipt copyWith({
    String? merchant,
    DateTime? purchaseDate,
    String? currency,
    List<ReceiptItem>? items,
    String? imagePath,
    String? rawOcrText,
  }) {
    return Receipt(
      id: id,
      merchant: merchant ?? this.merchant,
      purchaseDate: purchaseDate ?? this.purchaseDate,
      currency: currency ?? this.currency,
      items: items ?? this.items,
      createdAt: createdAt,
      imagePath: imagePath ?? this.imagePath,
      rawOcrText: rawOcrText ?? this.rawOcrText,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'merchant': merchant,
        'purchase_date': purchaseDate.toIso8601String(),
        'currency': currency,
        'image_path': imagePath,
        'raw_ocr_text': rawOcrText,
        'created_at': createdAt.toIso8601String(),
        'items': items.map((i) => i.toJson()).toList(),
      };

  factory Receipt.fromJson(Map<String, dynamic> json) => Receipt(
        id: json['id'] as String,
        merchant: json['merchant'] as String? ?? 'Unknown store',
        purchaseDate: DateTime.parse(json['purchase_date'] as String),
        currency: json['currency'] as String? ?? 'USD',
        imagePath: json['image_path'] as String?,
        rawOcrText: json['raw_ocr_text'] as String?,
        createdAt: DateTime.parse(json['created_at'] as String),
        items: (json['items'] as List<dynamic>? ?? [])
            .map((e) => ReceiptItem.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}
