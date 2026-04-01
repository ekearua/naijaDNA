import 'package:flutter/material.dart';
import 'package:naijapulse/core/theme/theme.dart';

class AuthFormCard extends StatelessWidget {
  const AuthFormCard({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 22),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface.withValues(
          alpha: theme.brightness == Brightness.dark ? 0.92 : 0.98,
        ),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(
          color: theme.dividerColor.withValues(
            alpha: theme.brightness == Brightness.dark ? 0.9 : 0.42,
          ),
        ),
        boxShadow: AppTheme.ambientShadow(theme.brightness),
      ),
      child: child,
    );
  }
}
