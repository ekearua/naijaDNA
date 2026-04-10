import 'package:flutter/material.dart';
import 'package:naijapulse/admin/data/models/admin_models.dart';
import 'package:go_router/go_router.dart';
import 'package:naijapulse/admin/data/datasource/admin_remote_datasource.dart';
import 'package:naijapulse/admin/presentation/widgets/homepage_quick_actions.dart';
import 'package:naijapulse/core/di/injection_container.dart';
import 'package:naijapulse/core/error/failures.dart';
import 'package:naijapulse/core/routing/app_router.dart';
import 'package:naijapulse/core/utils/content_text.dart';
import 'package:naijapulse/features/news/domain/entities/news_article.dart';
import 'package:naijapulse/features/news/presentation/widgets/news_time.dart';

class AdminArticlesManagementPage extends StatefulWidget {
  const AdminArticlesManagementPage({super.key});

  @override
  State<AdminArticlesManagementPage> createState() =>
      _AdminArticlesManagementPageState();
}

class _AdminArticlesManagementPageState
    extends State<AdminArticlesManagementPage> {
  static const int _pageSize = 20;
  static const List<_ArticleQueueTabConfig> _queueTabs =
      <_ArticleQueueTabConfig>[
        _ArticleQueueTabConfig(
          key: 'needs_review',
          label: 'Needs Review',
          statuses: <String>['submitted', 'in_review', 'approved'],
          sort: 'updated_desc',
        ),
        _ArticleQueueTabConfig(
          key: 'drafts',
          label: 'Drafts',
          statuses: <String>['draft'],
          sort: 'updated_desc',
        ),
        _ArticleQueueTabConfig(
          key: 'live',
          label: 'Live / Published',
          statuses: <String>['published'],
          sort: 'published_desc',
        ),
        _ArticleQueueTabConfig(
          key: 'rejected',
          label: 'Rejected',
          statuses: <String>['rejected'],
          sort: 'updated_desc',
        ),
        _ArticleQueueTabConfig(
          key: 'archived',
          label: 'Archived',
          statuses: <String>['archived'],
          sort: 'updated_desc',
        ),
        _ArticleQueueTabConfig(
          key: 'all',
          label: 'All',
          statuses: <String>[],
          sort: 'updated_desc',
        ),
      ];

  final AdminRemoteDataSource _remote =
      InjectionContainer.sl<AdminRemoteDataSource>();
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _tagController = TextEditingController();
  final TextEditingController _draftArchiveController = TextEditingController(
    text: '30',
  );
  final TextEditingController _reviewArchiveController = TextEditingController(
    text: '14',
  );
  final TextEditingController _rejectedArchiveController =
      TextEditingController(text: '14');

  List<NewsArticle> _articles = const <NewsArticle>[];
  List<String> _availableSources = const <String>[];
  String _selectedTabKey = 'needs_review';
  String? _selectedSource;
  DateTime? _publishedFrom;
  DateTime? _publishedTo;
  AdminArticleQueueCountsModel _queueCounts =
      const AdminArticleQueueCountsModel(
        draft: 0,
        submitted: 0,
        inReview: 0,
        approved: 0,
        published: 0,
        rejected: 0,
        archived: 0,
      );
  int _offset = 0;
  int _total = 0;
  bool _loading = true;
  bool _settingsLoading = true;
  bool _settingsSaving = false;
  bool _runningArchiveNow = false;
  bool _autoArchiveEnabled = true;
  String? _queueSettingsNotice;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_handleSearchChanged);
    _tagController.addListener(_handleSearchChanged);
    _loadSources();
    _loadQueueSettings();
    _loadArticles();
  }

  @override
  void dispose() {
    _searchController.removeListener(_handleSearchChanged);
    _tagController.removeListener(_handleSearchChanged);
    _searchController.dispose();
    _tagController.dispose();
    _draftArchiveController.dispose();
    _reviewArchiveController.dispose();
    _rejectedArchiveController.dispose();
    super.dispose();
  }

  void _handleSearchChanged() {
    if (!mounted) {
      return;
    }
    setState(() {});
  }

  Future<void> _loadSources() async {
    try {
      final items = await _remote.fetchSources();
      if (!mounted) {
        return;
      }
      final names = <String>{
        ...items
            .map((item) => item.name.trim())
            .where((item) => item.isNotEmpty),
        ...items.map((item) => item.id.trim()).where((item) => item.isNotEmpty),
      }.toList()..sort();
      setState(() => _availableSources = names);
    } catch (_) {
      // Keep queue usable even if source metadata cannot be loaded.
    }
  }

  _ArticleQueueTabConfig get _selectedTab => _queueTabs.firstWhere(
    (item) => item.key == _selectedTabKey,
    orElse: () => _queueTabs.first,
  );

  Future<void> _loadQueueSettings() async {
    try {
      final response = await _remote.fetchArticleQueueSettings();
      if (!mounted) {
        return;
      }
      setState(() {
        _autoArchiveEnabled = response.settings.autoArchiveEnabled;
        _queueCounts = response.counts;
        _queueSettingsNotice = null;
        _draftArchiveController.text = response.settings.archiveDraftAfterDays
            .toString();
        _reviewArchiveController.text = response.settings.archiveReviewAfterDays
            .toString();
        _rejectedArchiveController.text = response
            .settings
            .archiveRejectedAfterDays
            .toString();
      });
    } catch (error) {
      final failure = mapFailure(error);
      AdminArticleQueueCountsModel? fallbackCounts;
      try {
        fallbackCounts = await _loadQueueCountsFallback();
      } catch (_) {
        fallbackCounts = null;
      }
      if (!mounted) {
        return;
      }
      setState(() {
        if (fallbackCounts != null) {
          _queueCounts = fallbackCounts;
        }
        _queueSettingsNotice =
            failure is ServerFailure && failure.statusCode == 404
            ? 'Queue policy controls need the latest backend deploy. Counts below are using article-list fallbacks for now.'
            : failure.message;
      });
    } finally {
      if (mounted) {
        setState(() => _settingsLoading = false);
      }
    }
  }

  Future<AdminArticleQueueCountsModel> _loadQueueCountsFallback() async {
    Future<int> fetchStatusTotal(String status) async {
      final page = await _remote.fetchAdminArticlesPage(
        status: status,
        offset: 0,
        limit: 1,
      );
      return page.total;
    }

    final counts = await Future.wait<int>([
      fetchStatusTotal('draft'),
      fetchStatusTotal('submitted'),
      fetchStatusTotal('in_review'),
      fetchStatusTotal('approved'),
      fetchStatusTotal('published'),
      fetchStatusTotal('rejected'),
      fetchStatusTotal('archived'),
    ]);

    return AdminArticleQueueCountsModel(
      draft: counts[0],
      submitted: counts[1],
      inReview: counts[2],
      approved: counts[3],
      published: counts[4],
      rejected: counts[5],
      archived: counts[6],
    );
  }

  String _queueSettingsFailureMessage(Object error) {
    final failure = mapFailure(error);
    if (failure is ServerFailure && failure.statusCode == 404) {
      return 'Queue policy controls are not available on the current backend deploy yet. Redeploy the backend, then try again.';
    }
    return failure.message;
  }

  Future<void> _saveQueueSettings() async {
    final draftDays = int.tryParse(_draftArchiveController.text.trim());
    final reviewDays = int.tryParse(_reviewArchiveController.text.trim());
    final rejectedDays = int.tryParse(_rejectedArchiveController.text.trim());
    if (draftDays == null ||
        reviewDays == null ||
        rejectedDays == null ||
        draftDays < 1 ||
        reviewDays < 1 ||
        rejectedDays < 1) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Enter valid archive thresholds in days.'),
        ),
      );
      return;
    }

    setState(() => _settingsSaving = true);
    try {
      final response = await _remote.updateArticleQueueSettings(
        autoArchiveEnabled: _autoArchiveEnabled,
        archiveDraftAfterDays: draftDays,
        archiveReviewAfterDays: reviewDays,
        archiveRejectedAfterDays: rejectedDays,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _autoArchiveEnabled = response.settings.autoArchiveEnabled;
        _queueCounts = response.counts;
        _draftArchiveController.text = response.settings.archiveDraftAfterDays
            .toString();
        _reviewArchiveController.text = response.settings.archiveReviewAfterDays
            .toString();
        _rejectedArchiveController.text = response
            .settings
            .archiveRejectedAfterDays
            .toString();
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Archive policy updated.')));
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_queueSettingsFailureMessage(error))),
      );
    } finally {
      if (mounted) {
        setState(() => _settingsSaving = false);
      }
    }
  }

  Future<void> _runArchiveNow() async {
    if (_runningArchiveNow) {
      return;
    }

    setState(() => _runningArchiveNow = true);
    try {
      final response = await _remote.runArticleQueueAutoArchive();
      if (!mounted) {
        return;
      }
      setState(() => _queueCounts = response.counts);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            response.archivedCount == 0
                ? 'No stale articles needed archiving.'
                : 'Archived ${response.archivedCount} stale articles.',
          ),
        ),
      );
      await _loadArticles();
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_queueSettingsFailureMessage(error))),
      );
    } finally {
      if (mounted) {
        setState(() => _runningArchiveNow = false);
      }
    }
  }

  Future<void> _loadArticles() async {
    setState(() {
      _loading = true;
      _errorMessage = null;
    });
    try {
      final selectedTab = _selectedTab;
      final page = await _remote.fetchAdminArticlesPage(
        status: selectedTab.statuses.length == 1
            ? selectedTab.statuses.first
            : null,
        statuses: selectedTab.statuses.length > 1 ? selectedTab.statuses : null,
        query: _searchController.text,
        source: _selectedSource,
        tag: _tagController.text,
        publishedFrom: _publishedFrom,
        publishedTo: _publishedTo,
        sort: selectedTab.sort,
        offset: _offset,
        limit: _pageSize,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _articles = page.items;
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

  Future<void> _pickDateTime({required bool isStart}) async {
    final current = isStart ? _publishedFrom : _publishedTo;
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: current ?? now,
      firstDate: DateTime(2020),
      lastDate: DateTime(now.year + 2),
    );
    if (date == null || !mounted) {
      return;
    }
    final time = await showTimePicker(
      context: context,
      initialTime: current == null
          ? TimeOfDay.now()
          : TimeOfDay.fromDateTime(current),
    );
    if (time == null || !mounted) {
      return;
    }

    final picked = DateTime(
      date.year,
      date.month,
      date.day,
      time.hour,
      time.minute,
    );

    setState(() {
      if (isStart) {
        _publishedFrom = picked;
      } else {
        _publishedTo = picked;
      }
      _offset = 0;
    });
    await _loadArticles();
  }

  void _clearDateFilter(bool isStart) {
    setState(() {
      if (isStart) {
        _publishedFrom = null;
      } else {
        _publishedTo = null;
      }
      _offset = 0;
    });
    _loadArticles();
  }

  Future<void> _runWorkflowAction(NewsArticle article, String action) async {
    String? targetStatus;
    if (action == 'restore') {
      targetStatus = await _pickRestoreTarget();
      if (targetStatus == null) {
        return;
      }
    }

    try {
      final updated = await _remote.transitionAdminArticle(
        articleId: article.id,
        action: action,
        targetStatus: targetStatus,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        final index = _articles.indexWhere((item) => item.id == article.id);
        if (index < 0) {
          return;
        }
        final next = List<NewsArticle>.from(_articles);
        final selectedStatuses = _selectedTab.statuses;
        if (selectedStatuses.isNotEmpty &&
            !selectedStatuses.contains(updated.status)) {
          next.removeAt(index);
        } else {
          next[index] = updated;
        }
        _articles = next;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_actionLabel(action, completed: true))),
      );
      _loadQueueSettings();
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(mapFailure(error).message)));
    }
  }

  Future<String?> _pickRestoreTarget() async {
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Restore archived article'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _RestoreTargetTile(
              title: 'Restore to draft',
              subtitle:
                  'Send it back to the working queue for editing before review.',
              onTap: () => Navigator.of(context).pop('draft'),
            ),
            const SizedBox(height: 8),
            _RestoreTargetTile(
              title: 'Restore to approved',
              subtitle:
                  'Return it to the approved queue, ready for publication.',
              onTap: () => Navigator.of(context).pop('approved'),
            ),
            const SizedBox(height: 8),
            _RestoreTargetTile(
              title: 'Restore to published',
              subtitle:
                  'Make it live again immediately and move it back into the live queue.',
              onTap: () => Navigator.of(context).pop('published'),
            ),
          ],
        ),
      ),
    );
  }

  int _countForTab(_ArticleQueueTabConfig tab) {
    switch (tab.key) {
      case 'needs_review':
        return _queueCounts.submitted +
            _queueCounts.inReview +
            _queueCounts.approved;
      case 'drafts':
        return _queueCounts.draft;
      case 'live':
        return _queueCounts.published;
      case 'rejected':
        return _queueCounts.rejected;
      case 'archived':
        return _queueCounts.archived;
      case 'all':
        return _queueCounts.draft +
            _queueCounts.submitted +
            _queueCounts.inReview +
            _queueCounts.approved +
            _queueCounts.published +
            _queueCounts.rejected +
            _queueCounts.archived;
      default:
        return 0;
    }
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _loadArticles,
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
                      'Articles Queue',
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Review drafts, approve submissions, and move stories into publication.',
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: const Color(0xFF4F4A43),
                      ),
                    ),
                  ],
                ),
              ),
              FilledButton.icon(
                onPressed: () => context.push(AppRouter.adminArticleCreatePath),
                icon: const Icon(Icons.add_rounded),
                label: const Text('Create article'),
              ),
            ],
          ),
          const SizedBox(height: 18),
          _QueueSettingsCard(
            loading: _settingsLoading,
            saving: _settingsSaving,
            runningArchiveNow: _runningArchiveNow,
            autoArchiveEnabled: _autoArchiveEnabled,
            draftArchiveController: _draftArchiveController,
            reviewArchiveController: _reviewArchiveController,
            rejectedArchiveController: _rejectedArchiveController,
            onAutoArchiveChanged: (value) =>
                setState(() => _autoArchiveEnabled = value),
            onSave: _saveQueueSettings,
            onRunNow: _runArchiveNow,
          ),
          if (_queueSettingsNotice != null) ...[
            const SizedBox(height: 12),
            DecoratedBox(
              decoration: BoxDecoration(
                color: const Color(0xFFFFF7E8),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFE0C98F)),
              ),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.info_outline_rounded, size: 18),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        _queueSettingsNotice!,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: const Color(0xFF6A5431),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
          const SizedBox(height: 18),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: _queueTabs
                  .map(
                    (tab) => Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: Text('${tab.label} (${_countForTab(tab)})'),
                        selected: _selectedTabKey == tab.key,
                        onSelected: (_) {
                          if (_selectedTabKey == tab.key) {
                            return;
                          }
                          setState(() {
                            _selectedTabKey = tab.key;
                            _offset = 0;
                          });
                          _loadArticles();
                        },
                      ),
                    ),
                  )
                  .toList(growable: false),
            ),
          ),
          const SizedBox(height: 18),
          TextField(
            controller: _searchController,
            textInputAction: TextInputAction.search,
            onSubmitted: (_) {
              setState(() => _offset = 0);
              _loadArticles();
            },
            decoration: InputDecoration(
              hintText:
                  'Search articles by title, source, category, summary, or tag',
              prefixIcon: const Icon(Icons.search_rounded),
              suffixIcon: _searchController.text.trim().isEmpty
                  ? null
                  : IconButton(
                      tooltip: 'Clear search',
                      onPressed: () {
                        _searchController.clear();
                        _loadArticles();
                      },
                      icon: const Icon(Icons.close_rounded),
                    ),
            ),
          ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerLeft,
            child: OutlinedButton.icon(
              onPressed: () {
                setState(() => _offset = 0);
                _loadArticles();
              },
              icon: const Icon(Icons.search_rounded),
              label: const Text('Search'),
            ),
          ),
          const SizedBox(height: 18),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              SizedBox(
                width: 260,
                child: DropdownButtonFormField<String?>(
                  value: _selectedSource,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Source',
                    prefixIcon: Icon(Icons.rss_feed_rounded),
                  ),
                  items: [
                    const DropdownMenuItem<String?>(
                      value: null,
                      child: Text('All sources'),
                    ),
                    ..._availableSources.map(
                      (source) => DropdownMenuItem<String?>(
                        value: source,
                        child: Text(source, overflow: TextOverflow.ellipsis),
                      ),
                    ),
                  ],
                  onChanged: (value) {
                    setState(() {
                      _selectedSource = value;
                      _offset = 0;
                    });
                    _loadArticles();
                  },
                ),
              ),
              SizedBox(
                width: 220,
                child: TextField(
                  controller: _tagController,
                  onSubmitted: (_) {
                    setState(() => _offset = 0);
                    _loadArticles();
                  },
                  decoration: InputDecoration(
                    labelText: 'Tag',
                    prefixIcon: const Icon(Icons.sell_outlined),
                    suffixIcon: _tagController.text.trim().isEmpty
                        ? null
                        : IconButton(
                            tooltip: 'Clear tag filter',
                            onPressed: () {
                              _tagController.clear();
                              _loadArticles();
                            },
                            icon: const Icon(Icons.close_rounded),
                          ),
                  ),
                ),
              ),
              _DateFilterChip(
                label: _publishedFrom == null
                    ? 'From date & time'
                    : 'From ${_formatAdminDateTime(_publishedFrom!)}',
                icon: Icons.schedule_rounded,
                onTap: () => _pickDateTime(isStart: true),
                onClear: _publishedFrom == null
                    ? null
                    : () => _clearDateFilter(true),
              ),
              _DateFilterChip(
                label: _publishedTo == null
                    ? 'To date & time'
                    : 'To ${_formatAdminDateTime(_publishedTo!)}',
                icon: Icons.event_available_rounded,
                onTap: () => _pickDateTime(isStart: false),
                onClear: _publishedTo == null
                    ? null
                    : () => _clearDateFilter(false),
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
              title: 'Could not load the articles queue',
              message: _errorMessage!,
              actionLabel: 'Try again',
              onPressed: _loadArticles,
            )
          else if (_articles.isEmpty)
            _StateCard(
              title: 'No stories in ${_selectedTab.label.toLowerCase()}',
              message:
                  'Try another tab or adjust the filters to widen the queue.',
              actionLabel: 'Create article',
              onPressed: () => context.push(AppRouter.adminArticleCreatePath),
            )
          else
            ..._articles.map(
              (article) => Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: _ArticleCard(
                  article: article,
                  onOpen: () =>
                      context.go(AppRouter.adminArticleDetailPath(article.id)),
                  onActionSelected: (action) =>
                      _runWorkflowAction(article, action),
                ),
              ),
            ),
          if (!_loading && _errorMessage == null && _articles.isNotEmpty) ...[
            const SizedBox(height: 8),
            _PaginationBar(
              offset: _offset,
              limit: _pageSize,
              total: _total,
              onPrevious: _offset <= 0
                  ? null
                  : () {
                      setState(() {
                        final nextOffset = _offset - _pageSize;
                        _offset = nextOffset < 0 ? 0 : nextOffset;
                      });
                      _loadArticles();
                    },
              onNext: _offset + _pageSize >= _total
                  ? null
                  : () {
                      setState(() => _offset += _pageSize);
                      _loadArticles();
                    },
            ),
          ],
        ],
      ),
    );
  }

  String _actionLabel(String action, {bool completed = false}) {
    switch (action) {
      case 'submit':
        return completed
            ? 'Article submitted for review.'
            : 'Submit for review';
      case 'approve':
        return completed ? 'Article approved.' : 'Approve';
      case 'publish':
        return completed ? 'Article published.' : 'Publish';
      case 'reject':
        return completed ? 'Article rejected.' : 'Reject';
      case 'archive':
        return completed ? 'Article archived.' : 'Archive';
      case 'restore':
        return completed ? 'Article restored to draft.' : 'Restore';
      default:
        return action;
    }
  }
}

