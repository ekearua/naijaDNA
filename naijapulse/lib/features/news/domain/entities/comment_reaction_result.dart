import 'package:equatable/equatable.dart';

class CommentReactionResult extends Equatable {
  const CommentReactionResult({
    required this.commentId,
    required this.reactionType,
    required this.liked,
    required this.likeCount,
  });

  final int commentId;
  final String reactionType;
  final bool liked;
  final int likeCount;

  @override
  List<Object?> get props => [commentId, reactionType, liked, likeCount];
}
