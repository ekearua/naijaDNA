class NewsReadableTextModel {
  const NewsReadableTextModel({
    required this.articleId,
    required this.title,
    required this.source,
    required this.text,
    required this.wordCount,
    required this.extractionMethod,
    required this.usedFallback,
    this.articleUrl,
  });

  final String articleId;
  final String title;
  final String source;
  final String? articleUrl;
  final String text;
  final int wordCount;
  final String extractionMethod;
  final bool usedFallback;

  factory NewsReadableTextModel.fromJson(Map<String, dynamic> json) {
    return NewsReadableTextModel(
      articleId: (json['articleId'] ?? json['article_id'] ?? '').toString(),
      title: (json['title'] ?? '').toString(),
      source: (json['source'] ?? '').toString(),
      articleUrl:
          (json['articleUrl'] ?? json['article_url'] ?? json['url']) as String?,
      text: (json['text'] ?? '').toString(),
      wordCount: (json['wordCount'] ?? json['word_count'] ?? 0) as int,
      extractionMethod:
          (json['extractionMethod'] ?? json['extraction_method'] ?? 'unknown')
              .toString(),
      usedFallback:
          (json['usedFallback'] ?? json['used_fallback']) as bool? ?? false,
    );
  }
}
