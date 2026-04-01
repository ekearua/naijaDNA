import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:livekit_client/livekit_client.dart' as lk;
import 'package:naijapulse/core/di/injection_container.dart';
import 'package:naijapulse/core/error/exceptions.dart';
import 'package:naijapulse/core/routing/app_router.dart';
import 'package:naijapulse/core/theme/theme.dart';
import 'package:naijapulse/features/auth/data/auth_session_controller.dart';
import 'package:naijapulse/features/auth/data/datasource/local/auth_local_datasource.dart';
import 'package:naijapulse/features/news/presentation/widgets/news_time.dart';
import 'package:naijapulse/features/stream/domain/entities/stream_comment.dart';
import 'package:naijapulse/features/stream/domain/entities/stream_session.dart';
import 'package:naijapulse/features/stream/domain/usecases/get_livekit_connection.dart';
import 'package:naijapulse/features/stream/domain/usecases/get_stream_comments.dart';
import 'package:naijapulse/features/stream/domain/usecases/send_stream_comment.dart';
import 'package:naijapulse/features/stream/presentation/bloc/stream_bloc.dart';
import 'package:naijapulse/features/stream/presentation/widgets/live_stream_signal_bar.dart';
import 'package:naijapulse/features/stream/presentation/widgets/livekit_stream_stage.dart';
import 'package:naijapulse/features/stream/presentation/widgets/stream_comments_section.dart';

class LiveSessionPage extends StatefulWidget {
  const LiveSessionPage({required this.sessionId, this.session, super.key});

  final String sessionId;
  final StreamSession? session;

  @override
  State<LiveSessionPage> createState() => _LiveSessionPageState();
}

class _LiveSessionPageState extends State<LiveSessionPage> {
  final TextEditingController _commentController = TextEditingController();
  Timer? _refreshTimer;
  String? _currentUserId;
  bool _presenceJoined = false;
  bool _isConnectingMedia = false;
  bool _isLoadingComments = false;
  bool _isSendingComment = false;
  String? _connectedStreamId;
  String? _mediaErrorMessage;
  String? _commentsErrorMessage;
  List<StreamComment> _comments = const [];
  lk.Room? _room;
  late final StreamBloc _streamBloc;
  late final AuthSessionController _authSessionController;
  late final GetLiveKitConnection _getLiveKitConnection;
  late final GetStreamComments _getStreamComments;
  late final SendStreamComment _sendStreamComment;

