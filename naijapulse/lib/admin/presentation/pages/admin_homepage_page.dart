import 'package:flutter/material.dart';
import 'package:naijapulse/admin/data/datasource/admin_remote_datasource.dart';
import 'package:naijapulse/admin/data/models/admin_models.dart';
import 'package:naijapulse/admin/presentation/widgets/homepage_placement_dialog.dart';
import 'package:naijapulse/core/di/injection_container.dart';
import 'package:naijapulse/core/error/failures.dart';
import 'package:naijapulse/features/news/data/models/homepage_content_model.dart';
import 'package:naijapulse/features/news/data/models/news_article_model.dart';
import 'package:naijapulse/features/news/domain/entities/news_article.dart';

class AdminHomepagePage extends StatefulWidget {
  const AdminHomepagePage({super.key});

  @override
  State<AdminHomepagePage> createState() => _AdminHomepagePageState();
}

class _AdminHomepagePageState extends State<AdminHomepagePage> {
  final AdminRemoteDataSource _remote =
      InjectionContainer.sl<AdminRemoteDataSource>();
  bool _latestAutofillEnabled = true;
  final TextEditingController _latestItemLimitController =
      TextEditingController();
  final TextEditingController _latestWindowController = TextEditingController();
  final TextEditingController _latestFallbackWindowController =
      TextEditingController();

