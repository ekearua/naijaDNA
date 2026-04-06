import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:naijapulse/features/news/data/models/news_article_model.dart';
import 'package:naijapulse/features/news/domain/entities/news_article.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Lightweight local bookmark store keyed by article id.
class SavedStoryLocalDataSource {
  static const String _savedIdsKey = 'news_saved_article_ids_v1';
  static const String _savedStoriesKey = 'news_saved_articles_v2';

  final ValueNotifier<int> savedStoriesListenable = ValueNotifier<int>(0);

  Future<Set<String>> getSavedArticleIds() async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getStringList(_savedIdsKey) ?? const <String>[];
    return stored.map((id) => id.trim()).where((id) => id.isNotEmpty).toSet();
  }

  Future<List<NewsArticleModel>> getSavedStories() async {
    final snapshots = await _readSavedStorySnapshots();
    final entries = snapshots.entries.toList()
      ..sort(
        (a, b) => _savedAtForSnapshot(
          b.value,
        ).compareTo(_savedAtForSnapshot(a.value)),
      );

    return entries
        .map((entry) => _articleFromSnapshot(entry.key, entry.value))
        .whereType<NewsArticleModel>()
        .toList(growable: false);
  }

  Future<bool> isSaved(String articleId) async {
    final normalized = articleId.trim();
    if (normalized.isEmpty) {
      return false;
    }
    final ids = await getSavedArticleIds();
    return ids.contains(normalized);
  }

  Future<bool> toggleSaved(String articleId) async {
    final normalized = articleId.trim();
    if (normalized.isEmpty) {
      return false;
    }

    final prefs = await SharedPreferences.getInstance();
    final ids = await getSavedArticleIds();
    final snapshots = await _readSavedStorySnapshots();
    final nowSaved = !ids.contains(normalized);
    if (nowSaved) {
      ids.add(normalized);
    } else {
      ids.remove(normalized);
      snapshots.remove(normalized);
    }
    await _persistState(prefs, ids: ids, snapshots: snapshots);
    _notifySavedStoriesChanged();
    return nowSaved;
  }

  Future<bool> toggleSavedArticle(NewsArticle article) async {
    final normalized = article.id.trim();
    if (normalized.isEmpty) {
      return false;
    }

    final prefs = await SharedPreferences.getInstance();
    final ids = await getSavedArticleIds();
    final snapshots = await _readSavedStorySnapshots();
    final nowSaved = !ids.contains(normalized);

    if (nowSaved) {
      ids.add(normalized);
      snapshots[normalized] = <String, dynamic>{
        'savedAt': DateTime.now().toUtc().toIso8601String(),
        'article': NewsArticleModel.fromEntity(article).toJson(),
      };
    } else {
      ids.remove(normalized);
      snapshots.remove(normalized);
    }

    await _persistState(prefs, ids: ids, snapshots: snapshots);
    _notifySavedStoriesChanged();
    return nowSaved;
  }

  Future<void> saveStorySnapshot(NewsArticle article) async {
    final normalized = article.id.trim();
    if (normalized.isEmpty) {
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    final ids = await getSavedArticleIds();
    if (!ids.contains(normalized)) {
      return;
    }

    final snapshots = await _readSavedStorySnapshots();
    final existingSavedAt = snapshots[normalized] is Map<String, dynamic>
        ? (snapshots[normalized] as Map<String, dynamic>)['savedAt']
              ?.toString()
              .trim()
        : null;

    snapshots[normalized] = <String, dynamic>{
      'savedAt': existingSavedAt?.isNotEmpty == true
          ? existingSavedAt
          : DateTime.now().toUtc().toIso8601String(),
      'article': NewsArticleModel.fromEntity(article).toJson(),
    };

    await _persistState(prefs, ids: ids, snapshots: snapshots);
    _notifySavedStoriesChanged();
  }

  Future<void> removeSaved(String articleId) async {
    final normalized = articleId.trim();
    if (normalized.isEmpty) {
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    final ids = await getSavedArticleIds();
    final snapshots = await _readSavedStorySnapshots();
    final hadId = ids.remove(normalized);
    final removedSnapshot = snapshots.remove(normalized) != null;
    if (!hadId && !removedSnapshot) {
      return;
    }

    await _persistState(prefs, ids: ids, snapshots: snapshots);
    _notifySavedStoriesChanged();
  }

  Future<Map<String, Map<String, dynamic>>> _readSavedStorySnapshots() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_savedStoriesKey);
    if (raw == null || raw.trim().isEmpty) {
      return <String, Map<String, dynamic>>{};
    }

    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) {
        return <String, Map<String, dynamic>>{};
      }

      return decoded.map((key, value) {
        if (value is Map<String, dynamic>) {
          return MapEntry(key, value);
        }
        if (value is Map) {
          return MapEntry(key, Map<String, dynamic>.from(value));
        }
        return MapEntry(key, <String, dynamic>{});
      });
    } catch (_) {
      return <String, Map<String, dynamic>>{};
    }
  }

  Future<void> _persistState(
    SharedPreferences prefs, {
    required Set<String> ids,
    required Map<String, Map<String, dynamic>> snapshots,
  }) async {
    await prefs.setStringList(_savedIdsKey, ids.toList()..sort());
    await prefs.setString(_savedStoriesKey, jsonEncode(snapshots));
  }

  NewsArticleModel? _articleFromSnapshot(
    String articleId,
    Map<String, dynamic> snapshot,
  ) {
    final article = snapshot['article'];
    if (article is Map<String, dynamic>) {
      try {
        return NewsArticleModel.fromJson(<String, dynamic>{
          'id': articleId,
          ...article,
        });
      } catch (_) {
        return null;
      }
    }
    if (article is Map) {
      try {
        return NewsArticleModel.fromJson(<String, dynamic>{
          'id': articleId,
          ...Map<String, dynamic>.from(article),
        });
      } catch (_) {
        return null;
      }
    }
    return null;
  }

  DateTime _savedAtForSnapshot(Map<String, dynamic> snapshot) {
    final raw = snapshot['savedAt']?.toString().trim();
    if (raw == null || raw.isEmpty) {
      return DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);
    }
    return DateTime.tryParse(raw) ??
        DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);
  }

  void _notifySavedStoriesChanged() {
    savedStoriesListenable.value++;
  }
}
