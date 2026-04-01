import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:naijapulse/admin/data/datasource/admin_remote_datasource.dart';
import 'package:naijapulse/admin/data/models/admin_models.dart';
import 'package:naijapulse/core/di/injection_container.dart';
import 'package:naijapulse/core/error/failures.dart';
import 'package:naijapulse/core/routing/app_router.dart';
import 'package:naijapulse/core/utils/content_text.dart';
import 'package:naijapulse/features/news/domain/entities/news_article.dart';
import 'package:naijapulse/features/news/presentation/widgets/news_time.dart';

class AdminVerificationPage extends StatefulWidget {
  const AdminVerificationPage({super.key});

  @override
  State<AdminVerificationPage> createState() => _AdminVerificationPageState();
}

class _AdminVerificationPageState extends State<AdminVerificationPage> {
  static const List<String> _verificationFilters = <String>[
    'all',
    'unverified',
    'developing',
    'verified',
    'fact_checked',
    'opinion',
    'sponsored',
  ];

  static const List<String> _articleStatusFilters = <String>[
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

  AdminVerificationDeskModel? _desk;
  String _selectedVerification = 'all';
  String _selectedArticleStatus = 'all';
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
      final desk = await _remote.fetchVerificationDesk(
        verificationStatus: _selectedVerification == 'all'
            ? null
            : _selectedVerification,
        articleStatus: _selectedArticleStatus == 'all'
            ? null
            : _selectedArticleStatus,
      );
      if (!mounted) {
        return;
      }
      setState(() => _desk = desk);
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

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          Text(
            'Verification Desk',
            style: Theme.of(
              context,
            ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 6),
          Text(
            'Review trust labels and inspect which stories still need verification work.',
            style: Theme.of(
              context,
            ).textTheme.bodyLarge?.copyWith(color: const Color(0xFF4F4A43)),
          ),
          const SizedBox(height: 18),
          if (_desk != null)
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                _CountCard(label: 'Unverified', value: _desk!.unverifiedCount),
                _CountCard(label: 'Developing', value: _desk!.developingCount),
                _CountCard(label: 'Verified', value: _desk!.verifiedCount),
                _CountCard(
                  label: 'Fact Checked',
                  value: _desk!.factCheckedCount,
                ),
                _CountCard(label: 'Opinion', value: _desk!.opinionCount),
                _CountCard(label: 'Sponsored', value: _desk!.sponsoredCount),
              ],
            ),
          const SizedBox(height: 18),
          Text(
            'Verification Status',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 10),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: _verificationFilters
                  .map(
                    (value) => Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: Text(_prettyLabel(value)),
                        selected: _selectedVerification == value,
                        onSelected: (_) {
                          if (_selectedVerification == value) {
                            return;
                          }
                          setState(() => _selectedVerification = value);
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
            'Article Status',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 10),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: _articleStatusFilters
                  .map(
                    (value) => Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: Text(_prettyLabel(value)),
                        selected: _selectedArticleStatus == value,
                        onSelected: (_) {
                          if (_selectedArticleStatus == value) {
                            return;
                          }
                          setState(() => _selectedArticleStatus = value);
                          _load();
                        },
                      ),
                    ),
                  )
                  .toList(growable: false),
            ),
          ),
          const SizedBox(height: 18),
          if (_loading)
            const Padding(
              padding: EdgeInsets.only(top: 80),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_errorMessage != null)
            _StateCard(
              title: 'Could not load verification desk',
              message: _errorMessage!,
              actionLabel: 'Try again',
              onPressed: _load,
            )
          else if ((_desk?.items.isEmpty ?? true))
            _StateCard(
              title: 'No stories match these filters',
              message:
                  'Adjust the filters to inspect a different verification queue.',
              actionLabel: 'Refresh',
              onPressed: _load,
            )
          else
            ..._desk!.items.map(
              (article) => Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: _VerificationArticleCard(article: article),
              ),
            ),
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

class _VerificationArticleCard extends StatelessWidget {
  const _VerificationArticleCard({required this.article});

  final NewsArticle article;

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
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _Badge(
                  label: article.status,
                  color: _statusColor(article.status),
                ),
                _Badge(
                  label: article.verificationStatus,
                  color: _verificationColor(article.verificationStatus),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              article.title,
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            Text(
              '${article.source} - ${article.category} - ${adminDateTimeLabel(article.publishedAt)}',
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: const Color(0xFF4F4A43)),
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
            const SizedBox(height: 14),
            Align(
              alignment: Alignment.centerRight,
              child: OutlinedButton.icon(
                onPressed: () =>
                    context.go(AppRouter.adminArticleDetailPath(article.id)),
                icon: const Icon(Icons.open_in_new_rounded),
                label: const Text('Open review'),
              ),
            ),
          ],
        ),
      ),
    );
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

class _CountCard extends StatelessWidget {
  const _CountCard({required this.label, required this.value});

  final String label;
  final int value;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 170,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFFCFC3B0), width: 1.2),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF12261C).withValues(alpha: 0.04),
              blurRadius: 16,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '$value',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 4),
              Text(label, style: Theme.of(context).textTheme.bodyMedium),
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
        color: color.withValues(alpha: 0.1),
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
