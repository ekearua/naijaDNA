import 'app_bootstrap.dart';
import 'core/app_runtime.dart';
import 'core/routing/app_router.dart';

Future<void> main() async {
  final initialPath = Uri.base.path;
  final isClientRecoveryPath =
      initialPath == AppRouter.clientRecoveryForgotPasswordPath ||
      initialPath == AppRouter.clientRecoveryResetPasswordPath ||
      initialPath == AppRouter.forgotPasswordPath ||
      initialPath == AppRouter.resetPasswordPath;
  await bootstrapApp(
    variant: AppVariant.admin,
    routerConfig: isClientRecoveryPath
        ? AppRouter.clientRouterForUri(Uri.base)
        : AppRouter.adminRouterForUri(Uri.base),
    title: isClientRecoveryPath ? 'naijaDNA Recovery' : 'naijaDNA Admin',
  );
}
