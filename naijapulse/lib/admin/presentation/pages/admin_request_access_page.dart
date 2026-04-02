import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:naijapulse/admin/presentation/admin_theme.dart';
import 'package:naijapulse/core/di/injection_container.dart';
import 'package:naijapulse/core/error/exceptions.dart';
import 'package:naijapulse/core/error/failures.dart';
import 'package:naijapulse/core/routing/app_router.dart';
import 'package:naijapulse/features/auth/data/datasource/remote/auth_remote_datasource.dart';

class AdminRequestAccessPage extends StatefulWidget {
  const AdminRequestAccessPage({super.key});

  @override
  State<AdminRequestAccessPage> createState() => _AdminRequestAccessPageState();
}

class _AdminRequestAccessPageState extends State<AdminRequestAccessPage> {
  static const List<String> _roleOptions = <String>[
    'Senior Editor',
    'Staff Journalist',
    'Verification Desk',
    'Technical Admin',
  ];

  final _formKey = GlobalKey<FormState>();
  final _fullNameController = TextEditingController();
  final _workEmailController = TextEditingController();
  final _bureauController = TextEditingController();
  final _reasonController = TextEditingController();
  final AuthRemoteDataSource _authRemote =
      InjectionContainer.sl<AuthRemoteDataSource>();

  String? _selectedRole;
  bool _submitting = false;
  Map<String, dynamic>? _submissionResult;

