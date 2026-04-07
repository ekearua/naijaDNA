import 'package:equatable/equatable.dart';
import 'package:naijapulse/core/utils/backend_time.dart';
import 'package:naijapulse/features/news/data/models/news_article_model.dart';
import 'package:naijapulse/features/polls/data/models/poll_model.dart';

class LiveUpdateAuthorModel extends Equatable {
  const LiveUpdateAuthorModel({this.id, required this.displayName});

  final String? id;
  final String displayName;

  factory LiveUpdateAuthorModel.fromJson(Map<String, dynamic> json) {
    return LiveUpdateAuthorModel(
      id: (json['id'] ?? '').toString().trim().isEmpty
          ? null
          : (json['id'] ?? '').toString(),
      displayName:
          (json['display_name'] ?? json['displayName'] ?? 'Editorial Desk')
              .toString(),
    );
  }

  @override
  List<Object?> get props => [id, displayName];
}

class LiveUpdateEntryModel extends Equatable {
  const LiveUpdateEntryModel({
    required this.id,
    required this.pageId,
    required this.blockType,
    required this.publishedAt,
    this.headline,
    this.body,
    this.imageUrl,
    this.imageCaption,
    this.linkedArticle,
    this.linkedPoll,
    this.isPinned = false,
    this.isVisible = true,
    this.author,
  });

  final String id;
  final String pageId;
  final String blockType;
  final String? headline;
  final String? body;
  final String? imageUrl;
  final String? imageCaption;
  final NewsArticleModel? linkedArticle;
  final PollModel? linkedPoll;
  final DateTime publishedAt;
  final bool isPinned;
  final bool isVisible;
  final LiveUpdateAuthorModel? author;

  factory LiveUpdateEntryModel.fromJson(Map<String, dynamic> json) {
    final rawArticle = json['linked_article'] ?? json['linkedArticle'];
    final rawPoll = json['linked_poll'] ?? json['linkedPoll'];
    final rawAuthor = json['author'];
    return LiveUpdateEntryModel(
      id: (json['id'] ?? '').toString(),
      pageId: (json['page_id'] ?? json['pageId'] ?? '').toString(),
      blockType: (json['block_type'] ?? json['blockType'] ?? 'text').toString(),
      headline: json['headline'] as String?,
      body: json['body'] as String?,
      imageUrl: (json['image_url'] ?? json['imageUrl']) as String?,
      imageCaption: (json['image_caption'] ?? json['imageCaption']) as String?,
      linkedArticle: rawArticle is Map<String, dynamic>
          ? NewsArticleModel.fromJson(rawArticle)
          : null,
      linkedPoll: rawPoll is Map<String, dynamic>
          ? PollModel.fromJson(rawPoll)
          : null,
      publishedAt: parseBackendDateTime(
        json['published_at'] ?? json['publishedAt'],
      ),
      isPinned: (json['is_pinned'] ?? json['isPinned']) as bool? ?? false,
      isVisible: (json['is_visible'] ?? json['isVisible']) as bool? ?? true,
      author: rawAuthor is Map<String, dynamic>
          ? LiveUpdateAuthorModel.fromJson(rawAuthor)
          : null,
    );
  }

  LiveUpdateEntryModel copyWith({
    String? headline,
    String? body,
    String? imageUrl,
    String? imageCaption,
    NewsArticleModel? linkedArticle,
    PollModel? linkedPoll,
    DateTime? publishedAt,
    bool? isPinned,
    bool? isVisible,
    LiveUpdateAuthorModel? author,
  }) {
    return LiveUpdateEntryModel(
      id: id,
      pageId: pageId,
      blockType: blockType,
      headline: headline ?? this.headline,
      body: body ?? this.body,
      imageUrl: imageUrl ?? this.imageUrl,
      imageCaption: imageCaption ?? this.imageCaption,
      linkedArticle: linkedArticle ?? this.linkedArticle,
      linkedPoll: linkedPoll ?? this.linkedPoll,
      publishedAt: publishedAt ?? this.publishedAt,
      isPinned: isPinned ?? this.isPinned,
      isVisible: isVisible ?? this.isVisible,
      author: author ?? this.author,
    );
  }

  @override
  List<Object?> get props => [
    id,
    pageId,
    blockType,
    headline,
    body,
    imageUrl,
    imageCaption,
    linkedArticle,
    linkedPoll,
    publishedAt,
    isPinned,
    isVisible,
    author,
  ];
}

