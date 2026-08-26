import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

import '../../../core/theme/app_theme.dart';

/// Shimmer placeholder for message list loading.
class MessageShimmerList extends StatelessWidget {
  const MessageShimmerList({super.key, this.itemCount = 8});
  final int itemCount;

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDark;
    final base      = isDark ? const Color(0xFF2C2C3E) : const Color(0xFFE0E0E0);
    final highlight = isDark ? const Color(0xFF3A3A52) : const Color(0xFFF5F5F5);
    return Shimmer.fromColors(
      baseColor: base,
      highlightColor: highlight,
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        itemCount: itemCount,
        itemBuilder: (_, i) {
          final fromMe = i.isEven;
          return Align(
            alignment: fromMe ? Alignment.centerRight : Alignment.centerLeft,
            child: Container(
              margin: const EdgeInsets.symmetric(vertical: 5),
              width: 120 + (i % 4) * 40.0,
              height: 38,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.only(
                  topLeft:     const Radius.circular(14),
                  topRight:    const Radius.circular(14),
                  bottomLeft:  Radius.circular(fromMe ? 14 : 4),
                  bottomRight: Radius.circular(fromMe ? 4  : 14),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Shimmer placeholder for chat list.
class ChatListShimmer extends StatelessWidget {
  const ChatListShimmer({super.key, this.itemCount = 10});
  final int itemCount;

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDark;
    final base      = isDark ? const Color(0xFF2C2C3E) : const Color(0xFFE0E0E0);
    final highlight = isDark ? const Color(0xFF3A3A52) : const Color(0xFFF5F5F5);
    return Shimmer.fromColors(
      baseColor:      base,
      highlightColor: highlight,
      child: ListView.builder(
        itemCount: itemCount,
        itemBuilder: (_, __) => Padding(
          padding: const EdgeInsets.symmetric(
              horizontal: 14, vertical: 8),
          child: Row(
            children: [
              const CircleAvatar(
                radius: 26,
                backgroundColor: Colors.white,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      height: 14, width: 140,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(7),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      height: 11, width: double.infinity,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(5),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
