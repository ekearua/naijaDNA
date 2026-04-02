enum AppVariant { client, admin }

class AppRuntime {
  AppRuntime._();

  static AppVariant _variant = AppVariant.client;

  static void configure(AppVariant variant) {
    _variant = variant;
  }

  static AppVariant get variant => _variant;

  static bool get isAdminBuild => _variant == AppVariant.admin;

  static bool get supportsAdminRoutes => isAdminBuild;
}
