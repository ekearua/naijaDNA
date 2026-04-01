import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:naijapulse/core/di/injection_container.dart';
import 'package:naijapulse/core/routing/app_router.dart';
import 'package:naijapulse/core/shell/app_shell_page.dart';
import 'package:naijapulse/core/theme/theme.dart';
import 'package:naijapulse/core/widgets/news_thumbnail.dart';
import 'package:naijapulse/features/auth/data/auth_session_controller.dart';
import 'package:naijapulse/features/auth/data/datasource/local/auth_local_datasource.dart';
import 'package:naijapulse/features/auth/domain/entities/auth_session.dart';
import 'package:naijapulse/features/news/presentation/widgets/news_time.dart';
import 'package:naijapulse/features/stream/domain/entities/stream_session.dart';
import 'package:naijapulse/features/stream/presentation/bloc/stream_bloc.dart';
import 'package:naijapulse/features/stream/presentation/widgets/stream_filter_strip.dart';

class StreamHomePage extends StatefulWidget {
  const StreamHomePage({super.key});

  @override
  State<StreamHomePage> createState() => _StreamHomePageState();
}

class _StreamHomePageState extends State<StreamHomePage> {
  String _selectedCategory = 'All';
  Timer? _refreshTimer;
  bool _isLiveTabActive = false;
  String? _currentUserId;
  AuthSession? _authSession;
  late final AuthSessionController _authSessionController;

  @override
  void initState() {
    super.initState();
    _authSessionController = InjectionContainer.sl<AuthSessionController>();
    _authSessionController.addListener(_handleAuthChanged);
    _loadCurrentUser();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final isActive = AppShellScope.maybeOf(context)?.currentIndex == 1;
    if (isActive == _isLiveTabActive) {
      return;
    }
    _isLiveTabActive = isActive;
    _updatePollingState();
    if (_isLiveTabActive) {
      context.read<StreamBloc>().add(const LoadStreamsRequested(silent: true));
    }
  }

  Future<void> _loadCurrentUser() async {
    final session = await InjectionContainer.sl<AuthLocalDataSource>()
        .getCachedSession();
    if (!mounted) {
      return;
    }
    setState(() {
      _authSession = session;
      _currentUserId = session?.userId.trim();
    });
  }

  void _handleAuthChanged() {
    if (!mounted) {
      return;
    }
    setState(() {
      _authSession = _authSessionController.session;
      _currentUserId = _authSessionController.session?.userId.trim();
    });
  }

  @override
  void dispose() {
    _authSessionController.removeListener(_handleAuthChanged);
    _refreshTimer?.cancel();
    super.dispose();
  }

  void _updatePollingState() {
    _refreshTimer?.cancel();
    if (!_isLiveTabActive) {
      _refreshTimer = null;
      return;
    }
    _refreshTimer = Timer.periodic(const Duration(seconds: 20), (_) {
      if (!mounted || !_isLiveTabActive) {
        return;
      }
      context.read<StreamBloc>().add(const LoadStreamsRequested(silent: true));
    });
  }

  void _openStreamSession(StreamSession session) {
    context.push(AppRouter.liveSessionPath(session.id), extra: session);
  }

