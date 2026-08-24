import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../data/models/chat_model.dart';
import '../../../data/models/message_model.dart';
import '../../../presentation/auth/viewmodel/auth_viewmodel.dart';
import '../viewmodel/message_viewmodel.dart';

class ChatDetailScreen extends ConsumerStatefulWidget {
  const ChatDetailScreen({super.key, required this.chat});
  final ChatModel chat;

  @override
  ConsumerState<ChatDetailScreen> createState() => _ChatDetailScreenState();
}

class _ChatDetailScreenState extends ConsumerState<ChatDetailScreen> {
  final _textCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  bool _showScrollToBottom = false;

  String? get _currentUserId =>
      ref.read(authViewModelProvider).user?.id;

  @override
  void initState() {
    super.initState();
    _textCtrl.addListener(() => setState(() {}));
    _scrollCtrl.addListener(() {
      final atBottom = _scrollCtrl.position.pixels >=
          _scrollCtrl.position.maxScrollExtent - 150;
      if (_showScrollToBottom == atBottom) {
        setState(() => _showScrollToBottom = !atBottom);
      }
      // Load more when scrolled to top
      if (_scrollCtrl.position.pixels <= 100) {
        ref
            .read(messageViewModelProvider(widget.chat.id).notifier)
            .loadMore();
      }
    });
  }

