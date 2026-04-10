import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:naijapulse/core/theme/theme.dart';

enum AppIconSize { xSmall, small, medium, large }

enum AppIconTone { primary, secondary, muted, inverse, accent, danger }

enum AppIconButtonStyle { neutral, glass, tonal, contrast }

class AppInteractionTokens {
  static const double compactTapTarget = 40;
  static const double standardTapTarget = 44;

  static const double radiusSmall = 12;
  static const double radiusMedium = 14;
  static const double radiusLarge = 18;
  static const double radiusPill = 999;

  static const EdgeInsets chipPadding = EdgeInsets.symmetric(
    horizontal: 14,
    vertical: 10,
  );
  static const EdgeInsets compactChipPadding = EdgeInsets.symmetric(
    horizontal: 12,
    vertical: 8,
  );

  static const EdgeInsets inlineActionPadding = EdgeInsets.symmetric(
    horizontal: 10,
    vertical: 8,
  );

  static double iconSize(AppIconSize size) {
    switch (size) {
      case AppIconSize.xSmall:
        return 16;
      case AppIconSize.small:
        return 18;
      case AppIconSize.medium:
        return 20;
      case AppIconSize.large:
        return 24;
    }
  }
}

class AppIcon extends StatelessWidget {
  const AppIcon(
    this.icon, {
    this.size = AppIconSize.medium,
    this.tone = AppIconTone.primary,
    this.color,
    super.key,
  });

  final IconData icon;
  final AppIconSize size;
  final AppIconTone tone;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Icon(
      icon,
      size: AppInteractionTokens.iconSize(size),
      color: color ?? _resolveTone(theme, tone),
    );
  }

  static Color resolveColor(BuildContext context, AppIconTone tone) {
    return _resolveTone(Theme.of(context), tone);
  }

  static Color _resolveTone(ThemeData theme, AppIconTone tone) {
    final isDark = theme.brightness == Brightness.dark;
    switch (tone) {
      case AppIconTone.primary:
        return theme.colorScheme.onSurface;
      case AppIconTone.secondary:
        return isDark ? AppTheme.darkTextSecondary : AppTheme.textSecondary;
      case AppIconTone.muted:
        return theme.colorScheme.outline;
      case AppIconTone.inverse:
        return Colors.white;
      case AppIconTone.accent:
        return AppTheme.primary;
      case AppIconTone.danger:
        return theme.colorScheme.error;
    }
  }
}

class AppBadge extends StatelessWidget {
  const AppBadge({required this.count, this.inverseBorder = false, super.key});

  final int count;
  final bool inverseBorder;

