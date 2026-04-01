import 'package:flutter/material.dart';
import 'package:naijapulse/core/theme/theme.dart';

class LiveStreamCommentRow extends StatelessWidget {
  const LiveStreamCommentRow({
    required this.author,
    required this.timeLabel,
    required this.body,
    required this.likeCount,
    required this.commentCount,
    this.avatarUrl,
    this.trailingLikeCount,
    super.key,
  });

  final String author;
  final String timeLabel;
  final String body;
  final int likeCount;
  final int commentCount;
  final String? avatarUrl;
  final int? trailingLikeCount;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Theme.of(context).dividerColor),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _Avatar(avatarUrl: avatarUrl),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text.rich(
                  TextSpan(
                    text: '@$author',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                    children: [
                      TextSpan(
                        text: ' - $timeLabel',
                        style: Theme.of(context).textTheme.headlineSmall
                            ?.copyWith(
                              color: Theme.of(context).hintColor,
                              fontWeight: FontWeight.w500,
                            ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  body,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(
                      Icons.thumb_up_alt_outlined,
                      size: 20,
                      color: Theme.of(context).hintColor,
                    ),
                    const SizedBox(width: 5),
                    Text(
                      '$likeCount',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: Theme.of(context).hintColor,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(width: 18),
                    Icon(
                      Icons.chat_bubble_rounded,
                      size: 18,
                      color: Theme.of(context).hintColor,
                    ),
                    const SizedBox(width: 5),
                    Text(
                      '$commentCount comments',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: Theme.of(context).hintColor,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    if (trailingLikeCount != null) ...[
                      const Spacer(),
                      Icon(
                        Icons.thumb_up_alt,
                        size: 18,
                        color: Theme.of(context).hintColor,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '$trailingLikeCount',
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(
                              color: Theme.of(context).hintColor,
                              fontWeight: FontWeight.w600,
                            ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 6),
          Icon(
            Icons.more_horiz_rounded,
            size: 22,
            color: Theme.of(context).hintColor,
          ),
        ],
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({required this.avatarUrl});

  final String? avatarUrl;

  @override
  Widget build(BuildContext context) {
    final hasImage = avatarUrl != null && avatarUrl!.trim().isNotEmpty;
    return ClipOval(
      child: SizedBox(
        width: 50,
        height: 50,
        child: hasImage
            ? Image.network(
                avatarUrl!,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => _fallback(context),
              )
            : _fallback(context),
      ),
    );
  }

  Widget _fallback(BuildContext context) {
    return Container(
      color: AppTheme.primary.withValues(alpha: 0.18),
      child: Icon(
        Icons.person_rounded,
        color: Theme.of(context).colorScheme.primary,
        size: 24,
      ),
    );
  }
}