  @override
  void dispose() {
    _textCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    if (_scrollCtrl.hasClients) {
      _scrollCtrl.animateTo(
        _scrollCtrl.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  void _sendMessage() {
    final text = _textCtrl.text.trim();
    if (text.isEmpty) return;
    _textCtrl.clear();
    ref
        .read(messageViewModelProvider(widget.chat.id).notifier)
        .sendText(text, currentUserId: _currentUserId);
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
  }

  @override
  Widget build(BuildContext context) {
    final msgState = ref.watch(messageViewModelProvider(widget.chat.id));

    return Scaffold(
      backgroundColor: const Color(0xFFF0F4F8),
      appBar: _buildAppBar(msgState),
      body: Column(
        children: [
          Expanded(child: _buildMessageList(msgState)),
          if (msgState.isTyping) _buildTypingIndicator(),
          if (msgState.replyTo != null)
            _buildReplyPreview(msgState.replyTo!, msgState),
          _buildInputBar(msgState),
        ],
      ),
      floatingActionButton: _showScrollToBottom
          ? FloatingActionButton.small(
              onPressed: _scrollToBottom,
              backgroundColor: Colors.white,
              child: const Icon(Icons.keyboard_arrow_down_rounded,
                  color: Color(0xFF1976D2)),
            )
          : null,
    );
  }

  // ── AppBar ────────────────────────────────────────────────────────────────
  PreferredSizeWidget _buildAppBar(MessageState msgState) {
    return AppBar(
      backgroundColor: Colors.white,
      elevation: 0,
      titleSpacing: 0,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_rounded, color: Color(0xFF1A1A2E)),
        onPressed: () => Navigator.pop(context),
      ),
      title: Row(
        children: [
          Stack(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: const Color(0xFFDDE4EF),
                backgroundImage: widget.chat.avatar != null
                    ? NetworkImage(widget.chat.avatar!)
                    : null,
                child: widget.chat.avatar == null
                    ? Icon(
                        widget.chat.type == ChatType.group
                            ? Icons.group_rounded
                            : Icons.person_rounded,
                        color: const Color(0xFF9AA6B8),
                        size: 20,
                      )
                    : null,
              ),
              if (widget.chat.isOnline && widget.chat.type == ChatType.direct)
                Positioned(
                  right: 1,
                  bottom: 1,
                  child: Container(
                    width: 9,
                    height: 9,
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
                Text(
                  widget.chat.name ?? 'Chat',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1A1A2E),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (msgState.isTyping)
                  const Text(
                    'typing…',
                    style: TextStyle(
                        fontSize: 12,
                        color: Color(0xFF1976D2),
                        fontStyle: FontStyle.italic),
                  )
                else if (widget.chat.isOnline &&
                    widget.chat.type == ChatType.direct)
                  const Text(
                    'Online',
                    style: TextStyle(fontSize: 12, color: Color(0xFF4CAF50)),
                  ),
              ],
            ),
          ),
        ],
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.videocam_outlined, color: Color(0xFF1A1A2E)),
          onPressed: () {},
        ),
        IconButton(
          icon: const Icon(Icons.call_outlined, color: Color(0xFF1A1A2E)),
          onPressed: () {},
        ),
        IconButton(
          icon: const Icon(Icons.more_vert_rounded, color: Color(0xFF1A1A2E)),
          onPressed: () {},
        ),
      ],
      bottom: const PreferredSize(
        preferredSize: Size.fromHeight(0.5),
        child: Divider(height: 0, color: Color(0xFFEEEEEE)),
      ),
    );
  }

  // ── Message list ──────────────────────────────────────────────────────────
  Widget _buildMessageList(MessageState msgState) {
    if (msgState.isLoading) {
      return const Center(
          child: CircularProgressIndicator(color: Color(0xFF1976D2)));
    }
    if (msgState.status == MessageStatus2.error) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline_rounded,
                size: 48, color: Color(0xFF9AA6B8)),
            const SizedBox(height: 8),
            Text(
              msgState.errorMessage ?? 'Failed to load messages.',
              style: const TextStyle(color: Color(0xFF9AA6B8)),
            ),
          ],
        ),
      );
    }

    final messages = msgState.messages;
    if (messages.isEmpty) {
      return const Center(
        child: Text(
          'No messages yet.\nSay hello! 👋',
          textAlign: TextAlign.center,
          style: TextStyle(color: Color(0xFF9AA6B8), fontSize: 15),
        ),
      );
    }

    return ListView.builder(
      controller: _scrollCtrl,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      itemCount: messages.length + (msgState.hasMore ? 1 : 0),
      itemBuilder: (ctx, i) {
        // Load more indicator at top
        if (i == 0 && msgState.hasMore) {
          return const Padding(
            padding: EdgeInsets.only(bottom: 8),
            child: Center(
                child: SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(
                  strokeWidth: 2, color: Color(0xFF1976D2)),
            )),
          );
        }
        final msgIndex = msgState.hasMore ? i - 1 : i;
        final msg = messages[msgIndex];
        final prevMsg =
            msgIndex > 0 ? messages[msgIndex - 1] : null;

        // Date divider
        final showDate =
            prevMsg == null || !_sameDay(prevMsg.createdAt, msg.createdAt);

        return Column(
          children: [
            if (showDate) _DateDivider(iso: msg.createdAt),
            if (msg.isSystemMessage)
              _SystemMessage(msg: msg)
            else
              _MessageBubble(
                msg: msg,
                onLongPress: () => _showMessageMenu(msg),
                onReply: () => ref
                    .read(messageViewModelProvider(widget.chat.id).notifier)
                    .setReplyTo(msg),
              ),
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
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(
            3,
            (i) => _TypingDot(delay: Duration(milliseconds: i * 150)),
          ),
        ),
      ),
    );
  }

  // ── Reply preview bar ─────────────────────────────────────────────────────
  Widget _buildReplyPreview(MessageModel replyTo, MessageState state) {
    return Container(
      color: const Color(0xFFF2F4F8),
      padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
      child: Row(
        children: [
          Container(
            width: 3,
            height: 36,
            decoration: BoxDecoration(
              color: const Color(0xFF1976D2),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Reply',
                    style: TextStyle(
                        fontSize: 12,
                        color: Color(0xFF1976D2),
                        fontWeight: FontWeight.w600)),
                Text(
                  replyTo.text ?? _contentLabel(replyTo.contentType),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style:
                      const TextStyle(fontSize: 13, color: Color(0xFF666666)),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close_rounded,
                size: 18, color: Color(0xFF9AA6B8)),
            onPressed: () => ref
                .read(messageViewModelProvider(widget.chat.id).notifier)
                .setReplyTo(null),
          ),
        ],
      ),
    );
  }

  // ── Input bar ─────────────────────────────────────────────────────────────
  Widget _buildInputBar(MessageState state) {
    final hasText = _textCtrl.text.trim().isNotEmpty;
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
      child: SafeArea(
        top: false,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            // Attach button
            IconButton(
              icon: const Icon(Icons.attach_file_rounded,
                  color: Color(0xFF9AA6B8)),
              onPressed: () {},
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
                    hintStyle:
                        TextStyle(color: Color(0xFF9AA6B8), fontSize: 15),
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(
                        horizontal: 16, vertical: 10),
                  ),
                  onSubmitted: (_) => _sendMessage(),
                ),
              ),
            ),
            const SizedBox(width: 8),
            // Send / Mic button
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              child: GestureDetector(
                key: ValueKey(hasText),
                onTap: hasText ? _sendMessage : null,
                child: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: hasText
                        ? const Color(0xFF1976D2)
                        : const Color(0xFFF2F4F8),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    hasText
                        ? Icons.send_rounded
                        : Icons.mic_none_rounded,
                    color: hasText
                        ? Colors.white
                        : const Color(0xFF9AA6B8),
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

  // ── Message context menu ───────────────────────────────────────────────────
  void _showMessageMenu(MessageModel msg) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 8),
            ListTile(
              leading: const Icon(Icons.reply_rounded,
                  color: Color(0xFF1976D2)),
              title: const Text('Reply'),
              onTap: () {
                Navigator.pop(context);
                ref
                    .read(messageViewModelProvider(widget.chat.id).notifier)
                    .setReplyTo(msg);
              },
            ),
            if (msg.text != null)
              ListTile(
                leading: const Icon(Icons.copy_rounded,
                    color: Color(0xFF1976D2)),
                title: const Text('Copy'),
                onTap: () {
                  Navigator.pop(context);
                  Clipboard.setData(ClipboardData(text: msg.text!));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Copied to clipboard')),
                  );
                },
              ),
            ListTile(
              leading: const Icon(Icons.star_border_rounded,
                  color: Color(0xFF1976D2)),
              title: const Text('Star Message'),
              onTap: () => Navigator.pop(context),
            ),
            if (msg.fromMe)
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
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            const Text('Delete Message',
                style:
                    TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            ListTile(
              leading: const Icon(Icons.delete_outline_rounded,
                  color: Color(0xFFEF4444)),
              title: const Text('Delete for Me'),
              onTap: () {
                Navigator.pop(context);
                ref
                    .read(messageViewModelProvider(widget.chat.id).notifier)
                    .deleteMessage(msg.id);
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete_sweep_rounded,
                  color: Color(0xFFEF4444)),
              title: const Text('Delete for Everyone'),
              onTap: () {
                Navigator.pop(context);
                ref
                    .read(messageViewModelProvider(widget.chat.id).notifier)
                    .deleteMessage(msg.id, forEveryone: true);
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  static bool _sameDay(String? a, String? b) {
    if (a == null || b == null) return false;
    try {
      final da = DateTime.parse(a);
      final db = DateTime.parse(b);
      return da.year == db.year &&
          da.month == db.month &&
          da.day == db.day;
    } catch (_) {
      return false;
    }
  }

  static String _contentLabel(ContentType t) {
    switch (t) {
      case ContentType.image:
        return '📷 Photo';
      case ContentType.video:
        return '🎥 Video';
      case ContentType.audio:
        return '🎵 Audio';
      case ContentType.file:
        return '📎 File';
      default:
        return 'Message';
    }
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
      final dt = DateTime.parse(iso).toLocal();
      final now = DateTime.now();
      if (dt.year == now.year &&
          dt.month == now.month &&
          dt.day == now.day) {
        label = 'Today';
      } else {
        final y = now.subtract(const Duration(days: 1));
        if (dt.year == y.year && dt.month == y.month && dt.day == y.day) {
          label = 'Yesterday';
        } else {
          label = DateFormat('MMMM d, yyyy').format(dt);
        }
      }
    } catch (_) {
      label = '';
    }
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            label,
            style: const TextStyle(
                fontSize: 12, color: Color(0xFF666666)),
          ),
        ),
      ),
    );
  }
}

