import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../models/in_call_reaction.dart';

/// Centered floating reaction that rises and fades out.
class InCallReactionOverlay extends StatelessWidget {
  const InCallReactionOverlay({super.key, required this.reactions});

  final List<InCallReaction> reactions;

  @override
  Widget build(BuildContext context) {
    if (reactions.isEmpty) return const SizedBox.shrink();

    return IgnorePointer(
      child: Align(
        alignment: const Alignment(0, -0.08),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var i = 0; i < reactions.length; i++) ...[
              if (i > 0) SizedBox(height: 10.h),
              _FloatingReactionBubble(
                key: ValueKey(reactions[i].id),
                reaction: reactions[i],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _FloatingReactionBubble extends StatefulWidget {
  const _FloatingReactionBubble({super.key, required this.reaction});

  final InCallReaction reaction;

  @override
  State<_FloatingReactionBubble> createState() =>
      _FloatingReactionBubbleState();
}

class _FloatingReactionBubbleState extends State<_FloatingReactionBubble>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2800),
  )..forward();

  late final Animation<double> _opacity = TweenSequence<double>([
    TweenSequenceItem(tween: Tween(begin: 0, end: 1), weight: 12),
    TweenSequenceItem(tween: ConstantTween(1), weight: 58),
    TweenSequenceItem(tween: Tween(begin: 1, end: 0), weight: 30),
  ]).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));

  late final Animation<Offset> _slide = Tween<Offset>(
    begin: const Offset(0, 0.18),
    end: const Offset(0, -0.55),
  ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));

  late final Animation<double> _scale = TweenSequence<double>([
    TweenSequenceItem(
      tween: Tween(begin: 0.86, end: 1.05).chain(CurveTween(curve: Curves.easeOutBack)),
      weight: 18,
    ),
    TweenSequenceItem(tween: Tween(begin: 1.05, end: 1), weight: 12),
    TweenSequenceItem(tween: ConstantTween(1), weight: 70),
  ]).animate(_controller);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reaction = widget.reaction;
    final name = reaction.displayName.trim().isEmpty
        ? 'friend'
        : reaction.displayName.trim().toLowerCase();

    return FadeTransition(
      opacity: _opacity,
      child: SlideTransition(
        position: _slide,
        child: ScaleTransition(
          scale: _scale,
          child: Container(
            constraints: BoxConstraints(maxWidth: 280.w),
            padding: EdgeInsets.symmetric(horizontal: 18.w, vertical: 14.h),
            decoration: BoxDecoration(
              color: const Color.fromRGBO(0, 0, 0, 0.62),
              borderRadius: BorderRadius.circular(22.r),
              border: Border.all(
                color: const Color.fromRGBO(255, 255, 255, 0.16),
              ),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x66000000),
                  blurRadius: 24,
                  offset: Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  reaction.text,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: reaction.isEmojiOnly ? 40.sp : 18.sp,
                    fontWeight: FontWeight.w700,
                    height: 1.2,
                  ),
                ),
                SizedBox(height: 6.h),
                Text(
                  name,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white60,
                    fontSize: 12.sp,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
