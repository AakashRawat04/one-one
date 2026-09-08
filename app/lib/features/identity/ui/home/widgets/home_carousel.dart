part of '../../identity_home_screen.dart';

// 1. Horizontal group carousel + create/join placeholders.
// 2. Edge veil and dashed add circle.

class _ExperienceCarousel extends StatefulWidget {
  const _ExperienceCarousel({
    required this.items,
    required this.index,
    required this.connectedGroupId,
    required this.connecting,
    required this.talkEnabled,
    required this.talkActive,
    required this.talkBusy,
    required this.accent,
    required this.nudgeGroupId,
    required this.goLiveGroupId,
    required this.onNudge,
    required this.onSelected,
    required this.onTalkStart,
    required this.onTalkStop,
    required this.onJoinVoiceGroup,
    required this.onCreateGroup,
    required this.onJoinGroup,
  });

  final List<_CarouselItem> items;
  final int index;
  final String? connectedGroupId;

  /// True while LiveKit is joining, reconnecting, or leaving.
  final bool connecting;
  final bool talkEnabled;
  final bool talkActive;
  final bool talkBusy;
  final Color accent;

  /// Group id of the focused card when the whole group (self included) is
  /// offline — tapping the main circle opens the nudge composer. Null when
  /// the focused card should join instead (peers already live, or switching
  /// from another connected group).
  final String? nudgeGroupId;

  /// Focused room with an active LiveKit peer while this user is offline.
  final String? goLiveGroupId;
  final VoidCallback? onNudge;
  final ValueChanged<int> onSelected;
  final Future<void> Function() onTalkStart;
  final Future<void> Function() onTalkStop;
  final VoidCallback onJoinVoiceGroup;
  final VoidCallback onCreateGroup;
  final VoidCallback onJoinGroup;

  @override
  State<_ExperienceCarousel> createState() => _ExperienceCarouselState();
}

