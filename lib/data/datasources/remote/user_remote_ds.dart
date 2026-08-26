import 'package:dio/dio.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/api_endpoints.dart';
import '../../../core/network/network_exceptions.dart';
import '../../models/user_model.dart';
import '../../repositories/auth_repository.dart';
import '../../repositories/user_repository.dart';

/// Remote data source — calls the SocialEngine REST API for user-profile
/// and miscellaneous user operations. Mirrors the non-auth functions from the
/// React-Native `auth.js` module (report, translation, about, editProfile…).
class UserRemoteDataSource implements UserRepository {
  const UserRemoteDataSource(this._api);

  final ApiClient _api;

  // ── Helpers ───────────────────────────────────────────────────────────────

  static String? _messageFromError(Object e) {
    if (e is NetworkException) return e.message;
    return e.toString().replaceFirst('Exception: ', '');
  }

  /// Build a [FormData] from a flat map, converting any `XFile` / path strings
  /// whose key matches common file-upload names (photo, cover, file, avatar)
  /// into [MultipartFile] entries. Used by [editProfile].
  static Future<FormData> _toFormData(Map<String, dynamic> data) async {
    final form = <String, dynamic>{};
    for (final entry in data.entries) {
      final key = entry.key;
      final value = entry.value;
      if (value == null) continue;
      final isFileKey = const {'photo', 'cover', 'file', 'avatar', 'image'}
          .any((k) => key.toLowerCase().contains(k));
      if (isFileKey && value is String) {
        form[key] = await MultipartFile.fromFile(value);
      } else {
        form[key] = value;
      }
    }
    return FormData.fromMap(form);
  }

  // ── Profile ───────────────────────────────────────────────────────────────

  @override
  Future<UserModel> getUserById(String userId) async {
    final data = await _api.get<Map<String, dynamic>>(
      ApiEndpoints.page(userId), // Reuse `/user/page/$id` helper, or override
    );
    final userJson = data['user'] is Map<String, dynamic>
        ? data['user'] as Map<String, dynamic>
        : data;
    return UserModel.fromJson(userJson);
  }

  @override
  Future<ApiResult<UserModel>> editProfile(Map<String, dynamic> data) async {
    try {
      final formData = await _toFormData(data);
      final response = await _api.uploadFile<Map<String, dynamic>>(
        ApiEndpoints.editProfile,
        formData,
      );
      final userJson = response['user'] is Map<String, dynamic>
          ? response['user'] as Map<String, dynamic>
          : response;
      return ApiResult.success(UserModel.fromJson(userJson));
    } catch (e) {
      return ApiResult.failure(
        _messageFromError(e) ?? 'Failed to update profile.',
      );
    }
  }

  @override
  Future<ApiResult<void>> deleteAccount(Map<String, dynamic> data) async {
    try {
      await _api.delete<void>(ApiEndpoints.deleteAccount, data: data);
      return ApiResult.success();
    } catch (e) {
      return ApiResult.failure(
        _messageFromError(e) ?? 'Failed to delete account.',
      );
    }
  }

  @override
  Future<UserModel> updateProfile({
    String? displayName,
    String? bio,
    String? phone,
  }) async {
    final patch = <String, dynamic>{
      if (displayName != null) 'display_name': displayName,
      if (bio != null) 'bio': bio,
      if (phone != null) 'phone': phone,
    };
    final data = await _api.patch<Map<String, dynamic>>(
      ApiEndpoints.editProfile,
      data: patch,
    );
    final userJson = data['user'] is Map<String, dynamic>
        ? data['user'] as Map<String, dynamic>
        : data;
    return UserModel.fromJson(userJson);
  }

  @override
  Future<String> uploadAvatar(String localPath) async {
    final formData = FormData.fromMap({
      'photo': await MultipartFile.fromFile(localPath),
    });
    final data = await _api.uploadFile<Map<String, dynamic>>(
      ApiEndpoints.editProfile,
      formData,
    );
    return (data['avatar_url'] ?? data['photo_url'] ?? '') as String;
  }

  // ── About ─────────────────────────────────────────────────────────────────

  @override
  Future<ApiResult<Map<String, dynamic>>> about() async {
    try {
      final data = await _api.get<Map<String, dynamic>>(ApiEndpoints.about);
      return ApiResult.success(data);
    } catch (e) {
      return ApiResult.failure(
        _messageFromError(e) ?? 'Failed to load about info.',
      );
    }
  }

