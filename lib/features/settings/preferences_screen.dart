import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/user_preferences.dart';
import '../../core/repositories/preferences_repository.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';

class PreferencesScreen extends ConsumerWidget {
  const PreferencesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final prefs = ref.watch(preferencesProvider);
    final notifier = ref.read(preferencesProvider.notifier);
    final text = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Preferences')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          children: [
            Text('These shape the recipes we suggest.', style: text.bodyMedium),
            const SizedBox(height: AppSpacing.xl),
            Text('Diet', style: text.titleSmall),
            const SizedBox(height: AppSpacing.sm),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: [
                for (final d in DietPreference.values)
                  ChoiceChip(
                    label: Text(d.label),
                    selected: prefs.diet == d,
                    onSelected: (_) =>
                        notifier.update((p) => p.copyWith(diet: d)),
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.xl),
            Text('Cooking time', style: text.titleSmall),
            const SizedBox(height: AppSpacing.sm),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: [
                for (final t in MaxCookingTime.values)
                  ChoiceChip(
                    label: Text(t.label),
                    selected: prefs.maxCookingTime == t,
                    onSelected: (_) =>
                        notifier.update((p) => p.copyWith(maxCookingTime: t)),
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.xl),
            Text('Avoid these ingredients', style: text.titleSmall),
            const SizedBox(height: AppSpacing.sm),
            _ExcludedEditor(
              values: prefs.excludedIngredients,
              onChanged: (list) =>
                  notifier.update((p) => p.copyWith(excludedIngredients: list)),
            ),

          ],
        ),
      ),
    );
  }
}

class _ExcludedEditor extends StatefulWidget {
  const _ExcludedEditor({required this.values, required this.onChanged});
  final List<String> values;
  final ValueChanged<List<String>> onChanged;

  @override
  State<_ExcludedEditor> createState() => _ExcludedEditorState();
}

class _ExcludedEditorState extends State<_ExcludedEditor> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _add() {
    final v = _controller.text.trim();
    if (v.isEmpty || widget.values.contains(v)) return;
    widget.onChanged([...widget.values, v]);
    _controller.clear();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (widget.values.isNotEmpty)
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              for (final v in widget.values)
                InputChip(
                  label: Text(v),
                  onDeleted: () => widget.onChanged(
                    widget.values.where((e) => e != v).toList(),
                  ),
                ),
            ],
          ),
        const SizedBox(height: AppSpacing.sm),
        TextField(
          controller: _controller,
          onSubmitted: (_) => _add(),
          decoration: InputDecoration(
            hintText: 'e.g. peanuts, shellfish',
            fillColor: AppColors.surfaceTint,
            suffixIcon: TextButton(onPressed: _add, child: const Text('Add')),
          ),
        ),
      ],
    );
  }
}