class _ExperienceCarouselState extends State<_ExperienceCarousel>
    with SingleTickerProviderStateMixin {
  late final AnimationController _settleController = AnimationController(
    vsync: this,
  );
  late double _position = widget.index.toDouble();
  Animation<double>? _settleAnimation;
  double _itemSpacing = 64;
  int? _selectionAfterSettle;

  @override
  void initState() {
    super.initState();
    _settleController.addListener(_onSettleTick);
    _settleController.addStatusListener(_onSettleStatus);
  }

  @override
  void didUpdateWidget(covariant _ExperienceCarousel oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.items.isEmpty) {
      _settleController.stop();
      _position = 0;
      return;
    }

    final lastIndex = widget.items.length - 1;
    _position = _position.clamp(0, lastIndex).toDouble();
    if (widget.index != oldWidget.index &&
        widget.index != _position.round() &&
        !_settleController.isAnimating) {
      _animateTo(widget.index, notifySelection: false);
    }
  }

  @override
  void dispose() {
    _settleController
      ..removeListener(_onSettleTick)
      ..removeStatusListener(_onSettleStatus)
      ..dispose();
    super.dispose();
  }

  void _onSettleTick() {
    final animation = _settleAnimation;
    if (animation == null || !mounted) return;
    setState(() => _position = animation.value);
  }

  void _onSettleStatus(AnimationStatus status) {
    if (status != AnimationStatus.completed) return;
    final selection = _selectionAfterSettle;
    _selectionAfterSettle = null;
    if (selection == null || selection == widget.index) return;
    unawaited(HapticFeedback.selectionClick());
    widget.onSelected(selection);
  }

  void _animateTo(int target, {required bool notifySelection}) {
    if (widget.items.isEmpty) return;
    final resolvedTarget = target.clamp(0, widget.items.length - 1);
    final distance = (_position - resolvedTarget).abs();

    _settleController.stop();
    _selectionAfterSettle = notifySelection ? resolvedTarget : null;
    _settleController.duration = Duration(
      milliseconds: (220 + distance * 45).clamp(220, 420).round(),
    );
    _settleAnimation =
        Tween<double>(begin: _position, end: resolvedTarget.toDouble()).animate(
          CurvedAnimation(
            parent: _settleController,
            curve: Curves.easeOutCubic,
          ),
        );
    _settleController.forward(from: 0);
  }

  void _onHorizontalDragStart(DragStartDetails details) {
    _selectionAfterSettle = null;
    _settleController.stop();
  }

  void _onHorizontalDragUpdate(DragUpdateDetails details) {
    if (widget.items.length < 2) return;
    final next = _position - details.delta.dx / _itemSpacing;
    setState(() {
      _position = next.clamp(0, widget.items.length - 1).toDouble();
    });
  }

  void _onHorizontalDragEnd(DragEndDetails details) {
    if (widget.items.isEmpty) return;
    final projected = _position - details.velocity.pixelsPerSecond.dx / 1000;
    _animateTo(projected.round(), notifySelection: true);
  }

  void _onHorizontalDragCancel() {
    if (widget.items.isEmpty) return;
    _animateTo(_position.round(), notifySelection: true);
  }

  Widget _buildGroupCircle(int itemIndex, double spacing) {
    final item = widget.items[itemIndex];
    final delta = itemIndex - _position;
    final distance = delta.abs();
    final visualFocus = _position.round().clamp(0, widget.items.length - 1);
    final visuallySelected = itemIndex == visualFocus;
    final actuallySelected = itemIndex == widget.index;
    final scale = (1 / (1 + distance * 0.46)).clamp(0.4, 1.0);
    final opacity = (1 - distance * 0.18).clamp(0.28, 1.0);
    final rotationY = (delta * -0.26).clamp(-0.62, 0.62);

    final connectedToThisGroup = item.group.groupId == widget.connectedGroupId;
    final focused = actuallySelected && distance < 0.45;
    final goLiveMode = focused && item.group.groupId == widget.goLiveGroupId;
    Widget circle = _MainAvatarCircle(
      item: item,
      selected: visuallySelected,
      connected: connectedToThisGroup,
      connecting: widget.connecting && focused,
      talkEnabled: widget.talkEnabled && focused,
      joinEnabled:
          focused &&
          !widget.connecting &&
          !connectedToThisGroup &&
          // Direct join only when this card is in Join? / go-live mode.
          // Locked / unknown access never sets goLiveGroupId, so Join?
          // cannot appear or be tapped.
          goLiveMode,
      talkActive: widget.talkActive && actuallySelected,
      talkBusy: widget.talkBusy,
      accent: widget.accent,
      // Offline/default icon whenever this focused card is not in a live
      // session and not mid-connect — never leave the circle with no glyph.
      nudgeMode:
          focused &&
          !widget.connecting &&
          !connectedToThisGroup &&
          item.group.groupId == widget.nudgeGroupId,
      goLiveMode: goLiveMode,
      onNudge: widget.onNudge,
      onTalkStart: widget.onTalkStart,
      onTalkStop: widget.onTalkStop,
      onJoin: widget.onJoinVoiceGroup,
    );

    if (!actuallySelected) {
      circle = Semantics(
        button: true,
        label: context.l10n.homeSelectGroup(item.group.name),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => _animateTo(itemIndex, notifySelection: true),
          child: circle,
        ),
      );
    }

    return Positioned.fill(
      child: Center(
        child: Transform.translate(
          offset: Offset(delta * spacing, distance * 7.h),
          child: Opacity(
            opacity: opacity,
            child: Transform(
              alignment: Alignment.center,
              transform: Matrix4.identity()
                ..setEntry(3, 2, 0.0014)
                ..rotateY(rotationY),
              child: Transform.scale(
                scale: scale,
                child: focused && connectedToThisGroup && !widget.connecting
                    ? Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            widget.talkActive
                                ? context.l10n.homeTapToStopTalking
                                : context.l10n.homeTapToTalk,
                            maxLines: 1,
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 12.sp,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          SizedBox(height: 4.h),
                          circle,
                        ],
                      )
                    : circle,
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.items.isEmpty) {
      return Row(
        children: [
          SizedBox(width: 16.w),
          _DashedAddCircle(
            onTap: widget.onJoinGroup,
            compact: true,
            label: context.l10n.homeJoinGroup,
          ),
          const Spacer(),
          _DashedAddCircle(
            onTap: widget.onCreateGroup,
            compact: true,
            label: context.l10n.homeCreateGroup,
          ),
          SizedBox(width: 16.w),
        ],
      );
    }

    return Row(
      children: [
        SizedBox(width: 12.w),
        _DashedAddCircle(
          onTap: widget.onJoinGroup,
          compact: true,
          label: context.l10n.homeJoinGroup,
        ),
        SizedBox(width: 8.w),
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final spacing = (constraints.maxWidth * 0.34).clamp(52.w, 70.w);
              _itemSpacing = spacing;
              final paintOrder =
                  List<int>.generate(
                    widget.items.length,
                    (itemIndex) => itemIndex,
                  )..sort((a, b) {
                    final aDistance = (a - _position).abs();
                    final bDistance = (b - _position).abs();
                    return bDistance.compareTo(aDistance);
                  });

              return ClipRect(
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: ShaderMask(
                        blendMode: BlendMode.dstIn,
                        shaderCallback: (bounds) => const LinearGradient(
                          colors: [
                            Colors.transparent,
                            Color(0x40FFFFFF),
                            Colors.white,
                            Colors.white,
                            Color(0x40FFFFFF),
                            Colors.transparent,
                          ],
                          stops: [0, 0.08, 0.22, 0.78, 0.92, 1],
                        ).createShader(bounds),
                        child: GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onHorizontalDragStart: _onHorizontalDragStart,
                          onHorizontalDragUpdate: _onHorizontalDragUpdate,
                          onHorizontalDragEnd: _onHorizontalDragEnd,
                          onHorizontalDragCancel: _onHorizontalDragCancel,
                          child: Stack(
                            clipBehavior: Clip.hardEdge,
                            children: [
                              for (final itemIndex in paintOrder)
                                _buildGroupCircle(itemIndex, spacing),
                            ],
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      left: 0,
                      top: 0,
                      bottom: 0,
                      width: 52.w,
                      child: const HorizontalEdgeVeil(leftEdge: true),
                    ),
                    Positioned(
                      right: 0,
                      top: 0,
                      bottom: 0,
                      width: 52.w,
                      child: const HorizontalEdgeVeil(leftEdge: false),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
        SizedBox(width: 8.w),
        _DashedAddCircle(
          onTap: widget.onCreateGroup,
          compact: true,
          label: context.l10n.homeCreateGroup,
        ),
        SizedBox(width: 12.w),
      ],
    );
  }
}

class _DashedAddCircle extends StatelessWidget {
  const _DashedAddCircle({
    required this.onTap,
    required this.compact,
    required this.label,
  });

  final VoidCallback? onTap;
  final bool compact;
  final String label;

  @override
  Widget build(BuildContext context) {
    final size = compact ? 72.w : 110.w;
    return GestureDetector(
      onTap: onTap,
      child: Opacity(
        opacity: onTap == null ? 0.45 : 1,
        child: CustomPaint(
          painter: _DashedCirclePainter(
            color: const Color.fromRGBO(255, 255, 255, 0.7),
          ),
          child: SizedBox(
            width: size,
            height: size,
            child: Center(
              child: Padding(
                padding: EdgeInsets.all(10.w),
                child: Text(
                  label,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: compact ? 9.sp : 12.sp,
                    fontWeight: FontWeight.w600,
                    height: 1.15,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _DashedCirclePainter extends CustomPainter {
  const _DashedCirclePainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8;

    final radius = size.shortestSide / 2;
    const dashCount = 28;
    const dashSweep = 0.12;
    const gapSweep = (6.28318530718 / dashCount) - dashSweep;
    var start = 0.0;

    for (var i = 0; i < dashCount; i++) {
      canvas.drawArc(
        Rect.fromCircle(center: size.center(Offset.zero), radius: radius),
        start,
        dashSweep,
        false,
        paint,
      );
      start += dashSweep + gapSweep;
    }
  }

  @override
  bool shouldRepaint(covariant _DashedCirclePainter oldDelegate) {
    return oldDelegate.color != color;
  }
}

class _CarouselItem {
  const _CarouselItem({
    required this.group,
    required this.displayName,
    required this.availability,
    this.profilePhotoUrl,
    this.profilePhotoBase64,
    this.avatarAsset,
    this.members = const [],
  });

  factory _CarouselItem.group({
    required GroupSummary group,
    required String displayName,
    required String? profilePhotoUrl,
    required String? profilePhotoBase64,
    required String? avatarAsset,
    required MemberAvailability availability,
    List<GroupMemberSummary> members = const [],
  }) {
    return _CarouselItem(
      group: group,
      displayName: displayName,
      profilePhotoUrl: profilePhotoUrl,
      profilePhotoBase64: profilePhotoBase64,
      avatarAsset: avatarAsset,
      availability: availability,
      members: members,
    );
  }

  final GroupSummary group;
  final String displayName;
  final MemberAvailability availability;
  final String? profilePhotoUrl;
  final String? profilePhotoBase64;
  final String? avatarAsset;

  /// Group members loaded for this group (only populated for the
  /// currently-selected/focused group). Used to render a photo collage on
  /// the connect circle so it's obvious at a glance who you're joining.
  final List<GroupMemberSummary> members;
}
