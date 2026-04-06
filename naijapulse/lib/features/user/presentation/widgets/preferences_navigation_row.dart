import 'package:flutter/material.dart';
import 'package:naijapulse/core/widgets/app_interactions.dart';

class PreferencesNavigationRow extends StatelessWidget {
  const PreferencesNavigationRow({
    required this.title,
    this.valueLabel,
    this.leadingIcon,
    this.badgeCount = 0,
    this.selected = false,
    this.showDivider = true,
    this.onTap,
    super.key,
  });

  final String title;
  final String? valueLabel;
  final IconData? leadingIcon;
  final int badgeCount;
  final bool selected;
  final bool showDivider;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final activeTint = theme.colorScheme.primary;

    return Material(
      color: selected
          ? theme.colorScheme.surfaceContainerLow
          : Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            border: showDivider
                ? Border(bottom: BorderSide(color: theme.dividerColor))
                : null,
          ),
          padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
          child: Row(
            children: [
              if (leadingIcon != null) ...[
                AppIcon(
                  leadingIcon!,
                  size: AppIconSize.small,
                  tone: selected ? AppIconTone.accent : AppIconTone.secondary,
                ),
                const SizedBox(width: 12),
              ],
              Expanded(
                child: Text(
                  title,
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: selected ? activeTint : theme.colorScheme.onSurface,
                  ),
                ),
              ),
              if (badgeCount > 0) ...[
                AppBadge(count: badgeCount),
                const SizedBox(width: 10),
              ],
              if (valueLabel != null && valueLabel!.isNotEmpty) ...[
                Text(
                  valueLabel!,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: selected
                        ? activeTint
                        : theme.colorScheme.onSurface.withValues(alpha: 0.78),
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  ),
                ),
                const SizedBox(width: 6),
              ],
              AppIcon(
                Icons.chevron_right_rounded,
                size: AppIconSize.small,
                tone: selected ? AppIconTone.accent : AppIconTone.muted,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
