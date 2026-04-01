import 'package:flutter/material.dart';

class AppSearchBar extends StatelessWidget {
  const AppSearchBar({
    this.hintText = 'Search news, topics, keywords...',
    this.leadingIcon = Icons.search_rounded,
    this.height = 56,
    this.onTap,
    super.key,
  });

  final String hintText;
  final IconData leadingIcon;
  final double height;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final onSurface = theme.colorScheme.onSurface;
    final isDark = theme.brightness == Brightness.dark;
    final hintColor = onSurface.withValues(alpha: isDark ? 0.82 : 0.72);
    final iconColor = onSurface.withValues(alpha: isDark ? 0.88 : 0.76);

    final searchField = Container(
      height: height,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: theme.colorScheme.surface.withValues(alpha: isDark ? 0.9 : 0.94),
        border: Border.all(
          color: theme.dividerColor.withValues(alpha: isDark ? 0.9 : 0.55),
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(
        children: [
          Icon(leadingIcon, size: 22, color: iconColor),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              hintText,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: hintColor,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );

    if (onTap == null) {
      return searchField;
    }

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: searchField,
    );
  }
}
