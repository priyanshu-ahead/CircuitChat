import '../../../core/storage/shared_prefs.dart';
import '../../models/chat_model.dart';

/// Local cache for recent chats — persists last-fetched chat list to SharedPrefs.
class ChatLocalDataSource {
  const ChatLocalDataSource(this._prefs);

  final AppSharedPrefs _prefs;

  static const _keyChatIds = 'cached_chat_ids';

  Future<void> cacheChats(List<ChatModel> chats) async {
    final ids = chats.map((c) => c.id).toList();
    await _prefs.setString(_keyChatIds, ids.join(','));
  }

  List<String> getCachedChatIds() {
    final raw = _prefs.getString(_keyChatIds);
    if (raw == null || raw.isEmpty) return [];
    return raw.split(',');
  }

  Future<void> clearCache() => _prefs.remove(_keyChatIds);
}
