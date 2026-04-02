import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:naijapulse/core/routing/app_router.dart';
import 'package:naijapulse/core/theme/theme.dart';
import 'package:naijapulse/features/auth/presentation/bloc/auth_bloc.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final _formKey = GlobalKey<FormState>();
  final _displayNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;

  @override
  void dispose() {
    _displayNameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
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
              SnackBar(content: Text('Welcome ${state.session?.displayName}!')),
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
                    : const [Color(0xFFF6F1E7), Color(0xFFF0E9DD)],
              ),
            ),
            child: SafeArea(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final isWide = constraints.maxWidth >= 960;
                  return Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 1180),
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: isWide
                            ? Row(
                                children: [
                                  Expanded(
                                    child: _RegisterEditorialPanel(
                                      compact: false,
                                    ),
                                  ),
                                  const SizedBox(width: 28),
                                  Expanded(
                                    child: SingleChildScrollView(
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 12,
                                      ),
                                      child: _buildFormCard(
                                        context,
                                        isLoading: isLoading,
                                      ),
                                    ),
                                  ),
                                ],
                              )
                            : ListView(
                                children: [
                                  _buildHeaderRow(context),
                                  const SizedBox(height: 20),
                                  const _RegisterEditorialPanel(compact: true),
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
            if (MediaQuery.sizeOf(context).width >= 960)
              _buildHeaderRow(context),
            if (MediaQuery.sizeOf(context).width >= 960)
              const SizedBox(height: 18),
            Text(
              'Create account',
              style: theme.textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.w900,
                fontFamily: AppTheme.headlineFontFamily,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'Build your reading profile so you can save stories, follow the topics you care about, and join the conversation around live coverage.',
              style: theme.textTheme.bodyLarge?.copyWith(
                color: AppTheme.textSecondary,
              ),
            ),
            const SizedBox(height: 24),
            TextFormField(
              controller: _displayNameController,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.person_outline_rounded),
                labelText: 'Display name',
                hintText: 'How should we address you?',
              ),
              validator: _validateDisplayName,
            ),
            const SizedBox(height: 14),
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
              textInputAction: TextInputAction.next,
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.lock_outline_rounded),
                labelText: 'Password',
                hintText: 'At least 8 characters',
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
            const SizedBox(height: 14),
            TextFormField(
              controller: _confirmPasswordController,
              obscureText: _obscureConfirmPassword,
              textInputAction: TextInputAction.done,
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.lock_reset_rounded),
                labelText: 'Confirm password',
                hintText: 'Repeat your password',
                suffixIcon: IconButton(
                  onPressed: () {
                    setState(
                      () => _obscureConfirmPassword = !_obscureConfirmPassword,
                    );
                  },
                  icon: Icon(
                    _obscureConfirmPassword
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined,
                  ),
                ),
              ),
              validator: _validateConfirmPassword,
            ),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: theme.brightness == Brightness.dark
                    ? AppTheme.darkSurfaceMuted
                    : AppTheme.bgSoft,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color:
                      (theme.brightness == Brightness.dark
                              ? AppTheme.darkDivider
                              : AppTheme.divider)
                          .withValues(alpha: 0.55),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Your account unlocks:',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 8),
                  _benefit('Saved stories synced across sessions'),
                  _benefit('Live stream reminders and comment notifications'),
                  _benefit('A more tailored home feed'),
                ],
              ),
            ),
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: isLoading ? null : _submitRegistration,
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
                    : const Text('Create account'),
              ),
            ),
            const SizedBox(height: 18),
            Text(
              'By continuing, you agree to our Terms and Privacy Policy.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: AppTheme.textMeta,
              ),
            ),
            const SizedBox(height: 18),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                TextButton(
                  onPressed: () => context.pushReplacement(AppRouter.loginPath),
                  child: const Text('Already have an account?'),
                ),
                TextButton(
                  onPressed: () => context.go(AppRouter.homePath),
                  child: const Text('Back to app'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeaderRow(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: AppTheme.primary.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(14),
          ),
          child: const Icon(Icons.newspaper_rounded, color: AppTheme.primary),
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
          onPressed: () => context.pushReplacement(AppRouter.loginPath),
          child: const Text('Log in'),
        ),
      ],
    );
  }

  Widget _benefit(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          const Icon(
            Icons.check_circle_rounded,
            size: 18,
            color: AppTheme.primary,
          ),
          const SizedBox(width: 8),
          Expanded(child: Text(text)),
        ],
      ),
    );
  }

  void _submitRegistration() {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    context.read<AuthBloc>().add(
      AuthRegisterRequested(
        displayName: _displayNameController.text.trim(),
        email: _emailController.text.trim(),
        password: _passwordController.text,
      ),
    );
  }

  String? _validateDisplayName(String? value) {
    final input = (value ?? '').trim();
    if (input.isEmpty) {
      return 'Enter a display name.';
    }
    return null;
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

  String? _validateConfirmPassword(String? value) {
    final input = value ?? '';
    if (input != _passwordController.text) {
      return 'Passwords do not match.';
    }
    return null;
  }
}

class _RegisterEditorialPanel extends StatelessWidget {
  const _RegisterEditorialPanel({required this.compact});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(compact ? 24 : 34),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF0E6B43), Color(0xFF147C57), Color(0xFF289568)],
        ),
        borderRadius: BorderRadius.circular(34),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              'The Digital Curator',
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: Colors.white,
                letterSpacing: 0.7,
              ),
            ),
          ),
          SizedBox(height: compact ? 24 : 40),
          Text(
            'Create your briefing room for smarter reading.',
            style: Theme.of(context).textTheme.displaySmall?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w900,
              fontFamily: AppTheme.headlineFontFamily,
              height: 1.05,
            ),
          ),
          const SizedBox(height: 18),
          Text(
            'Set up your account once and keep your saved reads, alerts, and topic preferences ready wherever you open naijaDNA.',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              color: Colors.white.withValues(alpha: 0.88),
              height: 1.5,
            ),
          ),
          SizedBox(height: compact ? 20 : 32),
          ...const [
            'Curated headlines with stronger local context.',
            'One-tap access to live streams and discussion threads.',
            'Personalized alerts across politics, business, tech, sports, and culture.',
          ].map(
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
                      color: Color(0xFFF4D36F),
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
