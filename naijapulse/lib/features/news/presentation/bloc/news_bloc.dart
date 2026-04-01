import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:naijapulse/core/error/failures.dart';
import 'package:naijapulse/features/news/domain/usecases/get_latest_stories.dart';
import 'package:naijapulse/features/news/domain/usecases/get_top_stories.dart';
import 'package:naijapulse/features/news/domain/usecases/record_story_opened.dart';
import 'package:naijapulse/features/news/presentation/bloc/news_event.dart';
import 'package:naijapulse/features/news/presentation/bloc/news_state.dart';

export 'news_event.dart';
export 'news_state.dart';

class NewsBloc extends Bloc<NewsEvent, NewsState> {
  final GetTopStories _getTopStories;
  final GetLatestStories _getLatestStories;
  final RecordStoryOpened _recordStoryOpened;

  NewsBloc({
    required GetTopStories getTopStories,
    required GetLatestStories getLatestStories,
    required RecordStoryOpened recordStoryOpened,
  }) : _getTopStories = getTopStories,
       _getLatestStories = getLatestStories,
       _recordStoryOpened = recordStoryOpened,
       super(const NewsState()) {
    on<LoadNewsRequested>(_onLoadNewsRequested);
    on<NewsStoryOpened>(_onNewsStoryOpened);
  }

  Future<void> _onLoadNewsRequested(
    LoadNewsRequested event,
    Emitter<NewsState> emit,
  ) async {
    // Fetch both sections independently so cached/partial data can still render offline.
    emit(state.copyWith(status: NewsStatus.loading, error: null));

    var topStories = state.topStories;
    var latestStories = state.latestStories;
    String? topError;
    String? latestError;

    try {
      topStories = await _getTopStories();
    } catch (error) {
      topError = mapFailure(error).message;
    }

    try {
      latestStories = await _getLatestStories();
    } catch (error) {
      latestError = mapFailure(error).message;
    }

    final hasAnyStories = topStories.isNotEmpty || latestStories.isNotEmpty;
    if (hasAnyStories) {
      // App remains usable offline as long as at least one cached feed has data.
      emit(
        state.copyWith(
          status: NewsStatus.loaded,
          topStories: topStories,
          latestStories: latestStories,
          error: topError ?? latestError,
        ),
      );
      return;
    }

    final fallbackMessage =
        topError ?? latestError ?? 'Unable to load stories right now.';
    emit(state.copyWith(status: NewsStatus.error, error: fallbackMessage));
  }

  Future<void> _onNewsStoryOpened(
    NewsStoryOpened event,
    Emitter<NewsState> emit,
  ) async {
    await _recordStoryOpened(event.articleId);
  }
}
