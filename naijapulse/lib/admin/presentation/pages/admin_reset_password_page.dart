import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:naijapulse/admin/presentation/admin_theme.dart';
import 'package:naijapulse/core/di/injection_container.dart';
import 'package:naijapulse/core/error/failures.dart';
import 'package:naijapulse/core/routing/app_router.dart';
import 'package:naijapulse/features/auth/data/datasource/remote/auth_remote_datasource.dart';

class AdminResetPasswordPage extends StatefulWidget {
  const AdminResetPasswordPage({this.initialToken, super.key});

  final String? initialToken;

  @override
  State<AdminResetPasswordPage> createState() => _AdminResetPasswordPageState();
}

class _AdminResetPasswordPageState extends State<AdminResetPasswordPage> {
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
    return Theme(
      data: AdminTheme.of(context),
      child: Scaffold(
        backgroundColor: const Color(0xFFF6F4EF),
        body: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
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
                      color: const Color(0xFF12261C).withValues(alpha: 0.08),
                      blurRadius: 40,
                      offset: const Offset(0, 16),
                    ),
                  ],
                ),
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: _completed
                      ? Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Password updated',
                              style: Theme.of(context).textTheme.headlineMedium
                                  ?.copyWith(fontWeight: FontWeight.w800),
                            ),
                            const SizedBox(height: 10),
                            Text(
                              'Your editorial password has been reset successfully. You can sign in with the new password now.',
                              style: Theme.of(context).textTheme.bodyLarge
                                  ?.copyWith(color: const Color(0xFF4B453E)),
                            ),
                            const SizedBox(height: 20),
                            FilledButton.icon(
                              onPressed: () =>
                                  context.go(AppRouter.adminLoginPath),
                              icon: const Icon(Icons.login_rounded),
                              label: const Text('Return to login'),
                            ),
                          ],
                        )
                      : Form(
                          key: _formKey,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Reset password',
                                style: Theme.of(context)
                                    .textTheme
                                    .headlineMedium
                                    ?.copyWith(fontWeight: FontWeight.w800),
                              ),
                              const SizedBox(height: 10),
                              Text(
                                'Use the secure link from your email to set a new password for your admin account. If you opened this page from that link, the token is already filled in below.',
                                style: Theme.of(context).textTheme.bodyLarge
                                    ?.copyWith(color: const Color(0xFF4B453E)),
                              ),
                              const SizedBox(height: 24),
                              TextFormField(
                                controller: _tokenController,
                                minLines: 2,
                                maxLines: 4,
                                decoration: _decoration(
                                  label: 'Reset token',
                                  icon: Icons.key_outlined,
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
                                decoration: _decoration(
                                  label: 'New password',
                                  icon: Icons.lock_outline_rounded,
                                  suffix: IconButton(
                                    onPressed: () {
                                      setState(() {
                                        _obscurePassword = !_obscurePassword;
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
                                decoration: _decoration(
                                  label: 'Confirm new password',
                                  icon: Icons.lock_reset_rounded,
                                  suffix: IconButton(
                                    onPressed: () {
                                      setState(() {
                                        _obscureConfirmPassword =
                                            !_obscureConfirmPassword;
                                      });
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
                                child: FilledButton(
                                  onPressed: _saving ? null : _submit,
                                  style: FilledButton.styleFrom(
                                    backgroundColor: const Color(0xFF0F6B4B),
                                    foregroundColor: Colors.white,
                                    minimumSize: const Size.fromHeight(54),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(14),
                                    ),
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
                              const SizedBox(height: 18),
                              TextButton.icon(
                                onPressed: () => context.go(
                                  AppRouter.adminForgotPasswordPath,
                                ),
                                icon: const Icon(Icons.arrow_back_rounded),
                                label: const Text('Back to recovery'),
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
    );
  }

  InputDecoration _decoration({
    required String label,
    required IconData icon,
    Widget? suffix,
  }) => InputDecoration(
    labelText: label,
    labelStyle: const TextStyle(
      color: Color(0xFF5A5248),
      fontWeight: FontWeight.w600,
    ),
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
  );
}
