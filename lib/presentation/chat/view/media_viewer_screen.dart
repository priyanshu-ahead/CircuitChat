import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:chewie/chewie.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:video_player/video_player.dart';

import '../../../data/models/message_model.dart';

/// Full-screen media viewer — mirrors RN's components/carousel/index.js.
///
/// Shows images (pinch-zoom, swipe between) and videos (native controls).
/// Header: sender name / date + options (⋮) + close.
/// Options: Forward, Star, Download/Share.
class MediaViewerScreen extends StatefulWidget {
  const MediaViewerScreen({
    super.key,
    required this.messages,    // all media messages to swipe through
    required this.initialIndex,
    this.currentUserId,
  });

  final List<MessageModel> messages;
  final int                initialIndex;
  final String?            currentUserId;

  /// Push-navigation helper used from chat bubble tap.
  static Future<void> open(
    BuildContext context, {
    required List<MessageModel> messages,
    required int initialIndex,
    String? currentUserId,
  }) {
    return Navigator.push(
      context,
      PageRouteBuilder(
        opaque: false,
        barrierColor: Colors.black,
        transitionDuration: const Duration(milliseconds: 250),
        pageBuilder: (_, __, ___) => MediaViewerScreen(
          messages:     messages,
          initialIndex: initialIndex,
          currentUserId: currentUserId,
        ),
        transitionsBuilder: (_, anim, __, child) =>
            FadeTransition(opacity: anim, child: child),
      ),
    );
  }

  @override
  State<MediaViewerScreen> createState() => _MediaViewerScreenState();
}

class _MediaViewerScreenState extends State<MediaViewerScreen> {
  late final PageController _pageCtrl;
  late int _currentIndex;
  bool _showOptions = false;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageCtrl = PageController(initialPage: widget.initialIndex);
    // Force landscape-friendly full-screen experience
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  }

  @override
  void dispose() {
    _pageCtrl.dispose();
    // Restore system UI
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  MessageModel get _current => widget.messages[_currentIndex];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // ── Swipeable media ─────────────────────────────────────────────
          PageView.builder(
            controller: _pageCtrl,
            itemCount: widget.messages.length,
            onPageChanged: (i) {
              setState(() {
                _currentIndex = i;
                _showOptions  = false;
              });
            },
            itemBuilder: (_, i) {
              final msg = widget.messages[i];
              if (msg.contentType == ContentType.video) {
                return _VideoPage(url: msg.mediaUrl ?? '');
              }
              return _ImagePage(url: msg.mediaUrl ?? '');
            },
          ),

          // ── Header bar ───────────────────────────────────────────────────
          Positioned(
            top: 0, left: 0, right: 0,
            child: _Header(
              message:       _current,
              currentUserId: widget.currentUserId,
              showOptions:   _showOptions,
              onToggleOptions: () =>
                  setState(() => _showOptions = !_showOptions),
              onClose: () => Navigator.pop(context),
            ),
          ),

          // ── Options panel ────────────────────────────────────────────────
          if (_showOptions)
            Positioned(
              top: 64, right: 8,
              child: _OptionsPanel(
                message: _current,
                onClose: () => setState(() => _showOptions = false),
              ),
            ),

          // ── Page counter (e.g. 2/5) ─────────────────────────────────────
          if (widget.messages.length > 1)
            Positioned(
              bottom: 32, left: 0, right: 0,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.black45,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '${_currentIndex + 1} / ${widget.messages.length}',
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w500),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ── Header ─────────────────────────────────────────────────────────────────────
class _Header extends StatelessWidget {
  const _Header({
    required this.message,
    required this.currentUserId,
    required this.showOptions,
    required this.onToggleOptions,
    required this.onClose,
  });

  final MessageModel message;
  final String?      currentUserId;
  final bool         showOptions;
  final VoidCallback onToggleOptions;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final isMe       = message.senderId == currentUserId || message.fromMe;
    final senderLabel = isMe ? 'You' : (message.chatId);
    final dateLabel   = message.createdAt.isNotEmpty
        ? DateFormat('MMM d, yyyy').format(
            DateTime.tryParse(message.createdAt)?.toLocal() ??
                DateTime.now())
        : '';

    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Colors.black87, Colors.transparent],
        ),
      ),
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 4,
        left: 8, right: 8, bottom: 16,
      ),
      child: Row(
        children: [
          // Sender + date
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(left: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(senderLabel,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w600),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                  if (dateLabel.isNotEmpty)
                    Text(dateLabel,
                        style: const TextStyle(
                            color: Colors.white70, fontSize: 12)),
                ],
              ),
            ),
          ),
          // Options toggle
          IconButton(
            icon: const Icon(Icons.more_vert_rounded,
                color: Colors.white, size: 22),
            onPressed: onToggleOptions,
          ),
          // Close
          IconButton(
            icon: const Icon(Icons.close_rounded,
                color: Colors.white, size: 24),
            onPressed: onClose,
          ),
        ],
      ),
    );
  }
}

