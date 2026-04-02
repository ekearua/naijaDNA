import 'package:naijapulse/core/utils/backend_time.dart';
import 'package:naijapulse/features/news/domain/entities/news_article.dart';

class NewsArticleModel extends NewsArticle {
  const NewsArticleModel({
    required super.id,
    required super.title,
    required super.source,
    required super.category,
    super.tags = const <String>[],
    required super.publishedAt,
    super.sourceDomain,
    super.sourceType,
    super.summary,
    super.commentCount,
    super.imageUrl,
    super.articleUrl,
    super.isFactChecked,
    super.status,
    super.verificationStatus,
    super.isFeatured,
    super.reviewNotes,
  });

  factory NewsArticleModel.fromJson(Map<String, dynamic> json) {
    final publishedAtRaw = json['publishedAt'] ?? json['published_at'];
    if (publishedAtRaw == null) {
      throw const FormatException(
        'Missing published timestamp in news article.',
      );
    }

    return NewsArticleModel(
      id: (json['id'] ?? '').toString(),
      title: (json['title'] ?? '').toString(),
      source: (json['source'] ?? '').toString(),
      category: (json['category'] ?? 'General').toString(),
      tags: ((json['tags'] as List<dynamic>?) ?? const <dynamic>[])
          .map((item) => item.toString().trim())
          .where((item) => item.isNotEmpty)
          .toList(growable: false),
      sourceDomain: (json['sourceDomain'] ?? json['source_domain']) as String?,
      sourceType: (json['sourceType'] ?? json['source_type']) as String?,
      summary: json['summary'] as String?,
      commentCount: (json['commentCount'] ?? json['comment_count']) as int?,
      imageUrl: (json['imageUrl'] ?? json['image_url']) as String?,
      articleUrl:
          (json['articleUrl'] ?? json['article_url'] ?? json['url']) as String?,
      isFactChecked:
          (json['isFactChecked'] ?? json['fact_checked']) as bool? ?? false,
      status: (json['status'] ?? 'published').toString(),
      verificationStatus:
          (json['verificationStatus'] ??
                  json['verification_status'] ??
                  'unverified')
              .toString(),
      isFeatured: (json['isFeatured'] ?? json['is_featured']) as bool? ?? false,
      reviewNotes: (json['reviewNotes'] ?? json['review_notes']) as String?,
      publishedAt: parseBackendDateTime(publishedAtRaw),
    );
  }

  factory NewsArticleModel.fromEntity(NewsArticle entity) {
    return NewsArticleModel(
      id: entity.id,
      title: entity.title,
      source: entity.source,
      category: entity.category,
      tags: entity.tags,
      sourceDomain: entity.sourceDomain,
      sourceType: entity.sourceType,
      summary: entity.summary,
      commentCount: entity.commentCount,
      imageUrl: entity.imageUrl,
      articleUrl: entity.articleUrl,
      publishedAt: entity.publishedAt,
      isFactChecked: entity.isFactChecked,
      status: entity.status,
      verificationStatus: entity.verificationStatus,
      isFeatured: entity.isFeatured,
      reviewNotes: entity.reviewNotes,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'source': source,
      'category': category,
      'tags': tags,
      'sourceDomain': sourceDomain,
      'sourceType': sourceType,
      'summary': summary,
      'commentCount': commentCount,
      'imageUrl': imageUrl,
      'articleUrl': articleUrl,
      'isFactChecked': isFactChecked,
      'status': status,
      'verificationStatus': verificationStatus,
      'isFeatured': isFeatured,
      'reviewNotes': reviewNotes,
      'publishedAt': publishedAt.toIso8601String(),
    };
  }
}
