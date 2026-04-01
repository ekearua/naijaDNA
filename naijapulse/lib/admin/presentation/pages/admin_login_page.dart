import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:naijapulse/admin/presentation/admin_theme.dart';
import 'package:naijapulse/core/routing/app_router.dart';
import 'package:naijapulse/features/auth/presentation/bloc/auth_bloc.dart';

class AdminLoginPage extends StatefulWidget {
  const AdminLoginPage({super.key});

  @override
  State<AdminLoginPage> createState() => _AdminLoginPageState();
}

class _AdminLoginPageState extends State<AdminLoginPage> {
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

  void _submit() {
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

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: AdminTheme.of(context),
      child: Scaffold(
        backgroundColor: const Color(0xFFF6F4EF),
        body: BlocConsumer<AuthBloc, AuthState>(
          listenWhen: (previous, current) =>
              previous.status != current.status ||
              previous.errorMessage != current.errorMessage,
          listener: (context, state) {
            if (state.status == AuthStatus.authenticated &&
                state.session != null) {
              if (state.session!.canManageEditorialContent) {
                context.go(AppRouter.adminDashboardPath);
                return;
              }
              if (state.session!.canModerateDiscussions) {
                context.go(AppRouter.adminModerationPath);
                return;
              }
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text(
                    'This account does not have editorial dashboard access yet.',
                  ),
                ),
              );
              context.go(AppRouter.homePath);
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
            final isWide = MediaQuery.sizeOf(context).width >= 980;

            return Row(
              children: [
                if (isWide)
                  const Expanded(
                    flex: 5,
                    child: _AdminAuthHero(
                      title: 'Editorial Platform',
                      subtitle:
                          'Manage curation, moderation, trust, and source health from one newsroom console.',
                    ),
                  ),
                Expanded(
                  flex: 6,
                  child: Center(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(24),
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 460),
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(24),
                            border: Border.all(
                              color: const Color(0xFFC0B29E),
                              width: 1.2,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(
                                  0xFF12261C,
                                ).withValues(alpha: 0.08),
                                blurRadius: 40,
                                offset: const Offset(0, 16),
                              ),
                            ],
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(32),
                            child: Form(
                              key: _formKey,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'NaijaPulse Admin',
                                    style: Theme.of(context)
                                        .textTheme
                                        .labelLarge
                                        ?.copyWith(
                                          color: const Color(0xFF4B453E),
                                          fontWeight: FontWeight.w700,
                                        ),
                                  ),
                                  const SizedBox(height: 12),
                                  Text(
                                    'Log in',
                                    style: Theme.of(context)
                                        .textTheme
                                        .headlineMedium
                                        ?.copyWith(
                                          fontWeight: FontWeight.w800,
                                          color: const Color(0xFF1D1B18),
                                        ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'Access the editorial dashboard and moderation tools.',
                                    style: Theme.of(context).textTheme.bodyLarge
                                        ?.copyWith(
                                          color: const Color(0xFF4B453E),
                                        ),
                                  ),
                                  const SizedBox(height: 28),
                                  _LabeledField(
                                    label: 'Email address',
                                    child: TextFormField(
                                      controller: _emailController,
                                      keyboardType: TextInputType.emailAddress,
                                      textInputAction: TextInputAction.next,
                                      decoration: _inputDecoration(
                                        icon: Icons.email_outlined,
                                        hintText: 'editor@naijapulse.ng',
                                      ),
                                      validator: (value) {
                                        final input = (value ?? '').trim();
                                        if (input.isEmpty ||
                                            !input.contains('@')) {
                                          return 'Enter a valid email address.';
                                        }
                                        return null;
                                      },
                                    ),
                                  ),
                                  const SizedBox(height: 18),
                                  _LabeledField(
                                    label: 'Password',
                                    child: TextFormField(
                                      controller: _passwordController,
                                      obscureText: _obscurePassword,
                                      textInputAction: TextInputAction.done,
                                      onFieldSubmitted: (_) => _submit(),
                                      decoration: _inputDecoration(
                                        icon: Icons.lock_outline_rounded,
                                        hintText: 'Enter your password',
                                        suffix: IconButton(
                                          onPressed: () {
                                            setState(() {
                                              _obscurePassword =
                                                  !_obscurePassword;
                                            });
                                          },
                                          icon: Icon(
                                            _obscurePassword
                                                ? Icons.visibility_outlined
                                                : Icons.visibility_off_outlined,
                                          ),
                                        ),
                                      ),
                                      validator: (value) {
                                        if ((value ?? '').length < 8) {
                                          return 'Password must be at least 8 characters.';
                                        }
                                        return null;
                                      },
                                    ),
                                  ),
                                  const SizedBox(height: 10),
                                  Align(
                                    alignment: Alignment.centerRight,
                                    child: TextButton(
                                      onPressed: () => context.go(
                                        AppRouter.adminForgotPasswordPath,
                                      ),
                                      child: const Text('Forgot password?'),
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  SizedBox(
                                    width: double.infinity,
                                    child: FilledButton(
                                      onPressed: isLoading ? null : _submit,
                                      style: FilledButton.styleFrom(
                                        backgroundColor: const Color(
                                          0xFF0F6B4B,
                                        ),
                                        foregroundColor: Colors.white,
                                        minimumSize: const Size.fromHeight(54),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            14,
                                          ),
                                        ),
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
                                    'Restricted access for authorized editorial staff.',
                                    style: Theme.of(context).textTheme.bodySmall
                                        ?.copyWith(
                                          color: const Color(0xFF4B453E),
                                        ),
                                  ),
                                  const SizedBox(height: 8),
                                  Row(
                                    children: [
                                      TextButton(
                                        onPressed: () =>
                                            context.go(AppRouter.homePath),
                                        child: const Text('Back to app'),
                                      ),
                                      const Spacer(),
                                      TextButton(
                                        onPressed: () => context.push(
                                          AppRouter.adminRequestAccessPath,
                                        ),
                                        child: const Text('Request access'),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  InputDecoration _inputDecoration({
    required IconData icon,
    required String hintText,
    Widget? suffix,
  }) {
    return InputDecoration(
      hintText: hintText,
      hintStyle: const TextStyle(
        color: Color(0xFF695F52),
        fontWeight: FontWeight.w500,
      ),
      prefixIcon: Icon(icon, color: const Color(0xFF5B5146)),
      suffixIcon: suffix,
      suffixIconColor: const Color(0xFF5B5146),
      filled: true,
      fillColor: const Color(0xFFF1E8DC),
      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFFB8AA94), width: 1.2),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFFB8AA94), width: 1.2),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFF0F6B4B), width: 1.8),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFFC53030), width: 1.2),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFFC53030), width: 1.8),
      ),
    );
  }
}

