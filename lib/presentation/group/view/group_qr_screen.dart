import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../viewmodel/group_viewmodel.dart';

class GroupQRScreen extends ConsumerStatefulWidget {
  const GroupQRScreen({super.key, required this.groupId});
  final String groupId;

  @override
  ConsumerState<GroupQRScreen> createState() => _GroupQRScreenState();
}

class _GroupQRScreenState extends ConsumerState<GroupQRScreen> {
  bool _qrLoading = true;

  @override
  void initState() {
    super.initState();
    _loadQR();
  }

  Future<void> _loadQR() async {
    await ref
        .read(groupViewModelProvider(widget.groupId).notifier)
        .loadQR();
    if (mounted) setState(() => _qrLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(groupViewModelProvider(widget.groupId));
    final group = state.group;
    final qrUrl = state.qrUrl;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0.5,
        title: const Text(
          'Group QR Code',
          style: TextStyle(fontWeight: FontWeight.w600, fontSize: 17),
        ),
      ),
      body: state.isLoading || group == null
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              child: Column(
                children: [
                  const SizedBox(height: 24),
                  // Group info + QR card
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 24),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 24, vertical: 32),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.06),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        )
                      ],
                    ),
                    child: Column(
                      children: [
                        // Avatar
                        _buildGroupAvatar(group.avatar, group.name),
                        const SizedBox(height: 12),
                        // Name
                        Text(
                          group.name,
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 18,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        if (group.about != null && group.about!.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            group.about!,
                            style: const TextStyle(
                                fontSize: 13,
                                color: Color(0xFF888888)),
                            textAlign: TextAlign.center,
                            maxLines: 2,
                          ),
                        ],
                        const SizedBox(height: 24),
                        // QR image
                        Container(
                          width: 220,
                          height: 220,
                          decoration: BoxDecoration(
                            border: Border.all(
                                color: const Color(0xFFEEEEEE), width: 1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: _qrLoading
                              ? const Center(
                                  child: CircularProgressIndicator())
                              : qrUrl != null && qrUrl.isNotEmpty
                                  ? ClipRRect(
                                      borderRadius:
                                          BorderRadius.circular(7),
                                      child: CachedNetworkImage(
                                        imageUrl: qrUrl,
                                        fit: BoxFit.contain,
                                        placeholder: (_, __) => const Center(
                                            child:
                                                CircularProgressIndicator()),
                                        errorWidget: (_, __, ___) =>
                                            const Icon(Icons.qr_code_2,
                                                size: 80,
                                                color:
                                                    Color(0xFFCCCCCC)),
                                      ),
                                    )
                                  : const Center(
                                      child: Icon(Icons.qr_code_2,
                                          size: 80,
                                          color: Color(0xFFCCCCCC))),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Text(
                      'Scan this QR code to join the group.',
                      style: const TextStyle(
                          fontSize: 13, color: Color(0xFF888888)),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  const SizedBox(height: 20),
                  // Reset button
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: OutlinedButton(
                      onPressed: _qrLoading ? null : _resetQR,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF1976D2),
                        side: const BorderSide(color: Color(0xFF1976D2)),
                        minimumSize: const Size.fromHeight(44),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: const Text('Reset QR Code'),
                    ),
                  ),
                  const SizedBox(height: 32),
                ],
              ),
            ),
    );
  }

  Future<void> _resetQR() async {
    setState(() => _qrLoading = true);
    await ref
        .read(groupViewModelProvider(widget.groupId).notifier)
        .resetQR();
    if (mounted) setState(() => _qrLoading = false);
  }

  Widget _buildGroupAvatar(String? url, String name) {
    if (url != null && url.isNotEmpty) {
      return CircleAvatar(
        radius: 40,
        backgroundImage: CachedNetworkImageProvider(url),
      );
    }
    return CircleAvatar(
      radius: 40,
      backgroundColor: const Color(0xFF1976D2),
      child: Text(
        name.isNotEmpty ? name[0].toUpperCase() : 'G',
        style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w700,
            fontSize: 30),
      ),
    );
  }
}
