import 'enums.dart';

/// One line extracted from a receipt by the AI pipeline, before the user
/// has confirmed it. Mutable-ish via [copyWith] because the confirmation
/// screen edits these heavily.
class ReceiptItem {
  const ReceiptItem({
    required this.id,
    required this.rawName,
    required this.normalizedName,
    required this.category,
    required this.quantity,
    required this.unit,
    required this.isFood,
    required this.confidence,
    this.brand,
    this.price,
    this.storageLocation,
    this.included = true,
  });

  final String id;
  final String rawName;
  final String normalizedName;
  final FoodCategory category;
  final double quantity;
  final String unit;
  final bool isFood;

  /// 0.0–1.0 model confidence in the normalization.
  final double confidence;
  final String? brand;
  final double? price;

  /// Chosen on the confirmation screen; defaults are inferred from category.
  final StorageLocation? storageLocation;

  /// Whether this row will be added to the kitchen.
  final bool included;

  bool get isLowConfidence => confidence < 0.7;

  StorageLocation get effectiveStorage =>
      storageLocation ?? _defaultStorageFor(category);

  String get quantityLabel {
    final q = quantity == quantity.roundToDouble()
        ? quantity.toStringAsFixed(0)
        : quantity.toStringAsFixed(1);
    return unit.isEmpty ? q : '$q $unit';
  }

  ReceiptItem copyWith({
    String? normalizedName,
    FoodCategory? category,
    double? quantity,
    String? unit,
    bool? isFood,
    double? confidence,
    Object? brand = _sentinel,
    Object? price = _sentinel,
    Object? storageLocation = _sentinel,
    bool? included,
  }) {
    return ReceiptItem(
      id: id,
      rawName: rawName,
      normalizedName: normalizedName ?? this.normalizedName,
      category: category ?? this.category,
      quantity: quantity ?? this.quantity,
      unit: unit ?? this.unit,
      isFood: isFood ?? this.isFood,
      confidence: confidence ?? this.confidence,
      brand: brand == _sentinel ? this.brand : brand as String?,
      price: price == _sentinel ? this.price : price as double?,
      storageLocation: storageLocation == _sentinel
          ? this.storageLocation
          : storageLocation as StorageLocation?,
      included: included ?? this.included,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'raw_name': rawName,
        'normalized_name': normalizedName,
        'brand': brand,
        'category': category.name,
        'quantity': quantity,
        'unit': unit,
        'price': price,
        'is_food': isFood,
        'confidence': confidence,
        'storage_location': storageLocation?.name,
      };

  factory ReceiptItem.fromJson(Map<String, dynamic> json) => ReceiptItem(
        id: json['id'] as String,
        rawName: json['raw_name'] as String? ?? '',
        normalizedName: json['normalized_name'] as String? ?? '',
        brand: json['brand'] as String?,
        category: FoodCategory.fromAny(json['category'] as String?),
        quantity: (json['quantity'] as num?)?.toDouble() ?? 1,
        unit: json['unit'] as String? ?? '',
        price: (json['price'] as num?)?.toDouble(),
        isFood: json['is_food'] as bool? ?? true,
        confidence: (json['confidence'] as num?)?.toDouble() ?? 0.5,
        storageLocation: json['storage_location'] == null
            ? null
            : StorageLocation.fromName(json['storage_location'] as String?),
      );

  static StorageLocation _defaultStorageFor(FoodCategory category) =>
      switch (category) {
        FoodCategory.meat || FoodCategory.dairy => StorageLocation.fridge,
        FoodCategory.frozen => StorageLocation.freezer,
        FoodCategory.produce => StorageLocation.fridge,
        FoodCategory.bakery => StorageLocation.counter,
        _ => StorageLocation.pantry,
      };

  static const Object _sentinel = Object();
}
