import 'dart:async';
import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:circuit_chat/core/constants/app_strings.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:just_audio/just_audio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:record/record.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/di/providers.dart';
import '../../../core/network/api_endpoints.dart';
import '../../../core/router/app_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/chat_model.dart';
import '../../../data/models/message_model.dart';
import '../../../data/models/user_model.dart';
import '../../../presentation/app_init/app_init_viewmodel.dart';
import '../../../presentation/auth/viewmodel/auth_viewmodel.dart';
import '../../../presentation/chat/viewmodel/active_users_viewmodel.dart';
import '../../../presentation/chat/viewmodel/chat_list_viewmodel.dart';
import '../../../presentation/common/widgets/forward_message_sheet.dart';
import '../../../presentation/common/widgets/shimmer_list.dart';
import '../../group/viewmodel/group_viewmodel.dart';
import 'media_viewer_screen.dart';
import '../viewmodel/message_viewmodel.dart';

// ── Group members subtitle provider ──────────────────────────────────────────
final _groupMembersSubtitleProvider =
    FutureProvider.family<String, String>((ref, groupId) async {
  try {
    final api = ref.read(apiClientProvider);
    final raw = await api.get<dynamic>(
        '/group/members/$groupId',
        queryParameters: {'page': 1, 'limit': 50});

    // ── Debug: log the raw response so we can see the exact shape ─────────
    debugPrint('[GroupSubtitle] raw type=${raw.runtimeType}');
    if (raw is Map) {
      debugPrint('[GroupSubtitle] map keys=${(raw as Map).keys.toList()}');
      for (final k in (raw as Map).keys) {
        final v = (raw as Map)[k];
        if (v is List && v.isNotEmpty) {
          debugPrint('[GroupSubtitle] key=$k first item=${v.first}');
        }
      }
    } else if (raw is List && (raw as List).isNotEmpty) {
      debugPrint('[GroupSubtitle] direct list, first=${(raw as List).first}');
    }

    // ── Extract the list regardless of wrapper ─────────────────────────────
    List<dynamic> rawList;
    if (raw is List) {
      rawList = raw as List;
    } else if (raw is Map<String, dynamic>) {
      rawList = (raw['users']   as List?) ??
                (raw['members'] as List?) ??
                (raw['data']    as List?) ??
                (raw['result']  as List?) ??
                [];
    } else {
      rawList = [];
    }

    debugPrint('[GroupSubtitle] rawList.length=${rawList.length}');

    if (rawList.isEmpty) return '';

    // ── Extract first name from every possible field shape ─────────────────
    final names = rawList
        .whereType<Map<String, dynamic>>()
        .map((m) {
          // Shape 1: { user: { name/display_name/username } }
          final userField = m['user'];
          if (userField is Map<String, dynamic>) {
            final n = (userField['name']         ??
                       userField['display_name']  ??
                       userField['displayName']   ??
                       userField['username']       ??
                       '').toString().trim();
            if (n.isNotEmpty) return n.split(' ').first;
          }
          // Shape 2: flat { name / display_name / username }
          final flat = (m['name']         ??
                        m['display_name']  ??
                        m['displayName']   ??
                        m['username']       ??
                        '').toString().trim();
          return flat.split(' ').first;
        })
        .where((n) => n.isNotEmpty)
        .take(6)
        .join(', ');

    debugPrint('[GroupSubtitle] result="$names"');
    return names;
  } catch (e) {
    debugPrint('[GroupSubtitle] error: $e');
    return '';
  }
});

class ChatDetailScreen extends ConsumerStatefulWidget {
  const ChatDetailScreen({super.key, required this.chat});
  final ChatModel chat;

  @override
  ConsumerState<ChatDetailScreen> createState() => _ChatDetailScreenState();
}

class _ChatDetailScreenState extends ConsumerState<ChatDetailScreen> {
  final _textCtrl   = TextEditingController();
  final _scrollCtrl = ScrollController();
  final _searchCtrl = TextEditingController();
  final _recorder   = AudioRecorder();
  bool    _showScrollToBottom = false;
  bool    _isRecording        = false;
  bool    _isRecordingPaused  = false;
  bool    _searchMode         = false;
  String? _recordingPath;

  // ── Recording timer ───────────────────────────────────────────────────────
  int    _recordingSeconds = 0;
  Timer? _recordingTimer;

  // ── Search navigation ─────────────────────────────────────────────────────
  int _searchMatchIndex = 0; // current result index (0-based)

  String? get _currentUserId => ref.read(authViewModelProvider).user?.id;

  /// 'user' = direct, 'group' = group — matches RN CHAT_TYPE constant
  MessageVmArg get _vmArg => (
        chatId:   widget.chat.id,
        chatType: widget.chat.type == ChatType.group ? 'group' : 'user',
      );

