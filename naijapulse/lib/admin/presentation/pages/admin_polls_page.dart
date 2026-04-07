import 'package:flutter/material.dart';
import 'package:naijapulse/admin/data/datasource/admin_remote_datasource.dart';
import 'package:naijapulse/admin/presentation/admin_theme.dart';
import 'package:naijapulse/core/di/injection_container.dart';
import 'package:naijapulse/core/error/failures.dart';
import 'package:naijapulse/features/news/presentation/widgets/news_time.dart';
import 'package:naijapulse/features/polls/domain/entities/poll.dart';
import 'package:naijapulse/features/polls/domain/entities/poll_category.dart';

class AdminPollsPage extends StatefulWidget {
  const AdminPollsPage({super.key});

  @override
  State<AdminPollsPage> createState() => _AdminPollsPageState();
}

class _AdminPollsPageState extends State<AdminPollsPage> {
  final AdminRemoteDataSource _remote =
      InjectionContainer.sl<AdminRemoteDataSource>();

  List<Poll> _polls = const <Poll>[];
  List<PollCategory> _categories = const <PollCategory>[];
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
      final results = await Future.wait<dynamic>(<Future<dynamic>>[
        _remote.fetchActivePolls(),
        _remote.fetchPollCategories(),
      ]);
      if (!mounted) {
        return;
      }
      setState(() {
        _polls = results[0] as List<Poll>;
        _categories = results[1] as List<PollCategory>;
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

  Future<void> _openCreatePollDialog() async {
    final created = await showDialog<bool>(
      context: context,
      builder: (context) => _PollEditorDialog(categories: _categories),
    );
    if (created == true) {
      await _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final totalVotes = _polls.fold<int>(
      0,
      (sum, poll) => sum + poll.totalVotes,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Polls', style: theme.textTheme.headlineSmall),
                  const SizedBox(height: 8),
                  Text(
                    'Create audience polls for major stories, track live participation, and prepare embeds for the live updates timeline.',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: AdminTheme.textMuted,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16),
            FilledButton.icon(
              onPressed: _openCreatePollDialog,
              icon: const Icon(Icons.add_chart_rounded),
              label: const Text('Create poll'),
            ),
          ],
        ),
        const SizedBox(height: 20),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            _MetricCard(
              icon: Icons.poll_outlined,
              label: 'Active polls',
              value: '${_polls.length}',
            ),
            _MetricCard(
              icon: Icons.how_to_vote_outlined,
              label: 'Votes recorded',
              value: '$totalVotes',
            ),
            _MetricCard(
              icon: Icons.category_outlined,
              label: 'Categories',
              value: '${_categories.length}',
            ),
          ],
        ),
        const SizedBox(height: 20),
        Expanded(
          child: Card(
            clipBehavior: Clip.antiAlias,
            child: RefreshIndicator(
              onRefresh: _load,
              child: _buildBody(context),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildBody(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_errorMessage != null) {
      return ListView(
        padding: const EdgeInsets.all(28),
        children: [
          _EmptyStateCard(
            icon: Icons.error_outline_rounded,
            title: 'Polls could not be loaded',
            message: _errorMessage!,
            actionLabel: 'Retry',
            onAction: _load,
          ),
        ],
      );
    }
    if (_polls.isEmpty) {
      return ListView(
        padding: const EdgeInsets.all(28),
        children: [
          _EmptyStateCard(
            icon: Icons.poll_outlined,
            title: 'No active polls yet',
            message:
                'Create the first poll here, then use it in coverage, alerts, and the upcoming live updates timeline.',
            actionLabel: 'Create poll',
            onAction: _openCreatePollDialog,
          ),
        ],
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(20),
      itemCount: _polls.length,
      separatorBuilder: (_, _) => const SizedBox(height: 16),
      itemBuilder: (context, index) => _PollCard(poll: _polls[index]),
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 220,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AdminTheme.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AdminTheme.cardBorder, width: 1.1),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AdminTheme.surfaceAlt,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: AdminTheme.accentDark),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 2),
                Text(
                  label,
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: AdminTheme.textMuted),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PollCard extends StatelessWidget {
  const _PollCard({required this.poll});

  final Poll poll;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AdminTheme.surfaceAlt,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AdminTheme.cardBorder, width: 1.1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _StatusChip(
                          label: poll.isClosed ? 'Closed' : 'Active',
                          color: poll.isClosed
                              ? const Color(0xFF8A5B14)
                              : AdminTheme.accentDark,
                        ),
                        _InfoChip(
                          icon: Icons.schedule_rounded,
                          label: 'Ends ${adminDateTimeLabel(poll.endsAt)}',
                        ),
                        _InfoChip(
                          icon: Icons.category_outlined,
                          label: poll.categoryName ?? 'Uncategorized',
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Text(
                      poll.question,
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                        height: 1.2,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '${poll.totalVotes}',
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    poll.totalVotes == 1 ? 'vote' : 'votes',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: AdminTheme.textMuted,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 18),
          ...poll.options.map(
            (option) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _PollOptionBreakdown(
                option: option,
                totalVotes: poll.totalVotes,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PollOptionBreakdown extends StatelessWidget {
  const _PollOptionBreakdown({required this.option, required this.totalVotes});

  final PollOption option;
  final int totalVotes;

  @override
  Widget build(BuildContext context) {
    final percentage = totalVotes == 0 ? 0.0 : option.votes / totalVotes;
    final percentLabel = '${(percentage * 100).round()}%';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                option.label,
                style: Theme.of(
                  context,
                ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
              ),
            ),
            const SizedBox(width: 12),
            Text(
              '${option.votes} | $percentLabel',
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: AdminTheme.textMuted),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: LinearProgressIndicator(
            value: percentage,
            minHeight: 10,
            backgroundColor: const Color(0xFFE8DDD0),
            valueColor: const AlwaysStoppedAnimation<Color>(AdminTheme.accent),
          ),
        ),
      ],
    );
  }
}

class _InfoChip extends StatelessWidget {
  const _InfoChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AdminTheme.cardBorder),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: AdminTheme.textMuted),
          const SizedBox(width: 6),
          Text(
            label,
            style: Theme.of(
              context,
            ).textTheme.labelMedium?.copyWith(color: AdminTheme.textBase),
          ),
        ],
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
          color: color,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _EmptyStateCard extends StatelessWidget {
  const _EmptyStateCard({
    required this.icon,
    required this.title,
    required this.message,
    required this.actionLabel,
    required this.onAction,
  });

  final IconData icon;
  final String title;
  final String message;
  final String actionLabel;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: AdminTheme.surfaceAlt,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AdminTheme.cardBorder, width: 1.1),
      ),
      child: Column(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: AdminTheme.cardBorder),
            ),
            child: Icon(icon, color: AdminTheme.accentDark),
          ),
          const SizedBox(height: 16),
          Text(
            title,
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            message,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: AdminTheme.textMuted),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: onAction,
            icon: const Icon(Icons.refresh_rounded),
            label: Text(actionLabel),
          ),
        ],
      ),
    );
  }
}