  AdminHomepageConfigModel? _config;
  List<NewsArticleModel>? _publishedStories;
  bool _loading = true;
  bool _saving = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _latestItemLimitController.dispose();
    _latestWindowController.dispose();
    _latestFallbackWindowController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _errorMessage = null;
    });
    try {
      final config = await _remote.fetchHomepageConfig();
      if (!mounted) {
        return;
      }
      setState(() {
        _config = config;
        _latestAutofillEnabled = config.settings.latestAutofillEnabled;
        _latestItemLimitController.text = config.settings.latestItemLimit
            .toString();
        _latestWindowController.text = config.settings.latestWindowHours
            .toString();
        _latestFallbackWindowController.text = config
            .settings
            .latestFallbackWindowHours
            .toString();
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

  Future<List<NewsArticleModel>> _publishedArticleOptions() async {
    final cached = _publishedStories;
    if (cached != null) {
      return cached;
    }
    final items = await _remote.fetchAdminArticles(
      status: 'published',
      limit: 200,
    );
    _publishedStories = items.whereType<NewsArticleModel>().toList(
      growable: false,
    );
    return _publishedStories!;
  }

  Future<void> _commitMutation(
    Future<AdminHomepageConfigModel> Function() run,
    String successMessage,
  ) async {
    if (_saving) {
      return;
    }
    setState(() => _saving = true);
    try {
      final updated = await run();
      if (!mounted) {
        return;
      }
      setState(() {
        _config = updated;
        _latestAutofillEnabled = updated.settings.latestAutofillEnabled;
        _latestItemLimitController.text = updated.settings.latestItemLimit
            .toString();
        _latestWindowController.text = updated.settings.latestWindowHours
            .toString();
        _latestFallbackWindowController.text = updated
            .settings
            .latestFallbackWindowHours
            .toString();
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(successMessage)));
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

  List<AdminHomepageCategoryConfigModel> _normalizeCategories(
    List<AdminHomepageCategoryConfigModel> items,
  ) => items
      .asMap()
      .entries
      .map((entry) => entry.value.copyWith(position: entry.key))
      .toList(growable: false);

  List<AdminHomepageSecondaryChipConfigModel> _normalizeChips(
    List<AdminHomepageSecondaryChipConfigModel> items,
  ) => items
      .asMap()
      .entries
      .map((entry) => entry.value.copyWith(position: entry.key))
      .toList(growable: false);

  List<AdminHomepagePlacementItemModel> _currentPlacements() {
    final config = _config;
    if (config == null) {
      return const <AdminHomepagePlacementItemModel>[];
    }

    final items = <AdminHomepagePlacementItemModel>[
      ...config.topStories.asMap().entries.map(
        (entry) => entry.value.toPatchItem(positionOverride: entry.key),
      ),
      ...config.latestStories.asMap().entries.map(
        (entry) => entry.value.toPatchItem(positionOverride: entry.key),
      ),
    ];

    for (final section in config.categorySections) {
      for (var index = 0; index < section.items.length; index += 1) {
        items.add(
          AdminHomepagePlacementItemModel(
            articleId: section.items[index].id,
            section: 'category',
            targetKey: section.key,
            position: index,
            enabled: true,
          ),
        );
      }
    }

    for (final section in config.secondaryChipSections) {
      for (var index = 0; index < section.items.length; index += 1) {
        items.add(
          AdminHomepagePlacementItemModel(
            articleId: section.items[index].id,
            section: 'secondary_chip',
            targetKey: section.key,
            position: index,
            enabled: true,
          ),
        );
      }
    }

    return _normalizePlacements(items);
  }

  List<AdminHomepagePlacementItemModel> _normalizePlacements(
    List<AdminHomepagePlacementItemModel> items,
  ) {
    final grouped = <String, List<AdminHomepagePlacementItemModel>>{};
    for (final item in items) {
      final bucket = '${item.section}::${item.targetKey ?? ''}';
      grouped
          .putIfAbsent(bucket, () => <AdminHomepagePlacementItemModel>[])
          .add(item);
    }

    return grouped.values
        .expand(
          (bucket) => bucket.asMap().entries.map(
            (entry) => entry.value.copyWith(position: entry.key),
          ),
        )
        .toList(growable: false);
  }

  bool _isStaleArticle(NewsArticle article, {DateTime? now}) {
    final current = now ?? DateTime.now();
    final age = current.difference(article.publishedAt);
    final category = article.category.trim().toLowerCase();
    Duration threshold;
    if (category.contains('breaking')) {
      threshold = const Duration(hours: 18);
    } else if (category.contains('politic') || category.contains('election')) {
      threshold = const Duration(hours: 48);
    } else if (category.contains('business') ||
        category.contains('econom') ||
        category.contains('finance')) {
      threshold = const Duration(hours: 48);
    } else if (category.contains('sport')) {
      threshold = const Duration(hours: 30);
    } else if (category.contains('tech')) {
      threshold = const Duration(hours: 72);
    } else if (category.contains('entertain') ||
        category.contains('music') ||
        category.contains('lifestyle')) {
      threshold = const Duration(hours: 72);
    } else if (category.contains('opinion') || category.contains('analysis')) {
      threshold = const Duration(days: 7);
    } else {
      threshold = const Duration(hours: 36);
    }
    return age > threshold;
  }

  Future<void> _removeStalePlacements() async {
    final config = _config;
    if (config == null) {
      return;
    }

    final articleLookup = <String, NewsArticle>{
      for (final item in config.topStories) item.article.id: item.article,
      for (final item in config.latestStories) item.article.id: item.article,
      for (final section in config.categorySections)
        for (final item in section.items) item.id: item,
      for (final section in config.secondaryChipSections)
        for (final item in section.items) item.id: item,
    };

    final current = _currentPlacements();
    final freshPlacements = current
        .where((item) {
          final article = articleLookup[item.articleId];
          if (article == null) {
            return false;
          }
          return !_isStaleArticle(article);
        })
        .toList(growable: false);

    final removedCount = current.length - freshPlacements.length;
    if (removedCount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No stale homepage placements were found.'),
        ),
      );
      return;
    }

    await _replacePlacements(
      freshPlacements,
      message: 'Removed $removedCount stale homepage placement(s).',
    );
  }

  Future<void> _replaceCategories(
    List<AdminHomepageCategoryConfigModel> items,
  ) async {
    final currentPlacements = _currentPlacements();
    final allowedKeys = items.map((item) => item.key).toSet();
    final filteredPlacements = currentPlacements
        .where(
          (item) =>
              item.section != 'category' ||
              (item.targetKey != null && allowedKeys.contains(item.targetKey)),
        )
        .toList(growable: false);

    await _commitMutation(() async {
      await _remote.updateHomepageCategories(_normalizeCategories(items));
      if (filteredPlacements.length != currentPlacements.length) {
        return _remote.updateHomepagePlacements(
          _normalizePlacements(filteredPlacements),
        );
      }
      return _remote.fetchHomepageConfig();
    }, 'Homepage categories updated.');
  }

  Future<void> _replaceChips(
    List<AdminHomepageSecondaryChipConfigModel> items,
  ) async {
    final currentPlacements = _currentPlacements();
    final allowedKeys = items.map((item) => item.key).toSet();
    final filteredPlacements = currentPlacements
        .where(
          (item) =>
              item.section != 'secondary_chip' ||
              (item.targetKey != null && allowedKeys.contains(item.targetKey)),
        )
        .toList(growable: false);

    await _commitMutation(() async {
      await _remote.updateHomepageSecondaryChips(_normalizeChips(items));
      if (filteredPlacements.length != currentPlacements.length) {
        return _remote.updateHomepagePlacements(
          _normalizePlacements(filteredPlacements),
        );
      }
      return _remote.fetchHomepageConfig();
    }, 'Homepage chips updated.');
  }

  Future<void> _replacePlacements(
    List<AdminHomepagePlacementItemModel> items, {
    String message = 'Homepage placements updated.',
  }) async {
    await _commitMutation(
      () => _remote.updateHomepagePlacements(_normalizePlacements(items)),
      message,
    );
  }

  Future<void> _updateHomepageSettings() async {
    final itemLimit = int.tryParse(_latestItemLimitController.text.trim());
    final latestWindow = int.tryParse(_latestWindowController.text.trim());
    final fallbackWindow = int.tryParse(
      _latestFallbackWindowController.text.trim(),
    );

    if (itemLimit == null || itemLimit < 1 || itemLimit > 50) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Enter a latest item limit between 1 and 50.'),
        ),
      );
      return;
    }

    if (latestWindow == null || latestWindow < 1 || latestWindow > 168) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Enter a latest stories window between 1 and 168 hours.',
          ),
        ),
      );
      return;
    }

    if (fallbackWindow == null || fallbackWindow < 1 || fallbackWindow > 336) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Enter a fallback window between 1 and 336 hours.'),
        ),
      );
      return;
    }

    if (fallbackWindow < latestWindow) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Fallback window must be greater than or equal to the latest stories window.',
          ),
        ),
      );
      return;
    }

    await _commitMutation(
      () => _remote.updateHomepageSettings(
        latestAutofillEnabled: _latestAutofillEnabled,
        latestItemLimit: itemLimit,
        latestWindowHours: latestWindow,
        latestFallbackWindowHours: fallbackWindow,
      ),
      'Homepage settings updated.',
    );
  }

  Future<void> _showCategoryDialog([
    AdminHomepageCategoryConfigModel? existing,
  ]) async {
    final keyController = TextEditingController(text: existing?.key ?? '');
    final labelController = TextEditingController(text: existing?.label ?? '');
    final colorController = TextEditingController(
      text: existing?.colorHex ?? '',
    );
    var enabled = existing?.enabled ?? true;

    final result = await showDialog<AdminHomepageCategoryConfigModel>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => AlertDialog(
          title: Text(
            existing == null ? 'Add homepage category' : 'Edit category',
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: keyController,
                decoration: const InputDecoration(labelText: 'Key'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: labelController,
                decoration: const InputDecoration(labelText: 'Label'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: colorController,
                decoration: const InputDecoration(labelText: 'Color hex'),
              ),
              const SizedBox(height: 12),
              SwitchListTile.adaptive(
                value: enabled,
                contentPadding: EdgeInsets.zero,
                title: const Text('Enabled'),
                onChanged: (value) => setModalState(() => enabled = value),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(
                AdminHomepageCategoryConfigModel(
                  key: keyController.text.trim(),
                  label: labelController.text.trim(),
                  colorHex: colorController.text.trim().isEmpty
                      ? null
                      : colorController.text.trim(),
                  position: existing?.position ?? 0,
                  enabled: enabled,
                ),
              ),
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );

    keyController.dispose();
    labelController.dispose();
    colorController.dispose();
    if (result == null) {
      return;
    }

    final next = List<AdminHomepageCategoryConfigModel>.from(
      _config?.categories ?? const [],
    );
    if (existing == null) {
      next.add(result.copyWith(position: next.length));
    } else {
      final index = next.indexWhere((item) => item.key == existing.key);
      if (index >= 0) {
        next[index] = result.copyWith(position: index);
      }
    }
    await _replaceCategories(next);
  }

  Future<void> _showChipDialog([
    AdminHomepageSecondaryChipConfigModel? existing,
  ]) async {
    final keyController = TextEditingController(text: existing?.key ?? '');
    final labelController = TextEditingController(text: existing?.label ?? '');
    final colorController = TextEditingController(
      text: existing?.colorHex ?? '',
    );
    var chipType = existing?.chipType ?? 'tag';
    var enabled = existing?.enabled ?? true;

    final result = await showDialog<AdminHomepageSecondaryChipConfigModel>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => AlertDialog(
          title: Text(existing == null ? 'Add homepage chip' : 'Edit chip'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: keyController,
                decoration: const InputDecoration(labelText: 'Key'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: labelController,
                decoration: const InputDecoration(labelText: 'Label'),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: chipType,
                decoration: const InputDecoration(labelText: 'Type'),
                items: const [
                  DropdownMenuItem(value: 'tag', child: Text('Tag')),
                  DropdownMenuItem(value: 'live', child: Text('Live')),
                ],
                onChanged: (value) =>
                    setModalState(() => chipType = value ?? 'tag'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: colorController,
                decoration: const InputDecoration(labelText: 'Color hex'),
              ),
              const SizedBox(height: 12),
              SwitchListTile.adaptive(
                value: enabled,
                contentPadding: EdgeInsets.zero,
                title: const Text('Enabled'),
                onChanged: (value) => setModalState(() => enabled = value),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(
                AdminHomepageSecondaryChipConfigModel(
                  key: keyController.text.trim(),
                  label: labelController.text.trim(),
                  chipType: chipType,
                  colorHex: colorController.text.trim().isEmpty
                      ? null
                      : colorController.text.trim(),
                  position: existing?.position ?? 0,
                  enabled: enabled,
                ),
              ),
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );

    keyController.dispose();
    labelController.dispose();
    colorController.dispose();
    if (result == null) {
      return;
    }

    final next = List<AdminHomepageSecondaryChipConfigModel>.from(
      _config?.secondaryChips ?? const [],
    );
    if (existing == null) {
      next.add(result.copyWith(position: next.length));
    } else {
      final index = next.indexWhere((item) => item.key == existing.key);
      if (index >= 0) {
        next[index] = result.copyWith(position: index);
      }
    }
    await _replaceChips(next);
  }

  Future<void> _addPlacements({
    required String section,
    String? targetKey,
  }) async {
    final publishedStories = await _publishedArticleOptions();
    if (!mounted) {
      return;
    }
    final selectedStories = await showHomepageStoryMultiPickerDialog(
      context,
      stories: publishedStories,
      title: 'Add published stories',
    );
    if (selectedStories == null || selectedStories.isEmpty || !mounted) {
      return;
    }
    final current = _currentPlacements();
    final existingIds = current
        .where((item) => item.section == section && item.targetKey == targetKey)
        .map((item) => item.articleId)
        .toSet();
    final freshStories = selectedStories
        .where((story) => !existingIds.contains(story.id))
        .toList(growable: false);
    if (freshStories.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'All selected stories are already in this homepage slot.',
          ),
        ),
      );
      return;
    }
    final startPosition = current
        .where((item) => item.section == section && item.targetKey == targetKey)
        .length;
    final additions = freshStories.asMap().entries.map(
      (entry) => AdminHomepagePlacementItemModel(
        articleId: entry.value.id,
        section: section,
        targetKey: targetKey,
        position: startPosition + entry.key,
        enabled: true,
      ),
    );
    await _replacePlacements(
      [...current, ...additions],
      message: freshStories.length == 1
          ? 'Homepage placement added.'
          : '${freshStories.length} homepage placements added.',
    );
  }

  Future<void> _movePlacement(
    AdminHomepagePlacementItemModel target,
    int delta,
  ) async {
    final current = _currentPlacements();
    final bucket = current
        .where(
          (item) =>
              item.section == target.section &&
              item.targetKey == target.targetKey,
        )
        .toList(growable: true);
    final index = bucket.indexWhere(
      (item) => item.articleId == target.articleId,
    );
    final swapIndex = index + delta;
    if (index < 0 || swapIndex < 0 || swapIndex >= bucket.length) {
      return;
    }
    final temp = bucket[index];
    bucket[index] = bucket[swapIndex];
    bucket[swapIndex] = temp;
    final others = current
        .where(
          (item) =>
              item.section != target.section ||
              item.targetKey != target.targetKey,
        )
        .toList(growable: false);
    await _replacePlacements([...others, ...bucket]);
  }

  HomepageCategoryFeedModel _categorySection(
    AdminHomepageCategoryConfigModel category,
  ) {
    for (final section
        in _config?.categorySections ?? const <HomepageCategoryFeedModel>[]) {
      if (section.key == category.key) {
        return section;
      }
    }
    return HomepageCategoryFeedModel(
      key: category.key,
      label: category.label,
      colorHex: category.colorHex,
      position: category.position,
      items: const [],
    );
  }

  HomepageSecondaryChipFeedModel _chipSection(
    AdminHomepageSecondaryChipConfigModel chip,
  ) {
    for (final section
        in _config?.secondaryChipSections ??
            const <HomepageSecondaryChipFeedModel>[]) {
      if (section.key == chip.key) {
        return section;
      }
    }
    return HomepageSecondaryChipFeedModel(
      key: chip.key,
      label: chip.label,
      chipType: chip.chipType,
      colorHex: chip.colorHex,
      position: chip.position,
      items: const [],
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading && _config == null) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_errorMessage != null && _config == null) {
      return _StateCard(
        title: 'Could not load homepage configuration',
        message: _errorMessage!,
        onPressed: _load,
      );
    }

    final config = _config;
    if (config == null) {
      return _StateCard(
        title: 'Homepage configuration unavailable',
        message: 'The homepage configuration response was empty.',
        onPressed: _load,
      );
    }

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
                      'Homepage Curation',
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Control which chips, categories, and published stories appear on the client home screen.',
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: const Color(0xFF4F4A43),
                      ),
                    ),
                  ],
                ),
              ),
              if (_saving)
                const Padding(
                  padding: EdgeInsets.only(right: 12),
                  child: SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(strokeWidth: 2.2),
                  ),
                ),
              OutlinedButton.icon(
                onPressed: _saving ? null : _removeStalePlacements,
                icon: const Icon(Icons.auto_delete_outlined),
                label: const Text('Remove stale'),
              ),
              const SizedBox(width: 10),
              FilledButton.icon(
                onPressed: _saving ? null : _load,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Refresh'),
              ),
            ],
          ),
          const SizedBox(height: 20),
          _BucketCard(
            title: 'Homepage Settings',
            subtitle:
                'Control whether Latest Stories auto-fill is enabled, how many items are shown, and how far back the homepage looks for published stories.',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SwitchListTile.adaptive(
                  value: _latestAutofillEnabled,
                  onChanged: _saving
                      ? null
                      : (value) {
                          setState(() => _latestAutofillEnabled = value);
                        },
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Enable Latest Stories auto-fill'),
                  subtitle: const Text(
                    'When off, Latest Stories only shows manual homepage placements.',
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _latestItemLimitController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Latest item limit',
                          hintText: '20',
                          helperText: 'Allowed range: 1 to 50 items.',
                        ),
                        enabled: !_saving,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: _latestWindowController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Primary window (hours)',
                          hintText: '6',
                          helperText: 'Allowed range: 1 to 168 hours.',
                        ),
                        enabled: !_saving,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: _latestFallbackWindowController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Fallback window (hours)',
                          hintText: '24',
                          helperText:
                              'Used if the primary window is too sparse.',
                        ),
                        enabled: !_saving,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerRight,
                  child: FilledButton.icon(
                    onPressed: _saving ? null : _updateHomepageSettings,
                    icon: const Icon(Icons.tune_rounded),
                    label: const Text('Save'),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _BucketCard(
            title: 'Homepage Categories',
            subtitle: 'These drive the category chip rail on the home screen.',
            actionLabel: 'Add category',
            onActionPressed: _saving ? null : _showCategoryDialog,
            child: config.categories.isEmpty
                ? const _EmptyBucket(message: 'No homepage categories yet.')
                : Column(
                    children: config.categories
                        .asMap()
                        .entries
                        .map((entry) {
                          final category = entry.value;
                          return _ConfigRow(
                            title: category.label,
                            subtitle:
                                '${category.key}${category.colorHex == null ? '' : ' • ${category.colorHex}'}',
                            enabled: category.enabled,
                            onEdit: _saving
                                ? null
                                : () => _showCategoryDialog(category),
                            onMoveUp: entry.key == 0 || _saving
                                ? null
                                : () {
                                    final next =
                                        List<
                                          AdminHomepageCategoryConfigModel
                                        >.from(config.categories);
                                    final temp = next[entry.key - 1];
                                    next[entry.key - 1] = next[entry.key];
                                    next[entry.key] = temp;
                                    _replaceCategories(next);
                                  },
                            onMoveDown:
                                entry.key == config.categories.length - 1 ||
                                    _saving
                                ? null
                                : () {
                                    final next =
                                        List<
                                          AdminHomepageCategoryConfigModel
                                        >.from(config.categories);
                                    final temp = next[entry.key + 1];
                                    next[entry.key + 1] = next[entry.key];
                                    next[entry.key] = temp;
                                    _replaceCategories(next);
                                  },
                            onDelete: _saving
                                ? null
                                : () => _replaceCategories(
                                    config.categories
                                        .where(
                                          (item) => item.key != category.key,
                                        )
                                        .toList(growable: false),
                                  ),
                          );
                        })
                        .toList(growable: false),
                  ),
          ),
          const SizedBox(height: 18),
          _BucketCard(
            title: 'Homepage Chips',
            subtitle:
                'These drive the secondary chip rail under the categories.',
            actionLabel: 'Add chip',
            onActionPressed: _saving ? null : _showChipDialog,
            child: config.secondaryChips.isEmpty
                ? const _EmptyBucket(message: 'No homepage chips yet.')
                : Column(
                    children: config.secondaryChips
                        .asMap()
                        .entries
                        .map((entry) {
                          final chip = entry.value;
                          return _ConfigRow(
                            title: chip.label,
                            subtitle:
                                '${chip.key} • ${chip.chipType}${chip.colorHex == null ? '' : ' • ${chip.colorHex}'}',
                            enabled: chip.enabled,
                            onEdit: _saving
                                ? null
                                : () => _showChipDialog(chip),
                            onMoveUp: entry.key == 0 || _saving
                                ? null
                                : () {
                                    final next =
                                        List<
                                          AdminHomepageSecondaryChipConfigModel
                                        >.from(config.secondaryChips);
                                    final temp = next[entry.key - 1];
                                    next[entry.key - 1] = next[entry.key];
                                    next[entry.key] = temp;
                                    _replaceChips(next);
                                  },
                            onMoveDown:
                                entry.key == config.secondaryChips.length - 1 ||
                                    _saving
                                ? null
                                : () {
                                    final next =
                                        List<
                                          AdminHomepageSecondaryChipConfigModel
                                        >.from(config.secondaryChips);
                                    final temp = next[entry.key + 1];
                                    next[entry.key + 1] = next[entry.key];
                                    next[entry.key] = temp;
                                    _replaceChips(next);
                                  },
                            onDelete: _saving
                                ? null
                                : () => _replaceChips(
                                    config.secondaryChips
                                        .where((item) => item.key != chip.key)
                                        .toList(growable: false),
                                  ),
                          );
                        })
                        .toList(growable: false),
                  ),
          ),
          const SizedBox(height: 18),
          _PlacementBucket(
            title: 'Top Stories',
            subtitle: 'Manual-first lead stories.',
            onAdd: _saving ? null : () => _addPlacements(section: 'top'),
            items: config.topStories
                .map((item) => item.toPatchItem())
                .toList(growable: false),
            articleLookup: {
              for (final item in config.topStories)
                item.article.id: item.article,
            },
            onMoveUp: _saving ? null : (item) => _movePlacement(item, -1),
            onMoveDown: _saving ? null : (item) => _movePlacement(item, 1),
            onRemove: _saving
                ? null
                : (item) => _replacePlacements(
                    _currentPlacements()
                        .where(
                          (entry) =>
                              !(entry.articleId == item.articleId &&
                                  entry.section == item.section &&
                                  entry.targetKey == item.targetKey),
                        )
                        .toList(growable: false),
                    message: 'Homepage placement removed.',
                  ),
          ),
          const SizedBox(height: 18),
          _PlacementBucket(
            title: 'Latest Stories',
            subtitle: 'Manual-first latest rail.',
            onAdd: _saving ? null : () => _addPlacements(section: 'latest'),
            items: config.latestStories
                .map((item) => item.toPatchItem())
                .toList(growable: false),
            articleLookup: {
              for (final item in config.latestStories)
                item.article.id: item.article,
            },
            onMoveUp: _saving ? null : (item) => _movePlacement(item, -1),
            onMoveDown: _saving ? null : (item) => _movePlacement(item, 1),
            onRemove: _saving
                ? null
                : (item) => _replacePlacements(
                    _currentPlacements()
                        .where(
                          (entry) =>
                              !(entry.articleId == item.articleId &&
                                  entry.section == item.section &&
                                  entry.targetKey == item.targetKey),
                        )
                        .toList(growable: false),
                    message: 'Homepage placement removed.',
                  ),
          ),
          const SizedBox(height: 18),
          ...config.categories.map((category) {
            final section = _categorySection(category);
            return Padding(
              padding: const EdgeInsets.only(bottom: 18),
              child: _PlacementBucket(
                title: section.label,
                subtitle:
                    'Stories shown when this homepage category is selected.',
                onAdd: _saving
                    ? null
                    : () => _addPlacements(
                        section: 'category',
                        targetKey: section.key,
                      ),
                items: section.items
                    .asMap()
                    .entries
                    .map(
                      (entry) => AdminHomepagePlacementItemModel(
                        articleId: entry.value.id,
                        section: 'category',
                        targetKey: section.key,
                        position: entry.key,
                        enabled: true,
                      ),
                    )
                    .toList(growable: false),
                articleLookup: {
                  for (final item in section.items) item.id: item,
                },
                onMoveUp: _saving ? null : (item) => _movePlacement(item, -1),
                onMoveDown: _saving ? null : (item) => _movePlacement(item, 1),
                onRemove: _saving
                    ? null
                    : (item) => _replacePlacements(
                        _currentPlacements()
                            .where(
                              (entry) =>
                                  !(entry.articleId == item.articleId &&
                                      entry.section == item.section &&
                                      entry.targetKey == item.targetKey),
                            )
                            .toList(growable: false),
                        message: 'Homepage placement removed.',
                      ),
              ),
            );
          }),
          ...config.secondaryChips.map((chip) {
            final section = _chipSection(chip);
            return Padding(
              padding: const EdgeInsets.only(bottom: 18),
              child: _PlacementBucket(
                title: section.label,
                subtitle: 'Stories shown when this homepage chip is selected.',
                onAdd: _saving
                    ? null
                    : () => _addPlacements(
                        section: 'secondary_chip',
                        targetKey: section.key,
                      ),
                items: section.items
                    .asMap()
                    .entries
                    .map(
                      (entry) => AdminHomepagePlacementItemModel(
                        articleId: entry.value.id,
                        section: 'secondary_chip',
                        targetKey: section.key,
                        position: entry.key,
                        enabled: true,
                      ),
                    )
                    .toList(growable: false),
                articleLookup: {
                  for (final item in section.items) item.id: item,
                },
                onMoveUp: _saving ? null : (item) => _movePlacement(item, -1),
                onMoveDown: _saving ? null : (item) => _movePlacement(item, 1),
                onRemove: _saving
                    ? null
                    : (item) => _replacePlacements(
                        _currentPlacements()
                            .where(
                              (entry) =>
                                  !(entry.articleId == item.articleId &&
                                      entry.section == item.section &&
                                      entry.targetKey == item.targetKey),
                            )
                            .toList(growable: false),
                        message: 'Homepage placement removed.',
                      ),
              ),
            );
          }),
        ],
      ),
    );
  }
}

