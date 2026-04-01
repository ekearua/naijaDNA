import 'package:flutter/material.dart';
import 'package:naijapulse/admin/data/datasource/admin_remote_datasource.dart';
import 'package:naijapulse/admin/data/models/admin_models.dart';
import 'package:naijapulse/core/di/injection_container.dart';
import 'package:naijapulse/core/error/failures.dart';
import 'package:naijapulse/features/news/presentation/widgets/news_time.dart';

class AdminSourcesPage extends StatefulWidget {
  const AdminSourcesPage({super.key});

  @override
  State<AdminSourcesPage> createState() => _AdminSourcesPageState();
}

class _AdminSourcesPageState extends State<AdminSourcesPage> {
  final AdminRemoteDataSource _remote =
      InjectionContainer.sl<AdminRemoteDataSource>();

  List<AdminSourceModel> _sources = const <AdminSourceModel>[];
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
      final sources = await _remote.fetchSources();
      if (!mounted) {
        return;
      }
      setState(() => _sources = sources);
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

  Future<void> _openCreateSourceDialog() async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => const _SourceEditorDialog(),
    );
    if (result == true) {
      await _load();
    }
  }

  Future<void> _openEditSourceDialog(AdminSourceModel source) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => _SourceEditorDialog(source: source),
    );
    if (result == true) {
      await _load();
    }
  }

  Future<void> _runSourceAction(
    AdminSourceModel source, {
    required bool testOnly,
  }) async {
    try {
      final run = testOnly
          ? await _remote.testSource(source.id)
          : await _remote.runSource(source.id);
      if (!mounted) {
        return;
      }
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(testOnly ? 'Test result' : 'Source run complete'),
          content: SizedBox(
            width: 420,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Source: ${source.name}'),
                const SizedBox(height: 8),
                Text(
                  'Status: ${run.status} - fetched ${run.fetchedCount} - inserted ${run.insertedCount} - deduped ${run.dedupedCount}',
                ),
                if (run.sources.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  ...run.sources.map(
                    (item) => Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Text(
                        '${item.sourceName}: ${item.status}${item.errors.isEmpty ? '' : ' - ${item.errors.join('; ')}'}',
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Close'),
            ),
          ],
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

  Future<void> _toggleSourceEnabled(AdminSourceModel source) async {
    final disable = source.enabled;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(disable ? 'Disable source?' : 'Enable source?'),
        content: Text(
          disable
              ? 'This will stop ${source.name} from participating in scheduled and manual ingestion until it is enabled again.'
              : 'This will allow ${source.name} to participate in ingestion again.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(disable ? 'Disable' : 'Enable'),
          ),
        ],
      ),
    );
    if (confirmed != true) {
      return;
    }

    try {
      await _remote.updateSource(sourceId: source.id, enabled: !source.enabled);
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            source.enabled
                ? '${source.name} disabled.'
                : '${source.name} enabled.',
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
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Source Registry',
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Manage RSS and API source definitions, polling cadence, and notes for the newsroom.',
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: const Color(0xFF4F4A43),
                      ),
                    ),
                  ],
                ),
              ),
              FilledButton.icon(
                onPressed: _openCreateSourceDialog,
                icon: const Icon(Icons.add_rounded),
                label: const Text('Add source'),
              ),
            ],
          ),
          const SizedBox(height: 18),
          if (_loading)
            const Padding(
              padding: EdgeInsets.only(top: 80),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_errorMessage != null)
            _StateCard(
              title: 'Could not load sources',
              message: _errorMessage!,
              actionLabel: 'Try again',
              onPressed: _load,
            )
          else if (_sources.isEmpty)
            _StateCard(
              title: 'No sources configured',
              message:
                  'Add the first source to start managing ingestion inventory from the dashboard.',
              actionLabel: 'Add source',
              onPressed: _openCreateSourceDialog,
            )
          else
            ..._sources.map(
              (source) => Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: _SourceCard(
                  source: source,
                  onEdit: () => _openEditSourceDialog(source),
                  onTest: () => _runSourceAction(source, testOnly: true),
                  onRun: () => _runSourceAction(source, testOnly: false),
                  onToggleEnabled: () => _toggleSourceEnabled(source),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _SourceCard extends StatelessWidget {
  const _SourceCard({
    required this.source,
    required this.onEdit,
    required this.onTest,
    required this.onRun,
    required this.onToggleEnabled,
  });

  final AdminSourceModel source;
  final VoidCallback onEdit;
  final VoidCallback onTest;
  final VoidCallback onRun;
  final VoidCallback onToggleEnabled;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFCFC3B0), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF12261C).withValues(alpha: 0.04),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
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
                          _Badge(
                            label: source.enabled ? 'Enabled' : 'Disabled',
                            color: source.enabled
                                ? const Color(0xFF0F766E)
                                : const Color(0xFF6B7280),
                          ),
                          _Badge(
                            label: source.configured
                                ? 'Configured'
                                : 'Needs setup',
                            color: source.configured
                                ? const Color(0xFF2563EB)
                                : const Color(0xFFB7791F),
                          ),
                          _Badge(
                            label: source.type,
                            color: const Color(0xFF7C3AED),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        source.name,
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '${source.id} - Poll ${source.pollIntervalSeconds}s${source.country?.trim().isNotEmpty == true ? ' - ${source.country}' : ''}',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: const Color(0xFF4F4A43),
                        ),
                      ),
                    ],
                  ),
                ),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  alignment: WrapAlignment.end,
                  children: [
                    OutlinedButton.icon(
                      onPressed: onTest,
                      icon: const Icon(Icons.science_outlined),
                      label: const Text('Test'),
                    ),
                    FilledButton.tonalIcon(
                      onPressed: onRun,
                      icon: const Icon(Icons.play_arrow_rounded),
                      label: const Text('Run'),
                    ),
                    OutlinedButton.icon(
                      onPressed: onEdit,
                      icon: const Icon(Icons.edit_outlined),
                      label: const Text('Edit'),
                    ),
                    OutlinedButton.icon(
                      onPressed: onToggleEnabled,
                      icon: Icon(
                        source.enabled
                            ? Icons.pause_circle_outline_rounded
                            : Icons.play_circle_outline_rounded,
                      ),
                      label: Text(source.enabled ? 'Disable' : 'Enable'),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 14),
            if (source.feedUrl?.trim().isNotEmpty ?? false)
              Text(
                source.feedUrl!.trim(),
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            if (source.apiBaseUrl?.trim().isNotEmpty ?? false) ...[
              const SizedBox(height: 8),
              Text(
                source.apiBaseUrl!.trim(),
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ],
            if (source.notes?.trim().isNotEmpty ?? false) ...[
              const SizedBox(height: 10),
              Text(
                source.notes!.trim(),
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: const Color(0xFF4F4A43),
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
            const SizedBox(height: 12),
            Text(
              source.lastRunAt == null
                  ? 'No run recorded yet'
                  : 'Last run ${adminDateTimeLabel(source.lastRunAt!)}',
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: const Color(0xFF4F4A43)),
            ),
          ],
        ),
      ),
    );
  }
}