class _ArticleQueueTabConfig {
  const _ArticleQueueTabConfig({
    required this.key,
    required this.label,
    required this.statuses,
    required this.sort,
  });

  final String key;
  final String label;
  final List<String> statuses;
  final String sort;
}

String _formatAdminDateTime(DateTime value) {
  final twoDigitMonth = value.month.toString().padLeft(2, '0');
  final twoDigitDay = value.day.toString().padLeft(2, '0');
  final twoDigitHour = value.hour.toString().padLeft(2, '0');
  final twoDigitMinute = value.minute.toString().padLeft(2, '0');
  return '${value.year}-$twoDigitMonth-$twoDigitDay $twoDigitHour:$twoDigitMinute';
}

class _QueueSettingsCard extends StatelessWidget {
  const _QueueSettingsCard({
    required this.loading,
    required this.saving,
    required this.runningArchiveNow,
    required this.autoArchiveEnabled,
    required this.draftArchiveController,
    required this.reviewArchiveController,
    required this.rejectedArchiveController,
    required this.onAutoArchiveChanged,
    required this.onSave,
    required this.onRunNow,
  });

  final bool loading;
  final bool saving;
  final bool runningArchiveNow;
  final bool autoArchiveEnabled;
  final TextEditingController draftArchiveController;
  final TextEditingController reviewArchiveController;
  final TextEditingController rejectedArchiveController;
  final ValueChanged<bool> onAutoArchiveChanged;
  final VoidCallback onSave;
  final VoidCallback onRunNow;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFD8CEBE)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: loading
            ? const Center(child: CircularProgressIndicator())
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Archive Policy',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Auto-archive stale queue items based on the last time an article was updated.',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: const Color(0xFF5D564C),
                    ),
                  ),
                  const SizedBox(height: 16),
                  SwitchListTile.adaptive(
                    contentPadding: EdgeInsets.zero,
                    value: autoArchiveEnabled,
                    title: const Text('Enable auto-archive'),
                    subtitle: const Text(
                      'Draft, review, and rejected queues will roll into Archived automatically.',
                    ),
                    onChanged: onAutoArchiveChanged,
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      _NumericSettingField(
                        controller: draftArchiveController,
                        label: 'Drafts after',
                        suffix: 'days',
                      ),
                      _NumericSettingField(
                        controller: reviewArchiveController,
                        label: 'Review queue after',
                        suffix: 'days',
                      ),
                      _NumericSettingField(
                        controller: rejectedArchiveController,
                        label: 'Rejected after',
                        suffix: 'days',
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Align(
                    alignment: Alignment.centerRight,
                    child: Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: [
                        OutlinedButton.icon(
                          onPressed: runningArchiveNow ? null : onRunNow,
                          icon: runningArchiveNow
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.archive_outlined),
                          label: Text(
                            runningArchiveNow
                                ? 'Running...'
                                : 'Run archive now',
                          ),
                        ),
                        FilledButton.icon(
                          onPressed: saving ? null : onSave,
                          icon: saving
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.save_outlined),
                          label: Text(saving ? 'Saving...' : 'Save policy'),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

class _NumericSettingField extends StatelessWidget {
  const _NumericSettingField({
    required this.controller,
    required this.label,
    required this.suffix,
  });

  final TextEditingController controller;
  final String label;
  final String suffix;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 200,
      child: TextField(
        controller: controller,
        keyboardType: TextInputType.number,
        decoration: InputDecoration(labelText: label, suffixText: suffix),
      ),
    );
  }
}

class _RestoreTargetTile extends StatelessWidget {
  const _RestoreTargetTile({
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Ink(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFD8CEBE)),
          color: const Color(0xFFFFFBF5),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.only(top: 2),
              child: Icon(Icons.restore_rounded, size: 18),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: const Color(0xFF5D564C),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DateFilterChip extends StatelessWidget {
  const _DateFilterChip({
    required this.label,
    required this.icon,
    required this.onTap,
    this.onClear,
  });

  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onTap,
      icon: Icon(icon),
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(child: Text(label, overflow: TextOverflow.ellipsis)),
          if (onClear != null) ...[
            const SizedBox(width: 8),
            InkWell(
              onTap: onClear,
              child: const Icon(Icons.close_rounded, size: 18),
            ),
          ],
        ],
      ),
    );
  }
}