class _BucketCard extends StatelessWidget {
  const _BucketCard({
    required this.title,
    required this.subtitle,
    required this.child,
    this.actionLabel,
    this.onActionPressed,
  });

  final String title;
  final String subtitle;
  final Widget child;
  final String? actionLabel;
  final VoidCallback? onActionPressed;

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
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        subtitle,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: const Color(0xFF4F4A43),
                        ),
                      ),
                    ],
                  ),
                ),
                if (actionLabel != null)
                  FilledButton.tonalIcon(
                    onPressed: onActionPressed,
                    icon: const Icon(Icons.add_rounded),
                    label: Text(actionLabel!),
                  ),
              ],
            ),
            const SizedBox(height: 18),
            child,
          ],
        ),
      ),
    );
  }
}

class _PlacementBucket extends StatelessWidget {
  const _PlacementBucket({
    required this.title,
    required this.subtitle,
    required this.items,
    required this.articleLookup,
    required this.onMoveUp,
    required this.onMoveDown,
    required this.onRemove,
    this.onAdd,
  });

  final String title;
  final String subtitle;
  final List<AdminHomepagePlacementItemModel> items;
  final Map<String, NewsArticleModel> articleLookup;
  final ValueChanged<AdminHomepagePlacementItemModel>? onMoveUp;
  final ValueChanged<AdminHomepagePlacementItemModel>? onMoveDown;
  final ValueChanged<AdminHomepagePlacementItemModel>? onRemove;
  final VoidCallback? onAdd;