  @override
  void initState() {
    super.initState();
    _textCtrl.addListener(() => setState(() {}));
    _searchCtrl.addListener(() => setState(() {})); // rebuild clear button
    _scrollCtrl.addListener(_onScroll);
    // Ensure active-users presence data is loaded even if the chat-list
    // screen was never opened (mirrors RN which always fetches /friend/active).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(activeUsersViewModelProvider.notifier).loadOnce();
    });
  }

  void _onScroll() {
    // reverse:true → pixels=0 is visual bottom (newest). Away from bottom = pixels > 150
    final awayFromBottom = _scrollCtrl.position.pixels > 150;
    if (_showScrollToBottom != awayFromBottom) {
      setState(() => _showScrollToBottom = awayFromBottom);
    }
    // Load older messages when user scrolls to the visual top
    if (_scrollCtrl.position.pixels >=
        _scrollCtrl.position.maxScrollExtent - 200) {
      ref.read(messageViewModelProvider(_vmArg).notifier).loadMore();
    }
  }

  @override
  void dispose() {
    _textCtrl.dispose();
    _scrollCtrl.dispose();
    _searchCtrl.dispose();
    _recorder.dispose();
    _recordingTimer?.cancel();
    super.dispose();
  }

  // ── Scroll helpers ────────────────────────────────────────────────────────

  void _scrollToBottom() {
    if (_scrollCtrl.hasClients) {
      _scrollCtrl.animateTo(0,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut);
    }
  }

  /// Scrolls the list to the message at [index] in search results.
  /// With reverse:true, index 0 = newest (bottom). The search results are
  /// returned newest-first from the API, so index 0 = most recent match.
  void _scrollToMatchIndex(int index, int total) {
    if (!_scrollCtrl.hasClients || total == 0) return;
    // Estimate item height ~60px and scroll to approximate position
    // A more precise scroll would require item keys and RenderBox lookups.
    final itemHeight = 72.0;
    final maxScroll  = _scrollCtrl.position.maxScrollExtent;
    // index 0 = bottom (pixels = 0), index total-1 = top (pixels = max)
    final targetPixels =
        (index / (total - 1).clamp(1, total - 1)) * maxScroll;
    _scrollCtrl.animateTo(
      targetPixels.clamp(0, maxScroll),
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
    );
  }

  // ── Send text ─────────────────────────────────────────────────────────────

  void _sendText() {
    final text = _textCtrl.text.trim();
    if (text.isEmpty) return;
    _textCtrl.clear();
    ref
        .read(messageViewModelProvider(_vmArg).notifier)
        .sendText(text, currentUserId: _currentUserId);
    _scrollToBottom();
  }

  // ── Call initiation ───────────────────────────────────────────────────────

  Future<void> _initiateCall({required String callType}) async {
    try {
      final api    = ref.read(apiClientProvider);
      final chatId = widget.chat.id;
      final chatType = widget.chat.type == ChatType.group ? 'group' : 'user';
      // POST /call — mirrors RN handleCallInitiate() in app.js
      final raw = await api.post<Map<String, dynamic>>(
        ApiEndpoints.callInitiate,
        data: {
          'receiver':     chatId,
          'receiverType': chatType,
          'callType':     callType,
        },
      );
      final callId   = (raw['_id'] ?? raw['id'] ?? '').toString();
      final channel  = (raw['channelId'] ?? raw['channel'] ?? callId).toString();
      if (!mounted) return;
      context.push(
        Routes.callScreen.replaceFirst(':callId', callId),
        extra: {
          'callType':   callType,
          'chatName':   widget.chat.name ?? '',
          'isIncoming': false,
          'channelId':  channel,
        },
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to start call: $e')));
    }
  }

  // ── In-chat search ────────────────────────────────────────────────────────

  // ── Chat options bottom sheet ─────────────────────────────────────────────
  // All items mirror RN's components/options.js Menus component.
  // Items are STATE-DRIVEN from the ChatModel (archive, pin, mute, blocked).
  // Only Report is "static" (always shown).

  void _showChatOptions(ChatModel chat) {
    final cc = context.cc;
    showModalBottomSheet(
      context: context,
      backgroundColor: cc.pageBackground,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      isScrollControlled: true,
      builder: (_) => _ChatOptionsSheet(
        chat: chat,
        onClose: () => Navigator.pop(context),
        onAction: (action) {
          Navigator.pop(context);
          _handleChatOptionAction(action, chat);
        },
      ),
    );
  }

  Future<void> _handleChatOptionAction(
      _ChatOptionAction action, ChatModel chat) async {
    final vm    = ref.read(chatListViewModelProvider.notifier);
    final api   = ref.read(apiClientProvider);

    switch (action) {
      case _ChatOptionAction.chatInfo:
        context.push(Routes.chatProfile
            .replaceFirst(':chatId', chat.id), extra: chat);
        break;
      case _ChatOptionAction.archive:
        await vm.archiveChat(chat.id);
        if (mounted) Navigator.pop(context); // pop back to chat list
        break;
      case _ChatOptionAction.unarchive:
        await vm.unarchiveChat(chat.id);
        break;
      case _ChatOptionAction.pin:
        await vm.pinChat(chat.id);
        break;
      case _ChatOptionAction.unpin:
        await vm.unpinChat(chat.id);
        break;
      case _ChatOptionAction.mute:
        await vm.muteChat(chat.id);
        break;
      case _ChatOptionAction.unmute:
        await vm.unmuteChat(chat.id);
        break;
      case _ChatOptionAction.markRead:
        await vm.markRead(chat.id);
        break;
      case _ChatOptionAction.markUnread:
        await api.post<void>(ApiEndpoints.chatMarkUnread,
            data: [{'chat': chat.id,
              'chatType': chat.type == ChatType.group ? 'group' : 'user'}]);
        break;
      case _ChatOptionAction.block:
        await api.post<void>(ApiEndpoints.friendBlock,
            data: {'chat': chat.id});
        if (mounted) Navigator.pop(context);
        break;
      case _ChatOptionAction.unblock:
        await api.post<void>(ApiEndpoints.friendUnblock,
            data: {'chat': chat.id});
        break;
      case _ChatOptionAction.exitGroup:
        final repo   = ref.read(groupRepositoryProvider);
        final result = await repo.leaveGroup(chat.id);
        if (result.success && mounted) context.go(Routes.chatList);
        break;
      case _ChatOptionAction.delete:
        final confirmed = await _confirm(
          'Delete Chat',
          'Delete your conversation with ${chat.name ?? 'this chat'}?',
        );
        if (confirmed) {
          await vm.deleteChat(chat.id,
              chat.type == ChatType.group ? 'group' : 'user');
          if (mounted) Navigator.pop(context);
        }
        break;
      case _ChatOptionAction.report:
        final confirmed = await _confirm(
          'Report',
          'Report ${chat.name ?? 'this chat'} to CircuitChat?',
        );
        if (confirmed) {
          await api.post<void>(ApiEndpoints.report, data: {
            'report':     chat.id,
            'reportType': chat.type == ChatType.group ? 'group' : 'user',
          });
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Reported successfully.')));
          }
        }
        break;
    }
  }

  Future<bool> _confirm(String title, String message) async {
    final cc = context.cc;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false),
              child: Text('Cancel', style: TextStyle(color: cc.secondaryText))),
          TextButton(onPressed: () => Navigator.pop(ctx, true),
              child: Text(title,
                  style: const TextStyle(color: Color(0xFFE53935)))),
        ],
      ),
    );
    return ok ?? false;
  }

  // ── Attach menu ───────────────────────────────────────────────────────────

  void _showAttachMenu() {
    final cc = context.cc;
    showModalBottomSheet(
      context: context,
      backgroundColor: cc.pageBackground,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 36, height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                    color: cc.border,
                    borderRadius: BorderRadius.circular(2)),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _AttachOption(
                    icon: Icons.camera_alt_rounded,
                    color: const Color(0xFF9C27B0),
                    label: 'Camera',
                    onTap: () { Navigator.pop(context); _pickImage(ImageSource.camera); },
                  ),
                  _AttachOption(
                    icon: Icons.photo_library_rounded,
                    color: const Color(0xFF1976D2),
                    label: 'Gallery',
                    onTap: () { Navigator.pop(context); _pickImage(ImageSource.gallery); },
                  ),
                  _AttachOption(
                    icon: Icons.videocam_rounded,
                    color: const Color(0xFFE53935),
                    label: 'Video',
                    onTap: () { Navigator.pop(context); _pickVideo(); },
                  ),
                  _AttachOption(
                    icon: Icons.insert_drive_file_rounded,
                    color: const Color(0xFF43A047),
                    label: 'File',
                    onTap: () { Navigator.pop(context); _pickFile(); },
                  ),
                ],
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  // ── Media pickers ─────────────────────────────────────────────────────────

  Future<void> _pickImage(ImageSource source) async {
    final xf = await ImagePicker().pickImage(
        source: source, imageQuality: 85, maxWidth: 1920);
    if (xf == null) return;
    _sendMedia(localPath: xf.path, type: MessageType.image);
  }

  Future<void> _pickVideo() async {
    final xf = await ImagePicker().pickVideo(source: ImageSource.gallery);
    if (xf == null) return;
    _sendMedia(localPath: xf.path, type: MessageType.video);
  }

  Future<void> _pickFile() async {
    final result = await FilePicker.platform.pickFiles(
        type: FileType.any, allowMultiple: false);
    if (result == null || result.files.isEmpty) return;
    final path = result.files.single.path;
    if (path == null) return;
    _sendMedia(localPath: path, type: MessageType.file);
  }

  Future<void> _sendMedia({
    required String localPath,
    required MessageType type,
  }) async {
    await ref
        .read(messageViewModelProvider(_vmArg).notifier)
        .sendMedia(localPath: localPath, type: type,
            currentUserId: _currentUserId);
    _scrollToBottom();
  }

  // ── Audio recording ───────────────────────────────────────────────────────

  Future<void> _startRecording() async {
    final status = await Permission.microphone.request();
    if (!status.isGranted) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text(
                  'Microphone permission is required to record audio.')),
        );
      }
      return;
    }
    try {
      final dir  = await getTemporaryDirectory();
      final path =
          '${dir.path}/audio_${DateTime.now().millisecondsSinceEpoch}.m4a';
      await _recorder.start(
        const RecordConfig(
          encoder: AudioEncoder.aacLc,
          bitRate: 128000,
          sampleRate: 44100,
        ),
        path: path,
      );
      if (mounted) {
        setState(() {
          _isRecording      = true;
          _isRecordingPaused = false;
          _recordingPath    = path;
          _recordingSeconds = 0;
        });
        _recordingTimer?.cancel();
        // Start elapsed-time timer
        _recordingTimer = Timer.periodic(const Duration(seconds: 1), (_) {
          if (mounted && !_isRecordingPaused) {
            setState(() => _recordingSeconds++);
          }
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to start recording: $e')),
        );
      }
    }
  }

  Future<void> _togglePauseRecording() async {
    if (!_isRecording) return;
    try {
      if (_isRecordingPaused) {
        await _recorder.resume();
        if (mounted) setState(() => _isRecordingPaused = false);
      } else {
        await _recorder.pause();
        if (mounted) setState(() => _isRecordingPaused = true);
      }
    } catch (e) {
      debugPrint('Failed to toggle pause recording: $e');
    }
  }

  Future<void> _stopAndSendRecording() async {
    _recordingTimer?.cancel();
    _recordingTimer = null;
    try {
      final path = await _recorder.stop();
      if (mounted) {
        setState(() {
          _isRecording      = false;
          _isRecordingPaused = false;
          _recordingSeconds = 0;
        });
      }
      if (path == null || path.isEmpty) return;
      _sendMedia(localPath: path, type: MessageType.audio);
    } catch (e) {
      if (mounted) {
        setState(() {
          _isRecording      = false;
          _isRecordingPaused = false;
          _recordingSeconds = 0;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${AppStrings.failedToStopRecording} $e'),
          ),
        );
      }
    }
  }

  Future<void> _cancelRecording() async {
    _recordingTimer?.cancel();
    _recordingTimer = null;
    try { await _recorder.stop(); } catch (_) {}
    final p = _recordingPath;
    if (mounted) {
      setState(() {
        _isRecording      = false;
        _isRecordingPaused = false;
        _recordingSeconds = 0;
        _recordingPath    = null;
      });
    }
    if (p != null) {
      try { await File(p).delete(); } catch (_) {}
    }
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final cc = context.cc;
    final primary = Theme.of(context).colorScheme.primary;
    final msgState = ref.watch(messageViewModelProvider(_vmArg));
    return Scaffold(
      backgroundColor: cc.pageBackground,
      appBar: _buildAppBar(msgState),
      body: Column(
        children: [
          if (msgState.pinnedMessage != null)
            _PinnedBanner(
              message: msgState.pinnedMessage!,
              onTap: () {},
              onDismiss: () => ref
                  .read(messageViewModelProvider(_vmArg).notifier)
                  .unpinMessage(msgState.pinnedMessage!.id),
            ),
          // Stack the message list with the scroll-down button so the
          // FAB sits ABOVE the message list (not the input bar).
          Expanded(
            child: Stack(
              children: [
                _buildMessageList(msgState),
                // Scroll-to-bottom button — positioned inside the list area
                if (_showScrollToBottom)
                  Positioned(
                    right: 12,
                    bottom: 8,
                    child: GestureDetector(
                      onTap: _scrollToBottom,
                      child: Container(
                        width: 36, height: 36,
                        decoration: BoxDecoration(
                          color: cc.cardBackground,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.15),
                              blurRadius: 6,
                              offset: const Offset(0, 2),
                            ),
                          ],
                          border: Border.all(
                              color: cc.border, width: 0.5),
                        ),
                        child: Icon(
                          Icons.keyboard_arrow_down_rounded,
                          color: primary,
                          size: 22,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          if (msgState.isTyping) _buildTypingIndicator(),
          if (msgState.replyTo != null)
            _buildReplyPreview(msgState.replyTo!),
          _buildInputBar(),
        ],
      ),
      // No floatingActionButton — scroll button is inside the Stack above
    );
  }

  // ── AppBar ────────────────────────────────────────────────────────────────

  PreferredSizeWidget _buildAppBar(MessageState msgState) {
    final cc           = context.cc;
    final primary      = Theme.of(context).colorScheme.primary;
    final agoraEnabled = ref.watch(appInitProvider).agoraEnabled;

    // ── Search mode: profile bar is fully replaced by a search bar ────────
    if (_searchMode) {
      final msgState = ref.read(messageViewModelProvider(_vmArg));
      final totalMatches = msgState.messages.length;
      final hasMatches = _searchCtrl.text.trim().length >= 2;

      return AppBar(
        backgroundColor: cc.pageBackground,
        elevation: 0,
        titleSpacing: 0,
        automaticallyImplyLeading: false,
        title: Row(
          children: [
            // Back → exit search mode
            IconButton(
              icon: Icon(Icons.arrow_back_rounded, color: cc.primaryText),
              onPressed: () {
                setState(() {
                  _searchMode       = false;
                  _searchMatchIndex = 0;
                  _searchCtrl.clear();
                });
                ref.read(messageViewModelProvider(_vmArg).notifier)
                    .clearSearch();
              },
            ),
            // Search input — autofocus, full width
            Expanded(
              child: TextField(
                controller: _searchCtrl,
                autofocus: true,
                textInputAction: TextInputAction.search,
                style: TextStyle(color: cc.primaryText, fontSize: 15),
                decoration: InputDecoration(
                  hintText: 'Search messages…',
                  hintStyle: TextStyle(color: cc.secondaryText, fontSize: 15),
                  filled: true,
                  fillColor: cc.inputBackground,
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 8),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(20),
                    borderSide: BorderSide.none,
                  ),
                ),
                onChanged: (q) {
                  setState(() => _searchMatchIndex = 0);
                  if (q.trim().length >= 2) {
                    ref.read(messageViewModelProvider(_vmArg).notifier)
                        .searchMessages(q.trim());
                  } else if (q.isEmpty) {
                    ref.read(messageViewModelProvider(_vmArg).notifier)
                        .clearSearch();
                  }
                },
              ),
            ),

            // ── Match counter + up/down navigation ───────────────────────
            if (hasMatches && totalMatches > 0) ...[
              const SizedBox(width: 4),
              Text(
                '${_searchMatchIndex + 1}/$totalMatches',
                style: TextStyle(
                    fontSize: 13,
                    color: cc.secondaryText,
                    fontWeight: FontWeight.w500),
              ),
              // Up — previous match
              SizedBox(
                width: 36,
                child: IconButton(
                  padding: EdgeInsets.zero,
                  icon: Icon(Icons.keyboard_arrow_up_rounded,
                      color: cc.primaryText, size: 22),
                  onPressed: totalMatches <= 1
                      ? null
                      : () {
                          setState(() {
                            _searchMatchIndex =
                                (_searchMatchIndex - 1 + totalMatches) %
                                    totalMatches;
                          });
                          _scrollToMatchIndex(_searchMatchIndex, totalMatches);
                        },
                ),
              ),
              // Down — next match
              SizedBox(
                width: 36,
                child: IconButton(
                  padding: EdgeInsets.zero,
                  icon: Icon(Icons.keyboard_arrow_down_rounded,
                      color: cc.primaryText, size: 22),
                  onPressed: totalMatches <= 1
                      ? null
                      : () {
                          setState(() {
                            _searchMatchIndex =
                                (_searchMatchIndex + 1) % totalMatches;
                          });
                          _scrollToMatchIndex(_searchMatchIndex, totalMatches);
                        },
                ),
              ),
            ] else if (hasMatches && totalMatches == 0) ...[
              // No results
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: Text(
                  '0/0',
                  style: TextStyle(
                      fontSize: 13,
                      color: cc.secondaryText),
                ),
              ),
            ] else ...[
              // Clear button when no search active but has text
              if (_searchCtrl.text.isNotEmpty)
                IconButton(
                  icon: Icon(Icons.close_rounded,
                      color: cc.secondaryText),
                  onPressed: () {
                    _searchCtrl.clear();
                    setState(() => _searchMatchIndex = 0);
                    ref.read(messageViewModelProvider(_vmArg).notifier)
                        .clearSearch();
                  },
                )
              else
                const SizedBox(width: 8),
            ],
          ],
        ),
        bottom: PreferredSize(
            preferredSize: const Size.fromHeight(0.5),
            child: Divider(height: 0, color: cc.divider)),
      );
    }
    final chats        = ref.watch(chatListViewModelProvider).chats;
    final activeUsers  = ref.watch(activeUsersViewModelProvider).users;
    final chat         = chats
        .where((c) => c.id == widget.chat.id)
        .firstOrNull ?? widget.chat;

    // Watch group state at top level (outside Builder) so rebuilds work correctly
    final groupState = chat.type == ChatType.group
        ? ref.watch(groupViewModelProvider(chat.id))
        : null;

    // Direct subtitle fetch for groups — independent of GroupViewModel
    final groupSubtitleAsync = chat.type == ChatType.group
        ? ref.watch(_groupMembersSubtitleProvider(chat.id))
        : null;

    final bool isDirect   = chat.type == ChatType.direct;
    final String? otherId  = isDirect ? chat.id : null;
    final UserModel? otherUser = isDirect
        ? (activeUsers[otherId] ?? chat.members.firstOrNull)
        : null;
    final bool isOnline   = chat.isOnline ||
        (otherId != null && activeUsers[otherId]?.active == true);

    return AppBar(
      backgroundColor: cc.pageBackground,
      elevation: 0,
      titleSpacing: 0,
      leading: IconButton(
        icon: Icon(Icons.arrow_back_rounded, color: cc.primaryText),
        onPressed: () => Navigator.pop(context),
      ),
      title: GestureDetector(
        onTap: () => context.push(
            Routes.chatProfile.replaceFirst(':chatId', chat.id),
            extra: chat),
        child: Row(
          children: [
            Stack(
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor: cc.surfaceBackground,
                  backgroundImage: chat.avatar != null
                      ? NetworkImage(chat.avatar!) : null,
                  child: chat.avatar == null
                      ? Icon(
                          chat.type == ChatType.group
                              ? Icons.group_rounded : Icons.person_rounded,
                          color: cc.secondaryText, size: 20)
                      : null,
                ),
                if (isOnline && isDirect)
                  Positioned(
                    right: 1, bottom: 1,
                    child: Container(
                      width: 9, height: 9,
                      decoration: BoxDecoration(
                        color: const Color(0xFF4CAF50),
                        shape: BoxShape.circle,
                        border: Border.all(color: cc.cardBackground, width: 1.5),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(chat.name ?? AppStrings.chat,
                      style: TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w700,
                          color: cc.primaryText),
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                  // ── Status subtitle mirrors RN UserStatusText / header.js ──
                  Builder(builder: (_) {
                    // Typing takes priority
                    if (msgState.isTyping) {
                      return Text(AppStrings.typing,
                          style: TextStyle(fontSize: 12,
                              color: primary,
                              fontStyle: FontStyle.italic));
                    }

                    if (isDirect) {
                      // Use live data from activeUsersProvider first
                      final liveUser = otherId != null
                          ? activeUsers[otherId]
                          : null;
                      // Merge: liveUser if available, else otherUser from chat
                      final u = liveUser ?? otherUser;

                      if (u != null && u.active) {
                        // state: 1=active, 2=away, 3=dnd, 0=offline
                        switch (u.state) {
                          case 1: // Active / online
                            return Text(AppStrings.active,
                                style: TextStyle(
                                    fontSize: 12,
                                    color: const Color(0xFF4CAF50),
                                    fontWeight: FontWeight.w500));
                          case 2: // Away
                            return Text(
                              u.lastSeen != null
                                  ? '${AppStrings.active} ${_fromNow(u.lastSeen!)}'
                                  : AppStrings.active,
                              style: TextStyle(
                                fontSize: 12,
                                color: const Color(0xFFFFC107),
                              ),
                            );
                          case 3: // Do not disturb
                            return Text(AppStrings.doNotDisturb,
                                style: TextStyle(
                                    fontSize: 12,
                                    color: const Color(0xFFE53935)));
                          default:
                            return Text(AppStrings.active,
                                style: TextStyle(
                                    fontSize: 12,
                                    color: const Color(0xFF4CAF50),
                                    fontWeight: FontWeight.w500));
                        }
                      } else if (u?.lastSeen != null) {
                        // Offline but we have a lastSeen/lastActive from activeUsers
                        return Text(
                          '${AppStrings.active} ${_fromNow(u!.lastSeen!)}',
                          style: TextStyle(
                              fontSize: 12, color: cc.secondaryText),
                        );
                      } else if (chat.lastActive != null) {
                        // Fallback: use chat.lastActive from API — mirrors RN's
                        // `user?.lastActive || chat?.lastActive` check
                        return Text(
                          '${AppStrings.active} ${_fromNow(chat.lastActive!)}',
                          style: TextStyle(
                              fontSize: 12, color: cc.secondaryText),
                        );
                      } else if (chat.isOnline) {
                        return Text(AppStrings.active,
                            style: TextStyle(
                                fontSize: 12,
                                color: const Color(0xFF4CAF50),
                                fontWeight: FontWeight.w500));
                      } else {
                        return const SizedBox.shrink();
                      }
                    } else {
                      // Group: show member first-names from direct API fetch
                      // Uses _groupMembersSubtitleProvider which calls
                      // GET /group/members/:id directly — bypasses GroupViewModel

                      if (groupSubtitleAsync == null) {
                        return const SizedBox.shrink();
                      }

                      return groupSubtitleAsync.when(
                        loading: () {
                          // While loading: show a placeholder
                          final count = groupState?.group?.memberCount ?? 0;
                          return Text(
                            count > 0 ? '$count members' : 'Loading members…',
                            style: TextStyle(
                                fontSize: 12, color: cc.secondaryText),
                          );
                        },
                        error: (e, _) {
                          debugPrint('[GroupSubtitle] widget error: $e');
                          return const SizedBox.shrink();
                        },
                        data: (subtitle) {
                          debugPrint('[GroupSubtitle] widget data="$subtitle"');
                          if (subtitle.isEmpty) {
                            final count = groupState?.group?.memberCount ?? 0;
                            return Text(
                              count > 0 ? '$count members' : '',
                              style: TextStyle(
                                  fontSize: 12, color: cc.secondaryText),
                            );
                          }
                          return Text(
                            subtitle,
                            style: TextStyle(
                                fontSize: 12, color: cc.secondaryText),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          );
                        },
                      );
                    }
                  }),
                ],
              ),
            ),
          ],
        ),
      ),
      // ── Header icons order: call → video → search → options ────────────
      actions: [
        if (agoraEnabled)
          _AppBarIcon(
            icon: Icons.call_outlined,
            color: cc.primaryText,
            tooltip: 'Voice Call',
            onTap: () => _initiateCall(callType: 'audio'),
          ),
        if (agoraEnabled)
          _AppBarIcon(
            icon: Icons.videocam_outlined,
            color: cc.primaryText,
            tooltip: 'Video Call',
            onTap: () => _initiateCall(callType: 'video'),
          ),
        _AppBarIcon(
          icon: Icons.search_rounded,
          color: cc.primaryText,
          tooltip: 'Search',
          onTap: () => setState(() => _searchMode = true),
        ),
        _AppBarIcon(
          icon: Icons.more_vert_rounded,
          color: cc.primaryText,
          tooltip: 'Options',
          onTap: () => _showChatOptions(chat),
        ),
        const SizedBox(width: 4),
      ],
      bottom: PreferredSize(
          preferredSize: const Size.fromHeight(0.5),
          child: Divider(height: 0, color: cc.divider)),
    );
  }

  // ── Message list ──────────────────────────────────────────────────────────

  Widget _buildMessageList(MessageState msgState) {
    final cc = context.cc;
    final primary = Theme.of(context).colorScheme.primary;
    if (msgState.isLoading) return const MessageShimmerList();

    if (msgState.status == MessageStatus2.error) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline_rounded,
                size: 48, color: cc.secondaryText),
            const SizedBox(height: 8),
            Text(msgState.errorMessage ?? AppStrings.failedToLoadMessages,
                style: TextStyle(color: cc.secondaryText)),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: () => ref
                  .read(messageViewModelProvider(_vmArg).notifier)
                  .reload(),
              style: ElevatedButton.styleFrom(
                  backgroundColor: primary,
                  foregroundColor: Colors.white),
              child: const Text(AppStrings.retry),
            ),
          ],
        ),
      );
    }

    final messages = msgState.messages;
    if (messages.isEmpty) {
      return Center(
        child: Text(AppStrings.noMessagesYet,
            textAlign: TextAlign.center,
            style: TextStyle(color: cc.secondaryText, fontSize: 15)),
      );
    }

    final total = messages.length;

    return ListView.builder(
      controller: _scrollCtrl,
      reverse: true,   // index 0 = newest → appears at visual bottom
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      itemCount: total + (msgState.hasMore ? 1 : 0),
      itemBuilder: (_, i) {
        // Spinner at visual top (oldest end) when loading older messages
        if (i == total) {
          return Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Center(
              child: SizedBox(width: 24, height: 24,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: primary)),
            ),
          );
        }
        final msg     = messages[i];
        final nextMsg = (i + 1 < total) ? messages[i + 1] : null;
        // Show date divider when day changes (next = older in reverse list)
        final showDate = nextMsg == null ||
            !_sameDay(nextMsg.createdAt, msg.createdAt);

        return Column(
          children: [
            if (msg.isSystemMessage)
              _SystemMessage(msg: msg)
            else
              _MessageBubble(
                msg: msg,
                onLongPress: () => _showMessageMenu(msg),
                onReply: () => ref
                    .read(messageViewModelProvider(_vmArg).notifier)
                    .setReplyTo(msg),
                allMessages: messages,
                currentUserId: _currentUserId,
              ),
            if (showDate) _DateDivider(iso: msg.createdAt),
          ],
        );
      },
    );
  }

  // ── Typing indicator ──────────────────────────────────────────────────────

  Widget _buildTypingIndicator() {
    final cc = context.cc;
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.fromLTRB(16, 4, 80, 4),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: cc.cardBackground,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 4, offset: const Offset(0, 2))],
        ),
        child: Row(mainAxisSize: MainAxisSize.min,
            children: List.generate(3,
                (i) => _TypingDot(delay: Duration(milliseconds: i * 150)))),
      ),
    );
  }

  // ── Reply preview bar ─────────────────────────────────────────────────────

  Widget _buildReplyPreview(MessageModel replyTo) {
    final cc = context.cc;
    final primary = Theme.of(context).colorScheme.primary;
    return Container(
      color: cc.cardBackground,
      padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
      child: Row(
        children: [
          Container(
            width: 3, height: 36,
            decoration: BoxDecoration(
                color: primary,
                borderRadius: BorderRadius.circular(2)),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(AppStrings.reply,
                    style: TextStyle(fontSize: 12, color: primary,
                        fontWeight: FontWeight.w600)),
                Text(replyTo.text ?? _contentLabel(replyTo.contentType),
                    maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontSize: 13, color: cc.secondaryText)),
              ],
            ),
          ),
          IconButton(
            icon: Icon(Icons.close_rounded,
                size: 18, color: cc.secondaryText),
            onPressed: () => ref
                .read(messageViewModelProvider(_vmArg).notifier)
                .setReplyTo(null),
          ),
        ],
      ),
    );
  }

  // ── Input bar ─────────────────────────────────────────────────────────────

  Widget _buildInputBar() {
    final cc      = context.cc;
    final primary = Theme.of(context).colorScheme.primary;
    final hasText = _textCtrl.text.trim().isNotEmpty;

    // ── Recording mode ────────────────────────────────────────────────────
    if (_isRecording) {
      return SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 6, 8, 8),
          child: Container(
            decoration: BoxDecoration(
              color: cc.cardBackground,
              borderRadius: BorderRadius.circular(28),
              border: Border.all(
                  color: const Color(0xFFE53935).withOpacity(0.4)),
              boxShadow: [
                BoxShadow(
                    color: Colors.black.withOpacity(0.06),
                    blurRadius: 6,
                    offset: const Offset(0, -1)),
              ],
            ),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            child: Row(
              children: [
                // Cancel / delete
                IconButton(
                  icon: const Icon(Icons.delete_outline_rounded,
                      color: Color(0xFFE53935)),
                  tooltip: 'Cancel recording',
                  onPressed: _cancelRecording,
                ),
                // Waveform + timer + Pause/Resume
                Expanded(
                  child: _RecordingIndicator(
                    elapsed:  _recordingSeconds,
                    isPaused: _isRecordingPaused,
                    onPlayPause: _togglePauseRecording,
                  ),
                ),
                const SizedBox(width: 6),
                // Send — stops recording and sends
                GestureDetector(
                  onTap: _stopAndSendRecording,
                  child: Container(
                    width: 42, height: 42,
                    decoration: BoxDecoration(
                        color: primary, shape: BoxShape.circle),
                    child: const Icon(Icons.send_rounded,
                        color: Colors.white, size: 20),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    // ── Normal mode ───────────────────────────────────────────────────────
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 6, 8, 8),
        child: Container(
          decoration: BoxDecoration(
            color: cc.cardBackground,
            borderRadius: BorderRadius.circular(28),
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withOpacity(0.06),
                  blurRadius: 6,
                  offset: const Offset(0, -1)),
            ],
          ),
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              // Attach
              IconButton(
                icon: Icon(Icons.attach_file_rounded,
                    color: cc.secondaryText, size: 22),
                onPressed: _showAttachMenu,
                padding: const EdgeInsets.all(8),
                constraints: const BoxConstraints(),
              ),
              // Text field — rounded inner container
              Expanded(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 120),
                  child: TextField(
                    controller: _textCtrl,
                    maxLines: null,
                    textCapitalization: TextCapitalization.sentences,
                    style: TextStyle(color: cc.primaryText, fontSize: 15),
                    decoration: InputDecoration(
                      hintText: AppStrings.message,
                      hintStyle: TextStyle(
                          color: cc.secondaryText, fontSize: 15),
                      filled: true,
                      fillColor: cc.inputBackground,
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 9),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(20),
                        borderSide: BorderSide.none,
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(20),
                        borderSide: BorderSide.none,
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(20),
                        borderSide: BorderSide(
                            color: primary.withOpacity(0.4), width: 1),
                      ),
                    ),
                    onSubmitted: (_) => _sendText(),
                  ),
                ),
              ),
              const SizedBox(width: 4),
              // Send / Mic button
              if (hasText)
                _CircleButton(
                  icon: Icons.send_rounded,
                  color: primary,
                  iconColor: Colors.white,
                  onTap: _sendText,
                )
              else
                _CircleButton(
                  icon: Icons.mic_rounded,
                  // Tap to start recording
                  color: primary.withOpacity(0.12),
                  iconColor: primary,
                  onTap: _startRecording,
                  tooltip: AppStrings.tapToRecord,
                ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Message context menu ──────────────────────────────────────────────────

  void _showMessageMenu(MessageModel msg) {
    final cc = context.cc;
    final primary = Theme.of(context).colorScheme.primary;
    showModalBottomSheet(
      context: context,
      backgroundColor: cc.pageBackground,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(width: 40, height: 4,
                decoration: BoxDecoration(color: cc.border,
                    borderRadius: BorderRadius.circular(2))),
            // Emoji reaction strip
            if (!msg.isDeleted)
              _EmojiReactionStrip(
                onReact: (emoji) {
                  Navigator.pop(context);
                  ref.read(messageViewModelProvider(_vmArg).notifier)
                      .addReaction(msg.id, emoji);
                },
              ),
            Divider(height: 1, color: cc.divider),
            if (!msg.isDeleted) ...[
              ListTile(
                leading: Icon(Icons.reply_rounded,
                    color: primary),
                title: Text(AppStrings.reply, style: TextStyle(color: cc.primaryText)),
                onTap: () {
                  Navigator.pop(context);
                  ref.read(messageViewModelProvider(_vmArg).notifier)
                      .setReplyTo(msg);
                },
              ),
              if (msg.text != null && msg.text!.isNotEmpty)
                ListTile(
                  leading: Icon(Icons.copy_rounded,
                      color: primary),
                  title: Text(AppStrings.copy, style: TextStyle(color: cc.primaryText)),
                  onTap: () {
                    Navigator.pop(context);
                    Clipboard.setData(ClipboardData(text: msg.text!));
                    ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text(AppStrings.copied)));
                  },
                ),
              ListTile(
                leading: Icon(
                  msg.isStarred
                      ? Icons.star_rounded : Icons.star_border_rounded,
                  color: msg.isStarred
                      ? const Color(0xFFFFC107) : primary,
                ),
                title: Text(msg.isStarred ? AppStrings.unstar : AppStrings.star, style: TextStyle(color: cc.primaryText)),
                onTap: () {
                  Navigator.pop(context);
                  final vm = ref.read(
                      messageViewModelProvider(_vmArg).notifier);
                  if (msg.isStarred) {
                    vm.unstarMessage(msg.id);
                  } else {
                    vm.starMessage(msg.id);
                  }
                },
              ),
              ListTile(
                leading: Icon(Icons.forward_rounded,
                    color: primary),
                title: Text(AppStrings.forward, style: TextStyle(color: cc.primaryText)),
                onTap: () {
                  Navigator.pop(context);
                  ForwardMessageSheet.show(context, messageIds: [msg.id]);
                },
              ),
              ListTile(
                leading: Icon(
                  msg.pinned != null
                      ? Icons.push_pin_outlined : Icons.push_pin_rounded,
                  color: primary,
                ),
                title: Text(msg.pinned != null ? AppStrings.unpin : AppStrings.pin, style: TextStyle(color: cc.primaryText)),
                onTap: () {
                  Navigator.pop(context);
                  final vm = ref.read(
                      messageViewModelProvider(_vmArg).notifier);
                  if (msg.pinned != null) {
                    vm.unpinMessage(msg.id);
                  } else {
                    vm.pinMessage(msg.id);
                  }
                },
              ),
              if (msg.fromMe)
                ListTile(
                  leading: Icon(Icons.info_outline_rounded,
                      color: primary),
                  title: Text(AppStrings.messageInfo, style: TextStyle(color: cc.primaryText)),
                  onTap: () {
                    Navigator.pop(context);
                    context.push(Routes.messageInfo
                        .replaceFirst(':messageId', msg.id));
                  },
                ),
            ],
            ListTile(
              leading: const Icon(Icons.delete_outline_rounded,
                  color: Color(0xFFEF4444)),
              title: const Text(AppStrings.delete,
                  style: TextStyle(color: Color(0xFFEF4444))),
              onTap: () {
                Navigator.pop(context);
                _showDeleteOptions(msg);
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  void _showDeleteOptions(MessageModel msg) {
    final cc = context.cc;
    showModalBottomSheet(
      context: context,
      backgroundColor: cc.pageBackground,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            Text(AppStrings.deleteMessage,
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: cc.primaryText)),
            const SizedBox(height: 8),
            ListTile(
              leading: const Icon(Icons.delete_outline_rounded,
                  color: Color(0xFFEF4444)),
              title: Text(AppStrings.deleteForMe, style: TextStyle(color: cc.primaryText)),
              onTap: () {
                Navigator.pop(context);
                ref.read(messageViewModelProvider(_vmArg).notifier)
                    .deleteMessage(msg.id);
              },
            ),
            if (msg.fromMe)
              ListTile(
                leading: const Icon(Icons.delete_sweep_rounded,
                    color: Color(0xFFEF4444)),
                title: Text(AppStrings.deleteForEveryone, style: TextStyle(color: cc.primaryText)),
                onTap: () {
                  Navigator.pop(context);
                  ref.read(messageViewModelProvider(_vmArg).notifier)
                      .deleteMessage(msg.id, forEveryone: true);
                },
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  static bool _sameDay(String? a, String? b) {
    if (a == null || b == null) return false;
    try {
      final da = DateTime.parse(a);
      final db = DateTime.parse(b);
      return da.year == db.year && da.month == db.month && da.day == db.day;
    } catch (_) { return false; }
  }

  static String _contentLabel(ContentType t) {
    switch (t) {
      case ContentType.image:  return '📷 Photo';
      case ContentType.video:  return '🎥 Video';
      case ContentType.audio:  return '🎵 Audio';
      case ContentType.file:   return '📎 File';
      default:                 return 'Message';
    }
  }
}

// ── Compact circle button ─────────────────────────────────────────────────────
class _CircleButton extends StatelessWidget {
  const _CircleButton({
    required this.icon,
    required this.color,
    required this.iconColor,
    required this.onTap,
    this.tooltip = '',
  });
  final IconData icon;
  final Color    color, iconColor;
  final VoidCallback onTap;
  final String   tooltip;

  @override
  Widget build(BuildContext context) => Tooltip(
        message: tooltip,
        child: GestureDetector(
          onTap: onTap,
          child: Container(
            width: 42, height: 42,
            margin: const EdgeInsets.all(3),
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            child: Icon(icon, color: iconColor, size: 20),
          ),
        ),
      );
}

// ── Recording indicator (shows inside the recording bar) ──────────────────────
class _RecordingIndicator extends StatefulWidget {
  const _RecordingIndicator({
    required this.elapsed,
    required this.isPaused,
    required this.onPlayPause,
  });
  final int  elapsed;
  final bool isPaused;
  final VoidCallback onPlayPause;

  @override
  State<_RecordingIndicator> createState() => _RecordingIndicatorState();
}

class _RecordingIndicatorState extends State<_RecordingIndicator>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  String get _timeLabel {
    final m = widget.elapsed ~/ 60;
    final s = widget.elapsed % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        // Pause/Resume recording button
        GestureDetector(
          onTap: widget.onPlayPause,
          child: Container(
            width: 34, height: 34,
            decoration: BoxDecoration(
              color: const Color(0xFFE53935).withOpacity(0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(
              widget.isPaused
                  ? Icons.play_arrow_rounded
                  : Icons.pause_rounded,
              color: const Color(0xFFE53935),
              size: 20,
            ),
          ),
        ),
        const SizedBox(width: 8),
        // Animated waveform bars
        SizedBox(
          width: 60,
          height: 24,
          child: AnimatedBuilder(
            animation: _pulse,
            builder: (_, __) => Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: List.generate(8, (i) {
                final base = 4.0 + (i % 4) * 4.0;
                final h = !widget.isPaused
                    ? base + _pulse.value * 10
                    : base;
                return Container(
                  width: 3,
                  height: h.clamp(4.0, 18.0),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE53935),
                    borderRadius: BorderRadius.circular(2),
                  ),
                );
              }),
            ),
          ),
        ),
        const SizedBox(width: 8),
        // Pulsing dot + timer
        AnimatedBuilder(
          animation: _pulse,
          builder: (_, __) => Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 8, height: 8,
                decoration: BoxDecoration(
                  color: !widget.isPaused
                      ? Color.lerp(const Color(0xFFE53935),
                          const Color(0xFFFF8A80),
                          _pulse.value)
                      : const Color(0xFFE53935).withOpacity(0.5),
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                _timeLabel,
                style: const TextStyle(
                  color: Color(0xFFE53935),
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  fontFeatures: [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ── Attach option button ──────────────────────────────────────────────────────
class _AttachOption extends StatelessWidget {
  const _AttachOption({
    required this.icon, required this.color,
    required this.label, required this.onTap,
  });
  final IconData icon;
  final Color    color;
  final String   label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cc = context.cc;
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 56, height: 56,
            decoration: BoxDecoration(
                color: color.withOpacity(0.12),
                borderRadius: BorderRadius.circular(16)),
            child: Icon(icon, color: color, size: 28),
          ),
          const SizedBox(height: 6),
          Text(label,
              style: TextStyle(fontSize: 12, color: cc.secondaryText)),
        ],
      ),
    );
  }
}

// ── Date divider ──────────────────────────────────────────────────────────────
class _DateDivider extends StatelessWidget {
  const _DateDivider({required this.iso});
  final String iso;

  @override
  Widget build(BuildContext context) {
    final cc = context.cc;
    String label;
    try {
      final dt  = DateTime.parse(iso).toLocal();
      final now = DateTime.now();
      if (dt.year == now.year && dt.month == now.month && dt.day == now.day) {
        label = AppStrings.today;
      } else {
        final y = now.subtract(const Duration(days: 1));
        if (dt.year == y.year && dt.month == y.month && dt.day == y.day) {
          label = AppStrings.yesterday;
        } else {
          label = DateFormat('MMMM d, yyyy').format(dt);
        }
      }
    } catch (_) { label = ''; }

    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: isDark ? Colors.white10 : Colors.black.withOpacity(0.06),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(label,
              style: TextStyle(fontSize: 12, color: cc.secondaryText)),
        ),
      ),
    );
  }
}