  @override
  Widget build(BuildContext context) {
    if (count <= 0) {
      return const SizedBox.shrink();
    }

    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      constraints: const BoxConstraints(minWidth: 18),
      decoration: BoxDecoration(
        color: theme.colorScheme.error,
        borderRadius: BorderRadius.circular(AppInteractionTokens.radiusPill),
        border: Border.all(
          color: inverseBorder
              ? Colors.white.withValues(alpha: 0.92)
              : theme.colorScheme.surface,
        ),
      ),
      child: Text(
        count > 99 ? '99+' : '$count',
        textAlign: TextAlign.center,
        style: theme.textTheme.labelSmall?.copyWith(
          color: theme.colorScheme.onError,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class AppIconButton extends StatelessWidget {
  const AppIconButton({
    required this.icon,
    required this.onPressed,
    this.selected = false,
    this.selectedIcon,
    this.tooltip,
    this.semanticLabel,
    this.style = AppIconButtonStyle.neutral,
    this.compact = true,
    this.iconSize = AppIconSize.small,
    this.badgeCount = 0,
    this.enableHaptics = false,
    super.key,
  });

  final IconData icon;
  final IconData? selectedIcon;
  final VoidCallback? onPressed;
  final bool selected;
  final String? tooltip;
  final String? semanticLabel;
  final AppIconButtonStyle style;
  final bool compact;
  final AppIconSize iconSize;
  final int badgeCount;
  final bool enableHaptics;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final colors = _resolveButtonColors(theme, style, selected);
    final dimension = compact
        ? AppInteractionTokens.compactTapTarget
        : AppInteractionTokens.standardTapTarget;

    Widget child = Stack(
      clipBehavior: Clip.none,
      children: [
        Material(
          color: colors.background,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(
              AppInteractionTokens.radiusSmall,
            ),
            side: BorderSide(color: colors.border),
          ),
          child: InkWell(
            onTap: onPressed == null
                ? null
                : () {
                    _maybeHaptic(enableHaptics);
                    onPressed?.call();
                  },
            borderRadius: BorderRadius.circular(
              AppInteractionTokens.radiusSmall,
            ),
            overlayColor: WidgetStateProperty.resolveWith((states) {
              if (states.contains(WidgetState.pressed)) {
                return colors.foreground.withValues(alpha: 0.12);
              }
              if (states.contains(WidgetState.hovered)) {
                return colors.foreground.withValues(alpha: 0.06);
              }
              if (states.contains(WidgetState.focused)) {
                return colors.foreground.withValues(alpha: 0.08);
              }
              return null;
            }),
            child: SizedBox(
              width: dimension,
              height: dimension,
              child: Center(
                child: AppIcon(
                  selected ? (selectedIcon ?? icon) : icon,
                  size: iconSize,
                  color: onPressed == null
                      ? colors.foreground.withValues(alpha: 0.45)
                      : colors.foreground,
                ),
              ),
            ),
          ),
        ),
        if (badgeCount > 0)
          Positioned(
            right: -2,
            top: -4,
            child: AppBadge(
              count: badgeCount,
              inverseBorder: style == AppIconButtonStyle.glass || isDark,
            ),
          ),
      ],
    );

    final label = semanticLabel ?? tooltip;
    if (label != null && label.isNotEmpty) {
      child = Semantics(button: true, label: label, child: child);
    }
    if (tooltip != null && tooltip!.isNotEmpty) {
      child = Tooltip(message: tooltip!, child: child);
    }
    return child;
  }

  _ButtonColors _resolveButtonColors(
    ThemeData theme,
    AppIconButtonStyle style,
    bool selected,
  ) {
    final isDark = theme.brightness == Brightness.dark;
    switch (style) {
      case AppIconButtonStyle.glass:
        return _ButtonColors(
          background: isDark
              ? Colors.white.withValues(alpha: 0.16)
              : Colors.white.withValues(alpha: 0.9),
          border: isDark
              ? Colors.white.withValues(alpha: 0.12)
              : AppTheme.textPrimary.withValues(alpha: 0.08),
          foreground: isDark ? Colors.white : AppTheme.textPrimary,
        );
      case AppIconButtonStyle.tonal:
        return _ButtonColors(
          background: selected
              ? AppTheme.primary.withValues(alpha: 0.18)
              : theme.colorScheme.surfaceContainerLow,
          border: selected
              ? AppTheme.primary.withValues(alpha: 0.32)
              : theme.dividerColor.withValues(alpha: 0.16),
          foreground: selected ? AppTheme.primary : theme.colorScheme.onSurface,
        );
      case AppIconButtonStyle.contrast:
        return _ButtonColors(
          background: Colors.black.withValues(alpha: 0.18),
          border: Colors.white.withValues(alpha: 0.1),
          foreground: Colors.white,
        );
      case AppIconButtonStyle.neutral:
        return _ButtonColors(
          background: theme.colorScheme.surface,
          border: theme.dividerColor.withValues(alpha: 0.18),
          foreground: selected ? AppTheme.primary : theme.colorScheme.onSurface,
        );
    }
  }
}

class AppActionChip extends StatelessWidget {
  const AppActionChip({
    required this.label,
    this.onTap,
    this.selected = false,
    this.icon,
    this.tooltip,
    this.selectedColor,
    this.selectedForegroundColor,
    this.compact = false,
    this.inverse = false,
    this.enableHaptics = false,
    this.textMaxLines,
    this.textOverflow = TextOverflow.ellipsis,
    this.textSoftWrap = false,
    super.key,
  });

  final String label;
  final VoidCallback? onTap;
  final bool selected;
  final IconData? icon;
  final String? tooltip;
  final Color? selectedColor;
  final Color? selectedForegroundColor;
  final bool compact;
  final bool inverse;
  final bool enableHaptics;
  final int? textMaxLines;
  final TextOverflow textOverflow;
  final bool textSoftWrap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final baseBackground = inverse
        ? Colors.white.withValues(alpha: 0.14)
        : theme.colorScheme.surfaceContainerLow;
    final baseBorder = inverse
        ? Colors.white.withValues(alpha: 0.18)
        : theme.dividerColor.withValues(alpha: 0.18);
    final activeBackground =
        selectedColor ??
        (inverse ? Colors.white : AppTheme.primary.withValues(alpha: 0.12));
    final activeForeground =
        selectedForegroundColor ??
        (inverse ? AppTheme.textPrimary : AppTheme.primary);
    final foreground = selected
        ? activeForeground
        : inverse
        ? Colors.white
        : theme.colorScheme.onSurface;

    Widget child = Material(
      color: selected ? activeBackground : baseBackground,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppInteractionTokens.radiusMedium),
        side: BorderSide(
          color: selected
              ? (selectedColor ?? AppTheme.primary).withValues(
                  alpha: inverse ? 0.16 : 0.28,
                )
              : baseBorder,
        ),
      ),
      child: InkWell(
        onTap: onTap == null
            ? null
            : () {
                _maybeHaptic(enableHaptics);
                onTap?.call();
              },
        borderRadius: BorderRadius.circular(AppInteractionTokens.radiusMedium),
        overlayColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.pressed)) {
            return foreground.withValues(alpha: 0.12);
          }
          if (states.contains(WidgetState.hovered)) {
            return foreground.withValues(alpha: 0.06);
          }
          return null;
        }),
        child: Padding(
          padding: compact
              ? AppInteractionTokens.compactChipPadding
              : AppInteractionTokens.chipPadding,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                AppIcon(
                  icon!,
                  size: compact ? AppIconSize.xSmall : AppIconSize.small,
                  color: foreground,
                ),
                const SizedBox(width: 8),
              ],
              Text(
                label,
                maxLines: textMaxLines,
                overflow: textOverflow,
                softWrap: textSoftWrap,
                style: theme.textTheme.labelLarge?.copyWith(
                  color: foreground,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );

    final semanticsLabel = tooltip ?? label;
    child = Semantics(
      button: onTap != null,
      selected: selected,
      label: semanticsLabel,
      child: child,
    );
    if (tooltip != null && tooltip!.isNotEmpty) {
      child = Tooltip(message: tooltip!, child: child);
    }
    return child;
  }
}

