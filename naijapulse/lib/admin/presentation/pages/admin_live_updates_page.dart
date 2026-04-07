import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:naijapulse/admin/data/datasource/admin_remote_datasource.dart';
import 'package:naijapulse/admin/presentation/admin_theme.dart';
import 'package:naijapulse/core/di/injection_container.dart';
import 'package:naijapulse/core/error/failures.dart';
import 'package:naijapulse/core/routing/app_router.dart';
import 'package:naijapulse/features/live_updates/data/datasource/remote/live_updates_remote_datasource.dart';
import 'package:naijapulse/features/live_updates/data/models/live_update_models.dart';
import 'package:naijapulse/features/news/data/models/news_article_model.dart';
import 'package:naijapulse/features/news/presentation/widgets/news_time.dart';
import 'package:naijapulse/features/polls/data/models/poll_model.dart';

class AdminLiveUpdatesPage extends StatefulWidget {
  const AdminLiveUpdatesPage({super.key});

  @override
  State<AdminLiveUpdatesPage> createState() => _AdminLiveUpdatesPageState();
}

class _AdminLiveUpdatesPageState extends State<AdminLiveUpdatesPage> {
  static const List<String> _statusFilters = <String>[
    'all',
    'draft',
    'live',
    'ended',
    'archived',
  ];

  final LiveUpdatesRemoteDataSource _liveRemote =
      InjectionContainer.sl<LiveUpdatesRemoteDataSource>();
  final AdminRemoteDataSource _adminRemote =
      InjectionContainer.sl<AdminRemoteDataSource>();

