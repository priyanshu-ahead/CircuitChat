import 'dart:convert';
import 'dart:developer' as dev;

import 'package:dio/dio.dart';

import '../storage/secure_storage.dart';
import 'network_exceptions.dart';

/// Log tag for HTTP network calls. In Android Studio Logcat, combine with the
/// auth tag by using the regex: `CircuitChat(AUTH|HTTP)`
const String kHttpLogTag = 'CircuitChatHTTP';

void _httpLog(String message, {Object? error, StackTrace? stackTrace}) {
  dev.log(
    message,
    name: kHttpLogTag,
    error: error,
    stackTrace: stackTrace,
  );
}

String _obfuscateBody(dynamic data) {
  if (data == null) return '(null)';
  try {
    String json;
    if (data is Map || data is List) {
      json = jsonEncode(data);
    } else {
      json = data.toString();
    }
    // Strip password / tokens from log output
    json = json.replaceAllMapped(
      RegExp(r'"(password|confirmPassword|current_password|refresh_token|access_token|token)"\s*:\s*"[^"]*"',
          caseSensitive: false),
      (m) => '"${m.group(1)}":"***"',
    );
    // Cap long payloads
    const max = 1200;
    return json.length > max ? '${json.substring(0, max)}…' : json;
  } catch (_) {
    return '(unserializable: ${data.runtimeType})';
  }
}

/// Dio wrapper with auth-token injection, token refresh, and error mapping.
class ApiClient {
  ApiClient(this._dio, this._secureStorage) {
    _addInterceptors();
  }

  final Dio _dio;
  final SecureStorage _secureStorage;

  void _addInterceptors() {
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          final token = await _secureStorage.getAuthToken();
          final hasToken = token != null && token.isNotEmpty;
          if (hasToken) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          final method = options.method.toUpperCase();
          _httpLog(
            '➡️  [$method] ${options.uri}  '
            'auth=${hasToken ? 'bearer' : 'none'}  '
            'data=${_obfuscateBody(options.data)}  '
            'query=${options.queryParameters}',
          );
          handler.next(options);
        },
        onResponse: (response, handler) {
          final options = response.requestOptions;
          _httpLog(
            '⬅️  [${response.statusCode}] ${options.method.toUpperCase()} ${options.uri}  '
            'body=${_obfuscateBody(response.data)}',
          );
          handler.next(response);
        },
        onError: (error, handler) async {
          final options = error.requestOptions;
          final method = options.method.toUpperCase();
          final status = error.response?.statusCode ?? '-';
          final body = _obfuscateBody(error.response?.data);
          _httpLog(
            '⚠️  [HTTP ERROR $status] $method ${options.uri}  '
            'type=${error.type.name}  '
            'message="${error.message ?? ''}"  '
            'body=$body',
            error: error.error ?? error,
            stackTrace: error.stackTrace,
          );
          if (error.response?.statusCode == 401) {
            // Attempt token refresh
            final refreshed = await _tryRefreshToken();
            if (refreshed) {
              // Retry the original request with new token
              final token = await _secureStorage.getAuthToken();
              error.requestOptions.headers['Authorization'] = 'Bearer $token';
              _httpLog(
                '🔄  [TOKEN REFRESHED] retrying $method ${options.uri}',
              );
              final retryResponse = await _dio.fetch(error.requestOptions);
              handler.resolve(retryResponse);
              return;
            } else {
              _httpLog(
                '🚫  [REFRESH FAILED] returning 401 to caller',
              );
            }
          }
          handler.next(error);
        },
      ),
    );
  }

  Future<bool> _tryRefreshToken() async {
    try {
      final refreshToken = await _secureStorage.getRefreshToken();
      if (refreshToken == null) return false;
      final response = await _dio.post(
        '/auth/refresh',
        data: {'refresh_token': refreshToken},
      );
      final newToken = response.data['access_token'] as String?;
      if (newToken != null) {
        await _secureStorage.saveAuthToken(newToken);
        return true;
      }
      return false;
    } catch (_) {
      return false;
    }
  }

  // ── Public HTTP methods ──────────────────────────────────────────────────

  Future<T> get<T>(
    String path, {
    Map<String, dynamic>? queryParameters,
    T Function(dynamic)? fromJson,
  }) async {
    final response = await _safeRequest(
      () => _dio.get(path, queryParameters: queryParameters),
    );
    return fromJson != null ? fromJson(response.data) : response.data as T;
  }

  Future<T> post<T>(
    String path, {
    dynamic data,
    T Function(dynamic)? fromJson,
  }) async {
    final response = await _safeRequest(() => _dio.post(path, data: data));
    return fromJson != null ? fromJson(response.data) : response.data as T;
  }

  Future<T> put<T>(
    String path, {
    dynamic data,
    T Function(dynamic)? fromJson,
  }) async {
    final response = await _safeRequest(() => _dio.put(path, data: data));
    return fromJson != null ? fromJson(response.data) : response.data as T;
  }

  Future<T> patch<T>(
    String path, {
    dynamic data,
    T Function(dynamic)? fromJson,
  }) async {
    final response = await _safeRequest(() => _dio.patch(path, data: data));
    return fromJson != null ? fromJson(response.data) : response.data as T;
  }

  Future<T> delete<T>(
    String path, {
    dynamic data,
    T Function(dynamic)? fromJson,
  }) async {
    final response = await _safeRequest(() => _dio.delete(path, data: data));
    return fromJson != null ? fromJson(response.data) : response.data as T;
  }

  Future<T> uploadFile<T>(
    String path,
    FormData formData, {
    T Function(dynamic)? fromJson,
    void Function(int, int)? onSendProgress,
  }) async {
    final response = await _safeRequest(
      () => _dio.post(path, data: formData, onSendProgress: onSendProgress),
    );
    return fromJson != null ? fromJson(response.data) : response.data as T;
  }

  // ── Error mapping ────────────────────────────────────────────────────────

  Future<Response> _safeRequest(Future<Response> Function() request) async {
    try {
      return await request();
    } on DioException catch (e) {
      throw _mapDioError(e);
    } catch (e) {
      throw UnknownException(e.toString());
    }
  }

  NetworkException _mapDioError(DioException e) {
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.receiveTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.connectionError:
        return const NoInternetException();
      case DioExceptionType.badResponse:
        final statusCode = e.response?.statusCode ?? 0;
        final message =
            (e.response?.data is Map ? e.response!.data['message'] : null) ??
            e.message ??
            'Error $statusCode';
        return switch (statusCode) {
          401 => const UnauthorisedException(),
          403 => const ForbiddenException(),
          404 => const NotFoundException(),
          422 => ValidationException(message),
          >= 500 => const ServerException(),
          _ => ClientException(message, statusCode: statusCode),
        };
      default:
        return UnknownException(e.message ?? 'Unknown error');
    }
  }
}
