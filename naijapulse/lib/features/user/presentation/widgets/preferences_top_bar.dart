import 'package:flutter/material.dart';
import 'package:naijapulse/core/theme/theme.dart';

class PreferencesTopBar extends StatelessWidget {
  const PreferencesTopBar({
    required this.title,
    required this.onBackTap,
    required this.onNotificationsTap,
    required this.onSearchTap,
    this.unreadCount = 0,
    super.key,
  });

  final String title;
  final VoidCallback onBackTap;
  final VoidCallback onNotificationsTap;
  final VoidCallback onSearchTap;
  final int unreadCount;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 12),
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
          Stack(
            clipBehavior: Clip.none,
            children: [
              IconButton(
                onPressed: onNotificationsTap,
                icon: const Icon(
                  Icons.notifications_none_rounded,
                  color: Colors.white,
                ),
                tooltip: 'Notifications',
              ),
              if (unreadCount > 0)
                Positioned(
                  right: 8,
                  top: 8,
                  child: Container(
                    height: 18,
                    width: 18,
                    decoration: const BoxDecoration(
                      color: Color(0xFFC63D35),
                      shape: BoxShape.circle,
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      '$unreadCount',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
            ],
          ),
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