  @override
  Future<ApiResult<Map<String, dynamic>>> updateAbout(
    Map<String, dynamic> data,
  ) async {
    try {
      final response = await _api.post<Map<String, dynamic>>(
        ApiEndpoints.about,
        data: data,
      );
      return ApiResult.success(response);
    } catch (e) {
      return ApiResult.failure(
        _messageFromError(e) ?? 'Failed to update about info.',
      );
    }
  }

  @override
  Future<ApiResult<Map<String, dynamic>>> deleteAbout(
    Map<String, dynamic> data,
  ) async {
    try {
      final response = await _api.delete<Map<String, dynamic>>(
        ApiEndpoints.about,
        data: data,
      );
      return ApiResult.success(response);
    } catch (e) {
      return ApiResult.failure(
        _messageFromError(e) ?? 'Failed to delete about info.',
      );
    }
  }

  // ── Misc ──────────────────────────────────────────────────────────────────

  @override
  Future<ApiResult<void>> report(Map<String, dynamic> data) async {
    try {
      await _api.post<void>(ApiEndpoints.report, data: data);
      return ApiResult.success();
    } catch (e) {
      return ApiResult.failure(_messageFromError(e) ?? 'Failed to submit report.');
    }
  }

  @override
  Future<ApiResult<Map<String, dynamic>>> getPermission() async {
    try {
      final data = await _api.get<Map<String, dynamic>>(ApiEndpoints.permissions);
      return ApiResult.success(data);
    } catch (e) {
      return ApiResult.failure(
        _messageFromError(e) ?? 'Failed to load permissions.',
      );
    }
  }

  @override
  Future<ApiResult<Map<String, dynamic>>> getGeneralSetting(String key) async {
    try {
      final data = await _api.get<Map<String, dynamic>>(
        ApiEndpoints.generalSettingsByKey(key),
      );
      return ApiResult.success(data);
    } catch (e) {
      return ApiResult.failure(
        _messageFromError(e) ?? 'Failed to load setting.',
      );
    }
  }

  @override
  Future<ApiResult<Map<String, dynamic>>> getTranslations() async {
    try {
      final data = await _api.get<Map<String, dynamic>>(ApiEndpoints.translation);
      return ApiResult.success(data);
    } catch (e) {
      return ApiResult.failure(
        _messageFromError(e) ?? 'Failed to load translations.',
      );
    }
  }

  @override
  Future<ApiResult<List<dynamic>>> getLanguages() async {
    try {
      final data = await _api.get<List<dynamic>>(ApiEndpoints.languages);
      return ApiResult.success(data);
    } catch (e) {
      return ApiResult.failure(
        _messageFromError(e) ?? 'Failed to load languages.',
      );
    }
  }

  @override
  Future<ApiResult<void>> changeLanguage(Map<String, dynamic> data) async {
    try {
      await _api.put<void>(ApiEndpoints.changeLanguage, data: data);
      return ApiResult.success();
    } catch (e) {
      return ApiResult.failure(
        _messageFromError(e) ?? 'Failed to change language.',
      );
    }
  }

  @override
  Future<ApiResult<Map<String, dynamic>>> pageInformation(String page) async {
    try {
      final data = await _api.get<Map<String, dynamic>>(ApiEndpoints.page(page));
      return ApiResult.success(data);
    } catch (e) {
      return ApiResult.failure(
        _messageFromError(e) ?? 'Failed to load page info.',
      );
    }
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  @override
  Future<List<UserModel>> searchUsers(String query) async {
    final data = await _api.get<List<dynamic>>(
      '/users/search',
      queryParameters: {'q': query},
    );
    return data
        .map((e) => UserModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<void> blockUser(String userId) =>
      _api.post<void>('/users/$userId/block');

  @override
  Future<void> unblockUser(String userId) =>
      _api.delete<void>('/users/$userId/block');

  @override
  Future<List<UserModel>> fetchActiveFriends() async {
    final raw = await _api.get<dynamic>(ApiEndpoints.friendActive);
    List list = const [];
    if (raw is List) {
      list = raw;
    } else if (raw is Map) {
      if (raw['data'] is List) {
        list = raw['data'] as List;
      } else if (raw['users'] is List) {
        list = raw['users'] as List;
      }
    }
    return list
        .whereType<Map>()
        .map((e) => UserModel.fromJson(Map<String, dynamic>.from(e)))
        .map((u) => u.copyWith(
              active: true,
              isOnline: true,
              state: u.state == 0 ? 1 : u.state,
            ))
        .where((u) => u.id.isNotEmpty)
        .toList();
  }
}