  @override
  Widget build(BuildContext context) {
    return _BucketCard(
      title: title,
      subtitle: subtitle,
      actionLabel: 'Add stories',
      onActionPressed: onAdd,
      child: items.isEmpty
          ? const _EmptyBucket(message: 'Nothing is curated here yet.')
          : Column(
              children: items
                  .asMap()
                  .entries
                  .map((entry) {
                    final item = entry.value;
                    final article = articleLookup[item.articleId];
                    if (article == null) {
                      return const SizedBox.shrink();
                    }
                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFFCF8),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: const Color(0xFFE2DBCF)),
                      ),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 17,
                            backgroundColor: const Color(0xFFE6F2ED),
                            child: Text(
                              '${entry.key + 1}',
                              style: const TextStyle(
                                color: Color(0xFF0F6B4B),
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  article.title,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: Theme.of(context).textTheme.titleMedium
                                      ?.copyWith(fontWeight: FontWeight.w700),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '${article.source} • ${article.category}',
                                  style: Theme.of(context).textTheme.bodySmall
                                      ?.copyWith(
                                        color: const Color(0xFF6E675C),
                                      ),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            onPressed: onMoveUp == null || entry.key == 0
                                ? null
                                : () => onMoveUp!(item),
                            icon: const Icon(Icons.keyboard_arrow_up_rounded),
                          ),
                          IconButton(
                            onPressed:
                                onMoveDown == null ||
                                    entry.key == items.length - 1
                                ? null
                                : () => onMoveDown!(item),
                            icon: const Icon(Icons.keyboard_arrow_down_rounded),
                          ),
                          IconButton(
                            onPressed: onRemove == null
                                ? null
                                : () => onRemove!(item),
                            icon: const Icon(Icons.delete_outline_rounded),
                          ),
                        ],
                      ),
                    );
                  })
                  .toList(growable: false),
            ),
    );
  }
}

