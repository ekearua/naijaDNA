import 'package:flutter/material.dart';

class NewsThumbnail extends StatelessWidget {
  const NewsThumbnail({
    required this.imageUrl,
    required this.fallbackLabel,
    this.fit = BoxFit.cover,
    this.alignment = Alignment.center,
    super.key,
  });

  final String? imageUrl;
  final String fallbackLabel;
  final BoxFit fit;
  final Alignment alignment;

  @override
  Widget build(BuildContext context) {
    if (imageUrl == null || imageUrl!.trim().isEmpty) {
      return const SizedBox.shrink();
    }
    return Semantics(
      label: fallbackLabel,
      child: Image.network(
        imageUrl!,
        fit: fit,
        alignment: alignment,
        errorBuilder: (_, _, _) => const SizedBox.shrink(),
      ),
    );
  }
}
