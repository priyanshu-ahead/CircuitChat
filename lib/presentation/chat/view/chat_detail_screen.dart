import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/di/providers.dart';
import '../../../core/network/api_endpoints.dart';
import '../../../core/router/app_router.dart';
import '../../../data/models/chat_model.dart';
import '../../../data/models/message_model.dart';
import '../../../presentation/app_init/app_init_viewmodel.dart';
import '../../../presentation/auth/viewmodel/auth_viewmodel.dart';
import '../../../presentation/chat/viewmodel/chat_list_viewmodel.dart';
import '../../../presentation/common/widgets/forward_message_sheet.dart';
import '../../../presentation/common/widgets/shimmer_list.dart';
import '../../../data/repositories/group_repository.dart';
import '../viewmodel/message_viewmodel.dart';

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
  bool _showScrollToBottom = false;
  bool _isRecording  = false;
  bool _searchMode   = false;
  String? _recordingPath;

  String? get _currentUserId => ref.read(authViewModelProvider).user?.id;

  /// '0' = direct, '1' = group — matches RN CHAT_TYPE / SE backend
  MessageVmArg get _vmArg => (
        chatId:   widget.chat.id,
        chatType: widget.chat.type == ChatType.group ? '1' : '0',
      );

  @override
  void initState() {
    super.initState();
    _textCtrl.addListener(() => setState(() {}));
    _scrollCtrl.addListener(_onScroll);
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
      final chatType = widget.chat.type == ChatType.group ? '1' : '0';
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

  PreferredSize _buildSearchBar() {
    return PreferredSize(
      preferredSize: const Size.fromHeight(52),
      child: Container(
        color: Colors.white,
        padding: const EdgeInsets.fromLTRB(8, 6, 8, 8),
        child: Row(
          children: [
            IconButton(
              icon: const Icon(Icons.arrow_back_rounded,
                  color: Color(0xFF1A1A2E)),
              onPressed: () {
                setState(() { _searchMode = false; _searchCtrl.clear(); });
                ref.read(messageViewModelProvider(_vmArg).notifier)
                    .clearSearch();
              },
            ),
            Expanded(
              child: TextField(
                controller: _searchCtrl,
                autofocus: true,
                decoration: InputDecoration(
                  hintText: 'Search messages…',
                  filled: true,
                  fillColor: const Color(0xFFF2F4F8),
                  contentPadding: const EdgeInsets.symmetric(
                      vertical: 8, horizontal: 14),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: BorderSide.none,
                  ),
                  suffixIcon: _searchCtrl.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.close_rounded, size: 18),
                          onPressed: () {
                            _searchCtrl.clear();
                            ref.read(messageViewModelProvider(_vmArg)
                                .notifier).clearSearch();
                          })
                      : null,
                ),
                onChanged: (q) {
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
          ],
        ),
      ),
    );
  }

  // ── Chat options bottom sheet ─────────────────────────────────────────────
  // All items mirror RN's components/options.js Menus component.
  // Items are STATE-DRIVEN from the ChatModel (archive, pin, mute, blocked).
  // Only Report is "static" (always shown).

  void _showChatOptions(ChatModel chat) {
    showModalBottomSheet(
      context: context,
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
              'chatType': chat.type == ChatType.group ? '1' : '0'}]);
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
              chat.type == ChatType.group ? '1' : '0');
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
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
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
    showModalBottomSheet(
      context: context,
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
                    color: const Color(0xFFCCCCCC),
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
    final hasPermission = await _recorder.hasPermission();
    if (!hasPermission) return;
    final dir  = await getTemporaryDirectory();
    final path = '${dir.path}/audio_${DateTime.now().millisecondsSinceEpoch}.m4a';
    await _recorder.start(const RecordConfig(), path: path);
    setState(() { _isRecording = true; _recordingPath = path; });
  }

  Future<void> _stopAndSendRecording() async {
    final path = await _recorder.stop();
    setState(() => _isRecording = false);
    if (path == null || path.isEmpty) return;
    _sendMedia(localPath: path, type: MessageType.audio);
  }

  Future<void> _cancelRecording() async {
    await _recorder.stop();
    final p = _recordingPath;
    setState(() { _isRecording = false; _recordingPath = null; });
    if (p != null) {
      try { await File(p).delete(); } catch (_) {}
    }
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final msgState = ref.watch(messageViewModelProvider(_vmArg));
    return Scaffold(
      backgroundColor: const Color(0xFFF0F4F8),
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
          Expanded(child: _buildMessageList(msgState)),
          if (msgState.isTyping) _buildTypingIndicator(),
          if (msgState.replyTo != null)
            _buildReplyPreview(msgState.replyTo!),
          _buildInputBar(),
        ],
      ),
      floatingActionButton: _showScrollToBottom
          ? FloatingActionButton.small(
              onPressed: _scrollToBottom,
              backgroundColor: Colors.white,
              child: const Icon(Icons.keyboard_arrow_down_rounded,
                  color: Color(0xFF1976D2)))
          : null,
    );
  }

  // ── AppBar ────────────────────────────────────────────────────────────────

  PreferredSizeWidget _buildAppBar(MessageState msgState) {
    final agoraEnabled = ref.read(appInitProvider).agoraEnabled;
    final chatState    = ref.read(chatListViewModelProvider).chats
        .where((c) => c.id == widget.chat.id)
        .firstOrNull ?? widget.chat;

    debugPrint("check agora enabled or not : $agoraEnabled");
    return AppBar(
      backgroundColor: Colors.white,
      elevation: 0,
      titleSpacing: 0,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_rounded, color: Color(0xFF1A1A2E)),
        onPressed: () => Navigator.pop(context),
      ),
      title: GestureDetector(
        onTap: () => context.push(
            Routes.chatProfile.replaceFirst(':chatId', widget.chat.id),
            extra: widget.chat),
        child: Row(
          children: [
            Stack(
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor: const Color(0xFFDDE4EF),
                  backgroundImage: widget.chat.avatar != null
                      ? NetworkImage(widget.chat.avatar!) : null,
                  child: widget.chat.avatar == null
                      ? Icon(
                          widget.chat.type == ChatType.group
                              ? Icons.group_rounded : Icons.person_rounded,
                          color: const Color(0xFF9AA6B8), size: 20)
                      : null,
                ),
                if (widget.chat.isOnline && widget.chat.type == ChatType.direct)
                  Positioned(
                    right: 1, bottom: 1,
                    child: Container(
                      width: 9, height: 9,
                      decoration: BoxDecoration(
                        color: const Color(0xFF4CAF50),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 1.5),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(widget.chat.name ?? 'Chat',
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w700,
                          color: Color(0xFF1A1A2E)),
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                  if (msgState.isTyping)
                    const Text('typing…',
                        style: TextStyle(fontSize: 12,
                            color: Color(0xFF1976D2),
                            fontStyle: FontStyle.italic))
                  else if (widget.chat.isOnline &&
                      widget.chat.type == ChatType.direct)
                    const Text('Online',
                        style: TextStyle(fontSize: 12,
                            color: Color(0xFF4CAF50))),
                ],
              ),
            ),
          ],
        ),
      ),
      // ── Header icons order: call → video → search → options ────────────
      actions: [
        // Audio call (only when Agora enabled)
        if (agoraEnabled)
          IconButton(
            icon: const Icon(Icons.call_outlined, color: Color(0xFF1A1A2E)),
            tooltip: 'Voice Call',
            onPressed: () => _initiateCall(callType: 'audio'),
          ),
        // Video call (only when Agora enabled)
        if (agoraEnabled)
          IconButton(
            icon: const Icon(Icons.videocam_outlined, color: Color(0xFF1A1A2E)),
            tooltip: 'Video Call',
            onPressed: () => _initiateCall(callType: 'video'),
          ),
        // Search in chat
        IconButton(
          icon: const Icon(Icons.search_rounded, color: Color(0xFF1A1A2E)),
          tooltip: 'Search',
          onPressed: () => setState(() => _searchMode = true),
        ),
        // Options menu (⋮)
        IconButton(
          icon: const Icon(Icons.more_vert_rounded, color: Color(0xFF1A1A2E)),
          tooltip: 'Options',
          onPressed: () => _showChatOptions(chatState),
        ),
      ],
      bottom: _searchMode
          ? _buildSearchBar()
          : const PreferredSize(
              preferredSize: Size.fromHeight(0.5),
              child: Divider(height: 0, color: Color(0xFFEEEEEE))),
    );
  }

  // ── Message list ──────────────────────────────────────────────────────────

  Widget _buildMessageList(MessageState msgState) {
    if (msgState.isLoading) return const MessageShimmerList();

    if (msgState.status == MessageStatus2.error) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline_rounded,
                size: 48, color: Color(0xFF9AA6B8)),
            const SizedBox(height: 8),
            Text(msgState.errorMessage ?? 'Failed to load messages.',
                style: const TextStyle(color: Color(0xFF9AA6B8))),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: () => ref
                  .read(messageViewModelProvider(_vmArg).notifier)
                  .reload(),
              style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1976D2),
                  foregroundColor: Colors.white),
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    final messages = msgState.messages;
    if (messages.isEmpty) {
      return const Center(
        child: Text('No messages yet.\nSay hello! 👋',
            textAlign: TextAlign.center,
            style: TextStyle(color: Color(0xFF9AA6B8), fontSize: 15)),
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
          return const Padding(
            padding: EdgeInsets.only(top: 8),
            child: Center(
              child: SizedBox(width: 24, height: 24,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Color(0xFF1976D2))),
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
              ),
            if (showDate) _DateDivider(iso: msg.createdAt),
          ],
        );
      },
    );
  }

  // ── Typing indicator ──────────────────────────────────────────────────────

  Widget _buildTypingIndicator() {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.fromLTRB(16, 4, 80, 4),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white,
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
    return Container(
      color: const Color(0xFFF2F4F8),
      padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
      child: Row(
        children: [
          Container(
            width: 3, height: 36,
            decoration: BoxDecoration(
                color: const Color(0xFF1976D2),
                borderRadius: BorderRadius.circular(2)),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Reply',
                    style: TextStyle(fontSize: 12, color: Color(0xFF1976D2),
                        fontWeight: FontWeight.w600)),
                Text(replyTo.text ?? _contentLabel(replyTo.contentType),
                    maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 13, color: Color(0xFF666666))),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close_rounded,
                size: 18, color: Color(0xFF9AA6B8)),
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
    final hasText = _textCtrl.text.trim().isNotEmpty;

    if (_isRecording) {
      return Container(
        color: Colors.white,
        padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
        child: SafeArea(
          top: false,
          child: Row(
            children: [
              // Cancel
              IconButton(
                icon: const Icon(Icons.delete_outline_rounded,
                    color: Color(0xFFE53935)),
                onPressed: _cancelRecording,
              ),
              // Recording indicator
              Expanded(
                child: Container(
                  height: 44,
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF3F3),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: const Color(0xFFE53935).withOpacity(0.3)),
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.mic_rounded, color: Color(0xFFE53935), size: 18),
                      SizedBox(width: 8),
                      Text('Recording…',
                          style: TextStyle(color: Color(0xFFE53935),
                              fontSize: 14, fontWeight: FontWeight.w500)),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              // Send recording
              GestureDetector(
                onTap: _stopAndSendRecording,
                child: Container(
                  width: 44, height: 44,
                  decoration: const BoxDecoration(
                      color: Color(0xFF1976D2), shape: BoxShape.circle),
                  child: const Icon(Icons.send_rounded,
                      color: Colors.white, size: 22),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
      child: SafeArea(
        top: false,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            // Attach
            IconButton(
              icon: const Icon(Icons.attach_file_rounded,
                  color: Color(0xFF9AA6B8)),
              onPressed: _showAttachMenu,
            ),
            // Text field
            Expanded(
              child: Container(
                constraints: const BoxConstraints(maxHeight: 120),
                decoration: BoxDecoration(
                  color: const Color(0xFFF2F4F8),
                  borderRadius: BorderRadius.circular(24),
                ),
                child: TextField(
                  controller: _textCtrl,
                  maxLines: null,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(
                    hintText: 'Message…',
                    hintStyle: TextStyle(
                        color: Color(0xFF9AA6B8), fontSize: 15),
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(
                        horizontal: 16, vertical: 10),
                  ),
                  onSubmitted: (_) => _sendText(),
                ),
              ),
            ),
            const SizedBox(width: 8),
            // Send / Mic
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              child: GestureDetector(
                key: ValueKey(hasText),
                onTap: hasText ? _sendText : null,
                onLongPress: hasText ? null : _startRecording,
                child: Container(
                  width: 44, height: 44,
                  decoration: BoxDecoration(
                    color: hasText
                        ? const Color(0xFF1976D2)
                        : const Color(0xFFF2F4F8),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    hasText ? Icons.send_rounded : Icons.mic_none_rounded,
                    color: hasText ? Colors.white : const Color(0xFF9AA6B8),
                    size: 22,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Message context menu ──────────────────────────────────────────────────

  void _showMessageMenu(MessageModel msg) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(width: 40, height: 4,
                decoration: BoxDecoration(color: Colors.grey[300],
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
            const Divider(height: 1),
            if (!msg.isDeleted) ...[
              ListTile(
                leading: const Icon(Icons.reply_rounded,
                    color: Color(0xFF1976D2)),
                title: const Text('Reply'),
                onTap: () {
                  Navigator.pop(context);
                  ref.read(messageViewModelProvider(_vmArg).notifier)
                      .setReplyTo(msg);
                },
              ),
              if (msg.text != null && msg.text!.isNotEmpty)
                ListTile(
                  leading: const Icon(Icons.copy_rounded,
                      color: Color(0xFF1976D2)),
                  title: const Text('Copy'),
                  onTap: () {
                    Navigator.pop(context);
                    Clipboard.setData(ClipboardData(text: msg.text!));
                    ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Copied')));
                  },
                ),
              ListTile(
                leading: Icon(
                  msg.isStarred
                      ? Icons.star_rounded : Icons.star_border_rounded,
                  color: msg.isStarred
                      ? const Color(0xFFFFC107) : const Color(0xFF1976D2),
                ),
                title: Text(msg.isStarred ? 'Unstar' : 'Star'),
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
                leading: const Icon(Icons.forward_rounded,
                    color: Color(0xFF1976D2)),
                title: const Text('Forward'),
                onTap: () {
                  Navigator.pop(context);
                  ForwardMessageSheet.show(context, messageIds: [msg.id]);
                },
              ),
              ListTile(
                leading: Icon(
                  msg.pinned != null
                      ? Icons.push_pin_outlined : Icons.push_pin_rounded,
                  color: const Color(0xFF1976D2),
                ),
                title: Text(msg.pinned != null ? 'Unpin' : 'Pin'),
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
                  leading: const Icon(Icons.info_outline_rounded,
                      color: Color(0xFF1976D2)),
                  title: const Text('Message Info'),
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
              title: const Text('Delete',
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
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            const Text('Delete Message',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            ListTile(
              leading: const Icon(Icons.delete_outline_rounded,
                  color: Color(0xFFEF4444)),
              title: const Text('Delete for Me'),
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
                title: const Text('Delete for Everyone'),
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
              style: const TextStyle(fontSize: 12, color: Color(0xFF666666))),
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
    String label;
    try {
      final dt  = DateTime.parse(iso).toLocal();
      final now = DateTime.now();
      if (dt.year == now.year && dt.month == now.month && dt.day == now.day) {
        label = 'Today';
      } else {
        final y = now.subtract(const Duration(days: 1));
        if (dt.year == y.year && dt.month == y.month && dt.day == y.day) {
          label = 'Yesterday';
        } else {
          label = DateFormat('MMMM d, yyyy').format(dt);
        }
      }
    } catch (_) { label = ''; }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.06),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(label,
              style: const TextStyle(fontSize: 12, color: Color(0xFF666666))),
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
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Center(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.06),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(msg.text ?? '',
                style: const TextStyle(fontSize: 12, color: Color(0xFF666666)),
                textAlign: TextAlign.center),
          ),
        ),
      );
}

// ── Message bubble ────────────────────────────────────────────────────────────
class _MessageBubble extends StatelessWidget {
  const _MessageBubble({
    required this.msg,
    required this.onLongPress,
    required this.onReply,
  });
  final MessageModel msg;
  final VoidCallback onLongPress;
  final VoidCallback onReply;

  static const _bubbleMe    = Color(0xFF1976D2);
  static const _bubbleOther = Colors.white;

  @override
  Widget build(BuildContext context) {
    final isMe = msg.fromMe;
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
                  color: isMe ? _bubbleMe : _bubbleOther,
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
                      Text('This message was deleted',
                          style: TextStyle(fontSize: 14,
                              fontStyle: FontStyle.italic,
                              color: isMe
                                  ? Colors.white70
                                  : const Color(0xFF9AA6B8)))
                    else if (msg.contentType == ContentType.text)
                      Text(msg.text ?? '',
                          style: TextStyle(fontSize: 15,
                              color: isMe ? Colors.white : const Color(0xFF1A1A2E),
                              height: 1.4))
                    else
                      _MediaContent(msg: msg, isMe: isMe),

                    const SizedBox(height: 4),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(_formatTime(msg.createdAt),
                            style: TextStyle(fontSize: 11,
                                color: isMe
                                    ? Colors.white70
                                    : const Color(0xFF9AA6B8))),
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
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.only(bottom: 4),
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: isMe
              ? Colors.white.withOpacity(0.15)
              : const Color(0xFFF0F4F8),
          borderRadius: BorderRadius.circular(10),
          border: const Border(
              left: BorderSide(color: Color(0xFF1976D2), width: 3)),
        ),
        child: Text(reply.text ?? '📎 Media',
            maxLines: 2, overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 12,
                color: isMe ? Colors.white70 : const Color(0xFF666666))),
      );
}

// ── Media content ─────────────────────────────────────────────────────────────
class _MediaContent extends StatelessWidget {
  const _MediaContent({required this.msg, required this.isMe});
  final MessageModel msg;
  final bool isMe;

  @override
  Widget build(BuildContext context) {
    switch (msg.contentType) {
      case ContentType.image:
        return GestureDetector(
          onTap: () => _openFullScreen(context, msg.mediaUrl!),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: msg.mediaUrl != null
                ? CachedNetworkImage(
                    imageUrl: msg.mediaUrl!,
                    width: 220, height: 220, fit: BoxFit.cover,
                    placeholder: (_, __) => Container(
                        width: 220, height: 220,
                        color: const Color(0xFFEEEEEE),
                        child: const Center(
                            child: CircularProgressIndicator())),
                    errorWidget: (_, __, ___) =>
                        _placeholder(Icons.broken_image_rounded),
                  )
                : _placeholder(Icons.image_rounded),
          ),
        );

      case ContentType.video:
        return GestureDetector(
          onTap: () {
            if (msg.mediaUrl != null) {
              launchUrl(Uri.parse(msg.mediaUrl!));
            }
          },
          child: Stack(
            alignment: Alignment.center,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: msg.mediaUrl != null
                    ? CachedNetworkImage(
                        imageUrl: msg.mediaUrl!,
                        width: 220, height: 150, fit: BoxFit.cover,
                        errorWidget: (_, __, ___) =>
                            _placeholder(Icons.videocam_rounded),
                      )
                    : _placeholder(Icons.videocam_rounded),
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
                  : const Color(0xFFF0F4F8),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.insert_drive_file_rounded,
                    color: isMe ? Colors.white : const Color(0xFF1976D2),
                    size: 28),
                const SizedBox(width: 8),
                Flexible(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(msg.mediaUrl?.split('/').last ?? 'file',
                          style: TextStyle(fontSize: 13,
                              fontWeight: FontWeight.w500,
                              color: isMe ? Colors.white : Colors.black87),
                          maxLines: 2, overflow: TextOverflow.ellipsis),
                      if (msg.mediaSize != null)
                        Text(
                            '${(msg.mediaSize! / 1024).toStringAsFixed(1)} KB',
                            style: TextStyle(fontSize: 11,
                                color: isMe
                                    ? Colors.white70
                                    : const Color(0xFF888888))),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Icon(Icons.download_rounded,
                    color: isMe ? Colors.white70 : const Color(0xFF1976D2),
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
                  : const Color(0xFFF0F4F8),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                  color: isMe ? Colors.white24 : const Color(0xFFDDDDDD)),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.location_on_rounded,
                    color: Color(0xFFE53935), size: 30),
                const SizedBox(height: 4),
                Text('View Location',
                    style: TextStyle(fontSize: 12,
                        color: isMe
                            ? Colors.white70
                            : const Color(0xFF1976D2))),
              ],
            ),
          ),
        );

      default:
        return Text(msg.text ?? '',
            style: TextStyle(
                color: isMe ? Colors.white : const Color(0xFF1A1A2E)));
    }
  }

  void _openFullScreen(BuildContext context, String url) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => Scaffold(
          backgroundColor: Colors.black,
          appBar: AppBar(backgroundColor: Colors.black,
              foregroundColor: Colors.white, elevation: 0),
          body: Center(
            child: InteractiveViewer(
              child: CachedNetworkImage(imageUrl: url, fit: BoxFit.contain),
            ),
          ),
        ),
      ),
    );
  }

  Widget _placeholder(IconData icon) => Container(
        width: 200, height: 140,
        decoration: BoxDecoration(
          color: isMe
              ? Colors.white.withOpacity(0.15)
              : const Color(0xFFF0F4F8),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, size: 48,
            color: isMe ? Colors.white38 : const Color(0xFFCCCCCC)),
      );
}

// ── Audio bubble ──────────────────────────────────────────────────────────────
class _AudioBubble extends StatefulWidget {
  const _AudioBubble({required this.msg, required this.isMe});
  final MessageModel msg;
  final bool isMe;

  @override
  State<_AudioBubble> createState() => _AudioBubbleState();
}

class _AudioBubbleState extends State<_AudioBubble> {
  bool _playing = false;

  @override
  Widget build(BuildContext context) {
    final isMe = widget.isMe;
    final dur  = widget.msg.mediaDuration;
    final label = dur != null
        ? '${(dur ~/ 60).toString().padLeft(2, '0')}:'
          '${(dur % 60).toString().padLeft(2, '0')}'
        : '0:00';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: isMe
            ? Colors.white.withOpacity(0.15)
            : const Color(0xFFF0F4F8),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          GestureDetector(
            onTap: () {
              setState(() => _playing = !_playing);
              // Wire just_audio here when available
            },
            child: Container(
              width: 36, height: 36,
              decoration: BoxDecoration(
                color: isMe ? Colors.white24 : const Color(0xFF1976D2),
                shape: BoxShape.circle,
              ),
              child: Icon(
                _playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
                color: Colors.white, size: 20),
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 100,
            height: 24,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: List.generate(14, (i) {
                final h = 4.0 + (i % 3) * 6.0 + (i % 5) * 2.0;
                return Container(
                  width: 2,
                  height: h.clamp(4.0, 18.0),
                  decoration: BoxDecoration(
                    color: isMe
                        ? Colors.white54
                        : const Color(0xFF1976D2),
                    borderRadius: BorderRadius.circular(1),
                  ),
                );
              }),
            ),
          ),
          const SizedBox(width: 8),
          Text(label,
              style: TextStyle(fontSize: 11,
                  color: isMe ? Colors.white70 : const Color(0xFF888888))),
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
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Container(
          color: Colors.white,
          padding: const EdgeInsets.fromLTRB(16, 6, 8, 6),
          child: Row(
            children: [
              Container(
                width: 3, height: 32,
                decoration: BoxDecoration(
                    color: const Color(0xFF1976D2),
                    borderRadius: BorderRadius.circular(2)),
              ),
              const SizedBox(width: 10),
              const Icon(Icons.push_pin_rounded,
                  size: 14, color: Color(0xFF1976D2)),
              const SizedBox(width: 6),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('Pinned Message',
                        style: TextStyle(fontSize: 11,
                            color: Color(0xFF1976D2),
                            fontWeight: FontWeight.w600)),
                    Text(
                      message.text ??
                          (message.contentType == ContentType.image
                              ? '📷 Photo'
                              : message.contentType == ContentType.audio
                                  ? '🎵 Audio'
                                  : '📎 Attachment'),
                      maxLines: 1, overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 12, color: Color(0xFF444444)),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close_rounded,
                    size: 16, color: Color(0xFF888888)),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                onPressed: onDismiss,
              ),
            ],
          ),
        ),
      );
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
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFEEEEEE)),
            boxShadow: [BoxShadow(
                color: Colors.black.withOpacity(0.04), blurRadius: 2)],
          ),
          child: Text('${e.key} ${e.value}',
              style: const TextStyle(fontSize: 12)),
        )).toList(),
      ),
    );
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
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: _anim,
        builder: (_, __) => Transform.translate(
          offset: Offset(0, _anim.value),
          child: Container(
            width: 7, height: 7,
            margin: const EdgeInsets.symmetric(horizontal: 2),
            decoration: const BoxDecoration(
                color: Color(0xFF9AA6B8), shape: BoxShape.circle),
          ),
        ),
      );
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
                  color: const Color(0xFFCCCCCC),
                  borderRadius: BorderRadius.circular(2)),
            ),
          ),
          const SizedBox(height: 4),

          // Chat Info — always shown
          _OptionTile(
            icon:  Icons.person_outline_rounded,
            label: isGroup ? 'Group Info' : 'Chat Info',
            onTap: () => onAction(_ChatOptionAction.chatInfo),
          ),

          // Archive / Unarchive — state-driven
          if (chat.isArchived)
            _OptionTile(
              icon:  Icons.unarchive_outlined,
              label: 'Unarchive',
              onTap: () => onAction(_ChatOptionAction.unarchive),
            )
          else
            _OptionTile(
              icon:  Icons.archive_outlined,
              label: 'Archive',
              onTap: () => onAction(_ChatOptionAction.archive),
            ),

          // Pin / Unpin — state-driven (only when not archived)
          if (!chat.isArchived)
            chat.isPinned
                ? _OptionTile(
                    icon:  Icons.push_pin_outlined,
                    label: 'Unpin',
                    onTap: () => onAction(_ChatOptionAction.unpin),
                  )
                : _OptionTile(
                    icon:  Icons.push_pin_rounded,
                    label: 'Pin',
                    onTap: () => onAction(_ChatOptionAction.pin),
                  ),

          // Mute / Unmute — state-driven
          if (!chat.isArchived)
            chat.isMuted
                ? _OptionTile(
                    icon:  Icons.volume_up_outlined,
                    label: 'Unmute',
                    onTap: () => onAction(_ChatOptionAction.unmute),
                  )
                : _OptionTile(
                    icon:  Icons.volume_off_outlined,
                    label: 'Mute',
                    onTap: () => onAction(_ChatOptionAction.mute),
                  ),

          // Mark Read / Unread — state-driven
          if (chat.unreadCount > 0)
            _OptionTile(
              icon:  Icons.mark_email_read_outlined,
              label: 'Mark as Read',
              onTap: () => onAction(_ChatOptionAction.markRead),
            )
          else
            _OptionTile(
              icon:  Icons.mark_email_unread_outlined,
              label: 'Mark as Unread',
              onTap: () => onAction(_ChatOptionAction.markUnread),
            ),

          // Block / Unblock — direct chats only, state-driven
          if (!isGroup)
            chat.isBlockedByMe
                ? _OptionTile(
                    icon:  Icons.block_flipped,
                    label: 'Unblock',
                    onTap: () => onAction(_ChatOptionAction.unblock),
                  )
                : _OptionTile(
                    icon:  Icons.block_rounded,
                    label: 'Block',
                    onTap: () => onAction(_ChatOptionAction.block),
                  ),

          // Exit Group — group chats only
          if (isGroup)
            _OptionTile(
              icon:  Icons.exit_to_app_rounded,
              label: 'Exit Group',
              color: const Color(0xFFE53935),
              onTap: () => onAction(_ChatOptionAction.exitGroup),
            ),

          // Delete — always shown
          _OptionTile(
            icon:  Icons.delete_outline_rounded,
            label: 'Delete Chat',
            color: const Color(0xFFE53935),
            onTap: () => onAction(_ChatOptionAction.delete),
          ),

          // Report — always shown (static — not driven by backend)
          _OptionTile(
            icon:  Icons.flag_outlined,
            label: 'Report',
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
                  foregroundColor: const Color(0xFF888888),
                  side: const BorderSide(color: Color(0xFFDDDDDD)),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
                child: const Text('Cancel'),
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
    final c = color ?? const Color(0xFF1A1A2E);
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
