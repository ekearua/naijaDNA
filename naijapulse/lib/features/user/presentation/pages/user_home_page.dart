import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:naijapulse/core/app_runtime.dart';
import 'package:naijapulse/core/di/injection_container.dart';
import 'package:naijapulse/core/error/failures.dart';
import 'package:naijapulse/core/routing/app_router.dart';
import 'package:naijapulse/core/theme/theme.dart';
import 'package:naijapulse/core/theme/app_theme_controller.dart';
import 'package:naijapulse/core/theme/app_theme_scope.dart';
import 'package:naijapulse/features/auth/data/auth_session_controller.dart';
import 'package:naijapulse/features/auth/domain/entities/auth_session.dart';
import 'package:naijapulse/features/auth/domain/usecases/get_cached_session.dart';
import 'package:naijapulse/features/notifications/data/notifications_inbox_controller.dart';
import 'package:naijapulse/features/auth/domain/usecases/logout_user.dart';
import 'package:naijapulse/features/news/presentation/bloc/news_bloc.dart';
import 'package:naijapulse/features/user/data/datasource/remote/user_preferences_remote_datasource.dart';
import 'package:naijapulse/features/user/data/models/user_personalization_profile_model.dart';
import 'package:naijapulse/features/user/data/models/user_settings_model.dart';
import 'package:naijapulse/features/user/presentation/widgets/preferences_navigation_row.dart';
import 'package:naijapulse/features/user/presentation/widgets/preferences_section_label.dart';
import 'package:naijapulse/features/user/presentation/widgets/preferences_toggle_row.dart';

class UserHomePage extends StatefulWidget {
  const UserHomePage({super.key});

  @override
  State<UserHomePage> createState() => _UserHomePageState();
}

class _UserHomePageState extends State<UserHomePage> {
  static const String _categoryPolitics = 'politics';
  static const String _categoryBusiness = 'business';
  static const String _categoryTechnology = 'technology';
  static const String _categorySports = 'sports';
  static const String _categoryEntertainment = 'entertainment';

  bool _breakingAlerts = true;
  bool _liveAlerts = true;
  bool _commentReplies = true;
  bool _politicsInterest = true;
  bool _businessInterest = true;
  bool _techInterest = true;
  bool _sportsInterest = true;
  bool _entertainmentInterest = false;

  String _themeKey = 'system';
  String _textSizeKey = 'small';
  List<Map<String, dynamic>> _accessRequests = const <Map<String, dynamic>>[];

  AuthSession? _authSession;
  AppThemeController? _themeController;
  late final AuthSessionController _authSessionController;
  late final NotificationsInboxController _notificationsInboxController;

  bool _isLoadingInterests = false;
  bool _isSavingInterests = false;
  bool _isLoadingSettings = false;
  bool _isSavingSettings = false;

  Timer? _saveInterestsDebounce;

  UserPreferencesRemoteDataSource get _preferencesRemoteDataSource =>
      InjectionContainer.sl<UserPreferencesRemoteDataSource>();

  @override
  void initState() {
    super.initState();
    _authSessionController = InjectionContainer.sl<AuthSessionController>();
    _notificationsInboxController =
        InjectionContainer.sl<NotificationsInboxController>();
    _authSessionController.addListener(_handleAuthChanged);
    _notificationsInboxController.addListener(_handleNotificationsChanged);
    _loadAuthSession();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _themeController ??= AppThemeScope.of(context);
  }

  @override
  void dispose() {
    _authSessionController.removeListener(_handleAuthChanged);
    _notificationsInboxController.removeListener(_handleNotificationsChanged);
    _saveInterestsDebounce?.cancel();
    super.dispose();
  }

  void _handleNotificationsChanged() {
    if (!mounted) {
      return;
    }
    setState(() {});
  }

  Future<void> _handleAuthChanged() async {
    if (!mounted) {
      return;
    }
    final session = _authSessionController.session;
    if (session?.userId == _authSession?.userId) {
      return;
    }
    setState(() => _authSession = session);
    if (session == null) {
      _resetSettingsForGuest();
      return;
    }
    await Future.wait([
      _loadRemoteInterests(session.userId),
      _loadRemoteSettings(session.userId),
      _loadAccessRequests(session.userId),
    ]);
  }