  List<LiveUpdatePageSummaryModel> _pages =
      const <LiveUpdatePageSummaryModel>[];
  LiveUpdatePageDetailModel? _selectedDetail;
  List<NewsArticleModel> _articles = const <NewsArticleModel>[];
  List<PollModel> _polls = const <PollModel>[];
  String _statusFilter = 'all';
  bool _loading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load({String? selectedPageId}) async {
    setState(() {
      _loading = true;
      _errorMessage = null;
    });
    try {
      final pageResults = await Future.wait<dynamic>([
        _liveRemote.fetchAdminPages(
          status: _statusFilter == 'all' ? null : _statusFilter,
        ),
        _adminRemote.fetchAdminArticlesPage(
          status: 'published',
          offset: 0,
          limit: 30,
        ),
        _adminRemote.fetchActivePolls(),
      ]);
      final pages = pageResults[0] as List<LiveUpdatePageSummaryModel>;
      final articlePage = pageResults[1];
      final polls = pageResults[2] as List<PollModel>;
      final requestedSelectedId = selectedPageId ?? _selectedDetail?.page.id;
      final nextSelectedId =
          requestedSelectedId != null &&
              pages.any((page) => page.id == requestedSelectedId)
          ? requestedSelectedId
          : (pages.isNotEmpty ? pages.first.id : null);
      LiveUpdatePageDetailModel? nextDetail;
      if (nextSelectedId != null) {
        nextDetail = await _liveRemote.fetchAdminPage(nextSelectedId);
      }
      if (!mounted) {
        return;
      }
      setState(() {
        _pages = pages;
        _articles = articlePage.items as List<NewsArticleModel>;
        _polls = polls;
        _selectedDetail = nextDetail;
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

  Future<void> _selectPage(String pageId) async {
    setState(() {
      _loading = true;
      _errorMessage = null;
    });
    try {
      final detail = await _liveRemote.fetchAdminPage(pageId);
      if (!mounted) {
        return;
      }
      setState(() => _selectedDetail = detail);
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

  Future<void> _openCreatePageDialog() async {
    final created = await showDialog<_LivePageFormResult>(
      context: context,
      builder: (context) => const _LivePageEditorDialog(),
    );
    if (created == null) {
      return;
    }
    try {
      final detail = await _liveRemote.createAdminPage(
        title: created.title,
        summary: created.summary,
        category: created.category,
        slug: created.slug,
        heroKicker: created.heroKicker,
        coverImageUrl: created.coverImageUrl,
        status: created.status,
        isFeatured: created.isFeatured,
        isBreaking: created.isBreaking,
      );
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Live updates page created.')),
      );
      await _load(selectedPageId: detail.page.id);
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(mapFailure(error).message)));
    }
  }

  Future<void> _openEditPageDialog() async {
    final detail = _selectedDetail;
    if (detail == null) {
      return;
    }
    final updated = await showDialog<_LivePageFormResult>(
      context: context,
      builder: (context) => _LivePageEditorDialog(initial: detail.page),
    );
    if (updated == null) {
      return;
    }
    try {
      final nextDetail = await _liveRemote.updateAdminPage(
        pageId: detail.page.id,
        title: updated.title,
        summary: updated.summary,
        category: updated.category,
        slug: updated.slug,
        heroKicker: updated.heroKicker,
        coverImageUrl: updated.coverImageUrl,
        status: updated.status,
        isFeatured: updated.isFeatured,
        isBreaking: updated.isBreaking,
      );
      if (!mounted) {
        return;
      }
      setState(() => _selectedDetail = nextDetail);
      await _load(selectedPageId: nextDetail.page.id);
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(mapFailure(error).message)));
    }
  }

  Future<void> _openCreateEntryDialog() async {
    final detail = _selectedDetail;
    if (detail == null) {
      return;
    }
    final result = await showDialog<_LiveEntryFormResult>(
      context: context,
      builder: (context) =>
          _LiveEntryEditorDialog(articles: _articles, polls: _polls),
    );
    if (result == null) {
      return;
    }
    try {
      final nextDetail = await _liveRemote.createAdminEntry(
        pageId: detail.page.id,
        blockType: result.blockType,
        headline: result.headline,
        body: result.body,
        imageUrl: result.imageUrl,
        imageCaption: result.imageCaption,
        linkedArticleId: result.linkedArticleId,
        linkedPollId: result.linkedPollId,
        isPinned: result.isPinned,
        isVisible: result.isVisible,
      );
      if (!mounted) {
        return;
      }
      setState(() => _selectedDetail = nextDetail);
      await _load(selectedPageId: nextDetail.page.id);
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(mapFailure(error).message)));
    }
  }

  Future<void> _openEditEntryDialog(LiveUpdateEntryModel entry) async {
    final detail = _selectedDetail;
    if (detail == null) {
      return;
    }
    final result = await showDialog<_LiveEntryFormResult>(
      context: context,
      builder: (context) => _LiveEntryEditorDialog(
        initial: entry,
        articles: _articles,
        polls: _polls,
      ),
    );
    if (result == null) {
      return;
    }
    try {
      final nextDetail = await _liveRemote.updateAdminEntry(
        entryId: entry.id,
        headline: result.headline,
        body: result.body,
        imageUrl: result.imageUrl,
        imageCaption: result.imageCaption,
        linkedArticleId: result.linkedArticleId,
        linkedPollId: result.linkedPollId,
        isPinned: result.isPinned,
        isVisible: result.isVisible,
      );
      if (!mounted) {
        return;
      }
      setState(() => _selectedDetail = nextDetail);
      await _load(selectedPageId: detail.page.id);
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(mapFailure(error).message)));
    }
  }

  Future<void> _toggleEntryVisibility(LiveUpdateEntryModel entry) async {
    final detail = _selectedDetail;
    if (detail == null) {
      return;
    }
    try {
      final nextDetail = await _liveRemote.updateAdminEntry(
        entryId: entry.id,
        isVisible: !entry.isVisible,
      );
      if (!mounted) {
        return;
      }
      setState(() => _selectedDetail = nextDetail);
      await _load(selectedPageId: detail.page.id);
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(mapFailure(error).message)));
    }
  }

  Future<void> _toggleEntryPinned(LiveUpdateEntryModel entry) async {
    final detail = _selectedDetail;
    if (detail == null) {
      return;
    }
    try {
      final nextDetail = await _liveRemote.updateAdminEntry(
        entryId: entry.id,
        isPinned: !entry.isPinned,
      );
      if (!mounted) {
        return;
      }
      setState(() => _selectedDetail = nextDetail);
      await _load(selectedPageId: detail.page.id);
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
    final detail = _selectedDetail;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Live Updates',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Create event pages, post timeline blocks, and keep public coverage updating in real time.',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AdminTheme.textMuted,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16),
            SizedBox(
              width: 160,
              child: DropdownButtonFormField<String>(
                initialValue: _statusFilter,
                decoration: const InputDecoration(labelText: 'Filter'),
                items: _statusFilters
                    .map(
                      (value) => DropdownMenuItem<String>(
                        value: value,
                        child: Text(
                          value == 'all' ? 'All statuses' : _titleCase(value),
                        ),
                      ),
                    )
                    .toList(growable: false),
                onChanged: (value) {
                  if (value == null) {
                    return;
                  }
                  setState(() => _statusFilter = value);
                  _load();
                },
              ),
            ),
            const SizedBox(width: 12),
            FilledButton.icon(
              onPressed: _openCreatePageDialog,
              icon: const Icon(Icons.add_circle_outline_rounded),
              label: const Text('New live page'),
            ),
          ],
        ),
        const SizedBox(height: 20),
        Expanded(
          child: Row(
            children: [
              SizedBox(width: 320, child: Card(child: _buildPageList())),
              const SizedBox(width: 20),
              Expanded(child: Card(child: _buildEditorPane(detail))),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPageList() {
    if (_loading && _pages.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_errorMessage != null && _pages.isEmpty) {
      return _AdminEmptyState(
        title: 'Live pages could not be loaded',
        message: _errorMessage!,
        onAction: _load,
      );
    }
    if (_pages.isEmpty) {
      return _AdminEmptyState(
        title: 'No live coverage pages yet',
        message:
            'Create the first live event page to start editorial coverage.',
        actionLabel: 'Create page',
        onAction: _openCreatePageDialog,
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemBuilder: (context, index) {
        final page = _pages[index];
        final selected = page.id == _selectedDetail?.page.id;
        return InkWell(
          onTap: () => _selectPage(page.id),
          borderRadius: BorderRadius.circular(18),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: selected ? const Color(0xFFEAF4EF) : AdminTheme.surfaceAlt,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: selected ? AdminTheme.accent : AdminTheme.cardBorder,
                width: selected ? 1.4 : 1.0,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _StatusPill(
                      label: _titleCase(page.status),
                      active: page.status == 'live',
                    ),
                    if (page.isBreaking) const _MiniPill(label: 'Breaking'),
                    if (page.isFeatured) const _MiniPill(label: 'Featured'),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  page.title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: AdminTheme.textStrong,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  page.summary,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AdminTheme.textMuted,
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  '${page.category} | ${page.entryCount} entries',
                  style: const TextStyle(
                    color: AdminTheme.textBase,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (page.lastPublishedEntryAt != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    'Updated ${adminDateTimeLabel(page.lastPublishedEntryAt!)}',
                    style: const TextStyle(color: AdminTheme.textMuted),
                  ),
                ],
              ],
            ),
          ),
        );
      },
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemCount: _pages.length,
    );
  }

  Widget _buildEditorPane(LiveUpdatePageDetailModel? detail) {
    if (_loading && detail == null) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_errorMessage != null && detail == null) {
      return _AdminEmptyState(
        title: 'Editor unavailable',
        message: _errorMessage!,
        onAction: _load,
      );
    }
    if (detail == null) {
      return _AdminEmptyState(
        title: 'Select a live page',
        message:
            'Choose a page from the left to edit its timeline and metadata.',
        onAction: _load,
      );
    }
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        _LivePageHeaderCard(
          detail: detail,
          onEditPage: _openEditPageDialog,
          onAddEntry: _openCreateEntryDialog,
          onOpenPreview: () =>
              context.push(AppRouter.liveUpdateDetailPath(detail.page.slug)),
        ),
        const SizedBox(height: 18),
        Text(
          'Timeline',
          style: Theme.of(
            context,
          ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 12),
        if (detail.entries.isEmpty)
          _AdminEmptyState(
            title: 'No timeline blocks yet',
            message:
                'Add the first update block to start the public live timeline.',
            actionLabel: 'Add update',
            onAction: _openCreateEntryDialog,
          )
        else
          ...detail.entries.map(
            (entry) => Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: _LiveEntryAdminCard(
                entry: entry,
                onEdit: () => _openEditEntryDialog(entry),
                onTogglePinned: () => _toggleEntryPinned(entry),
                onToggleVisible: () => _toggleEntryVisibility(entry),
              ),
            ),
          ),
      ],
    );
  }
}

