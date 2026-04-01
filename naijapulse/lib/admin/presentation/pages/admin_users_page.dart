import 'package:flutter/material.dart';
import 'package:naijapulse/admin/data/datasource/admin_remote_datasource.dart';
import 'package:naijapulse/admin/data/models/admin_models.dart';
import 'package:naijapulse/core/di/injection_container.dart';
import 'package:naijapulse/core/error/failures.dart';
import 'package:naijapulse/features/news/presentation/widgets/news_time.dart';

class AdminUsersPage extends StatefulWidget {
  const AdminUsersPage({super.key});

  @override
  State<AdminUsersPage> createState() => _AdminUsersPageState();
}

class _AdminUsersPageState extends State<AdminUsersPage> {
  static const List<String> _roleFilters = <String>[
    'all',
    'user',
    'contributor',
    'moderator',
    'editor',
    'admin',
  ];

  static const List<String> _activityFilters = <String>[
    'all',
    'active',
    'inactive',
  ];

  final AdminRemoteDataSource _remote =
      InjectionContainer.sl<AdminRemoteDataSource>();

  List<AdminUserModel> _users = const <AdminUserModel>[];
  List<AdminUserAccessRequestModel> _requests =
      const <AdminUserAccessRequestModel>[];
  String _selectedRole = 'all';
  String _selectedActivity = 'all';
  bool _loading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _errorMessage = null;
    });
    try {
      final results = await Future.wait([
        _remote.fetchUsers(
          role: _selectedRole == 'all' ? null : _selectedRole,
          isActive: switch (_selectedActivity) {
            'active' => true,
            'inactive' => false,
            _ => null,
          },
        ),
        _remote.fetchUserAccessRequests(status: 'pending', limit: 50),
      ]);
      if (!mounted) {
        return;
      }
      setState(() {
        _users = results[0] as List<AdminUserModel>;
        _requests = results[1] as List<AdminUserAccessRequestModel>;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() => _errorMessage = mapFailure(error).message);
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _openEditDialog(AdminUserModel user) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => _UserEditorDialog(user: user),
    );
    if (result == true) {
      await _load();
    }
  }

  Future<void> _reviewRequest(
    AdminUserAccessRequestModel request,
    String action,
  ) async {
    try {
      await _remote.reviewUserAccessRequest(
        requestId: request.id,
        action: action,
      );
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${_accessTypeLabel(request.accessType)} ${action == 'approve' ? 'approved' : 'rejected'}.',
          ),
        ),
      );
      await _load();
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(mapFailure(error).message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          Text(
            'Users and Access',
            style: Theme.of(
              context,
            ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 6),
          Text(
            'Review account health, editorial roles, and admin-granted access for users.',
            style: Theme.of(
              context,
            ).textTheme.bodyLarge?.copyWith(color: const Color(0xFF6E675C)),
          ),
          const SizedBox(height: 18),
          Text(
            'Role',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 10),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: _roleFilters
                  .map(
                    (role) => Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: Text(_prettyLabel(role)),
                        selected: _selectedRole == role,
                        onSelected: (_) {
                          if (_selectedRole == role) {
                            return;
                          }
                          setState(() => _selectedRole = role);
                          _load();
                        },
                      ),
                    ),
                  )
                  .toList(growable: false),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Account State',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 10),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: _activityFilters
                  .map(
                    (state) => Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: Text(_prettyLabel(state)),
                        selected: _selectedActivity == state,
                        onSelected: (_) {
                          if (_selectedActivity == state) {
                            return;
                          }
                          setState(() => _selectedActivity = state);
                          _load();
                        },
                      ),
                    ),
                  )
                  .toList(growable: false),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'Pending Access Requests',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 10),
          if (_loading)
            const Padding(
              padding: EdgeInsets.only(top: 80),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_errorMessage != null)
            _StateCard(
              title: 'Could not load user access',
              message: _errorMessage!,
              actionLabel: 'Try again',
              onPressed: _load,
            )
          else ...[
            if (_requests.isEmpty)
              _StateCard(
                title: 'No pending requests',
                message:
                    'Users can request stream access, stream hosting, or contribution access here.',
                actionLabel: 'Refresh',
                onPressed: _load,
              )
            else
              ..._requests.map(
                (request) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _AccessRequestCard(
                    request: request,
                    onApprove: () => _reviewRequest(request, 'approve'),
                    onReject: () => _reviewRequest(request, 'reject'),
                  ),
                ),
              ),
            const SizedBox(height: 18),
            Text(
              'User Accounts',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 10),
            if (_users.isEmpty)
              _StateCard(
                title: 'No users match these filters',
                message:
                    'Adjust the filters to inspect a different cohort of accounts.',
                actionLabel: 'Refresh',
                onPressed: _load,
              )
            else
              ..._users.map(
                (user) => Padding(
                  padding: const EdgeInsets.only(bottom: 14),
                  child: _UserCard(
                    user: user,
                    onEdit: () => _openEditDialog(user),
                  ),
                ),
              ),
          ],
        ],
      ),
    );
  }

  String _prettyLabel(String value) {
    if (value == 'all') {
      return 'All';
    }
    return value
        .split('_')
        .map((part) => '${part[0].toUpperCase()}${part.substring(1)}')
        .join(' ');
  }
}

