// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_database.dart';

// ignore_for_file: type=lint
class $NewsCacheEntriesTable extends NewsCacheEntries
    with TableInfo<$NewsCacheEntriesTable, NewsCacheEntry> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $NewsCacheEntriesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _bucketMeta = const VerificationMeta('bucket');
  @override
  late final GeneratedColumn<String> bucket = GeneratedColumn<String>(
    'bucket',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _requestCategoryMeta = const VerificationMeta(
    'requestCategory',
  );
  @override
  late final GeneratedColumn<String> requestCategory = GeneratedColumn<String>(
    'request_category',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _sortOrderMeta = const VerificationMeta(
    'sortOrder',
  );
  @override
  late final GeneratedColumn<int> sortOrder = GeneratedColumn<int>(
    'sort_order',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _articleIdMeta = const VerificationMeta(
    'articleId',
  );
  @override
  late final GeneratedColumn<String> articleId = GeneratedColumn<String>(
    'article_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  @override
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
    'title',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _sourceMeta = const VerificationMeta('source');
  @override
  late final GeneratedColumn<String> source = GeneratedColumn<String>(
    'source',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _articleCategoryMeta = const VerificationMeta(
    'articleCategory',
  );
  @override
  late final GeneratedColumn<String> articleCategory = GeneratedColumn<String>(
    'article_category',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _summaryMeta = const VerificationMeta(
    'summary',
  );
  @override
  late final GeneratedColumn<String> summary = GeneratedColumn<String>(
    'summary',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _imageUrlMeta = const VerificationMeta(
    'imageUrl',
  );
  @override
  late final GeneratedColumn<String> imageUrl = GeneratedColumn<String>(
    'image_url',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _articleUrlMeta = const VerificationMeta(
    'articleUrl',
  );
  @override
  late final GeneratedColumn<String> articleUrl = GeneratedColumn<String>(
    'article_url',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _publishedAtMeta = const VerificationMeta(
    'publishedAt',
  );
  @override
  late final GeneratedColumn<DateTime> publishedAt = GeneratedColumn<DateTime>(
    'published_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _isFactCheckedMeta = const VerificationMeta(
    'isFactChecked',
  );
  @override
  late final GeneratedColumn<bool> isFactChecked = GeneratedColumn<bool>(
    'is_fact_checked',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_fact_checked" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    bucket,
    requestCategory,
    sortOrder,
    articleId,
    title,
    source,
    articleCategory,
    summary,
    imageUrl,
    articleUrl,
    publishedAt,
    isFactChecked,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'news_cache_entries';
  @override
  VerificationContext validateIntegrity(
    Insertable<NewsCacheEntry> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('bucket')) {
      context.handle(
        _bucketMeta,
        bucket.isAcceptableOrUnknown(data['bucket']!, _bucketMeta),
      );
    } else if (isInserting) {
      context.missing(_bucketMeta);
    }
    if (data.containsKey('request_category')) {
      context.handle(
        _requestCategoryMeta,
        requestCategory.isAcceptableOrUnknown(
          data['request_category']!,
          _requestCategoryMeta,
        ),
      );
    }
    if (data.containsKey('sort_order')) {
      context.handle(
        _sortOrderMeta,
        sortOrder.isAcceptableOrUnknown(data['sort_order']!, _sortOrderMeta),
      );
    } else if (isInserting) {
      context.missing(_sortOrderMeta);
    }
    if (data.containsKey('article_id')) {
      context.handle(
        _articleIdMeta,
        articleId.isAcceptableOrUnknown(data['article_id']!, _articleIdMeta),
      );
    } else if (isInserting) {
      context.missing(_articleIdMeta);
    }
    if (data.containsKey('title')) {
      context.handle(
        _titleMeta,
        title.isAcceptableOrUnknown(data['title']!, _titleMeta),
      );
    } else if (isInserting) {
      context.missing(_titleMeta);
    }
    if (data.containsKey('source')) {
      context.handle(
        _sourceMeta,
        source.isAcceptableOrUnknown(data['source']!, _sourceMeta),
      );
    } else if (isInserting) {
      context.missing(_sourceMeta);
    }
    if (data.containsKey('article_category')) {
      context.handle(
        _articleCategoryMeta,
        articleCategory.isAcceptableOrUnknown(
          data['article_category']!,
          _articleCategoryMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_articleCategoryMeta);
    }
    if (data.containsKey('summary')) {
      context.handle(
        _summaryMeta,
        summary.isAcceptableOrUnknown(data['summary']!, _summaryMeta),
      );
    }
    if (data.containsKey('image_url')) {
      context.handle(
        _imageUrlMeta,
        imageUrl.isAcceptableOrUnknown(data['image_url']!, _imageUrlMeta),
      );
    }
    if (data.containsKey('article_url')) {
      context.handle(
        _articleUrlMeta,
        articleUrl.isAcceptableOrUnknown(data['article_url']!, _articleUrlMeta),
      );
    }
    if (data.containsKey('published_at')) {
      context.handle(
        _publishedAtMeta,
        publishedAt.isAcceptableOrUnknown(
          data['published_at']!,
          _publishedAtMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_publishedAtMeta);
    }
    if (data.containsKey('is_fact_checked')) {
      context.handle(
        _isFactCheckedMeta,
        isFactChecked.isAcceptableOrUnknown(
          data['is_fact_checked']!,
          _isFactCheckedMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  List<Set<GeneratedColumn>> get uniqueKeys => [
    {bucket, requestCategory, articleId},
  ];
  @override
  NewsCacheEntry map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return NewsCacheEntry(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      bucket: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}bucket'],
      )!,
      requestCategory: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}request_category'],
      ),
      sortOrder: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}sort_order'],
      )!,
      articleId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}article_id'],
      )!,
      title: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}title'],
      )!,
      source: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}source'],
      )!,
      articleCategory: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}article_category'],
      )!,
      summary: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}summary'],
      ),
      imageUrl: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}image_url'],
      ),
      articleUrl: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}article_url'],
      ),
      publishedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}published_at'],
      )!,
      isFactChecked: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_fact_checked'],
      )!,
    );
  }

  @override
  $NewsCacheEntriesTable createAlias(String alias) {
    return $NewsCacheEntriesTable(attachedDatabase, alias);
  }
}

