import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/di/providers.dart';
import '../../../data/models/group_model.dart';
import '../../../data/repositories/group_repository.dart';

// ── State ─────────────────────────────────────────────────────────────────────

enum GroupStatus { initial, loading, success, error }

class GroupState {
  const GroupState({
    this.group,
    this.status = GroupStatus.initial,
    this.members = const [],
    this.pendingMembers = const [],
    this.membersHasMore = true,
    this.membersPage = 1,
    this.inviteLink,
    this.qrUrl,
    this.errorMessage,
    this.isUpdating = false,
  });

  final GroupModel? group;
  final GroupStatus status;
  final List<GroupMember> members;
  final List<GroupPendingMember> pendingMembers;
  final bool membersHasMore;
  final int membersPage;
  final String? inviteLink;
  final String? qrUrl;
  final String? errorMessage;
  final bool isUpdating;

  bool get isLoading => status == GroupStatus.loading;

  GroupState copyWith({
    GroupModel? group,
    GroupStatus? status,
    List<GroupMember>? members,
    List<GroupPendingMember>? pendingMembers,
    bool? membersHasMore,
    int? membersPage,
    String? inviteLink,
    String? qrUrl,
    String? errorMessage,
    bool? isUpdating,
    bool clearError = false,
  }) =>
      GroupState(
        group: group ?? this.group,
        status: status ?? this.status,
        members: members ?? this.members,
        pendingMembers: pendingMembers ?? this.pendingMembers,
        membersHasMore: membersHasMore ?? this.membersHasMore,
        membersPage: membersPage ?? this.membersPage,
        inviteLink: inviteLink ?? this.inviteLink,
        qrUrl: qrUrl ?? this.qrUrl,
        errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
        isUpdating: isUpdating ?? this.isUpdating,
      );
}

// ── ViewModel ─────────────────────────────────────────────────────────────────

/// Keyed by groupId. Each group detail screen gets its own isolated state.
class GroupViewModel extends FamilyNotifier<GroupState, String> {
  @override
  GroupState build(String arg) {
    _groupId = arg;
    _load();
    return const GroupState(status: GroupStatus.loading);
  }

  late final String _groupId;
  GroupRepository get _repo => ref.read(groupRepositoryProvider);

  // ── Load group info ───────────────────────────────────────────────────────

  Future<void> _load() async {
    state = state.copyWith(status: GroupStatus.loading);
    final result = await _repo.getGroupInfo(_groupId);
    if (result.success && result.data != null) {
      state = state.copyWith(
        group: result.data,
        status: GroupStatus.success,
        clearError: true,
      );
    } else {
      state = state.copyWith(
        status: GroupStatus.error,
        errorMessage: result.message ?? 'Failed to load group.',
      );
    }
  }

  Future<void> refresh() => _load();

  // ── Update group info ─────────────────────────────────────────────────────

  Future<bool> updateGroup(Map<String, dynamic> data) async {
    state = state.copyWith(isUpdating: true);
    final result = await _repo.updateGroup(data);
    if (result.success && result.data != null) {
      state = state.copyWith(
          group: result.data, isUpdating: false, clearError: true);
      return true;
    }
    state = state.copyWith(
        isUpdating: false, errorMessage: result.message ?? 'Update failed.');
    return false;
  }

  // ── Settings ──────────────────────────────────────────────────────────────

  Future<bool> updateSettings(Map<String, dynamic> settings) async {
    // Optimistic update
    final prev = state.group;
    if (prev != null) {
      state = state.copyWith(
        group: prev.copyWith(
          settings: GroupPermissions.fromJson(settings),
        ),
      );
    }
    final result = await _repo.updateSetting(
        groupId: _groupId, settings: settings);
    if (!result.success) {
      state = state.copyWith(
          group: prev, errorMessage: result.message ?? 'Settings save failed.');
      return false;
    }
    return true;
  }

  // ── Members ───────────────────────────────────────────────────────────────

  Future<void> loadMembers({bool refresh = false}) async {
    if (refresh) {
      state = state.copyWith(
          members: [], membersPage: 1, membersHasMore: true);
    }
    if (!state.membersHasMore) return;

    final result = await _repo.fetchMembers(FetchGroupMembersParams(
      groupId: _groupId,
      page: state.membersPage,
    ));
    if (result.success && result.data != null) {
      final incoming = result.data!;
      state = state.copyWith(
        members: refresh
            ? incoming
            : [...state.members, ...incoming],
        membersPage: state.membersPage + 1,
        membersHasMore: incoming.length >= 20,
      );
    }
  }

  Future<bool> makeAdmin(String userId) async {
    final result = await _repo.makeAdmin(_groupId, userId);
    if (result.success) {
      _updateMemberRole(userId, 'admin');
    }
    return result.success;
  }

  Future<bool> dismissAdmin(String userId) async {
    final result = await _repo.dismissAdmin(_groupId, userId);
    if (result.success) {
      _updateMemberRole(userId, 'member');
    }
    return result.success;
  }

  Future<bool> removeMember(String userId) async {
    final result = await _repo.removeMember(_groupId, userId);
    if (result.success) {
      state = state.copyWith(
        members: state.members.where((m) => m.user.id != userId).toList(),
      );
    }
    return result.success;
  }

  void _updateMemberRole(String userId, String role) {
    state = state.copyWith(
      members: state.members
          .map((m) => m.user.id == userId
              ? GroupMember(
                  id: m.id,
                  user: m.user,
                  role: role,
                  status: m.status,
                  joinedAt: m.joinedAt,
                )
              : m)
          .toList(),
    );
  }