// ── System message ────────────────────────────────────────────────────────────
class _SystemMessage extends StatelessWidget {
  const _SystemMessage({required this.msg});
  final MessageModel msg;

  @override
  Widget build(BuildContext context) {
    final cc = context.cc;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
          decoration: BoxDecoration(
            color: isDark ? Colors.white10 : Colors.black.withOpacity(0.06),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(msg.text ?? '',
              style: TextStyle(fontSize: 12, color: cc.secondaryText),
              textAlign: TextAlign.center),
        ),
      ),
    );
  }
}

// ── Message bubble ────────────────────────────────────────────────────────────
class _MessageBubble extends StatelessWidget {
  const _MessageBubble({
    required this.msg,
    required this.onLongPress,
    required this.onReply,
    this.allMessages = const [],
    this.currentUserId,
  });
  final MessageModel       msg;
  final VoidCallback       onLongPress;
  final VoidCallback       onReply;
  final List<MessageModel> allMessages;
  final String?            currentUserId;

  @override
  Widget build(BuildContext context) {
    final isMe = msg.fromMe;
    final cc = context.cc;
    final bubbleColor = isMe ? cc.bubbleMe : cc.bubbleOther;
    final textColor   = isMe ? cc.bubbleMeText : cc.bubbleOtherText;
    final timeColor   = isMe ? cc.bubbleMeText.withOpacity(0.7) : cc.secondaryText;

    return GestureDetector(
      onLongPress: onLongPress,
      child: Padding(
        padding: EdgeInsets.only(
          top: 2, bottom: 2,
          left: isMe ? 60 : 0,
          right: isMe ? 0 : 60,
        ),
        child: Align(
          alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
          child: Column(
            crossAxisAlignment:
                isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
            children: [
              if (msg.replyToMessage != null)
                _InBubbleReply(reply: msg.replyToMessage!, isMe: isMe),

              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: bubbleColor,
                  borderRadius: BorderRadius.only(
                    topLeft:     const Radius.circular(16),
                    topRight:    const Radius.circular(16),
                    bottomLeft:  Radius.circular(isMe ? 16 : 4),
                    bottomRight: Radius.circular(isMe ? 4 : 16),
                  ),
                  boxShadow: [BoxShadow(
                    color: Colors.black.withOpacity(0.06),
                    blurRadius: 4, offset: const Offset(0, 2))],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    if (msg.isDeleted)
                      Text(AppStrings.messageDeleted,
                          style: TextStyle(fontSize: 14,
                              fontStyle: FontStyle.italic,
                              color: isMe
                                  ? cc.bubbleMeText.withOpacity(0.7)
                                  : cc.secondaryText))
                    else if (msg.contentType == ContentType.text)
                      _MessageText(
                        text: msg.text ?? '',
                        mentions: msg.mentions,
                        textColor: textColor,
                        isMe: isMe,
                      )
                    else
                      _MediaContent(
                        msg: msg,
                        isMe: isMe,
                        allMessages: allMessages,
                        currentUserId: currentUserId,
                      ),

                    const SizedBox(height: 4),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(_formatTime(msg.createdAt),
                            style: TextStyle(fontSize: 11,
                                color: timeColor)),
                        if (isMe) ...[
                          const SizedBox(width: 3),
                          _StatusIcon(status: msg.status),
                        ],
                      ],
                    ),
                  ],
                ),
              ),

              if (msg.reactions.isNotEmpty) _ReactionsRow(msg: msg),
            ],
          ),
        ),
      ),
    );
  }

  static String _formatTime(String iso) {
    try {
      return DateFormat('h:mm a').format(DateTime.parse(iso).toLocal());
    } catch (_) { return ''; }
  }
}

