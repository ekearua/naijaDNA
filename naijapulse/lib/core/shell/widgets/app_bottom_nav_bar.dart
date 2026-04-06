import 'package:flutter/material.dart';
import 'package:naijapulse/core/widgets/app_interactions.dart';

class AppBottomNavBar extends StatelessWidget {
  const AppBottomNavBar({
    required this.currentIndex,
    required this.onTap,
    this.profileUnreadCount = 0,
    super.key,
  });

  final int currentIndex;
  final ValueChanged<int> onTap;
  final int profileUnreadCount;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        child: NavigationBar(
          selectedIndex: currentIndex,
          onDestinationSelected: onTap,
          destinations: [
            const NavigationDestination(
              icon: AppIcon(Icons.home_outlined, size: AppIconSize.large),
              selectedIcon: AppIcon(
                Icons.home_rounded,
                size: AppIconSize.large,
                tone: AppIconTone.accent,
              ),
              label: 'Home',
            ),
            const NavigationDestination(
              icon: AppIcon(Icons.sensors_outlined, size: AppIconSize.large),
              selectedIcon: AppIcon(
                Icons.sensors_rounded,
                size: AppIconSize.large,
                tone: AppIconTone.accent,
              ),
              label: 'Live',
            ),
            const NavigationDestination(
              icon: AppIcon(Icons.explore_outlined, size: AppIconSize.large),
              selectedIcon: AppIcon(
                Icons.explore_rounded,
                size: AppIconSize.large,
                tone: AppIconTone.accent,
              ),
              label: 'Explore',
            ),
            const NavigationDestination(
              icon: AppIcon(
                Icons.bookmark_border_rounded,
                size: AppIconSize.large,
              ),
              selectedIcon: AppIcon(
                Icons.bookmark_rounded,
                size: AppIconSize.large,
                tone: AppIconTone.accent,
              ),
              label: 'Saved',
            ),
            NavigationDestination(
              icon: _NavBadgeIcon(
                icon: Icons.person_outline_rounded,
                count: profileUnreadCount,
              ),
              selectedIcon: _NavBadgeIcon(
                icon: Icons.person_rounded,
                count: profileUnreadCount,
              ),
              label: 'Profile',
            ),
          ],
        ),
      ),
    );
  }
}

class _NavBadgeIcon extends StatelessWidget {
  const _NavBadgeIcon({required this.icon, required this.count});

  final IconData icon;
  final int count;

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        AppIcon(icon, size: AppIconSize.large),
        if (count > 0)
          Positioned(right: -8, top: -6, child: const SizedBox.shrink()),
        if (count > 0)
          Positioned(right: -8, top: -6, child: AppBadge(count: count)),
      ],
    );
  }
}
