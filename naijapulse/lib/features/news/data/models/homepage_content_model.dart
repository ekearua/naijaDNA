import 'package:naijapulse/features/news/data/models/news_article_model.dart';

class HomepageCategoryFeedModel {
  const HomepageCategoryFeedModel({
    required this.key,
    required this.label,
    required this.position,
    required this.items,
    this.colorHex,
  });

  final String key;
  final String label;
  final String? colorHex;
  final int position;
  final List<NewsArticleModel> items;

  factory HomepageCategoryFeedModel.fromJson(Map<String, dynamic> json) =>
      HomepageCategoryFeedModel(
        key: (json['key'] as String?) ?? '',
        label: (json['label'] as String?) ?? '',
        colorHex: json['color_hex'] as String?,
        position: ((json['position'] as num?) ?? 0).toInt(),
        items: ((json['items'] as List<dynamic>?) ?? const <dynamic>[])
            .whereType<Map<String, dynamic>>()
            .map(NewsArticleModel.fromJson)
            .toList(),
      );
}

class HomepageSecondaryChipFeedModel {
  const HomepageSecondaryChipFeedModel({
    required this.key,
    required this.label,
    required this.chipType,
    required this.position,
    required this.items,
    this.colorHex,
  });

  final String key;
  final String label;
  final String chipType;
  final String? colorHex;
  final int position;
  final List<NewsArticleModel> items;

  factory HomepageSecondaryChipFeedModel.fromJson(Map<String, dynamic> json) =>
      HomepageSecondaryChipFeedModel(
        key: (json['key'] as String?) ?? '',
        label: (json['label'] as String?) ?? '',
        chipType: (json['chip_type'] as String?) ?? 'tag',
        colorHex: json['color_hex'] as String?,
        position: ((json['position'] as num?) ?? 0).toInt(),
        items: ((json['items'] as List<dynamic>?) ?? const <dynamic>[])
            .whereType<Map<String, dynamic>>()
            .map(NewsArticleModel.fromJson)
            .toList(),
      );
}

class HomepageContentModel {
  const HomepageContentModel({
    required this.generatedAt,
    required this.topStories,
    required this.latestStories,
    required this.categories,
    required this.secondaryChips,
  });

  final DateTime generatedAt;
  final List<NewsArticleModel> topStories;
  final List<NewsArticleModel> latestStories;
  final List<HomepageCategoryFeedModel> categories;
  final List<HomepageSecondaryChipFeedModel> secondaryChips;

  bool get isEmpty =>
      topStories.isEmpty &&
      latestStories.isEmpty &&
      categories.every((item) => item.items.isEmpty) &&
      secondaryChips.every((item) => item.items.isEmpty);

  factory HomepageContentModel.fromJson(
    Map<String, dynamic> json,
  ) => HomepageContentModel(
    generatedAt:
        DateTime.tryParse((json['generated_at'] as String?) ?? '') ??
        DateTime.fromMillisecondsSinceEpoch(0),
    topStories: ((json['top_stories'] as List<dynamic>?) ?? const <dynamic>[])
        .whereType<Map<String, dynamic>>()
        .map(NewsArticleModel.fromJson)
        .toList(),
    latestStories:
        ((json['latest_stories'] as List<dynamic>?) ?? const <dynamic>[])
            .whereType<Map<String, dynamic>>()
            .map(NewsArticleModel.fromJson)
            .toList(),
    categories: ((json['categories'] as List<dynamic>?) ?? const <dynamic>[])
        .whereType<Map<String, dynamic>>()
        .map(HomepageCategoryFeedModel.fromJson)
        .toList(),
    secondaryChips:
        ((json['secondary_chips'] as List<dynamic>?) ?? const <dynamic>[])
            .whereType<Map<String, dynamic>>()
            .map(HomepageSecondaryChipFeedModel.fromJson)
            .toList(),
  );
}
