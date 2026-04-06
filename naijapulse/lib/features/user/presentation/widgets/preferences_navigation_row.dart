import 'package:flutter/material.dart';
import 'package:naijapulse/core/widgets/app_interactions.dart';

class PreferencesNavigationRow extends StatelessWidget {
  const PreferencesNavigationRow({
    required this.title,
    this.valueLabel,
    this.leadingIcon,
    this.showDivider = true,
    this.onTap,
    super.key,
  });

  final String title;
  final String? valueLabel;
  final IconData? leadingIcon;
  final bool showDivider;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          border: showDivider
              ? Border(
                  bottom: BorderSide(color: Theme.of(context).dividerColor),
                )
              : null,
        ),
        padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
        child: Row(
          children: [
            if (leadingIcon != null) ...[
              AppIcon(
                leadingIcon!,
                size: AppIconSize.small,
                tone: AppIconTone.secondary,
              ),
              const SizedBox(width: 12),
            ],
            Text(
              title,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
            const Spacer(),
            if (valueLabel != null && valueLabel!.isNotEmpty) ...[
              Text(
                valueLabel!,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: Theme.of(
                    context,
                  ).colorScheme.onSurface.withValues(alpha: 0.78),
                ),
              ),
              const SizedBox(width: 6),
            ],
            const AppIcon(
              Icons.chevron_right_rounded,
              size: AppIconSize.small,
              tone: AppIconTone.muted,
            ),
          ],
        ),
      ),
    );
  }
}
