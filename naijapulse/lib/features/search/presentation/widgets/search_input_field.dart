import 'package:flutter/material.dart';

class SearchInputField extends StatelessWidget {
  const SearchInputField({
    required this.controller,
    required this.onChanged,
    this.onSubmitted,
    this.onClear,
    this.hintText = 'Search news, topics, keywords...',
    this.leadingIcon = Icons.search_rounded,
    this.height = 52,
    this.actionLabel,
    this.onActionTap,
    super.key,
  });

  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final ValueChanged<String>? onSubmitted;
  final VoidCallback? onClear;
  final String hintText;
  final IconData leadingIcon;
  final double height;
  final String? actionLabel;
  final VoidCallback? onActionTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SizedBox(
      height: height,
      child: TextField(
        controller: controller,
        onChanged: onChanged,
        onSubmitted: onSubmitted,
        textInputAction: TextInputAction.search,
        style: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600),
        decoration: InputDecoration(
          hintText: hintText,
          filled: true,
          fillColor: theme.colorScheme.surfaceContainerLow,
          prefixIcon: Icon(leadingIcon, size: 20),
          prefixIconConstraints: const BoxConstraints(minWidth: 42),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 14,
            vertical: 16,
          ),
          suffixIcon: actionLabel != null && onActionTap != null
              ? Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: Center(
                    widthFactor: 1,
                    child: FilledButton(
                      onPressed: onActionTap,
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 10,
                        ),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: Text(actionLabel!),
                    ),
                  ),
                )
              : controller.text.isEmpty
              ? null
              : IconButton(
                  onPressed: onClear,
                  icon: const Icon(Icons.close_rounded, size: 18),
                  visualDensity: VisualDensity.compact,
                  tooltip: 'Clear search',
                ),
        ),
      ),
    );
  }
}
