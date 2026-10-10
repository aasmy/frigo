import 'package:flutter/material.dart';

import '../../core/models/enums.dart';
import '../../core/models/inventory_item.dart';
import '../../core/theme/app_spacing.dart';

/// Small dot used inside tiles to hint at freshness without shouting.
class StatusDot extends StatelessWidget {
  const StatusDot(this.status, {super.key, this.size = 8});
  final FreshnessStatus status;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: size,
      width: size,
      decoration: BoxDecoration(color: status.color, shape: BoxShape.circle),
    );
  }
}

/// Soft freshness pill. Pass an [item] to get "3 days left" phrasing, or a
/// bare [status] for the generic label.
class ExpirationBadge extends StatelessWidget {
  const ExpirationBadge({
    super.key,
    this.item,
    this.status,
    this.label,
    this.dense = false,
  }) : assert(item != null || status != null);

  final InventoryItem? item;
  final FreshnessStatus? status;
  final String? label;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final s = item?.status ?? status!;
    final txt = label ?? item?.daysLeftLabel ?? s.label;
    final style = Theme.of(context).textTheme.labelSmall?.copyWith(
          color: s.color,
          fontWeight: FontWeight.w700,
        );
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: dense ? AppSpacing.sm : 10,
        vertical: dense ? 4 : 5,
      ),
      decoration: BoxDecoration(
        color: s.softColor,
        borderRadius: AppRadii.pillAll,
      ),
      child: Text(txt, style: style),
    );
  }
}
