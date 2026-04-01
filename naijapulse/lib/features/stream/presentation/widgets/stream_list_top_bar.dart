import 'package:flutter/material.dart';
import 'package:naijapulse/core/theme/theme.dart';

class StreamListTopBar extends StatelessWidget {
  const StreamListTopBar({
    required this.title,
    required this.onBackTap,
    required this.onSearchTap,
    super.key,
  });

  final String title;
  final VoidCallback onBackTap;
  final VoidCallback onSearchTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppTheme.primary, AppTheme.primary.withValues(alpha: 0.88)],
        ),
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: onBackTap,
            icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
            tooltip: 'Back',
          ),
          Text(
            title,
            style: Theme.of(context).textTheme.headlineLarge?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w800,
            ),
          ),
          const Spacer(),
          IconButton(
            onPressed: onSearchTap,
            icon: const Icon(Icons.search_rounded, color: Colors.white),
            tooltip: 'Search',
          ),
        ],
      ),
    );
  }
}
