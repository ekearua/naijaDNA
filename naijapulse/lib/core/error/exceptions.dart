class AppException implements Exception {
  final String message;
  final int? statusCode;

  const AppException(this.message, {this.statusCode});

  @override
  String toString() =>
      'AppException(message: $message, statusCode: $statusCode)';
}

class NetworkException extends AppException {
  const NetworkException(super.message);
}

class RequestTimeoutException extends AppException {
  const RequestTimeoutException(super.message);
}

class ServerException extends AppException {
  const ServerException(super.message, {super.statusCode});
}

class ParseException extends AppException {
  const ParseException(super.message);
}

class CacheException extends AppException {
  const CacheException(super.message);
}

class UnknownException extends AppException {
  const UnknownException(super.message);
}
