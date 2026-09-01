import 'dart:developer' as dev;

import 'package:dio/dio.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/api_endpoints.dart';
import '../../models/chat_model.dart';
import '../../models/group_model.dart';
import '../../models/user_model.dart';
import '../../repositories/auth_repository.dart';
import '../../repositories/chat_repository.dart';
import '../../repositories/group_repository.dart';

/// Remote data source for all Group operations.
/// Implements [GroupRepository] — mirrors RN's services/group.js exactly.
class GroupRemoteDataSource implements GroupRepository {
  const GroupRemoteDataSource(this._api);
  final ApiClient _api;

  // ── Helpers ───────────────────────────────────────────────────────────────

  ApiResult<T> _success<T>(T data) => ApiResult.success(data);
  ApiResult<T> _failure<T>(Object e) {
    final msg = e is Exception ? e.toString() : e.toString();
    return ApiResult.failure(msg);
  }

  // ── Group info ─────────────────────────────────────────────────────────────

  @override
  Future<ApiResult<GroupModel>> getGroupInfo(String groupId) async {
    try {
      final raw = await _api.get<dynamic>(
        ApiEndpoints.groupById(groupId),
      );
      dev.log(
        'getGroupInfo raw type=${raw.runtimeType} '
        'keys=${raw is Map ? (raw as Map).keys.toList() : "not a map"}',
        name: 'GroupDS',
      );
      final Map<String, dynamic> data;
      if (raw is Map<String, dynamic>) {
        data = raw;
      } else {
        return _failure('Unexpected response type: ${raw.runtimeType}');
      }
      final group = GroupModel.fromJson(data);
      dev.log(
        'getGroupInfo parsed: id=${group.id} name=${group.name} '
        'memberCount=${group.memberCount} embeddedMembers=${group.members.length}',
        name: 'GroupDS',
      );
      return _success(group);
    } catch (e) {
      dev.log('getGroupInfo error: $e', name: 'GroupDS');
      return _failure(e);
    }
  }

  @override
  Future<ApiResult<GroupModel>> createGroup(Map<String, dynamic> data) async {
    try {
      final formData = FormData.fromMap(data);
      final raw = await _api.uploadFile<Map<String, dynamic>>(
        ApiEndpoints.groupCreate,
        formData,
      );
      return _success(GroupModel.fromJson(raw['data'] ?? raw));
    } catch (e) {
      return _failure(e);
    }
  }

  @override
  Future<ApiResult<GroupModel>> updateGroup(Map<String, dynamic> data) async {
    try {
      final formData = FormData.fromMap(data);
      final raw = await _api.uploadFile<Map<String, dynamic>>(
        ApiEndpoints.groupEdit,
        formData,
      );
      return _success(GroupModel.fromJson(raw['data'] ?? raw));
    } catch (e) {
      return _failure(e);
    }
  }

  @override
  Future<ApiResult<void>> updateSetting({
    required String groupId,
    required Map<String, dynamic> settings,
  }) async {
    try {
      await _api.put<void>(ApiEndpoints.groupSetting, data: {
        'group': groupId,
        'settings': settings,
      });
      return _success(null);
    } catch (e) {
      return _failure(e);
    }
  }

  @override
  Future<ApiResult<void>> leaveGroup(String groupId) async {
    try {
      await _api.post<void>(ApiEndpoints.groupLeave,
          data: {'group': groupId});
      return _success(null);
    } catch (e) {
      return _failure(e);
    }
  }

  // ── Members ────────────────────────────────────────────────────────────────

  @override
  Future<ApiResult<List<GroupMember>>> fetchMembers(
      FetchGroupMembersParams params) async {
    try {
      final raw = await _api.get<dynamic>(
        ApiEndpoints.groupMembers(params.groupId),
        queryParameters: {
          'page':  params.page,
          'limit': params.limit,
        },
      );

      dev.log(
        'fetchMembers raw type=${raw.runtimeType} '
        'keys=${raw is Map ? (raw as Map).keys.toList() : "array"}',
        name: 'GroupDS',
      );

      List<dynamic> rawList;
      if (raw is List) {
        rawList = raw;
      } else if (raw is Map<String, dynamic>) {
        rawList = (raw['users']   as List?) ??
                  (raw['members'] as List?) ??
                  (raw['data']    as List?) ??
                  (raw['result']  as List?) ??
                  [];
      } else {
        rawList = [];
      }

      dev.log('fetchMembers rawList.length=${rawList.length}', name: 'GroupDS');

      final list = rawList
          .whereType<Map<String, dynamic>>()
          .map((e) => GroupMember.fromJson(e))
          .toList();

      dev.log('fetchMembers parsed=${list.length} members', name: 'GroupDS');
      return _success(list);
    } catch (e) {
      dev.log('fetchMembers error: $e', name: 'GroupDS');
      return _failure(e);
    }
  }

