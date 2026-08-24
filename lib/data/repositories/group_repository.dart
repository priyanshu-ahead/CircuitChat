import '../models/chat_model.dart';
import '../models/group_model.dart';
import '../models/user_model.dart';
import 'auth_repository.dart';
import 'chat_repository.dart';

/// Params for fetching a paginated member list.
class FetchGroupMembersParams {
  const FetchGroupMembersParams({
    required this.groupId,
    this.page = 1,
    this.limit = 20,
  });
  final String groupId;
  final int page;
  final int limit;
}

/// Abstract interface for all group data operations.
/// Matches the full surface of RN's services/group.js.
abstract interface class GroupRepository {
  // ── Group info ─────────────────────────────────────────────────────────────

  Future<ApiResult<GroupModel>> getGroupInfo(String groupId);

  Future<ApiResult<GroupModel>> createGroup(Map<String, dynamic> data);

  Future<ApiResult<GroupModel>> updateGroup(Map<String, dynamic> data);

  Future<ApiResult<void>> updateSetting({
    required String groupId,
    required Map<String, dynamic> settings,
  });

  Future<ApiResult<void>> leaveGroup(String groupId);

  // ── Members ────────────────────────────────────────────────────────────────

  Future<ApiResult<List<GroupMember>>> fetchMembers(
      FetchGroupMembersParams params);

  Future<ApiResult<void>> addMember(String groupId, String userId);

  Future<ApiResult<void>> removeMember(String groupId, String userId);

  Future<ApiResult<void>> makeAdmin(String groupId, String userId);

  Future<ApiResult<void>> dismissAdmin(String groupId, String userId);

  // ── Pending join requests ──────────────────────────────────────────────────

  Future<ApiResult<List<GroupPendingMember>>> fetchPendingMembers(
      String groupId);

  Future<ApiResult<void>> changePendingStatus({
    required String groupId,
    required String userId,
    required bool accept,
  });

  // ── Invite link ────────────────────────────────────────────────────────────

  Future<ApiResult<String>> getGroupLink(String groupId);

  Future<ApiResult<String>> resetGroupLink(String groupId);

  Future<ApiResult<void>> joinGroupByLink(String groupId);

  Future<ApiResult<void>> requestJoinGroup(
      String groupId, Map<String, dynamic> data);

  Future<ApiResult<void>> cancelJoinRequest(
      String groupId, Map<String, dynamic> data);

  // ── QR ────────────────────────────────────────────────────────────────────

  Future<ApiResult<String>> getGroupQR(String groupId);

  // ── Password ──────────────────────────────────────────────────────────────

  Future<ApiResult<void>> validatePassword(String groupId, String password);

  Future<ApiResult<void>> forgotPassword(Map<String, dynamic> data);

  Future<ApiResult<void>> verifyOtp(Map<String, dynamic> data);

  Future<ApiResult<void>> changePassword(Map<String, dynamic> data);

  // ── Search (for group creation / adding members) ───────────────────────────

  /// Search users to invite into a new group.
  Future<ApiResult<List<UserModel>>> searchUsersForNewGroup(String query);

  /// Search users to add to an existing group.
  Future<ApiResult<List<UserModel>>> searchUsersToAdd(
      String groupId, String query);
}

/// Abstract interface for call data operations.
/// Matches the full surface of RN's services/call.js.
abstract interface class CallRepository {
  Future<ApiResult<CallModel>> initiateCall(Map<String, dynamic> data);

  Future<ApiResult<CallModel>> callDetails(String callId);

  Future<ApiResult<Map<String, dynamic>>> channelDetails(String callId);

  Future<ApiResult<PaginatedResult<CallModel>>> callLog({
    String? lastCall,
    String? search,
    int limit = 20,
  });

  Future<ApiResult<void>> rejectCall(String callId);

  Future<ApiResult<void>> acceptCall(String callId);
}
