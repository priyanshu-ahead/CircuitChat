import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';

/// Circular cached avatar with initials fallback.
class CachedAvatar extends StatelessWidget {
  const CachedAvatar({
    super.key,
    this.url,
    required this.name,
    this.radius = 24,
    this.isOnline = false,
  });

  final String? url;
  final String name;
  final double radius;
  final bool isOnline;

  String get _initials {
    final words = name.trim().split(RegExp(r'\s+'));
    if (words.isEmpty) return '?';
    if (words.length == 1) return words[0][0].toUpperCase();
    return '${words[0][0]}${words[words.length - 1][0]}'.toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        CircleAvatar(
          radius: radius,
          backgroundColor: AppColors.primaryLight,
          child: url != null && url!.isNotEmpty
              ? ClipOval(
                  child: CachedNetworkImage(
                    imageUrl: url!,
                    width: radius * 2,
                    height: radius * 2,
                    fit: BoxFit.cover,
                    errorWidget: (_, __, ___) => _initialsWidget,
                  ),
                )
              : _initialsWidget,
        ),
        if (isOnline)
          Positioned(
            right: 0,
            bottom: 0,
            child: Container(
              width: radius * 0.5,
              height: radius * 0.5,
              decoration: BoxDecoration(
                color: AppColors.online,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 1.5),
              ),
            ),
          ),
      ],
    );
  }

  Widget get _initialsWidget => Text(
        _initials,
        style: TextStyle(
          color: Colors.white,
          fontSize: radius * 0.6,
          fontWeight: FontWeight.w600,
        ),
      );
}