  @override
  Future<ApiResult<void>> addMember(String groupId, String userId) async {
    try {
      await _api.post<void>(ApiEndpoints.groupAddUser,
          data: {'group': groupId, 'user': userId});
      return _success(null);
    } catch (e) {
      return _failure(e);
    }
  }

  @override
  Future<ApiResult<void>> removeMember(String groupId, String userId) async {
    try {
      await _api.post<void>(ApiEndpoints.groupRemoveMember,
          data: {'group': groupId, 'user': userId});
      return _success(null);
    } catch (e) {
      return _failure(e);
    }
  }

  @override
  Future<ApiResult<void>> makeAdmin(String groupId, String userId) async {
    try {
      await _api.post<void>(ApiEndpoints.groupChangeMemberRole, data: {
        'group': groupId,
        'user': userId,
        'role': 'admin',
      });
      return _success(null);
    } catch (e) {
      return _failure(e);
    }
  }

  @override
  Future<ApiResult<void>> dismissAdmin(String groupId, String userId) async {
    try {
      await _api.post<void>(ApiEndpoints.groupChangeMemberRole, data: {
        'group': groupId,
        'user': userId,
        'role': 'member',
      });
      return _success(null);
    } catch (e) {
      return _failure(e);
    }
  }

  // ── Pending join requests ──────────────────────────────────────────────────

  @override
  Future<ApiResult<List<GroupPendingMember>>> fetchPendingMembers(
      String groupId) async {
    try {
      final raw = await _api.get<dynamic>(ApiEndpoints.groupPending(groupId));
      final list = (raw is List
              ? raw
              : (raw is Map ? raw['data'] as List? ?? [] : []))
          .whereType<Map<String, dynamic>>()
          .map((e) => GroupPendingMember.fromJson(e))
          .toList();
      return _success(list);
    } catch (e) {
      return _failure(e);
    }
  }

  @override
  Future<ApiResult<void>> changePendingStatus({
    required String groupId,
    required String userId,
    required bool accept,
  }) async {
    try {
      await _api.post<void>(ApiEndpoints.groupPendingStatus, data: {
        'group': groupId,
        'user': userId,
        'accept': accept,
      });
      return _success(null);
    } catch (e) {
      return _failure(e);
    }
  }

  // ── Invite link ────────────────────────────────────────────────────────────

  @override
  Future<ApiResult<String>> getGroupLink(String groupId) async {
    try {
      final raw = await _api.get<dynamic>(ApiEndpoints.groupLink(groupId));
      final link = raw is String
          ? raw
          : (raw as Map<String, dynamic>)['data']?.toString() ?? '';
      return _success(link);
    } catch (e) {
      return _failure(e);
    }
  }

  @override
  Future<ApiResult<String>> resetGroupLink(String groupId) async {
    try {
      final raw =
          await _api.get<dynamic>(ApiEndpoints.groupResetLink(groupId));
      final link = raw is String
          ? raw
          : (raw as Map<String, dynamic>)['data']?.toString() ?? '';
      return _success(link);
    } catch (e) {
      return _failure(e);
    }
  }

  @override
  Future<ApiResult<void>> joinGroupByLink(String groupId) async {
    try {
      await _api.get<void>(ApiEndpoints.groupJoin(groupId));
      return _success(null);
    } catch (e) {
      return _failure(e);
    }
  }

  @override
  Future<ApiResult<void>> requestJoinGroup(
      String groupId, Map<String, dynamic> data) async {
    try {
      await _api.post<void>(ApiEndpoints.groupJoinRequest,
          data: {'group': groupId, ...data});
      return _success(null);
    } catch (e) {
      return _failure(e);
    }
  }

  @override
  Future<ApiResult<void>> cancelJoinRequest(
      String groupId, Map<String, dynamic> data) async {
    try {
      await _api.post<void>(ApiEndpoints.groupJoinRequestCancel,
          data: {'group': groupId, ...data});
      return _success(null);
    } catch (e) {
      return _failure(e);
    }
  }

  // ── QR ────────────────────────────────────────────────────────────────────

  @override
  Future<ApiResult<String>> getGroupQR(String groupId) async {
    try {
      final raw = await _api.get<dynamic>(ApiEndpoints.groupQR(groupId));
      final url = raw is String
          ? raw
          : (raw as Map<String, dynamic>)['data']?.toString() ?? '';
      return _success(url);
    } catch (e) {
      return _failure(e);
    }
  }

  // ── Password ──────────────────────────────────────────────────────────────