  Future<void> _ensureSignedInForStreaming() async {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Sign in to host, schedule, or start a stream.'),
      ),
    );
    await context.push(AppRouter.loginPath);
    await _loadCurrentUser();
  }

  Future<void> _openAccessRequestPath() async {
    if (!mounted) {
      return;
    }
    await context.push(AppRouter.profilePath);
  }

  Future<void> _showCreateStreamDialog() async {
    if ((_currentUserId ?? '').isEmpty) {
      await _ensureSignedInForStreaming();
      return;
    }

    final result = await showDialog<_StreamDraft>(
      context: context,
      builder: (context) => _CreateStreamDialog(
        initialCategory: _selectedCategory.toLowerCase() == 'all'
            ? 'Breaking News'
            : _selectedCategory,
      ),
    );
    if (!mounted || result == null) {
      return;
    }

    final bloc = context.read<StreamBloc>();
    if (result.scheduledFor != null) {
      bloc.add(
        ScheduleStreamRequested(
          title: result.title,
          category: result.category,
          scheduledFor: result.scheduledFor!,
          description: result.description,
          coverImageUrl: result.coverImageUrl,
          streamUrl: result.streamUrl,
        ),
      );
      return;
    }

    bloc.add(
      CreateLiveStreamRequested(
        title: result.title,
        category: result.category,
        description: result.description,
        coverImageUrl: result.coverImageUrl,
        streamUrl: result.streamUrl,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final session = _authSession;
    final canAccessStreams = session?.canAccessStreams ?? false;
    final canHostStreams = session?.canHostStreams ?? false;
    if (!canAccessStreams) {
      return SafeArea(
        top: false,
        bottom: false,
        child: _StreamAccessGate(
          isGuest: session == null,
          onPrimaryTap: session == null
              ? _ensureSignedInForStreaming
              : _openAccessRequestPath,
        ),
      );
    }

    return SafeArea(
      top: false,
      bottom: false,
      child: BlocConsumer<StreamBloc, StreamState>(
        listenWhen: (previous, current) =>
            previous.actionStatus != current.actionStatus ||
            previous.pendingNavigationSessionId !=
                current.pendingNavigationSessionId,
        listener: (context, state) {
          if (state.actionStatus != StreamActionStatus.success &&
              state.actionStatus != StreamActionStatus.failure) {
            return;
          }

          final message = state.actionMessage;
          if (message != null && message.trim().isNotEmpty) {
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(SnackBar(content: Text(message)));
          }

          final sessionId = state.pendingNavigationSessionId;
          if (sessionId != null) {
            final session = _findSessionById(sessionId, state);
            if (session != null) {
              _openStreamSession(session);
            }
          }

          context.read<StreamBloc>().add(const ClearStreamActionRequested());
        },
        builder: (context, state) {
          final allStreams = [...state.liveStreams, ...state.scheduledStreams];
          final categories = _buildCategories(allStreams);
          final effectiveCategory = categories.contains(_selectedCategory)
              ? _selectedCategory
              : categories.first;
          final liveStreams = _filterByCategory(
            state.liveStreams,
            effectiveCategory,
          );
          final scheduledStreams = _filterByCategory(
            state.scheduledStreams,
            effectiveCategory,
          );
          final featuredStream = liveStreams.isNotEmpty
              ? liveStreams.first
              : scheduledStreams.isNotEmpty
              ? scheduledStreams.first
              : null;
          final exploreStreams = liveStreams.length > 1
              ? liveStreams.skip(1).toList()
              : liveStreams;

          return RefreshIndicator(
            onRefresh: () async {
              context.read<StreamBloc>().add(const LoadStreamsRequested());
            },
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 28),
              children: [
                Container(
                  padding: const EdgeInsets.all(22),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        AppTheme.primary.withValues(alpha: 0.96),
                        AppTheme.primaryContainer,
                      ],
                    ),
                    borderRadius: BorderRadius.circular(28),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Live Streams',
                        style: Theme.of(context).textTheme.headlineMedium
                            ?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w900,
                              fontFamily: AppTheme.headlineFontFamily,
                            ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Follow live reports, join scheduled rooms, and host your own stream when the story needs a voice.',
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: Colors.white.withValues(alpha: 0.84),
                        ),
                      ),
                      const SizedBox(height: 14),
                      Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: [
                          _HeroStatChip(
                            label: '${liveStreams.length} live now',
                          ),
                          _HeroStatChip(
                            label: '${scheduledStreams.length} scheduled',
                          ),
                          _HeroStatChip(label: effectiveCategory),
                        ],
                      ),
                      const SizedBox(height: 18),
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: canHostStreams
                                  ? _showCreateStreamDialog
                                  : _openAccessRequestPath,
                              icon: const Icon(
                                Icons.videocam_rounded,
                                size: 18,
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.white,
                                foregroundColor: AppTheme.primary,
                              ),
                              label: Text(
                                canHostStreams
                                    ? 'Host Stream'
                                    : 'Upgrade to Host',
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () {
                                context.read<StreamBloc>().add(
                                  const LoadStreamsRequested(),
                                );
                              },
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Colors.white,
                                side: BorderSide(
                                  color: Colors.white.withValues(alpha: 0.42),
                                ),
                              ),
                              icon: const Icon(Icons.radar_rounded, size: 18),
                              label: const Text('Refresh'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surface,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: Theme.of(
                        context,
                      ).dividerColor.withValues(alpha: 0.34),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Topics in motion',
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 10),
                      StreamFilterStrip(
                        categories: categories,
                        selectedCategory: effectiveCategory,
                        onSelected: (value) =>
                            setState(() => _selectedCategory = value),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                if (state.status == StreamStatus.loading && allStreams.isEmpty)
                  const Padding(
                    padding: EdgeInsets.only(top: 40),
                    child: Center(child: CircularProgressIndicator()),
                  ),
                if (state.status == StreamStatus.error && allStreams.isEmpty)
                  _EmptyStreamsState(
                    message:
                        state.errorMessage ??
                        'Unable to load stream sessions right now.',
                    actionLabel: 'Try again',
                    onActionTap: () {
                      context.read<StreamBloc>().add(
                        const LoadStreamsRequested(),
                      );
                    },
                  ),
                if (state.status != StreamStatus.loading && allStreams.isEmpty)
                  _EmptyStreamsState(
                    message:
                        'No live or scheduled streams are available yet. ${canHostStreams ? 'Host one to get things started.' : 'Upgrade to unlock hosting and create the first room.'}',
                    actionLabel: canHostStreams
                        ? 'Host Stream'
                        : 'Request access',
                    onActionTap: () => canHostStreams
                        ? _showCreateStreamDialog()
                        : _openAccessRequestPath(),
                  ),
                if (featuredStream != null) ...[
                  _FeaturedStreamCard(
                    session: featuredStream,
                    onTap: () => featuredStream.isLive
                        ? _openStreamSession(featuredStream)
                        : _handleScheduledAction(featuredStream),
                  ),
                  const SizedBox(height: 22),
                ],
                if (liveStreams.isNotEmpty) ...[
                  _StreamsSectionHeader(
                    title: 'Explore Streams',
                    actionLabel:
                        '${liveStreams.length} live ${liveStreams.length == 1 ? 'room' : 'rooms'}',
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 220,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: exploreStreams.length,
                      separatorBuilder: (_, _) => const SizedBox(width: 14),
                      itemBuilder: (context, index) {
                        final session = exploreStreams[index];
                        return _StreamDiscoveryCard(
                          session: session,
                          onTap: () => _openStreamSession(session),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 18),
                  _CommunityPulseCard(
                    hasUser: (_currentUserId ?? '').isNotEmpty,
                    scheduledCount: scheduledStreams.length,
                    onCreate: canHostStreams
                        ? _showCreateStreamDialog
                        : _openAccessRequestPath,
                  ),
                  const SizedBox(height: 24),
                ],
                if (liveStreams.isNotEmpty || scheduledStreams.isNotEmpty) ...[
                  const _StreamsSectionHeader(title: 'Live Reports'),
                  const SizedBox(height: 12),
                  ...liveStreams.map(
                    (session) => Padding(
                      padding: const EdgeInsets.only(bottom: 14),
                      child: _StreamReportTile(
                        session: session,
                        timeLabel: relativeTimeLabel(
                          session.startedAt ?? session.createdAt,
                        ),
                        onTap: () => _openStreamSession(session),
                      ),
                    ),
                  ),
                  ...scheduledStreams.map(
                    (session) => Padding(
                      padding: const EdgeInsets.only(bottom: 14),
                      child: _StreamReportTile(
                        session: session,
                        timeLabel: _scheduledLabel(session),
                        onTap: () => _handleScheduledAction(session),
                      ),
                    ),
                  ),
                ],
                if (allStreams.isNotEmpty &&
                    liveStreams.isEmpty &&
                    scheduledStreams.isEmpty)
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      'No streams found in "$effectiveCategory" right now.',
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  StreamSession? _findSessionById(String sessionId, StreamState state) {
    for (final session in [...state.liveStreams, ...state.scheduledStreams]) {
      if (session.id == sessionId) {
        return session;
      }
    }
    return state.selectedSession?.id == sessionId
        ? state.selectedSession
        : null;
  }

  List<String> _buildCategories(List<StreamSession> sessions) {
    final categories =
        sessions
            .map((session) => _normalizeCategory(session.category))
            .where((value) => value.isNotEmpty)
            .toSet()
            .toList()
          ..sort();
    return ['All', ...categories];
  }

  List<StreamSession> _filterByCategory(
    List<StreamSession> sessions,
    String category,
  ) {
    if (category.toLowerCase() == 'all') {
      return sessions;
    }
    return sessions
        .where(
          (session) =>
              _normalizeCategory(session.category).toLowerCase() ==
              category.toLowerCase(),
        )
        .toList();
  }

  String _normalizeCategory(String category) {
    final value = category.trim();
    if (value.isEmpty) {
      return 'General';
    }
    return value;
  }

  bool _isHost(StreamSession session) {
    return _currentUserId != null &&
        session.hostUserId != null &&
        session.hostUserId == _currentUserId;
  }

  void _handleScheduledAction(StreamSession session) {
    if (_isHost(session)) {
      context.read<StreamBloc>().add(StartStreamRequested(session.id));
      return;
    }
    _openStreamSession(session);
  }

  String _scheduledLabel(StreamSession session) {
    final date = session.scheduledFor;
    if (date == null) {
      return 'Schedule pending';
    }
    final hour = date.hour % 12 == 0 ? 12 : date.hour % 12;
    final minute = date.minute.toString().padLeft(2, '0');
    final period = date.hour >= 12 ? 'PM' : 'AM';
    return '${date.day}/${date.month} - $hour:$minute $period';
  }
}

class _StreamsSectionHeader extends StatelessWidget {
  const _StreamsSectionHeader({required this.title, this.actionLabel});

  final String title;
  final String? actionLabel;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: Theme.of(
              context,
            ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
          ),
        ),
        if (actionLabel != null)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: AppTheme.primary.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              actionLabel!,
              style: Theme.of(
                context,
              ).textTheme.labelLarge?.copyWith(color: AppTheme.primary),
            ),
          ),
      ],
    );
  }
}

