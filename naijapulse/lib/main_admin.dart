import 'app_bootstrap.dart';
import 'core/app_runtime.dart';
import 'core/routing/app_router.dart';

Future<void> main() async {
  await bootstrapApp(
    variant: AppVariant.admin,
    routerConfig: AppRouter.adminRouter,
    title: 'naijaDNA Admin',
  );
}
