import 'package:naijapulse/features/auth/domain/entities/auth_session.dart';

class AuthSessionModel extends AuthSession {
  const AuthSessionModel({
    required super.userId,
    required super.email,
    required super.displayName,
    required super.role,
    required super.canAccessStreamsEntitlement,
    required super.canHostStreamsEntitlement,
    required super.canContributeStoriesEntitlement,
    required super.accessToken,
    required super.tokenType,
    required super.expiresInSeconds,
  });

  factory AuthSessionModel.fromJson(Map<String, dynamic> json) {
    final user = json['user'];
    if (user is! Map<String, dynamic>) {
      throw const FormatException('Missing user payload in auth response.');
    }

    return AuthSessionModel(
      userId: (user['id'] ?? '').toString(),
      email: (user['email'] ?? '').toString(),
      displayName: (user['display_name'] ?? user['displayName'] ?? '')
          .toString(),
      role: (user['role'] ?? 'user').toString(),
      canAccessStreamsEntitlement:
          (user['entitlements'] as Map<String, dynamic>?)?['can_access_streams']
              as bool?,
      canHostStreamsEntitlement:
          (user['entitlements'] as Map<String, dynamic>?)?['can_host_streams']
              as bool?,
      canContributeStoriesEntitlement:
          (user['entitlements']
                  as Map<String, dynamic>?)?['can_contribute_stories']
              as bool?,
      accessToken: (json['access_token'] ?? json['accessToken'] ?? '')
          .toString(),
      tokenType: (json['token_type'] ?? json['tokenType'] ?? 'bearer')
          .toString(),
      expiresInSeconds:
          ((json['expires_in_seconds'] ?? json['expiresInSeconds'] ?? 0) as num)
              .toInt(),
    );
  }

  factory AuthSessionModel.fromEntity(AuthSession entity) {
    return AuthSessionModel(
      userId: entity.userId,
      email: entity.email,
      displayName: entity.displayName,
      role: entity.role,
      canAccessStreamsEntitlement: entity.canAccessStreamsEntitlement,
      canHostStreamsEntitlement: entity.canHostStreamsEntitlement,
      canContributeStoriesEntitlement: entity.canContributeStoriesEntitlement,
      accessToken: entity.accessToken,
      tokenType: entity.tokenType,
      expiresInSeconds: entity.expiresInSeconds,
    );
  }

  Map<String, dynamic> toCacheJson() {
    return {
      'user_id': userId,
      'email': email,
      'display_name': displayName,
      'role': role,
      'can_access_streams': canAccessStreamsEntitlement,
      'can_host_streams': canHostStreamsEntitlement,
      'can_contribute_stories': canContributeStoriesEntitlement,
      'access_token': accessToken,
      'token_type': tokenType,
      'expires_in_seconds': expiresInSeconds,
    };
  }

  factory AuthSessionModel.fromCacheJson(Map<String, dynamic> json) {
    return AuthSessionModel(
      userId: (json['user_id'] ?? '').toString(),
      email: (json['email'] ?? '').toString(),
      displayName: (json['display_name'] ?? '').toString(),
      role: (json['role'] ?? 'user').toString(),
      canAccessStreamsEntitlement: json['can_access_streams'] as bool?,
      canHostStreamsEntitlement: json['can_host_streams'] as bool?,
      canContributeStoriesEntitlement: json['can_contribute_stories'] as bool?,
      accessToken: (json['access_token'] ?? '').toString(),
      tokenType: (json['token_type'] ?? 'bearer').toString(),
      expiresInSeconds: ((json['expires_in_seconds'] ?? 0) as num).toInt(),
    );
  }
}