class _SourceEditorDialog extends StatefulWidget {
  const _SourceEditorDialog({this.source});

  final AdminSourceModel? source;

  @override
  State<_SourceEditorDialog> createState() => _SourceEditorDialogState();
}

class _SourceEditorDialogState extends State<_SourceEditorDialog> {
  final _formKey = GlobalKey<FormState>();
  final AdminRemoteDataSource _remote =
      InjectionContainer.sl<AdminRemoteDataSource>();

  late final TextEditingController _idController;
  late final TextEditingController _nameController;
  late final TextEditingController _typeController;
  late final TextEditingController _countryController;
  late final TextEditingController _feedUrlController;
  late final TextEditingController _apiBaseUrlController;
  late final TextEditingController _pollController;
  late final TextEditingController _notesController;

  late bool _enabled;
  bool _saving = false;

  bool get _isEditing => widget.source != null;

  @override
  void initState() {
    super.initState();
    final source = widget.source;
    _idController = TextEditingController(text: source?.id ?? '');
    _nameController = TextEditingController(text: source?.name ?? '');
    _typeController = TextEditingController(text: source?.type ?? 'rss');
    _countryController = TextEditingController(text: source?.country ?? '');
    _feedUrlController = TextEditingController(text: source?.feedUrl ?? '');
    _apiBaseUrlController = TextEditingController(
      text: source?.apiBaseUrl ?? '',
    );
    _pollController = TextEditingController(
      text: '${source?.pollIntervalSeconds ?? 900}',
    );
    _notesController = TextEditingController(text: source?.notes ?? '');
    _enabled = source?.enabled ?? true;
  }

