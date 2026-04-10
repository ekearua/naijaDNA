import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:naijapulse/admin/data/datasource/admin_remote_datasource.dart';
import 'package:naijapulse/admin/data/models/admin_models.dart';
import 'package:naijapulse/core/di/injection_container.dart';
import 'package:naijapulse/core/error/failures.dart';
import 'package:naijapulse/core/routing/app_router.dart';
import 'package:naijapulse/features/news/presentation/widgets/news_time.dart';

class AdminWorkflowActivityPage extends StatefulWidget {
  const AdminWorkflowActivityPage({super.key});

  @override
  State<AdminWorkflowActivityPage> createState() =>
      _AdminWorkflowActivityPageState();
}

class _AdminWorkflowActivityPageState extends State<AdminWorkflowActivityPage> {
  static const int _pageSize = 30;

  final AdminRemoteDataSource _remote =
      InjectionContainer.sl<AdminRemoteDataSource>();
  final TextEditingController _actorController = TextEditingController();

  List<AdminWorkflowActivityModel> _items =
      const <AdminWorkflowActivityModel>[];
  String? _selectedRole;
  String? _selectedEventType;
  DateTime? _dateFrom;
  DateTime? _dateTo;
  int _offset = 0;
  int _total = 0;
  bool _loading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _actorController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _errorMessage = null;
    });
    try {
      final page = await _remote.fetchWorkflowActivityPage(
        actor: _actorController.text,
        role: _selectedRole,
        eventType: _selectedEventType,
        dateFrom: _dateFrom,
        dateTo: _dateTo,
        offset: _offset,
        limit: _pageSize,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _items = page.items;
        _total = page.total;
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

  Future<void> _pickDate({required bool isStart}) async {
    final current = isStart ? _dateFrom : _dateTo;
    final selected = await showDatePicker(
      context: context,
      initialDate: current ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (selected == null || !mounted) {
      return;
    }
    setState(() {
      if (isStart) {
        _dateFrom = DateTime(selected.year, selected.month, selected.day);
      } else {
        _dateTo = DateTime(
          selected.year,
          selected.month,
          selected.day,
          23,
          59,
          59,
        );
      }
      _offset = 0;
    });
    _load();
  }

  void _clearFilters() {
    setState(() {
      _actorController.clear();
      _selectedRole = null;
      _selectedEventType = null;
      _dateFrom = null;
      _dateTo = null;
      _offset = 0;
    });
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final canGoBack = _offset > 0;
    final canGoForward = _offset + _pageSize < _total;

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          _Panel(
            title: 'Workflow Activity',
            subtitle:
                'Every editorial action across the desk, with filters for user, role, event type, and date range.',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    SizedBox(
                      width: 280,
                      child: TextField(
                        controller: _actorController,
                        textInputAction: TextInputAction.search,
                        onSubmitted: (_) {
                          setState(() => _offset = 0);
                          _load();
                        },
                        decoration: const InputDecoration(
                          labelText: 'User',
                          hintText: 'Search by name, email, or user id',
                          prefixIcon: Icon(Icons.person_search_rounded),
                        ),
                      ),
                    ),
                    SizedBox(
                      width: 180,
                      child: DropdownButtonFormField<String?>(
                        value: _selectedRole,
                        isExpanded: true,
                        decoration: const InputDecoration(
                          labelText: 'Role',
                          prefixIcon: Icon(Icons.badge_outlined),
                        ),
                        items: const [
                          DropdownMenuItem<String?>(
                            value: null,
                            child: Text('All roles'),
                          ),
                          DropdownMenuItem<String?>(
                            value: 'admin',
                            child: Text('Admin'),
                          ),
                          DropdownMenuItem<String?>(
                            value: 'editor',
                            child: Text('Editor'),
                          ),
                          DropdownMenuItem<String?>(
                            value: 'moderator',
                            child: Text('Moderator'),
                          ),
                          DropdownMenuItem<String?>(
                            value: 'contributor',
                            child: Text('Contributor'),
                          ),
                          DropdownMenuItem<String?>(
                            value: 'user',
                            child: Text('User'),
                          ),
                        ],
                        onChanged: (value) {
                          setState(() {
                            _selectedRole = value;
                            _offset = 0;
                          });
                          _load();
                        },
                      ),
                    ),
                    SizedBox(
                      width: 200,
                      child: DropdownButtonFormField<String?>(
                        value: _selectedEventType,
                        isExpanded: true,
                        decoration: const InputDecoration(
                          labelText: 'Event',
                          prefixIcon: Icon(Icons.alt_route_rounded),
                        ),
                        items: const [
                          DropdownMenuItem<String?>(
                            value: null,
                            child: Text('All events'),
                          ),
                          DropdownMenuItem<String?>(
                            value: 'submit',
                            child: Text('Submit'),
                          ),
                          DropdownMenuItem<String?>(
                            value: 'approve',
                            child: Text('Approve'),
                          ),
                          DropdownMenuItem<String?>(
                            value: 'publish',
                            child: Text('Publish'),
                          ),
                          DropdownMenuItem<String?>(
                            value: 'reject',
                            child: Text('Reject'),
                          ),
                          DropdownMenuItem<String?>(
                            value: 'archive',
                            child: Text('Archive'),
                          ),
                          DropdownMenuItem<String?>(
                            value: 'restore',
                            child: Text('Restore'),
                          ),
                        ],
                        onChanged: (value) {
                          setState(() {
                            _selectedEventType = value;
                            _offset = 0;
                          });
                          _load();
                        },
                      ),
                    ),
                    OutlinedButton.icon(
                      onPressed: () => _pickDate(isStart: true),
                      icon: const Icon(Icons.event_outlined),
                      label: Text(
                        _dateFrom == null
                            ? 'From date'
                            : adminDateTimeLabel(_dateFrom!),
                      ),
                    ),
                    OutlinedButton.icon(
                      onPressed: () => _pickDate(isStart: false),
                      icon: const Icon(Icons.event_available_outlined),
                      label: Text(
                        _dateTo == null
                            ? 'To date'
                            : adminDateTimeLabel(_dateTo!),
                      ),
                    ),
                    FilledButton.icon(
                      onPressed: _loading
                          ? null
                          : () {
                              setState(() => _offset = 0);
                              _load();
                            },
                      icon: const Icon(Icons.search_rounded),
                      label: const Text('Apply'),
                    ),
                    TextButton(
                      onPressed: _loading ? null : _clearFilters,
                      child: const Text('Clear filters'),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                if (_errorMessage != null)
                  Text(
                    _errorMessage!,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: const Color(0xFFC53030),
                      fontWeight: FontWeight.w600,
                    ),
                  )
                else if (_loading)
                  const Center(child: CircularProgressIndicator())
                else if (_items.isEmpty)
                  const Text(
                    'No workflow activity matched the current filters.',
                  )
                else
                  Column(
                    children: _items
                        .map(
                          (item) => Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFFFCF8),
                              borderRadius: BorderRadius.circular(18),
                              border: Border.all(
                                color: const Color(0xFFE2DBCF),
                              ),
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                CircleAvatar(
                                  backgroundColor: const Color(0xFFE6F2ED),
                                  foregroundColor: const Color(0xFF0F6B4B),
                                  child: const Icon(Icons.history_rounded),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        item.articleTitle,
                                        style: Theme.of(context)
                                            .textTheme
                                            .titleMedium
                                            ?.copyWith(
                                              fontWeight: FontWeight.w800,
                                            ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        '${item.actorName}${item.actorRole == null ? '' : ' • ${item.actorRole}'} • ${_eventLabel(item.eventType)}',
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodyMedium
                                            ?.copyWith(
                                              color: const Color(0xFF4F4A43),
                                              fontWeight: FontWeight.w600,
                                            ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        adminDateTimeLabel(item.createdAt),
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodySmall
                                            ?.copyWith(
                                              color: const Color(0xFF6E675C),
                                            ),
                                      ),
                                      if (item.notes?.trim().isNotEmpty ??
                                          false) ...[
                                        const SizedBox(height: 8),
                                        Text(
                                          item.notes!,
                                          style: Theme.of(
                                            context,
                                          ).textTheme.bodySmall,
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 12),
                                TextButton(
                                  onPressed: () => context.go(
                                    AppRouter.adminArticleDetailPath(
                                      item.articleId,
                                    ),
                                  ),
                                  child: const Text('Open'),
                                ),
                              ],
                            ),
                          ),
                        )
                        .toList(growable: false),
                  ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Text(
                      _total == 0
                          ? 'No results'
                          : 'Showing ${_offset + 1}-${(_offset + _items.length).clamp(_offset + 1, _total)} of $_total',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: const Color(0xFF6E675C),
                      ),
                    ),
                    const Spacer(),
                    OutlinedButton(
                      onPressed: !canGoBack || _loading
                          ? null
                          : () {
                              setState(
                                () => _offset = (_offset - _pageSize).clamp(
                                  0,
                                  _offset,
                                ),
                              );
                              _load();
                            },
                      child: const Text('Previous'),
                    ),
                    const SizedBox(width: 8),
                    OutlinedButton(
                      onPressed: !canGoForward || _loading
                          ? null
                          : () {
                              setState(() => _offset += _pageSize);
                              _load();
                            },
                      child: const Text('Next'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _eventLabel(String eventType) {
    switch (eventType) {
      case 'submit':
        return 'submitted';
      case 'approve':
        return 'approved';
      case 'publish':
        return 'published';
      case 'reject':
        return 'rejected';
      case 'archive':
        return 'archived';
      case 'restore':
        return 'restored';
      default:
        return eventType;
    }
  }
}

class _Panel extends StatelessWidget {
  const _Panel({
    required this.title,
    required this.subtitle,
    required this.child,
  });

  final String title;
  final String subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFCFC3B0)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 6),
            Text(
              subtitle,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: const Color(0xFF4F4A43)),
            ),
            const SizedBox(height: 18),
            child,
          ],
        ),
      ),
    );
  }
}
