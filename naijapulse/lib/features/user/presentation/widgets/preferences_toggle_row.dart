import 'package:flutter/material.dart';
import 'package:naijapulse/core/theme/theme.dart';

class PreferencesToggleRow extends StatelessWidget {
  const PreferencesToggleRow({
    required this.title,
    required this.value,
    required this.onChanged,
    this.subtitle,
    this.leading,
    this.enabled = true,
    this.activeTrackColor,
    this.showDivider = true,
    super.key,
  });

  final String title;
  final String? subtitle;
  final Widget? leading;
  final bool enabled;
  final bool value;
  final ValueChanged<bool> onChanged;
  final Color? activeTrackColor;
  final bool showDivider;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        border: showDivider
            ? Border(bottom: BorderSide(color: Theme.of(context).dividerColor))
            : null,
      ),
      padding: const EdgeInsets.fromLTRB(16, 10, 10, 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (leading != null) ...[leading!, const SizedBox(width: 12)],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: Theme.of(context).colorScheme.onSurface.withValues(
                      alpha: enabled ? 1 : 0.58,
                    ),
                  ),
                ),
                if (subtitle != null && subtitle!.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      subtitle!,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurface
                            .withValues(alpha: enabled ? 0.78 : 0.5),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          Switch.adaptive(
            value: value,
            onChanged: enabled ? onChanged : null,
            activeTrackColor: activeTrackColor ?? AppTheme.primary,
            activeThumbColor: Colors.white,
            inactiveThumbColor: Colors.white,
            inactiveTrackColor: Theme.of(context).colorScheme.surfaceContainer,
            trackOutlineColor: const WidgetStatePropertyAll(Colors.transparent),
          ),
        ],
      ),
    );
  }
}