  @override
  void dispose() {
    _idController.dispose();
    _nameController.dispose();
    _typeController.dispose();
    _countryController.dispose();
    _feedUrlController.dispose();
    _apiBaseUrlController.dispose();
    _pollController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    setState(() => _saving = true);
    try {
      final poll = int.parse(_pollController.text.trim());
      if (_isEditing) {
        await _remote.updateSource(
          sourceId: widget.source!.id,
          name: _nameController.text,
          type: _typeController.text,
          country: _countryController.text,
          enabled: _enabled,
          feedUrl: _feedUrlController.text,
          apiBaseUrl: _apiBaseUrlController.text,
          pollIntervalSeconds: poll,
          notes: _notesController.text,
        );
      } else {
        await _remote.createSource(
          id: _idController.text,
          name: _nameController.text,
          type: _typeController.text,
          country: _countryController.text,
          enabled: _enabled,
          feedUrl: _feedUrlController.text,
          apiBaseUrl: _apiBaseUrlController.text,
          pollIntervalSeconds: poll,
          notes: _notesController.text,
        );
      }
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
      title: Text(_isEditing ? 'Edit source' : 'Add source'),
      content: SizedBox(
        width: 540,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: _idController,
                  enabled: !_isEditing,
                  decoration: const InputDecoration(labelText: 'Source ID'),
                  validator: (value) => (value ?? '').trim().isEmpty
                      ? 'Source ID is required.'
                      : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _nameController,
                  decoration: const InputDecoration(labelText: 'Source Name'),
                  validator: (value) => (value ?? '').trim().isEmpty
                      ? 'Source name is required.'
                      : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _typeController,
                  decoration: const InputDecoration(labelText: 'Type'),
                  validator: (value) =>
                      (value ?? '').trim().isEmpty ? 'Type is required.' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _countryController,
                  decoration: const InputDecoration(labelText: 'Country'),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _feedUrlController,
                  decoration: const InputDecoration(labelText: 'Feed URL'),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _apiBaseUrlController,
                  decoration: const InputDecoration(labelText: 'API Base URL'),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _pollController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Poll Interval Seconds',
                  ),
                  validator: (value) {
                    final parsed = int.tryParse((value ?? '').trim());
                    if (parsed == null || parsed < 60) {
                      return 'Enter a valid interval of at least 60 seconds.';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _notesController,
                  minLines: 3,
                  maxLines: 5,
                  decoration: const InputDecoration(labelText: 'Notes'),
                ),
                const SizedBox(height: 12),
                SwitchListTile.adaptive(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Enabled'),
                  value: _enabled,
                  onChanged: (value) => setState(() => _enabled = value),
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
          child: Text(
            _saving
                ? 'Saving...'
                : (_isEditing ? 'Save changes' : 'Create source'),
          ),
        ),
      ],
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
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
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 460),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: const Color(0xFFCFC3B0), width: 1.2),
          ),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 10),
                Text(
                  message,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 18),
                FilledButton(onPressed: onPressed, child: Text(actionLabel)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
