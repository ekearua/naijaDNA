import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:naijapulse/core/routing/app_router.dart';
import 'package:naijapulse/core/theme/theme.dart';
import 'package:naijapulse/features/auth/presentation/bloc/auth_bloc.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;

  @override
  void initState() {
    super.initState();
    context.read<AuthBloc>().add(const AuthSessionCheckedRequested());
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: BlocConsumer<AuthBloc, AuthState>(
        listenWhen: (previous, current) =>
            previous.status != current.status ||
            previous.errorMessage != current.errorMessage,
        listener: (context, state) {
          if (state.status == AuthStatus.authenticated) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Welcome back ${state.session?.displayName}!'),
              ),
            );
            context.go(AppRouter.profilePath);
            return;
          }
          if (state.status == AuthStatus.failure &&
              state.errorMessage != null &&
              state.errorMessage!.trim().isNotEmpty) {
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(SnackBar(content: Text(state.errorMessage!)));
          }
        },
        builder: (context, state) {
          final isLoading = state.status == AuthStatus.loading;
          final isDark = Theme.of(context).brightness == Brightness.dark;
          return DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: isDark
                    ? const [AppTheme.darkBg, AppTheme.darkBgSoft]
                    : const [Color(0xFFF5F0E6), Color(0xFFEEE7DA)],
              ),
            ),
            child: SafeArea(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final isWide = constraints.maxWidth >= 940;
                  return Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 1180),
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: isWide
                            ? Row(
                                children: [
                                  Expanded(
                                    child: _AuthEditorialPanel(
                                      eyebrow: 'The Digital Curator',
                                      title:
                                          'The stories shaping Nigeria, with context.',
                                      description:
                                          'Track breaking coverage, join live conversations, save essential reads, and keep your news feed grounded in topics that matter to you.',
                                      bullets: const [
                                        'Save important reads for later.',
                                        'Join live streams and discussion threads.',
                                        'Personalize your feed across devices.',
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 28),
                                  Expanded(
                                    child: _buildFormCard(
                                      context,
                                      isLoading: isLoading,
                                    ),
                                  ),
                                ],
                              )
                            : ListView(
                                children: [
                                  _buildTopActions(context),
                                  const SizedBox(height: 20),
                                  _AuthEditorialPanel(
                                    eyebrow: 'The Digital Curator',
                                    title:
                                        'The stories shaping Nigeria, with context.',
                                    description:
                                        'Track breaking coverage, join live conversations, save essential reads, and keep your feed aligned with what matters most to you.',
                                    bullets: const [
                                      'Save important reads for later.',
                                      'Join live streams and discussion threads.',
                                      'Personalize your feed across devices.',
                                    ],
                                    compact: true,
                                  ),
                                  const SizedBox(height: 20),
                                  _buildFormCard(context, isLoading: isLoading),
                                ],
                              ),
                      ),
                    ),
                  );
                },
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildFormCard(BuildContext context, {required bool isLoading}) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(32),
        border: Border.all(color: AppTheme.divider.withValues(alpha: 0.8)),
        boxShadow: AppTheme.ambientShadow(theme.brightness),
      ),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (MediaQuery.sizeOf(context).width >= 940)
              _buildTopActions(context),
            if (MediaQuery.sizeOf(context).width >= 940)
              const SizedBox(height: 18),
            Text(
              'Sign in',
              style: theme.textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.w900,
                fontFamily: AppTheme.headlineFontFamily,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'Access your saved stories, live discussions, and personalized briefings.',
              style: theme.textTheme.bodyLarge?.copyWith(
                color: AppTheme.textSecondary,
              ),
            ),
            const SizedBox(height: 24),
            TextFormField(
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.email_outlined),
                labelText: 'Email address',
                hintText: 'name@example.com',
              ),
              validator: _validateEmail,
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _passwordController,
              obscureText: _obscurePassword,
              textInputAction: TextInputAction.done,
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.lock_outline_rounded),
                labelText: 'Password',
                hintText: 'Enter your password',
                suffixIcon: IconButton(
                  onPressed: () {
                    setState(() => _obscurePassword = !_obscurePassword);
                  },
                  icon: Icon(
                    _obscurePassword
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined,
                  ),
                ),
              ),
              validator: _validatePassword,
            ),
            const SizedBox(height: 10),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () => context.push(AppRouter.forgotPasswordPath),
                child: const Text('Forgot password?'),
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: isLoading ? null : _submitLogin,
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size.fromHeight(56),
                ),
                child: isLoading
                    ? const SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text('Log in'),
              ),
            ),
            const SizedBox(height: 18),
            Text(
              'Restricted access is reserved for your personal naijaDNA account. Use the admin dashboard only if you have editorial credentials.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: AppTheme.textMeta,
              ),
            ),
            const SizedBox(height: 18),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                TextButton(
                  onPressed: () => context.go(AppRouter.homePath),
                  child: const Text('Back to app'),
                ),
                TextButton(
                  onPressed: () => context.push(AppRouter.registerPath),
                  child: const Text('Create account'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopActions(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: AppTheme.primary.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(14),
          ),
          child: const Icon(Icons.menu_book_rounded, color: AppTheme.primary),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            'naijaDNA',
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
          ),
        ),
        TextButton(
          onPressed: () => context.go(AppRouter.homePath),
          child: const Text('Browse first'),
        ),
      ],
    );
  }

  void _submitLogin() {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    context.read<AuthBloc>().add(
      AuthLoginRequested(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      ),
    );
  }

  String? _validateEmail(String? value) {
    final input = (value ?? '').trim();
    if (input.isEmpty || !input.contains('@')) {
      return 'Enter a valid email address.';
    }
    return null;
  }

  String? _validatePassword(String? value) {
    final input = value ?? '';
    if (input.length < 8) {
      return 'Password must be at least 8 characters.';
    }
    return null;
  }
}

class _AuthEditorialPanel extends StatelessWidget {
  const _AuthEditorialPanel({
    required this.eyebrow,
    required this.title,
    required this.description,
    required this.bullets,
    this.compact = false,
  });

  final String eyebrow;
  final String title;
  final String description;
  final List<String> bullets;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(compact ? 24 : 34),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppTheme.primary,
            AppTheme.primaryContainer,
            const Color(0xFF1E825D),
          ],
        ),
        borderRadius: BorderRadius.circular(34),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              eyebrow,
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: Colors.white,
                letterSpacing: 0.7,
              ),
            ),
          ),
          SizedBox(height: compact ? 24 : 40),
          Text(
            title,
            style: Theme.of(context).textTheme.displaySmall?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w900,
              fontFamily: AppTheme.headlineFontFamily,
              height: 1.05,
            ),
          ),
          const SizedBox(height: 18),
          Text(
            description,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              color: Colors.white.withValues(alpha: 0.88),
              height: 1.5,
            ),
          ),
          SizedBox(height: compact ? 20 : 32),
          ...bullets.map(
            (bullet) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    margin: const EdgeInsets.only(top: 3),
                    width: 10,
                    height: 10,
                    decoration: const BoxDecoration(
                      color: Color(0xFFF2D16B),
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      bullet,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Colors.white.withValues(alpha: 0.88),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
