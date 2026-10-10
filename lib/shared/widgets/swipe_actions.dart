import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';

import '../../core/theme/app_colors.dart';

/// Wraps a list row so a left-swipe reveals Edit (blue) and Delete (red).
class SwipeActions extends StatelessWidget {
  const SwipeActions({
    super.key,
    required this.child,
    required this.onEdit,
    required this.onDelete,
    this.groupTag = 'kitchen',
  });

  final Widget child;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final Object groupTag;

  @override
  Widget build(BuildContext context) {
    return Slidable(
      groupTag: groupTag,
      endActionPane: ActionPane(
        motion: const DrawerMotion(),
        extentRatio: 0.5,
        children: [
          SlidableAction(
            onPressed: (_) => onEdit(),
            backgroundColor: AppColors.primary,
            foregroundColor: AppColors.onPrimary,
            icon: Icons.edit_outlined,
            label: 'Edit',
          ),
          SlidableAction(
            onPressed: (_) => onDelete(),
            backgroundColor: AppColors.expired,
            foregroundColor: Colors.white,
            icon: Icons.delete_outline,
            label: 'Delete',
          ),
        ],
      ),
      child: child,
    );
  }
}
