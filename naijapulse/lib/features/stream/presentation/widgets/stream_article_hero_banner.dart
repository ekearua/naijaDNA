import 'package:flutter/material.dart';
import 'package:naijapulse/core/widgets/news_thumbnail.dart';

class StreamArticleHeroBanner extends StatelessWidget {
  const StreamArticleHeroBanner({
    required this.imageUrl,
    this.badgeLabel = 'BREAKING',
    super.key,
  });

  final String? imageUrl;
  final String badgeLabel;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 300,
      child: Stack(
        fit: StackFit.expand,
        children: [
          NewsThumbnail(imageUrl: imageUrl, fallbackLabel: 'Breaking'),
          Positioned(
            top: 18,
            left: 18,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFFC63D35),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                badgeLabel,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