// ── System / notification message ─────────────────────────────────────────────
class _SystemMessage extends StatelessWidget {
  const _SystemMessage({required this.msg});
  final MessageModel msg;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Center(
        child: Container(
          padding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            msg.text ?? '',
            style: const TextStyle(
                fontSize: 12, color: Color(0xFF666666)),
            textAlign: TextAlign.center,
          ),
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
  });

  final MessageModel msg;
  final VoidCallback onLongPress;
  final VoidCallback onReply;

  static const _bubbleMe = Color(0xFF1976D2);
  static const _bubbleOther = Colors.white;

  @override
  Widget build(BuildContext context) {
    final isMe = msg.fromMe;
    return GestureDetector(
      onLongPress: onLongPress,
      child: Padding(
        padding: EdgeInsets.only(
          top: 2,
          bottom: 2,
          left: isMe ? 60 : 0,
          right: isMe ? 0 : 60,
        ),
        child: Align(
          alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
          child: Column(
            crossAxisAlignment:
                isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
            children: [
              // Reply preview inside bubble
              if (msg.replyToMessage != null)
                _InBubbleReply(
                    reply: msg.replyToMessage!, isMe: isMe),

              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: isMe ? _bubbleMe : _bubbleOther,
                  borderRadius: BorderRadius.only(
                    topLeft: const Radius.circular(16),
                    topRight: const Radius.circular(16),
                    bottomLeft: Radius.circular(isMe ? 16 : 4),
                    bottomRight: Radius.circular(isMe ? 4 : 16),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.06),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    // Message content
                    if (msg.isDeleted)
                      Text(
                        'This message was deleted',
                        style: TextStyle(
                          fontSize: 14,
                          fontStyle: FontStyle.italic,
                          color: isMe
                              ? Colors.white70
                              : const Color(0xFF9AA6B8),
                        ),
                      )
                    else if (msg.contentType == ContentType.text)
                      Text(
                        msg.text ?? '',
                        style: TextStyle(
                          fontSize: 15,
                          color: isMe
                              ? Colors.white
                              : const Color(0xFF1A1A2E),
                          height: 1.4,
                        ),
                      )
                    else
                      _MediaPreview(msg: msg, isMe: isMe),

                    // Time + status
                    const SizedBox(height: 4),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _formatTime(msg.createdAt),
                          style: TextStyle(
                            fontSize: 11,
                            color: isMe
                                ? Colors.white70
                                : const Color(0xFF9AA6B8),
                          ),
                        ),
                        if (isMe) ...[
                          const SizedBox(width: 3),
                          _StatusIcon(status: msg.status, isMe: isMe),
                        ],
                      ],
                    ),
                  ],
                ),
              ),

              // Reactions row
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
    } catch (_) {
      return '';
    }
  }
}

