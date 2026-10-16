import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Single-select chips with a field label — used for short option lists.
class ChipSelector extends StatelessWidget {
  final String label;
  final IconData? icon;
  final List<String> options;
  final String? value;
  final ValueChanged<String?> onChanged;

  const ChipSelector({
    super.key,
    required this.label,
    required this.options,
    required this.value,
    required this.onChanged,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            if (icon != null) ...[
              Icon(icon, size: 18, color: AppColors.primary),
              const SizedBox(width: 6),
            ],
            Text(
              label,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.textMuted,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children:
              options.map((option) {
                final selected = option == value;
                return ChoiceChip(
                  label: Text(option),
                  selected: selected,
                  showCheckmark: false,
                  onSelected: (_) => onChanged(selected ? null : option),
                  labelStyle: TextStyle(
                    color: selected ? Colors.white : AppColors.textPrimary,
                    fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
                  ),
                  selectedColor: AppColors.primary,
                  backgroundColor: AppColors.fieldFill,
                  side: BorderSide(
                    color: selected ? AppColors.primary : AppColors.border,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                );
              }).toList(),
        ),
      ],
    );
  }
}

/// Dropdown with the app's field styling — used for longer option lists.
class AppDropdown extends StatelessWidget {
  final String label;
  final IconData? icon;
  final List<String> options;
  final String? value;
  final ValueChanged<String?> onChanged;

  const AppDropdown({
    super.key,
    required this.label,
    required this.options,
    required this.value,
    required this.onChanged,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final current = options.contains(value) ? value : null;
    return DropdownButtonFormField<String>(
      // Keyed on the value so a programmatic reset re-initialises the field.
      key: ValueKey('$label:$current'),
      initialValue: current,
      isExpanded: true,
      borderRadius: BorderRadius.circular(14),
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: icon == null ? null : Icon(icon),
      ),
      items:
          options
              .map((o) => DropdownMenuItem<String>(value: o, child: Text(o)))
              .toList(),
      onChanged: onChanged,
    );
  }
}
