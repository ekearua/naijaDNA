import 'package:flutter/material.dart';

class CategoryFilterStrip extends StatelessWidget {
  const CategoryFilterStrip({
    required this.categories,
    required this.selectedCategory,
    required this.onSelected,
    this.categoryColors = const {},
    super.key,
  });

  final List<String> categories;
  final String selectedCategory;
  final ValueChanged<String> onSelected;
  final Map<String, Color> categoryColors;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: categories.map((category) {
          final isSelected = category == selectedCategory;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              label: Text(category),
              selected: isSelected,
              onSelected: (_) => onSelected(category),
              showCheckmark: false,
              selectedColor: _selectedChipColor(context, category),
              backgroundColor: Theme.of(
                context,
              ).colorScheme.surfaceContainerHighest,
              side: BorderSide(
                color: isSelected
                    ? _selectedChipColor(context, category)
                    : Theme.of(context).colorScheme.outlineVariant,
              ),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              labelStyle: Theme.of(context).textTheme.titleSmall?.copyWith(
                color: isSelected
                    ? Colors.white
                    : Theme.of(
                        context,
                      ).colorScheme.onSurface.withValues(alpha: 0.92),
                fontWeight: FontWeight.w700,
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Color _selectedChipColor(BuildContext context, String category) {
    final normalized = _normalizeKey(category);
    if (categoryColors.containsKey(normalized)) {
      return categoryColors[normalized]!;
    }
    if (category == 'Breaking' || category == 'Breaking News') {
      return const Color(0xFFC63D35);
    }
    return Theme.of(context).colorScheme.primary;
  }

  String _normalizeKey(String value) {
    var normalized = value.trim().toLowerCase().replaceAll(' ', '-');
    if (normalized == 'breaking') {
      normalized = 'breaking-news';
    }
    if (normalized == 'tech') {
      normalized = 'technology';
    }
    return normalized;
  }
}
