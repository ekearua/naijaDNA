import 'package:naijapulse/features/news/domain/entities/comment_reaction_result.dart';

class CommentReactionResultModel extends CommentReactionResult {
  const CommentReactionResultModel({
    required super.commentId,
    required super.reactionType,
    required super.liked,
    required super.likeCount,
  });

  factory CommentReactionResultModel.fromJson(Map<String, dynamic> json) {
    return CommentReactionResultModel(
      commentId: ((json['comment_id'] ?? json['commentId']) as num).toInt(),
      reactionType: (json['reaction_type'] ?? json['reactionType'] ?? 'like')
          .toString(),
      liked: (json['liked'] ?? false) == true,
      likeCount: ((json['like_count'] ?? json['likeCount']) as num? ?? 0)
          .toInt(),
    );
  }
}
