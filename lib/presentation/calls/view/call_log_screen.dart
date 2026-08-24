import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../data/models/group_model.dart';
import '../../group/viewmodel/group_viewmodel.dart';

class CallLogScreen extends ConsumerStatefulWidget {
  const CallLogScreen({super.key});

  @override
  ConsumerState<CallLogScreen> createState() => _CallLogScreenState();
}

class _CallLogScreenState extends ConsumerState<CallLogScreen> {
  final _searchCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  final _searchFocus = FocusNode();
  bool _searchVisible = false;

  @override
  void initState() {
    super.initState();
    _scrollCtrl.addListener(_onScroll);
    _searchCtrl.addListener(() {
      ref
          .read(callLogViewModelProvider.notifier)
          .setSearch(_searchCtrl.text.trim());
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(callLogViewModelProvider.notifier).loadOnce();
    });
  }

  void _onScroll() {
    if (_scrollCtrl.position.pixels >=
        _scrollCtrl.position.maxScrollExtent - 200) {
      ref.read(callLogViewModelProvider.notifier).loadMore();
    }
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _scrollCtrl.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  void _toggleSearch() {
    if (_searchVisible) {
      _searchCtrl.clear();
      ref.read(callLogViewModelProvider.notifier).setSearch('');
      setState(() => _searchVisible = false);
    } else {
      setState(() => _searchVisible = true);
      _searchFocus.requestFocus();
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(callLogViewModelProvider);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0.5,
        title: const Text(
          'Calls',
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 22),
        ),
        titleSpacing: 16,
        actions: [
          IconButton(
            icon: Icon(
              _searchVisible
                  ? Icons.close_rounded
                  : Icons.search_rounded,
              color: const Color(0xFF1976D2),
            ),
            tooltip: _searchVisible ? 'Close search' : 'Search',
            onPressed: _toggleSearch,
          ),
          const SizedBox(width: 4),
        ],
        bottom: _searchVisible
            ? PreferredSize(
                preferredSize: const Size.fromHeight(52),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
                  child: TextField(
                    controller: _searchCtrl,
                    focusNode: _searchFocus,
                    decoration: InputDecoration(
                      hintText: 'Search calls…',
                      prefixIcon: const Icon(Icons.search_rounded,
                          color: Color(0xFF888888)),
                      suffixIcon: _searchCtrl.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.close_rounded,
                                  color: Color(0xFF888888)),
                              onPressed: () => _searchCtrl.clear(),
                            )
                          : null,
                      filled: true,
                      fillColor: const Color(0xFFF0F0F0),
                      contentPadding: const EdgeInsets.symmetric(
                          vertical: 8, horizontal: 14),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ),
              )
            : null,
      ),
      body: state.status == CallLogStatus.initial
          ? const SizedBox.shrink() // not yet mounted — show nothing
          : state.isLoading && state.calls.isEmpty
              ? const Center(child: CircularProgressIndicator())
              : state.calls.isEmpty
              ? const Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.phone_outlined,
                          size: 56, color: Color(0xFFCCCCCC)),
                      SizedBox(height: 12),
                      Text('No recent calls',
                          style: TextStyle(
                              color: Color(0xFFAAAAAA), fontSize: 15)),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: () =>
                      ref.read(callLogViewModelProvider.notifier).refresh(),
                  child: ListView.builder(
                    controller: _scrollCtrl,
                    itemCount: state.calls.length +
                        (state.hasMore ? 1 : 0),
                    itemBuilder: (_, i) {
                      if (i == state.calls.length) {
                        return const Padding(
                          padding: EdgeInsets.all(16),
                          child: Center(
                              child: CircularProgressIndicator()),
                        );
                      }
                      return _CallTile(call: state.calls[i]);
                    },
                  ),
                ),
    );
  }
}

class _CallTile extends StatelessWidget {
  const _CallTile({required this.call});
  final CallModel call;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      leading: _buildAvatar(),
      title: Text(
        call.chatName ?? 'Unknown',
        style: const TextStyle(fontWeight: FontWeight.w500),
      ),
      subtitle: Row(
        children: [
          _directionIcon(),
          const SizedBox(width: 4),
          Text(
            _subtitle(),
            style: const TextStyle(
                fontSize: 12, color: Color(0xFF888888)),
          ),
        ],
      ),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            _formatDate(call.createdAt),
            style: const TextStyle(
                fontSize: 12, color: Color(0xFF888888)),
          ),
          const SizedBox(height: 4),
          Icon(
            call.isVideo ? Icons.videocam_rounded : Icons.phone_rounded,
            color: const Color(0xFF1976D2),
            size: 18,
          ),
        ],
      ),
    );
  }

  Widget _buildAvatar() {
    final url = call.chatAvatar;
    if (url != null && url.isNotEmpty) {
      return CircleAvatar(
        radius: 24,
        backgroundImage: CachedNetworkImageProvider(url),
      );
    }
    return CircleAvatar(
      radius: 24,
      backgroundColor: const Color(0xFF1976D2),
      child: Text(
        (call.chatName ?? '?')[0].toUpperCase(),
        style: const TextStyle(
            color: Colors.white, fontWeight: FontWeight.w600),
      ),
    );
  }

  Widget _directionIcon() {
    if (call.isMissed) {
      return const Icon(Icons.call_missed_rounded,
          size: 14, color: Color(0xFFE53935));
    }
    if (call.fromMe) {
      return const Icon(Icons.call_made_rounded,
          size: 14, color: Color(0xFF43A047));
    }
    return const Icon(Icons.call_received_rounded,
        size: 14, color: Color(0xFF43A047));
  }

  String _subtitle() {
    final parts = <String>[];
    if (call.isMissed) {
      parts.add('Missed');
    } else {
      parts.add(call.fromMe ? 'Outgoing' : 'Incoming');
    }
    if (call.isVideo) {
      parts.add('Video');
    } else {
      parts.add('Voice');
    }
    if (call.duration != null && call.duration! > 0) {
      parts.add(_formatDuration(call.duration!));
    }
    return parts.join(' · ');
  }

  String _formatDate(String? iso) {
    if (iso == null) return '';
    try {
      final dt = DateTime.parse(iso).toLocal();
      final now = DateTime.now();
      if (dt.year == now.year &&
          dt.month == now.month &&
          dt.day == now.day) {
        return DateFormat('h:mm a').format(dt);
      }
      return DateFormat('MMM d').format(dt);
    } catch (_) {
      return '';
    }
  }

  String _formatDuration(int secs) {
    final m = secs ~/ 60;
    final s = secs % 60;
    if (m > 0) return '${m}m ${s}s';
    return '${s}s';
  }
}
