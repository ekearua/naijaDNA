import 'package:equatable/equatable.dart';
import 'package:naijapulse/features/news/domain/entities/news_article.dart';

enum NewsStatus { initial, loading, loaded, error }

class NewsState extends Equatable {
  final NewsStatus status;
  final List<NewsArticle> topStories;
  final List<NewsArticle> latestStories;
  final String? error;

  const NewsState({
    this.status = NewsStatus.initial,
    this.topStories = const [],
    this.latestStories = const [],
    this.error,
  });

  NewsState copyWith({
    NewsStatus? status,
    List<NewsArticle>? topStories,
    List<NewsArticle>? latestStories,
    String? error,
  }) {
    return NewsState(
      status: status ?? this.status,
      topStories: topStories ?? this.topStories,
      latestStories: latestStories ?? this.latestStories,
      error: error,
    );
  }

  @override
  List<Object?> get props => [status, topStories, latestStories, error];
}
