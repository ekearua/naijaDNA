import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:naijapulse/core/di/injection_container.dart';
import 'package:naijapulse/core/error/failures.dart';
import 'package:naijapulse/core/routing/app_router.dart';
import 'package:naijapulse/core/theme/theme.dart';
import 'package:naijapulse/features/auth/data/datasource/remote/auth_remote_datasource.dart';

class ResetPasswordPage extends StatefulWidget {
  const ResetPasswordPage({this.initialToken, super.key});

  final String? initialToken;

  @override
  State<ResetPasswordPage> createState() => _ResetPasswordPageState();
}

class _ResetPasswordPageState extends State<ResetPasswordPage> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _tokenController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController =
      TextEditingController();
  final AuthRemoteDataSource _authRemote =
      InjectionContainer.sl<AuthRemoteDataSource>();

  bool _saving = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _completed = false;

  @override
  void initState() {
    super.initState();
    _tokenController.text = widget.initialToken ?? '';
  }

  @override
  void dispose() {
    _tokenController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() => _saving = true);
    try {
      await _authRemote.resetPassword(
        token: _tokenController.text,
        password: _passwordController.text,
      );
      if (!mounted) {
        return;
      }
      setState(() => _completed = true);
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(mapFailure(error).message)));
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      body: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: isDark
                ? const [AppTheme.darkBg, AppTheme.darkBgSoft]
                : const [Color(0xFFF5F0E6), Color(0xFFEEE7DA)],
          ),
        ),
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: Container(
                padding: const EdgeInsets.all(30),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  borderRadius: BorderRadius.circular(30),
                  border: Border.all(
                    color: AppTheme.divider.withValues(alpha: 0.8),
                  ),
                  boxShadow: AppTheme.ambientShadow(
                    Theme.of(context).brightness,
                  ),
                ),
                child: _completed
                    ? _buildCompleteState(context)
                    : _buildForm(context),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCompleteState(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'Password updated',
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
            fontWeight: FontWeight.w900,
            fontFamily: AppTheme.headlineFontFamily,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          'Your NaijaPulse account password has been reset successfully. You can sign in with the new password now.',
          style: Theme.of(
            context,
          ).textTheme.bodyLarge?.copyWith(color: AppTheme.textSecondary),
        ),
        const SizedBox(height: 22),
        FilledButton.icon(
          onPressed: () => context.go(AppRouter.loginPath),
          icon: const Icon(Icons.login_rounded),
          label: const Text('Return to login'),
        ),
      ],
    );
  }

  Widget _buildForm(BuildContext context) {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Reset password',
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.w900,
              fontFamily: AppTheme.headlineFontFamily,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'Paste the reset token from your recovery link, then set a new password for your account.',
            style: Theme.of(
              context,
            ).textTheme.bodyLarge?.copyWith(color: AppTheme.textSecondary),
          ),
          const SizedBox(height: 24),
          TextFormField(
            controller: _tokenController,
            minLines: 2,
            maxLines: 4,
            decoration: const InputDecoration(
              labelText: 'Reset token',
              prefixIcon: Icon(Icons.key_outlined),
            ),
            validator: (value) {
              if ((value ?? '').trim().length < 16) {
                return 'Enter a valid reset token.';
              }
              return null;
            },
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _passwordController,
            obscureText: _obscurePassword,
            decoration: InputDecoration(
              labelText: 'New password',
              prefixIcon: const Icon(Icons.lock_outline_rounded),
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
            validator: (value) {
              if ((value ?? '').trim().length < 8) {
                return 'Password must be at least 8 characters.';
              }
              return null;
            },
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _confirmPasswordController,
            obscureText: _obscureConfirmPassword,
            decoration: InputDecoration(
              labelText: 'Confirm new password',
              prefixIcon: const Icon(Icons.lock_reset_rounded),
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
            validator: (value) {
              if (value != _passwordController.text) {
                return 'Passwords do not match.';
              }
              return null;
            },
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _saving ? null : _submit,
              style: ElevatedButton.styleFrom(
                minimumSize: const Size.fromHeight(56),
              ),
              child: _saving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text('Update password'),
            ),
          ),
          const SizedBox(height: 16),
          TextButton.icon(
            onPressed: () => context.go(AppRouter.forgotPasswordPath),
            icon: const Icon(Icons.arrow_back_rounded),
            label: const Text('Back to recovery'),
          ),
        ],
      ),
    );
  }
}