// ── In-bubble reply preview ───────────────────────────────────────────────────
class _InBubbleReply extends StatelessWidget {
  const _InBubbleReply({required this.reply, required this.isMe});
  final MessageModel reply;
  final bool isMe;

  @override
  Widget build(BuildContext context) {
    final cc = context.cc;
    final primary = Theme.of(context).colorScheme.primary;
    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: isMe
            ? Colors.white.withOpacity(0.15)
            : cc.pageBackground,
        borderRadius: BorderRadius.circular(10),
        border: Border(
            left: BorderSide(color: isMe ? Colors.white : primary, width: 3)),
      ),
      child: Text(reply.text ?? '📎 Media',
          maxLines: 2, overflow: TextOverflow.ellipsis,
          style: TextStyle(fontSize: 12,
              color: isMe ? Colors.white70 : cc.secondaryText)),
    );
  }
}

// ── Media content ─────────────────────────────────────────────────────────────
class _MediaContent extends StatelessWidget {
  const _MediaContent({
    required this.msg,
    required this.isMe,
    this.allMessages = const [],
    this.currentUserId,
  });
  final MessageModel       msg;
  final bool               isMe;
  final List<MessageModel> allMessages;  // sibling messages for swipe
  final String?            currentUserId;

  @override
  Widget build(BuildContext context) {
    final cc = context.cc;
    final primary = Theme.of(context).colorScheme.primary;

    switch (msg.contentType) {
      case ContentType.image:
        return GestureDetector(
          onTap: () {
            final mediaList = allMessages.isEmpty
                ? [msg]
                : allMessages
                    .where((m) =>
                        m.contentType == ContentType.image ||
                        m.contentType == ContentType.video)
                    .toList()
                    .reversed
                    .toList();
            final idx = mediaList.indexWhere((m) => m.id == msg.id);
            MediaViewerScreen.open(
              context,
              messages:      mediaList,
              initialIndex:  idx < 0 ? 0 : idx,
              currentUserId: currentUserId,
            );
          },
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: _buildImageWidget(cc, primary),
          ),
        );

      case ContentType.video:
        return GestureDetector(
          onTap: () {
            final mediaList = allMessages.isEmpty
                ? [msg]
                : allMessages
                    .where((m) =>
                        m.contentType == ContentType.image ||
                        m.contentType == ContentType.video)
                    .toList()
                    .reversed
                    .toList();
            final idx = mediaList.indexWhere((m) => m.id == msg.id);
            MediaViewerScreen.open(
              context,
              messages:      mediaList,
              initialIndex:  idx < 0 ? 0 : idx,
              currentUserId: currentUserId,
            );
          },
          child: Stack(
            alignment: Alignment.center,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: _buildVideoThumbnail(cc),
              ),
              Container(
                width: 48, height: 48,
                decoration: BoxDecoration(color: Colors.black54,
                    borderRadius: BorderRadius.circular(24)),
                child: const Icon(Icons.play_arrow_rounded,
                    color: Colors.white, size: 32),
              ),
            ],
          ),
        );

      case ContentType.audio:
        return _AudioBubble(msg: msg, isMe: isMe);

      case ContentType.file:
        return GestureDetector(
          onTap: () {
            if (msg.mediaUrl != null) {
              launchUrl(Uri.parse(msg.mediaUrl!));
            }
          },
          child: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: isMe
                  ? Colors.white.withOpacity(0.15)
                  : cc.surfaceBackground,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.insert_drive_file_rounded,
                    color: isMe ? Colors.white : primary,
                    size: 28),
                const SizedBox(width: 8),
                Flexible(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(msg.mediaUrl?.split('/').last ?? 'file',
                          style: TextStyle(fontSize: 13,
                              fontWeight: FontWeight.w500,
                              color: isMe ? Colors.white : cc.primaryText),
                          maxLines: 2, overflow: TextOverflow.ellipsis),
                      if (msg.mediaSize != null)
                        Text(
                            '${(msg.mediaSize! / 1024).toStringAsFixed(1)} KB',
                            style: TextStyle(fontSize: 11,
                                color: isMe
                                    ? Colors.white70
                                    : cc.secondaryText)),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Icon(Icons.download_rounded,
                    color: isMe ? Colors.white70 : primary,
                    size: 20),
              ],
            ),
          ),
        );

      case ContentType.location:
        final lat = msg.latitude  ?? 0.0;
        final lng = msg.longitude ?? 0.0;
        return GestureDetector(
          onTap: () => launchUrl(
              Uri.parse('https://maps.google.com/maps?q=$lat,$lng'),
              mode: LaunchMode.externalApplication),
          child: Container(
            width: 200, height: 110,
            decoration: BoxDecoration(
              color: isMe
                  ? Colors.white.withOpacity(0.15)
                  : cc.surfaceBackground,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                  color: isMe ? Colors.white24 : cc.border),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.location_on_rounded,
                    color: Color(0xFFE53935), size: 30),
                const SizedBox(height: 4),
                Text(AppStrings.viewLocation,
                    style: TextStyle(fontSize: 12,
                        color: isMe
                            ? Colors.white70
                            : primary)),
              ],
            ),
          ),
        );

      default:
        return Text(msg.text ?? '',
            style: TextStyle(
                color: isMe ? Colors.white : cc.primaryText));
    }
  }

  void _openFullScreen(BuildContext context, String url) {
    // Replaced by MediaViewerScreen.open() — kept for safety, forwards to it.
    MediaViewerScreen.open(
      context,
      messages: [MessageModel(
        id: url, chatId: '', senderId: '',
        contentType: ContentType.image,
        mediaUrl: url,
        createdAt: DateTime.now().toIso8601String(),
      )],
      initialIndex: 0,
      currentUserId: currentUserId,
    );
  }

  Widget _buildImageWidget(CircuitChatColors cc, Color primary) {
    final url = msg.mediaUrl;

    // Optimistic send — local file not yet uploaded, show from file system
    if (url != null && (url.startsWith('/') || url.startsWith('file://'))) {
      final file = File(url.replaceFirst('file://', ''));
      return Image.file(
        file,
        width: 220, height: 220, fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => _placeholder(Icons.broken_image_rounded, cc),
      );
    }

    // Uploaded — load from network
    if (url != null && url.isNotEmpty) {
      return CachedNetworkImage(
        imageUrl: url,
        width: 220, height: 220, fit: BoxFit.cover,
        placeholder: (_, __) => Container(
          width: 220, height: 220,
          color: cc.surfaceBackground,
          child: Center(child: CircularProgressIndicator(color: primary)),
        ),
        errorWidget: (_, __, ___) =>
            _placeholder(Icons.broken_image_rounded, cc),
      );
    }

    // Sending in progress — show spinner
    if (msg.status == MessageStatus.sending) {
      return Container(
        width: 220, height: 220,
        color: cc.surfaceBackground,
        child: Center(child: CircularProgressIndicator(color: primary)),
      );
    }

    return _placeholder(Icons.image_rounded, cc);
  }

  Widget _buildVideoThumbnail(CircuitChatColors cc) {
    final url = msg.mediaUrl;
    if (url != null && url.isNotEmpty && !url.startsWith('/')) {
      return CachedNetworkImage(
        imageUrl: url,
        width: 220, height: 150, fit: BoxFit.cover,
        errorWidget: (_, __, ___) => _placeholder(Icons.videocam_rounded, cc),
      );
    }
    return _placeholder(Icons.videocam_rounded, cc);
  }

  Widget _placeholder(IconData icon, CircuitChatColors cc) => Container(
        width: 200, height: 140,
        decoration: BoxDecoration(
          color: isMe
              ? Colors.white.withOpacity(0.15)
              : cc.surfaceBackground,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, size: 48,
            color: isMe ? Colors.white38 : cc.secondaryText),
      );
}

