const List<String> kEditorialArticleCategories = <String>[
  'World News',
  'Business',
  'Technology',
  'Entertainment',
  'Science',
  'Sports',
  'Health',
  'General',
];

List<String> articleCategoryOptionsFor(String? currentCategory) {
  final normalizedCurrent = (currentCategory ?? '').trim();
  final values = <String>[
    ...kEditorialArticleCategories,
    if (normalizedCurrent.isNotEmpty &&
        !kEditorialArticleCategories.any(
          (item) => item.toLowerCase() == normalizedCurrent.toLowerCase(),
        ))
      normalizedCurrent,
  ];
  return values;
}

List<String> parseArticleTagDraft(String raw) {
  final seen = <String>{};
  final tags = <String>[];
  for (final part in raw.split(RegExp(r'[,;\n]'))) {
    final normalized = part.trim();
    if (normalized.isEmpty) {
      continue;
    }
    final key = normalized.toLowerCase();
    if (seen.add(key)) {
      tags.add(normalized);
    }
  }
  return tags;
}

String articleTagDraftFromList(Iterable<String> tags) {
  return parseArticleTagDraft(tags.join(', ')).join(', ');
}
