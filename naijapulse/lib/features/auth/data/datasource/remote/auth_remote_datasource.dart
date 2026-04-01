import 'package:naijapulse/core/error/exceptions.dart';
import 'package:naijapulse/core/network/api_client.dart';
import 'package:naijapulse/features/auth/data/models/auth_session_model.dart';

abstract class AuthRemoteDataSource {
  Future<AuthSessionModel> login({
    required String email,
    required String password,
  });

  Future<AuthSessionModel> register({
    required String email,
    required String password,
    String? displayName,
  });

  Future<Map<String, dynamic>> requestPasswordReset({
    required String email,
    String? resetPath,
  });

  Future<Map<String, dynamic>> requestAdminAccess({
    required String fullName,
    required String workEmail,
    required String requestedRole,
    String? bureau,
    required String reason,
  });

  Future<void> resetPassword({required String token, required String password});
}

class AuthRemoteDataSourceImpl implements AuthRemoteDataSource {
  const AuthRemoteDataSourceImpl({required ApiClient apiClient})
    : _apiClient = apiClient;

  final ApiClient _apiClient;

  @override
  Future<AuthSessionModel> login({
    required String email,
    required String password,
  }) async {
    try {
      final response = await _apiClient.post(
        '/auth/login',
        data: {'email': email.trim(), 'password': password},
      );
      return AuthSessionModel.fromJson(response);
    } on AppException {
      rethrow;
    } catch (error) {
      throw ParseException('Could not parse login response: $error');
    }
  }

  @override
  Future<AuthSessionModel> register({
    required String email,
    required String password,
    String? displayName,
  }) async {
    try {
      final response = await _apiClient.post(
        '/auth/register',
        data: {
          'email': email.trim(),
          'password': password,
          if (displayName != null && displayName.trim().isNotEmpty)
            'display_name': displayName.trim(),
        },
      );
      return AuthSessionModel.fromJson(response);
    } on AppException {
      rethrow;
    } catch (error) {
      throw ParseException('Could not parse registration response: $error');
    }
  }

  @override
  Future<Map<String, dynamic>> requestPasswordReset({
    required String email,
    String? resetPath,
  }) async {
    try {
      return await _apiClient.post(
        '/auth/forgot-password',
        data: {
          'email': email.trim(),
          if (resetPath != null && resetPath.trim().isNotEmpty)
            'reset_path': resetPath.trim(),
        },
      );
    } on AppException {
      rethrow;
    } catch (error) {
      throw ParseException('Could not parse password reset response: $error');
    }
  }

  @override
  Future<Map<String, dynamic>> requestAdminAccess({
    required String fullName,
    required String workEmail,
    required String requestedRole,
    String? bureau,
    required String reason,
  }) async {
    try {
      return await _apiClient.post(
        '/auth/admin-request-access',
        data: {
          'full_name': fullName.trim(),
          'work_email': workEmail.trim(),
          'requested_role': requestedRole.trim(),
          if (bureau != null && bureau.trim().isNotEmpty)
            'bureau': bureau.trim(),
          'reason': reason.trim(),
        },
      );
    } on AppException {
      rethrow;
    } catch (error) {
      throw ParseException(
        'Could not parse admin access request response: $error',
      );
    }
  }

  @override
  Future<void> resetPassword({
    required String token,
    required String password,
  }) async {
    try {
      await _apiClient.post(
        '/auth/reset-password',
        data: {'token': token.trim(), 'password': password},
      );
    } on AppException {
      rethrow;
    } catch (error) {
      throw ParseException('Could not parse password update response: $error');
    }
  }
}
