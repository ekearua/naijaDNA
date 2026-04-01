import 'dart:io';

import 'package:dio/dio.dart';
import 'package:naijapulse/core/error/exceptions.dart';

/// Thin HTTP wrapper that converts Dio errors into app-level exceptions.
class ApiClient {
  final Dio _dio;

  const ApiClient({required Dio dio}) : _dio = dio;

  Future<Map<String, dynamic>> get(
    String path, {
    Map<String, dynamic>? queryParameters,
    Map<String, String>? headers,
  }) async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        path,
        queryParameters: queryParameters,
        options: headers == null ? null : Options(headers: headers),
      );
      final body = response.data;
      if (body == null) {
        throw const ParseException('Response body is empty.');
      }
      return body;
    } on DioException catch (error) {
      // Keep Dio specifics in one place and expose consistent domain-facing errors.
      throw _mapDioError(error);
    }
  }

  Future<Map<String, dynamic>> post(
    String path, {
    Map<String, dynamic>? data,
    Map<String, dynamic>? queryParameters,
    Map<String, String>? headers,
  }) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        path,
        data: data,
        queryParameters: queryParameters,
        options: headers == null ? null : Options(headers: headers),
      );
      final body = response.data;
      if (body == null) {
        throw const ParseException('Response body is empty.');
      }
      return body;
    } on DioException catch (error) {
      throw _mapDioError(error);
    }
  }

  Future<Map<String, dynamic>> patch(
    String path, {
    Map<String, dynamic>? data,
    Map<String, dynamic>? queryParameters,
    Map<String, String>? headers,
  }) async {
    try {
      final response = await _dio.patch<Map<String, dynamic>>(
        path,
        data: data,
        queryParameters: queryParameters,
        options: headers == null ? null : Options(headers: headers),
      );
      final body = response.data;
      if (body == null) {
        throw const ParseException('Response body is empty.');
      }
      return body;
    } on DioException catch (error) {
      throw _mapDioError(error);
    }
  }

  AppException _mapDioError(DioException error) {
    final requestUri = error.requestOptions.uri.toString();
    // Each transport failure maps to a stable exception used by repositories/blocs.
    switch (error.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return RequestTimeoutException(
          'Request timed out for $requestUri. Check API URL/connectivity and try again.',
        );
      case DioExceptionType.badResponse:
        final statusCode = error.response?.statusCode;
        final detail = _extractErrorDetail(error.response?.data);
        return ServerException(
          detail ??
              'Server error ${statusCode ?? ''}'.trim().replaceAll(
                RegExp(r'\s+'),
                ' ',
              ),
          statusCode: statusCode,
        );
      case DioExceptionType.cancel:
        return const UnknownException('Request was cancelled.');
      case DioExceptionType.connectionError:
        return NetworkException(
          'Connection error for $requestUri. Verify API URL and network access.',
        );
      case DioExceptionType.badCertificate:
        return const NetworkException('Could not verify secure connection.');
      case DioExceptionType.unknown:
        final rawError = error.error;
        if (rawError is SocketException) {
          return NetworkException(
            'Unable to reach $requestUri. Check network or API URL.',
          );
        }
        return UnknownException(
          rawError?.toString() ?? 'Unexpected network error.',
        );
    }
  }

  String? _extractErrorDetail(dynamic data) {
    if (data is Map<String, dynamic>) {
      final detail = data['detail'];
      if (detail is String && detail.trim().isNotEmpty) {
        return detail.trim();
      }
      final message = data['message'];
      if (message is String && message.trim().isNotEmpty) {
        return message.trim();
      }
    }
    return null;
  }
}
