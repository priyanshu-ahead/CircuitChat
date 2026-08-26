import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/di/providers.dart';
import '../../../core/services/socket_service.dart';
import '../../../data/models/user_model.dart';
import '../../../data/repositories/user_repository.dart';
import '../../auth/viewmodel/auth_viewmodel.dart';

/// Live map of presence for the chat-list online strip.
/// Mirrors RN Redux `state.users` populated by `GET /friend/active` and
/// socket `user_status` / `refresh` (`active_users`).
class ActiveUsersState {
  const ActiveUsersState({this.users = const {}});

  final Map<String, UserModel> users;

  List<UserModel> visible({String? excludeUserId}) {
    return users.values
        .where((u) => u.active && u.id != excludeUserId)
        .toList();
  }

  ActiveUsersState copyWith({Map<String, UserModel>? users}) =>
      ActiveUsersState(users: users ?? this.users);
}

class ActiveUsersViewModel extends Notifier<ActiveUsersState> {
  late final void Function(dynamic) _userStatusListener;
  late final void Function(dynamic) _refreshListener;

  @override
  ActiveUsersState build() {
    _userStatusListener = _onUserStatus;
    _refreshListener = _onRefresh;
    _subscribeSocket();
    ref.onDispose(_unsubscribeSocket);
    return const ActiveUsersState();
  }

  UserRepository get _repo => ref.read(userRepositoryProvider);
  SocketService get _socket => SocketService.instance;

  bool _loaded = false;

  Future<void> loadOnce() async {
    if (_loaded) return;
    _loaded = true;
    await refresh();
  }

  Future<void> refresh() async {
    try {
      final list = await _repo.fetchActiveFriends();
      final map = <String, UserModel>{
        for (final u in list) u.id: u,
      };
      state = ActiveUsersState(users: map);
    } catch (_) {
      // Keep whatever we already have (socket updates may still arrive).
    }
  }

  void _subscribeSocket() {
    _socket.on(SocketEvents.userStatus, _userStatusListener);
    _socket.on(SocketEvents.refresh, _refreshListener);
  }

  void _unsubscribeSocket() {
    _socket.off(SocketEvents.userStatus, _userStatusListener);
    _socket.off(SocketEvents.refresh, _refreshListener);
  }

  void _onUserStatus(dynamic data) {
    if (data is! Map) return;
    final user = UserModel.fromJson(Map<String, dynamic>.from(data));
    if (user.id.isEmpty) return;
    final next = Map<String, UserModel>.from(state.users);
    if (user.active) {
      next[user.id] = user;
    } else {
      next.remove(user.id);
    }
    state = state.copyWith(users: next);
  }

  void _onRefresh(dynamic data) {
    final key = data is String
        ? data
        : (data is Map ? data['type'] ?? data['event'] : null)?.toString();
    if (key == 'active_users') {
      refresh();
    }
  }
}

final activeUsersViewModelProvider =
    NotifierProvider<ActiveUsersViewModel, ActiveUsersState>(
        ActiveUsersViewModel.new);

final visibleActiveUsersProvider = Provider<List<UserModel>>((ref) {
  final selfId = ref.watch(authViewModelProvider).user?.id;
  return ref.watch(activeUsersViewModelProvider).visible(excludeUserId: selfId);
});
