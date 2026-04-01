import 'package:flutter/material.dart';
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
  static const List<String> _statusFilters = <String>[
    'all',
    'draft',
    'submitted',
    'approved',
    'published',
    'rejected',
    'archived',
  ];

  final AdminRemoteDataSource _remote =
      InjectionContainer.sl<AdminRemoteDataSource>();
  final TextEditingController _searchController = TextEditingController();

  List<NewsArticle> _articles = const <NewsArticle>[];
  List<String> _availableSources = const <String>[];
  String _selectedStatus = 'all';
  String? _selectedSource;
  DateTime? _publishedFrom;
  DateTime? _publishedTo;
  int _offset = 0;
  int _total = 0;
  bool _loading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_handleSearchChanged);
    _loadSources();
    _loadArticles();
  }

  @override
  void dispose() {
    _searchController.removeListener(_handleSearchChanged);
    _searchController.dispose();
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
      final names =
          items
              .map((item) => item.name.trim())
              .where((item) => item.isNotEmpty)
              .toSet()
              .toList()
            ..sort();
      setState(() => _availableSources = names);
    } catch (_) {
      // Keep queue usable even if source metadata cannot be loaded.
    }
  }

  Future<void> _loadArticles() async {
    setState(() {
      _loading = true;
      _errorMessage = null;
    });
    try {
      final page = await _remote.fetchAdminArticlesPage(
        status: _selectedStatus == 'all' ? null : _selectedStatus,
        query: _searchController.text,
        source: _selectedSource,
        publishedFrom: _publishedFrom,
        publishedTo: _publishedTo,
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
    try {
      final updated = await _remote.transitionAdminArticle(
        articleId: article.id,
        action: action,
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
        if (_selectedStatus != 'all' && updated.status != _selectedStatus) {
          next.removeAt(index);
        } else {
          next[index] = updated;
        }
        _articles = next;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_actionLabel(action, completed: true))),
      );
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
          TextField(
            controller: _searchController,
            textInputAction: TextInputAction.search,
            onSubmitted: (_) {
              setState(() => _offset = 0);
              _loadArticles();
            },
            decoration: InputDecoration(
              hintText:
                  'Search articles by title, source, category, or summary',
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
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: _statusFilters
                  .map(
                    (status) => Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: Text(_prettyLabel(status)),
                        selected: _selectedStatus == status,
                        onSelected: (_) {
                          if (_selectedStatus == status) {
                            return;
                          }
                          setState(() {
                            _selectedStatus = status;
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
              title: 'No stories in this queue',
              message: 'Switch filters or create a new article to get started.',
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

  String _prettyLabel(String value) => value == 'all'
      ? 'All'
      : value
            .split('_')
            .map((part) => '${part[0].toUpperCase()}${part.substring(1)}')
            .join(' ');

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
      default:
        return action;
    }
  }
}

String _formatAdminDateTime(DateTime value) {
  final twoDigitMonth = value.month.toString().padLeft(2, '0');
  final twoDigitDay = value.day.toString().padLeft(2, '0');
  final twoDigitHour = value.hour.toString().padLeft(2, '0');
  final twoDigitMinute = value.minute.toString().padLeft(2, '0');
  return '${value.year}-$twoDigitMonth-$twoDigitDay $twoDigitHour:$twoDigitMinute';
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