  @override
  void initState() {
    super.initState();
    _streamBloc = context.read<StreamBloc>();
    _authSessionController = InjectionContainer.sl<AuthSessionController>();
    _getLiveKitConnection = InjectionContainer.sl<GetLiveKitConnection>();
    _getStreamComments = InjectionContainer.sl<GetStreamComments>();
    _sendStreamComment = InjectionContainer.sl<SendStreamComment>();
    _authSessionController.addListener(_handleAuthChanged);
    _loadCurrentUser();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      _streamBloc.add(
        LoadStreamSessionRequested(
          widget.sessionId,
          initialSession: widget.session,
        ),
      );
      unawaited(_loadComments(showLoader: true));
    });
    _refreshTimer = Timer.periodic(const Duration(seconds: 20), (_) {
      if (!mounted) {
        return;
      }
      _streamBloc.add(LoadStreamSessionRequested(widget.sessionId));
      unawaited(_loadComments());
      if (_presenceJoined) {
        _streamBloc.add(
          UpdateStreamPresenceRequested(
            streamId: widget.sessionId,
            action: 'heartbeat',
          ),
        );
      }
    });
  }

  Future<void> _loadCurrentUser() async {
    final session = await InjectionContainer.sl<AuthLocalDataSource>()
        .getCachedSession();
    if (!mounted) {
      return;
    }
    setState(() => _currentUserId = session?.userId.trim());
  }

  void _handleAuthChanged() {
    if (!mounted) {
      return;
    }
    setState(() {
      _currentUserId = _authSessionController.session?.userId.trim();
    });
    final session = _resolvedSession(_streamBloc.state);
    if (session != null) {
      unawaited(_syncLiveKitRoom(session, force: true));
    }
    unawaited(_loadComments());
  }

  @override
  void dispose() {
    _authSessionController.removeListener(_handleAuthChanged);
    _refreshTimer?.cancel();
    _commentController.dispose();
    if (_presenceJoined) {
      _streamBloc.add(
        UpdateStreamPresenceRequested(
          streamId: widget.sessionId,
          action: 'leave',
        ),
      );
    }
    unawaited(_disposeRoom());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<StreamBloc, StreamState>(
      listenWhen: (previous, current) =>
          previous.selectedSession != current.selectedSession ||
          previous.actionStatus != current.actionStatus,
      listener: (context, state) {
        final session = state.selectedSession;
        if (session != null && session.id == widget.sessionId) {
          if (session.isLive && !_presenceJoined) {
            _presenceJoined = true;
            context.read<StreamBloc>().add(
              UpdateStreamPresenceRequested(
                streamId: widget.sessionId,
                action: 'join',
              ),
            );
          }
          if (!session.isLive && _presenceJoined) {
            _presenceJoined = false;
            context.read<StreamBloc>().add(
              UpdateStreamPresenceRequested(
                streamId: widget.sessionId,
                action: 'leave',
              ),
            );
          }
          unawaited(_syncLiveKitRoom(session));
        }

        if (state.actionStatus == StreamActionStatus.success ||
            state.actionStatus == StreamActionStatus.failure) {
          final message = state.actionMessage;
          if (message != null && message.trim().isNotEmpty) {
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(SnackBar(content: Text(message)));
          }
          context.read<StreamBloc>().add(const ClearStreamActionRequested());
        }
      },
      builder: (context, state) {
        final session = _resolvedSession(state);

        if (state.status == StreamStatus.loading && session == null) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (session == null) {
          return Scaffold(
            appBar: AppBar(title: const Text('Streams')),
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Text(
                  state.errorMessage ??
                      'This stream is not available from backend data right now.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
              ),
            ),
          );
        }

        final hasHeroImage =
            session.coverImageUrl != null &&
            session.coverImageUrl!.trim().isNotEmpty;
        final summaryText = _buildSummaryText(session.description);
        final commentItems = _comments
            .map(
              (comment) => (
                author: comment.authorName,
                timeLabel: relativeTimeLabel(comment.createdAt),
                body: comment.body,
              ),
            )
            .toList();
        final isHost =
            _currentUserId != null && _currentUserId == session.hostUserId;

        return Scaffold(
          appBar: AppBar(
            title: const Text('Streams'),
            leading: IconButton(
              onPressed: () {
                if (context.canPop()) {
                  context.pop();
                  return;
                }
                context.go(AppRouter.livePath);
              },
              icon: const Icon(Icons.arrow_back_rounded),
              tooltip: 'Back',
            ),
          ),
          bottomNavigationBar: _LiveChatInputBar(
            controller: _commentController,
            enabled: session.isLive,
            isSending: _isSendingComment,
            onSendTap: () => _handleSendComment(session),
          ),
          body: ListView(
            padding: const EdgeInsets.only(bottom: 20),
            children: [
              if (session.isLive) ...[
                LiveKitStreamStage(
                  title: session.title,
                  source: session.hostName ?? 'Community Host',
                  viewerCount: session.viewerCount,
                  isHost: isHost,
                  track: _primaryVideoTrack(),
                  fallbackImageUrl: session.coverImageUrl,
                  isConnecting: _isConnectingMedia,
                  errorMessage: _mediaErrorMessage,
                ),
                const LiveStreamSignalBar(),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                  child: _LiveSessionSummaryCard(
                    session: session,
                    summary: summaryText,
                    metaLabel: _sessionMeta(session),
                    isHost: isHost,
                    onReconnectTap: isHost
                        ? () => _syncLiveKitRoom(session, force: true)
                        : null,
                    onEndTap: isHost
                        ? () => context.read<StreamBloc>().add(
                            EndStreamRequested(session.id),
                          )
                        : null,
                  ),
                ),
              ] else ...[
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
                  child: _ScheduledSessionHero(
                    session: session,
                    isHost: isHost,
                    hasHeroImage: hasHeroImage,
                    summaryText: summaryText,
                    onStartTap: session.isScheduled && isHost
                        ? () => context.read<StreamBloc>().add(
                            StartStreamRequested(session.id),
                          )
                        : null,
                    onEndTap: session.isLive && isHost
                        ? () => context.read<StreamBloc>().add(
                            EndStreamRequested(session.id),
                          )
                        : null,
                  ),
                ),
              ],
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                child: _SessionPulseRail(session: session),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                child: _DiscussionCard(
                  session: session,
                  commentItems: commentItems,
                  isLoadingComments: _isLoadingComments,
                  commentsErrorMessage: _commentsErrorMessage,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _loadComments({bool showLoader = false}) async {
    if (showLoader && mounted) {
      setState(() => _isLoadingComments = true);
    }
    try {
      final comments = await _getStreamComments(widget.sessionId);
      if (!mounted) {
        return;
      }
      setState(() {
        _comments = comments;
        _commentsErrorMessage = null;
        _isLoadingComments = false;
      });
    } on AppException catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _commentsErrorMessage = error.message;
        _isLoadingComments = false;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _commentsErrorMessage = 'Unable to load comments right now.';
        _isLoadingComments = false;
      });
    }
  }

  Future<void> _handleSendComment(StreamSession session) async {
    if (!session.isLive) {
      return;
    }
    if ((_currentUserId ?? '').isEmpty) {
      await context.push(AppRouter.loginPath);
      await _loadCurrentUser();
      return;
    }

    final body = _commentController.text.trim();
    if (body.isEmpty || _isSendingComment) {
      return;
    }

    setState(() => _isSendingComment = true);
    try {
      final comment = await _sendStreamComment(
        streamId: widget.sessionId,
        body: body,
      );
      if (!mounted) {
        return;
      }
      _commentController.clear();
      setState(() {
        _comments = [comment, ..._comments];
        _commentsErrorMessage = null;
        _isSendingComment = false;
      });
    } on AppException catch (error) {
      if (!mounted) {
        return;
      }
      setState(() => _isSendingComment = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() => _isSendingComment = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not send comment right now.')),
      );
    }
  }

  Future<void> _syncLiveKitRoom(
    StreamSession session, {
    bool force = false,
  }) async {
    if (!session.isLive) {
      await _disposeRoom();
      if (mounted) {
        setState(() => _mediaErrorMessage = null);
      }
      return;
    }
    if (!force && _connectedStreamId == session.id && _room != null) {
      return;
    }
    if (_isConnectingMedia) {
      return;
    }

    setState(() {
      _isConnectingMedia = true;
      _mediaErrorMessage = null;
    });

    await _disposeRoom();
    if (!mounted) {
      return;
    }

    try {
      final connection = await _getLiveKitConnection(session.id);
      final room = lk.Room(
        roomOptions: const lk.RoomOptions(adaptiveStream: true, dynacast: true),
      );
      room.addListener(_handleRoomChanged);
      await room.prepareConnection(connection.wsUrl, connection.token);
      await room.connect(connection.wsUrl, connection.token);

      String? mediaWarning;
      if (connection.canPublish) {
        try {
          await room.localParticipant!.setCameraEnabled(true);
        } catch (error) {
          mediaWarning = 'Connected, but camera could not start: $error';
        }
        try {
          await room.localParticipant!.setMicrophoneEnabled(true);
        } catch (error) {
          mediaWarning = mediaWarning == null
              ? 'Connected, but microphone could not start: $error'
              : '$mediaWarning\nMicrophone error: $error';
        }
      }

      if (!mounted) {
        await room.disconnect();
        return;
      }

      setState(() {
        _room = room;
        _connectedStreamId = session.id;
        _mediaErrorMessage = mediaWarning;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _mediaErrorMessage = _friendlyMediaError(error);
      });
    } finally {
      if (mounted) {
        setState(() => _isConnectingMedia = false);
      }
    }
  }

  Future<void> _disposeRoom() async {
    final room = _room;
    if (room == null) {
      _connectedStreamId = null;
      return;
    }
    room.removeListener(_handleRoomChanged);
    _room = null;
    _connectedStreamId = null;
    try {
      await room.disconnect();
    } catch (_) {
      // Best-effort disconnect on page exit or reconnect.
    }
  }

  void _handleRoomChanged() {
    if (!mounted) {
      return;
    }
    setState(() {});
  }

  lk.VideoTrack? _primaryVideoTrack() {
    final room = _room;
    if (room == null) {
      return null;
    }

    for (final publication in room.localParticipant!.videoTrackPublications) {
      if (!publication.muted &&
          !publication.isScreenShare &&
          publication.track is lk.VideoTrack) {
        return publication.track as lk.VideoTrack;
      }
    }

    for (final participant in room.remoteParticipants.values) {
      for (final publication in participant.videoTrackPublications) {
        if (!publication.muted &&
            publication.subscribed &&
            !publication.isScreenShare &&
            publication.track is lk.VideoTrack) {
          return publication.track as lk.VideoTrack;
        }
      }
    }
    return null;
  }

  String _friendlyMediaError(Object error) {
    final message = error.toString();
    if (message.contains('503')) {
      return 'Live video is not configured on the server yet. Add the LiveKit Cloud credentials and try again.';
    }
    if (message.contains('409')) {
      return 'This stream is not live yet. Start the session first, then join the room.';
    }
    return 'Could not connect to the live room right now.';
  }

  StreamSession? _resolvedSession(StreamState state) {
    if (state.selectedSession?.id == widget.sessionId) {
      return state.selectedSession;
    }
    if (widget.session?.id == widget.sessionId) {
      return widget.session;
    }
    for (final session in [...state.liveStreams, ...state.scheduledStreams]) {
      if (session.id == widget.sessionId) {
        return session;
      }
    }
    return null;
  }

  String _buildSummaryText(String? description) {
    final text = _cleanText(description);
    if (text.isEmpty) {
      return '';
    }
    return _splitSentences(text).take(3).join(' ');
  }

  String _cleanText(String? value) {
    if (value == null || value.trim().isEmpty) {
      return '';
    }
    final withoutTags = value.replaceAll(RegExp(r'<[^>]*>'), ' ');
    return withoutTags.replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  List<String> _splitSentences(String value) {
    return value
        .split(RegExp(r'(?<=[.!?])\s+'))
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .toList();
  }

  String _sessionMeta(StreamSession session) {
    if (session.isLive) {
      final started = session.startedAt ?? session.createdAt;
      return '${session.hostName ?? 'Community Host'} - ${relativeTimeLabel(started)} - ${session.viewerCount} watching';
    }
    if (session.isScheduled && session.scheduledFor != null) {
      final date = session.scheduledFor!;
      final hour = date.hour % 12 == 0 ? 12 : date.hour % 12;
      final minute = date.minute.toString().padLeft(2, '0');
      final period = date.hour >= 12 ? 'PM' : 'AM';
      return '${session.hostName ?? 'Community Host'} - Scheduled for ${date.day}/${date.month} at $hour:$minute $period';
    }
    if (session.endedAt != null) {
      return '${session.hostName ?? 'Community Host'} - Ended ${relativeTimeLabel(session.endedAt!)}';
    }
    return session.hostName ?? 'Community Host';
  }
}

class _LiveSessionSummaryCard extends StatelessWidget {
  const _LiveSessionSummaryCard({
    required this.session,
    required this.summary,
    required this.metaLabel,
    required this.isHost,
    this.onReconnectTap,
    this.onEndTap,
  });

  final StreamSession session;
  final String summary;
  final String metaLabel;
  final bool isHost;
  final VoidCallback? onReconnectTap;
  final VoidCallback? onEndTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: Theme.of(context).dividerColor.withValues(alpha: 0.5),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _StatusChip(label: 'Live now', color: AppTheme.breaking),
              _StatusChip(label: session.category, color: AppTheme.primary),
              _StatusChip(
                label: '${session.viewerCount} watching',
                color: AppTheme.success,
              ),
              if (isHost)
                _StatusChip(label: 'Host controls', color: AppTheme.warning),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            session.title,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w800,
              height: 1.15,
            ),
          ),
          if (summary.trim().isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              summary,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(height: 1.5),
            ),
          ],
          const SizedBox(height: 10),
          Text(
            metaLabel,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: AppTheme.textMeta),
          ),
          if (isHost || onEndTap != null) ...[
            const SizedBox(height: 14),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                if (isHost && onReconnectTap != null)
                  OutlinedButton.icon(
                    onPressed: onReconnectTap,
                    icon: const Icon(Icons.refresh_rounded),
                    label: const Text('Reconnect room'),
                  ),
                if (onEndTap != null)
                  OutlinedButton.icon(
                    onPressed: onEndTap,
                    icon: const Icon(Icons.stop_circle_outlined),
                    label: const Text('End stream'),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _ScheduledSessionHero extends StatelessWidget {
  const _ScheduledSessionHero({
    required this.session,
    required this.isHost,
    required this.hasHeroImage,
    required this.summaryText,
    this.onStartTap,
    this.onEndTap,
  });

  final StreamSession session;
  final bool isHost;
  final bool hasHeroImage;
  final String summaryText;
  final VoidCallback? onStartTap;
  final VoidCallback? onEndTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(26),
        boxShadow: AppTheme.ambientShadow(Theme.of(context).brightness),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            height: 240,
            width: double.infinity,
            child: Stack(
              fit: StackFit.expand,
              children: [
                if (hasHeroImage)
                  Image.network(
                    session.coverImageUrl!,
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) =>
                        _SessionHeroPlaceholder(label: session.category),
                  )
                else
                  _SessionHeroPlaceholder(label: session.category),
                DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.black.withValues(alpha: 0.05),
                        Colors.black.withValues(alpha: 0.68),
                      ],
                    ),
                  ),
                ),
                Positioned(
                  top: 16,
                  left: 16,
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _StatusChip(
                        label: session.isScheduled ? 'Scheduled' : 'Off air',
                        color: session.isScheduled
                            ? AppTheme.primary
                            : AppTheme.warning,
                      ),
                      _StatusChip(
                        label: session.category,
                        color: AppTheme.success,
                      ),
                    ],
                  ),
                ),
                Positioned(
                  left: 18,
                  right: 18,
                  bottom: 18,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        session.title,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.headlineSmall
                            ?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w900,
                              height: 1.1,
                            ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _sessionLabel(session),
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Colors.white.withValues(alpha: 0.86),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (summaryText.trim().isNotEmpty)
                  Text(
                    summaryText,
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: AppTheme.textSecondary,
                      height: 1.5,
                    ),
                  ),
                if (summaryText.trim().isNotEmpty) const SizedBox(height: 16),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    if (onStartTap != null)
                      ElevatedButton.icon(
                        onPressed: onStartTap,
                        icon: const Icon(Icons.play_arrow_rounded),
                        label: const Text('Start stream'),
                      ),
                    if (onEndTap != null)
                      OutlinedButton.icon(
                        onPressed: onEndTap,
                        icon: const Icon(Icons.stop_circle_outlined),
                        label: const Text('End stream'),
                      ),
                    if (isHost && onStartTap == null && onEndTap == null)
                      OutlinedButton.icon(
                        onPressed: () {},
                        icon: const Icon(Icons.edit_calendar_outlined),
                        label: const Text('Host tools'),
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

  String _sessionLabel(StreamSession session) {
    if (session.scheduledFor == null) {
      return session.hostName ?? 'Community Host';
    }
    final date = session.scheduledFor!;
    final hour = date.hour % 12 == 0 ? 12 : date.hour % 12;
    final minute = date.minute.toString().padLeft(2, '0');
    final period = date.hour >= 12 ? 'PM' : 'AM';
    return '${session.hostName ?? 'Community Host'} • ${date.day}/${date.month} at $hour:$minute $period';
  }
}