class _HeroStatChip extends StatelessWidget {
  const _HeroStatChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelLarge?.copyWith(
          color: Colors.white,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _FeaturedStreamCard extends StatelessWidget {
  const _FeaturedStreamCard({required this.session, required this.onTap});

  final StreamSession session;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(24),
      child: Container(
        height: 260,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          color: Theme.of(context).colorScheme.surfaceContainerLow,
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            if ((session.coverImageUrl ?? '').trim().isNotEmpty)
              NewsThumbnail(
                imageUrl: session.coverImageUrl,
                fallbackLabel: session.category,
              ),
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.10),
                    Colors.black.withValues(alpha: 0.28),
                    Colors.black.withValues(alpha: 0.82),
                  ],
                ),
              ),
            ),
            Positioned(
              top: 16,
              left: 16,
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: session.isLive ? AppTheme.primary : Colors.black45,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      session.isLive ? 'LIVE' : 'SCHEDULED',
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: Colors.white,
                        letterSpacing: 1,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black45,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      session.isLive
                          ? '${session.viewerCount} viewers'
                          : _scheduledLabelStatic(session),
                      style: Theme.of(
                        context,
                      ).textTheme.labelMedium?.copyWith(color: Colors.white),
                    ),
                  ),
                ],
              ),
            ),
            Center(
              child: Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.92),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.play_arrow_rounded, size: 40),
              ),
            ),
            Positioned(
              left: 20,
              right: 20,
              bottom: 20,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    session.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(
                      context,
                    ).textTheme.headlineSmall?.copyWith(color: Colors.white),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${session.hostName ?? 'Community Host'} • ${session.category}',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Colors.white.withValues(alpha: 0.82),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StreamDiscoveryCard extends StatelessWidget {
  const _StreamDiscoveryCard({required this.session, required this.onTap});

  final StreamSession session;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: SizedBox(
        width: 280,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Stack(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: SizedBox.expand(
                      child: NewsThumbnail(
                        imageUrl: session.coverImageUrl,
                        fallbackLabel: session.category,
                      ),
                    ),
                  ),
                  Positioned(
                    top: 10,
                    left: 10,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: AppTheme.primary,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        'LIVE',
                        style: Theme.of(
                          context,
                        ).textTheme.labelMedium?.copyWith(color: Colors.white),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            Text(
              session.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 6),
            Text(
              '${session.viewerCount} watching',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 4),
            Text(
              session.hostName ?? 'Community host',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: AppTheme.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}

class _StreamReportTile extends StatelessWidget {
  const _StreamReportTile({
    required this.session,
    required this.timeLabel,
    required this.onTap,
  });

  final StreamSession session;
  final String timeLabel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: Theme.of(context).dividerColor.withValues(alpha: 0.22),
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: SizedBox(
                width: 88,
                height: 88,
                child: NewsThumbnail(
                  imageUrl: session.coverImageUrl,
                  fallbackLabel: session.category,
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        session.category,
                        style: Theme.of(context).textTheme.labelMedium
                            ?.copyWith(
                              color: AppTheme.primary,
                              letterSpacing: 0.8,
                            ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        timeLabel,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    session.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    session.description?.trim().isNotEmpty == true
                        ? session.description!.trim()
                        : 'Join this stream for live coverage and community context.',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).hintColor,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Icon(
                        session.isLive
                            ? Icons.wifi_tethering_rounded
                            : Icons.schedule_rounded,
                        size: 16,
                        color: AppTheme.primary,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          session.isLive
                              ? '${session.viewerCount} watching now'
                              : 'Tap to review the stream schedule.',
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: AppTheme.textSecondary),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

String _scheduledLabelStatic(StreamSession session) {
  final date = session.scheduledFor;
  if (date == null) {
    return 'Schedule pending';
  }
  final hour = date.hour % 12 == 0 ? 12 : date.hour % 12;
  final minute = date.minute.toString().padLeft(2, '0');
  final period = date.hour >= 12 ? 'PM' : 'AM';
  return '${date.day}/${date.month} • $hour:$minute $period';
}

class _CommunityPulseCard extends StatelessWidget {
  const _CommunityPulseCard({
    required this.hasUser,
    required this.scheduledCount,
    required this.onCreate,
  });

  final bool hasUser;
  final int scheduledCount;
  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkSurfaceMuted : const Color(0xFFE8F2ED),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: (isDark ? AppTheme.darkDivider : AppTheme.divider).withValues(
            alpha: 0.55,
          ),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: AppTheme.primary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(Icons.groups_rounded, color: AppTheme.primary),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Community pulse',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  scheduledCount > 0
                      ? '$scheduledCount scheduled conversations are already on the calendar.'
                      : 'No scheduled rooms yet. Start a stream and bring the audience in early.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppTheme.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          if (hasUser)
            TextButton(onPressed: onCreate, child: const Text('Create')),
        ],
      ),
    );
  }
}

class _EmptyStreamsState extends StatelessWidget {
  const _EmptyStreamsState({
    required this.message,
    this.actionLabel,
    this.onActionTap,
  });

  final String message;
  final String? actionLabel;
  final VoidCallback? onActionTap;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              message,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            if (actionLabel != null && onActionTap != null) ...[
              const SizedBox(height: 14),
              ElevatedButton(onPressed: onActionTap, child: Text(actionLabel!)),
            ],
          ],
        ),
      ),
    );
  }
}