class _AdminAuthHero extends StatelessWidget {
  const _AdminAuthHero({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(48, 56, 48, 48),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF0B4F38), Color(0xFF0F6B4B)],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(18),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.newspaper_rounded, color: Colors.white),
                SizedBox(width: 10),
                Text(
                  'NaijaPulse Admin',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
          const Spacer(),
          Text(
            title,
            style: Theme.of(context).textTheme.displaySmall?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            subtitle,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: Colors.white.withValues(alpha: 0.86),
              height: 1.45,
            ),
          ),
          const SizedBox(height: 28),
          const _HeroChecklistItem(label: 'Workflow-controlled publishing'),
          const SizedBox(height: 14),
          const _HeroChecklistItem(
            label: 'Comment moderation and verification tools',
          ),
          const SizedBox(height: 14),
          const _HeroChecklistItem(
            label: 'Ingestion, cache, and newsroom health visibility',
          ),
        ],
      ),
    );
  }
}

class _HeroChecklistItem extends StatelessWidget {
  const _HeroChecklistItem({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          height: 28,
          width: 28,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.14),
            borderRadius: BorderRadius.circular(999),
          ),
          alignment: Alignment.center,
          child: const Icon(Icons.check_rounded, color: Colors.white, size: 18),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            label,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}

class _LabeledField extends StatelessWidget {
  const _LabeledField({required this.label, required this.child});

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
            fontWeight: FontWeight.w700,
            color: const Color(0xFF3A362F),
          ),
        ),
        const SizedBox(height: 8),
        child,
      ],
    );
  }
}
