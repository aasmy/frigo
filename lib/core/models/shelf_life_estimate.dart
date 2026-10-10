enum EstimateConfidence { low, medium, high }

/// Result of AI Task C — a shelf-life estimate. Always framed as an estimate,
/// never a food-safety guarantee.
class ShelfLifeEstimate {
  const ShelfLifeEstimate({
    required this.estimatedDays,
    required this.confidence,
    this.notes = '',
  });

  final int estimatedDays;
  final EstimateConfidence confidence;
  final String notes;

  Map<String, dynamic> toJson() => {
        'estimated_days': estimatedDays,
        'confidence': confidence.name,
        'notes': notes,
      };

  factory ShelfLifeEstimate.fromJson(Map<String, dynamic> json) => ShelfLifeEstimate(
        estimatedDays: (json['estimated_days'] as num?)?.toInt() ?? 7,
        confidence: EstimateConfidence.values.firstWhere(
          (e) => e.name == json['confidence'],
          orElse: () => EstimateConfidence.medium,
        ),
        notes: json['notes'] as String? ?? '',
      );
}
