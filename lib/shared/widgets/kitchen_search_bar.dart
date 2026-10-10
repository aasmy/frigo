import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';

class KitchenSearchBar extends StatelessWidget {
  const KitchenSearchBar({
    super.key,
    required this.controller,
    this.hintText = 'Search your kitchen',
    this.onChanged,
    this.autofocus = false,
  });

  final TextEditingController controller;
  final String hintText;
  final ValueChanged<String>? onChanged;
  final bool autofocus;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: controller,
      builder: (context, value, _) {
        return TextField(
          controller: controller,
          autofocus: autofocus,
          onChanged: onChanged,
          textInputAction: TextInputAction.search,
          decoration: InputDecoration(
            hintText: hintText,
            prefixIcon: const Icon(Icons.search, color: AppColors.textTertiary),
            suffixIcon: value.text.isEmpty
                ? null
                : IconButton(
                    icon: const Icon(Icons.close, size: 18),
                    color: AppColors.textTertiary,
                    onPressed: () {
                      controller.clear();
                      onChanged?.call('');
                    },
                  ),
            filled: true,
            fillColor: AppColors.surfaceTint,
            contentPadding:
                const EdgeInsets.symmetric(vertical: AppSpacing.md),
            border: const OutlineInputBorder(
              borderRadius: AppRadii.cardMd,
              borderSide: BorderSide.none,
            ),
            enabledBorder: const OutlineInputBorder(
              borderRadius: AppRadii.cardMd,
              borderSide: BorderSide.none,
            ),
          ),
        );
      },
    );
  }
}