class _PaginationBar extends StatelessWidget {
  const _PaginationBar({
    required this.offset,
    required this.limit,
    required this.total,
    required this.onPrevious,
    required this.onNext,
  });

  final int offset;
  final int limit;
  final int total;
  final VoidCallback? onPrevious;
  final VoidCallback? onNext;

  @override
  Widget build(BuildContext context) {
    final start = total == 0 ? 0 : offset + 1;
    final end = total == 0
        ? 0
        : (offset + limit) > total
        ? total
        : offset + limit;

    return Row(
      children: [
        Expanded(
          child: Text(
            'Showing $start-$end of $total articles',
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: const Color(0xFF6E675C)),
          ),
        ),
        OutlinedButton.icon(
          onPressed: onPrevious,
          icon: const Icon(Icons.chevron_left_rounded),
          label: const Text('Previous'),
        ),
        const SizedBox(width: 10),
        OutlinedButton.icon(
          onPressed: onNext,
          icon: const Icon(Icons.chevron_right_rounded),
          label: const Text('Next'),
        ),
      ],
    );
  }
}

class _ArticleCard extends StatelessWidget {
  const _ArticleCard({
    required this.article,
    required this.onOpen,
    required this.onActionSelected,
  });

  final NewsArticle article;
  final VoidCallback onOpen;
  final ValueChanged<String> onActionSelected;

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
        child: Row(
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
                        label: article.status,
                        color: _statusColor(article.status),
                      ),
                      _StatusChip(
                        label: article.verificationStatus,
                        color: _verificationColor(article.verificationStatus),
                        outlined: true,
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    article.title,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${article.source} - ${article.category} - ${adminDateTimeLabel(article.publishedAt)}',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: const Color(0xFF4F4A43),
                    ),
                  ),
                  if (article.status == 'archived') ...[
                    const SizedBox(height: 8),
                    Text(
                      'Archived story • originally published ${adminDateTimeLabel(article.publishedAt)}',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: const Color(0xFF6B7280),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                  if (article.tags.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: article.tags
                          .take(5)
                          .map(
                            (tag) => Chip(
                              label: Text(tag),
                              visualDensity: VisualDensity.compact,
                            ),
                          )
                          .toList(growable: false),
                    ),
                  ],
                  if (article.summary?.trim().isNotEmpty ?? false) ...[
                    const SizedBox(height: 12),
                    Text(
                      plainTextExcerpt(article.summary),
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 16),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                PopupMenuButton<String>(
                  tooltip: 'Workflow actions',
                  onSelected: onActionSelected,
                  itemBuilder: (context) => _actionsFor(article.status)
                      .map(
                        (action) => PopupMenuItem<String>(
                          value: action,
                          child: Text(switch (action) {
                            'submit' => 'Submit for review',
                            'approve' => 'Approve',
                            'publish' => 'Publish',
                            'reject' => 'Reject',
                            'archive' => 'Archive',
                            'restore' => 'Restore to draft',
                            _ => action,
                          }),
                        ),
                      )
                      .toList(growable: false),
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: article.status == 'published'
                      ? () => addArticleToHomepageFlow(
                          context,
                          remote:
                              InjectionContainer.sl<AdminRemoteDataSource>(),
                          article: article,
                        )
                      : null,
                  icon: const Icon(Icons.push_pin_outlined),
                  label: const Text('Homepage'),
                ),
                const SizedBox(height: 28),
                OutlinedButton.icon(
                  onPressed: onOpen,
                  icon: const Icon(Icons.open_in_new_rounded),
                  label: const Text('Review'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  List<String> _actionsFor(String status) {
    switch (status) {
      case 'draft':
        return const ['submit', 'approve', 'publish', 'reject', 'archive'];
      case 'submitted':
        return const ['approve', 'publish', 'reject', 'archive'];
      case 'approved':
        return const ['publish', 'reject', 'archive'];
      case 'published':
        return const ['archive'];
      case 'rejected':
        return const ['submit', 'publish', 'archive'];
      case 'archived':
        return const ['restore'];
      default:
        return const ['archive'];
    }
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'published':
        return const Color(0xFF0F766E);
      case 'approved':
        return const Color(0xFF2563EB);
      case 'submitted':
        return const Color(0xFFB7791F);
      case 'rejected':
        return const Color(0xFFC53030);
      case 'archived':
        return const Color(0xFF6B7280);
      default:
        return const Color(0xFF475569);
    }
  }

  Color _verificationColor(String status) {
    switch (status) {
      case 'fact_checked':
        return const Color(0xFF166534);
      case 'verified':
        return const Color(0xFF0F766E);
      case 'developing':
        return const Color(0xFFB45309);
      case 'opinion':
        return const Color(0xFF7C3AED);
      case 'sponsored':
        return const Color(0xFFB91C1C);
      default:
        return const Color(0xFF64748B);
    }
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({
    required this.label,
    required this.color,
    this.outlined = false,
  });

  final String label;
  final Color color;
  final bool outlined;

  @override
  Widget build(BuildContext context) {
    final text = label
        .split('_')
        .map((part) => '${part[0].toUpperCase()}${part.substring(1)}')
        .join(' ');
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: outlined ? 0.08 : 0.14),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.3)),
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