class _PollEditorDialog extends StatefulWidget {
  const _PollEditorDialog({required this.categories});

  final List<PollCategory> categories;

  @override
  State<_PollEditorDialog> createState() => _PollEditorDialogState();
}

class _PollEditorDialogState extends State<_PollEditorDialog> {
  final AdminRemoteDataSource _remote =
      InjectionContainer.sl<AdminRemoteDataSource>();
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _questionController = TextEditingController();
  final List<TextEditingController> _optionControllers =
      List<TextEditingController>.generate(4, (_) => TextEditingController());

  DateTime _endsAt = DateTime.now().add(const Duration(days: 1));
  String? _selectedCategoryId;
  bool _submitting = false;

  @override
  void dispose() {
    _questionController.dispose();
    for (final controller in _optionControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _pickEndsAt() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _endsAt,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (date == null || !mounted) {
      return;
    }
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_endsAt),
    );
    if (time == null || !mounted) {
      return;
    }
    setState(() {
      _endsAt = DateTime(
        date.year,
        date.month,
        date.day,
        time.hour,
        time.minute,
      );
    });
  }

  Future<void> _submit() async {
    final form = _formKey.currentState;
    if (form == null || !form.validate()) {
      return;
    }
    final optionLabels = _optionControllers
        .map((controller) => controller.text.trim())
        .where((value) => value.isNotEmpty)
        .toList(growable: false);
    if (optionLabels.length < 2) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Add at least two poll options.')),
      );
      return;
    }

    setState(() => _submitting = true);
    try {
      final messenger = ScaffoldMessenger.of(context);
      await _remote.createPoll(
        question: _questionController.text.trim(),
        endsAt: _endsAt,
        categoryId: _selectedCategoryId,
        optionLabels: optionLabels,
      );
      if (!mounted) {
        return;
      }
      Navigator.of(context).pop(true);
      messenger.showSnackBar(
        const SnackBar(content: Text('Poll created successfully.')),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(mapFailure(error).message)));
      setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Create poll'),
      content: SizedBox(
        width: 520,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextFormField(
                  controller: _questionController,
                  maxLines: 3,
                  minLines: 2,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(
                    labelText: 'Question',
                    hintText:
                        'What should the audience vote on during coverage?',
                  ),
                  validator: (value) {
                    final trimmed = value?.trim() ?? '';
                    if (trimmed.isEmpty) {
                      return 'Question is required.';
                    }
                    if (trimmed.length < 10) {
                      return 'Make the question a bit more specific.';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  initialValue: _selectedCategoryId ?? '',
                  decoration: const InputDecoration(
                    labelText: 'Category',
                    hintText: 'Optional topic alignment',
                  ),
                  items: [
                    const DropdownMenuItem<String>(
                      value: '',
                      child: Text('No category'),
                    ),
                    ...widget.categories.map(
                      (category) => DropdownMenuItem<String>(
                        value: category.id,
                        child: Text(category.name),
                      ),
                    ),
                  ],
                  onChanged: (value) {
                    setState(() {
                      _selectedCategoryId = value == null || value.isEmpty
                          ? null
                          : value;
                    });
                  },
                ),
                const SizedBox(height: 16),
                InkWell(
                  onTap: _pickEndsAt,
                  borderRadius: BorderRadius.circular(14),
                  child: InputDecorator(
                    decoration: const InputDecoration(
                      labelText: 'Poll closes',
                      prefixIcon: Icon(Icons.schedule_rounded),
                    ),
                    child: Row(
                      children: [
                        Expanded(child: Text(adminDateTimeLabel(_endsAt))),
                        const SizedBox(width: 12),
                        const Icon(Icons.edit_calendar_rounded, size: 18),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Options',
                  style: Theme.of(
                    context,
                  ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 10),
                ...List<Widget>.generate(_optionControllers.length, (index) {
                  return Padding(
                    padding: EdgeInsets.only(
                      bottom: index == _optionControllers.length - 1 ? 0 : 12,
                    ),
                    child: TextFormField(
                      controller: _optionControllers[index],
                      textCapitalization: TextCapitalization.sentences,
                      decoration: InputDecoration(
                        labelText: 'Option ${index + 1}',
                        hintText: index < 2
                            ? 'Required'
                            : 'Optional extra choice',
                      ),
                      validator: (value) {
                        if (index < 2 && (value?.trim().isEmpty ?? true)) {
                          return 'At least two options are required.';
                        }
                        return null;
                      },
                    ),
                  );
                }),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _submitting ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton.icon(
          onPressed: _submitting ? null : _submit,
          icon: _submitting
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.add_chart_rounded),
          label: Text(_submitting ? 'Creating...' : 'Create poll'),
        ),
      ],
    );
  }
}
