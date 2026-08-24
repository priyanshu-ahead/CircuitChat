import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../chat/view/chat_list_screen.dart';

/// Chats tab — delegates fully to [ChatListScreen] which is wired to the
/// real [ChatListViewModel] and the SE backend.
///
/// Previously this contained dummy data; now all data management lives in
/// the shared ViewModel so both this tab and the standalone /chats route
/// share the exact same state.
class ChatsTab extends ConsumerWidget {
  const ChatsTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Just embed the full ChatListScreen — it handles all state itself.
    return const ChatListScreen();
  }
}