class NewsCacheEntry extends DataClass implements Insertable<NewsCacheEntry> {
  final int id;
  final String bucket;
  final String? requestCategory;
  final int sortOrder;
  final String articleId;
  final String title;
  final String source;
  final String articleCategory;
  final String? summary;
  final String? imageUrl;
  final String? articleUrl;
  final DateTime publishedAt;
  final bool isFactChecked;
  const NewsCacheEntry({
    required this.id,
    required this.bucket,
    this.requestCategory,
    required this.sortOrder,
    required this.articleId,
    required this.title,
    required this.source,
    required this.articleCategory,
    this.summary,
    this.imageUrl,
    this.articleUrl,
    required this.publishedAt,
    required this.isFactChecked,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['bucket'] = Variable<String>(bucket);
    if (!nullToAbsent || requestCategory != null) {
      map['request_category'] = Variable<String>(requestCategory);
    }
    map['sort_order'] = Variable<int>(sortOrder);
    map['article_id'] = Variable<String>(articleId);
    map['title'] = Variable<String>(title);
    map['source'] = Variable<String>(source);
    map['article_category'] = Variable<String>(articleCategory);
    if (!nullToAbsent || summary != null) {
      map['summary'] = Variable<String>(summary);
    }
    if (!nullToAbsent || imageUrl != null) {
      map['image_url'] = Variable<String>(imageUrl);
    }
    if (!nullToAbsent || articleUrl != null) {
      map['article_url'] = Variable<String>(articleUrl);
    }
    map['published_at'] = Variable<DateTime>(publishedAt);
    map['is_fact_checked'] = Variable<bool>(isFactChecked);
    return map;
  }

  NewsCacheEntriesCompanion toCompanion(bool nullToAbsent) {
    return NewsCacheEntriesCompanion(
      id: Value(id),
      bucket: Value(bucket),
      requestCategory: requestCategory == null && nullToAbsent
          ? const Value.absent()
          : Value(requestCategory),
      sortOrder: Value(sortOrder),
      articleId: Value(articleId),
      title: Value(title),
      source: Value(source),
      articleCategory: Value(articleCategory),
      summary: summary == null && nullToAbsent
          ? const Value.absent()
          : Value(summary),
      imageUrl: imageUrl == null && nullToAbsent
          ? const Value.absent()
          : Value(imageUrl),
      articleUrl: articleUrl == null && nullToAbsent
          ? const Value.absent()
          : Value(articleUrl),
      publishedAt: Value(publishedAt),
      isFactChecked: Value(isFactChecked),
    );
  }

  factory NewsCacheEntry.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return NewsCacheEntry(
      id: serializer.fromJson<int>(json['id']),
      bucket: serializer.fromJson<String>(json['bucket']),
      requestCategory: serializer.fromJson<String?>(json['requestCategory']),
      sortOrder: serializer.fromJson<int>(json['sortOrder']),
      articleId: serializer.fromJson<String>(json['articleId']),
      title: serializer.fromJson<String>(json['title']),
      source: serializer.fromJson<String>(json['source']),
      articleCategory: serializer.fromJson<String>(json['articleCategory']),
      summary: serializer.fromJson<String?>(json['summary']),
      imageUrl: serializer.fromJson<String?>(json['imageUrl']),
      articleUrl: serializer.fromJson<String?>(json['articleUrl']),
      publishedAt: serializer.fromJson<DateTime>(json['publishedAt']),
      isFactChecked: serializer.fromJson<bool>(json['isFactChecked']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'bucket': serializer.toJson<String>(bucket),
      'requestCategory': serializer.toJson<String?>(requestCategory),
      'sortOrder': serializer.toJson<int>(sortOrder),
      'articleId': serializer.toJson<String>(articleId),
      'title': serializer.toJson<String>(title),
      'source': serializer.toJson<String>(source),
      'articleCategory': serializer.toJson<String>(articleCategory),
      'summary': serializer.toJson<String?>(summary),
      'imageUrl': serializer.toJson<String?>(imageUrl),
      'articleUrl': serializer.toJson<String?>(articleUrl),
      'publishedAt': serializer.toJson<DateTime>(publishedAt),
      'isFactChecked': serializer.toJson<bool>(isFactChecked),
    };
  }

  NewsCacheEntry copyWith({
    int? id,
    String? bucket,
    Value<String?> requestCategory = const Value.absent(),
    int? sortOrder,
    String? articleId,
    String? title,
    String? source,
    String? articleCategory,
    Value<String?> summary = const Value.absent(),
    Value<String?> imageUrl = const Value.absent(),
    Value<String?> articleUrl = const Value.absent(),
    DateTime? publishedAt,
    bool? isFactChecked,
  }) => NewsCacheEntry(
    id: id ?? this.id,
    bucket: bucket ?? this.bucket,
    requestCategory: requestCategory.present
        ? requestCategory.value
        : this.requestCategory,
    sortOrder: sortOrder ?? this.sortOrder,
    articleId: articleId ?? this.articleId,
    title: title ?? this.title,
    source: source ?? this.source,
    articleCategory: articleCategory ?? this.articleCategory,
    summary: summary.present ? summary.value : this.summary,
    imageUrl: imageUrl.present ? imageUrl.value : this.imageUrl,
    articleUrl: articleUrl.present ? articleUrl.value : this.articleUrl,
    publishedAt: publishedAt ?? this.publishedAt,
    isFactChecked: isFactChecked ?? this.isFactChecked,
  );
  NewsCacheEntry copyWithCompanion(NewsCacheEntriesCompanion data) {
    return NewsCacheEntry(
      id: data.id.present ? data.id.value : this.id,
      bucket: data.bucket.present ? data.bucket.value : this.bucket,
      requestCategory: data.requestCategory.present
          ? data.requestCategory.value
          : this.requestCategory,
      sortOrder: data.sortOrder.present ? data.sortOrder.value : this.sortOrder,
      articleId: data.articleId.present ? data.articleId.value : this.articleId,
      title: data.title.present ? data.title.value : this.title,
      source: data.source.present ? data.source.value : this.source,
      articleCategory: data.articleCategory.present
          ? data.articleCategory.value
          : this.articleCategory,
      summary: data.summary.present ? data.summary.value : this.summary,
      imageUrl: data.imageUrl.present ? data.imageUrl.value : this.imageUrl,
      articleUrl: data.articleUrl.present
          ? data.articleUrl.value
          : this.articleUrl,
      publishedAt: data.publishedAt.present
          ? data.publishedAt.value
          : this.publishedAt,
      isFactChecked: data.isFactChecked.present
          ? data.isFactChecked.value
          : this.isFactChecked,
    );
  }

  @override
  String toString() {
    return (StringBuffer('NewsCacheEntry(')
          ..write('id: $id, ')
          ..write('bucket: $bucket, ')
          ..write('requestCategory: $requestCategory, ')
          ..write('sortOrder: $sortOrder, ')
          ..write('articleId: $articleId, ')
          ..write('title: $title, ')
          ..write('source: $source, ')
          ..write('articleCategory: $articleCategory, ')
          ..write('summary: $summary, ')
          ..write('imageUrl: $imageUrl, ')
          ..write('articleUrl: $articleUrl, ')
          ..write('publishedAt: $publishedAt, ')
          ..write('isFactChecked: $isFactChecked')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    bucket,
    requestCategory,
    sortOrder,
    articleId,
    title,
    source,
    articleCategory,
    summary,
    imageUrl,
    articleUrl,
    publishedAt,
    isFactChecked,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is NewsCacheEntry &&
          other.id == this.id &&
          other.bucket == this.bucket &&
          other.requestCategory == this.requestCategory &&
          other.sortOrder == this.sortOrder &&
          other.articleId == this.articleId &&
          other.title == this.title &&
          other.source == this.source &&
          other.articleCategory == this.articleCategory &&
          other.summary == this.summary &&
          other.imageUrl == this.imageUrl &&
          other.articleUrl == this.articleUrl &&
          other.publishedAt == this.publishedAt &&
          other.isFactChecked == this.isFactChecked);
}

class NewsCacheEntriesCompanion extends UpdateCompanion<NewsCacheEntry> {
  final Value<int> id;
  final Value<String> bucket;
  final Value<String?> requestCategory;
  final Value<int> sortOrder;
  final Value<String> articleId;
  final Value<String> title;
  final Value<String> source;
  final Value<String> articleCategory;
  final Value<String?> summary;
  final Value<String?> imageUrl;
  final Value<String?> articleUrl;
  final Value<DateTime> publishedAt;
  final Value<bool> isFactChecked;
  const NewsCacheEntriesCompanion({
    this.id = const Value.absent(),
    this.bucket = const Value.absent(),
    this.requestCategory = const Value.absent(),
    this.sortOrder = const Value.absent(),
    this.articleId = const Value.absent(),
    this.title = const Value.absent(),
    this.source = const Value.absent(),
    this.articleCategory = const Value.absent(),
    this.summary = const Value.absent(),
    this.imageUrl = const Value.absent(),
    this.articleUrl = const Value.absent(),
    this.publishedAt = const Value.absent(),
    this.isFactChecked = const Value.absent(),
  });
  NewsCacheEntriesCompanion.insert({
    this.id = const Value.absent(),
    required String bucket,
    this.requestCategory = const Value.absent(),
    required int sortOrder,
    required String articleId,
    required String title,
    required String source,
    required String articleCategory,
    this.summary = const Value.absent(),
    this.imageUrl = const Value.absent(),
    this.articleUrl = const Value.absent(),
    required DateTime publishedAt,
    this.isFactChecked = const Value.absent(),
  }) : bucket = Value(bucket),
       sortOrder = Value(sortOrder),
       articleId = Value(articleId),
       title = Value(title),
       source = Value(source),
       articleCategory = Value(articleCategory),
       publishedAt = Value(publishedAt);
  static Insertable<NewsCacheEntry> custom({
    Expression<int>? id,
    Expression<String>? bucket,
    Expression<String>? requestCategory,
    Expression<int>? sortOrder,
    Expression<String>? articleId,
    Expression<String>? title,
    Expression<String>? source,
    Expression<String>? articleCategory,
    Expression<String>? summary,
    Expression<String>? imageUrl,
    Expression<String>? articleUrl,
    Expression<DateTime>? publishedAt,
    Expression<bool>? isFactChecked,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (bucket != null) 'bucket': bucket,
      if (requestCategory != null) 'request_category': requestCategory,
      if (sortOrder != null) 'sort_order': sortOrder,
      if (articleId != null) 'article_id': articleId,
      if (title != null) 'title': title,
      if (source != null) 'source': source,
      if (articleCategory != null) 'article_category': articleCategory,
      if (summary != null) 'summary': summary,
      if (imageUrl != null) 'image_url': imageUrl,
      if (articleUrl != null) 'article_url': articleUrl,
      if (publishedAt != null) 'published_at': publishedAt,
      if (isFactChecked != null) 'is_fact_checked': isFactChecked,
    });
  }

  NewsCacheEntriesCompanion copyWith({
    Value<int>? id,
    Value<String>? bucket,
    Value<String?>? requestCategory,
    Value<int>? sortOrder,
    Value<String>? articleId,
    Value<String>? title,
    Value<String>? source,
    Value<String>? articleCategory,
    Value<String?>? summary,
    Value<String?>? imageUrl,
    Value<String?>? articleUrl,
    Value<DateTime>? publishedAt,
    Value<bool>? isFactChecked,
  }) {
    return NewsCacheEntriesCompanion(
      id: id ?? this.id,
      bucket: bucket ?? this.bucket,
      requestCategory: requestCategory ?? this.requestCategory,
      sortOrder: sortOrder ?? this.sortOrder,
      articleId: articleId ?? this.articleId,
      title: title ?? this.title,
      source: source ?? this.source,
      articleCategory: articleCategory ?? this.articleCategory,
      summary: summary ?? this.summary,
      imageUrl: imageUrl ?? this.imageUrl,
      articleUrl: articleUrl ?? this.articleUrl,
      publishedAt: publishedAt ?? this.publishedAt,
      isFactChecked: isFactChecked ?? this.isFactChecked,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (bucket.present) {
      map['bucket'] = Variable<String>(bucket.value);
    }
    if (requestCategory.present) {
      map['request_category'] = Variable<String>(requestCategory.value);
    }
    if (sortOrder.present) {
      map['sort_order'] = Variable<int>(sortOrder.value);
    }
    if (articleId.present) {
      map['article_id'] = Variable<String>(articleId.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (source.present) {
      map['source'] = Variable<String>(source.value);
    }
    if (articleCategory.present) {
      map['article_category'] = Variable<String>(articleCategory.value);
    }
    if (summary.present) {
      map['summary'] = Variable<String>(summary.value);
    }
    if (imageUrl.present) {
      map['image_url'] = Variable<String>(imageUrl.value);
    }
    if (articleUrl.present) {
      map['article_url'] = Variable<String>(articleUrl.value);
    }
    if (publishedAt.present) {
      map['published_at'] = Variable<DateTime>(publishedAt.value);
    }
    if (isFactChecked.present) {
      map['is_fact_checked'] = Variable<bool>(isFactChecked.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('NewsCacheEntriesCompanion(')
          ..write('id: $id, ')
          ..write('bucket: $bucket, ')
          ..write('requestCategory: $requestCategory, ')
          ..write('sortOrder: $sortOrder, ')
          ..write('articleId: $articleId, ')
          ..write('title: $title, ')
          ..write('source: $source, ')
          ..write('articleCategory: $articleCategory, ')
          ..write('summary: $summary, ')
          ..write('imageUrl: $imageUrl, ')
          ..write('articleUrl: $articleUrl, ')
          ..write('publishedAt: $publishedAt, ')
          ..write('isFactChecked: $isFactChecked')
          ..write(')'))
        .toString();
  }
}

class $PollCacheEntriesTable extends PollCacheEntries
    with TableInfo<$PollCacheEntriesTable, PollCacheEntry> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $PollCacheEntriesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _pollIdMeta = const VerificationMeta('pollId');
  @override
  late final GeneratedColumn<String> pollId = GeneratedColumn<String>(
    'poll_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _questionMeta = const VerificationMeta(
    'question',
  );
  @override
  late final GeneratedColumn<String> question = GeneratedColumn<String>(
    'question',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _optionsJsonMeta = const VerificationMeta(
    'optionsJson',
  );
  @override
  late final GeneratedColumn<String> optionsJson = GeneratedColumn<String>(
    'options_json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _endsAtMeta = const VerificationMeta('endsAt');
  @override
  late final GeneratedColumn<DateTime> endsAt = GeneratedColumn<DateTime>(
    'ends_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _hasVotedMeta = const VerificationMeta(
    'hasVoted',
  );
  @override
  late final GeneratedColumn<bool> hasVoted = GeneratedColumn<bool>(
    'has_voted',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("has_voted" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _selectedOptionIdMeta = const VerificationMeta(
    'selectedOptionId',
  );
  @override
  late final GeneratedColumn<String> selectedOptionId = GeneratedColumn<String>(
    'selected_option_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _sortOrderMeta = const VerificationMeta(
    'sortOrder',
  );
  @override
  late final GeneratedColumn<int> sortOrder = GeneratedColumn<int>(
    'sort_order',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    pollId,
    question,
    optionsJson,
    endsAt,
    hasVoted,
    selectedOptionId,
    sortOrder,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'poll_cache_entries';
  @override
  VerificationContext validateIntegrity(
    Insertable<PollCacheEntry> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('poll_id')) {
      context.handle(
        _pollIdMeta,
        pollId.isAcceptableOrUnknown(data['poll_id']!, _pollIdMeta),
      );
    } else if (isInserting) {
      context.missing(_pollIdMeta);
    }
    if (data.containsKey('question')) {
      context.handle(
        _questionMeta,
        question.isAcceptableOrUnknown(data['question']!, _questionMeta),
      );
    } else if (isInserting) {
      context.missing(_questionMeta);
    }
    if (data.containsKey('options_json')) {
      context.handle(
        _optionsJsonMeta,
        optionsJson.isAcceptableOrUnknown(
          data['options_json']!,
          _optionsJsonMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_optionsJsonMeta);
    }
    if (data.containsKey('ends_at')) {
      context.handle(
        _endsAtMeta,
        endsAt.isAcceptableOrUnknown(data['ends_at']!, _endsAtMeta),
      );
    } else if (isInserting) {
      context.missing(_endsAtMeta);
    }
    if (data.containsKey('has_voted')) {
      context.handle(
        _hasVotedMeta,
        hasVoted.isAcceptableOrUnknown(data['has_voted']!, _hasVotedMeta),
      );
    }
    if (data.containsKey('selected_option_id')) {
      context.handle(
        _selectedOptionIdMeta,
        selectedOptionId.isAcceptableOrUnknown(
          data['selected_option_id']!,
          _selectedOptionIdMeta,
        ),
      );
    }
    if (data.containsKey('sort_order')) {
      context.handle(
        _sortOrderMeta,
        sortOrder.isAcceptableOrUnknown(data['sort_order']!, _sortOrderMeta),
      );
    } else if (isInserting) {
      context.missing(_sortOrderMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {pollId};
  @override
  PollCacheEntry map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return PollCacheEntry(
      pollId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}poll_id'],
      )!,
      question: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}question'],
      )!,
      optionsJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}options_json'],
      )!,
      endsAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}ends_at'],
      )!,
      hasVoted: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}has_voted'],
      )!,
      selectedOptionId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}selected_option_id'],
      ),
      sortOrder: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}sort_order'],
      )!,
    );
  }

  @override
  $PollCacheEntriesTable createAlias(String alias) {
    return $PollCacheEntriesTable(attachedDatabase, alias);
  }
}