class LiveUpdatePageSummaryModel extends Equatable {
  const LiveUpdatePageSummaryModel({
    required this.id,
    required this.slug,
    required this.title,
    required this.summary,
    required this.category,
    required this.status,
    required this.entryCount,
    this.heroKicker,
    this.coverImageUrl,
    this.isFeatured = false,
    this.isBreaking = false,
    this.startedAt,
    this.endedAt,
    this.lastPublishedEntryAt,
  });

  final String id;
  final String slug;
  final String title;
  final String summary;
  final String category;
  final String status;
  final int entryCount;
  final String? heroKicker;
  final String? coverImageUrl;
  final bool isFeatured;
  final bool isBreaking;
  final DateTime? startedAt;
  final DateTime? endedAt;
  final DateTime? lastPublishedEntryAt;

  bool get isLive => status == 'live';

  factory LiveUpdatePageSummaryModel.fromJson(Map<String, dynamic> json) {
    return LiveUpdatePageSummaryModel(
      id: (json['id'] ?? '').toString(),
      slug: (json['slug'] ?? '').toString(),
      title: (json['title'] ?? '').toString(),
      summary: (json['summary'] ?? '').toString(),
      heroKicker: (json['hero_kicker'] ?? json['heroKicker']) as String?,
      category: (json['category'] ?? 'General').toString(),
      coverImageUrl:
          (json['cover_image_url'] ?? json['coverImageUrl']) as String?,
      status: (json['status'] ?? 'draft').toString(),
      isFeatured: (json['is_featured'] ?? json['isFeatured']) as bool? ?? false,
      isBreaking: (json['is_breaking'] ?? json['isBreaking']) as bool? ?? false,
      startedAt: parseBackendDateTimeOrNull(
        json['started_at'] ?? json['startedAt'],
      ),
      endedAt: parseBackendDateTimeOrNull(json['ended_at'] ?? json['endedAt']),
      lastPublishedEntryAt: parseBackendDateTimeOrNull(
        json['last_published_entry_at'] ?? json['lastPublishedEntryAt'],
      ),
      entryCount:
          ((json['entry_count'] ?? json['entryCount']) as num?)?.toInt() ?? 0,
    );
  }

  LiveUpdatePageSummaryModel copyWith({
    String? title,
    String? summary,
    String? category,
    String? status,
    int? entryCount,
    String? heroKicker,
    String? coverImageUrl,
    bool? isFeatured,
    bool? isBreaking,
    DateTime? startedAt,
    DateTime? endedAt,
    DateTime? lastPublishedEntryAt,
  }) {
    return LiveUpdatePageSummaryModel(
      id: id,
      slug: slug,
      title: title ?? this.title,
      summary: summary ?? this.summary,
      heroKicker: heroKicker ?? this.heroKicker,
      category: category ?? this.category,
      coverImageUrl: coverImageUrl ?? this.coverImageUrl,
      status: status ?? this.status,
      isFeatured: isFeatured ?? this.isFeatured,
      isBreaking: isBreaking ?? this.isBreaking,
      startedAt: startedAt ?? this.startedAt,
      endedAt: endedAt ?? this.endedAt,
      lastPublishedEntryAt: lastPublishedEntryAt ?? this.lastPublishedEntryAt,
      entryCount: entryCount ?? this.entryCount,
    );
  }

  @override
  List<Object?> get props => [
    id,
    slug,
    title,
    summary,
    heroKicker,
    category,
    coverImageUrl,
    status,
    isFeatured,
    isBreaking,
    startedAt,
    endedAt,
    lastPublishedEntryAt,
    entryCount,
  ];
}

class LiveUpdatePageDetailModel extends Equatable {
  const LiveUpdatePageDetailModel({required this.page, required this.entries});

  final LiveUpdatePageSummaryModel page;
  final List<LiveUpdateEntryModel> entries;

  factory LiveUpdatePageDetailModel.fromJson(Map<String, dynamic> json) {
    final rawPage = json['page'];
    final rawEntries = json['entries'];
    if (rawPage is! Map<String, dynamic>) {
      throw const FormatException('Missing live update page payload.');
    }
    return LiveUpdatePageDetailModel(
      page: LiveUpdatePageSummaryModel.fromJson(rawPage),
      entries: (rawEntries as List<dynamic>? ?? const <dynamic>[])
          .whereType<Map<String, dynamic>>()
          .map(LiveUpdateEntryModel.fromJson)
          .toList(growable: false),
    );
  }

  LiveUpdatePageDetailModel copyWith({
    LiveUpdatePageSummaryModel? page,
    List<LiveUpdateEntryModel>? entries,
  }) {
    return LiveUpdatePageDetailModel(
      page: page ?? this.page,
      entries: entries ?? this.entries,
    );
  }

  @override
  List<Object?> get props => [page, entries];
}
