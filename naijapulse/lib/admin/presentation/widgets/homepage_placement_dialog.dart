import 'package:flutter/material.dart';
import 'package:naijapulse/admin/data/models/admin_models.dart';
import 'package:naijapulse/features/news/data/models/news_article_model.dart';

class HomepagePlacementSelection {
  const HomepagePlacementSelection({required this.section, this.targetKey});

  final String section;
  final String? targetKey;
}

Future<HomepagePlacementSelection?> showHomepagePlacementDialog(
  BuildContext context, {
  required List<AdminHomepageCategoryConfigModel> categories,
  required List<AdminHomepageSecondaryChipConfigModel> secondaryChips,
  String initialSection = 'top',
  String? initialTargetKey,
}) {
  var selectedSection = initialSection;
  var selectedTargetKey = initialTargetKey;

  List<DropdownMenuItem<String>> buildTargetItems() {
    switch (selectedSection) {
      case 'category':
        return categories
            .map(
              (item) => DropdownMenuItem<String>(
                value: item.key,
                child: Text(item.label),
              ),
            )
            .toList(growable: false);
      case 'secondary_chip':
        return secondaryChips
            .map(
              (item) => DropdownMenuItem<String>(
                value: item.key,
                child: Text(item.label),
              ),
            )
            .toList(growable: false);
      default:
        return const <DropdownMenuItem<String>>[];
    }
  }

  return showDialog<HomepagePlacementSelection>(
    context: context,
    builder: (context) {
      return StatefulBuilder(
        builder: (context, setModalState) {
          final targetItems = buildTargetItems();
          final needsTarget =
              selectedSection == 'category' ||
              selectedSection == 'secondary_chip';
          if (needsTarget &&
              (selectedTargetKey == null ||
                  !targetItems.any(
                    (item) => item.value == selectedTargetKey,
                  ))) {
            selectedTargetKey = targetItems.isNotEmpty
                ? targetItems.first.value
                : null;
          }

          return AlertDialog(
            title: const Text('Add to homepage'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                DropdownButtonFormField<String>(
                  initialValue: selectedSection,
                  decoration: const InputDecoration(labelText: 'Section'),
                  items: const [
                    DropdownMenuItem(value: 'top', child: Text('Top Stories')),
                    DropdownMenuItem(
                      value: 'latest',
                      child: Text('Latest Stories'),
                    ),
                    DropdownMenuItem(
                      value: 'category',
                      child: Text('Homepage Category'),
                    ),
                    DropdownMenuItem(
                      value: 'secondary_chip',
                      child: Text('Homepage Chip'),
                    ),
                  ],
                  onChanged: (value) {
                    if (value == null) {
                      return;
                    }
                    setModalState(() {
                      selectedSection = value;
                      selectedTargetKey = null;
                    });
                  },
                ),
                if (needsTarget) ...[
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    initialValue: selectedTargetKey,
                    decoration: InputDecoration(
                      labelText: selectedSection == 'category'
                          ? 'Category'
                          : 'Chip',
                    ),
                    items: targetItems,
                    onChanged: (value) =>
                        setModalState(() => selectedTargetKey = value),
                  ),
                ],
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: needsTarget && selectedTargetKey == null
                    ? null
                    : () => Navigator.of(context).pop(
                        HomepagePlacementSelection(
                          section: selectedSection,
                          targetKey: selectedTargetKey,
                        ),
                      ),
                child: const Text('Add'),
              ),
            ],
          );
        },
      );
    },
  );
}

Future<NewsArticleModel?> showHomepageStoryPickerDialog(
  BuildContext context, {
  required List<NewsArticleModel> stories,
  String title = 'Select story',
}) {
  final controller = TextEditingController();
  var query = '';

  return showDialog<NewsArticleModel>(
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (context, setModalState) {
        final normalizedQuery = query.trim().toLowerCase();
        final filteredStories = stories
            .where((story) {
              if (normalizedQuery.isEmpty) {
                return true;
              }
              final haystack =
                  '${story.title} ${story.source} ${story.category}'
                      .toLowerCase();
              return haystack.contains(normalizedQuery);
            })
            .toList(growable: false);

        return AlertDialog(
          title: Text(title),
          content: SizedBox(
            width: 560,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: controller,
                  decoration: const InputDecoration(
                    labelText: 'Search published stories',
                    prefixIcon: Icon(Icons.search_rounded),
                  ),
                  onChanged: (value) => setModalState(() => query = value),
                ),
                const SizedBox(height: 16),
                Flexible(
                  child: filteredStories.isEmpty
                      ? const Center(
                          child: Text(
                            'No published stories matched this search.',
                          ),
                        )
                      : ListView.separated(
                          shrinkWrap: true,
                          itemCount: filteredStories.length,
                          separatorBuilder: (_, __) => const Divider(height: 1),
                          itemBuilder: (context, index) {
                            final story = filteredStories[index];
                            return ListTile(
                              title: Text(
                                story.title,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              subtitle: Text(
                                '${story.source} • ${story.category}',
                              ),
                              onTap: () => Navigator.of(context).pop(story),
                            );
                          },
                        ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
          ],
        );
      },
    ),
  ).whenComplete(controller.dispose);
}

Future<List<NewsArticleModel>?> showHomepageStoryMultiPickerDialog(
  BuildContext context, {
  required List<NewsArticleModel> stories,
  String title = 'Select stories',
}) {
  final controller = TextEditingController();
  var query = '';
  final selectedIds = <String>{};

  return showDialog<List<NewsArticleModel>>(
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (context, setModalState) {
        final normalizedQuery = query.trim().toLowerCase();
        final filteredStories = stories
            .where((story) {
              if (normalizedQuery.isEmpty) {
                return true;
              }
              final haystack =
                  '${story.title} ${story.source} ${story.category}'
                      .toLowerCase();
              return haystack.contains(normalizedQuery);
            })
            .toList(growable: false);

        return AlertDialog(
          title: Text(title),
          content: SizedBox(
            width: 640,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: controller,
                  decoration: const InputDecoration(
                    labelText: 'Search published stories',
                    prefixIcon: Icon(Icons.search_rounded),
                  ),
                  onChanged: (value) => setModalState(() => query = value),
                ),
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    selectedIds.isEmpty
                        ? 'No stories selected'
                        : '${selectedIds.length} selected',
                  ),
                ),
                const SizedBox(height: 12),
                Flexible(
                  child: filteredStories.isEmpty
                      ? const Center(
                          child: Text(
                            'No published stories matched this search.',
                          ),
                        )
                      : ListView.separated(
                          shrinkWrap: true,
                          itemCount: filteredStories.length,
                          separatorBuilder: (_, __) => const Divider(height: 1),
                          itemBuilder: (context, index) {
                            final story = filteredStories[index];
                            final isSelected = selectedIds.contains(story.id);
                            return CheckboxListTile(
                              value: isSelected,
                              controlAffinity: ListTileControlAffinity.leading,
                              contentPadding: EdgeInsets.zero,
                              title: Text(
                                story.title,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              subtitle: Text(
                                '${story.source} • ${story.category}',
                              ),
                              onChanged: (_) => setModalState(() {
                                if (isSelected) {
                                  selectedIds.remove(story.id);
                                } else {
                                  selectedIds.add(story.id);
                                }
                              }),
                            );
                          },
                        ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: selectedIds.isEmpty
                  ? null
                  : () => Navigator.of(context).pop(
                      stories
                          .where((story) => selectedIds.contains(story.id))
                          .toList(growable: false),
                    ),
              child: const Text('Add selected'),
            ),
          ],
        );
      },
    ),
  ).whenComplete(controller.dispose);
}