class _SessionHeroPlaceholder extends StatelessWidget {
  const _SessionHeroPlaceholder({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppTheme.primary.withValues(alpha: 0.96),
            AppTheme.primaryContainer,
          ],
        ),
      ),
      child: Center(
        child: Text(
          label,
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
    );
  }
}

class _SessionPulseRail extends StatelessWidget {
  const _SessionPulseRail({required this.session});

  final StreamSession session;

  @override
  Widget build(BuildContext context) {
    final items = [
      (
        'Status',
        session.isLive
            ? 'Live'
            : session.isScheduled
            ? 'Scheduled'
            : 'Ended',
      ),
      ('Category', session.category),
      ('Audience', session.isLive ? '${session.viewerCount}' : 'Preview'),
    ];

    return Row(
      children: items
          .map(
            (item) => Expanded(
              child: Container(
                margin: EdgeInsets.only(right: item == items.last ? 0 : 12),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: Theme.of(
                      context,
                    ).dividerColor.withValues(alpha: 0.45),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.$1,
                      style: Theme.of(
                        context,
                      ).textTheme.bodySmall?.copyWith(color: AppTheme.textMeta),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      item.$2,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          )
          .toList(),
    );
  }
}

class _DiscussionCard extends StatelessWidget {
  const _DiscussionCard({
    required this.session,
    required this.commentItems,
    required this.isLoadingComments,
    required this.commentsErrorMessage,
  });

  final StreamSession session;
  final List<({String author, String timeLabel, String body})> commentItems;
  final bool isLoadingComments;
  final String? commentsErrorMessage;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: Theme.of(context).dividerColor.withValues(alpha: 0.45),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Discussion',
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 6),
                Text(
                  session.isLive
                      ? 'Live reactions, questions, and community context.'
                      : 'The discussion rail opens fully once the stream goes live.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppTheme.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          StreamCommentsSection(
            commentCountLabel: '${commentItems.length} comments',
            comments: commentItems,
          ),
          if (isLoadingComments)
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 12, 16, 12),
              child: Center(child: CircularProgressIndicator()),
            ),
          if (!isLoadingComments &&
              commentsErrorMessage != null &&
              commentItems.isEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              child: Text(
                commentsErrorMessage!,
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(color: AppTheme.textMeta),
              ),
            ),
          if (!isLoadingComments && commentItems.isEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              child: Text(
                session.isLive
                    ? 'No comments yet. Be the first to join the conversation.'
                    : 'Comments will appear here when the stream is live.',
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(color: AppTheme.textMeta),
              ),
            ),
        ],
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.22)),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelLarge?.copyWith(
          color: color,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _LiveChatInputBar extends StatelessWidget {
  const _LiveChatInputBar({
    required this.controller,
    required this.enabled,
    required this.isSending,
    required this.onSendTap,
  });

  final TextEditingController controller;
  final bool enabled;
  final bool isSending;
  final VoidCallback onSendTap;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          border: Border(
            top: BorderSide(color: Theme.of(context).dividerColor),
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: controller,
                enabled: enabled && !isSending,
                minLines: 1,
                maxLines: 3,
                decoration: InputDecoration(
                  hintText: enabled
                      ? 'Type a message...'
                      : 'Chat becomes available when the stream is live.',
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                  suffixIcon: IconButton(
                    onPressed: enabled && !isSending ? () {} : null,
                    icon: const Icon(Icons.mood_outlined),
                    tooltip: 'Emoji',
                  ),
                ),
                onSubmitted: enabled && !isSending ? (_) => onSendTap() : null,
              ),
            ),
            const SizedBox(width: 8),
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
              ),
              child: IconButton(
                onPressed: enabled && !isSending ? onSendTap : null,
                icon: isSending
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.send_rounded),
                tooltip: 'Send',
              ),
            ),
          ],
        ),
      ),
    );
  }
}
