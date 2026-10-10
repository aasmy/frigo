import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';

/// A unit picker: a dropdown of the common grocery units plus a "Custom…" entry
/// that reveals a free-text field. Value is always a plain [String].
class UnitField extends StatefulWidget {
  const UnitField({
    super.key,
    required this.value,
    required this.onChanged,
    this.label = 'Unit',
  });

  final String value;
  final ValueChanged<String> onChanged;
  final String label;

  static const common = <String>[
    'piece', 'g', 'kg', 'mL', 'L', 'oz', 'lb', 'dozen', 'bunch', 'bag', 'box',
    'can', 'jar', 'bottle', 'carton', 'pack', 'package', 'loaf', 'bulb', 'head',
    'block', 'tub', 'stick', 'clove', 'slice', 'cup',
  ];

  @override
  State<UnitField> createState() => _UnitFieldState();
}

class _UnitFieldState extends State<UnitField> {
  static const _customKey = '__custom__';
  late final TextEditingController _custom;
  late bool _isCustom;

  @override
  void initState() {
    super.initState();
    _isCustom = !UnitField.common.contains(widget.value) &&
        widget.value.trim().isNotEmpty;
    _custom = TextEditingController(text: _isCustom ? widget.value : '');
  }

  @override
  void didUpdateWidget(UnitField old) {
    super.didUpdateWidget(old);
    if (widget.value != old.value &&
        !UnitField.common.contains(widget.value) &&
        widget.value != _custom.text) {
      _isCustom = widget.value.trim().isNotEmpty;
      _custom.text = _isCustom ? widget.value : '';
    }
  }

  @override
  void dispose() {
    _custom.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dropdownValue = _isCustom
        ? _customKey
        : (UnitField.common.contains(widget.value) ? widget.value : _customKey);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        DropdownButtonFormField<String>(
          initialValue: dropdownValue,
          isExpanded: true,
          decoration: InputDecoration(labelText: widget.label),
          borderRadius: AppRadii.cardMd,
          items: [
            for (final u in UnitField.common)
              DropdownMenuItem(value: u, child: Text(u)),
            const DropdownMenuItem(
              value: _customKey,
              child: Text('Custom…', style: TextStyle(color: AppColors.primary)),
            ),
          ],
          onChanged: (v) {
            if (v == null) return;
            if (v == _customKey) {
              setState(() => _isCustom = true);
              WidgetsBinding.instance.addPostFrameCallback(
                  (_) => FocusScope.of(context).requestFocus(_customFocus));
            } else {
              setState(() => _isCustom = false);
              widget.onChanged(v);
            }
          },
        ),
        if (_isCustom) ...[
          const SizedBox(height: AppSpacing.sm),
          TextField(
            controller: _custom,
            focusNode: _customFocus,
            textCapitalization: TextCapitalization.none,
            decoration: const InputDecoration(
              labelText: 'Custom unit',
              hintText: 'e.g. sachet, tray, punnet',
            ),
            onChanged: (v) => widget.onChanged(v.trim()),
          ),
        ],
      ],
    );
  }

  final _customFocus = FocusNode();
}