class _AccessRequestCard extends StatelessWidget {
  const _AccessRequestCard({
    required this.request,
    required this.onApprove,
    required this.onReject,
  });

  final AdminUserAccessRequestModel request;
  final VoidCallback onApprove;
  final VoidCallback onReject;

  @override
  Widget build(BuildContext context) {
    final displayName = request.userDisplayName?.trim().isNotEmpty == true
        ? request.userDisplayName!.trim()
        : request.userEmail ?? request.userId;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFE2DBCF)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          _Badge(
                            label: _accessTypeLabel(request.accessType),
                            color: const Color(0xFF7C3AED),
                          ),
                          _Badge(
                            label: request.status,
                            color: const Color(0xFF0F766E),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Text(
                        displayName,
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        request.userEmail ?? request.userId,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: const Color(0xFF6E675C),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Column(
                  children: [
                    OutlinedButton(
                      onPressed: onReject,
                      child: const Text('Reject'),
                    ),
                    const SizedBox(height: 8),
                    FilledButton(
                      onPressed: onApprove,
                      child: const Text('Approve'),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              request.reason,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: const Color(0xFF4A4338)),
            ),
            const SizedBox(height: 10),
            Text(
              'Requested ${adminDateTimeLabel(request.createdAt)}',
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: const Color(0xFF6E675C)),
            ),
          ],
        ),
      ),
    );
  }
}

class _UserCard extends StatelessWidget {
  const _UserCard({required this.user, required this.onEdit});

  final AdminUserModel user;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final displayName = user.displayName?.trim().isNotEmpty == true
        ? user.displayName!.trim()
        : user.email ?? user.id;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFE2DBCF)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  radius: 24,
                  backgroundColor: const Color(0xFFE6F2ED),
                  foregroundColor: const Color(0xFF0F6B4B),
                  child: Text(
                    displayName.characters.first.toUpperCase(),
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          _Badge(
                            label: user.role,
                            color: const Color(0xFF2563EB),
                          ),
                          _Badge(
                            label: user.isActive ? 'Active' : 'Inactive',
                            color: user.isActive
                                ? const Color(0xFF0F766E)
                                : const Color(0xFFC53030),
                          ),
                          if (user.streamAccessGranted)
                            const _Badge(
                              label: 'Stream Access',
                              color: Color(0xFF0F766E),
                            ),
                          if (user.streamHostingGranted)
                            const _Badge(
                              label: 'Stream Hosting',
                              color: Color(0xFFD97706),
                            ),
                          if (user.contributionAccessGranted)
                            const _Badge(
                              label: 'Contribution',
                              color: Color(0xFF7C3AED),
                            ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        displayName,
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        user.email ?? user.id,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: const Color(0xFF6E675C),
                        ),
                      ),
                    ],
                  ),
                ),
                OutlinedButton.icon(
                  onPressed: onEdit,
                  icon: const Icon(Icons.manage_accounts_outlined),
                  label: const Text('Edit'),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                _MetricTile(
                  label: 'Submitted',
                  value: user.submittedArticleCount,
                ),
                _MetricTile(
                  label: 'Published',
                  value: user.publishedArticleCount,
                ),
                _MetricTile(label: 'Comments', value: user.commentCount),
                _MetricTile(label: 'Reports', value: user.reportCount),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              'Joined ${adminDateTimeLabel(user.createdAt)}',
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: const Color(0xFF6E675C)),
            ),
          ],
        ),
      ),
    );
  }
}

class _UserEditorDialog extends StatefulWidget {
  const _UserEditorDialog({required this.user});

  final AdminUserModel user;

  @override
  State<_UserEditorDialog> createState() => _UserEditorDialogState();
}

class _UserEditorDialogState extends State<_UserEditorDialog> {
  static const List<String> _roles = <String>[
    'user',
    'contributor',
    'moderator',
    'editor',
    'admin',
  ];

  final _formKey = GlobalKey<FormState>();
  final AdminRemoteDataSource _remote =
      InjectionContainer.sl<AdminRemoteDataSource>();