// ── In-bubble reply preview ───────────────────────────────────────────────────
class _InBubbleReply extends StatelessWidget {
  const _InBubbleReply({required this.reply, required this.isMe});
  final MessageModel reply;
  final bool isMe;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: isMe
            ? Colors.white.withValues(alpha: 0.15)
            : const Color(0xFFF0F4F8),
        borderRadius: BorderRadius.circular(10),
        border: const Border(
          left: BorderSide(color: Color(0xFF1976D2), width: 3),
        ),
      ),
      child: Text(
        reply.text ?? '📎 Media',
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontSize: 12,
          color: isMe ? Colors.white70 : const Color(0xFF666666),
        ),
      ),
    );
  }
}

// ── Media preview placeholder ─────────────────────────────────────────────────
class _MediaPreview extends StatelessWidget {
  const _MediaPreview({required this.msg, required this.isMe});
  final MessageModel msg;
  final bool isMe;

  @override
  Widget build(BuildContext context) {
    switch (msg.contentType) {
      case ContentType.image:
        return ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: msg.mediaUrl != null
              ? Image.network(
                  msg.mediaUrl!,
                  width: 200,
                  height: 200,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) =>
                      _placeholder(Icons.broken_image_rounded, isMe),
                )
              : _placeholder(Icons.image_rounded, isMe),
        );
      case ContentType.video:
        return _placeholder(Icons.play_circle_rounded, isMe);
      case ContentType.audio:
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.mic_rounded,
                color: isMe ? Colors.white : const Color(0xFF1976D2)),
            const SizedBox(width: 8),
            Text(
              '🎵 Audio',
              style: TextStyle(
                  color: isMe ? Colors.white : const Color(0xFF1A1A2E)),
            ),
          ],
        );
      case ContentType.file:
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.insert_drive_file_rounded,
                color: isMe ? Colors.white : const Color(0xFF1976D2)),
            const SizedBox(width: 8),
            Text(
              '📎 File',
              style: TextStyle(
                  color: isMe ? Colors.white : const Color(0xFF1A1A2E)),
            ),
          ],
        );
      default:
        return Text(
          msg.text ?? '',
          style: TextStyle(
            color: isMe ? Colors.white : const Color(0xFF1A1A2E),
          ),
        );
    }
  }

  Widget _placeholder(IconData icon, bool isMe) => Container(
        width: 160,
        height: 120,
        decoration: BoxDecoration(
          color: isMe
              ? Colors.white.withValues(alpha: 0.15)
              : const Color(0xFFF0F4F8),
          borderRadius: BorderRadius.circular(8),
        ),
        child:
            Icon(icon, size: 40, color: isMe ? Colors.white54 : Colors.grey),
      );
}