  @override
  void dispose() {
    _fullNameController.dispose();
    _workEmailController.dispose();
    _bureauController.dispose();
    _reasonController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    setState(() => _submitting = true);
    try {
      final response = await _authRemote.requestAdminAccess(
        fullName: _fullNameController.text,
        workEmail: _workEmailController.text,
        requestedRole: _selectedRole!,
        bureau: _bureauController.text,
        reason: _reasonController.text,
      );
      if (!mounted) {
        return;
      }
      setState(() => _submissionResult = response);
    } on AppException catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(mapFailure(error).message)));
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not submit access request: $error')),
      );
    } finally {
      if (mounted) {
        setState(() => _submitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.sizeOf(context).width >= 1040;
    return Theme(
      data: AdminTheme.of(context),
      child: Scaffold(
        backgroundColor: const Color(0xFFFFF8F3),
        body: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 18, 24, 0),
                child: Row(
                  children: [
                    Text(
                      'naijaDNA Admin',
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(
                            fontFamily: 'Newsreader',
                            color: const Color(0xFF005137),
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                    const Spacer(),
                    if (isWide) ...[
                      _TopLink(label: 'Help', onTap: () {}),
                      const SizedBox(width: 18),
                      _TopLink(label: 'Guidelines', onTap: () {}),
                      const SizedBox(width: 18),
                      _TopLink(label: 'Support', onTap: () {}),
                    ],
                  ],
                ),
              ),
              Expanded(
                child: Center(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(24),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 1180),
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(28),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(
                                0xFF1D1B18,
                              ).withValues(alpha: 0.06),
                              blurRadius: 34,
                              offset: const Offset(0, 16),
                            ),
                          ],
                        ),
                        child: isWide
                            ? Row(
                                children: [
                                  const Expanded(
                                    flex: 5,
                                    child: _RequestAccessHero(),
                                  ),
                                  Expanded(
                                    flex: 7,
                                    child: _RequestAccessFormPanel(
                                      formKey: _formKey,
                                      fullNameController: _fullNameController,
                                      workEmailController: _workEmailController,
                                      bureauController: _bureauController,
                                      reasonController: _reasonController,
                                      roleOptions: _roleOptions,
                                      selectedRole: _selectedRole,
                                      onRoleChanged: (value) {
                                        setState(() => _selectedRole = value);
                                      },
                                      isSubmitting: _submitting,
                                      submissionResult: _submissionResult,
                                      onSubmit: _submit,
                                    ),
                                  ),
                                ],
                              )
                            : Column(
                                children: [
                                  const _RequestAccessHero(compact: true),
                                  _RequestAccessFormPanel(
                                    formKey: _formKey,
                                    fullNameController: _fullNameController,
                                    workEmailController: _workEmailController,
                                    bureauController: _bureauController,
                                    reasonController: _reasonController,
                                    roleOptions: _roleOptions,
                                    selectedRole: _selectedRole,
                                    onRoleChanged: (value) {
                                      setState(() => _selectedRole = value);
                                    },
                                    isSubmitting: _submitting,
                                    submissionResult: _submissionResult,
                                    onSubmit: _submit,
                                  ),
                                ],
                              ),
                      ),
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 18),
                child: Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 18,
                  runSpacing: 8,
                  children: const [
                    Text(
                      'Contributor accounts use the naijaDNA mobile app.',
                      style: TextStyle(
                        fontSize: 12,
                        color: Color(0xFF6A6258),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Text(
                      'Security',
                      style: TextStyle(fontSize: 12, color: Color(0xFF6A6258)),
                    ),
                    Text(
                      'Newsroom ethics',
                      style: TextStyle(fontSize: 12, color: Color(0xFF6A6258)),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RequestAccessHero extends StatelessWidget {
  const _RequestAccessHero({this.compact = false});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(minHeight: compact ? 260 : 620),
      padding: EdgeInsets.fromLTRB(32, compact ? 32 : 48, 32, 32),
      decoration: BoxDecoration(
        borderRadius: compact
            ? const BorderRadius.vertical(top: Radius.circular(28))
            : const BorderRadius.horizontal(left: Radius.circular(28)),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF0F6B4B), Color(0xFF0B4F38)],
        ),
      ),
      child: Stack(
        children: [
          Positioned(
            right: -40,
            top: -20,
            child: Container(
              width: 220,
              height: 220,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.06),
              ),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.shield_outlined, size: 16, color: Colors.white),
                    SizedBox(width: 8),
                    Text(
                      'Secure Administration',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.6,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 28),
              Text(
                'Defining the pulse of digital narrative.',
                style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                  fontFamily: 'Newsreader',
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  height: 1.1,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Access to the naijaDNA editorial suite is restricted to verified newsroom staff and administrative partners.',
                style: TextStyle(
                  color: Color(0xD8FFFFFF),
                  fontSize: 14,
                  height: 1.6,
                ),
              ),
              const Spacer(),
              Row(
                children: [
                  Container(
                    width: 34,
                    height: 1,
                    color: Colors.white.withValues(alpha: 0.34),
                  ),
                  const SizedBox(width: 12),
                  const Text(
                    'EDITORIAL INTEGRITY FIRST',
                    style: TextStyle(
                      color: Color(0xCCFFFFFF),
                      fontSize: 10,
                      letterSpacing: 1.3,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _RequestAccessFormPanel extends StatelessWidget {
  const _RequestAccessFormPanel({
    required this.formKey,
    required this.fullNameController,
    required this.workEmailController,
    required this.bureauController,
    required this.reasonController,
    required this.roleOptions,
    required this.selectedRole,
    required this.onRoleChanged,
    required this.isSubmitting,
    required this.submissionResult,
    required this.onSubmit,
  });

  final GlobalKey<FormState> formKey;
  final TextEditingController fullNameController;
  final TextEditingController workEmailController;
  final TextEditingController bureauController;
  final TextEditingController reasonController;
  final List<String> roleOptions;
  final String? selectedRole;
  final ValueChanged<String?> onRoleChanged;
  final bool isSubmitting;
  final Map<String, dynamic>? submissionResult;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 460),
          child: submissionResult == null
              ? Form(
                  key: formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Request newsroom access',
                        style: Theme.of(context).textTheme.headlineMedium
                            ?.copyWith(
                              fontFamily: 'Newsreader',
                              color: const Color(0xFF1D1B18),
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                      const SizedBox(height: 10),
                      const Text(
                        'Complete the verification form below. Our platform administrator will review your credentials within 24 hours.',
                        style: TextStyle(
                          color: Color(0xFF4B453E),
                          fontSize: 14,
                          height: 1.6,
                        ),
                      ),
                      const SizedBox(height: 28),
                      _RequestField(
                        label: 'Full name',
                        child: TextFormField(
                          controller: fullNameController,
                          decoration: _requestDecoration(
                            hintText: 'e.g. Chinua Achebe',
                          ),
                          validator: (value) {
                            if ((value ?? '').trim().length < 2) {
                              return 'Enter your full name.';
                            }
                            return null;
                          },
                        ),
                      ),
                      const SizedBox(height: 18),
                      _RequestField(
                        label: 'Work email',
                        child: TextFormField(
                          controller: workEmailController,
                          keyboardType: TextInputType.emailAddress,
                          decoration: _requestDecoration(
                            hintText: 'name@naijadna.com',
                          ),
                          validator: (value) {
                            final input = (value ?? '').trim();
                            if (input.isEmpty || !input.contains('@')) {
                              return 'Enter a valid work email.';
                            }
                            return null;
                          },
                        ),
                      ),
                      const SizedBox(height: 18),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: _RequestField(
                              label: 'Role / team',
                              child: DropdownButtonFormField<String>(
                                value: selectedRole,
                                items: roleOptions
                                    .map(
                                      (role) => DropdownMenuItem<String>(
                                        value: role,
                                        child: Text(role),
                                      ),
                                    )
                                    .toList(),
                                decoration: _requestDecoration(
                                  hintText: 'Select position',
                                ),
                                onChanged: onRoleChanged,
                                validator: (value) {
                                  if ((value ?? '').trim().isEmpty) {
                                    return 'Select a role.';
                                  }
                                  return null;
                                },
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: _RequestField(
                              label: 'Bureau',
                              child: TextFormField(
                                controller: bureauController,
                                decoration: _requestDecoration(
                                  hintText: 'Lagos HQ',
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),
                      _RequestField(
                        label: 'Reason for access',
                        child: TextFormField(
                          controller: reasonController,
                          minLines: 4,
                          maxLines: 4,
                          decoration: _requestDecoration(
                            hintText:
                                'Briefly describe your editorial responsibilities or project requirements...',
                          ),
                          validator: (value) {
                            if ((value ?? '').trim().length < 8) {
                              return 'Add a short reason for access.';
                            }
                            return null;
                          },
                        ),
                      ),
                      const SizedBox(height: 24),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          onPressed: isSubmitting ? null : onSubmit,
                          icon: isSubmitting
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Icon(Icons.send_rounded, size: 18),
                          label: Text(
                            isSubmitting ? 'Submitting...' : 'Submit request',
                          ),
                          style: FilledButton.styleFrom(
                            backgroundColor: const Color(0xFF0F6B4B),
                            foregroundColor: Colors.white,
                            minimumSize: const Size.fromHeight(56),
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF6F1EA),
                          borderRadius: BorderRadius.circular(18),
                        ),
                        child: const Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(Icons.info_rounded, color: Color(0xFF0F6B4B)),
                            SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                'Dashboard access is limited to editors and administrators. Contributor accounts should continue through the naijaDNA app experience.',
                                style: TextStyle(
                                  color: Color(0xFF4B453E),
                                  height: 1.5,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          onPressed: () => context.go(AppRouter.adminLoginPath),
                          child: const Text('Back to login'),
                        ),
                      ),
                    ],
                  ),
                )
              : _RequestSubmittedState(
                  message:
                      '${submissionResult!['message'] ?? 'Your request has been recorded.'}',
                  requestId: '${submissionResult!['request_id'] ?? ''}',
                ),
        ),
      ),
    );
  }
}

class _RequestSubmittedState extends StatelessWidget {
  const _RequestSubmittedState({
    required this.message,
    required this.requestId,
  });

  final String message;
  final String requestId;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            color: const Color(0xFF0F6B4B).withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(20),
          ),
          child: const Icon(
            Icons.mark_email_read_rounded,
            color: Color(0xFF0F6B4B),
            size: 30,
          ),
        ),
        const SizedBox(height: 20),
        Text(
          'Request received',
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
            fontFamily: 'Newsreader',
            fontWeight: FontWeight.w700,
            color: const Color(0xFF1D1B18),
          ),
        ),
        const SizedBox(height: 10),
        Text(
          message,
          style: const TextStyle(
            color: Color(0xFF4B453E),
            fontSize: 14,
            height: 1.6,
          ),
        ),
        if (requestId.trim().isNotEmpty) ...[
          const SizedBox(height: 18),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xFFF6F1EA),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                const Icon(Icons.confirmation_number_outlined, size: 18),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Reference: $requestId',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 26),
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: () => context.go(AppRouter.adminLoginPath),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF0F6B4B),
              foregroundColor: Colors.white,
              minimumSize: const Size.fromHeight(54),
            ),
            child: const Text('Return to login'),
          ),
        ),
        const SizedBox(height: 12),
        Align(
          alignment: Alignment.center,
          child: TextButton(
            onPressed: () => context.go(AppRouter.homePath),
            child: const Text('Back to app'),
          ),
        ),
      ],
    );
  }
}

class _RequestField extends StatelessWidget {
  const _RequestField({required this.label, required this.child});

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 2, bottom: 8),
          child: Text(
            label,
            style: const TextStyle(
              color: Color(0x8C3F4943),
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.8,
            ),
          ),
        ),
        child,
      ],
    );
  }
}

class _TopLink extends StatelessWidget {
  const _TopLink({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
        child: Text(
          label,
          style: const TextStyle(
            color: Color(0xFF6A6258),
            fontSize: 13,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }
}

InputDecoration _requestDecoration({required String hintText}) {
  return InputDecoration(
    hintText: hintText,
    hintStyle: const TextStyle(
      color: Color(0xFF94897B),
      fontWeight: FontWeight.w500,
    ),
    filled: true,
    fillColor: const Color(0xFFF9F2ED),
    contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: BorderSide.none,
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: BorderSide.none,
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: const BorderSide(color: Color(0xFF0F6B4B), width: 1.4),
    ),
    errorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: const BorderSide(color: Color(0xFFC53030), width: 1.2),
    ),
    focusedErrorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: const BorderSide(color: Color(0xFFC53030), width: 1.4),
    ),
  );
}