  late final TextEditingController _displayNameController;
  late final TextEditingController _avatarUrlController;
  late String _role;
  late bool _isActive;
  late bool _streamAccessGranted;
  late bool _streamHostingGranted;
  late bool _contributionAccessGranted;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _displayNameController = TextEditingController(
      text: widget.user.displayName ?? '',
    );
    _avatarUrlController = TextEditingController(
      text: widget.user.avatarUrl ?? '',
    );
    _role = widget.user.role;
    _isActive = widget.user.isActive;
    _streamAccessGranted = widget.user.streamAccessGranted;
    _streamHostingGranted = widget.user.streamHostingGranted;
    _contributionAccessGranted = widget.user.contributionAccessGranted;
  }

  @override
  void dispose() {
    _displayNameController.dispose();
    _avatarUrlController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    setState(() => _saving = true);
    try {
      await _remote.updateUser(
        userId: widget.user.id,
        displayName: _displayNameController.text,
        avatarUrl: _avatarUrlController.text,
        isActive: _isActive,
        role: _role,
        streamAccessGranted: _streamAccessGranted || _streamHostingGranted,
        streamHostingGranted: _streamHostingGranted,
        contributionAccessGranted: _contributionAccessGranted,
      );
      if (!mounted) {
        return;
      }
      Navigator.of(context).pop(true);
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
    return AlertDialog(
      title: const Text('Edit user'),
      content: SizedBox(
        width: 520,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  initialValue: widget.user.email ?? widget.user.id,
                  enabled: false,
                  decoration: const InputDecoration(labelText: 'Account'),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _displayNameController,
                  decoration: const InputDecoration(labelText: 'Display Name'),
                  validator: (value) => (value ?? '').trim().isEmpty
                      ? 'Display name is required.'
                      : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _avatarUrlController,
                  decoration: const InputDecoration(labelText: 'Avatar URL'),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: _role,
                  decoration: const InputDecoration(labelText: 'Role'),
                  items: _roles
                      .map(
                        (role) => DropdownMenuItem<String>(
                          value: role,
                          child: Text(
                            role[0].toUpperCase() + role.substring(1),
                          ),
                        ),
                      )
                      .toList(growable: false),
                  onChanged: (value) {
                    if (value != null) {
                      setState(() => _role = value);
                    }
                  },
                ),
                const SizedBox(height: 12),
                SwitchListTile.adaptive(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Stream Access'),
                  subtitle: const Text(
                    'Can view stream content and discussions.',
                  ),
                  value: _streamAccessGranted || _streamHostingGranted,
                  onChanged: (value) => setState(() {
                    _streamAccessGranted = value;
                    if (!value) {
                      _streamHostingGranted = false;
                    }
                  }),
                ),
                SwitchListTile.adaptive(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Stream Hosting'),
                  subtitle: const Text('Can start and manage live streams.'),
                  value: _streamHostingGranted,
                  onChanged: (value) => setState(() {
                    _streamHostingGranted = value;
                    if (value) {
                      _streamAccessGranted = true;
                    }
                  }),
                ),
                SwitchListTile.adaptive(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Contribution Access'),
                  subtitle: const Text(
                    'Can submit stories for editorial review.',
                  ),
                  value: _contributionAccessGranted,
                  onChanged: (value) =>
                      setState(() => _contributionAccessGranted = value),
                ),
                SwitchListTile.adaptive(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Account Active'),
                  value: _isActive,
                  onChanged: (value) => setState(() => _isActive = value),
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _saving ? null : _save,
          child: Text(_saving ? 'Saving...' : 'Save changes'),
        ),
      ],
    );
  }
}

class _MetricTile extends StatelessWidget {
  const _MetricTile({required this.label, required this.value});

  final String label;
  final int value;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 120,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: const Color(0xFFF8F4ED),
          borderRadius: BorderRadius.circular(18),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '$value',
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 4),
              Text(label, style: Theme.of(context).textTheme.bodySmall),
            ],
          ),
        ),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final text = label
        .split('_')
        .map((part) => '${part[0].toUpperCase()}${part.substring(1)}')
        .join(' ');
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
          color: color,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _StateCard extends StatelessWidget {
  const _StateCard({
    required this.title,
    required this.message,
    required this.actionLabel,
    required this.onPressed,
  });

  final String title;
  final String message;
  final String actionLabel;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFE2DBCF)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: const Color(0xFF6E675C)),
            ),
            const SizedBox(height: 16),
            FilledButton(onPressed: onPressed, child: Text(actionLabel)),
          ],
        ),
      ),
    );
  }
}

String _accessTypeLabel(String accessType) {
  switch (accessType) {
    case 'stream_access':
      return 'Stream Access';
    case 'stream_hosting':
      return 'Stream Hosting';
    case 'contribution_access':
      return 'Contribution Access';
    default:
      return accessType;
  }
}
