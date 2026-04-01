import 'package:flutter/material.dart';

class StreamArticleMainTextSection extends StatelessWidget {
  const StreamArticleMainTextSection({required this.paragraphs, super.key});

  final List<String> paragraphs;

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
          _sectionHeader(context, 'Article Main Text'),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: paragraphs.map((paragraph) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Text(
                    paragraph,
                    style: Theme.of(
                      context,
                    ).textTheme.bodyLarge?.copyWith(height: 1.45),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }
}

Widget _sectionHeader(BuildContext context, String label) {
  return Container(
    width: double.infinity,
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
    color: Theme.of(context).colorScheme.surfaceContainerHighest,
    child: Text(
      label,
      style: Theme.of(
        context,
      ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
    ),
  );
}