// ── Message status icon ───────────────────────────────────────────────────────
class _StatusIcon extends StatelessWidget {
  const _StatusIcon({required this.status, required this.isMe});
  final MessageStatus status;
  final bool isMe;

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
    // Group reactions by emoji
    final grouped = <String, int>{};
    for (final r in msg.reactions) {
      grouped[r.reaction] = (grouped[r.reaction] ?? 0) + 1;
    }
    return Padding(
      padding: const EdgeInsets.only(top: 2),
      child: Wrap(
        spacing: 4,
        children: grouped.entries
            .map((e) => Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFEEEEEE)),
                    boxShadow: [
                      BoxShadow(
                          color: Colors.black.withValues(alpha: 0.04),
                          blurRadius: 2),
                    ],
                  ),
                  child: Text('${e.key} ${e.value}',
                      style: const TextStyle(fontSize: 12)),
                ))
            .toList(),
      ),
    );
  }
}

// ── Typing dot animation ──────────────────────────────────────────────────────
class _TypingDot extends StatefulWidget {
  const _TypingDot({required this.delay});
  final Duration delay;

  @override
  State<_TypingDot> createState() => _TypingDotState();
}

class _TypingDotState extends State<_TypingDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    Future.delayed(widget.delay, () {
      if (mounted) _ctrl.repeat(reverse: true);
    });
    _anim = Tween<double>(begin: 0, end: -6).animate(
        CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _anim,
      builder: (_, __) => Transform.translate(
        offset: Offset(0, _anim.value),
        child: Container(
          width: 7,
          height: 7,
          margin: const EdgeInsets.symmetric(horizontal: 2),
          decoration: const BoxDecoration(
            color: Color(0xFF9AA6B8),
            shape: BoxShape.circle,
          ),
        ),
      ),
    );
  }
}
