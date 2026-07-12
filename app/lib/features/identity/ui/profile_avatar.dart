import 'dart:convert';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

class ProfileAvatar extends StatelessWidget {
  const ProfileAvatar({
    super.key,
    this.profilePhotoUrl,
    this.profilePhotoBase64,
    required this.radius,
    this.backgroundColor,
    this.fallback,
  });

  final String? profilePhotoUrl;
  final String? profilePhotoBase64;
  final double radius;
  final Color? backgroundColor;
  final Widget? fallback;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final resolvedBackgroundColor =
        backgroundColor ?? colors.surfaceContainerHighest;
    final resolvedFallback =
        fallback ??
        Icon(
          Icons.person_outline,
          color: colors.onSurfaceVariant,
        );

    final url = profilePhotoUrl?.trim();
    if (url != null && url.isNotEmpty) {
      return CircleAvatar(
        radius: radius,
        backgroundColor: resolvedBackgroundColor,
        backgroundImage: CachedNetworkImageProvider(url),
        onBackgroundImageError: (_, _) {},
        child: null,
      );
    }

    final encodedPhoto = profilePhotoBase64?.trim();
    if (encodedPhoto != null && encodedPhoto.isNotEmpty) {
      try {
        final bytes = base64Decode(encodedPhoto);
        return CircleAvatar(
          radius: radius,
          backgroundColor: resolvedBackgroundColor,
          backgroundImage: MemoryImage(bytes),
        );
      } catch (_) {
        // Fall through to the icon avatar if legacy base64 data is invalid.
      }
    }

    return CircleAvatar(
      radius: radius,
      backgroundColor: resolvedBackgroundColor,
      child: resolvedFallback,
    );
  }
}