  Future<void> _loadAuthSession() async {
    AuthSession? session;
    try {
      session = await InjectionContainer.sl<GetCachedSession>()();
    } catch (_) {
      session = null;
    }

    if (!mounted) {
      return;
    }

    setState(() => _authSession = session);

    if (session == null) {
      _resetSettingsForGuest();
      return;
    }

    if (mounted) {
      context.read<NewsBloc>().add(const LoadNewsRequested());
    }

    await Future.wait([
      _loadRemoteInterests(session.userId),
      _loadRemoteSettings(session.userId),
      _loadAccessRequests(session.userId),
    ]);
  }

  void _resetSettingsForGuest() {
    setState(() {
      _breakingAlerts = true;
      _liveAlerts = true;
      _commentReplies = true;
      _politicsInterest = true;
      _businessInterest = true;
      _techInterest = true;
      _sportsInterest = true;
      _entertainmentInterest = false;
      _themeKey = 'system';
      _textSizeKey = 'small';
      _accessRequests = const <Map<String, dynamic>>[];
    });

    _themeController?.setThemeModeFromKey('system');
    _themeController?.setTextSizeFromKey('small');
  }

  Future<void> _loadRemoteInterests(String userId) async {
    setState(() => _isLoadingInterests = true);
    try {
      final profile = await _preferencesRemoteDataSource.fetchProfile(
        userId: userId,
      );
      if (!mounted) {
        return;
      }
      _applyInterestProfile(profile);
    } catch (error) {
      if (!mounted) {
        return;
      }
      final message = mapFailure(error).message;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not load interests: $message')),
      );
    } finally {
      if (mounted) {
        setState(() => _isLoadingInterests = false);
      }
    }
  }

  Future<void> _loadRemoteSettings(String userId) async {
    setState(() => _isLoadingSettings = true);
    try {
      final settings = await _preferencesRemoteDataSource.fetchSettings(
        userId: userId,
      );

      if (!mounted) {
        return;
      }

      _applySettingsModel(settings);
    } catch (error) {
      if (!mounted) {
        return;
      }
      final message = mapFailure(error).message;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not load settings: $message')),
      );
    } finally {
      if (mounted) {
        setState(() => _isLoadingSettings = false);
      }
    }
  }

  Future<void> _loadAccessRequests(String userId) async {
    try {
      final items = await _preferencesRemoteDataSource.fetchAccessRequests(
        userId: userId,
      );
      if (!mounted) {
        return;
      }
      setState(() => _accessRequests = items);
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() => _accessRequests = const <Map<String, dynamic>>[]);
    }
  }

  void _applyInterestProfile(UserPersonalizationProfileModel profile) {
    final enabled = profile.interests
        .where((item) => item.isEnabled)
        .map((item) => item.categoryId.trim().toLowerCase())
        .toSet();

    setState(() {
      _politicsInterest = enabled.contains(_categoryPolitics);
      _businessInterest = enabled.contains(_categoryBusiness);
      _techInterest = enabled.contains(_categoryTechnology);
      _sportsInterest = enabled.contains(_categorySports);
      _entertainmentInterest = enabled.contains(_categoryEntertainment);
    });
  }

  void _applySettingsModel(UserSettingsModel model) {
    final normalizedTheme = _normalizeTheme(model.theme);
    final normalizedTextSize = _normalizeTextSize(model.textSize);

    setState(() {
      _breakingAlerts = model.breakingNewsAlerts;
      _liveAlerts = model.liveStreamAlerts;
      _commentReplies = model.commentReplies;
      _themeKey = normalizedTheme;
      _textSizeKey = normalizedTextSize;
    });

    _themeController?.setThemeModeFromKey(normalizedTheme);
    _themeController?.setTextSizeFromKey(normalizedTextSize);
  }

  void _onInterestChanged(VoidCallback updateSelection) {
    updateSelection();
    setState(() {});
    _queueInterestsSave();
  }

  void _queueInterestsSave() {
    if (_authSession == null) {
      return;
    }
    _saveInterestsDebounce?.cancel();
    _saveInterestsDebounce = Timer(const Duration(milliseconds: 500), () {
      _saveInterests();
    });
  }

  Future<void> _saveInterests() async {
    final session = _authSession;
    if (session == null || _isSavingInterests) {
      return;
    }

    setState(() => _isSavingInterests = true);
    try {
      final enabledCategoryIds = <String>[
        if (_politicsInterest) _categoryPolitics,
        if (_businessInterest) _categoryBusiness,
        if (_techInterest) _categoryTechnology,
        if (_sportsInterest) _categorySports,
        if (_entertainmentInterest) _categoryEntertainment,
      ];

      await _preferencesRemoteDataSource.setInterests(
        userId: session.userId,
        enabledCategoryIds: enabledCategoryIds,
      );

      if (mounted) {
        context.read<NewsBloc>().add(const LoadNewsRequested());
      }
    } catch (error) {
      if (!mounted) {
        return;
      }
      final message = mapFailure(error).message;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not save interests: $message')),
      );
    } finally {
      if (mounted) {
        setState(() => _isSavingInterests = false);
      }
    }
  }

  Future<void> _updateSettings({
    bool? breakingNewsAlerts,
    bool? liveStreamAlerts,
    bool? commentReplies,
    String? theme,
    String? textSize,
    required VoidCallback rollback,
  }) async {
    final session = _authSession;
    if (session == null) {
      if (mounted) {
        setState(rollback);
      }
      await _promptSignInToSaveSettings();
      return;
    }

    setState(() => _isSavingSettings = true);
    try {
      final settings = await _preferencesRemoteDataSource.updateSettings(
        userId: session.userId,
        breakingNewsAlerts: breakingNewsAlerts,
        liveStreamAlerts: liveStreamAlerts,
        commentReplies: commentReplies,
        theme: theme,
        textSize: textSize,
      );
      if (!mounted) {
        return;
      }
      _applySettingsModel(settings);
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(rollback);
      if (theme != null) {
        _themeController?.setThemeModeFromKey(_themeKey);
      }
      if (textSize != null) {
        _themeController?.setTextSizeFromKey(_textSizeKey);
      }
      final message = mapFailure(error).message;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not save settings: $message')),
      );
    } finally {
      if (mounted) {
        setState(() => _isSavingSettings = false);
      }
    }
  }

  Future<void> _onThemeTap() async {
    final selected = await _showOptionsSheet(
      title: 'Theme',
      currentValue: _themeKey,
      options: const [
        _OptionItem(value: 'system', label: 'System Default'),
        _OptionItem(value: 'light', label: 'Light'),
        _OptionItem(value: 'dark', label: 'Dark'),
      ],
    );

    if (selected == null || selected == _themeKey) {
      return;
    }

    final previous = _themeKey;
    setState(() => _themeKey = selected);
    _themeController?.setThemeModeFromKey(selected);

    if (_authSession == null) {
      return;
    }

    await _updateSettings(
      theme: selected,
      rollback: () {
        _themeKey = previous;
      },
    );
  }

  Future<void> _onTextSizeTap() async {
    final selected = await _showOptionsSheet(
      title: 'Text Size',
      currentValue: _textSizeKey,
      options: const [
        _OptionItem(value: 'small', label: 'Small'),
        _OptionItem(value: 'normal', label: 'Normal'),
        _OptionItem(value: 'large', label: 'Large'),
      ],
    );

    if (selected == null || selected == _textSizeKey) {
      return;
    }

    final previous = _textSizeKey;
    setState(() => _textSizeKey = selected);
    _themeController?.setTextSizeFromKey(selected);

    if (_authSession == null) {
      return;
    }

    await _updateSettings(
      textSize: selected,
      rollback: () {
        _textSizeKey = previous;
      },
    );
  }

  Future<void> _onRequestAccessTap() async {
    final session = _authSession;
    if (session == null) {
      await _promptSignInToSaveSettings();
      return;
    }

    final selectedAccess = await _showOptionsSheet(
      title: 'Request More Access',
      currentValue: '',
      options: const [
        _OptionItem(value: 'stream_access', label: 'Stream Access'),
        _OptionItem(value: 'stream_hosting', label: 'Stream Hosting'),
        _OptionItem(value: 'contribution_access', label: 'Contribution Access'),
      ],
    );

    if (!mounted) {
      return;
    }
    if (selectedAccess == null) {
      return;
    }
    if (_hasGrantedAccess(selectedAccess)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${_accessTypeLabel(selectedAccess)} is already enabled.',
          ),
        ),
      );
      return;
    }
    if (_hasPendingRequest(selectedAccess)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'You already have a pending ${_accessTypeLabel(selectedAccess).toLowerCase()} request.',
          ),
        ),
      );
      return;
    }

    final reason = await _showAccessReasonDialog(selectedAccess);
    if (!mounted) {
      return;
    }
    if (reason == null) {
      return;
    }

    setState(() => _isSavingSettings = true);
    try {
      await _preferencesRemoteDataSource.createAccessRequest(
        userId: session.userId,
        accessType: selectedAccess,
        reason: reason,
      );
      await _loadAccessRequests(session.userId);
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${_accessTypeLabel(selectedAccess)} request sent to the admin team.',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      final message = mapFailure(error).message;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not send access request: $message')),
      );
    } finally {
      if (mounted) {
        setState(() => _isSavingSettings = false);
      }
    }
  }

  Future<void> _promptSignInToSaveSettings() async {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Sign in to save your settings.')),
    );
    await context.push(AppRouter.loginPath);
    await _loadAuthSession();
  }

  Future<String?> _showOptionsSheet({
    required String title,
    required String currentValue,
    required List<_OptionItem> options,
  }) {
    return showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                title: Text(
                  title,
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
                ),
              ),
              ...options.map((option) {
                final selected = option.value == currentValue;
                return ListTile(
                  title: Text(option.label),
                  trailing: selected
                      ? Icon(
                          Icons.check_rounded,
                          color: Theme.of(context).colorScheme.primary,
                        )
                      : null,
                  onTap: () => Navigator.of(context).pop(option.value),
                );
              }),
              const SizedBox(height: 10),
            ],
          ),
        );
      },
    );
  }

  String _normalizeTheme(String value) {
    switch (value.trim().toLowerCase()) {
      case 'light':
      case 'dark':
      case 'system':
        return value.trim().toLowerCase();
      default:
        return 'system';
    }
  }

  String _normalizeTextSize(String value) {
    switch (value.trim().toLowerCase()) {
      case 'small':
      case 'large':
      case 'normal':
        return value.trim().toLowerCase();
      default:
        return 'small';
    }
  }

  String _themeLabel(String value) {
    switch (value) {
      case 'light':
        return 'Light';
      case 'dark':
        return 'Dark';
      case 'system':
      default:
        return 'System Default';
    }
  }

  String _textSizeLabel(String value) {
    switch (value) {
      case 'small':
        return 'Small';
      case 'large':
        return 'Large';
      case 'normal':
      default:
        return 'Normal';
    }
  }

  String _accountTypeLabel(bool isGuest) => isGuest ? 'Guest' : 'User';

  bool _hasGrantedAccess(String accessType) {
    final session = _authSession;
    if (session == null) {
      return false;
    }
    switch (accessType) {
      case 'stream_access':
        return session.canAccessStreams;
      case 'stream_hosting':
        return session.canHostStreams;
      case 'contribution_access':
        return session.canContributeStories;
      default:
        return false;
    }
  }

  bool _hasPendingRequest(String accessType) {
    return _accessRequests.any(
      (item) =>
          (item['access_type'] ?? '').toString() == accessType &&
          (item['status'] ?? '').toString() == 'pending',
    );
  }

  int _pendingAccessRequestCount() {
    return _accessRequests
        .where((item) => (item['status'] ?? '').toString() == 'pending')
        .length;
  }

  String _accessTypeLabel(String accessType) {
    switch (accessType) {
      case 'stream_access':
        return 'Stream Access';
      case 'stream_hosting':
        return 'Stream Hosting';
      case 'contribution_access':
        return 'Contribution Access';
      default:
        return 'Additional Access';
    }
  }

  Future<String?> _showAccessReasonDialog(String accessType) async {
    return showDialog<String>(
      context: context,
      builder: (context) =>
          _AccessReasonDialog(title: 'Request ${_accessTypeLabel(accessType)}'),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isGuest = _authSession == null;
    final activeInterests = [
      _politicsInterest,
      _businessInterest,
      _techInterest,
      _sportsInterest,
      _entertainmentInterest,
    ].where((value) => value).length;
    final unreadCount = _notificationsInboxController.unreadCount;
    final pendingAccessRequests = _pendingAccessRequestCount();

    return ListView(
      padding: EdgeInsets.zero,
      children: [
        if (_isLoadingInterests ||
            _isSavingInterests ||
            _isLoadingSettings ||
            _isSavingSettings)
          const LinearProgressIndicator(minHeight: 2),
        Container(
          margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [AppTheme.primary, AppTheme.primaryContainer],
            ),
            borderRadius: BorderRadius.circular(30),
          ),
          padding: const EdgeInsets.all(22),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 30,
                    backgroundColor: Colors.white.withValues(alpha: 0.16),
                    child: Text(
                      (_authSession?.displayName.isNotEmpty == true
                              ? _authSession!.displayName.characters.first
                              : 'G')
                          .toUpperCase(),
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w900,
                          ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _authSession?.displayName.isNotEmpty == true
                              ? _authSession!.displayName
                              : 'Guest User',
                          style: Theme.of(context).textTheme.headlineSmall
                              ?.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.w900,
                                fontFamily: AppTheme.headlineFontFamily,
                              ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _authSession?.email ??
                              'Sign in to save your preferences and alerts',
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(
                                color: Colors.white.withValues(alpha: 0.84),
                              ),
                        ),
                      ],
                    ),
                  ),
                  OutlinedButton(
                    onPressed: _onManageAccountTap,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      side: BorderSide(
                        color: Colors.white.withValues(alpha: 0.42),
                      ),
                    ),
                    child: Text(_authSession == null ? 'Log in' : 'Log out'),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  _profileBadge(
                    icon: Icons.notifications_active_outlined,
                    label: unreadCount > 0 ? '$unreadCount new' : 'Inbox clear',
                  ),
                  _profileBadge(
                    icon: Icons.person_outline_rounded,
                    label: _accountTypeLabel(isGuest),
                  ),
                  _profileBadge(
                    icon: Icons.tune_rounded,
                    label: '$activeInterests interests',
                  ),
                  if (!isGuest)
                    _profileBadge(
                      icon: Icons.verified_user_outlined,
                      label: pendingAccessRequests > 0
                          ? '$pendingAccessRequests request${pendingAccessRequests == 1 ? '' : 's'} pending'
                          : 'Standard access',
                    ),
                ],
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 18, 16, 0),
          child: Row(
            children: [
              Expanded(
                child: _metricCard(
                  'Inbox',
                  unreadCount.toString(),
                  unreadCount > 0 ? 'Unread updates' : 'All caught up',
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _metricCard(
                  'Alerts',
                  [
                    _breakingAlerts,
                    _liveAlerts,
                    _commentReplies,
                  ].where((value) => value).length.toString(),
                  'Enabled signals',
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _metricCard(
                  'Account',
                  _accountTypeLabel(isGuest),
                  isGuest ? 'Signed out' : 'Signed in',
                ),
              ),
            ],
          ),
        ),
        if (isGuest)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: _guestHint(
              'Sign in to sync saved stories, alerts, and reading preferences across devices.',
            ),
          ),
        const Padding(
          padding: EdgeInsets.fromLTRB(16, 22, 16, 8),
          child: PreferencesSectionLabel(title: 'Notifications'),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: _sectionCard(
            children: [
              PreferencesToggleRow(
                title: 'Breaking News Alerts',
                subtitle: 'Get notifications on major breaking news.',
                enabled: !isGuest,
                value: _breakingAlerts,
                onChanged: (value) async {
                  final previous = _breakingAlerts;
                  setState(() => _breakingAlerts = value);
                  await _updateSettings(
                    breakingNewsAlerts: value,
                    rollback: () => _breakingAlerts = previous,
                  );
                },
              ),
              PreferencesToggleRow(
                title: 'Live Stream Alerts',
                subtitle: 'Receive alerts for upcoming live broadcasts.',
                enabled: !isGuest,
                value: _liveAlerts,
                onChanged: (value) async {
                  final previous = _liveAlerts;
                  setState(() => _liveAlerts = value);
                  await _updateSettings(
                    liveStreamAlerts: value,
                    rollback: () => _liveAlerts = previous,
                  );
                },
              ),
              PreferencesToggleRow(
                title: 'Comment Replies',
                subtitle: 'Be notified when someone replies to your comment.',
                enabled: !isGuest,
                value: _commentReplies,
                showDivider: false,
                onChanged: (value) async {
                  final previous = _commentReplies;
                  setState(() => _commentReplies = value);
                  await _updateSettings(
                    commentReplies: value,
                    rollback: () => _commentReplies = previous,
                  );
                },
              ),
            ],
          ),
        ),
        const Padding(
          padding: EdgeInsets.fromLTRB(16, 22, 16, 8),
          child: PreferencesSectionLabel(title: 'Interests'),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: _sectionCard(
            children: [
              PreferencesToggleRow(
                title: 'Politics',
                enabled: !isGuest,
                leading: _interestBadge(
                  context,
                  icon: Icons.gavel_rounded,
                  color: const Color(0xFFB74040),
                ),
                value: _politicsInterest,
                onChanged: (value) => _onInterestChanged(() {
                  _politicsInterest = value;
                }),
              ),
              PreferencesToggleRow(
                title: 'Business',
                enabled: !isGuest,
                leading: _interestBadge(
                  context,
                  icon: Icons.work_rounded,
                  color: const Color(0xFF0F74A8),
                ),
                value: _businessInterest,
                onChanged: (value) => _onInterestChanged(() {
                  _businessInterest = value;
                }),
              ),
              PreferencesToggleRow(
                title: 'Tech',
                enabled: !isGuest,
                leading: _interestBadge(
                  context,
                  icon: Icons.memory_rounded,
                  color: const Color(0xFF118978),
                ),
                value: _techInterest,
                onChanged: (value) => _onInterestChanged(() {
                  _techInterest = value;
                }),
              ),
              PreferencesToggleRow(
                title: 'Sports',
                enabled: !isGuest,
                leading: _interestBadge(
                  context,
                  icon: Icons.sports_soccer_rounded,
                  color: const Color(0xFFD88C2F),
                ),
                value: _sportsInterest,
                activeTrackColor: const Color(0xFFD88C2F),
                onChanged: (value) => _onInterestChanged(() {
                  _sportsInterest = value;
                }),
              ),
              PreferencesToggleRow(
                title: 'Entertainment',
                enabled: !isGuest,
                leading: _interestBadge(
                  context,
                  icon: Icons.movie_rounded,
                  color: const Color(0xFF6B4FB2),
                ),
                value: _entertainmentInterest,
                showDivider: false,
                onChanged: (value) => _onInterestChanged(() {
                  _entertainmentInterest = value;
                }),
              ),
            ],
          ),
        ),
        const Padding(
          padding: EdgeInsets.fromLTRB(16, 22, 16, 8),
          child: PreferencesSectionLabel(title: 'Appearance'),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: _sectionCard(
            children: [
              PreferencesNavigationRow(
                title: 'Theme',
                valueLabel: _themeLabel(_themeKey),
                onTap: _onThemeTap,
              ),
              PreferencesNavigationRow(
                title: 'Text Size',
                valueLabel: _textSizeLabel(_textSizeKey),
                showDivider: false,
                onTap: _onTextSizeTap,
              ),
            ],
          ),
        ),
        const Padding(
          padding: EdgeInsets.fromLTRB(16, 22, 16, 8),
          child: PreferencesSectionLabel(title: 'Account'),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: _sectionCard(
            children: [
              PreferencesNavigationRow(
                title: 'Notifications Inbox',
                valueLabel: _authSession == null
                    ? null
                    : unreadCount > 0
                    ? '$unreadCount new'
                    : 'Up to date',
                onTap: () => context.push(AppRouter.alertsPath),
              ),
              if ((_authSession?.canManageEditorialContent ?? false) &&
                  AppRuntime.supportsAdminRoutes)
                PreferencesNavigationRow(
                  title: 'Editorial Desk',
                  valueLabel: 'Review queue',
                  onTap: () => context.push(AppRouter.adminDashboardPath),
                ),
              PreferencesNavigationRow(
                title: 'Saved Stories',
                valueLabel: 'Shelf',
                onTap: () => context.go(AppRouter.savedPath),
              ),
              PreferencesNavigationRow(
                title: 'Request More Access',
                valueLabel: isGuest
                    ? 'Sign in required'
                    : pendingAccessRequests > 0
                    ? '$pendingAccessRequests pending'
                    : 'Ask admins',
                showDivider: false,
                onTap: _onRequestAccessTap,
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _sectionCard({required List<Widget> children}) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppTheme.divider.withValues(alpha: 0.55)),
      ),
      child: Column(children: children),
    );
  }

  Widget _metricCard(String label, String value, String meta) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppTheme.divider.withValues(alpha: 0.6)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: AppTheme.textMeta),
          ),
          const SizedBox(height: 10),
          Text(
            value,
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 4),
          Text(
            meta,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: AppTheme.textSecondary),
          ),
        ],
      ),
    );
  }

  Widget _guestHint(String message) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        message,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
          color: Theme.of(
            context,
          ).colorScheme.onSurface.withValues(alpha: 0.72),
        ),
      ),
    );
  }

  Widget _interestBadge(
    BuildContext context, {
    required IconData icon,
    required Color color,
  }) {
    return Container(
      height: 24,
      width: 24,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(5),
      ),
      alignment: Alignment.center,
      child: Icon(icon, size: 15, color: color),
    );
  }

  Widget _profileBadge({required IconData icon, required String label}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: Colors.white),
          const SizedBox(width: 8),
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _onManageAccountTap() async {
    if (_authSession == null) {
      await context.push(AppRouter.loginPath);
      await _loadAuthSession();
      return;
    }

    await InjectionContainer.sl<LogoutUser>()();
    if (!mounted) {
      return;
    }

    setState(() => _authSession = null);
    _resetSettingsForGuest();
    context.read<NewsBloc>().add(const LoadNewsRequested());
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Logged out successfully.')));
  }
}

class _OptionItem {
  const _OptionItem({required this.value, required this.label});

  final String value;
  final String label;
}

class _AccessReasonDialog extends StatefulWidget {
  const _AccessReasonDialog({required this.title});

  final String title;

  @override
  State<_AccessReasonDialog> createState() => _AccessReasonDialogState();
}

class _AccessReasonDialogState extends State<_AccessReasonDialog> {
  final TextEditingController _controller = TextEditingController();
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: Form(
        key: _formKey,
        child: TextFormField(
          controller: _controller,
          maxLines: 4,
          minLines: 3,
          decoration: const InputDecoration(
            labelText: 'Reason',
            hintText: 'Tell the admins what you need this access for.',
          ),
          validator: (value) {
            if ((value ?? '').trim().length < 7) {
              return 'Please add a brief reason.';
            }
            return null;
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () {
            if (_formKey.currentState?.validate() != true) {
              return;
            }
            Navigator.of(context).pop(_controller.text.trim());
          },
          child: const Text('Send request'),
        ),
      ],
    );
  }
}
