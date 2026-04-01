import 'package:flutter/material.dart';
import 'package:naijapulse/core/theme/app_theme_controller.dart';

class AppThemeScope extends InheritedNotifier<AppThemeController> {
  const AppThemeScope({
    required AppThemeController controller,
    required super.child,
    super.key,
  }) : super(notifier: controller);

  static AppThemeController of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<AppThemeScope>();
    assert(scope != null, 'AppThemeScope is not found in widget tree.');
    final controller = scope?.notifier;
    assert(controller != null, 'AppThemeController is not available.');
    return controller!;
  }
}