// ── Audio bubble with just_audio playback ────────────────────────────────────
class _AudioBubble extends StatefulWidget {
  const _AudioBubble({required this.msg, required this.isMe});
  final MessageModel msg;
  final bool isMe;

  @override
  State<_AudioBubble> createState() => _AudioBubbleState();
}

class _AudioBubbleState extends State<_AudioBubble> {
  final _player = AudioPlayer();
  bool   _playing  = false;
  bool   _loading  = false;
  bool   _error    = false;
  Duration _pos    = Duration.zero;
  Duration _total  = Duration.zero;

  @override
  void initState() {
    super.initState();
    _player.playerStateStream.listen((s) {
      if (!mounted) return;
      final playing = s.playing &&
          s.processingState != ProcessingState.completed;
      setState(() => _playing = playing);
      if (s.processingState == ProcessingState.completed) {
        _player.seek(Duration.zero);
        setState(() { _playing = false; _pos = Duration.zero; });
      }
    });
    _player.positionStream.listen((p) {
      if (mounted) setState(() => _pos = p);
    });
    _player.durationStream.listen((d) {
      if (mounted && d != null) setState(() => _total = d);
    });
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  Future<void> _togglePlay() async {
    final url = widget.msg.mediaUrl;
    if (url == null || url.isEmpty) return;

    if (_playing) {
      await _player.pause();
      return;
    }

    // Load if not already loaded
    if (_player.processingState == ProcessingState.idle ||
        _player.processingState == ProcessingState.completed) {
      setState(() { _loading = true; _error = false; });
      try {
        final isLocal = url.startsWith('/') || url.startsWith('file://');
        if (isLocal) {
          await _player.setFilePath(
              url.replaceFirst('file://', ''));
        } else {
          await _player.setUrl(url);
        }
        if (mounted) setState(() => _loading = false);
      } catch (_) {
        if (mounted) setState(() { _loading = false; _error = true; });
        return;
      }
    }

    await _player.play();
  }

  String _formatDuration(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final isMe    = widget.isMe;
    final cc      = context.cc;
    final primary = Theme.of(context).colorScheme.primary;

    // Use server duration if player hasn't loaded yet
    final serverDur = widget.msg.mediaDuration;
    final displayTotal = _total > Duration.zero
        ? _total
        : (serverDur != null
            ? Duration(seconds: serverDur)
            : Duration.zero);

    final progress = displayTotal.inMilliseconds > 0
        ? (_pos.inMilliseconds / displayTotal.inMilliseconds).clamp(0.0, 1.0)
        : 0.0;

    return Container(
      width: 220,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: isMe
            ? Colors.white.withOpacity(0.15)
            : cc.surfaceBackground,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          // Play / Pause / Loading
          GestureDetector(
            onTap: _loading ? null : _togglePlay,
            child: Container(
              width: 36, height: 36,
              decoration: BoxDecoration(
                color: isMe ? Colors.white24 : primary,
                shape: BoxShape.circle,
              ),
              child: _loading
                  ? const Padding(
                      padding: EdgeInsets.all(8),
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : _error
                      ? const Icon(Icons.error_outline_rounded,
                          color: Colors.white, size: 18)
                      : Icon(
                          _playing
                              ? Icons.pause_rounded
                              : Icons.play_arrow_rounded,
                          color: Colors.white, size: 22),
            ),
          ),
          const SizedBox(width: 8),
          // Progress + waveform
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Progress bar
                ClipRRect(
                  borderRadius: BorderRadius.circular(2),
                  child: LinearProgressIndicator(
                    value: progress.toDouble(),
                    backgroundColor: (isMe
                            ? Colors.white
                            : primary)
                        .withOpacity(0.25),
                    valueColor: AlwaysStoppedAnimation<Color>(
                      isMe ? Colors.white70 : primary,
                    ),
                    minHeight: 3,
                  ),
                ),
                const SizedBox(height: 4),
                // Time display
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      _formatDuration(_pos),
                      style: TextStyle(
                          fontSize: 10,
                          color: isMe
                              ? Colors.white60
                              : cc.secondaryText),
                    ),
                    Text(
                      _formatDuration(displayTotal),
                      style: TextStyle(
                          fontSize: 10,
                          color: isMe
                              ? Colors.white60
                              : cc.secondaryText),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Pinned message banner ─────────────────────────────────────────────────────
class _PinnedBanner extends StatelessWidget {
  const _PinnedBanner({
    required this.message, required this.onTap, required this.onDismiss});
  final MessageModel message;
  final VoidCallback onTap;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final cc = context.cc;
    final primary = Theme.of(context).colorScheme.primary;
    return GestureDetector(
        onTap: onTap,
        child: Container(
          color: cc.cardBackground,
          padding: const EdgeInsets.fromLTRB(16, 6, 8, 6),
          child: Row(
            children: [
              Container(
                width: 3, height: 32,
                decoration: BoxDecoration(
                    color: primary,
                    borderRadius: BorderRadius.circular(2)),
              ),
              const SizedBox(width: 10),
              Icon(Icons.push_pin_rounded,
                  size: 14, color: primary),
              const SizedBox(width: 6),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(AppStrings.pinnedMessage,
                        style: TextStyle(fontSize: 11,
                            color: primary,
                            fontWeight: FontWeight.w600)),
                    Text(
                      message.text ??
                          (message.contentType == ContentType.image
                              ? '📷 Photo'
                              : message.contentType == ContentType.audio
                                  ? '🎵 Audio'
                                  : '📎 Attachment'),
                      maxLines: 1, overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontSize: 12, color: cc.primaryText),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: Icon(Icons.close_rounded,
                    size: 16, color: cc.secondaryText),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                onPressed: onDismiss,
              ),
            ],
          ),
        ),
      );
  }
}

// ── Emoji reaction strip ──────────────────────────────────────────────────────
class _EmojiReactionStrip extends StatelessWidget {
  const _EmojiReactionStrip({required this.onReact});
  final void Function(String) onReact;

  static const _emojis = ['👍', '❤️', '😂', '😮', '😢', '🙏'];

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: _emojis
              .map((e) => GestureDetector(
                    onTap: () => onReact(e),
                    child: Text(e,
                        style: const TextStyle(fontSize: 28)),
                  ))
              .toList(),
        ),
      );
}

// ── Status icon ───────────────────────────────────────────────────────────────
class _StatusIcon extends StatelessWidget {
  const _StatusIcon({required this.status});
  final MessageStatus status;

