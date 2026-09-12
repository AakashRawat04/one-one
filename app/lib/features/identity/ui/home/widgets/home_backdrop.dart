part of '../../identity_home_screen.dart';

// 1. Blurred member collage (default) or illustrated doodle wallpaper.
// 2. Tile grid for group photos.

class _HomeBackdrop extends StatelessWidget {
  const _HomeBackdrop({
    required this.members,
    required this.fallbackPhotoUrl,
    required this.fallbackPhotoBase64,
    required this.fallbackAvatarAsset,
    required this.accent,
  });

  final List<GroupMemberSummary> members;
  final String? fallbackPhotoUrl;
  final String? fallbackPhotoBase64;
  final String? fallbackAvatarAsset;
  final Color accent;

  bool _memberHasPhoto(GroupMemberSummary member) {
    return (member.profilePhotoUrl?.trim().isNotEmpty ?? false) ||
        (member.profilePhotoBase64?.trim().isNotEmpty ?? false) ||
        (member.avatarAsset?.trim().isNotEmpty ?? false);
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<HomeVisualVariant>(
      valueListenable: HomeVisualVariantController.current,
      builder: (context, variant, _) {
        if (variant.usesDoodleBackdrop) {
          return _DoodleBackdrop(assetPath: variant.assetPath!);
        }
        return _CollageBackdrop(
          members: members,
          fallbackPhotoUrl: fallbackPhotoUrl,
          fallbackPhotoBase64: fallbackPhotoBase64,
          fallbackAvatarAsset: fallbackAvatarAsset,
          accent: accent,
          hasMemberPhotos: members.any(_memberHasPhoto),
        );
      },
    );
  }
}

/// Production look: blurred member collage with a dark overlay.
class _CollageBackdrop extends StatelessWidget {
  const _CollageBackdrop({
    required this.members,
    required this.fallbackPhotoUrl,
    required this.fallbackPhotoBase64,
    required this.fallbackAvatarAsset,
    required this.accent,
    required this.hasMemberPhotos,
  });

  static const double _backdropOpacity = 0.35;
  static const double _blurSigma = 40;

  final List<GroupMemberSummary> members;
  final String? fallbackPhotoUrl;
  final String? fallbackPhotoBase64;
  final String? fallbackAvatarAsset;
  final Color accent;
  final bool hasMemberPhotos;

  @override
  Widget build(BuildContext context) {
    final hasFallbackPhoto =
        (fallbackPhotoUrl?.trim().isNotEmpty ?? false) ||
        (fallbackPhotoBase64?.trim().isNotEmpty ?? false) ||
        (fallbackAvatarAsset?.trim().isNotEmpty ?? false);
    final showCollage = members.isNotEmpty ? true : hasFallbackPhoto;
    final baseOpacity = hasMemberPhotos || hasFallbackPhoto
        ? _backdropOpacity
        : 0.2;
    final overlay = (1.15 - _backdropOpacity).clamp(0.42, 0.92);

    return Stack(
      fit: StackFit.expand,
      children: [
        const ColoredBox(color: Colors.black),
        if (showCollage)
          Opacity(
            opacity: baseOpacity,
            child: ImageFiltered(
              imageFilter: ImageFilter.blur(
                sigmaX: _blurSigma,
                sigmaY: _blurSigma,
              ),
              child: FittedBox(
                fit: BoxFit.cover,
                child: SizedBox(
                  width: 400,
                  height: 800,
                  child: _BackdropMemberCollage(
                    members: members,
                    fallbackPhotoUrl: fallbackPhotoUrl,
                    fallbackPhotoBase64: fallbackPhotoBase64,
                    fallbackAvatarAsset: fallbackAvatarAsset,
                  ),
                ),
              ),
            ),
          ),
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.black.withValues(alpha: overlay * 0.34),
                Colors.black.withValues(alpha: overlay * 0.62),
                Colors.black.withValues(alpha: overlay),
                Color.lerp(Colors.black, accent, 0.14)!,
              ],
              stops: const [0, 0.35, 0.72, 1],
            ),
          ),
        ),
      ],
    );
  }
}