class PollCacheEntry extends DataClass implements Insertable<PollCacheEntry> {
  final String pollId;
  final String question;
  final String optionsJson;
  final DateTime endsAt;
  final bool hasVoted;
  final String? selectedOptionId;
  final int sortOrder;
  const PollCacheEntry({
    required this.pollId,
    required this.question,
    required this.optionsJson,
    required this.endsAt,
    required this.hasVoted,
    this.selectedOptionId,
    required this.sortOrder,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['poll_id'] = Variable<String>(pollId);
    map['question'] = Variable<String>(question);
    map['options_json'] = Variable<String>(optionsJson);
    map['ends_at'] = Variable<DateTime>(endsAt);
    map['has_voted'] = Variable<bool>(hasVoted);
    if (!nullToAbsent || selectedOptionId != null) {
      map['selected_option_id'] = Variable<String>(selectedOptionId);
    }
    map['sort_order'] = Variable<int>(sortOrder);
    return map;
  }

  PollCacheEntriesCompanion toCompanion(bool nullToAbsent) {
    return PollCacheEntriesCompanion(
      pollId: Value(pollId),
      question: Value(question),
      optionsJson: Value(optionsJson),
      endsAt: Value(endsAt),
      hasVoted: Value(hasVoted),
      selectedOptionId: selectedOptionId == null && nullToAbsent
          ? const Value.absent()
          : Value(selectedOptionId),
      sortOrder: Value(sortOrder),
    );
  }

  factory PollCacheEntry.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return PollCacheEntry(
      pollId: serializer.fromJson<String>(json['pollId']),
      question: serializer.fromJson<String>(json['question']),
      optionsJson: serializer.fromJson<String>(json['optionsJson']),
      endsAt: serializer.fromJson<DateTime>(json['endsAt']),
      hasVoted: serializer.fromJson<bool>(json['hasVoted']),
      selectedOptionId: serializer.fromJson<String?>(json['selectedOptionId']),
      sortOrder: serializer.fromJson<int>(json['sortOrder']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'pollId': serializer.toJson<String>(pollId),
      'question': serializer.toJson<String>(question),
      'optionsJson': serializer.toJson<String>(optionsJson),
      'endsAt': serializer.toJson<DateTime>(endsAt),
      'hasVoted': serializer.toJson<bool>(hasVoted),
      'selectedOptionId': serializer.toJson<String?>(selectedOptionId),
      'sortOrder': serializer.toJson<int>(sortOrder),
    };
  }

  PollCacheEntry copyWith({
    String? pollId,
    String? question,
    String? optionsJson,
    DateTime? endsAt,
    bool? hasVoted,
    Value<String?> selectedOptionId = const Value.absent(),
    int? sortOrder,
  }) => PollCacheEntry(
    pollId: pollId ?? this.pollId,
    question: question ?? this.question,
    optionsJson: optionsJson ?? this.optionsJson,
    endsAt: endsAt ?? this.endsAt,
    hasVoted: hasVoted ?? this.hasVoted,
    selectedOptionId: selectedOptionId.present
        ? selectedOptionId.value
        : this.selectedOptionId,
    sortOrder: sortOrder ?? this.sortOrder,
  );
  PollCacheEntry copyWithCompanion(PollCacheEntriesCompanion data) {
    return PollCacheEntry(
      pollId: data.pollId.present ? data.pollId.value : this.pollId,
      question: data.question.present ? data.question.value : this.question,
      optionsJson: data.optionsJson.present
          ? data.optionsJson.value
          : this.optionsJson,
      endsAt: data.endsAt.present ? data.endsAt.value : this.endsAt,
      hasVoted: data.hasVoted.present ? data.hasVoted.value : this.hasVoted,
      selectedOptionId: data.selectedOptionId.present
          ? data.selectedOptionId.value
          : this.selectedOptionId,
      sortOrder: data.sortOrder.present ? data.sortOrder.value : this.sortOrder,
    );
  }

  @override
  String toString() {
    return (StringBuffer('PollCacheEntry(')
          ..write('pollId: $pollId, ')
          ..write('question: $question, ')
          ..write('optionsJson: $optionsJson, ')
          ..write('endsAt: $endsAt, ')
          ..write('hasVoted: $hasVoted, ')
          ..write('selectedOptionId: $selectedOptionId, ')
          ..write('sortOrder: $sortOrder')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    pollId,
    question,
    optionsJson,
    endsAt,
    hasVoted,
    selectedOptionId,
    sortOrder,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is PollCacheEntry &&
          other.pollId == this.pollId &&
          other.question == this.question &&
          other.optionsJson == this.optionsJson &&
          other.endsAt == this.endsAt &&
          other.hasVoted == this.hasVoted &&
          other.selectedOptionId == this.selectedOptionId &&
          other.sortOrder == this.sortOrder);
}

class PollCacheEntriesCompanion extends UpdateCompanion<PollCacheEntry> {
  final Value<String> pollId;
  final Value<String> question;
  final Value<String> optionsJson;
  final Value<DateTime> endsAt;
  final Value<bool> hasVoted;
  final Value<String?> selectedOptionId;
  final Value<int> sortOrder;
  final Value<int> rowid;
  const PollCacheEntriesCompanion({
    this.pollId = const Value.absent(),
    this.question = const Value.absent(),
    this.optionsJson = const Value.absent(),
    this.endsAt = const Value.absent(),
    this.hasVoted = const Value.absent(),
    this.selectedOptionId = const Value.absent(),
    this.sortOrder = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  PollCacheEntriesCompanion.insert({
    required String pollId,
    required String question,
    required String optionsJson,
    required DateTime endsAt,
    this.hasVoted = const Value.absent(),
    this.selectedOptionId = const Value.absent(),
    required int sortOrder,
    this.rowid = const Value.absent(),
  }) : pollId = Value(pollId),
       question = Value(question),
       optionsJson = Value(optionsJson),
       endsAt = Value(endsAt),
       sortOrder = Value(sortOrder);
  static Insertable<PollCacheEntry> custom({
    Expression<String>? pollId,
    Expression<String>? question,
    Expression<String>? optionsJson,
    Expression<DateTime>? endsAt,
    Expression<bool>? hasVoted,
    Expression<String>? selectedOptionId,
    Expression<int>? sortOrder,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (pollId != null) 'poll_id': pollId,
      if (question != null) 'question': question,
      if (optionsJson != null) 'options_json': optionsJson,
      if (endsAt != null) 'ends_at': endsAt,
      if (hasVoted != null) 'has_voted': hasVoted,
      if (selectedOptionId != null) 'selected_option_id': selectedOptionId,
      if (sortOrder != null) 'sort_order': sortOrder,
      if (rowid != null) 'rowid': rowid,
    });
  }

  PollCacheEntriesCompanion copyWith({
    Value<String>? pollId,
    Value<String>? question,
    Value<String>? optionsJson,
    Value<DateTime>? endsAt,
    Value<bool>? hasVoted,
    Value<String?>? selectedOptionId,
    Value<int>? sortOrder,
    Value<int>? rowid,
  }) {
    return PollCacheEntriesCompanion(
      pollId: pollId ?? this.pollId,
      question: question ?? this.question,
      optionsJson: optionsJson ?? this.optionsJson,
      endsAt: endsAt ?? this.endsAt,
      hasVoted: hasVoted ?? this.hasVoted,
      selectedOptionId: selectedOptionId ?? this.selectedOptionId,
      sortOrder: sortOrder ?? this.sortOrder,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (pollId.present) {
      map['poll_id'] = Variable<String>(pollId.value);
    }
    if (question.present) {
      map['question'] = Variable<String>(question.value);
    }
    if (optionsJson.present) {
      map['options_json'] = Variable<String>(optionsJson.value);
    }
    if (endsAt.present) {
      map['ends_at'] = Variable<DateTime>(endsAt.value);
    }
    if (hasVoted.present) {
      map['has_voted'] = Variable<bool>(hasVoted.value);
    }
    if (selectedOptionId.present) {
      map['selected_option_id'] = Variable<String>(selectedOptionId.value);
    }
    if (sortOrder.present) {
      map['sort_order'] = Variable<int>(sortOrder.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('PollCacheEntriesCompanion(')
          ..write('pollId: $pollId, ')
          ..write('question: $question, ')
          ..write('optionsJson: $optionsJson, ')
          ..write('endsAt: $endsAt, ')
          ..write('hasVoted: $hasVoted, ')
          ..write('selectedOptionId: $selectedOptionId, ')
          ..write('sortOrder: $sortOrder, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $PollVoteOutboxEntriesTable extends PollVoteOutboxEntries
    with TableInfo<$PollVoteOutboxEntriesTable, PollVoteOutboxEntry> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $PollVoteOutboxEntriesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _voteIdMeta = const VerificationMeta('voteId');
  @override
  late final GeneratedColumn<String> voteId = GeneratedColumn<String>(
    'vote_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _pollIdMeta = const VerificationMeta('pollId');
  @override
  late final GeneratedColumn<String> pollId = GeneratedColumn<String>(
    'poll_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _optionIdMeta = const VerificationMeta(
    'optionId',
  );
  @override
  late final GeneratedColumn<String> optionId = GeneratedColumn<String>(
    'option_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _attemptsMeta = const VerificationMeta(
    'attempts',
  );
  @override
  late final GeneratedColumn<int> attempts = GeneratedColumn<int>(
    'attempts',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _lastErrorMeta = const VerificationMeta(
    'lastError',
  );
  @override
  late final GeneratedColumn<String> lastError = GeneratedColumn<String>(
    'last_error',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    voteId,
    pollId,
    optionId,
    createdAt,
    attempts,
    lastError,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'poll_vote_outbox_entries';
  @override
  VerificationContext validateIntegrity(
    Insertable<PollVoteOutboxEntry> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('vote_id')) {
      context.handle(
        _voteIdMeta,
        voteId.isAcceptableOrUnknown(data['vote_id']!, _voteIdMeta),
      );
    } else if (isInserting) {
      context.missing(_voteIdMeta);
    }
    if (data.containsKey('poll_id')) {
      context.handle(
        _pollIdMeta,
        pollId.isAcceptableOrUnknown(data['poll_id']!, _pollIdMeta),
      );
    } else if (isInserting) {
      context.missing(_pollIdMeta);
    }
    if (data.containsKey('option_id')) {
      context.handle(
        _optionIdMeta,
        optionId.isAcceptableOrUnknown(data['option_id']!, _optionIdMeta),
      );
    } else if (isInserting) {
      context.missing(_optionIdMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('attempts')) {
      context.handle(
        _attemptsMeta,
        attempts.isAcceptableOrUnknown(data['attempts']!, _attemptsMeta),
      );
    }
    if (data.containsKey('last_error')) {
      context.handle(
        _lastErrorMeta,
        lastError.isAcceptableOrUnknown(data['last_error']!, _lastErrorMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  List<Set<GeneratedColumn>> get uniqueKeys => [
    {voteId},
    {pollId},
  ];
  @override
  PollVoteOutboxEntry map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return PollVoteOutboxEntry(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      voteId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}vote_id'],
      )!,
      pollId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}poll_id'],
      )!,
      optionId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}option_id'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      attempts: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}attempts'],
      )!,
      lastError: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}last_error'],
      ),
    );
  }

  @override
  $PollVoteOutboxEntriesTable createAlias(String alias) {
    return $PollVoteOutboxEntriesTable(attachedDatabase, alias);
  }
}

class PollVoteOutboxEntry extends DataClass
    implements Insertable<PollVoteOutboxEntry> {
  final int id;
  final String voteId;
  final String pollId;
  final String optionId;
  final DateTime createdAt;
  final int attempts;
  final String? lastError;
  const PollVoteOutboxEntry({
    required this.id,
    required this.voteId,
    required this.pollId,
    required this.optionId,
    required this.createdAt,
    required this.attempts,
    this.lastError,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['vote_id'] = Variable<String>(voteId);
    map['poll_id'] = Variable<String>(pollId);
    map['option_id'] = Variable<String>(optionId);
    map['created_at'] = Variable<DateTime>(createdAt);
    map['attempts'] = Variable<int>(attempts);
    if (!nullToAbsent || lastError != null) {
      map['last_error'] = Variable<String>(lastError);
    }
    return map;
  }

  PollVoteOutboxEntriesCompanion toCompanion(bool nullToAbsent) {
    return PollVoteOutboxEntriesCompanion(
      id: Value(id),
      voteId: Value(voteId),
      pollId: Value(pollId),
      optionId: Value(optionId),
      createdAt: Value(createdAt),
      attempts: Value(attempts),
      lastError: lastError == null && nullToAbsent
          ? const Value.absent()
          : Value(lastError),
    );
  }

  factory PollVoteOutboxEntry.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return PollVoteOutboxEntry(
      id: serializer.fromJson<int>(json['id']),
      voteId: serializer.fromJson<String>(json['voteId']),
      pollId: serializer.fromJson<String>(json['pollId']),
      optionId: serializer.fromJson<String>(json['optionId']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      attempts: serializer.fromJson<int>(json['attempts']),
      lastError: serializer.fromJson<String?>(json['lastError']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'voteId': serializer.toJson<String>(voteId),
      'pollId': serializer.toJson<String>(pollId),
      'optionId': serializer.toJson<String>(optionId),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'attempts': serializer.toJson<int>(attempts),
      'lastError': serializer.toJson<String?>(lastError),
    };
  }

  PollVoteOutboxEntry copyWith({
    int? id,
    String? voteId,
    String? pollId,
    String? optionId,
    DateTime? createdAt,
    int? attempts,
    Value<String?> lastError = const Value.absent(),
  }) => PollVoteOutboxEntry(
    id: id ?? this.id,
    voteId: voteId ?? this.voteId,
    pollId: pollId ?? this.pollId,
    optionId: optionId ?? this.optionId,
    createdAt: createdAt ?? this.createdAt,
    attempts: attempts ?? this.attempts,
    lastError: lastError.present ? lastError.value : this.lastError,
  );
  PollVoteOutboxEntry copyWithCompanion(PollVoteOutboxEntriesCompanion data) {
    return PollVoteOutboxEntry(
      id: data.id.present ? data.id.value : this.id,
      voteId: data.voteId.present ? data.voteId.value : this.voteId,
      pollId: data.pollId.present ? data.pollId.value : this.pollId,
      optionId: data.optionId.present ? data.optionId.value : this.optionId,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      attempts: data.attempts.present ? data.attempts.value : this.attempts,
      lastError: data.lastError.present ? data.lastError.value : this.lastError,
    );
  }

  @override
  String toString() {
    return (StringBuffer('PollVoteOutboxEntry(')
          ..write('id: $id, ')
          ..write('voteId: $voteId, ')
          ..write('pollId: $pollId, ')
          ..write('optionId: $optionId, ')
          ..write('createdAt: $createdAt, ')
          ..write('attempts: $attempts, ')
          ..write('lastError: $lastError')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, voteId, pollId, optionId, createdAt, attempts, lastError);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is PollVoteOutboxEntry &&
          other.id == this.id &&
          other.voteId == this.voteId &&
          other.pollId == this.pollId &&
          other.optionId == this.optionId &&
          other.createdAt == this.createdAt &&
          other.attempts == this.attempts &&
          other.lastError == this.lastError);
}

class PollVoteOutboxEntriesCompanion
    extends UpdateCompanion<PollVoteOutboxEntry> {
  final Value<int> id;
  final Value<String> voteId;
  final Value<String> pollId;
  final Value<String> optionId;
  final Value<DateTime> createdAt;
  final Value<int> attempts;
  final Value<String?> lastError;
  const PollVoteOutboxEntriesCompanion({
    this.id = const Value.absent(),
    this.voteId = const Value.absent(),
    this.pollId = const Value.absent(),
    this.optionId = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.attempts = const Value.absent(),
    this.lastError = const Value.absent(),
  });
  PollVoteOutboxEntriesCompanion.insert({
    this.id = const Value.absent(),
    required String voteId,
    required String pollId,
    required String optionId,
    required DateTime createdAt,
    this.attempts = const Value.absent(),
    this.lastError = const Value.absent(),
  }) : voteId = Value(voteId),
       pollId = Value(pollId),
       optionId = Value(optionId),
       createdAt = Value(createdAt);
  static Insertable<PollVoteOutboxEntry> custom({
    Expression<int>? id,
    Expression<String>? voteId,
    Expression<String>? pollId,
    Expression<String>? optionId,
    Expression<DateTime>? createdAt,
    Expression<int>? attempts,
    Expression<String>? lastError,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (voteId != null) 'vote_id': voteId,
      if (pollId != null) 'poll_id': pollId,
      if (optionId != null) 'option_id': optionId,
      if (createdAt != null) 'created_at': createdAt,
      if (attempts != null) 'attempts': attempts,
      if (lastError != null) 'last_error': lastError,
    });
  }

  PollVoteOutboxEntriesCompanion copyWith({
    Value<int>? id,
    Value<String>? voteId,
    Value<String>? pollId,
    Value<String>? optionId,
    Value<DateTime>? createdAt,
    Value<int>? attempts,
    Value<String?>? lastError,
  }) {
    return PollVoteOutboxEntriesCompanion(
      id: id ?? this.id,
      voteId: voteId ?? this.voteId,
      pollId: pollId ?? this.pollId,
      optionId: optionId ?? this.optionId,
      createdAt: createdAt ?? this.createdAt,
      attempts: attempts ?? this.attempts,
      lastError: lastError ?? this.lastError,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (voteId.present) {
      map['vote_id'] = Variable<String>(voteId.value);
    }
    if (pollId.present) {
      map['poll_id'] = Variable<String>(pollId.value);
    }
    if (optionId.present) {
      map['option_id'] = Variable<String>(optionId.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (attempts.present) {
      map['attempts'] = Variable<int>(attempts.value);
    }
    if (lastError.present) {
      map['last_error'] = Variable<String>(lastError.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('PollVoteOutboxEntriesCompanion(')
          ..write('id: $id, ')
          ..write('voteId: $voteId, ')
          ..write('pollId: $pollId, ')
          ..write('optionId: $optionId, ')
          ..write('createdAt: $createdAt, ')
          ..write('attempts: $attempts, ')
          ..write('lastError: $lastError')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $NewsCacheEntriesTable newsCacheEntries = $NewsCacheEntriesTable(
    this,
  );
  late final $PollCacheEntriesTable pollCacheEntries = $PollCacheEntriesTable(
    this,
  );
  late final $PollVoteOutboxEntriesTable pollVoteOutboxEntries =
      $PollVoteOutboxEntriesTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    newsCacheEntries,
    pollCacheEntries,
    pollVoteOutboxEntries,
  ];
}

typedef $$NewsCacheEntriesTableCreateCompanionBuilder =
    NewsCacheEntriesCompanion Function({
      Value<int> id,
      required String bucket,
      Value<String?> requestCategory,
      required int sortOrder,
      required String articleId,
      required String title,
      required String source,
      required String articleCategory,
      Value<String?> summary,
      Value<String?> imageUrl,
      Value<String?> articleUrl,
      required DateTime publishedAt,
      Value<bool> isFactChecked,
    });
typedef $$NewsCacheEntriesTableUpdateCompanionBuilder =
    NewsCacheEntriesCompanion Function({
      Value<int> id,
      Value<String> bucket,
      Value<String?> requestCategory,
      Value<int> sortOrder,
      Value<String> articleId,
      Value<String> title,
      Value<String> source,
      Value<String> articleCategory,
      Value<String?> summary,
      Value<String?> imageUrl,
      Value<String?> articleUrl,
      Value<DateTime> publishedAt,
      Value<bool> isFactChecked,
    });

class $$NewsCacheEntriesTableFilterComposer
    extends Composer<_$AppDatabase, $NewsCacheEntriesTable> {
  $$NewsCacheEntriesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get bucket => $composableBuilder(
    column: $table.bucket,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get requestCategory => $composableBuilder(
    column: $table.requestCategory,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get sortOrder => $composableBuilder(
    column: $table.sortOrder,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get articleId => $composableBuilder(
    column: $table.articleId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get source => $composableBuilder(
    column: $table.source,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get articleCategory => $composableBuilder(
    column: $table.articleCategory,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get summary => $composableBuilder(
    column: $table.summary,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get imageUrl => $composableBuilder(
    column: $table.imageUrl,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get articleUrl => $composableBuilder(
    column: $table.articleUrl,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get publishedAt => $composableBuilder(
    column: $table.publishedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isFactChecked => $composableBuilder(
    column: $table.isFactChecked,
    builder: (column) => ColumnFilters(column),
  );
}

class $$NewsCacheEntriesTableOrderingComposer
    extends Composer<_$AppDatabase, $NewsCacheEntriesTable> {
  $$NewsCacheEntriesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get bucket => $composableBuilder(
    column: $table.bucket,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get requestCategory => $composableBuilder(
    column: $table.requestCategory,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get sortOrder => $composableBuilder(
    column: $table.sortOrder,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get articleId => $composableBuilder(
    column: $table.articleId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get source => $composableBuilder(
    column: $table.source,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get articleCategory => $composableBuilder(
    column: $table.articleCategory,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get summary => $composableBuilder(
    column: $table.summary,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get imageUrl => $composableBuilder(
    column: $table.imageUrl,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get articleUrl => $composableBuilder(
    column: $table.articleUrl,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get publishedAt => $composableBuilder(
    column: $table.publishedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isFactChecked => $composableBuilder(
    column: $table.isFactChecked,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$NewsCacheEntriesTableAnnotationComposer
    extends Composer<_$AppDatabase, $NewsCacheEntriesTable> {
  $$NewsCacheEntriesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get bucket =>
      $composableBuilder(column: $table.bucket, builder: (column) => column);

  GeneratedColumn<String> get requestCategory => $composableBuilder(
    column: $table.requestCategory,
    builder: (column) => column,
  );

  GeneratedColumn<int> get sortOrder =>
      $composableBuilder(column: $table.sortOrder, builder: (column) => column);

  GeneratedColumn<String> get articleId =>
      $composableBuilder(column: $table.articleId, builder: (column) => column);

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<String> get source =>
      $composableBuilder(column: $table.source, builder: (column) => column);

  GeneratedColumn<String> get articleCategory => $composableBuilder(
    column: $table.articleCategory,
    builder: (column) => column,
  );

  GeneratedColumn<String> get summary =>
      $composableBuilder(column: $table.summary, builder: (column) => column);

  GeneratedColumn<String> get imageUrl =>
      $composableBuilder(column: $table.imageUrl, builder: (column) => column);

  GeneratedColumn<String> get articleUrl => $composableBuilder(
    column: $table.articleUrl,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get publishedAt => $composableBuilder(
    column: $table.publishedAt,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get isFactChecked => $composableBuilder(
    column: $table.isFactChecked,
    builder: (column) => column,
  );
}

class $$NewsCacheEntriesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $NewsCacheEntriesTable,
          NewsCacheEntry,
          $$NewsCacheEntriesTableFilterComposer,
          $$NewsCacheEntriesTableOrderingComposer,
          $$NewsCacheEntriesTableAnnotationComposer,
          $$NewsCacheEntriesTableCreateCompanionBuilder,
          $$NewsCacheEntriesTableUpdateCompanionBuilder,
          (
            NewsCacheEntry,
            BaseReferences<
              _$AppDatabase,
              $NewsCacheEntriesTable,
              NewsCacheEntry
            >,
          ),
          NewsCacheEntry,
          PrefetchHooks Function()
        > {
  $$NewsCacheEntriesTableTableManager(
    _$AppDatabase db,
    $NewsCacheEntriesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$NewsCacheEntriesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$NewsCacheEntriesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$NewsCacheEntriesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> bucket = const Value.absent(),
                Value<String?> requestCategory = const Value.absent(),
                Value<int> sortOrder = const Value.absent(),
                Value<String> articleId = const Value.absent(),
                Value<String> title = const Value.absent(),
                Value<String> source = const Value.absent(),
                Value<String> articleCategory = const Value.absent(),
                Value<String?> summary = const Value.absent(),
                Value<String?> imageUrl = const Value.absent(),
                Value<String?> articleUrl = const Value.absent(),
                Value<DateTime> publishedAt = const Value.absent(),
                Value<bool> isFactChecked = const Value.absent(),
              }) => NewsCacheEntriesCompanion(
                id: id,
                bucket: bucket,
                requestCategory: requestCategory,
                sortOrder: sortOrder,
                articleId: articleId,
                title: title,
                source: source,
                articleCategory: articleCategory,
                summary: summary,
                imageUrl: imageUrl,
                articleUrl: articleUrl,
                publishedAt: publishedAt,
                isFactChecked: isFactChecked,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String bucket,
                Value<String?> requestCategory = const Value.absent(),
                required int sortOrder,
                required String articleId,
                required String title,
                required String source,
                required String articleCategory,
                Value<String?> summary = const Value.absent(),
                Value<String?> imageUrl = const Value.absent(),
                Value<String?> articleUrl = const Value.absent(),
                required DateTime publishedAt,
                Value<bool> isFactChecked = const Value.absent(),
              }) => NewsCacheEntriesCompanion.insert(
                id: id,
                bucket: bucket,
                requestCategory: requestCategory,
                sortOrder: sortOrder,
                articleId: articleId,
                title: title,
                source: source,
                articleCategory: articleCategory,
                summary: summary,
                imageUrl: imageUrl,
                articleUrl: articleUrl,
                publishedAt: publishedAt,
                isFactChecked: isFactChecked,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$NewsCacheEntriesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $NewsCacheEntriesTable,
      NewsCacheEntry,
      $$NewsCacheEntriesTableFilterComposer,
      $$NewsCacheEntriesTableOrderingComposer,
      $$NewsCacheEntriesTableAnnotationComposer,
      $$NewsCacheEntriesTableCreateCompanionBuilder,
      $$NewsCacheEntriesTableUpdateCompanionBuilder,
      (
        NewsCacheEntry,
        BaseReferences<_$AppDatabase, $NewsCacheEntriesTable, NewsCacheEntry>,
      ),
      NewsCacheEntry,
      PrefetchHooks Function()
    >;
typedef $$PollCacheEntriesTableCreateCompanionBuilder =
    PollCacheEntriesCompanion Function({
      required String pollId,
      required String question,
      required String optionsJson,
      required DateTime endsAt,
      Value<bool> hasVoted,
      Value<String?> selectedOptionId,
      required int sortOrder,
      Value<int> rowid,
    });
typedef $$PollCacheEntriesTableUpdateCompanionBuilder =
    PollCacheEntriesCompanion Function({
      Value<String> pollId,
      Value<String> question,
      Value<String> optionsJson,
      Value<DateTime> endsAt,
      Value<bool> hasVoted,
      Value<String?> selectedOptionId,
      Value<int> sortOrder,
      Value<int> rowid,
    });

class $$PollCacheEntriesTableFilterComposer
    extends Composer<_$AppDatabase, $PollCacheEntriesTable> {
  $$PollCacheEntriesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get pollId => $composableBuilder(
    column: $table.pollId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get question => $composableBuilder(
    column: $table.question,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get optionsJson => $composableBuilder(
    column: $table.optionsJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get endsAt => $composableBuilder(
    column: $table.endsAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get hasVoted => $composableBuilder(
    column: $table.hasVoted,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get selectedOptionId => $composableBuilder(
    column: $table.selectedOptionId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get sortOrder => $composableBuilder(
    column: $table.sortOrder,
    builder: (column) => ColumnFilters(column),
  );
}

class $$PollCacheEntriesTableOrderingComposer
    extends Composer<_$AppDatabase, $PollCacheEntriesTable> {
  $$PollCacheEntriesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get pollId => $composableBuilder(
    column: $table.pollId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get question => $composableBuilder(
    column: $table.question,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get optionsJson => $composableBuilder(
    column: $table.optionsJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get endsAt => $composableBuilder(
    column: $table.endsAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get hasVoted => $composableBuilder(
    column: $table.hasVoted,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get selectedOptionId => $composableBuilder(
    column: $table.selectedOptionId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get sortOrder => $composableBuilder(
    column: $table.sortOrder,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$PollCacheEntriesTableAnnotationComposer
    extends Composer<_$AppDatabase, $PollCacheEntriesTable> {
  $$PollCacheEntriesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get pollId =>
      $composableBuilder(column: $table.pollId, builder: (column) => column);

  GeneratedColumn<String> get question =>
      $composableBuilder(column: $table.question, builder: (column) => column);

  GeneratedColumn<String> get optionsJson => $composableBuilder(
    column: $table.optionsJson,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get endsAt =>
      $composableBuilder(column: $table.endsAt, builder: (column) => column);

  GeneratedColumn<bool> get hasVoted =>
      $composableBuilder(column: $table.hasVoted, builder: (column) => column);

  GeneratedColumn<String> get selectedOptionId => $composableBuilder(
    column: $table.selectedOptionId,
    builder: (column) => column,
  );

  GeneratedColumn<int> get sortOrder =>
      $composableBuilder(column: $table.sortOrder, builder: (column) => column);
}

class $$PollCacheEntriesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $PollCacheEntriesTable,
          PollCacheEntry,
          $$PollCacheEntriesTableFilterComposer,
          $$PollCacheEntriesTableOrderingComposer,
          $$PollCacheEntriesTableAnnotationComposer,
          $$PollCacheEntriesTableCreateCompanionBuilder,
          $$PollCacheEntriesTableUpdateCompanionBuilder,
          (
            PollCacheEntry,
            BaseReferences<
              _$AppDatabase,
              $PollCacheEntriesTable,
              PollCacheEntry
            >,
          ),
          PollCacheEntry,
          PrefetchHooks Function()
        > {
  $$PollCacheEntriesTableTableManager(
    _$AppDatabase db,
    $PollCacheEntriesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$PollCacheEntriesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$PollCacheEntriesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$PollCacheEntriesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> pollId = const Value.absent(),
                Value<String> question = const Value.absent(),
                Value<String> optionsJson = const Value.absent(),
                Value<DateTime> endsAt = const Value.absent(),
                Value<bool> hasVoted = const Value.absent(),
                Value<String?> selectedOptionId = const Value.absent(),
                Value<int> sortOrder = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => PollCacheEntriesCompanion(
                pollId: pollId,
                question: question,
                optionsJson: optionsJson,
                endsAt: endsAt,
                hasVoted: hasVoted,
                selectedOptionId: selectedOptionId,
                sortOrder: sortOrder,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String pollId,
                required String question,
                required String optionsJson,
                required DateTime endsAt,
                Value<bool> hasVoted = const Value.absent(),
                Value<String?> selectedOptionId = const Value.absent(),
                required int sortOrder,
                Value<int> rowid = const Value.absent(),
              }) => PollCacheEntriesCompanion.insert(
                pollId: pollId,
                question: question,
                optionsJson: optionsJson,
                endsAt: endsAt,
                hasVoted: hasVoted,
                selectedOptionId: selectedOptionId,
                sortOrder: sortOrder,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$PollCacheEntriesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $PollCacheEntriesTable,
      PollCacheEntry,
      $$PollCacheEntriesTableFilterComposer,
      $$PollCacheEntriesTableOrderingComposer,
      $$PollCacheEntriesTableAnnotationComposer,
      $$PollCacheEntriesTableCreateCompanionBuilder,
      $$PollCacheEntriesTableUpdateCompanionBuilder,
      (
        PollCacheEntry,
        BaseReferences<_$AppDatabase, $PollCacheEntriesTable, PollCacheEntry>,
      ),
      PollCacheEntry,
      PrefetchHooks Function()
    >;
typedef $$PollVoteOutboxEntriesTableCreateCompanionBuilder =
    PollVoteOutboxEntriesCompanion Function({
      Value<int> id,
      required String voteId,
      required String pollId,
      required String optionId,
      required DateTime createdAt,
      Value<int> attempts,
      Value<String?> lastError,
    });
typedef $$PollVoteOutboxEntriesTableUpdateCompanionBuilder =
    PollVoteOutboxEntriesCompanion Function({
      Value<int> id,
      Value<String> voteId,
      Value<String> pollId,
      Value<String> optionId,
      Value<DateTime> createdAt,
      Value<int> attempts,
      Value<String?> lastError,
    });

class $$PollVoteOutboxEntriesTableFilterComposer
    extends Composer<_$AppDatabase, $PollVoteOutboxEntriesTable> {
  $$PollVoteOutboxEntriesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get voteId => $composableBuilder(
    column: $table.voteId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get pollId => $composableBuilder(
    column: $table.pollId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get optionId => $composableBuilder(
    column: $table.optionId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get attempts => $composableBuilder(
    column: $table.attempts,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get lastError => $composableBuilder(
    column: $table.lastError,
    builder: (column) => ColumnFilters(column),
  );
}

class $$PollVoteOutboxEntriesTableOrderingComposer
    extends Composer<_$AppDatabase, $PollVoteOutboxEntriesTable> {
  $$PollVoteOutboxEntriesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get voteId => $composableBuilder(
    column: $table.voteId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get pollId => $composableBuilder(
    column: $table.pollId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get optionId => $composableBuilder(
    column: $table.optionId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get attempts => $composableBuilder(
    column: $table.attempts,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get lastError => $composableBuilder(
    column: $table.lastError,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$PollVoteOutboxEntriesTableAnnotationComposer
    extends Composer<_$AppDatabase, $PollVoteOutboxEntriesTable> {
  $$PollVoteOutboxEntriesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get voteId =>
      $composableBuilder(column: $table.voteId, builder: (column) => column);

  GeneratedColumn<String> get pollId =>
      $composableBuilder(column: $table.pollId, builder: (column) => column);

  GeneratedColumn<String> get optionId =>
      $composableBuilder(column: $table.optionId, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<int> get attempts =>
      $composableBuilder(column: $table.attempts, builder: (column) => column);

  GeneratedColumn<String> get lastError =>
      $composableBuilder(column: $table.lastError, builder: (column) => column);
}

class $$PollVoteOutboxEntriesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $PollVoteOutboxEntriesTable,
          PollVoteOutboxEntry,
          $$PollVoteOutboxEntriesTableFilterComposer,
          $$PollVoteOutboxEntriesTableOrderingComposer,
          $$PollVoteOutboxEntriesTableAnnotationComposer,
          $$PollVoteOutboxEntriesTableCreateCompanionBuilder,
          $$PollVoteOutboxEntriesTableUpdateCompanionBuilder,
          (
            PollVoteOutboxEntry,
            BaseReferences<
              _$AppDatabase,
              $PollVoteOutboxEntriesTable,
              PollVoteOutboxEntry
            >,
          ),
          PollVoteOutboxEntry,
          PrefetchHooks Function()
        > {
  $$PollVoteOutboxEntriesTableTableManager(
    _$AppDatabase db,
    $PollVoteOutboxEntriesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$PollVoteOutboxEntriesTableFilterComposer(
                $db: db,
                $table: table,
              ),
          createOrderingComposer: () =>
              $$PollVoteOutboxEntriesTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              $$PollVoteOutboxEntriesTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> voteId = const Value.absent(),
                Value<String> pollId = const Value.absent(),
                Value<String> optionId = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<int> attempts = const Value.absent(),
                Value<String?> lastError = const Value.absent(),
              }) => PollVoteOutboxEntriesCompanion(
                id: id,
                voteId: voteId,
                pollId: pollId,
                optionId: optionId,
                createdAt: createdAt,
                attempts: attempts,
                lastError: lastError,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String voteId,
                required String pollId,
                required String optionId,
                required DateTime createdAt,
                Value<int> attempts = const Value.absent(),
                Value<String?> lastError = const Value.absent(),
              }) => PollVoteOutboxEntriesCompanion.insert(
                id: id,
                voteId: voteId,
                pollId: pollId,
                optionId: optionId,
                createdAt: createdAt,
                attempts: attempts,
                lastError: lastError,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$PollVoteOutboxEntriesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $PollVoteOutboxEntriesTable,
      PollVoteOutboxEntry,
      $$PollVoteOutboxEntriesTableFilterComposer,
      $$PollVoteOutboxEntriesTableOrderingComposer,
      $$PollVoteOutboxEntriesTableAnnotationComposer,
      $$PollVoteOutboxEntriesTableCreateCompanionBuilder,
      $$PollVoteOutboxEntriesTableUpdateCompanionBuilder,
      (
        PollVoteOutboxEntry,
        BaseReferences<
          _$AppDatabase,
          $PollVoteOutboxEntriesTable,
          PollVoteOutboxEntry
        >,
      ),
      PollVoteOutboxEntry,
      PrefetchHooks Function()
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$NewsCacheEntriesTableTableManager get newsCacheEntries =>
      $$NewsCacheEntriesTableTableManager(_db, _db.newsCacheEntries);
  $$PollCacheEntriesTableTableManager get pollCacheEntries =>
      $$PollCacheEntriesTableTableManager(_db, _db.pollCacheEntries);
  $$PollVoteOutboxEntriesTableTableManager get pollVoteOutboxEntries =>
      $$PollVoteOutboxEntriesTableTableManager(_db, _db.pollVoteOutboxEntries);
}