  // ── Pending requests ──────────────────────────────────────────────────────

  Future<void> loadPendingMembers() async {
    final result = await _repo.fetchPendingMembers(_groupId);
    if (result.success && result.data != null) {
      state = state.copyWith(pendingMembers: result.data!);
    }
  }

  Future<bool> approvePending(String userId) async {
    final result = await _repo.changePendingStatus(
        groupId: _groupId, userId: userId, accept: true);
    if (result.success) {
      state = state.copyWith(
        pendingMembers:
            state.pendingMembers.where((m) => m.user.id != userId).toList(),
      );
    }
    return result.success;
  }

  Future<bool> rejectPending(String userId) async {
    final result = await _repo.changePendingStatus(
        groupId: _groupId, userId: userId, accept: false);
    if (result.success) {
      state = state.copyWith(
        pendingMembers:
            state.pendingMembers.where((m) => m.user.id != userId).toList(),
      );
    }
    return result.success;
  }

  // ── Invite link ───────────────────────────────────────────────────────────

  Future<void> loadInviteLink() async {
    final result = await _repo.getGroupLink(_groupId);
    if (result.success && result.data != null) {
      state = state.copyWith(inviteLink: result.data);
    }
  }

  Future<void> resetInviteLink() async {
    state = state.copyWith(inviteLink: null);
    final result = await _repo.resetGroupLink(_groupId);
    if (result.success && result.data != null) {
      state = state.copyWith(inviteLink: result.data);
    }
  }

  // ── QR code ───────────────────────────────────────────────────────────────

  Future<void> loadQR() async {
    final result = await _repo.getGroupQR(_groupId);
    if (result.success && result.data != null) {
      state = state.copyWith(qrUrl: result.data);
    }
  }

  Future<void> resetQR() async {
    state = state.copyWith(qrUrl: null);
    // Reset link then re-fetch QR
    await _repo.resetGroupLink(_groupId);
    await loadQR();
  }

  // ── Leave group ───────────────────────────────────────────────────────────

  Future<bool> leaveGroup() async {
    final result = await _repo.leaveGroup(_groupId);
    return result.success;
  }
}

final groupViewModelProvider =
    NotifierProviderFamily<GroupViewModel, GroupState, String>(
        GroupViewModel.new);

// ── Call Log ViewModel ────────────────────────────────────────────────────────

enum CallLogStatus { initial, loading, success, loadingMore, error }

class CallLogState {
  const CallLogState({
    this.calls = const [],
    this.status = CallLogStatus.initial,
    this.hasMore = true,
    this.searchQuery = '',
    this.errorMessage,
  });

  final List<CallModel> calls;
  final CallLogStatus status;
  final bool hasMore;
  final String searchQuery;
  final String? errorMessage;

  bool get isLoading => status == CallLogStatus.loading;

  CallLogState copyWith({
    List<CallModel>? calls,
    CallLogStatus? status,
    bool? hasMore,
    String? searchQuery,
    String? errorMessage,
  }) =>
      CallLogState(
        calls: calls ?? this.calls,
        status: status ?? this.status,
        hasMore: hasMore ?? this.hasMore,
        searchQuery: searchQuery ?? this.searchQuery,
        errorMessage: errorMessage ?? this.errorMessage,
      );
}

class CallLogViewModel extends Notifier<CallLogState> {
  @override
  CallLogState build() {
    _loadInitial();
    return const CallLogState(status: CallLogStatus.loading);
  }

  CallRepository get _repo => ref.read(callRepositoryProvider);
  String? _lastCall;

  Future<void> _loadInitial({bool refresh = false}) async {
    if (refresh) {
      _lastCall = null;
      state = state.copyWith(
          status: CallLogStatus.loading, calls: [], hasMore: true);
    }
    try {
      final result = await _repo.callLog(
        lastCall: _lastCall,
        search: state.searchQuery.isEmpty ? null : state.searchQuery,
      );
      if (result.success && result.data != null) {
        final page = result.data!;
        if (page.items.isNotEmpty) {
          _lastCall = page.items.last.id;
        }
        state = state.copyWith(
          calls: refresh
              ? page.items
              : [...state.calls, ...page.items],
          status: CallLogStatus.success,
          hasMore: page.hasMore,
        );
      } else {
        state = state.copyWith(
            status: CallLogStatus.error,
            errorMessage: result.message ?? 'Failed to load calls.');
      }
    } catch (e) {
      state = state.copyWith(
          status: CallLogStatus.error, errorMessage: e.toString());
    }
  }

  Future<void> refresh() => _loadInitial(refresh: true);

  Future<void> loadMore() async {
    if (!state.hasMore || state.status == CallLogStatus.loadingMore) return;
    state = state.copyWith(status: CallLogStatus.loadingMore);
    try {
      final result =
          await _repo.callLog(lastCall: _lastCall, search: state.searchQuery);
      if (result.success && result.data != null) {
        final page = result.data!;
        if (page.items.isNotEmpty) _lastCall = page.items.last.id;
        state = state.copyWith(
          calls: [...state.calls, ...page.items],
          status: CallLogStatus.success,
          hasMore: page.hasMore,
        );
      } else {
        state = state.copyWith(status: CallLogStatus.success);
      }
    } catch (_) {
      state = state.copyWith(status: CallLogStatus.success);
    }
  }

  void setSearch(String query) {
    state = state.copyWith(searchQuery: query);
    _loadInitial(refresh: true);
  }
}

final callLogViewModelProvider =
    NotifierProvider<CallLogViewModel, CallLogState>(CallLogViewModel.new);