  @override
  Widget build(BuildContext context) {
    switch (status) {
      case MessageStatus.sending:
        return const Icon(Icons.access_time_rounded,
            size: 13, color: Colors.white70);
      case MessageStatus.sent:
        return const Icon(Icons.check_rounded,
            size: 14, color: Colors.white70);
      case MessageStatus.delivered:
        return const Icon(Icons.done_all_rounded,
            size: 14, color: Colors.white70);
      case MessageStatus.seen:
        return const Icon(Icons.done_all_rounded,
            size: 14, color: Colors.white);
      case MessageStatus.failed:
        return const Icon(Icons.error_outline_rounded,
            size: 13, color: Color(0xFFFFCDD2));
      default:
        return const SizedBox.shrink();
    }
  }
}

// ── Reactions row ─────────────────────────────────────────────────────────────
class _ReactionsRow extends StatelessWidget {
  const _ReactionsRow({required this.msg});
  final MessageModel msg;

  @override
  Widget build(BuildContext context) {
    final cc = context.cc;
    final grouped = <String, int>{};
    for (final r in msg.reactions) {
      grouped[r.reaction] = (grouped[r.reaction] ?? 0) + 1;
    }
    return Padding(
      padding: const EdgeInsets.only(top: 2),
      child: Wrap(
        spacing: 4,
        children: grouped.entries.map((e) => Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: cc.cardBackground,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: cc.border),
            boxShadow: [BoxShadow(
                color: Colors.black.withOpacity(0.04), blurRadius: 2)],
          ),
          child: Text('${e.key} ${e.value}',
              style: TextStyle(fontSize: 12, color: cc.primaryText)),
        )).toList(),
      ),
    );
  }
}

