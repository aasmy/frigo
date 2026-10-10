/// Which bucket a shopping list row belongs to.
enum ShoppingSection { need, suggested, recentlyBought }

class ShoppingListItem {
  const ShoppingListItem({
    required this.id,
    required this.name,
    required this.createdAt,
    this.quantity,
    this.unit,
    this.completed = false,
    this.section = ShoppingSection.need,
    this.reason,
  });

  final String id;
  final String name;
  final double? quantity;
  final String? unit;
  final bool completed;
  final ShoppingSection section;

  /// Human explanation for AI-suggested rows, e.g. "You usually buy milk now".
  final String? reason;
  final DateTime createdAt;

  String? get quantityLabel {
    if (quantity == null) return null;
    final q = quantity == quantity!.roundToDouble()
        ? quantity!.toStringAsFixed(0)
        : quantity!.toStringAsFixed(1);
    return unit == null || unit!.isEmpty ? q : '$q $unit';
  }

  ShoppingListItem copyWith({
    String? name,
    Object? quantity = _sentinel,
    Object? unit = _sentinel,
    bool? completed,
    ShoppingSection? section,
    Object? reason = _sentinel,
  }) {
    return ShoppingListItem(
      id: id,
      name: name ?? this.name,
      quantity: quantity == _sentinel ? this.quantity : quantity as double?,
      unit: unit == _sentinel ? this.unit : unit as String?,
      completed: completed ?? this.completed,
      section: section ?? this.section,
      reason: reason == _sentinel ? this.reason : reason as String?,
      createdAt: createdAt,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'quantity': quantity,
        'unit': unit,
        'completed': completed,
        'section': section.name,
        'reason': reason,
        'created_at': createdAt.toIso8601String(),
      };

  factory ShoppingListItem.fromJson(Map<String, dynamic> json) => ShoppingListItem(
        id: json['id'] as String,
        name: json['name'] as String,
        quantity: (json['quantity'] as num?)?.toDouble(),
        unit: json['unit'] as String?,
        completed: json['completed'] as bool? ?? false,
        section: ShoppingSection.values.firstWhere(
          (e) => e.name == json['section'],
          orElse: () => ShoppingSection.need,
        ),
        reason: json['reason'] as String?,
        createdAt: DateTime.parse(json['created_at'] as String),
      );

  static const Object _sentinel = Object();
}
