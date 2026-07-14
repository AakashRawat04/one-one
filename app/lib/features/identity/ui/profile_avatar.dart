import 'dart:convert';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

/// Renders a profile photo filling its bounds, falling back to [fallback]
/// (or a person icon) when there is no photo or the photo fails to load.
///
/// Unlike a bare `CircleAvatar` with `backgroundImage`, load failures are
/// surfaced through [CachedNetworkImage]'s `errorWidget` (and logged via
/// [debugPrint]) instead of silently rendering a blank space, which was
/// previously hiding broken Cloudinary URLs.
class ProfileImage extends StatelessWidget {
  const ProfileImage({
    super.key,
    this.profilePhotoUrl,
    this.profilePhotoBase64,
    this.backgroundColor,
    this.fallback,
    this.fit = BoxFit.cover,
  });

  final String? profilePhotoUrl;
  final String? profilePhotoBase64;
  final Color? backgroundColor;
  final Widget? fallback;
  final BoxFit fit;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final resolvedBackgroundColor =
        backgroundColor ?? colors.surfaceContainerHighest;
    final resolvedFallback =
        fallback ??
        Icon(Icons.person_outline, color: colors.onSurfaceVariant);

    final url = profilePhotoUrl?.trim();
    if (url != null && url.isNotEmpty) {
      return ColoredBox(
        color: resolvedBackgroundColor,
        child: CachedNetworkImage(
          imageUrl: url,
          fit: fit,
          fadeInDuration: const Duration(milliseconds: 150),
          placeholder: (context, url) => const SizedBox.shrink(),
          errorWidget: (context, url, error) {
            // Surface Cloudinary/network failures instead of failing silently.
            debugPrint('ProfileImage: failed to load "$url": $error');
            return Center(child: resolvedFallback);
          },
        ),
      );
    }

    final encodedPhoto = profilePhotoBase64?.trim();
    if (encodedPhoto != null && encodedPhoto.isNotEmpty) {
      try {
        final bytes = base64Decode(encodedPhoto);
        return ColoredBox(
          color: resolvedBackgroundColor,
          child: Image.memory(
            bytes,
            fit: fit,
            errorBuilder: (context, error, stackTrace) {
              debugPrint('ProfileImage: failed to decode base64 photo: $error');
              return Center(child: resolvedFallback);
            },
          ),
        );
      } catch (error) {
        debugPrint('ProfileImage: failed to decode base64 photo: $error');
        // Fall through to the icon avatar if legacy base64 data is invalid.
      }
    }

    return ColoredBox(
      color: resolvedBackgroundColor,
      child: Center(child: resolvedFallback),
    );
  }
}

/// Circular profile avatar built on top of [ProfileImage].
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
    return ClipOval(
      child: SizedBox(
        width: radius * 2,
        height: radius * 2,
        child: ProfileImage(
          profilePhotoUrl: profilePhotoUrl,
          profilePhotoBase64: profilePhotoBase64,
          backgroundColor: backgroundColor,
          fallback: fallback,
        ),
      ),
    );
  }
}
