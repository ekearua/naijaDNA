import 'package:equatable/equatable.dart';

class AuthSession extends Equatable {
  const AuthSession({
    required this.userId,
    required this.email,
    required this.displayName,
    required this.role,
    required this.canAccessStreamsEntitlement,
    required this.canHostStreamsEntitlement,
    required this.canContributeStoriesEntitlement,
    required this.accessToken,
    required this.tokenType,
    required this.expiresInSeconds,
  });

  final String userId;
  final String email;
  final String displayName;
  final String role;
  final bool? canAccessStreamsEntitlement;
  final bool? canHostStreamsEntitlement;
  final bool? canContributeStoriesEntitlement;
  final String accessToken;
  final String tokenType;
  final int expiresInSeconds;

  String get normalizedRole => role.trim().toLowerCase();

  bool get isAdmin => normalizedRole == 'admin';
  bool get isEditor => normalizedRole == 'editor';
  bool get isContributor => normalizedRole == 'contributor';
  bool get isModerator => normalizedRole == 'moderator';
  bool get canManageEditorialContent => isAdmin || isEditor;
  bool get canModerateDiscussions =>
      isModerator || isAdmin || isEditor;
  bool get canManageAdminUsers => isAdmin;
  bool get canManageSources => isAdmin;
  bool get canAccessStreams =>
      canAccessStreamsEntitlement ??
      (isContributor || canManageEditorialContent);
  bool get canHostStreams =>
      canHostStreamsEntitlement ?? (isContributor || canManageEditorialContent);
  bool get canContributeStories =>
      canContributeStoriesEntitlement ??
      (isContributor || canManageEditorialContent);

  @override
  List<Object?> get props => [
    userId,
    email,
    displayName,
    role,
    canAccessStreamsEntitlement,
    canHostStreamsEntitlement,
    canContributeStoriesEntitlement,
    accessToken,
    tokenType,
    expiresInSeconds,
  ];
}