class AppInlineAction extends StatelessWidget {
  const AppInlineAction({
    required this.icon,
    required this.label,
    this.onTap,
    this.tooltip,
    this.tone = AppIconTone.secondary,
    this.compact = false,
    this.enableHaptics = false,
    super.key,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final String? tooltip;
  final AppIconTone tone;
  final bool compact;
  final bool enableHaptics;

  @override
  Widget build(BuildContext context) {
    final color = AppIcon.resolveColor(context, tone);
    final textStyle = Theme.of(context).textTheme.bodySmall?.copyWith(
      color: onTap == null ? color.withValues(alpha: 0.58) : color,
      fontWeight: FontWeight.w600,
    );

    Widget child = Material(
      color: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppInteractionTokens.radiusPill),
      ),
      child: InkWell(
        onTap: onTap == null
            ? null
            : () {
                _maybeHaptic(enableHaptics);
                onTap?.call();
              },
        borderRadius: BorderRadius.circular(AppInteractionTokens.radiusPill),
        overlayColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.pressed)) {
            return color.withValues(alpha: 0.1);
          }
          if (states.contains(WidgetState.hovered)) {
            return color.withValues(alpha: 0.05);
          }
          return null;
        }),
        child: Padding(
          padding: compact
              ? const EdgeInsets.symmetric(horizontal: 8, vertical: 6)
              : AppInteractionTokens.inlineActionPadding,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              AppIcon(
                icon,
                size: compact ? AppIconSize.xSmall : AppIconSize.small,
                color: onTap == null ? color.withValues(alpha: 0.58) : color,
              ),
              const SizedBox(width: 6),
              Text(label, style: textStyle),
            ],
          ),
        ),
      ),
    );

    final semanticsLabel = tooltip ?? label;
    child = Semantics(
      button: onTap != null,
      label: semanticsLabel,
      child: child,
    );
    if (tooltip != null && tooltip!.isNotEmpty) {
      child = Tooltip(message: tooltip!, child: child);
    }
    return child;
  }
}

class _ButtonColors {
  const _ButtonColors({
    required this.background,
    required this.border,
    required this.foreground,
  });

  final Color background;
  final Color border;
  final Color foreground;
}

void _maybeHaptic(bool enabled) {
  if (!enabled || kIsWeb) {
    return;
  }
  HapticFeedback.selectionClick();
}