class _LivePageHeaderCard extends StatelessWidget {
  const _LivePageHeaderCard({
    required this.detail,
    required this.onEditPage,
    required this.onAddEntry,
    required this.onOpenPreview,
  });

  final LiveUpdatePageDetailModel detail;
  final VoidCallback onEditPage;
  final VoidCallback onAddEntry;
  final VoidCallback onOpenPreview;

  @override
  Widget build(BuildContext context) {
    final page = detail.page;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AdminTheme.surfaceAlt,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AdminTheme.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 10,
            runSpacing: 10,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              _StatusPill(label: _titleCase(page.status), active: page.isLive),
              if (page.isBreaking) const _MiniPill(label: 'Breaking'),
              if (page.isFeatured) const _MiniPill(label: 'Featured'),
              _MiniPill(label: page.category),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            page.title,
            style: Theme.of(
              context,
            ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          Text(
            page.summary,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: AdminTheme.textMuted),
          ),
          if (page.heroKicker?.trim().isNotEmpty ?? false) ...[
            const SizedBox(height: 10),
            Text(
              page.heroKicker!,
              style: Theme.of(
                context,
              ).textTheme.labelLarge?.copyWith(color: AdminTheme.accentDark),
            ),
          ],
          const SizedBox(height: 14),
          Wrap(
            spacing: 12,
            runSpacing: 10,
            children: [
              if (page.lastPublishedEntryAt != null)
                Text(
                  'Latest: ${adminDateTimeLabel(page.lastPublishedEntryAt!)}',
                  style: const TextStyle(color: AdminTheme.textMuted),
                ),
              Text(
                '${page.entryCount} blocks',
                style: const TextStyle(color: AdminTheme.textMuted),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              FilledButton.icon(
                onPressed: onAddEntry,
                icon: const Icon(Icons.playlist_add_rounded),
                label: const Text('Add update'),
              ),
              OutlinedButton.icon(
                onPressed: onEditPage,
                icon: const Icon(Icons.edit_outlined),
                label: const Text('Edit page'),
              ),
              OutlinedButton.icon(
                onPressed: onOpenPreview,
                icon: const Icon(Icons.open_in_new_rounded),
                label: const Text('Preview'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _LiveEntryAdminCard extends StatelessWidget {
  const _LiveEntryAdminCard({
    required this.entry,
    required this.onEdit,
    required this.onTogglePinned,
    required this.onToggleVisible,
  });

  final LiveUpdateEntryModel entry;
  final VoidCallback onEdit;
  final VoidCallback onTogglePinned;
  final VoidCallback onToggleVisible;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: entry.isVisible ? Colors.white : const Color(0xFFF2ECE3),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: entry.isPinned ? AdminTheme.accent : AdminTheme.cardBorder,
          width: entry.isPinned ? 1.3 : 1.0,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _MiniPill(
                label: _titleCase(entry.blockType.replaceAll('_', ' ')),
              ),
              if (entry.isPinned) const _MiniPill(label: 'Pinned'),
              if (!entry.isVisible) const _MiniPill(label: 'Hidden'),
              _MiniPill(label: adminDateTimeLabel(entry.publishedAt)),
            ],
          ),
          const SizedBox(height: 10),
          if (entry.headline?.trim().isNotEmpty ?? false)
            Text(
              entry.headline!,
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
            ),
          if (entry.body?.trim().isNotEmpty ?? false) ...[
            const SizedBox(height: 6),
            Text(
              entry.body!,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: AdminTheme.textBase),
            ),
          ],
          if (entry.imageUrl?.trim().isNotEmpty ?? false) ...[
            const SizedBox(height: 10),
            Text(
              'Image: ${entry.imageUrl}',
              style: const TextStyle(color: AdminTheme.textMuted),
            ),
          ],
          if (entry.linkedArticle != null) ...[
            const SizedBox(height: 10),
            Text(
              'Article: ${entry.linkedArticle!.title}',
              style: const TextStyle(
                color: AdminTheme.textStrong,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
          if (entry.linkedPoll != null) ...[
            const SizedBox(height: 10),
            Text(
              'Poll: ${entry.linkedPoll!.question}',
              style: const TextStyle(
                color: AdminTheme.textStrong,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
          const SizedBox(height: 14),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              OutlinedButton.icon(
                onPressed: onEdit,
                icon: const Icon(Icons.edit_outlined),
                label: const Text('Edit'),
              ),
              OutlinedButton.icon(
                onPressed: onTogglePinned,
                icon: Icon(
                  entry.isPinned ? Icons.push_pin : Icons.push_pin_outlined,
                ),
                label: Text(entry.isPinned ? 'Unpin' : 'Pin'),
              ),
              OutlinedButton.icon(
                onPressed: onToggleVisible,
                icon: Icon(
                  entry.isVisible
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                ),
                label: Text(entry.isVisible ? 'Hide' : 'Show'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _AdminEmptyState extends StatelessWidget {
  const _AdminEmptyState({
    required this.title,
    required this.message,
    required this.onAction,
    this.actionLabel = 'Refresh',
  });

  final String title;
  final String message;
  final String actionLabel;
  final Future<void> Function() onAction;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.timeline_rounded,
              size: 42,
              color: AdminTheme.accentDark,
            ),
            const SizedBox(height: 12),
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
            FilledButton(onPressed: () => onAction(), child: Text(actionLabel)),
          ],
        ),
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.label, required this.active});

  final String label;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final color = active ? AdminTheme.accentDark : AdminTheme.textMuted;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Text(
        label,
        style: TextStyle(color: color, fontWeight: FontWeight.w800),
      ),
    );
  }
}

class _MiniPill extends StatelessWidget {
  const _MiniPill({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AdminTheme.cardBorder),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: AdminTheme.textBase,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _LivePageEditorDialog extends StatefulWidget {
  const _LivePageEditorDialog({this.initial});

  final LiveUpdatePageSummaryModel? initial;

  @override
  State<_LivePageEditorDialog> createState() => _LivePageEditorDialogState();
}

class _LivePageEditorDialogState extends State<_LivePageEditorDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _titleController;
  late final TextEditingController _summaryController;
  late final TextEditingController _slugController;
  late final TextEditingController _heroKickerController;
  late final TextEditingController _categoryController;
  late final TextEditingController _coverImageController;
  late String _status;
  late bool _isFeatured;
  late bool _isBreaking;

  @override
  void initState() {
    super.initState();
    final initial = widget.initial;
    _titleController = TextEditingController(text: initial?.title ?? '');
    _summaryController = TextEditingController(text: initial?.summary ?? '');
    _slugController = TextEditingController(text: initial?.slug ?? '');
    _heroKickerController = TextEditingController(
      text: initial?.heroKicker ?? '',
    );
    _categoryController = TextEditingController(text: initial?.category ?? '');
    _coverImageController = TextEditingController(
      text: initial?.coverImageUrl ?? '',
    );
    _status = initial?.status ?? 'draft';
    _isFeatured = initial?.isFeatured ?? false;
    _isBreaking = initial?.isBreaking ?? false;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _summaryController.dispose();
    _slugController.dispose();
    _heroKickerController.dispose();
    _categoryController.dispose();
    _coverImageController.dispose();
    super.dispose();
  }

  void _submit() {
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }
    Navigator.of(context).pop(
      _LivePageFormResult(
        title: _titleController.text.trim(),
        summary: _summaryController.text.trim(),
        slug: _slugController.text.trim(),
        heroKicker: _heroKickerController.text.trim(),
        category: _categoryController.text.trim(),
        coverImageUrl: _coverImageController.text.trim(),
        status: _status,
        isFeatured: _isFeatured,
        isBreaking: _isBreaking,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(
        widget.initial == null ? 'Create live page' : 'Edit live page',
      ),
      content: SizedBox(
        width: 560,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: _titleController,
                  decoration: const InputDecoration(labelText: 'Title'),
                  validator: (value) => (value?.trim().isEmpty ?? true)
                      ? 'Title is required.'
                      : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _summaryController,
                  maxLines: 4,
                  decoration: const InputDecoration(labelText: 'Summary'),
                  validator: (value) => (value?.trim().length ?? 0) < 8
                      ? 'Add a fuller summary.'
                      : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _slugController,
                  decoration: const InputDecoration(labelText: 'Slug'),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _heroKickerController,
                  decoration: const InputDecoration(labelText: 'Hero kicker'),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _categoryController,
                  decoration: const InputDecoration(labelText: 'Category'),
                  validator: (value) => (value?.trim().isEmpty ?? true)
                      ? 'Category is required.'
                      : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _coverImageController,
                  decoration: const InputDecoration(
                    labelText: 'Cover image URL',
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: _status,
                  decoration: const InputDecoration(labelText: 'Status'),
                  items: const ['draft', 'live', 'ended', 'archived']
                      .map(
                        (value) => DropdownMenuItem<String>(
                          value: value,
                          child: Text(_titleCase(value)),
                        ),
                      )
                      .toList(growable: false),
                  onChanged: (value) {
                    if (value != null) {
                      setState(() => _status = value);
                    }
                  },
                ),
                const SizedBox(height: 12),
                SwitchListTile(
                  value: _isFeatured,
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Featured'),
                  onChanged: (value) => setState(() => _isFeatured = value),
                ),
                SwitchListTile(
                  value: _isBreaking,
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Breaking'),
                  onChanged: (value) => setState(() => _isBreaking = value),
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _submit,
          child: Text(widget.initial == null ? 'Create page' : 'Save changes'),
        ),
      ],
    );
  }
}

class _LiveEntryEditorDialog extends StatefulWidget {
  const _LiveEntryEditorDialog({
    required this.articles,
    required this.polls,
    this.initial,
  });

  final LiveUpdateEntryModel? initial;
  final List<NewsArticleModel> articles;
  final List<PollModel> polls;

  @override
  State<_LiveEntryEditorDialog> createState() => _LiveEntryEditorDialogState();
}

class _LiveEntryEditorDialogState extends State<_LiveEntryEditorDialog> {
  final _formKey = GlobalKey<FormState>();
  late String _blockType;
  late final TextEditingController _headlineController;
  late final TextEditingController _bodyController;
  late final TextEditingController _imageUrlController;
  late final TextEditingController _imageCaptionController;
  String? _selectedArticleId;
  String? _selectedPollId;
  late bool _isPinned;
  late bool _isVisible;

  bool get _showBody => _blockType == 'text' || _blockType == 'milestone';
  bool get _showImageFields => _blockType == 'image';
  bool get _showArticlePicker => _blockType == 'article_embed';
  bool get _showPollPicker => _blockType == 'poll_embed';

  @override
  void initState() {
    super.initState();
    final initial = widget.initial;
    _blockType = initial?.blockType ?? 'text';
    _headlineController = TextEditingController(text: initial?.headline ?? '');
    _bodyController = TextEditingController(text: initial?.body ?? '');
    _imageUrlController = TextEditingController(text: initial?.imageUrl ?? '');
    _imageCaptionController = TextEditingController(
      text: initial?.imageCaption ?? '',
    );
    _selectedArticleId = initial?.linkedArticle?.id;
    _selectedPollId = initial?.linkedPoll?.id;
    _isPinned = initial?.isPinned ?? false;
    _isVisible = initial?.isVisible ?? true;
  }

  @override
  void dispose() {
    _headlineController.dispose();
    _bodyController.dispose();
    _imageUrlController.dispose();
    _imageCaptionController.dispose();
    super.dispose();
  }

  void _submit() {
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }
    Navigator.of(context).pop(
      _LiveEntryFormResult(
        blockType: _blockType,
        headline: _headlineController.text.trim(),
        body: _bodyController.text.trim(),
        imageUrl: _imageUrlController.text.trim(),
        imageCaption: _imageCaptionController.text.trim(),
        linkedArticleId: _selectedArticleId,
        linkedPollId: _selectedPollId,
        isPinned: _isPinned,
        isVisible: _isVisible,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(
        widget.initial == null ? 'Add update block' : 'Edit update block',
      ),
      content: SizedBox(
        width: 560,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  initialValue: _blockType,
                  decoration: const InputDecoration(labelText: 'Block type'),
                  items:
                      const [
                            'text',
                            'image',
                            'article_embed',
                            'poll_embed',
                            'milestone',
                          ]
                          .map(
                            (value) => DropdownMenuItem<String>(
                              value: value,
                              child: Text(
                                _titleCase(value.replaceAll('_', ' ')),
                              ),
                            ),
                          )
                          .toList(growable: false),
                  onChanged: widget.initial != null
                      ? null
                      : (value) {
                          if (value != null) {
                            setState(() => _blockType = value);
                          }
                        },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _headlineController,
                  decoration: const InputDecoration(labelText: 'Headline'),
                  validator: (value) {
                    if (_blockType == 'milestone' &&
                        (value?.trim().isEmpty ?? true)) {
                      return 'Milestones require a headline.';
                    }
                    return null;
                  },
                ),
                if (_showBody) ...[
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _bodyController,
                    maxLines: 5,
                    decoration: const InputDecoration(labelText: 'Body'),
                    validator: (value) {
                      if (_blockType == 'text' &&
                          (value?.trim().isEmpty ?? true)) {
                        return 'Text updates need body content.';
                      }
                      return null;
                    },
                  ),
                ],
                if (_showImageFields) ...[
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _imageUrlController,
                    decoration: const InputDecoration(labelText: 'Image URL'),
                    validator: (value) => (value?.trim().isEmpty ?? true)
                        ? 'Image blocks require an image URL.'
                        : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _imageCaptionController,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      labelText: 'Image caption',
                    ),
                  ),
                ],
                if (_showArticlePicker) ...[
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: _selectedArticleId,
                    decoration: const InputDecoration(
                      labelText: 'Linked article',
                    ),
                    items: widget.articles
                        .map(
                          (article) => DropdownMenuItem<String>(
                            value: article.id,
                            child: Text(
                              article.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        )
                        .toList(growable: false),
                    onChanged: (value) =>
                        setState(() => _selectedArticleId = value),
                    validator: (value) => (value?.trim().isEmpty ?? true)
                        ? 'Choose an article to embed.'
                        : null,
                  ),
                ],
                if (_showPollPicker) ...[
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: _selectedPollId,
                    decoration: const InputDecoration(labelText: 'Linked poll'),
                    items: widget.polls
                        .map(
                          (poll) => DropdownMenuItem<String>(
                            value: poll.id,
                            child: Text(
                              poll.question,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        )
                        .toList(growable: false),
                    onChanged: (value) =>
                        setState(() => _selectedPollId = value),
                    validator: (value) => (value?.trim().isEmpty ?? true)
                        ? 'Choose a poll to embed.'
                        : null,
                  ),
                ],
                const SizedBox(height: 12),
                SwitchListTile(
                  value: _isPinned,
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Pinned'),
                  onChanged: (value) => setState(() => _isPinned = value),
                ),
                SwitchListTile(
                  value: _isVisible,
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Visible to readers'),
                  onChanged: (value) => setState(() => _isVisible = value),
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _submit,
          child: Text(widget.initial == null ? 'Add block' : 'Save block'),
        ),
      ],
    );
  }
}

class _LivePageFormResult {
  const _LivePageFormResult({
    required this.title,
    required this.summary,
    required this.category,
    required this.status,
    required this.isFeatured,
    required this.isBreaking,
    this.slug,
    this.heroKicker,
    this.coverImageUrl,
  });

  final String title;
  final String summary;
  final String category;
  final String status;
  final bool isFeatured;
  final bool isBreaking;
  final String? slug;
  final String? heroKicker;
  final String? coverImageUrl;
}

class _LiveEntryFormResult {
  const _LiveEntryFormResult({
    required this.blockType,
    required this.isPinned,
    required this.isVisible,
    this.headline,
    this.body,
    this.imageUrl,
    this.imageCaption,
    this.linkedArticleId,
    this.linkedPollId,
  });

  final String blockType;
  final bool isPinned;
  final bool isVisible;
  final String? headline;
  final String? body;
  final String? imageUrl;
  final String? imageCaption;
  final String? linkedArticleId;
  final String? linkedPollId;
}

String _titleCase(String value) {
  return value
      .split(RegExp(r'[\s_-]+'))
      .where((word) => word.isNotEmpty)
      .map((word) => '${word[0].toUpperCase()}${word.substring(1)}')
      .join(' ');
}
