import 'enums.dart';

/// A single food item the user has at home.
///
/// [status] is derived from [estimatedExpirationDate] unless the item is
/// explicitly [FreshnessStatus.frozen]. We never store a hard status that
/// contradicts the dates.
class InventoryItem {
  const InventoryItem({
    required this.id,
    required this.name,
    required this.category,
    required this.quantity,
    required this.unit,
    required this.storageLocation,
    required this.purchaseDate,
    this.normalizedName,
    this.estimatedExpirationDate,
    this.manualStatus,
    this.receiptId,
    this.photoPath,
    this.imageUrl,
    this.notes,
    this.openedDate,
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : createdAt = createdAt ?? purchaseDate,
        updatedAt = updatedAt ?? purchaseDate;

  final String id;
  final String name;
  final String? normalizedName;
  final FoodCategory category;
  final double quantity;
  final String unit;
  final StorageLocation storageLocation;
  final DateTime purchaseDate;
  final DateTime? estimatedExpirationDate;

  /// When set (e.g. user froze the item), overrides the date-derived status.
  final FreshnessStatus? manualStatus;
  final String? receiptId;

  /// A user-picked local photo (future); takes priority over [imageUrl].
  final String? photoPath;

  /// A resolved remote thumbnail URL, stored so it stays stable for this item.
  final String? imageUrl;
  final String? notes;
  final DateTime? openedDate;
  final DateTime createdAt;
  final DateTime updatedAt;

  String get displayName => normalizedName?.trim().isNotEmpty == true
      ? normalizedName!.trim()
      : name;

  /// Whole days until the estimate elapses. Negative when already past.
  int? get daysUntilExpiration {
    final exp = estimatedExpirationDate;
    if (exp == null) return null;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final target = DateTime(exp.year, exp.month, exp.day);
    return target.difference(today).inDays;
  }

  int get daysSincePurchase {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final p = DateTime(purchaseDate.year, purchaseDate.month, purchaseDate.day);
    return today.difference(p).inDays;
  }

  FreshnessStatus get status {
    if (manualStatus != null) return manualStatus!;
    if (storageLocation == StorageLocation.freezer) return FreshnessStatus.frozen;
    final days = daysUntilExpiration;
    if (days == null) return FreshnessStatus.unknown;
    if (days < 0) return FreshnessStatus.expired;
    if (days <= 2) return FreshnessStatus.useSoon;
    return FreshnessStatus.fresh;
  }

  /// Soft, non-authoritative freshness phrasing for the UI.
  String get freshnessLabel {
    if (manualStatus == FreshnessStatus.frozen ||
        storageLocation == StorageLocation.freezer) {
      return 'Frozen — keeps for months';
    }
    final days = daysUntilExpiration;
    if (days == null) return 'Purchased ${_ago(daysSincePurchase)}';
    if (days < 0) return 'Best used a while ago — check before eating';
    if (days == 0) return 'Best used today';
    if (days == 1) return 'Best used within a day';
    if (days <= 4) return 'Best used within ~$days days';
    return 'Estimated freshness ~$days days';
  }

  static String _ago(int days) {
    if (days <= 0) return 'today';
    if (days == 1) return 'yesterday';
    return '$days days ago';
  }

  /// Compact chip text: "1 day left", "5 days left", "Fresh", "Frozen".
  String get daysLeftLabel {
    if (manualStatus == FreshnessStatus.frozen ||
        storageLocation == StorageLocation.freezer) {
      return 'Frozen';
    }
    final days = daysUntilExpiration;
    if (days == null) return 'No date';
    if (days < 0) return 'Overdue';
    if (days == 0) return 'Today';
    if (days == 1) return '1 day left';
    if (days <= 14) return '$days days left';
    if (days <= 60) return '${(days / 7).round()} wks left';
    return 'Fresh';
  }

  String get quantityLabel {
    final q = quantity == quantity.roundToDouble()
        ? quantity.toStringAsFixed(0)
        : quantity.toStringAsFixed(1);
    return unit.isEmpty ? q : '$q $unit';
  }

  InventoryItem copyWith({
    String? name,
    String? normalizedName,
    FoodCategory? category,
    double? quantity,
    String? unit,
    StorageLocation? storageLocation,
    DateTime? purchaseDate,
    DateTime? estimatedExpirationDate,
    Object? manualStatus = _sentinel,
    Object? receiptId = _sentinel,
    Object? photoPath = _sentinel,
    Object? imageUrl = _sentinel,
    Object? notes = _sentinel,
    Object? openedDate = _sentinel,
    DateTime? updatedAt,
  }) {
    return InventoryItem(
      id: id,
      name: name ?? this.name,
      normalizedName: normalizedName ?? this.normalizedName,
      category: category ?? this.category,
      quantity: quantity ?? this.quantity,
      unit: unit ?? this.unit,
      storageLocation: storageLocation ?? this.storageLocation,
      purchaseDate: purchaseDate ?? this.purchaseDate,
      estimatedExpirationDate: estimatedExpirationDate ?? this.estimatedExpirationDate,
      manualStatus: manualStatus == _sentinel
          ? this.manualStatus
          : manualStatus as FreshnessStatus?,
      receiptId: receiptId == _sentinel ? this.receiptId : receiptId as String?,
      photoPath: photoPath == _sentinel ? this.photoPath : photoPath as String?,
      imageUrl: imageUrl == _sentinel ? this.imageUrl : imageUrl as String?,
      notes: notes == _sentinel ? this.notes : notes as String?,
      openedDate: openedDate == _sentinel ? this.openedDate : openedDate as DateTime?,
      createdAt: createdAt,
      updatedAt: updatedAt ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'normalized_name': normalizedName,
        'category': category.name,
        'quantity': quantity,
        'unit': unit,
        'storage_location': storageLocation.name,
        'purchase_date': purchaseDate.toIso8601String(),
        'estimated_expiration_date': estimatedExpirationDate?.toIso8601String(),
        'manual_status': manualStatus?.name,
        'receipt_id': receiptId,
        'photo_path': photoPath,
        'image_url': imageUrl,
        'notes': notes,
        'opened_date': openedDate?.toIso8601String(),
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
      };

  factory InventoryItem.fromJson(Map<String, dynamic> json) => InventoryItem(
        id: json['id'] as String,
        name: json['name'] as String,
        normalizedName: json['normalized_name'] as String?,
        category: FoodCategory.fromAny(json['category'] as String?),
        quantity: (json['quantity'] as num).toDouble(),
        unit: json['unit'] as String? ?? '',
        storageLocation: StorageLocation.fromName(json['storage_location'] as String?),
        purchaseDate: DateTime.parse(json['purchase_date'] as String),
        estimatedExpirationDate: _parseDate(json['estimated_expiration_date']),
        manualStatus: json['manual_status'] == null
            ? null
            : FreshnessStatus.fromName(json['manual_status'] as String?),
        receiptId: json['receipt_id'] as String?,
        photoPath: json['photo_path'] as String?,
        imageUrl: json['image_url'] as String?,
        notes: json['notes'] as String?,
        openedDate: _parseDate(json['opened_date']),
        createdAt: _parseDate(json['created_at']),
        updatedAt: _parseDate(json['updated_at']),
      );

  static DateTime? _parseDate(Object? v) =>
      v == null ? null : DateTime.tryParse(v as String);

  static const Object _sentinel = Object();
}
