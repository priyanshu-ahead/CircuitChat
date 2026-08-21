/// Typed network exception model — mirrors NetworkExceptions pattern from RN.
sealed class NetworkException implements Exception {
  const NetworkException(this.message);
  final String message;

  @override
  String toString() => message;
}

/// HTTP 4xx client errors.
class ClientException extends NetworkException {
  const ClientException(super.message, {required this.statusCode});
  final int statusCode;
}

/// HTTP 401 — token expired / unauthorised.
class UnauthorisedException extends NetworkException {
  const UnauthorisedException([super.message = 'Unauthorised. Please log in again.']);
}

/// HTTP 403 — forbidden.
class ForbiddenException extends NetworkException {
  const ForbiddenException([super.message = 'You do not have permission to do this.']);
}

/// HTTP 404 — resource not found.
class NotFoundException extends NetworkException {
  const NotFoundException([super.message = 'Resource not found.']);
}

/// HTTP 422 — validation errors from the server.
class ValidationException extends NetworkException {
  const ValidationException(super.message, {this.errors = const {}});
  final Map<String, List<String>> errors;
}

/// HTTP 5xx server errors.
class ServerException extends NetworkException {
  const ServerException([super.message = 'Server error. Please try again later.']);
}

/// No internet / socket timeout.
class NoInternetException extends NetworkException {
  const NoInternetException([super.message = 'No internet connection.']);
}

/// Any other / unknown error.
class UnknownException extends NetworkException {
  const UnknownException([super.message = 'Something went wrong. Please try again.']);
}