class _StreamAccessGate extends StatelessWidget {
  const _StreamAccessGate({required this.isGuest, required this.onPrimaryTap});

  final bool isGuest;
  final Future<void> Function() onPrimaryTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 520),
          padding: const EdgeInsets.all(28),
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(28),
            border: Border.all(
              color: isDark ? AppTheme.darkDivider : AppTheme.divider,
            ),
            boxShadow: AppTheme.ambientShadow(theme.brightness),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: AppTheme.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: const Icon(
                  Icons.podcasts_rounded,
                  color: AppTheme.primary,
                  size: 28,
                ),
              ),
              const SizedBox(height: 18),
              Text(
                isGuest
                    ? 'Sign in to access Streams'
                    : 'Streams require admin approval',
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w900,
                  fontFamily: AppTheme.headlineFontFamily,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                isGuest
                    ? 'Live rooms, scheduled coverage, and host tools are available once you sign in.'
                    : 'This account does not have stream access yet. Visit your profile to request access from the admin team.',
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: isDark
                      ? AppTheme.darkTextSecondary
                      : AppTheme.textSecondary,
                  height: 1.55,
                ),
              ),
              const SizedBox(height: 18),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: const [
                  _GateFeatureChip(label: 'Live reporting'),
                  _GateFeatureChip(label: 'Scheduled rooms'),
                  _GateFeatureChip(label: 'Host streams'),
                ],
              ),
              const SizedBox(height: 22),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => onPrimaryTap(),
                  icon: Icon(
                    isGuest
                        ? Icons.login_rounded
                        : Icons.verified_user_outlined,
                  ),
                  label: Text(
                    isGuest ? 'Sign in and continue' : 'Request access',
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GateFeatureChip extends StatelessWidget {
  const _GateFeatureChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkSurfaceMuted : AppTheme.bgSoft,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: isDark ? AppTheme.darkDivider : AppTheme.divider,
        ),
      ),
      child: Text(
        label,
        style: Theme.of(
          context,
        ).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700),
      ),
    );
  }
}

