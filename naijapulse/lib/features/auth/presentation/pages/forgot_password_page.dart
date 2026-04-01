import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:naijapulse/core/di/injection_container.dart';
import 'package:naijapulse/core/error/failures.dart';
import 'package:naijapulse/core/routing/app_router.dart';
import 'package:naijapulse/core/theme/theme.dart';
import 'package:naijapulse/features/auth/data/datasource/remote/auth_remote_datasource.dart';

class ForgotPasswordPage extends StatefulWidget {
  const ForgotPasswordPage({super.key});

  @override
  State<ForgotPasswordPage> createState() => _ForgotPasswordPageState();
}

class _ForgotPasswordPageState extends State<ForgotPasswordPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  bool _submitting = false;
  String? _resetUrl;

  AuthRemoteDataSource get _remote =>
      InjectionContainer.sl<AuthRemoteDataSource>();

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _submitting = true;
      _resetUrl = null;
    });

    try {
      final response = await _remote.requestPasswordReset(
        email: _emailController.text.trim(),
        resetPath: AppRouter.resetPasswordPath,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _resetUrl = response['reset_url'] as String?;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Reset instructions generated for this account.'),
        ),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(mapFailure(error).message)));
    } finally {
      if (mounted) {
        setState(() => _submitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        leading: IconButton(
          onPressed: () {
            if (context.canPop()) {
              context.pop();
              return;
            }
            context.go(AppRouter.loginPath);
          },
          icon: const Icon(Icons.arrow_back_rounded),
        ),
        title: const Text('Forgot Password'),
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isWide = constraints.maxWidth >= 900;
          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
            children: [
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1100),
                child: Center(
                  child: isWide
                      ? Row(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Expanded(child: _ForgotPasswordEditorialPanel()),
                            const SizedBox(width: 24),
                            Expanded(child: _buildFormCard(context)),
                          ],
                        )
                      : _buildFormCard(context),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildFormCard(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: theme.dividerColor.withValues(alpha: 0.24)),
        boxShadow: AppTheme.ambientShadow(theme.brightness),
      ),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Restore Access',
              style: theme.textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'Provide your registered email to initiate a secure verification sequence.',
              style: theme.textTheme.bodyLarge?.copyWith(
                color: AppTheme.textSecondary,
              ),
            ),
            const SizedBox(height: 24),
            TextFormField(
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(
                labelText: 'Verified Editorial Email',
                prefixIcon: Icon(Icons.mark_email_read_outlined),
              ),
              validator: (value) {
                final input = (value ?? '').trim();
                if (input.isEmpty || !input.contains('@')) {
                  return 'Enter a valid email address.';
                }
                return null;
              },
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _submitting ? null : _submit,
                icon: _submitting
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.forward_rounded),
                label: Text(_submitting ? 'Sending...' : 'Send Reset Link'),
              ),
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                const Icon(Icons.verified_user_outlined, size: 18),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Your identity is protected by the Digital Curator encryption standards.',
                    style: theme.textTheme.bodySmall,
                  ),
                ),
              ],
            ),
            if (_resetUrl != null) ...[
              const SizedBox(height: 18),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: theme.dividerColor.withValues(alpha: 0.35),
                  ),
                ),
                child: SelectableText(
                  _resetUrl!,
                  style: theme.textTheme.bodyMedium,
                ),
              ),
            ],
            const SizedBox(height: 22),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                TextButton.icon(
                  onPressed: () => context.go(AppRouter.loginPath),
                  icon: const Icon(Icons.login_rounded),
                  label: const Text('Back to Sign In'),
                ),
                TextButton.icon(
                  onPressed: () => context.go(AppRouter.registerPath),
                  icon: const Icon(Icons.how_to_reg_rounded),
                  label: const Text('Create Account'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ForgotPasswordEditorialPanel extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppTheme.primary, AppTheme.primaryContainer],
        ),
        borderRadius: BorderRadius.circular(28),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Text(
            '"Information is the currency of democracy."',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              color: Colors.white,
              fontStyle: FontStyle.italic,
            ),
          ),
          const SizedBox(height: 18),
          Container(
            width: 48,
            height: 2,
            color: Colors.white.withValues(alpha: 0.35),
          ),
          const SizedBox(height: 18),
          Text(
            'The Editorial Mandate',
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: Colors.white.withValues(alpha: 0.84),
              letterSpacing: 1.1,
            ),
          ),
        ],
      ),
    );
  }
}