// ── Options panel ─────────────────────────────────────────────────────────────
class _OptionsPanel extends StatelessWidget {
  const _OptionsPanel({required this.message, required this.onClose});
  final MessageModel message;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Container(
        width: 180,
        decoration: BoxDecoration(
          color: const Color(0xFF2A2A2A),
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(color: Colors.black38, blurRadius: 8),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _OptionItem(
              icon:  Icons.share_rounded,
              label: 'Share',
              onTap: () async {
                onClose();
                final url = message.mediaUrl;
                if (url != null) await Share.share(url);
              },
            ),
            const Divider(height: 1, color: Color(0xFF444444)),
            _OptionItem(
              icon:  Icons.download_rounded,
              label: 'Download',
              onTap: () async {
                onClose();
                final url = message.mediaUrl;
                if (url != null) {
                  final uri = Uri.tryParse(url);
                  if (uri != null) {
                    await launchUrl(uri,
                        mode: LaunchMode.externalApplication);
                  }
                }
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _OptionItem extends StatelessWidget {
  const _OptionItem(
      {required this.icon, required this.label, required this.onTap});
  final IconData icon;
  final String   label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => ListTile(
        dense: true,
        leading: Icon(icon, color: Colors.white70, size: 20),
        title: Text(label,
            style: const TextStyle(color: Colors.white, fontSize: 14)),
        onTap: onTap,
      );
}

// ── Image page — pinch-zoom via InteractiveViewer ─────────────────────────────
class _ImagePage extends StatelessWidget {
  const _ImagePage({required this.url});
  final String url;

  @override
  Widget build(BuildContext context) {
    if (url.isEmpty) {
      return const Center(
          child: Icon(Icons.broken_image_rounded,
              color: Colors.white38, size: 64));
    }

    // Local file (optimistic / recently sent)
    final isLocal = url.startsWith('/') || url.startsWith('file://');
    if (isLocal) {
      final file = File(url.replaceFirst('file://', ''));
      return InteractiveViewer(
        minScale: 0.5,
        maxScale: 5.0,
        child: Center(
          child: Image.file(
            file,
            fit: BoxFit.contain,
            errorBuilder: (_, __, ___) => const Icon(
                Icons.broken_image_rounded,
                color: Colors.white38, size: 64),
          ),
        ),
      );
    }

    return InteractiveViewer(
      minScale: 0.5,
      maxScale: 5.0,
      child: Center(
        child: CachedNetworkImage(
          imageUrl: url,
          fit: BoxFit.contain,
          placeholder: (_, __) =>
              const Center(child: CircularProgressIndicator(
                  color: Colors.white54, strokeWidth: 2)),
          errorWidget: (_, __, ___) =>
              const Icon(Icons.broken_image_rounded,
                  color: Colors.white38, size: 64),
        ),
      ),
    );
  }
}

// ── Video page — chewie player ─────────────────────────────────────────────────
class _VideoPage extends StatefulWidget {
  const _VideoPage({required this.url});
  final String url;

  @override
  State<_VideoPage> createState() => _VideoPageState();
}

class _VideoPageState extends State<_VideoPage> {
  VideoPlayerController? _vpc;
  ChewieController?      _chewieCtrl;
  bool _loading = true;
  bool _error   = false;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    try {
      final isLocal = widget.url.startsWith('/') ||
          widget.url.startsWith('file://');
      final vpc = isLocal
          ? VideoPlayerController.file(File(widget.url))
          : VideoPlayerController.networkUrl(Uri.parse(widget.url));
      await vpc.initialize();
      _chewieCtrl = ChewieController(
        videoPlayerController: vpc,
        autoPlay:    false,
        looping:     false,
        aspectRatio: vpc.value.aspectRatio,
        showControls: true,
        materialProgressColors: ChewieProgressColors(
          playedColor:   const Color(0xFF1877F2),
          bufferedColor: Colors.white38,
        ),
      );
      _vpc = vpc;
      if (mounted) setState(() => _loading = false);
    } catch (_) {
      if (mounted) setState(() { _loading = false; _error = true; });
    }
  }

  @override
  void dispose() {
    _chewieCtrl?.dispose();
    _vpc?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator(
          color: Colors.white54, strokeWidth: 2));
    }
    if (_error || _chewieCtrl == null) {
      return const Center(
          child: Icon(Icons.videocam_off_rounded,
              color: Colors.white38, size: 64));
    }
    return Center(child: Chewie(controller: _chewieCtrl!));
  }
}