// ── Message text with @mention highlighting ───────────────────────────────────
/// Mirrors RN content.js mention resolution:
///   message.text.replace(`@${mention._id}`, `@${mention.name}`)
/// In Flutter we build a RichText with highlighted mention spans.
class _MessageText extends StatelessWidget {
  const _MessageText({
    required this.text,
    required this.mentions,
    required this.textColor,
    required this.isMe,
  });

  final String                text;
  final List<MessageMention>  mentions;
  final Color                 textColor;
  final bool                  isMe;

  @override
  Widget build(BuildContext context) {
    if (mentions.isEmpty) {
      return Text(text,
          style: TextStyle(fontSize: 15, color: textColor, height: 1.4));
    }

    // Resolve @userId → @name for each mention
    // Build a map: userId → displayName
    final mentionMap = {
      for (final m in mentions) m.id: m.name,
    };

    // Split text on @userId patterns and build TextSpans
    final spans = <TextSpan>[];
    var remaining = text;

    // Sort mentions by their position in the text to process in order
    final mentionPattern = RegExp(r'@([a-zA-Z0-9_]+)');
    final matches = mentionPattern.allMatches(text).toList();

    if (matches.isEmpty) {
      return Text(text,
          style: TextStyle(fontSize: 15, color: textColor, height: 1.4));
    }

    int lastEnd = 0;
    for (final match in matches) {
      // Add text before this mention
      if (match.start > lastEnd) {
        spans.add(TextSpan(
          text: text.substring(lastEnd, match.start),
          style: TextStyle(fontSize: 15, color: textColor, height: 1.4),
        ));
      }

      final userId = match.group(1) ?? '';
      final displayName = mentionMap[userId] ?? userId;

      // Highlight the mention
      spans.add(TextSpan(
        text: '@$displayName',
        style: TextStyle(
          fontSize: 15,
          height: 1.4,
          color: isMe ? Colors.white : const Color(0xFF1877F2),
          fontWeight: FontWeight.w600,
        ),
      ));

      lastEnd = match.end;
    }

    // Add remaining text after last mention
    if (lastEnd < text.length) {
      spans.add(TextSpan(
        text: text.substring(lastEnd),
        style: TextStyle(fontSize: 15, color: textColor, height: 1.4),
      ));
    }

    return RichText(text: TextSpan(children: spans));
  }
}

