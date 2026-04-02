import 'package:equatable/equatable.dart';

class NewsArticle extends Equatable {
  final String id;
  final String title;
  final String source;
  final String category;
  final List<String> tags;
  final String? sourceDomain;
  final String? sourceType;
  final String? summary;
  final int? commentCount;
  final String? imageUrl;
  final String? articleUrl;
  final DateTime publishedAt;
  final bool isFactChecked;
  final String status;
  final String verificationStatus;
  final bool isFeatured;
  final String? reviewNotes;

  const NewsArticle({
    required this.id,
    required this.title,
    required this.source,
    required this.category,
    required this.publishedAt,
    this.tags = const <String>[],
    this.sourceDomain,
    this.sourceType,
    this.summary,
    this.commentCount,
    this.imageUrl,
    this.articleUrl,
    this.isFactChecked = false,
    this.status = 'published',
    this.verificationStatus = 'unverified',
    this.isFeatured = false,
    this.reviewNotes,
  });

  bool get isPublished => status == 'published';
  bool get isDraft => status == 'draft';
  bool get isSubmitted => status == 'submitted';
  bool get isApproved => status == 'approved';

  @override
  List<Object?> get props => [
    id,
    title,
    source,
    category,
    tags,
    sourceDomain,
    sourceType,
    summary,
    commentCount,
    imageUrl,
    articleUrl,
    publishedAt,
    isFactChecked,
    status,
    verificationStatus,
    isFeatured,
    reviewNotes,
  ];
}
