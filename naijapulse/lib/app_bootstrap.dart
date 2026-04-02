import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_web_plugins/url_strategy.dart';

import 'core/app_runtime.dart';
import 'core/di/injection_container.dart';
import 'core/theme/app_theme_controller.dart';
import 'core/theme/app_theme_scope.dart';
import 'core/theme/theme.dart';

Future<void> bootstrapApp({
  required AppVariant variant,
  required RouterConfig<Object> routerConfig,
  required String title,
}) async {
  WidgetsFlutterBinding.ensureInitialized();
  if (kIsWeb) {
    usePathUrlStrategy();
  }

  AppRuntime.configure(variant);
  await InjectionContainer.init();
  runApp(_NaijaDNAApp(title: title, routerConfig: routerConfig));
}

class _NaijaDNAApp extends StatefulWidget {
  const _NaijaDNAApp({required this.title, required this.routerConfig});

  final String title;
  final RouterConfig<Object> routerConfig;

  @override
  State<_NaijaDNAApp> createState() => _NaijaDNAAppState();
}

class _NaijaDNAAppState extends State<_NaijaDNAApp> {
  late final AppThemeController _themeController;

  @override
  void initState() {
    super.initState();
    _themeController = AppThemeController();
  }

  @override
  void dispose() {
    _themeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AppThemeScope(
      controller: _themeController,
      child: AnimatedBuilder(
        animation: _themeController,
        builder: (context, _) {
          return MaterialApp.router(
            title: widget.title,
            debugShowCheckedModeBanner: false,
            theme: AppTheme.light,
            darkTheme: AppTheme.dark,
            themeMode: _themeController.themeMode,
            routerConfig: widget.routerConfig,
            builder: (context, child) {
              final mediaQuery = MediaQuery.of(context);
              return MediaQuery(
                data: mediaQuery.copyWith(
                  textScaler: TextScaler.linear(
                    _themeController.textScaleFactor,
                  ),
                ),
                child: child ?? const SizedBox.shrink(),
              );
            },
          );
        },
      ),
    );
  }
}
