import 'package:shared_preferences/shared_preferences.dart';

/// Lightweight local bookmark store keyed by article id.
class SavedStoryLocalDataSource {
  static const String _savedIdsKey = 'news_saved_article_ids_v1';

  Future<Set<String>> getSavedArticleIds() async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getStringList(_savedIdsKey) ?? const <String>[];
    return stored.map((id) => id.trim()).where((id) => id.isNotEmpty).toSet();
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
    final nowSaved = !ids.contains(normalized);
    if (nowSaved) {
      ids.add(normalized);
    } else {
      ids.remove(normalized);
    }
    await prefs.setStringList(_savedIdsKey, ids.toList()..sort());
    return nowSaved;
  }
}