// ── Typing dot ────────────────────────────────────────────────────────────────
class _TypingDot extends StatefulWidget {
  const _TypingDot({required this.delay});
  final Duration delay;

  @override
  State<_TypingDot> createState() => _TypingDotState();
}

class _TypingDotState extends State<_TypingDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double>    _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this,
        duration: const Duration(milliseconds: 600));
    Future.delayed(widget.delay, () {
      if (mounted) _ctrl.repeat(reverse: true);
    });
    _anim = Tween<double>(begin: 0, end: -6)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final cc = context.cc;
    return AnimatedBuilder(
        animation: _anim,
        builder: (_, __) => Transform.translate(
          offset: Offset(0, _anim.value),
          child: Container(
            width: 7, height: 7,
            margin: const EdgeInsets.symmetric(horizontal: 2),
            decoration: BoxDecoration(
                color: cc.secondaryText, shape: BoxShape.circle),
          ),
        ),
      );
  }
}

// ── Helpers ───────────────────────────────────────────────────────────────────

/// Formats a last-seen ISO timestamp into a human-readable string.
/// Mirrors RN's `moment(lastActive).fromNow()`.
/// Returns a human-readable relative time string matching RN's
/// `moment(date).fromNow()` — e.g. "just now", "2 minutes ago", "3 hours ago".
String _fromNow(String iso) {
  try {
    final dt   = DateTime.parse(iso).toLocal();
    final diff = DateTime.now().difference(dt);
    if (diff.inSeconds < 60)  return 'just now';
    if (diff.inMinutes < 60)  return '${diff.inMinutes} minute${diff.inMinutes == 1 ? '' : 's'} ago';
    if (diff.inHours   < 24)  return '${diff.inHours} hour${diff.inHours == 1 ? '' : 's'} ago';
    if (diff.inDays    < 7)   return '${diff.inDays} day${diff.inDays == 1 ? '' : 's'} ago';
    return '${(diff.inDays / 7).floor()} week${(diff.inDays / 7).floor() == 1 ? '' : 's'} ago';
  } catch (_) {
    return '';
  }
}

// Keep for any other callers that use old naming
String _formatLastSeen(String iso) => _fromNow(iso);

// ── Compact AppBar icon button ────────────────────────────────────────────────

/// Tighter than [IconButton] — reduces horizontal padding so 4 icons
/// fit comfortably in the AppBar without crowding the title.
class _AppBarIcon extends StatelessWidget {
  const _AppBarIcon({
    required this.icon,
    required this.color,
    required this.onTap,
    this.tooltip = '',
  });

  final IconData icon;
  final Color    color;
  final VoidCallback onTap;
  final String   tooltip;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          // 6 px horizontal instead of the default 12 px → tighter spacing
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
          child: Icon(icon, color: color, size: 22),
        ),
      ),
    );
  }
}

// ── Chat option actions (mirrors RN components/options.js) ────────────────────

enum _ChatOptionAction {
  chatInfo,
  archive, unarchive,
  pin,     unpin,
  mute,    unmute,
  markRead, markUnread,
  block,   unblock,
  exitGroup,
  delete,
  report,
}

/// State-driven options bottom sheet — every item reflects the current
/// ChatModel state (archived, pinned, muted, blocked) exactly like RN.
class _ChatOptionsSheet extends ConsumerWidget {
  const _ChatOptionsSheet({
    required this.chat,
    required this.onClose,
    required this.onAction,
  });

  final ChatModel chat;
  final VoidCallback onClose;
  final void Function(_ChatOptionAction) onAction;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cc       = context.cc;
    final isGroup  = chat.type == ChatType.group;

    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle
          const SizedBox(height: 8),
          Center(
            child: Container(
              width: 36, height: 4,
              decoration: BoxDecoration(
                  color: cc.border,
                  borderRadius: BorderRadius.circular(2)),
            ),
          ),
          const SizedBox(height: 4),

          // Chat Info — always shown
          _OptionTile(
            icon:  Icons.person_outline_rounded,
            label: isGroup ? AppStrings.groupInfo : AppStrings.chatInfo,
            onTap: () => onAction(_ChatOptionAction.chatInfo),
          ),

          // Archive / Unarchive — state-driven
          if (chat.isArchived)
            _OptionTile(
              icon:  Icons.unarchive_outlined,
              label: AppStrings.unarchive,
              onTap: () => onAction(_ChatOptionAction.unarchive),
            )
          else
            _OptionTile(
              icon:  Icons.archive_outlined,
              label: AppStrings.archive,
              onTap: () => onAction(_ChatOptionAction.archive),
            ),

          // Pin / Unpin — state-driven (only when not archived)
          if (!chat.isArchived)
            chat.isPinned
                ? _OptionTile(
                    icon:  Icons.push_pin_outlined,
                    label: AppStrings.unpin,
                    onTap: () => onAction(_ChatOptionAction.unpin),
                  )
                : _OptionTile(
                    icon:  Icons.push_pin_rounded,
                    label: AppStrings.pin,
                    onTap: () => onAction(_ChatOptionAction.pin),
                  ),

          // Mute / Unmute — state-driven
          if (!chat.isArchived)
            chat.isMuted
                ? _OptionTile(
                    icon:  Icons.volume_up_outlined,
                    label: AppStrings.unmute,
                    onTap: () => onAction(_ChatOptionAction.unmute),
                  )
                : _OptionTile(
                    icon:  Icons.volume_off_outlined,
                    label: AppStrings.mute,
                    onTap: () => onAction(_ChatOptionAction.mute),
                  ),

          // Mark Read / Unread — state-driven
          if (chat.unreadCount > 0)
            _OptionTile(
              icon:  Icons.mark_email_read_outlined,
              label: AppStrings.markAsRead,
              onTap: () => onAction(_ChatOptionAction.markRead),
            )
          else
            _OptionTile(
              icon:  Icons.mark_email_unread_outlined,
              label: AppStrings.markAsUnread,
              onTap: () => onAction(_ChatOptionAction.markUnread),
            ),

          // Block / Unblock — direct chats only, state-driven
          if (!isGroup)
            chat.isBlockedByMe
                ? _OptionTile(
                    icon:  Icons.block_flipped,
                    label: AppStrings.unblock,
                    onTap: () => onAction(_ChatOptionAction.unblock),
                  )
                : _OptionTile(
                    icon:  Icons.block_rounded,
                    label: AppStrings.block,
                    onTap: () => onAction(_ChatOptionAction.block),
                  ),

          // Exit Group — group chats only
          if (isGroup)
            _OptionTile(
              icon:  Icons.exit_to_app_rounded,
              label: AppStrings.exitGroup,
              color: const Color(0xFFE53935),
              onTap: () => onAction(_ChatOptionAction.exitGroup),
            ),

          // Delete — always shown
          _OptionTile(
            icon:  Icons.delete_outline_rounded,
            label: AppStrings.deleteChat,
            color: const Color(0xFFE53935),
            onTap: () => onAction(_ChatOptionAction.delete),
          ),

          // Report — always shown (static — not driven by backend)
          _OptionTile(
            icon:  Icons.flag_outlined,
            label: AppStrings.report,
            color: const Color(0xFFE53935),
            onTap: () => onAction(_ChatOptionAction.report),
          ),

          // Cancel
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: onClose,
                style: OutlinedButton.styleFrom(
                  foregroundColor: cc.secondaryText,
                  side: BorderSide(color: cc.border),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
                child: const Text(AppStrings.cancel),
              ),
            ),
          ),
          const SizedBox(height: 4),
        ],
      ),
    );
  }
}

class _OptionTile extends StatelessWidget {
  const _OptionTile({
    required this.icon,
    required this.label,
    required this.onTap,
    this.color,
  });

  final IconData icon;
  final String   label;
  final VoidCallback onTap;
  final Color?   color;

  @override
  Widget build(BuildContext context) {
    final cc = context.cc;
    final c = color ?? cc.primaryText;
    return ListTile(
      onTap: onTap,
      leading: Icon(icon, color: c, size: 22),
      title: Text(label,
          style: TextStyle(fontSize: 15, color: c, fontWeight: FontWeight.w500)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 20),
      dense: true,
    );
  }
}
