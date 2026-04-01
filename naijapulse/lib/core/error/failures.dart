import 'package:equatable/equatable.dart';
import 'package:naijapulse/core/error/exceptions.dart';

abstract class Failure extends Equatable {
  final String message;

  const Failure(this.message);

  @override
  List<Object?> get props => [message];
}

class NetworkFailure extends Failure {
  const NetworkFailure(super.message);
}

class TimeoutFailure extends Failure {
  const TimeoutFailure(super.message);
}

class ServerFailure extends Failure {
  final int? statusCode;

  const ServerFailure(super.message, {this.statusCode});

  @override
  List<Object?> get props => [message, statusCode];
}

class ParseFailure extends Failure {
  const ParseFailure(super.message);
}

class CacheFailure extends Failure {
  const CacheFailure(super.message);
}

class UnexpectedFailure extends Failure {
  const UnexpectedFailure(super.message);
}

Failure mapFailure(Object error) {
  if (error is NetworkException) {
    return NetworkFailure(error.message);
  }
  if (error is RequestTimeoutException) {
    return TimeoutFailure(error.message);
  }
  if (error is ServerException) {
    return ServerFailure(error.message, statusCode: error.statusCode);
  }
  if (error is ParseException) {
    return ParseFailure(error.message);
  }
  if (error is CacheException) {
    return CacheFailure(error.message);
  }
  if (error is AppException) {
    return UnexpectedFailure(error.message);
  }
  return const UnexpectedFailure('An unexpected error occurred.');
}
