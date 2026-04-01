import 'package:equatable/equatable.dart';

abstract class NewsEvent extends Equatable {
  const NewsEvent();

  @override
  List<Object?> get props => [];
}

class LoadNewsRequested extends NewsEvent {
  const LoadNewsRequested();
}

class NewsStoryOpened extends NewsEvent {
  const NewsStoryOpened(this.articleId);

  final String articleId;

  @override
  List<Object?> get props => [articleId];
}
