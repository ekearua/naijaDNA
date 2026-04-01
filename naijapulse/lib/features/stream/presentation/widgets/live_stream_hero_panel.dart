import 'package:flutter/material.dart';
import 'package:naijapulse/core/theme/theme.dart';
import 'package:naijapulse/core/widgets/news_thumbnail.dart';

class LiveStreamHeroPanel extends StatelessWidget {
  const LiveStreamHeroPanel({
    required this.imageUrl,
    required this.topicLabel,
    required this.title,
    required this.source,
    required this.viewerCount,
    required this.onWatchTap,
    super.key,
  });

  final String? imageUrl;
  final String topicLabel;
  final String title;
  final String source;
  final int viewerCount;
  final VoidCallback onWatchTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 470,
      child: Stack(
        children: [
          Positioned.fill(
            child: NewsThumbnail(
              imageUrl: imageUrl,
              fallbackLabel: 'Live Stream',
            ),
          ),
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    Colors.black.withValues(alpha: 0.2),
                    Colors.black.withValues(alpha: 0.75),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            top: 18,
            left: 12,
            child: Row(
              children: [
                _Badge(
                  backgroundColor: AppTheme.breaking,
                  icon: Icons.circle_outlined,
                  label: 'LIVE NOW',
                ),
                const SizedBox(width: 8),
                _Badge(
                  backgroundColor: Colors.black.withValues(alpha: 0.55),
                  icon: Icons.visibility_rounded,
                  label: _viewerCountLabel(viewerCount),
                ),
              ],
            ),
          ),
          Positioned(
            left: 12,
            right: 12,
            bottom: 74,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: AppTheme.breaking.withValues(alpha: 0.9),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    topicLabel,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  title,
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    height: 1.15,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        '$source - Live now',
                        style: Theme.of(context).textTheme.headlineSmall
                            ?.copyWith(
                              color: Colors.white.withValues(alpha: 0.92),
                              fontWeight: FontWeight.w500,
                            ),
                      ),
                    ),
                    ElevatedButton.icon(
                      onPressed: onWatchTap,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.breaking,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      icon: const Icon(Icons.play_arrow_rounded, size: 24),
                      label: const Text('Watch'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _viewerCountLabel(int count) {
    if (count >= 1000) {
      return '${(count / 1000).toStringAsFixed(1)}k';
    }
    return count.toString();
  }
}

class _Badge extends StatelessWidget {
  const _Badge({
    required this.backgroundColor,
    required this.icon,
    required this.label,
  });

  final Color backgroundColor;
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Icon(icon, size: 16, color: Colors.white),
          const SizedBox(width: 5),
          Text(
            label,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