/// Dark fade behind top or bottom chrome. No-op on the default look.
class _HomeEdgeVeil extends StatelessWidget {
  const _HomeEdgeVeil({
    required this.fromTop,
    required this.child,
  });

  final bool fromTop;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<HomeVisualVariant>(
      valueListenable: HomeVisualVariantController.current,
      builder: (context, variant, _) {
        if (!variant.usesDoodleBackdrop) return child;
        return DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: fromTop ? Alignment.topCenter : Alignment.bottomCenter,
              end: fromTop ? Alignment.bottomCenter : Alignment.topCenter,
              colors: [
                Colors.black.withValues(alpha: 0.42),
                Colors.black.withValues(alpha: 0.16),
                Colors.transparent,
              ],
              stops: const [0, 0.62, 1],
            ),
          ),
          child: child,
        );
      },
    );
  }
}

/// Full-bleed doodle wallpaper with top/bottom scrims so chrome stays readable.
class _DoodleBackdrop extends StatelessWidget {
  const _DoodleBackdrop({required this.assetPath});

  final String assetPath;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        const ColoredBox(color: Colors.black),
        Image.asset(
          assetPath,
          fit: BoxFit.cover,
          alignment: Alignment.center,
          filterQuality: FilterQuality.medium,
        ),
        // Light overall dim so doodles stay visible but don't compete with UI.
        const ColoredBox(color: Color.fromRGBO(0, 0, 0, 0.12)),
        // Stronger opacity at the top and bottom where chrome sits.
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Color.fromRGBO(0, 0, 0, 0.42),
                Color.fromRGBO(0, 0, 0, 0.16),
                Color.fromRGBO(0, 0, 0, 0.04),
                Color.fromRGBO(0, 0, 0, 0.06),
                Color.fromRGBO(0, 0, 0, 0.22),
                Color.fromRGBO(0, 0, 0, 0.50),
              ],
              stops: [0.0, 0.16, 0.38, 0.58, 0.78, 1.0],
            ),
          ),
        ),
      ],
    );
  }
}

/// Full-bleed member photo grid for the blurred home backdrop.
class _BackdropMemberCollage extends StatelessWidget {
  const _BackdropMemberCollage({
    required this.members,
    required this.fallbackPhotoUrl,
    required this.fallbackPhotoBase64,
    required this.fallbackAvatarAsset,
  });

  static const int _maxTiles = 9;

  final List<GroupMemberSummary> members;
  final String? fallbackPhotoUrl;
  final String? fallbackPhotoBase64;
  final String? fallbackAvatarAsset;

  int _columnsFor(int count) {
    if (count <= 1) return 1;
    if (count <= 4) return 2;
    return 3;
  }

  Widget _tile(GroupMemberSummary member) {
    final initial = profileDisplayInitial(member.displayName);
    return ProfileImage(
      // Keyed by user ID so switching groups/members never reuses another
      // user's ProfileImage state (and its sticky-photo cache) by position.
      key: ValueKey(member.userId),
      profilePhotoUrl: member.profilePhotoUrl,
      profilePhotoBase64: member.profilePhotoBase64,
      avatarAsset: member.avatarAsset,
      backgroundColor: const Color(0xff1a1a1a),
      fallback: Text(
        initial,
        style: const TextStyle(
          color: Colors.white54,
          fontSize: 48,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (members.isEmpty) {
      return ProfileImage(
        profilePhotoUrl: fallbackPhotoUrl,
        profilePhotoBase64: fallbackPhotoBase64,
        avatarAsset: fallbackAvatarAsset,
        backgroundColor: const Color(0xff1a1a1a),
        fallback: const Icon(
          Icons.person_outline,
          color: Colors.white38,
          size: 120,
        ),
      );
    }

    final tiles = members.take(_maxTiles).toList(growable: false);
    final columns = _columnsFor(tiles.length);
    final rows = (tiles.length / columns).ceil();

    return Column(
      children: List.generate(rows, (row) {
        return Expanded(
          child: Row(
            children: List.generate(columns, (column) {
              final index = row * columns + column;
              if (index >= tiles.length) {
                return const Expanded(
                  child: ColoredBox(color: Color(0xff141414)),
                );
              }
              return Expanded(child: _tile(tiles[index]));
            }),
          ),
        );
      }),
    );
  }
}