  @override
  Future<ApiResult<void>> validatePassword(
      String groupId, String password) async {
    try {
      await _api.post<void>(ApiEndpoints.groupValidatePassword,
          data: {'group': groupId, 'password': password});
      return _success(null);
    } catch (e) {
      return _failure(e);
    }
  }

  @override
  Future<ApiResult<void>> forgotPassword(Map<String, dynamic> data) async {
    try {
      await _api.post<void>(ApiEndpoints.groupForgotPassword, data: data);
      return _success(null);
    } catch (e) {
      return _failure(e);
    }
  }

  @override
  Future<ApiResult<void>> verifyOtp(Map<String, dynamic> data) async {
    try {
      await _api.post<void>(ApiEndpoints.groupVerifyOtp, data: data);
      return _success(null);
    } catch (e) {
      return _failure(e);
    }
  }

  @override
  Future<ApiResult<void>> changePassword(Map<String, dynamic> data) async {
    try {
      await _api.post<void>(ApiEndpoints.groupChangePassword, data: data);
      return _success(null);
    } catch (e) {
      return _failure(e);
    }
  }

  // ── Search ────────────────────────────────────────────────────────────────

  @override
  Future<ApiResult<List<UserModel>>> searchUsersForNewGroup(
      String query) async {
    try {
      final raw = await _api.get<Map<String, dynamic>>(
        ApiEndpoints.groupCreateSearch,
        queryParameters: {'search': query},
      );
      final list =
          (raw['users'] as List? ?? raw['data'] as List? ?? [])
              .whereType<Map<String, dynamic>>()
              .map((e) => UserModel.fromJson(e))
              .toList();
      return _success(list);
    } catch (e) {
      return _failure(e);
    }
  }

  @override
  Future<ApiResult<List<UserModel>>> searchUsersToAdd(
      String groupId, String query) async {
    try {
      final raw = await _api.get<Map<String, dynamic>>(
        ApiEndpoints.groupAddUserSearch(groupId),
        queryParameters: {'search': query},
      );
      final list =
          (raw['users'] as List? ?? raw['data'] as List? ?? [])
              .whereType<Map<String, dynamic>>()
              .map((e) => UserModel.fromJson(e))
              .toList();
      return _success(list);
    } catch (e) {
      return _failure(e);
    }
  }
}

/// Remote data source for all Call operations.
/// Implements [CallRepository] — mirrors RN's services/call.js exactly.
class CallRemoteDataSource implements CallRepository {
  const CallRemoteDataSource(this._api);
  final ApiClient _api;

  ApiResult<T> _s<T>(T d) => ApiResult.success(d);
  ApiResult<T> _f<T>(Object e) => ApiResult.failure(e.toString());

  @override
  Future<ApiResult<CallModel>> initiateCall(Map<String, dynamic> data) async {
    try {
      final raw = await _api.post<Map<String, dynamic>>(
          ApiEndpoints.callInitiate, data: data);
      return _s(CallModel.fromJson(raw));
    } catch (e) {
      return _f(e);
    }
  }

  @override
  Future<ApiResult<CallModel>> callDetails(String callId) async {
    try {
      final raw = await _api
          .get<Map<String, dynamic>>(ApiEndpoints.callById(callId));
      return _s(CallModel.fromJson(raw));
    } catch (e) {
      return _f(e);
    }
  }

  @override
  Future<ApiResult<Map<String, dynamic>>> channelDetails(
      String callId) async {
    try {
      final raw = await _api
          .get<Map<String, dynamic>>(ApiEndpoints.callChannel(callId));
      return _s(raw);
    } catch (e) {
      return _f(e);
    }
  }

  @override
  Future<ApiResult<PaginatedResult<CallModel>>> callLog({
    String? lastCall,
    String? search,
    int limit = 20,
  }) async {
    try {
      final raw = await _api.get<Map<String, dynamic>>(
        ApiEndpoints.callLog,
        queryParameters: {
          'limit': limit,
          if (lastCall != null) 'lastCall': lastCall,
          if (search != null && search.isNotEmpty) 'search': search,
        },
      );
      final calls = (raw['calls'] as List? ?? raw['data'] as List? ?? [])
          .whereType<Map<String, dynamic>>()
          .map((e) => CallModel.fromJson(e))
          .toList();
      return _s(PaginatedResult(items: calls, hasMore: raw['more'] == true));
    } catch (e) {
      return _f(e);
    }
  }

  @override
  Future<ApiResult<void>> rejectCall(String callId) async {
    try {
      await _api.post<void>(ApiEndpoints.callReject(callId));
      return _s(null);
    } catch (e) {
      return _f(e);
    }
  }

  @override
  Future<ApiResult<void>> acceptCall(String callId) async {
    try {
      await _api.post<void>(ApiEndpoints.callAccept(callId));
      return _s(null);
    } catch (e) {
      return _f(e);
    }
  }
}