class _CreateStreamDialog extends StatefulWidget {
  const _CreateStreamDialog({required this.initialCategory});

  final String initialCategory;

  @override
  State<_CreateStreamDialog> createState() => _CreateStreamDialogState();
}

class _CreateStreamDialogState extends State<_CreateStreamDialog> {
  late final TextEditingController _titleController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _coverImageUrlController;
  late final TextEditingController _streamUrlController;
  late String _category;
  DateTime? _scheduledFor;
  bool _scheduleForLater = false;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController();
    _descriptionController = TextEditingController();
    _coverImageUrlController = TextEditingController();
    _streamUrlController = TextEditingController();
    _category = widget.initialCategory;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _coverImageUrlController.dispose();
    _streamUrlController.dispose();
    super.dispose();
  }

  Future<void> _pickScheduleDateTime() async {
    final now = DateTime.now();
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: now.add(const Duration(days: 1)),
      firstDate: now,
      lastDate: now.add(const Duration(days: 365)),
    );
    if (!mounted || pickedDate == null) {
      return;
    }

    final pickedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(now.add(const Duration(hours: 1))),
    );
    if (!mounted || pickedTime == null) {
      return;
    }

    setState(() {
      _scheduledFor = DateTime(
        pickedDate.year,
        pickedDate.month,
        pickedDate.day,
        pickedTime.hour,
        pickedTime.minute,
      );
    });
  }

  void _submit() {
    final title = _titleController.text.trim();
    final description = _descriptionController.text.trim();
    if (title.length < 5) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a stream title.')),
      );
      return;
    }
    if (_scheduleForLater && _scheduledFor == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pick a date and time for the stream.')),
      );
      return;
    }

    Navigator.of(context).pop(
      _StreamDraft(
        title: title,
        description: description.isEmpty ? null : description,
        category: _category,
        coverImageUrl: _coverImageUrlController.text.trim().isEmpty
            ? null
            : _coverImageUrlController.text.trim(),
        streamUrl: _streamUrlController.text.trim().isEmpty
            ? null
            : _streamUrlController.text.trim(),
        scheduledFor: _scheduleForLater ? _scheduledFor : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Create Stream'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _titleController,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(
                labelText: 'Stream title',
                hintText: 'e.g. Lagos policy town hall',
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _descriptionController,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Description',
                hintText: 'What is this stream about?',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _coverImageUrlController,
              keyboardType: TextInputType.url,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(
                labelText: 'Cover image URL',
                hintText: 'Optional thumbnail image',
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _streamUrlController,
              keyboardType: TextInputType.url,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(
                labelText: 'Stream URL',
                hintText: 'Optional playback or hosting URL',
              ),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _category,
              decoration: const InputDecoration(labelText: 'Category'),
              items: const [
                DropdownMenuItem(
                  value: 'Breaking News',
                  child: Text('Breaking News'),
                ),
                DropdownMenuItem(value: 'Politics', child: Text('Politics')),
                DropdownMenuItem(value: 'Business', child: Text('Business')),
                DropdownMenuItem(
                  value: 'Technology',
                  child: Text('Technology'),
                ),
                DropdownMenuItem(value: 'Sports', child: Text('Sports')),
                DropdownMenuItem(
                  value: 'Entertainment',
                  child: Text('Entertainment'),
                ),
              ],
              onChanged: (value) {
                if (value == null || value.trim().isEmpty) {
                  return;
                }
                setState(() => _category = value);
              },
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              children: [
                ChoiceChip(
                  label: const Text('Go live now'),
                  selected: !_scheduleForLater,
                  onSelected: (_) => setState(() => _scheduleForLater = false),
                ),
                ChoiceChip(
                  label: const Text('Schedule'),
                  selected: _scheduleForLater,
                  onSelected: (_) => setState(() => _scheduleForLater = true),
                ),
              ],
            ),
            if (_scheduleForLater) ...[
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: _pickScheduleDateTime,
                icon: const Icon(Icons.calendar_today_rounded),
                label: Text(
                  _scheduledFor == null
                      ? 'Pick date and time'
                      : _formatScheduledDate(_scheduledFor!),
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _submit,
          child: Text(_scheduleForLater ? 'Schedule' : 'Start'),
        ),
      ],
    );
  }

  String _formatScheduledDate(DateTime value) {
    final hour = value.hour % 12 == 0 ? 12 : value.hour % 12;
    final minute = value.minute.toString().padLeft(2, '0');
    final period = value.hour >= 12 ? 'PM' : 'AM';
    return '${value.day}/${value.month}/${value.year} - $hour:$minute $period';
  }
}

class _StreamDraft {
  const _StreamDraft({
    required this.title,
    required this.category,
    this.description,
    this.coverImageUrl,
    this.streamUrl,
    this.scheduledFor,
  });

  final String title;
  final String category;
  final String? description;
  final String? coverImageUrl;
  final String? streamUrl;
  final DateTime? scheduledFor;
}
