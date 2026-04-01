import 'package:flutter/material.dart';
import 'package:naijapulse/features/stream/presentation/widgets/live_comment_tile.dart';

class StreamCommentsSection extends StatelessWidget {
  const StreamCommentsSection({
    required this.commentCountLabel,
    required this.comments,
    super.key,
  });

  final String commentCountLabel;
  final List<({String author, String timeLabel, String body})> comments;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Theme.of(context).dividerColor),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            child: Row(
              children: [
                Text(
                  'Comments',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  commentCountLabel,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
            child: Column(
              children: comments.map((comment) {
                return LiveCommentTile(
                  author: comment.author,
                  timeLabel: comment.timeLabel,
                  body: comment.body,
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }
}