class _ConfigRow extends StatelessWidget {
  const _ConfigRow({
    required this.title,
    required this.subtitle,
    required this.enabled,
    this.onEdit,
    this.onMoveUp,
    this.onMoveDown,
    this.onDelete,
  });

  final String title;
  final String subtitle;
  final bool enabled;
  final VoidCallback? onEdit;
  final VoidCallback? onMoveUp;
  final VoidCallback? onMoveDown;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFCF8),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE2DBCF)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      title,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color:
                            (enabled
                                    ? const Color(0xFF0F6B4B)
                                    : const Color(0xFF8A8275))
                                .withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        enabled ? 'Enabled' : 'Hidden',
                        style: TextStyle(
                          color: enabled
                              ? const Color(0xFF0F6B4B)
                              : const Color(0xFF8A8275),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: const Color(0xFF6E675C),
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: onMoveUp,
            icon: const Icon(Icons.keyboard_arrow_up_rounded),
          ),
          IconButton(
            onPressed: onMoveDown,
            icon: const Icon(Icons.keyboard_arrow_down_rounded),
          ),
          IconButton(onPressed: onEdit, icon: const Icon(Icons.edit_outlined)),
          IconButton(
            onPressed: onDelete,
            icon: const Icon(Icons.delete_outline_rounded),
          ),
        ],
      ),
    );
  }
}

class _EmptyBucket extends StatelessWidget {
  const _EmptyBucket({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFCF8),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE2DBCF)),
      ),
      child: Text(
        message,
        style: Theme.of(
          context,
        ).textTheme.bodyMedium?.copyWith(color: const Color(0xFF6E675C)),
      ),
    );
  }
}

class _StateCard extends StatelessWidget {
  const _StateCard({
    required this.title,
    required this.message,
    required this.onPressed,
  });

  final String title;
  final String message;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: _BucketCard(
          title: title,
          subtitle: message,
          actionLabel: 'Try again',
          onActionPressed: onPressed,
          child: const SizedBox.shrink(),
        ),
      ),
    );
  }
}
